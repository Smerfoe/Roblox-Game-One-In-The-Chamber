local Schema = require("../Schema")
local T = require("../Transactions")
local Coordinator = require("../Coordinator")
local Router = require("../RequestRouter")
local OwnerAdapter = require("../OwnerAdapter")
local ProfileStore = require("./generated/ProfileStore")
local MemoryStore = require("./generated/MemoryStore")
local Config = require("./generated/DataConfig")
local ExistingTests = require("./generated/DataTests")
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed += 1; print("PASS " .. name)
    else failed += 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end
local function request(seq, action, id)
    return { Sequence = seq, Action = action, ItemId = id }
end
local function world(stored, customRandom)
    local w = { time = 1000, store = MemoryStore.new("offline"), rolls = 0 }
    if stored then w.store:Poke("u_1", {Data=stored}) end
    local function session(id)
        return ProfileStore.new({store=w.store, sessionId=id, config=Config,
            now=function() return w.time end, wait=function(s) w.time += s or 0 end})
    end
    w.session = session
    w.profileStore = session("A")
    local status, profile = w.profileStore:Load("u_1")
    assert(status == "Ok", status)
    w.profile = profile
    w.context = { InLobby = true, IsStudio = true }
    w.owner = Coordinator.new({Profile=profile, ProfileStore=w.profileStore,
        Context=function() return w.context end,
        RandomIndex=function(n) w.rolls += 1; return customRandom and customRandom(n) or 1 end})
    return w
end
local function grant(w, amount)
    assert(w.owner:Credit("AdminGrant",1,amount).Code == "Credited")
