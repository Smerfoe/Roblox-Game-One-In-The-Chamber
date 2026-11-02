-- MemoryStore: an in-memory stand-in for a DataStore, used in Studio when API
-- access is off and by the data tests. It behaves like UpdateAsync (the
-- transform gets a copy of the current value; returning nil cancels the write)
-- and can be told to fail, so error handling can be tested.
-- Contents are lost when the server stops.

local Schema = require(script.Parent.Schema)

local MemoryStore = {}
MemoryStore.__index = MemoryStore

function MemoryStore.new(name)
	return setmetatable({
		Name = name or "Memory",
		Kind = "Memory",
		values = {},
		failNext = 0, -- the next N calls error
		failAll = false, -- every call errors (store "down")
		calls = 0,
		writes = 0,
	}, MemoryStore)
end

function MemoryStore:UpdateAsync(key, transform)
	self.calls += 1
	task.wait() -- real calls always yield
	if self.failAll or self.failNext > 0 then
		self.failNext = math.max(0, self.failNext - 1)
		error("MemoryStore: simulated DataStore failure", 0)
	end
	local result = transform(Schema.DeepCopy(self.values[key]))
	if result ~= nil then
		self.values[key] = Schema.DeepCopy(result)
		self.writes += 1
	end
	return result
end

-- test helpers
function MemoryStore:FailNext(n)
	self.failNext = n
end
function MemoryStore:SetFailAll(on)
	self.failAll = on
end
function MemoryStore:Peek(key)
	return Schema.DeepCopy(self.values[key])
end
function MemoryStore:Poke(key, value)
	self.values[key] = Schema.DeepCopy(value)
end

return MemoryStore
