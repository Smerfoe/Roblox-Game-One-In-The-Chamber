local Run=game:GetService("RunService")
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local C=require(RS.Shared.Config.ArmoryCatalog)
local Controller={}
function Controller.Start()
 if not Run:IsStudio() then return end
 local p=Players.LocalPlayer;local remote=RS.Remotes:WaitForChild("DevArmory")
 local gui=Instance.new("ScreenGui");gui.Name="DevArmoryGui";gui.ResetOnSpawn=false;gui.DisplayOrder=35;gui.Parent=p:WaitForChild("PlayerGui")
 local function label(parent,text,pos,size)
  local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Text=text;t.TextColor3=Color3.fromRGB(225,231,237);t.TextSize=16;t.Font=Enum.Font.Gotham;t.TextWrapped=true;t.Position=pos;t.Size=size;t.Parent=parent;return t
 end
 local function button(parent,text,pos,size,callback)
  local b=Instance.new("TextButton");b.BackgroundColor3=Color3.fromRGB(38,59,74);b.TextColor3=Color3.new(1,1,1);b.Text=text;b.TextSize=15;b.Font=Enum.Font.Gotham;b.Position=pos;b.Size=size;b.Parent=parent;b.Activated:Connect(callback);return b
 end
 local panel=Instance.new("Frame");panel.Name="Panel";panel.Size=UDim2.fromOffset(520,540);panel.AnchorPoint=Vector2.new(0.5,0.5);panel.Position=UDim2.fromScale(0.5,0.5);panel.BackgroundColor3=Color3.fromRGB(17,23,30);panel.Visible=false;panel.Parent=gui
 label(panel,"TEST ARMORY — Studio session only",UDim2.fromOffset(16,10),UDim2.new(1,-70,0,28))
 local balance=label(panel,"",UDim2.fromOffset(16,42),UDim2.new(1,-32,0,28))
 local message=label(panel,"",UDim2.fromOffset(16,455),UDim2.new(1,-32,0,68))
 local buttons={};local state;local requestId=0;local pending=false
 local refresh
 local function send(action,id)
  if pending then return end;pending=true;requestId+=1
  local ok,result=pcall(function() return remote:InvokeServer(action,requestId,id) end)
  pending=false
  if ok and type(result)=="table" then state=result;refresh() else message.Text="Armory unavailable — try again" end
 end
 refresh=function()
  balance.Text=string.format("%d test coins • resets when testing stops",state.Coins)
  message.Text=state.Message or "Choose weapons here, then enter practice."
  for id,b in buttons do
   local item=C[id];local selected=state.Selected[item.Slot]==id
   b.Text=item.Name.." — "..(selected and "SELECTED" or state.Owned[id] and "EQUIP" or item.Crate and "CRATE ONLY" or tostring(item.Price).." coins")
  end
 end
 local ids={};for id in C do table.insert(ids,id) end
 table.sort(ids,function(a,b) if C[a].Slot~=C[b].Slot then return C[a].Slot>C[b].Slot end return (C[a].Price or 0)<(C[b].Price or 0) or ((C[a].Price or 0)==(C[b].Price or 0) and a<b) end)
 for i,id in ids do buttons[id]=button(panel,"",UDim2.fromOffset(16,80+(i-1)*29),UDim2.new(1,-32,0,26),function()
  if state.Owned[id] then send("Equip",id) elseif not C[id].Crate then send("Buy",id) end
 end) end
 button(panel,"OPEN TEST CRATE — 10 coins",UDim2.fromOffset(16,380),UDim2.new(1,-32,0,32),function() send("Crate") end)
 label(panel,"25% each: Karambit • Butterfly • Machete • Bowie\nDuplicates refund all 10 test coins",UDim2.fromOffset(16,416),UDim2.new(1,-32,0,38))
 button(panel,"X",UDim2.new(1,-45,0,10),UDim2.fromOffset(30,28),function() panel.Visible=false end)
 local open=button(gui,"TEST ARMORY",UDim2.new(0,16,1,-52),UDim2.fromOffset(150,36),function() panel.Visible=not panel.Visible;if panel.Visible then send("Get") end end)
 local function visibility() open.Visible=p:GetAttribute("Location")=="Lobby";if not open.Visible then panel.Visible=false end end
 p:GetAttributeChangedSignal("Location"):Connect(visibility);visibility()
end
return Controller
