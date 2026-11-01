-- Immediate local presentation; confirmed shot path and hit feedback stay server-owned.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Tween=game:GetService("TweenService")
local Content=game:GetService("ContentProvider")
local Effects=require(RS.Shared.PolishEffects)
local VM=require(script.Parent.ViewmodelController)
local player=Players.LocalPlayer
local Controller={}
local predicted={Shot=0,Swing=0}
function Controller.Predict(kind,id)
 predicted[kind]=id
 VM.PredictAttack(kind,id)
 Effects.Sound(kind,workspace.CurrentCamera)
 if kind=="Shot" then local m=VM.GetViewmodel();Effects.Muzzle(m and m:FindFirstChild("Muzzle",true)) end
end
function Controller.Start()
 task.spawn(function()
  local sounds={}
  for _,def in require(RS.Shared.Config.PolishConfig).Sounds do
   local s=Instance.new("Sound");s.SoundId=def.Id;table.insert(sounds,s)
  end
  pcall(function() Content:PreloadAsync(sounds) end)
  for _,s in sounds do s:Destroy() end
 end)
 local gui=Instance.new("ScreenGui");gui.Name="ConfirmedHitFeedback";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=20;gui.Parent=player:WaitForChild("PlayerGui")
 local mark=Instance.new("TextLabel");mark.Name="HitMarker";mark.AnchorPoint=Vector2.new(0.5,0.5);mark.Position=UDim2.fromScale(0.5,0.5);mark.Size=UDim2.fromOffset(36,36);mark.BackgroundTransparency=1;mark.Font=Enum.Font.GothamBold;mark.TextSize=28;mark.Text="×";mark.TextTransparency=1;mark.Parent=gui
 local fade
 RS.Remotes:WaitForChild("HitFeedback").OnClientEvent:Connect(function(kind)
  if kind~="Hit" and kind~="Elimination" then return end
  if fade then fade:Cancel() end
  mark.TextColor3=kind=="Elimination" and Color3.fromRGB(255,94,81) or Color3.new(1,1,1)
  mark.TextTransparency=0
  fade=Tween:Create(mark,TweenInfo.new(0.3),{TextTransparency=1});fade:Play()
 end)
 RS.Remotes:WaitForChild("PolishEffect").OnClientEvent:Connect(function(character,kind,endpoint,hit,requestId)
  if not character or not character.Parent then return end
  local own=character==player.Character
  local model=own and VM.GetViewmodel() or character:FindFirstChildOfClass("Tool")
  local root=character:FindFirstChild("HumanoidRootPart")
  local already=own and type(requestId)=="number" and requestId<=(predicted[kind] or 0)
  if kind=="Shot" then
   Effects.Shot(model and model:FindFirstChild("Muzzle",true),endpoint,hit,already)
   if not already then Effects.Sound("Shot",own and workspace.CurrentCamera or root) end
  elseif kind=="Swing" and not already then
   Effects.Sound("Swing",own and workspace.CurrentCamera or root)
  end
 end)
end
return Controller