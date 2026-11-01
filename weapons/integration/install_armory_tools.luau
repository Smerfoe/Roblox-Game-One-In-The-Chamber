-- Run in Edit mode after importing models into ServerStorage.WeaponExpansionStaging
-- and installing ArmoryCatalog at ReplicatedStorage.Shared.Config.
assert(not game:GetService("RunService"):IsRunning(),"Stop play first")
local RS=game:GetService("ReplicatedStorage")
assert(not RS.Assets:FindFirstChild("ArmoryTools"),"ArmoryTools already exists")
local folder=Instance.new("Folder");folder.Name="ArmoryTools"
local C=require(RS.Shared.Config.ArmoryCatalog)
local kinds={OldWestRevolver="OldWest",HeavyEagle="HeavyPistol",PythonMagnum="Revolver",FrontierRepeater="Repeater",ButterflyKnife="Butterfly",Machete="Machete",TrailBowie="Bowie",BasicKnife="ButterKnife"}
for id,def in C do
 if def.Model then
  local model=game.ServerStorage.WeaponExpansionStaging[def.Model]:Clone()
  local anchor=model.PrimaryPart
  local tool=Instance.new("Tool");tool.Name=id;tool.RequiresHandle=true;tool.CanBeDropped=false
  for _,v in model:GetChildren() do v.Parent=tool end
  model:Destroy();anchor.Name="Handle"
  local grip=Instance.new("Attachment");grip.Name="Grip";grip.Parent=anchor
  local minZ=0
  for _,v in tool:GetDescendants() do
   if v:IsA("BasePart") then
    v.Anchored=false;v.Massless=true;v.CanCollide=false;v.CanQuery=false;v.CanTouch=false
    minZ=math.min(minZ,v.Position.Z-v.Size.Z/2)
   end
  end
  if def.Slot=="Pistol" then
   local muzzle=Instance.new("Attachment");muzzle.Name="Muzzle";muzzle.Position=Vector3.new(0,0.4,minZ);muzzle.Parent=anchor
  end
  tool:SetAttribute("ArmoryId",id);tool:SetAttribute("ArmoryKind",kinds[id]);tool.Parent=folder
 end
end
folder.Parent=RS.Assets
print("Installed",#folder:GetChildren(),"additional armory Tools")
