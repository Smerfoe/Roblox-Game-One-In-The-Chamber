-- Studio-only session economy. No saved currency or live purchases.
local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local C=require(RS.Shared.Config.ArmoryCatalog)
local Service={}
local states={}
local rng=Random.new()
local function fresh()
 return {Coins=125000,Owned={Service1911=true,BasicKnife=true},Selected={Pistol="Service1911",Knife="BasicKnife"},Cache={},Order={},Last=-math.huge}
end
local function snapshot(p,s,message)
 for slot,id in s.Selected do p:SetAttribute("DevWeapon_"..slot,id) end
 local copy={Coins=s.Coins,Owned={},Selected={},Message=message}
 for id,v in s.Owned do copy.Owned[id]=v end
 for slot,id in s.Selected do copy.Selected[slot]=id end
 return copy
end
local function transact(s,action,id)
 if action=="Buy" then
  local item=type(id)=="string" and C[id]
  if not item or item.Slot~="Pistol" or type(item.Price)~="number" then return "Unknown purchase" end
  if s.Owned[id] then return "Already owned" end
  if s.Coins<item.Price then return "Not enough test coins" end
  s.Coins-=item.Price; s.Owned[id]=true
  return "Purchased "..item.Name
 elseif action=="Equip" then
  local item=type(id)=="string" and C[id]
  if not item or not s.Owned[id] then return "Item is not owned" end
  s.Selected[item.Slot]=id
  return "Selected "..item.Name.." — used on your next practice entry or round"
 elseif action=="Crate" then
  if s.Coins<10 then return "Not enough test coins" end
  local pool={};for key,item in C do if item.Crate then table.insert(pool,key) end end;table.sort(pool)
  local won=pool[rng:NextInteger(1,#pool)]
  s.Coins-=10
  if s.Owned[won] then s.Coins+=10;return "Duplicate "..C[won].Name.." — 10 test coins refunded" end
  s.Owned[won]=true
  return "Unboxed "..C[won].Name
 end
 return "Unknown action"
end
local function request(p,action,requestId,id)
 local s=states[p];if not s then s=fresh();states[p]=s end
 if action=="Get" then return snapshot(p,s) end
 if type(requestId)~="number" or requestId%1~=0 or requestId<1 or requestId>2^31 then return snapshot(p,s,"Invalid request") end
 -- A high-water mark blocks replay even after the bounded result cache expires.
 if s.Cache[requestId] then return snapshot(p,s,s.Cache[requestId]) end
 if requestId<=(s.Highest or 0) then return snapshot(p,s,"Old request ignored") end
 local now=os.clock()
 if now-s.Last<0.25 then return snapshot(p,s,"Please wait") end
 s.Last=now;s.Highest=requestId
 local message
 if p:GetAttribute("Location")~="Lobby" or p:GetAttribute("InMatch") or p:GetAttribute("MatchId")~=nil then message="Return to the lobby first"
 else message=transact(s,action,id) end
 s.Cache[requestId]=message;table.insert(s.Order,requestId)
 if #s.Order>32 then s.Cache[table.remove(s.Order,1)]=nil end
 return snapshot(p,s,message)
end
function Service.Start()
 if not Run:IsStudio() then return end
 local remote=RS.Remotes:FindFirstChild("DevArmory") or Instance.new("RemoteFunction")
 remote.Name="DevArmory";remote.Parent=RS.Remotes;remote.OnServerInvoke=request
 local function added(p) local s=fresh();states[p]=s;snapshot(p,s) end
 Players.PlayerAdded:Connect(added);for _,p in Players:GetPlayers() do added(p) end
 Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
 -- Tests call the same transaction logic without touching player profiles.
 local hook=Instance.new("BindableFunction");hook.Name="DevArmoryTest"
 hook.OnInvoke=function(action,...)
  if action=="Fresh" then return fresh() end
  if action=="Transact" then return transact(...) end
  if action=="Request" then return request(...) end
 end
 hook.Parent=game.ServerStorage
end
return Service
