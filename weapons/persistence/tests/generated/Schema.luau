-- Candidate schema v2. Does not modify the installed schema or Studio.
local Schema = { CURRENT = 2 }
function Schema.DeepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Schema.DeepCopy(v) end
    return out
end
local function integer(value, low, high)
    return type(value) == "number" and value == value and value % 1 == 0 and value >= low and value <= high
end
function Schema.IsNewer(data)
    return type(data) == "table" and type(data.SchemaVersion) == "number" and data.SchemaVersion > Schema.CURRENT
end
local function freshArmory()
    return {
        Coins = 0, Owned = { Service1911 = true, BasicKnife = true },
        Selected = { Pistol = "Service1911", Knife = "BasicKnife" },
        LastSequence = 0, Receipts = {}, ReceiptOrder = {},
        CreditCursors = {},
    }
end
function Schema.Default()
    return { SchemaVersion = 2, Inventory = { Skins = {} }, Equipped = {}, Progression = {}, Armory = freshArmory() }
end
local function repairLegacy(data)
    if type(data.Inventory) ~= "table" then data.Inventory = {} end
    if type(data.Inventory.Skins) ~= "table" then data.Inventory.Skins = {} end
    for id, owned in pairs(data.Inventory.Skins) do
        if type(id) ~= "string" or owned ~= true then data.Inventory.Skins[id] = nil end
    end
    if type(data.Equipped) ~= "table" then data.Equipped = {} end
    for id, skin in pairs(data.Equipped) do
        if type(id) ~= "string" or type(skin) ~= "string" then data.Equipped[id] = nil end
    end
    if type(data.Progression) ~= "table" then data.Progression = {} end
end
local function validateArmory(a)
    -- Fail closed on corrupt currency/idempotency records; never reset them to zero.
    assert(type(a) == "table", "CorruptArmory")
    assert(integer(a.Coins, 0, 2147483647), "CorruptCoins")
    assert(integer(a.LastSequence, 0, 9007199254740990), "CorruptSequence")
    assert(type(a.Owned) == "table" and type(a.Selected) == "table", "CorruptOwnership")
    for id, value in pairs(a.Owned) do assert(type(id) == "string" and value == true, "CorruptOwnership") end
    for slot, id in pairs(a.Selected) do assert(type(slot) == "string" and type(id) == "string", "CorruptSelection") end
    assert(type(a.Receipts) == "table" and type(a.ReceiptOrder) == "table", "CorruptReceipts")
    assert(#a.ReceiptOrder <= 32, "CorruptReceiptLimit")
    local seen, previous = {}, 0
    for key in pairs(a.ReceiptOrder) do assert(integer(key, 1, #a.ReceiptOrder), "CorruptReceiptArray") end
    for index, sequence in ipairs(a.ReceiptOrder) do
        assert(integer(sequence, 1, a.LastSequence) and sequence > previous, "CorruptReceiptOrder")
        local key = tostring(sequence)
        local receipt = a.Receipts[key]
        assert(type(receipt) == "table" and receipt.Sequence == sequence and type(receipt.Action) == "string"
            and type(receipt.ItemId) == "string" and type(receipt.Result) == "table"
            and type(receipt.Result.Code) == "string" and type(receipt.Result.ItemId) == "string"
            and integer(receipt.Result.Cost, 0, 2147483647), "CorruptReceipt")
        seen[key] = true; previous = sequence
        assert(a.ReceiptOrder[index] == sequence)
    end
    for key in pairs(a.Receipts) do assert(seen[key], "OrphanReceipt") end
    assert(type(a.CreditCursors) == "table", "CorruptCreditCursors")
    for source, sequence in pairs(a.CreditCursors) do
        assert(type(source) == "string" and integer(sequence, 0, 9007199254740990), "CorruptCreditCursor")
    end
    a.Owned.Service1911 = true; a.Owned.BasicKnife = true
end
function Schema.Migrate(stored)
    if stored == nil then return Schema.Default(), true end
    assert(type(stored) == "table", "CorruptRecord")
    assert(not Schema.IsNewer(stored), "NewerSchema")
    local version = stored.SchemaVersion
    if version == nil then version = 1 end
    assert(integer(version, 1, Schema.CURRENT), "CorruptSchemaVersion")
    local data = Schema.DeepCopy(stored)
    repairLegacy(data)
    local changed = version ~= Schema.CURRENT
    if version == 1 then
        -- Armory did not exist in v1. Preserve an unexpected same-named field for review.
        assert(data.Armory == nil, "UnexpectedV1Armory")
        data.Armory = freshArmory()
        -- Existing players retain access to their old default knife.
        data.Armory.Owned.Karambit = true
        data.Armory.Selected.Knife = "Karambit"
    end
    data.SchemaVersion = Schema.CURRENT
    validateArmory(data.Armory)
    return data, changed
end
return Schema
