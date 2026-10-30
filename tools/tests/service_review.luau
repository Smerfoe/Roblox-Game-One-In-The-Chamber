-- Deterministic service regression harness. Roblox services/remotes are mocked.
local clock, scheduled = 0, {}
local function schedule(at, thread, args) table.insert(scheduled, {at=at, thread=thread, args=args or {}}) end
local task = {}
function task.spawn(fn, ...) schedule(clock, coroutine.create(fn), {...}) end
function task.delay(delay, fn, ...) schedule(clock+delay, coroutine.create(fn), {...}) end
function task.wait(delay) return coroutine.yield(delay or .01) end
local os = {clock=function() return clock end,time=function() return 1000+math.floor(clock) end}
local function run(duration)
 local target=clock+duration;local steps=0
 while true do
  table.sort(scheduled,function(a,b)return a.at<b.at end)
  local item=scheduled[1]
  if not item or item.at>target then break end
  table.remove(scheduled,1);clock=item.at;steps+=1;assert(steps<30000,'scheduler stuck')
  local ok,delay=coroutine.resume(item.thread,table.unpack(item.args));assert(ok,delay)
  if coroutine.status(item.thread)~='dead' then schedule(clock+(delay or .01),item.thread) end
 end
 clock=target
end
local function signal()
 local callbacks={}
 return {Connect=function(_,fn)table.insert(callbacks,fn);return {Disconnect=function()end} end,
 Fire=function(_,...)for _,fn in callbacks do task.spawn(fn,...)end end}
end
local function object(kind)
 local t={ClassName=kind}
 if kind=='BindableEvent' then t.Event=signal();t.Fire=function(_,...)t.Event:Fire(...)end end
 return t
end
local Instance={new=object}
local warn=function()end
local print=print
local Enum={Material={}}
for _,key in {'Metal','SmoothPlastic','Plastic','CorrodedMetal'} do Enum.Material[key]=table.freeze({EnumType=Enum.Material,Name=key}) end
local Color3={fromRGB=function(...)return {...}end}
local function typeof(value)return type(value)end
local factories,loaded={},{}
local require
require=function(name)
 if loaded[name]==nil then assert(factories[name],name);loaded[name]=factories[name]() end
 return loaded[name]
end
local players={PlayerAdded=signal(),PlayerRemoving=signal(),list={}}
function players:GetPlayers()return table.clone(self.list)end
function players:GetPlayerByUserId(id)for _,p in self.list do if p.UserId==id then return p end end end
local function player(id)
 local p={UserId=id,Name='Test'..id,attrs={},Parent=players}
 function p:SetAttribute(k,v)self.attrs[k]=v end
 function p:GetAttribute(k)return self.attrs[k]end
 return p
end
function players:add(p)table.insert(self.list,p);p.Parent=self;self.PlayerAdded:Fire(p)end
function players:remove(p)
 p.Parent=nil
 for i,v in self.list do if v==p then table.remove(self.list,i);break end end
 self.PlayerRemoving:Fire(p)
end
local db={values={},holdNext=false,gate=false,calls=0}
function db:GetAsync()return nil end
function db:UpdateAsync(key, transform)
 self.calls+=1;task.wait(.01)
 local result=transform(require('Schema').DeepCopy(self.values[key]))
 if result~=nil then self.values[key]=require('Schema').DeepCopy(result)end
 if self.holdNext then
  self.holdNext=false
  while self.gate do task.wait(.01)end
 end
 return result
end
local guids=0
local remotes={}
function remotes:FindFirstChild(name)return self[name]end
local inventoryRemote={OnServerEvent=signal(),messages={}}
function inventoryRemote:FireClient(p,...)table.insert(self.messages,{player=p,args={...}})end
remotes.Inventory=inventoryRemote
local dataFolder={DataConfig='DataConfig',Schema='Schema',ProfileStore='ProfileStore',MemoryStore='MemoryStore'}
local shared={Config={SkinCatalog='SkinCatalog'},SkinAppearance='SkinAppearance',PlayerState='PlayerState'}
local serverScripts={WaitForChild=function()return dataFolder end}
local services={Players=players,ReplicatedStorage={Shared=shared,Remotes=remotes},ServerScriptService=serverScripts,
 ServerStorage={},RunService={IsStudio=function()return true end},
 HttpService={GenerateGUID=function()guids+=1;return 'server-'..guids end,JSONEncode=function()return 'mock' end},
 DataStoreService={GetDataStore=function(_,name)assert(name=='OITC_PlayerData_STUDIO_v1','production store used');return db end}}