end
test("existing 13 persistence/session-lock regressions",function()
    local report, ok = ExistingTests.Run()
    print(report)
    assert(ok, "existing persistence regression failed")
end)
test("new accounts have zero coins and free pistol/basic knife",function()
    local d=Schema.Default()
    assert(d.Armory.Coins==0 and d.Armory.Owned.BasicKnife and d.Armory.Owned.Service1911)
    assert(not d.Armory.Owned.Karambit and d.Armory.Selected.Knife=="BasicKnife")
end)
test("v1 migration preserves skins, equipment and unrelated fields",function()
    local old={SchemaVersion=1,Inventory={Skins={rare=true},Custom={kept=true}},Equipped={Service1911="rare"},Progression={XP=500},Other={Hello="world"}}
    local d, changed=Schema.Migrate(old)
    assert(changed and d.SchemaVersion==2 and d.Inventory.Skins.rare and d.Inventory.Custom.kept)
    assert(d.Equipped.Service1911=="rare" and d.Progression.XP==500 and d.Other.Hello=="world")
    assert(d.Armory.Owned.Karambit and d.Armory.Selected.Knife=="Karambit")
    assert(old.SchemaVersion==1 and old.Armory==nil)
end)
test("repeated migration is idempotent and keeps unknown owned IDs",function()
    local d=Schema.Default();d.Armory.Owned.retired=true;d.Armory.Selected.Knife="retired"
    local again,changed=Schema.Migrate(d)
    assert(not changed and again.Armory.Owned.retired and again.Armory.Selected.Knife=="retired")
    assert(T.Selection(again,"Knife")=="BasicKnife")
end)
test("newer and malformed monetary records fail closed",function()
    assert(not pcall(Schema.Migrate,{SchemaVersion=3}))
    for _,value in { -1, 0/0, math.huge, 2.5, 2147483648, "100" } do
        local d=Schema.Default();d.Armory.Coins=value
        assert(not pcall(Schema.Migrate,d))
    end
    assert(not pcall(Schema.Migrate,{SchemaVersion=1,Armory={Coins=100}}))
end)
test("purchase saves ownership/deduction/receipt in one record",function()
    local w=world();grant(w,10000)
    assert(w.owner:Transact(request(1,"Buy","OldWestRevolver")).Code=="Purchased")
    local saved=w.store:Peek("u_1").Data.Armory
    assert(saved.Coins==7500 and saved.Owned.OldWestRevolver and saved.Receipts["1"].Result.Code=="Purchased")
end)
test("request replay across save/rejoin cannot charge twice",function()
    local w=world();grant(w,10000)
    local r=request(1,"Buy","OldWestRevolver")
    assert(w.owner:Transact(r).Code=="Purchased")
    assert(w.owner:Flush(true).Code=="Saved")
    local b=w.session("B");local status,p=b:Load("u_1");assert(status=="Ok")
    local owner=Coordinator.new({Profile=p,ProfileStore=b,Context=function()return w.context end,RandomIndex=function()error("must not roll")end})
    local writes=w.store.writes
    assert(owner:Transact(r).Code=="Purchased" and owner:Snapshot().Coins==7500)
    assert(w.store.writes==writes)
end)
test("same sequence with a different payload is rejected",function()
    local w=world();grant(w,10000)
    w.owner:Transact(request(1,"Buy","OldWestRevolver"))
    assert(w.owner:Transact(request(1,"Buy","HeavyEagle")).Code=="SequenceConflict")
    assert(w.owner:Snapshot().Coins==7500)
end)
test("out-of-order and malformed packets consume nothing",function()
    local w=world();local writes=w.store.writes
    for _,r in {request(0,"Buy","HeavyEagle"),request(0/0,"Buy","HeavyEagle"),request(math.huge,"Buy","HeavyEagle"),request(1.5,"Buy","HeavyEagle"),request(1,"Buy",string.rep("x",65))} do
        assert(w.owner:Transact(r).Code=="InvalidRequest")
    end
    assert(w.owner:Transact(request(2,"Buy","HeavyEagle")).Code=="OutOfOrder")
    assert(w.owner:Snapshot().NextSequence==1 and w.store.writes==writes)
end)
test("insufficient funds, unknown products and unowned equip are safe",function()
    local w=world()
    assert(w.owner:Transact(request(1,"Buy","HeavyEagle")).Code=="InsufficientCoins")
    assert(w.owner:Transact(request(2,"Buy","forged")).Code=="UnknownPurchase")
    assert(w.owner:Transact(request(3,"Equip","PythonMagnum")).Code=="NotOwned")
    assert(w.owner:Snapshot().Coins==0 and w.owner:Snapshot().Selected.Pistol=="Service1911")
end)
test("owned purchase doesn't charge; equip selection survives rejoin",function()
    local w=world();grant(w,10000)
    w.owner:Transact(request(1,"Buy","OldWestRevolver"))
    assert(w.owner:Transact(request(2,"Buy","OldWestRevolver")).Code=="AlreadyOwned")
    assert(w.owner:Transact(request(3,"Equip","OldWestRevolver")).Code=="Equipped")
    assert(w.owner:Flush(true).Code=="Saved")
    local status,p=w.session("B"):Load("u_1")
    assert(status=="Ok" and p.Data.Armory.Selected.Pistol=="OldWestRevolver" and p.Data.Armory.Coins==7500)
end)
test("crate roll is recorded once and duplicate has zero net cost",function()
    local w=world();grant(w,100)
    local first=w.owner:Transact(request(1,"Crate","TestBlades"))
    assert(first.Code=="Unboxed" and first.ItemId=="Karambit" and w.owner:Snapshot().Coins==90)
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).ItemId=="Karambit" and w.rolls==1)
    assert(w.owner:Transact(request(2,"Crate","TestBlades")).Code=="DuplicateRefund")
    assert(w.owner:Snapshot().Coins==90 and w.rolls==2)
