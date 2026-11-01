-- ViewmodelController: the weapon you see in first person.
-- While a weapon is equipped and the player is InMatch, a local-only copy of the
-- weapon's parts follows the camera. The real Tool (which other players see in
-- your hand) is hidden for you only. Everything is removed on unequip or death.
--
-- Animations play only on server cues and are computed from the time since the
-- cue, never added on top of the previous frame, so the weapon always returns
-- exactly to rest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local SkinAppearance = require(ReplicatedStorage.Shared.SkinAppearance)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PISTOL = WeaponConfig.Pistol
local KNIFE = WeaponConfig.Knife
local RENDER_NAME = "WeaponViewmodel"

local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local ViewmodelController = {}
local predicted={}
local hiddenParts={}
local visibilityConnection
local UIS = game:GetService("UserInputService")
local AvatarArms = require(ReplicatedStorage.Shared.AvatarArms)
local Effects = require(ReplicatedStorage.Shared.PolishEffects)
local ArmoryAnimator=require(ReplicatedStorage.Shared.ArmoryAnimator)
local inspectStarted = nil
local arms = nil

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end

-- 0 -> 1 -> 0 envelope: rises until `peak`, eases back to 0 at `finish`
local function pulse(t, peak, finish)
	if t <= 0 or t >= finish then
		return 0
	elseif t < peak then
		return t / peak
	end
	local k = (t - peak) / (finish - peak)
	return 1 - k * k * (3 - 2 * k)
end

------------------------------------------------------------------ pistol firing animation
local FIRE = {
	Duration = 0.22,
	SlideTravel = 0.25, -- slide moves back along the gun
	SlideBack = 0.05, -- time to reach full travel
	SlideReturn = 0.13, -- fully forward again
	HammerFall = -32, -- hammer drops forward when the shot breaks
	HammerDrop = 0.02,
	HammerRecock = 0.12, -- slide has re-cocked the hammer by this time
	RecoilKick = 0.12, -- gun pushes back toward the camera
	RecoilPitch = 5, -- muzzle rises
	RecoilPeak = 0.03,
}

local function animatePistolFire(t, weapon)
	if t >= FIRE.Duration then
		return nil, nil, true
	end
	local r = pulse(t, FIRE.RecoilPeak, FIRE.Duration)
	local rootAdjust = CFrame.new(0, 0, FIRE.RecoilKick * r) * CFrame.Angles(math.rad(FIRE.RecoilPitch * r), 0, 0)
	local slideZ = FIRE.SlideTravel * pulse(t, FIRE.SlideBack, FIRE.SlideReturn)
	local hammerAngle
	if t < FIRE.HammerDrop then
		hammerAngle = lerp(0, FIRE.HammerFall, t / FIRE.HammerDrop)
	elseif t < FIRE.SlideBack then
		hammerAngle = FIRE.HammerFall
	else
		hammerAngle = lerp(FIRE.HammerFall, 0, (t - FIRE.SlideBack) / (FIRE.HammerRecock - FIRE.SlideBack))
	end
	local poses = { Slide = CFrame.new(0, 0, slideZ) } -- +Z is toward the shooter
	local pivot = weapon.pivots.HammerPivot
	if pivot then
		poses.Hammer = CFrame.new(pivot) * CFrame.Angles(math.rad(hammerAngle), 0, 0) * CFrame.new(-pivot)
	end
	return rootAdjust, poses, false
end

------------------------------------------------------------------ knife animations
-- Knife poses are given in camera axes (x right, y up, z toward the player) and
-- rotate the knife about its own grip. The slash is purely visual: whether it
-- hits is decided by the server on its own timer.

local function smooth(k)
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- keyframes: { time, position, pitch, yaw, roll } (degrees)
local function sampleKeys(keys, t)
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local k = smooth((t - a[1]) / (b[1] - a[1]))
			local pos = a[2]:Lerp(b[2], k)
			return CFrame.new(pos) * CFrame.Angles(
				math.rad(lerp(a[3], b[3], k)), math.rad(lerp(a[4], b[4], k)), math.rad(lerp(a[5], b[5], k)))
		end
	end
	return CFrame.identity
end

local DRAW_KEYS = {
	{ 0.00, Vector3.new(0.25, -0.9, 0.2), -70, 20, 0 }, -- below the screen, blade tipped down
	{ 0.18, Vector3.new(0.02, 0.05, 0), 6, -4, 0 }, -- slight overshoot
	{ 0.28, Vector3.zero, 0, 0, 0 },
}

