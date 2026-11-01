-- One owner for an already session-locked full player profile.
-- ALL profile mutations and saves must go through this coordinator after integration.
local Schema = require("./Schema")
local Transactions = require("./Transactions")
local Coordinator = {}
Coordinator.__index = Coordinator
function Coordinator.new(options)
    assert(options.Profile and options.Profile.Active, "Active locked profile required")
    assert(options.ProfileStore and options.RandomIndex and options.Context, "Missing server dependencies")
    assert(options.Profile.Data.SchemaVersion == Schema.CURRENT, "Migrate with candidate Schema before opening")
    return setmetatable({
        profile = options.Profile, store = options.ProfileStore,
        randomIndex = options.RandomIndex, context = options.Context,
        confirmed = Schema.DeepCopy(options.Profile.Data),
        busy = false, pending = nil, lost = false, closed = false,
    }, Coordinator)
end
function Coordinator:Status()
    if self.lost then return "SessionLost" end
    if self.closed then return "Closed" end
    if self.busy then return "Saving" end
    if self.pending then return "Pending" end
    if not self.profile.Active then return "Inactive" end
    return "Ready"
end
function Coordinator:Snapshot()
    local a = self.confirmed.Armory
    return {
        Status = self:Status(), Coins = a.Coins, Owned = Schema.DeepCopy(a.Owned),
        Selected = { Pistol = Transactions.Selection(self.confirmed, "Pistol"), Knife = Transactions.Selection(self.confirmed, "Knife") },
        NextSequence = a.LastSequence + 1,
        PendingSequence = self.pending and self.pending.request and self.pending.request.Sequence or nil,
    }
end
local function response(code)
    return { Code = code }
end
local function noYield(fn)
    local thread = coroutine.create(fn)
    local ok, a, b = coroutine.resume(thread)
    if coroutine.status(thread) ~= "dead" then
        coroutine.close(thread)
        return false, "Server mutator yielded"
    end
    return ok, a, b
end
local function sameRequest(a, b)
    return a and b and a.Sequence == b.Sequence and a.Action == b.Action and a.ItemId == b.ItemId
end
function Coordinator:_persist()
    assert(not self.busy and self.pending)
    self.busy = true
    local ok, status = pcall(function() return self.store:Save(self.profile, false) end)
    self.busy = false
    if ok and status == "Ok" then
        self.confirmed = Schema.DeepCopy(self.profile.Data)
        local result = Schema.DeepCopy(self.pending.result)
        self.pending = nil
        return result
    elseif ok and (status == "LostLock" or status == "Inactive") then
        self.lost = true
        return response("SessionLost")
    end
    -- Save may have committed before an acknowledgement was lost. Keep the exact
    -- working snapshot/roll, block mutations, and retry that snapshot unchanged.
    return response("Pending")
end
function Coordinator:_stage(working, result, request)
    self.profile.Data = working
    self.pending = { result = Schema.DeepCopy(result), request = request and Schema.DeepCopy(request) }
    return self:_persist()
end
function Coordinator:Transact(request)
    if not Transactions.ValidateRequest(request) then return response("InvalidRequest") end
    if self.busy then return response("Busy") end
    if self.lost or self.closed or not self.profile.Active then return response("Unavailable") end
    if self.pending then
        if sameRequest(self.pending.request, request) then return self:_persist() end
        return response("Pending")
    end
    local ok, working, result = noYield(function()
        return Transactions.Apply(self.confirmed, request, self.context(), self.randomIndex)
    end)
    if not ok then return response("InternalError") end
    if not working then return result end -- replay / malformed ordering: no save, no charge
    return self:_stage(working, result, request)
end
-- Trusted server caller only; never include this method in remote dispatch.
function Coordinator:Credit(source, event, amount)
    if self:Status() ~= "Ready" then return response("Unavailable") end
    local working, result = Transactions.Credit(self.confirmed, source, event, amount)
    if not working then return result end
    return self:_stage(working, result)
end
-- Preserve skin/progression writes through the SAME profile owner, instead of
-- letting the old DataService.Update race against a spending transaction.
function Coordinator:UpdateLegacy(mutator)
    if self:Status() ~= "Ready" then return response("Unavailable") end
    local working = Schema.DeepCopy(self.confirmed)
    local ok, changed = noYield(function() return mutator(working) end)
    if not ok then return response("InternalError") end
    if changed ~= true then return response("Unchanged") end
    -- The armory API is the exclusive owner of these fields.
    working.Armory = Schema.DeepCopy(self.confirmed.Armory)
    working.SchemaVersion = Schema.CURRENT
    return self:_stage(working, response("Updated"))
end
function Coordinator:RetryPending()
    if self.busy then return response("Busy") end
    if self.lost or self.closed or not self.profile.Active then return response("Unavailable") end
    if not self.pending then return response("NothingPending") end
    return self:_persist()
end
function Coordinator:Flush(release)
    if self.busy then return response("Busy") end
    if self.lost or self.closed or not self.profile.Active then return response("Unavailable") end
    if self.pending then
        local saved = self:_persist()
        if self.pending then return saved end
    end
    self.busy = true
    local ok, status = pcall(function() return self.store:Save(self.profile, release == true) end)
    self.busy = false
    if ok and status == "Ok" then
        if release then self.closed = true end
        return response("Saved")
    end
    if ok and (status == "LostLock" or status == "Inactive") then self.lost = true;return response("SessionLost") end
    return response("SaveFailed")
end
return Coordinator