end)
test("all crate buckets map to valid owned items",function()
    for index,id in {"Karambit","ButterflyKnife","Machete","TrailBowie"} do
        local w=world(nil,function()return index end);grant(w,10)
        local r=w.owner:Transact(request(1,"Crate","TestBlades"))
        assert(r.ItemId==id and w.owner:Snapshot().Owned[id] and w.owner:Snapshot().Coins==0)
    end
end)
test("live test crate stays disabled and client cannot forge context",function()
    local w=world();grant(w,100);w.context.IsStudio=false
    local r=request(1,"Crate","TestBlades");r.IsStudio=true;r.Price=0;r.Coins=999999
    assert(w.owner:Transact(r).Code=="CrateDisabled" and w.owner:Snapshot().Coins==100 and w.rolls==0)
end)
test("purchases outside lobby are refused",function()
    local w=world();grant(w,10000);w.context.InLobby=false
    assert(w.owner:Transact(request(1,"Buy","HeavyEagle")).Code=="ReturnToLobby")
    assert(w.owner:Snapshot().Coins==10000)
end)
test("save failure hides provisional reward and blocks more spending",function()
    local w=world();grant(w,100)
    w.store:SetFailAll(true)
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="Pending")
    local snap=w.owner:Snapshot()
    assert(snap.Status=="Pending" and snap.Coins==100 and not snap.Owned.Karambit)
    assert(w.owner:Transact(request(2,"Crate","TestBlades")).Code=="Pending" and w.rolls==1)
    assert(w.owner:UpdateLegacy(function(d)d.Equipped.Karambit="x";return true end).Code=="Unavailable")
    w.store:SetFailAll(false)
    assert(w.owner:RetryPending().Code=="Unboxed")
    assert(w.owner:Snapshot().Coins==90 and w.owner:Snapshot().Owned.Karambit and w.rolls==1)
end)
test("lost save acknowledgement retries same roll without double award",function()
    local w=world();grant(w,100)
    local original=w.store.UpdateAsync;local remaining=Config.SaveAttempts
    w.store.UpdateAsync=function(self,...)
        local value=original(self,...)
        if remaining>0 then remaining-=1;error("response lost AFTER commit") end
        return value
    end
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="Pending")
    assert(w.store:Peek("u_1").Data.Armory.Coins==90)
    assert(w.owner:Snapshot().Coins==100)
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="Unboxed")
    assert(w.owner:Snapshot().Coins==90 and w.rolls==1)
end)
test("crash after uncertain commit recovers receipt in new session",function()
    local w=world();grant(w,100)
    local original=w.store.UpdateAsync
    w.store.UpdateAsync=function(self,...) local value=original(self,...);error("response lost AFTER commit") end
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="Pending")
    w.store.UpdateAsync=original;w.time+=Config.LockStaleAfter+1
    local b=w.session("B");local status,p=b:Load("u_1");assert(status=="Ok")
    local owner=Coordinator.new({Profile=p,ProfileStore=b,Context=function()return w.context end,RandomIndex=function()error("reroll")end})
    assert(owner:Transact(request(1,"Crate","TestBlades")).Code=="Unboxed")
    assert(owner:Snapshot().Coins==90 and owner:Snapshot().Owned.Karambit)
    assert(w.owner:RetryPending().Code=="SessionLost")
end)
test("stale old session cannot overwrite new owner",function()
    local w=world();grant(w,10000);w.time+=Config.LockStaleAfter+1
    local b=w.session("B");local status,p=b:Load("u_1");assert(status=="Ok")
    p.Data.Progression.XP=777;assert(b:Save(p)=="Ok")
    assert(w.owner:Transact(request(1,"Buy","OldWestRevolver")).Code=="SessionLost")
    assert(w.store:Peek("u_1").Data.Progression.XP==777 and w.store:Peek("u_1").Data.Armory.Coins==10000)
end)
test("overlapping requests see Busy while save yields",function()
    local w=world();grant(w,10000);local observed
    w.store.onWait=function()
        if not observed then observed=w.owner:Transact(request(2,"Buy","HeavyEagle")).Code end
    end
    assert(w.owner:Transact(request(1,"Buy","OldWestRevolver")).Code=="Purchased")
    assert(observed=="Busy" and w.owner:Snapshot().Coins==7500)
end)
test("evicted old receipt cannot be charged or rerolled again",function()
    local w=world();grant(w,100)
    w.owner:Transact(request(1,"Crate","TestBlades"))
    for i=2,40 do w.owner:Transact(request(i,"Equip","BasicKnife")) end
    local writes=w.store.writes
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="ExpiredRequest")
    assert(w.owner:Snapshot().Coins==90 and w.rolls==1 and w.store.writes==writes)
    assert(#w.profile.Data.Armory.ReceiptOrder==32)
    assert(pcall(Schema.Migrate,w.profile.Data))
end)
test("trusted credits are ordered, bounded and replay safe",function()
    local w=world()
    assert(w.owner:Credit("Match",1,50).Code=="Credited")
    assert(w.owner:Credit("Match",1,5000).Code=="CreditAlreadyProcessed")
    assert(w.owner:Credit("Match",3,50).Code=="CreditOutOfOrder")
    assert(w.owner:Credit("unknown",1,50).Code=="InvalidCredit")
    assert(w.owner:Credit("Match",2,-50).Code=="InvalidCredit")
    assert(w.owner:Credit("Match",2,2147483647).Code=="CoinLimit")
    assert(w.owner:Snapshot().Coins==50)
end)
test("legacy skin mutation preserves currency, items and receipts",function()
    local w=world();grant(w,10000);w.owner:Transact(request(1,"Buy","OldWestRevolver"))
    assert(w.owner:UpdateLegacy(function(d)
        d.Inventory.Skins.rare=true;d.Equipped.Service1911="rare";d.Armory.Coins=999999;return true
    end).Code=="Updated")
    local saved=w.store:Peek("u_1").Data
    assert(saved.Inventory.Skins.rare and saved.Equipped.Service1911=="rare")
    assert(saved.Armory.Coins==7500 and saved.Armory.Owned.OldWestRevolver and saved.Armory.Receipts["1"])
end)
test("invalid server RNG never mutates data",function()
    local w=world(nil,function()return 99 end);grant(w,100)
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="InternalError")
    assert(w.owner:Snapshot().Coins==100 and w.owner:Snapshot().NextSequence==1)
