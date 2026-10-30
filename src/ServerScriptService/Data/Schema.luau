-- Schema: the shape of saved player data, with versioning.
--
-- Version 1:
--   {
--     SchemaVersion = 1,
--     Inventory   = { Skins = { [skinId] = true } },   -- owned skins (defaults are implied, not stored)
--     Equipped    = { [weaponId] = skinId },          -- chosen skin per weapon
--     Progression = {},                               -- reserved for later (levels, XP, ...)
--   }
--
-- To change the shape: bump CURRENT, add a step to MIGRATIONS that upgrades
-- version n to n + 1, and never edit an old step. Data written by a NEWER
-- version than this code knows is refused (never downgraded or overwritten).

local Schema = {}

Schema.CURRENT = 1

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
Schema.DeepCopy = deepCopy

function Schema.Default()
	return {
		SchemaVersion = Schema.CURRENT,
		Inventory = { Skins = {} },
		Equipped = {},
		Progression = {},
	}
end

-- MIGRATIONS[n] upgrades a version-n table to version n + 1 (none yet).
local MIGRATIONS = {}

function Schema.IsNewer(data)
	return type(data) == "table" and type(data.SchemaVersion) == "number" and data.SchemaVersion > Schema.CURRENT
end

-- Repair wrong-typed fields without dropping anything that might be valid
-- (unknown skin ids are kept: a retired skin may come back).
local function repair(data)
	if type(data.Inventory) ~= "table" then
		data.Inventory = {}
	end
	if type(data.Inventory.Skins) ~= "table" then
		data.Inventory.Skins = {}
	end
	for id, owned in data.Inventory.Skins do
		if type(id) ~= "string" or owned ~= true then
			data.Inventory.Skins[id] = nil
		end
	end
	if type(data.Equipped) ~= "table" then
		data.Equipped = {}
	end
	for weapon, skin in data.Equipped do
		if type(weapon) ~= "string" or type(skin) ~= "string" then
			data.Equipped[weapon] = nil
		end
	end
	if type(data.Progression) ~= "table" then
		data.Progression = {}
	end
	return data
end

-- Returns (data, changed). nil (a new player) gives the defaults.
-- Never call this with data where IsNewer(data) is true.
function Schema.Migrate(stored)
	if stored == nil then
		return Schema.Default(), true
	end
	assert(type(stored) == "table", "stored data must be a table")
	assert(not Schema.IsNewer(stored), "data is from a newer schema")
	local data = deepCopy(stored)
	local version = type(data.SchemaVersion) == "number" and data.SchemaVersion or 1
	while version < Schema.CURRENT do
		data = MIGRATIONS[version](data)
		version += 1
	end
	data.SchemaVersion = Schema.CURRENT
	return repair(data), version ~= stored.SchemaVersion
end

return Schema