local SLASH_KEYS = {
	{ 0.00, Vector3.zero, 0, 0, 0 },
	{ 0.07, Vector3.new(0.25, 0.2, 0.05), 10, 20, 25 }, -- wind up: out to the right and up
	{ 0.13, Vector3.new(-0.3, 0.0, -0.25), -10, -20, -20 }, -- sweep across, curving forward
	{ 0.19, Vector3.new(-0.75, -0.3, -0.1), -20, -40, -40 }, -- follow-through low and left
	{ 0.38, Vector3.zero, 0, 0, 0 }, -- back to rest
}

local function keyAnimation(keys)
	local duration = keys[#keys][1]
	return function(t)
		if t >= duration then
			return nil, nil, true
		end
		return nil, nil, false, sampleKeys(keys, t)
	end
end

local animateKnifeDraw = keyAnimation(DRAW_KEYS)
local animateKnifeSlash = keyAnimation(SLASH_KEYS)
local INSPECT_KEYS = {
 {0,Vector3.zero,0,0,0},
 {0.35,Vector3.new(-0.3,0.15,0.2),-15,-50,-25},
 {1.1,Vector3.new(-0.3,0.15,0.2),-15,-50,-25},
 {1.55,Vector3.new(-0.15,0.1,0.15),10,40,25},
 {2.2,Vector3.new(-0.15,0.1,0.15),10,40,25},
 {2.6,Vector3.zero,0,0,0},
}
local KNIFE_INSPECT_KEYS = {
 {0,Vector3.zero,0,0,0},
 {0.4,Vector3.new(-0.3,0.2,0.1),-15,-35,35},
 {1.1,Vector3.new(-0.3,0.2,0.1),-15,-35,35},
 {1.6,Vector3.new(-0.05,0.1,0.1),10,25,-20},
 {2.2,Vector3.new(-0.05,0.1,0.1),10,25,-20},
 {2.6,Vector3.zero,0,0,0},
}
local PISTOL_DRAW_KEYS = {
 {0,Vector3.new(0.15,-0.7,0.3),-30,15,10},
 {0.25,Vector3.zero,0,0,0},
 {0.55,Vector3.zero,0,0,0},
}
local function pistolDraw(t)
 if t>=0.55 then return nil,nil,true end
 return nil,{Slide=CFrame.new(0,0,0.25*pulse(t-0.15,0.12,0.35))},false,sampleKeys(PISTOL_DRAW_KEYS,t)
end

------------------------------------------------------------------ weapons
local WEAPONS = {
	[PISTOL.ToolName] = { offset = PISTOL.ViewOffset, draw = pistolDraw, cues = { ShotAccepted = animatePistolFire } },
	[KNIFE.ToolName] = { offset = KNIFE.ViewOffset, draw = animateKnifeDraw, cues = { SwingAccepted = animateKnifeSlash } },
}

local current -- { tool, name, def, model, parts = {[part] = rest offset}, pivots = {} }
local anim -- { fn, start }

local function build(name, skinId, equippedTool)
	local template = equippedTool or ReplicatedStorage.Assets.Weapons:FindFirstChild(name)
	local grip = template and template:FindFirstChild("Grip", true)
	if not grip then
		warn("[Viewmodel] " .. name .. " template or its Grip attachment is missing")
		return nil
	end
	local gripWorld = grip.WorldCFrame
	local model = Instance.new("Model")
	model.Name = "WeaponViewmodel"
	local parts, pivots = {}, {}
 local sourceMap={}
 local kind=template:GetAttribute("ArmoryKind")
	for _, source in template:GetDescendants() do
		if source:IsA("BasePart") then
			local part = source:Clone()
			for _, child in part:GetChildren() do
				-- joints are not needed (parts are placed every frame); keep everything
				-- visual such as SurfaceAppearance, decals, textures and attachments
				if child:IsA("JointInstance") or child:IsA("WeldConstraint") or child:IsA("Constraint") then
					child:Destroy()
				end
			end
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Parent = model
			parts[part] = gripWorld:ToObjectSpace(source.CFrame)
   sourceMap[source]=part
		elseif source:IsA("Attachment") and source.Name:match("Pivot$") then
			pivots[source.Name] = gripWorld:ToObjectSpace(source.WorldCFrame).Position
		end
	end
	-- same skin as the real Tool (set by the server's LoadoutService)
	SkinAppearance.Apply(model, name, skinId)
	local graph
 if kind then
  graph={kind=kind,links={},root=sourceMap[template:FindFirstChild("Handle")],scale=template:GetAttribute("ViewScale") or 1}
  for _,joint in template:GetDescendants() do
   if (joint:IsA("Motor6D") or joint:IsA("WeldConstraint")) and joint.Part0 and joint.Part1 then
    local child,parent=sourceMap[joint.Part1],sourceMap[joint.Part0]
    if child and parent then
     graph.links[child]={parent=parent,name=joint.Name,motor=joint:IsA("Motor6D"),
      rest=joint:IsA("Motor6D") and joint.C0 or joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame),
      inverse=joint:IsA("Motor6D") and joint.C1:Inverse() or CFrame.identity}
    end
   end
  end
 end
 return model, parts, pivots,graph
end

local sprintBlend = 0
local sway = Vector2.zero
local gait = 0
local function place(dt)
 dt=math.clamp(dt or 1/60,0,0.1)
	if not current then
		return
	end
	debug.profilebegin("OITC.WeaponViewmodel")
	local rootAdjust, poses, camPose = CFrame.identity, nil, nil
	if anim then
		local adjust, partPoses, done, cameraPose = anim.fn(os.clock() - anim.start, current)
		if done then
			anim = nil -- finished: back to the exact rest pose
		else
			rootAdjust, poses, camPose = adjust or CFrame.identity, partPoses, cameraPose
		end
	end
	if inspectStarted then
 local elapsed=os.clock()-inspectStarted
 if elapsed>=2.6 then inspectStarted=nil elseif not current.graph then camPose=sampleKeys(current.name==KNIFE.ToolName and KNIFE_INSPECT_KEYS or INSPECT_KEYS,elapsed) end
end
local mode=player:GetAttribute("MovementState")
local ch=player.Character
local h=ch and ch:FindFirstChildOfClass("Humanoid")
local moving=h and h.MoveDirection.Magnitude>0.1
local running=(mode=="Sprint" and moving) or mode=="Slide"
if running then inspectStarted=nil end
local alpha=1-math.exp(-12*dt)
sprintBlend+=( (running and 1 or 0)-sprintBlend)*alpha
local mouse=UIS:GetMouseDelta()
local target=Vector2.new(math.clamp(mouse.X/math.max(dt,0.001)*0.00004,-0.035,0.035),math.clamp(mouse.Y/math.max(dt,0.001)*0.00004,-0.025,0.025))
sway=sway:Lerp(target,1-math.exp(-16*dt))
local speed=moving and (mode=="Sprint" and 14 or 9) or 0
gait+=speed*dt
local amplitude=moving and h.FloorMaterial~=Enum.Material.Air and 0.018 or 0
local bob=CFrame.new(math.sin(gait)*amplitude,math.abs(math.cos(gait))*amplitude,0)
local motion=CFrame.new(0,-0.18*sprintBlend,0.15*sprintBlend)*CFrame.Angles(math.rad(-12)*sprintBlend,-sway.X,-sway.X*0.4)*CFrame.Angles(-sway.Y,0,math.rad(-8)*sprintBlend)*bob
rootAdjust=motion*rootAdjust
local offset = current.def.offset
	local root
 local handRoot
	if camPose then
		-- move in camera axes and rotate about the weapon's grip
		root = workspace.CurrentCamera.CFrame * CFrame.new(offset.Position) * camPose * offset.Rotation * rootAdjust
	else
		root = workspace.CurrentCamera.CFrame * offset * rootAdjust
	end
	if current.graph then
  local deltas={}
  if inspectStarted then deltas=ArmoryAnimator.Sample(current.graph.kind,"Inspect",os.clock()-inspectStarted)
  elseif current.rigAction then
   local done
   deltas,done=ArmoryAnimator.Sample(current.graph.kind,current.rigAction.action,os.clock()-current.rigAction.start)
   if done then current.rigAction=nil end
  end
  local solved={}
  local visiting={}
  local function solve(part)
   if solved[part] then return solved[part] end
   if visiting[part] then return root*current.parts[part] end
   visiting[part]=true
   local link=current.graph.links[part]
   local cf
   if part==current.graph.root then cf=root
   elseif link then local d=link.motor and deltas[link.name] or CFrame.identity
    if current.graph.scale~=1 then d=CFrame.new(d.Position*current.graph.scale)*d.Rotation end -- tracks were authored at prototype size
    cf=solve(link.parent)*link.rest*d*link.inverse
   else cf=root*current.parts[part] end
   solved[part]=cf;visiting[part]=nil;return cf
  end
  for part in current.parts do part.CFrame=solve(part)
   if part.Name=="Body" then handRoot=part.CFrame*current.parts[part]:Inverse() end
  end
 else
  for part, offset in current.parts do
   local pose = poses and poses[part.Name]
   part.CFrame = root * (pose and pose * offset or offset)
  end
 end
	AvatarArms.Place(arms,workspace.CurrentCamera.CFrame,handRoot or root,current.name==KNIFE.ToolName)
 for _,part in hiddenParts do
  if part.Parent then part.LocalTransparencyModifier=1 end
 end
 debug.profileend()
end


local function hide()
 RunService:UnbindFromRenderStep(RENDER_NAME)
 if visibilityConnection then visibilityConnection:Disconnect();visibilityConnection=nil end
 for _,part in hiddenParts do if part.Parent then part.LocalTransparencyModifier=0 end end
 table.clear(hiddenParts)
 sprintBlend=0; sway=Vector2.zero; gait=0
	if player.Character then
		for _,v in player.Character:GetDescendants() do
			if v:IsA("BasePart") then v.LocalTransparencyModifier=0 end
		end
	end
	anim = nil
 inspectStarted=nil
 if arms then arms.model:Destroy(); arms=nil end
 if current then
		current.model:Destroy()
		if current.tool.Parent then
			for _, d in current.tool:GetDescendants() do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 0
				end
			end
		end
		current = nil
	end
end

local function show(tool)
	hide()
	local model, parts, pivots,graph = build(tool.Name, tool:GetAttribute("SkinId"),tool)
	if not model then
		return
	end
	current = { tool = tool, name = tool.Name, def = WEAPONS[tool.Name], model = model, parts = parts, pivots = pivots,graph=graph }
	model.Parent = workspace.CurrentCamera
 local character=player.Character
 if character then
  for _,part in character:GetDescendants() do if part:IsA("BasePart") then table.insert(hiddenParts,part) end end
  visibilityConnection=character.DescendantAdded:Connect(function(part)
   if part:IsA("BasePart") then table.insert(hiddenParts,part) end
  end)
 end
 arms=AvatarArms.Build(player.Character)
 if arms then arms.model.Parent=workspace.CurrentCamera end
 Effects.Sound(tool.Name==PISTOL.ToolName and "Rack" or "Draw",workspace.CurrentCamera)
	if graph then current.rigAction={action="Equip",start=os.clock()}
 elseif current.def.draw then anim = { fn = current.def.draw, start = os.clock() } end
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, place)
	place()