end)
test("router rate limits, strips authority fields and cleans up",function()
    local w=world();grant(w,10000);local player={};local now=0
    local router=Router.new({GetOwner=function(p)return p==player and w.owner end,Now=function()return now end})
    local r=request(1,"Buy","OldWestRevolver");r.Price=0;r.Coins=999999
    local response=router:Handle(player,"Transact",r)
    assert(response.Code=="Purchased" and response.Snapshot.Coins==7500)
    assert(router:Handle(player,"Snapshot").Code=="RateLimited")
    now=1;assert(router:Handle(player,"Credit",{}).Code=="InvalidAction")
    assert(router:Handle({},"Snapshot").Code=="DataUnavailable")
    router:Forget(player);assert(router.last[player]==nil)
end)
test("yielding server RNG cannot create overlapping unsaved mutations",function()
    local w=world(nil,function()coroutine.yield();return 1 end);grant(w,100)
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="InternalError")
    assert(w.owner:Snapshot().Coins==100 and w.owner:Snapshot().NextSequence==1)
end)
test("yielding/throwing context or legacy callbacks fail closed",function()
    local w=world();grant(w,100)
    w.owner.context=function()error("bad context")end
    assert(w.owner:Transact(request(1,"Equip","BasicKnife")).Code=="InternalError")
    assert(w.owner:UpdateLegacy(function(d)d.Inventory.Skins.x=true;coroutine.yield();return true end).Code=="InternalError")
    assert(w.owner:Snapshot().Status=="Ready" and w.owner.confirmed.Inventory.Skins.x==nil)
end)
test("failed load and malformed monetary record cannot become defaults",function()
    local store=MemoryStore.new("down");store:SetFailAll(true)
    local p=ProfileStore.new({store=store,sessionId="A",config=Config,now=function()return 1 end,wait=function()end})
    local status,profile=p:Load("u_1")
    assert(status=="Failed" and type(profile)=="string" and store.writes==0)
    store:SetFailAll(false);local bad=Schema.Default();bad.Armory.Coins=-9
    store:Poke("u_1",{Data=bad});status=p:Load("u_1")
    assert(status=="Failed" and store:Peek("u_1").Data.Armory.Coins==-9 and store.writes==0)
end)
test("pending award flushes before releasing profile on leave",function()
    local w=world();grant(w,100);w.store:SetFailAll(true)
    assert(w.owner:Transact(request(1,"Crate","TestBlades")).Code=="Pending")
    w.store:SetFailAll(false)
    assert(w.owner:Flush(true).Code=="Saved")
    local saved=w.store:Peek("u_1")
    assert(saved.Lock==nil and saved.Data.Armory.Coins==90 and saved.Data.Armory.Owned.Karambit)
    assert(w.owner:Snapshot().Status=="Closed" and w.owner:Transact(request(2,"Equip","Karambit")).Code=="Unavailable")
end)
test("credit after lost acknowledgement survives crash without a second credit",function()
    local w=world();local original=w.store.UpdateAsync
    w.store.UpdateAsync=function(self,...)local v=original(self,...);error("after commit")end
    assert(w.owner:Credit("Match",1,50).Code=="Pending")
    w.store.UpdateAsync=original;w.time+=Config.LockStaleAfter+1
    local b=w.session("B");local status,p=b:Load("u_1");assert(status=="Ok")
    local owner=Coordinator.new({Profile=p,ProfileStore=b,Context=function()return w.context end,RandomIndex=function()return 1 end})
    assert(owner:Credit("Match",1,5000).Code=="CreditAlreadyProcessed" and owner:Snapshot().Coins==50)
end)
test("owner adapter exposes confirmed data and publishes pending/recovery",function()
    local w=world();local statuses={}
    local adapter=OwnerAdapter.new({Profile=w.profile,ProfileStore=w.profileStore,Context=function()return w.context end,
        RandomIndex=function()return 1 end,Changed=function(status)table.insert(statuses,status)end})
    assert(adapter:GetOwner():Credit("AdminGrant",1,10000).Code=="Credited")
    w.store:SetFailAll(true)
    assert(adapter:Transact(request(1,"Buy","OldWestRevolver")).Code=="Pending")
    assert(adapter:GetStatus()=="Pending" and adapter:GetData().Armory.Coins==10000)
    w.store:SetFailAll(false);assert(adapter:RetryPending().Code=="Purchased")
    assert(statuses[1]=="Pending" and statuses[2]=="Ready" and adapter:GetData().Armory.Coins==7500)
    local copy=adapter:GetData();copy.Armory.Coins=1
    assert(adapter:GetData().Armory.Coins==7500)
end)
test("randomized transaction history conserves coins and never loses ownership",function()
    local seed=991
    local function nextIndex(n)seed=(seed*48271)%2147483647;return seed%n+1 end
    local w=world(nil,nextIndex);grant(w,250000)
    local items={"OldWestRevolver","HeavyEagle","PythonMagnum","FrontierRepeater","BasicKnife","Karambit","forged"}
    for sequence=1,250 do
        local before=w.owner:Snapshot()
        local action=({"Buy","Equip","Crate"})[nextIndex(3)]
        local id=action=="Crate" and "TestBlades" or items[nextIndex(#items)]
        local r=request(sequence,action,id)
        local receipt=w.owner:Transact(r)
        local after=w.owner:Snapshot()
        assert(after.Status=="Ready" and before.Coins-after.Coins==receipt.Cost)
        for owned in before.Owned do assert(after.Owned[owned]) end
        local rolls=w.rolls;local writes=w.store.writes
        assert(w.owner:Transact(r).Code==receipt.Code and w.owner:Snapshot().Coins==after.Coins)
        assert(w.rolls==rolls and w.store.writes==writes)
        assert(pcall(Schema.Migrate,w.profile.Data))
    end
end)
test("request router and owner adapter integrate without a second profile writer",function()
    local w=world();local published=0;local player={};local now=0
    local adapter=OwnerAdapter.new({Profile=w.profile,ProfileStore=w.profileStore,Context=function()return w.context end,
        RandomIndex=function()return 1 end,Changed=function()published+=1 end})
    assert(adapter:Credit("AdminGrant",1,10000).Code=="Credited")
    local router=Router.new({GetOwner=function()return adapter end,Now=function()return now end})
    assert(router:Handle(player,"Snapshot").Snapshot.Coins==10000)
    now=1
    local r=router:Handle(player,"Transact",request(1,"Buy","OldWestRevolver"))
    assert(r.Code=="Purchased" and r.Snapshot.Coins==7500 and published==2)
end)
print(string.format("ARMORY SUITE: %d passed, %d failed",passed,failed))
assert(failed==0,"Armory tests failed")