local close
local game={GetService=function(_,name)assert(services[name],name);return services[name]end,BindToClose=function(_,fn)close=fn end}
-- MODULES_INSERTED_HERE
local data=require('DataService');local inventory=require('InventoryService')
data.Start();inventory.Start()
local p=player(1);players:add(p);run(.1)
assert(data.IsReady(p),'initial load')
data.DevGrantSkin(p,'service1911.slate');data.DevGrantSkin(p,'service1911.desert');run(.1)
local function request(id,weapon,skin)
 inventoryRemote.OnServerEvent:Fire(p,'Equip',id,weapon,skin);run(.01)
end
request(1,'Service1911','service1911.slate')
assert(data.Get(p).Equipped.Service1911=='service1911.slate','owned skin equip')
run(.3);p:SetAttribute('MatchId',12);p:SetAttribute('InMatch',false)
request(2,'Service1911','service1911.desert')
assert(data.Get(p).Equipped.Service1911=='service1911.slate','spectator/between-round equip must be refused')
p:SetAttribute('MatchId',nil);run(.3);p:SetAttribute('Location','Practice')
request(3,'Service1911','service1911.desert')
assert(data.Get(p).Equipped.Service1911=='service1911.slate','practice equip blocked')
p:SetAttribute('Location','Lobby');run(.3)
request(4,'Service1911','service1911.crimson')
assert(data.Get(p).Equipped.Service1911=='service1911.slate','unowned equip blocked')
run(.3);request(5,'Service1911','karambit.ivory')
assert(data.Get(p).Equipped.Service1911=='service1911.slate','wrong weapon blocked')
run(.3);local count=#inventoryRemote.messages
for i=1,1000 do inventoryRemote.OnServerEvent:Fire(p,'Equip',i,{}, {}) end
run(.01)
assert(#inventoryRemote.messages-count<=2,'malformed request replies must be bounded')
print('PASS inventory: ownership, compatibility, practice, inactive match participant, malformed-request reply budget')
-- A leaving profile is still being saved. A replacement player leaves while
-- waiting for that write. Releasing the old write must not load the departed one.
db.gate=true;db.holdNext=true
players:remove(p);run(.03)
assert(not data.Update(p,function(record)record.Equipped.Service1911='service1911.desert';return true end),'closing profile must reject mutations')
local departed=player(1);players:add(departed);run(.03);players:remove(departed);run(.03)
db.gate=false;run(.3)
assert(not data.IsReady(departed),'departed waiter was loaded and retained')
assert(departed:GetAttribute('DataStatus')==nil,'departed waiter started loading')
assert(db.values.u_1.Lock==nil,'departed waiter reacquired the lock')
local current=player(1);players:add(current);run(.1)
assert(data.IsReady(current),'new join after release')
assert(data.Get(current).Equipped.Service1911=='service1911.slate','saved selection survives')
print('PASS lifecycle: departing while waiting for release does not acquire a profile; real replacement loads saved data')
-- Disconnect while a load response is held; eventual cleanup must release it.
local late=player(2);db.gate=true;db.holdNext=true;players:add(late);run(.03)
players:remove(late);run(.03);db.gate=false;run(.2)
assert(not data.IsReady(late) and db.values.u_2.Lock==nil,'late load must be cleaned up')
print('PASS lifecycle: departing during a load response releases its own acquisition')
-- Shutdown overlaps a leave-save and must wait for it.
db.gate=true;db.holdNext=true;players:remove(current);run(.03)
local closed=false;task.spawn(function()close();closed=true end);run(.05)
assert(not closed,'shutdown finished before an existing leave-save')
db.gate=false;run(.3)
assert(closed and db.values.u_1.Lock==nil,'shutdown waited and released')
print('PASS lifecycle: shutdown waits for overlapping leave-save')
print('All service regression scenarios passed (mock services; not Roblox Studio).')
