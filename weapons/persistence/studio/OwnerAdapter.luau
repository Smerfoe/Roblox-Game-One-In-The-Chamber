-- Candidate DataService integration seam. Requires a single existing profile owner.
-- This module does not create a DataStore, acquire another lock or start remotes.
local Schema = require(script.Parent.Schema)
local Coordinator = require(script.Parent.Coordinator)
local Adapter = {}
Adapter.__index = Adapter
function Adapter.new(options)
    assert(options.Changed, "Inject the existing DataService changed publisher")
    local owner = Coordinator.new(options)
    return setmetatable({ owner = owner, changed = options.Changed }, Adapter)
end
function Adapter:GetOwner()
    return self.owner
end
function Adapter:GetStatus()
    return self.owner:Status()
end
function Adapter:Snapshot()
    return self.owner:Snapshot()
end
function Adapter:GetData()
    return Schema.DeepCopy(self.owner.confirmed)
end
function Adapter:Update(mutator)
    local result = self.owner:UpdateLegacy(mutator)
    self.changed(self.owner:Status())
    return result -- caller must handle Pending; do not convert it to success
end
function Adapter:Transact(request)
    local result = self.owner:Transact(request)
    self.changed(self.owner:Status())
    return result
end
-- Trusted server code only; RequestRouter does not dispatch this method.
function Adapter:Credit(source, event, amount)
    local result = self.owner:Credit(source, event, amount)
    self.changed(self.owner:Status())
    return result
end
function Adapter:RetryPending()
    local result = self.owner:RetryPending()
    self.changed(self.owner:Status())
    return result
end
function Adapter:Save(release)
    local result = self.owner:Flush(release)
    self.changed(self.owner:Status())
    return result
end
return Adapter
