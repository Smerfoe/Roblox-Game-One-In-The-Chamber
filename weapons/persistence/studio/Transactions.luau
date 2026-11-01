-- Pure domain rules. Server owns context and RNG; never feed either from a remote.
local Schema = require(script.Parent.Schema)
local Catalog = require(script.Parent.Catalog)
local T = {}
local function integer(n, low, high)
    return type(n) == "number" and n == n and n % 1 == 0 and n >= low and n <= high
end
local function result(code, item, cost)
    return { Code = code, ItemId = item or "", Cost = cost or 0 }
end
function T.ValidateRequest(request)
    return type(request) == "table" and integer(request.Sequence, 1, 9007199254740990)
        and type(request.Action) == "string" and #request.Action <= 16
        and type(request.ItemId) == "string" and #request.ItemId <= 64
end
function T.Replay(data, request)
    local a = data.Armory
    if request.Sequence > a.LastSequence then return nil end
    local old = a.Receipts[tostring(request.Sequence)]
    if not old then return result("ExpiredRequest") end
    if old.Action ~= request.Action or old.ItemId ~= request.ItemId then return result("SequenceConflict") end
    return Schema.DeepCopy(old.Result)
end
local function perform(a, request, context, randomIndex)
    local action, id = request.Action, request.ItemId
    if context.InLobby ~= true then return result("ReturnToLobby") end
    if action == "Buy" then
        local item = Catalog.Items[id]
        if not item or item.Slot ~= "Pistol" or item.Price == nil then return result("UnknownPurchase") end
        if a.Owned[id] then return result("AlreadyOwned", id) end
        if a.Coins < item.Price then return result("InsufficientCoins") end
        a.Coins = a.Coins - item.Price; a.Owned[id] = true
        return result("Purchased", id, item.Price)
    elseif action == "Equip" then
        local item = Catalog.Items[id]
        if not item then return result("UnknownItem") end
        if not a.Owned[id] then return result("NotOwned") end
        a.Selected[item.Slot] = id
        return result("Equipped", id)
    elseif action == "Crate" then
        local crate = Catalog.Crates[id]
        if not crate then return result("UnknownCrate") end
        if crate.StudioOnly and context.IsStudio ~= true then return result("CrateDisabled") end
        if a.Coins < crate.Price then return result("InsufficientCoins") end
        local index = randomIndex(#crate.Items)
        assert(integer(index, 1, #crate.Items), "InvalidServerRoll")
        local won = crate.Items[index]
        if a.Owned[won] then return result("DuplicateRefund", won, 0) end
        a.Coins = a.Coins - crate.Price; a.Owned[won] = true
        return result("Unboxed", won, crate.Price)
    end
    return result("UnknownAction")
end
function T.Apply(data, request, context, randomIndex)
    if not T.ValidateRequest(request) then return nil, result("InvalidRequest") end
    local replay = T.Replay(data, request)
    if replay then return nil, replay end
    if request.Sequence ~= data.Armory.LastSequence + 1 then return nil, result("OutOfOrder") end
    local working = Schema.DeepCopy(data)
    local receipt = perform(working.Armory, request, context, randomIndex)
    local a = working.Armory
    a.LastSequence = request.Sequence
    a.Receipts[tostring(request.Sequence)] = {
        Sequence = request.Sequence, Action = request.Action, ItemId = request.ItemId, Result = receipt,
    }
    table.insert(a.ReceiptOrder, request.Sequence)
    if #a.ReceiptOrder > Catalog.ReceiptLimit then
        a.Receipts[tostring(table.remove(a.ReceiptOrder, 1))] = nil
    end
    return working, Schema.DeepCopy(receipt)
end
-- Server-only award API. Cursor must be a durable, ordered event number per source.
-- Do not expose this as a remote or derive source/amount/event from client data.
function T.Credit(data, source, event, amount)
    if not Catalog.CreditSources[source] or not integer(event, 1, 9007199254740990)
        or not integer(amount, 1, Catalog.MaxCoins) then return nil, result("InvalidCredit") end
    local previous = data.Armory.CreditCursors[source] or 0
    if event <= previous then return nil, result("CreditAlreadyProcessed") end
    if event ~= previous + 1 then return nil, result("CreditOutOfOrder") end
    if data.Armory.Coins > Catalog.MaxCoins - amount then return nil, result("CoinLimit") end
    local working = Schema.DeepCopy(data)
    working.Armory.Coins = working.Armory.Coins + amount
    working.Armory.CreditCursors[source] = event
    return working, result("Credited", source, -amount)
end
function T.Selection(data, slot)
    local id = data.Armory.Selected[slot]
    local item = Catalog.Items[id]
    if item and item.Slot == slot and data.Armory.Owned[id] then return id end
    return slot == "Pistol" and "Service1911" or slot == "Knife" and "BasicKnife" or nil
end
return T
