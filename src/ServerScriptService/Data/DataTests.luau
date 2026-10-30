-- DataTests: checks for ProfileStore / Schema against MemoryStore with a fake
-- clock (no real DataStore calls, no waiting). Run from the Studio command bar
-- or a test server:  print(require(game.ServerScriptService.Data.DataTests).Run())
-- Not required by any game script.

local Schema = require(script.Parent.Schema)
local ProfileStore = require(script.Parent.ProfileStore)
local MemoryStore = require(script.Parent.MemoryStore)
local DataConfig = require(script.Parent.DataConfig)

local DataTests = {}

local function same(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not same(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- a world with one shared store and a controllable clock
local function world()
	local w = { t = 1000, store = MemoryStore.new("test") }
	w.now = function()
		return w.t
	end
	w.wait = function(seconds)
		w.t += seconds or 0 -- waiting moves the fake clock; nothing really sleeps
	end
	w.session = function(id)
		return ProfileStore.new({ store = w.store, sessionId = id, config = DataConfig, now = w.now, wait = w.wait })
	end
	return w
end

local cases = {}
local function case(name, fn)
	table.insert(cases, { name = name, fn = fn })
end

case("new player loads defaults and takes the lock", function()
	local w = world()
	local a = w.session("A")
	local result, profile = a:Load("u_1")
	assert(result == "Ok", result)
	assert(profile.IsNew and same(profile.Data, Schema.Default()), "defaults")
	local record = w.store:Peek("u_1")
	assert(record.Lock.Session == profile.Session, "lock owner")
end)

case("save persists data and refreshes the lock", function()
	local w = world()
	local a = w.session("A")
	local _, profile = a:Load("u_1")
	profile.Data.Inventory.Skins["service1911.slate"] = true
	profile.Data.Equipped.Service1911 = "service1911.slate"
	w.t += 50
	assert(a:Save(profile) == "Ok")
	local record = w.store:Peek("u_1")
	assert(record.Data.Equipped.Service1911 == "service1911.slate", "saved")
	assert(record.Lock.Time == w.t, "lock refreshed")
	assert(record.SaveCount == 1, "save count")
end)

case("leave releases the lock; rejoin (other server) gets the saved data", function()
	local w = world()
	local a = w.session("A")
	local _, profile = a:Load("u_1")
	profile.Data.Inventory.Skins["karambit.ember"] = true
	assert(a:Save(profile, true) == "Ok")
	assert(profile.Active == false and w.store:Peek("u_1").Lock == nil, "released")
	assert(a:Save(profile) == "Inactive", "no saves after release")
	local b = w.session("B")
	local result, again = b:Load("u_1")
	assert(result == "Ok" and again.Data.Inventory.Skins["karambit.ember"] == true, "rejoin data")
	assert(not again.IsNew, "not new")
end)

case("competing session: second server waits, then gives up without writing", function()
	local w = world()
	local a = w.session("A")
	local _, profileA = a:Load("u_1")
	profileA.Data.Inventory.Skins["service1911.desert"] = true
	a:Save(profileA)
	local before = w.store:Peek("u_1")
	local writes = w.store.writes
	local b = w.session("B")
	local result = b:Load("u_1")
	assert(result == "Locked", result)
	assert(w.store.writes == writes, "B wrote nothing")
	assert(same(w.store:Peek("u_1"), before), "record unchanged")
	-- A keeps working normally
	assert(a:Save(profileA) == "Ok", "A still saves")
end)

case("competing session: a released lock is picked up while waiting", function()
	local w = world()
	local a = w.session("A")
	local _, profileA = a:Load("u_1")
	local b = w.session("B")
	-- A releases during B's first wait
	local realWait = w.wait
	local released = false
	b.wait = function(s)
		if not released then
			released = true
			a:Save(profileA, true)
		end
		realWait(s)
	end
	local result, profileB = b:Load("u_1")
	assert(result == "Ok", result)
	assert(w.store:Peek("u_1").Lock.Session == profileB.Session, "B owns it")
end)

case("stale lock (crashed server) is taken over; the old server can't save over it", function()
	local w = world()
	local a = w.session("A")
	local _, profileA = a:Load("u_1")
	w.t += DataConfig.LockStaleAfter + 1 -- A stopped refreshing
	local b = w.session("B")
	local result, profileB = b:Load("u_1")
	assert(result == "Ok", result)
	profileB.Data.Inventory.Skins["karambit.forest"] = true
	assert(b:Save(profileB) == "Ok")
	profileA.Data.Inventory.Skins = {} -- old, wrong data on the dead server
	assert(a:Save(profileA) == "LostLock", "A must not write")
	assert(profileA.Active == false, "A deactivated")
	assert(w.store:Peek("u_1").Data.Inventory.Skins["karambit.forest"] == true, "B's data intact")
end)

case("failed load (store down) never writes and leaves existing data intact", function()
	local w = world()
	local a = w.session("A")
	local _, profile = a:Load("u_1")
	profile.Data.Inventory.Skins["service1911.crimson"] = true
	a:Save(profile, true)
	local before = w.store:Peek("u_1")
	w.store:SetFailAll(true)
	local b = w.session("B")
	local result, err = b:Load("u_1")
	assert(result == "Failed" and err, tostring(result))
	assert(w.store.calls > 0)
	w.store:SetFailAll(false)
	assert(same(w.store:Peek("u_1"), before), "existing data untouched")
	-- after recovery the real data loads
	local again, loaded = b:Load("u_1")
	assert(again == "Ok" and loaded.Data.Inventory.Skins["service1911.crimson"], "data back")
end)

case("transient errors: load succeeds after retries with backoff", function()
	local w = world()
	w.store:FailNext(2)
	local start = w.t
	local result = w.session("A"):Load("u_1")
	assert(result == "Ok", result)
	assert(w.t - start == DataConfig.RetryBaseDelay * 3, "waited 1 + 2 seconds")
end)

case("save failure keeps the profile active and the old record; a later save works", function()
	local w = world()
	local a = w.session("A")
	local _, profile = a:Load("u_1")
	a:Save(profile)
	local before = w.store:Peek("u_1")
	profile.Data.Equipped.Karambit = "karambit.ivory"
	w.store:SetFailAll(true)
	local result = a:Save(profile)
	assert(result == "Failed", result)
	assert(profile.Active, "still active")
	assert(same(w.store:Peek("u_1"), before), "nothing partial written")
	w.store:SetFailAll(false)
	assert(a:Save(profile) == "Ok")
	assert(w.store:Peek("u_1").Data.Equipped.Karambit == "karambit.ivory")
end)

case("data from a newer schema is refused and never overwritten", function()
	local w = world()
	local future = { Data = { SchemaVersion = 99, Inventory = { Skins = { ["x.future"] = true } } } }
	w.store:Poke("u_1", future)
	local result = w.session("A"):Load("u_1")
	assert(result == "Incompatible", result)
	assert(same(w.store:Peek("u_1"), future), "untouched")
end)

case("an unreadable record is refused and never overwritten", function()
	local w = world()
	w.store:Poke("u_1", "not a record")
	assert(w.session("A"):Load("u_1") == "Corrupt")
	assert(w.store:Peek("u_1") == "not a record", "untouched")
	w.store:Poke("u_2", { Data = 5 })
	assert(w.session("A"):Load("u_2") == "Corrupt")
end)

case("schema repair keeps valid entries and drops wrong types", function()
	local data = Schema.Migrate({
		SchemaVersion = 1,
		Inventory = { Skins = { ["service1911.slate"] = true, ["bad"] = "yes", [5] = true } },
		Equipped = { Service1911 = "service1911.slate", Karambit = 12 },
		Progression = "oops",
	})
	assert(data.Inventory.Skins["service1911.slate"] == true and data.Inventory.Skins.bad == nil and data.Inventory.Skins[5] == nil)
	assert(data.Equipped.Service1911 == "service1911.slate" and data.Equipped.Karambit == nil)
	assert(type(data.Progression) == "table")
	local missing = Schema.Migrate({})
	assert(missing.SchemaVersion == Schema.CURRENT and type(missing.Inventory.Skins) == "table")
end)

case("same server rejoin cannot reuse an active acquisition", function()
	local w = world()
	local a = w.session("A")
	local _, old = a:Load("u_1")
	assert(a:Load("u_1") == "Locked", "second handle must wait")
	assert(a:Save(old, true) == "Ok")
	local result, current = a:Load("u_1")
	assert(result == "Ok" and current.Session ~= old.Session, "fresh acquisition")
end)

case("old same-server cleanup cannot erase a newer acquisition", function()
	local w = world()
	local a = w.session("A")
	local _, old = a:Load("u_1")
	w.t += DataConfig.LockStaleAfter + 1
	local result, current = a:Load("u_1")
	assert(result == "Ok")
	current.Data.Inventory.Skins["service1911.slate"] = true
	assert(a:Save(current) == "Ok")
	local before = w.store:Peek("u_1")
	local saved = a:Save(old, true)
	assert(same(w.store:Peek("u_1"), before), "stale cleanup erased data or released the new lock")
	assert(saved == "LostLock", "late cleanup must not release new lock")
end)

case("ambiguous committed load retries its own acquisition safely", function()
	local w = world()
	local update = w.store.UpdateAsync
	local failed = false
	w.store.UpdateAsync = function(store, key, transform)
		local result = update(store, key, transform)
		if not failed then failed = true; error("response lost after commit") end
		return result
	end
	local result, profile = w.session("A"):Load("u_1")
	assert(result == "Ok" and profile.Active, result)
	assert(w.store:Peek("u_1").Lock.Session == profile.Session)
end)

case("missing payload and malformed envelope are refused without writes", function()
	local records = {
		{}, { SaveCount = 12 },
		{ Data = {}, Lock = "bad" },
		{ Data = {}, Lock = { Session = "other", Time = "bad" } },
		{ Data = {}, Lock = { Time = 1000 } },
		{ Data = {}, SaveCount = "bad" },
		{ Data = { SchemaVersion = "99" } },
		{ Data = { SchemaVersion = 1.5 } },
		{ Data = { SchemaVersion = 0 } },
	}
	for _, record in records do
		local w = world()
		w.store:Poke("u_1", record)
		assert(w.session("A"):Load("u_1") == "Corrupt")
		assert(w.store.writes == 0 and same(w.store:Peek("u_1"), record), "malformed record untouched")
	end
end)

function DataTests.Run()
	local passed, failed, lines = 0, 0, {}
	for _, c in cases do
		local ok, err = pcall(c.fn)
		if ok then
			passed += 1
			table.insert(lines, "PASS  " .. c.name)
		else
			failed += 1
			table.insert(lines, "FAIL  " .. c.name .. "  ->  " .. tostring(err))
		end
	end
	table.insert(lines, ("%d passed, %d failed"):format(passed, failed))
	return table.concat(lines, "\n"), failed == 0
end

return DataTests
