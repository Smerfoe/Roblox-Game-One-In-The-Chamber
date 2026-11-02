-- DataService: server-owned player data (inventory, equipped skins, later progression).
--
--   * Loads each player's record with a session lock (Data.ProfileStore) and
--     saves through UpdateAsync with retries and backoff.
--   * Saves: shortly after a change, every AutosaveInterval, and on leave /
--     server shutdown (releasing the lock).
--   * If the load fails, is locked by another server or the data is from a
--     newer version, the player keeps playing with default skins, nothing is
--     ever saved for them this session, and their stored data stays as it was.
--   * Studio uses a separate store; without Studio API access it falls back to
--     an in-memory store (see Data.DataConfig).
--   * Clients never write data. Other services change it only through
--     DataService.Update; equipping goes through InventoryService.
--
-- Player attribute "DataStatus": Loading | Ready | Failed | Locked | Incompatible | Corrupt | SessionLost
-- Nothing else about the data is replicated from here (InventoryService sends
-- the owner their own inventory).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local DataFolder = ServerScriptService:WaitForChild("Data")
local DataConfig = require(DataFolder.DataConfig)
local Schema = require(DataFolder.Schema)
local ProfileStore = require(DataFolder.ProfileStore)
local MemoryStore = require(DataFolder.MemoryStore)

local IS_STUDIO = RunService:IsStudio()

local DataService = {}

local sessionId = HttpService:GenerateGUID(false)
local store -- adapter with UpdateAsync
local profiles -- ProfileStore
local states = {} -- [player] = { profile, status, version, savedVersion, saveQueued, saving }
local releasing = {} -- [userId] = true while a leave-save is in flight

local changedEvent = Instance.new("BindableEvent")
DataService.Changed = changedEvent.Event -- (player) data or status changed

local function log(...)
	print("[Data]", ...)
end

------------------------------------------------------------------ store selection
local function dataStoreAdapter(name)
	local ds = DataStoreService:GetDataStore(name)
	return {
		Kind = "DataStore",
		Name = name,
		UpdateAsync = function(_, key, transform, userIds)
			return ds:UpdateAsync(key, function(old)
				local new = transform(old)
				if new == nil then
					return nil
				end
				return new, userIds
			end)
		end,
	}
end

local function chooseStore()
	if not IS_STUDIO then
		return dataStoreAdapter(DataConfig.StoreName)
	end
	-- Studio: probe API access with a read of the Studio-only store
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(DataConfig.StudioStoreName):GetAsync("probe")
	end)
	if ok then
		return dataStoreAdapter(DataConfig.StudioStoreName)
	end
	if DataConfig.StudioFallbackToMemory then
		warn("[Data] Studio DataStore access unavailable (" .. tostring(err) .. "). Using an in-memory store; data is lost when the test stops.")
		return MemoryStore.new(DataConfig.StudioStoreName .. " (memory)")
	end
	return dataStoreAdapter(DataConfig.StudioStoreName) -- loads will fail safely
end

local function keyFor(userId)
	return DataConfig.KeyPrefix .. tostring(userId)
end

local function setStatus(player, status)
	local state = states[player]
	if state then
		state.status = status
	end
	player:SetAttribute("DataStatus", status)
	changedEvent:Fire(player)
end

------------------------------------------------------------------ saving
local function save(player, release)
	local state = states[player]
	if not state or not state.profile or not state.profile.Active then
		return "Inactive"
	end
	while state.saving do
		task.wait() -- one write at a time per player, in order
	end
	if not state.profile.Active then
		return "Inactive"
	end
	state.saving = true
	local version = state.version
	local result, err = profiles:Save(state.profile, release, { player.UserId })
	state.saving = false
	if result == "Ok" then
		state.savedVersion = math.max(state.savedVersion, version)
	elseif result == "LostLock" then
		warn("[Data] another server took over", player.Name, "'s data; this server stopped saving it")
		if player.Parent then
			setStatus(player, "SessionLost")
		end
	elseif result == "Failed" then
		warn("[Data] save failed for", player.Name, err)
	end
	return result
end

local function queueSave(player)
	local state = states[player]
	if not state or state.saveQueued then
		return
	end
	state.saveQueued = true
	task.delay(DataConfig.SaveDelayAfterChange, function()
		state.saveQueued = false
		if states[player] == state and state.version > state.savedVersion then
			save(player, false)
		end
	end)
end

------------------------------------------------------------------ load / unload
local function load(player)
	while releasing[player.UserId] do
		task.wait(0.1) -- rejoining this same server while the leave-save is still running
	end
	local state = { status = "Loading", version = 0, savedVersion = 0 }
	states[player] = state
	setStatus(player, "Loading")
	local result, info = profiles:Load(keyFor(player.UserId), { player.UserId })
	if states[player] ~= state then
		-- the player left (or was reloaded by a test) while loading: give the lock back
		if result == "Ok" then
			profiles:Save(info, true, { player.UserId })
		end
		return
	end
	if result == "Ok" then
		state.profile = info
		setStatus(player, "Ready")
		log("loaded", player.Name, info.IsNew and "(new)" or "")
	else
		state.profile = nil
		setStatus(player, result)
		warn("[Data] load for", player.Name, "ended as", result, "-", typeof(info) == "table" and HttpService:JSONEncode(info) or tostring(info), "- defaults this session, nothing will be saved")
	end
end

local function unload(player)
	local state = states[player]
	if not state then
		return
	end
	releasing[player.UserId] = true
	if state.profile and state.profile.Active then
		save(player, true)
	end
	states[player] = nil
	releasing[player.UserId] = nil
end

------------------------------------------------------------------ public API
function DataService.GetStatus(player)
	local state = states[player]
	return state and state.status or "Loading"