end

local function equippedWeapon(character)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and WEAPONS[child.Name] then
			return child
		end
	end
	return nil
end

local function refresh()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = character and equippedWeapon(character)
	if tool and humanoid and humanoid.Health > 0 and PlayerState.IsArmed(player) then
		if not current or current.tool ~= tool then
			show(tool)
		end
	else
		hide()
	end
end

local function onCharacterAdded(character)
	hide()
	character.ChildAdded:Connect(refresh)
	character.ChildRemoved:Connect(refresh)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(hide)
	refresh()
end

local function onCue(cueName,requestId)
 if type(requestId)=="number" and requestId<=(predicted[cueName] or 0) then return end
 inspectStarted=nil
	if current then
  if current.graph then current.rigAction={action=cueName=="ShotAccepted" and "Fire" or "Attack",start=os.clock()};return end
		local fn = current.def.cues[cueName]
		if fn then
			anim = { fn = fn, start = os.clock() } -- restart from rest; poses are never stacked
		end
	end
end

function ViewmodelController.PredictAttack(kind,id)
 local cue=kind=="Shot" and "ShotAccepted" or "SwingAccepted"
 predicted[cue]=math.max(predicted[cue] or 0,id)
 onCue(cue)
end

function ViewmodelController.GetViewmodel()
	return current and current.model
end

function ViewmodelController.Start()
 UIS.InputBegan:Connect(function(input,processed)
  if processed or UIS:GetFocusedTextBox() then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 then inspectStarted=nil end
  if input.KeyCode==Enum.KeyCode.F and current and not anim and player:GetAttribute("MovementState")~="Sprint" and player:GetAttribute("MovementState")~="Slide" then
   if inspectStarted then inspectStarted=nil else inspectStarted=os.clock() end
  end
 end)
 player.CharacterAppearanceLoaded:Connect(function(character)
  if current and character==player.Character then
   if arms then arms.model:Destroy() end
   arms=AvatarArms.Build(character)
   if arms then arms.model.Parent=workspace.CurrentCamera end
  end
 end)
	Remotes:WaitForChild("ShotAccepted").OnClientEvent:Connect(function(id)
		onCue("ShotAccepted",id)
	end)
	Remotes:WaitForChild("SwingAccepted").OnClientEvent:Connect(function(id)
		onCue("SwingAccepted",id)
	end)
	PlayerState.OnArmedChanged(player, refresh)
	player.CharacterRemoving:Connect(hide)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return ViewmodelController

