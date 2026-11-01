-- Transport-neutral adapter. It never trusts client prices, context or RNG.
local Transactions = require(script.Parent.Transactions)
local Router = {}
Router.__index = Router
function Router.new(options)
    assert(options.GetOwner and options.Now, "server owner lookup and clock required")
    return setmetatable({ getOwner = options.GetOwner, now = options.Now, last = {} }, Router)
end
function Router:Handle(player, action, request)
    if action ~= "Snapshot" and action ~= "Transact" then return { Code = "InvalidAction" } end
    local now = self.now()
    if self.last[player] and now - self.last[player] < 1 then return { Code = "RateLimited" } end
    self.last[player] = now
    local owner = self.getOwner(player)
    if not owner then return { Code = "DataUnavailable" } end
    if action == "Snapshot" then return { Code = "Snapshot", Snapshot = owner:Snapshot() } end
    if not Transactions.ValidateRequest(request) then return { Code = "InvalidRequest", Snapshot = owner:Snapshot() } end
    -- Drop all fields except the validated request identity.
    local result = owner:Transact({ Sequence = request.Sequence, Action = request.Action, ItemId = request.ItemId })
    return { Code = result.Code, Result = result, Snapshot = owner:Snapshot() }
end
function Router:Forget(player)
    self.last[player] = nil
end
return Router