end

function DataService.IsReady(player)
	local state = states[player]
	return state ~= nil and state.status == "Ready" and state.profile ~= nil and state.profile.Active
end

-- Read-only copy of the player's data (nil unless Ready).
function DataService.Get(player)
	return DataService.IsReady(player) and Schema.DeepCopy(states[player].profile.Data) or nil
end

-- Change data on the server. mutator(data) edits in place and returns true if it changed.
-- Returns false (and changes nothing) unless the data is loaded and owned by this server.
function DataService.Update(player, mutator)
	if not DataService.IsReady(player) then
		return false
	end
	local state = states[player]
	local working = Schema.DeepCopy(state.profile.Data)
	if mutator(working) ~= true then
		return false
	end
	state.profile.Data = working
	state.version += 1
	queueSave(player)
	changedEvent:Fire(player)
	return true
end

function DataService.OwnsSkin(player, skinId)
	local data = DataService.IsReady(player) and states[player].profile.Data
	return data and data.Inventory.Skins[skinId] == true or false
end

-- The stored equipped skin id for a weapon (may be nil or no longer valid;
-- callers resolve it with SkinAppearance.Resolve).
function DataService.GetEquippedSkin(player, weaponId)
	local data = DataService.IsReady(player) and states[player].profile.Data
	return data and data.Equipped[weaponId] or nil
end

------------------------------------------------------------------ developer test grants (server-only, no remote)
local function devAllowed(player)
	if IS_STUDIO then
		return true
	end
	return DataConfig.AllowLiveDevGrants and table.find(DataConfig.DeveloperUserIds, player.UserId) ~= nil
end

function DataService.DevGrantSkin(player, skinId)
	assert(devAllowed(player), "developer grants are not allowed here")
	assert(type(skinId) == "string", "skinId must be a string")
	return DataService.Update(player, function(data)
		if data.Inventory.Skins[skinId] then
			return false
		end
		data.Inventory.Skins[skinId] = true
		return true
	end)
end

function DataService.DevRevokeSkin(player, skinId)
	assert(devAllowed(player), "developer grants are not allowed here")
	return DataService.Update(player, function(data)
		if not data.Inventory.Skins[skinId] then
			return false
		end
		data.Inventory.Skins[skinId] = nil
		for weapon, equipped in data.Equipped do
			if equipped == skinId then
				data.Equipped[weapon] = nil
			end
		end
		return true
	end)
end

------------------------------------------------------------------ Studio test hooks
-- Only in Studio: lets the data tests simulate leave / rejoin and inspect the store.
if IS_STUDIO then
	DataService.Test = {
		SaveNow = function(player)
			return save(player, false)
		end,
		Leave = function(player) -- the same save-and-release that runs on PlayerRemoving
			unload(player)
			player:SetAttribute("DataStatus", nil)
		end,
		Join = function(player) -- the same load that runs on PlayerAdded
			load(player)
		end,
		Store = function()
			return store
		end,
		Key = keyFor,
		SessionId = function()
			return sessionId
		end,
		Profiles = function()
			return profiles
		end,
		-- a second "server" on the same store, to test competing sessions
		CompetingLoad = function(userId, waitSeconds)
			local other = ProfileStore.new({
				store = store,
				sessionId = "other-server-" .. HttpService:GenerateGUID(false),
				config = DataConfig,
				wait = function()
					task.wait(waitSeconds or 0.05)
				end,
			})
			return other:Load(keyFor(userId))
		end,
	}
end

-- Studio only: test scripts run outside the game's script context and can't
-- reach this module's state with require(), so they call in through this
-- server-only BindableFunction (ServerStorage.DataTestHook). Not created in live servers.
local function installTestHook()
	local hook = Instance.new("BindableFunction")
	hook.Name = "DataTestHook"
	hook.OnInvoke = function(action, userId, arg)
		local player = Players:GetPlayerByUserId(userId)
		local t = DataService.Test
		if action == "Grant" then
			return DataService.DevGrantSkin(player, arg)
		elseif action == "Revoke" then
			return DataService.DevRevokeSkin(player, arg)
		elseif action == "Get" then
			return DataService.Get(player), DataService.GetStatus(player)
		elseif action == "SaveNow" then
			return t.SaveNow(player)
		elseif action == "Leave" then
			return t.Leave(player)
		elseif action == "Join" then
			return t.Join(player)
		elseif action == "Peek" then
			return store.Peek and store:Peek(keyFor(userId))
		elseif action == "Poke" then
			return store.Poke and store:Poke(keyFor(userId), arg)
		elseif action == "FailAll" then
			return store.SetFailAll and store:SetFailAll(arg)
		elseif action == "FailNext" then
			return store.FailNext and store:FailNext(arg)
		elseif action == "CompetingLoad" then
			return t.CompetingLoad(userId, arg)
		elseif action == "StoreKind" then
			return store.Kind, store.Name
		end
		error("unknown action " .. tostring(action))
	end
	hook.Parent = game:GetService("ServerStorage")
end

------------------------------------------------------------------ start
function DataService.Start()
	store = chooseStore()
	profiles = ProfileStore.new({ store = store, sessionId = sessionId, config = DataConfig, log = log })
	log("using", store.Kind, store.Name, "session", sessionId)
	if IS_STUDIO then
		installTestHook()
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(unload)

	task.spawn(function()
		while true do
			task.wait(DataConfig.AutosaveInterval)
			for player, state in states do
				if state.profile and state.profile.Active and not state.saving then
					task.spawn(save, player, false) -- also refreshes the session lock
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in states do
			pending += 1
			task.spawn(function()
				unload(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
