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
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PISTOL = WeaponConfig.Pistol
local KNIFE = WeaponConfig.Knife
local RENDER_NAME = "WeaponViewmodel"

local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local ViewmodelController = {}

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

------------------------------------------------------------------ weapons
local WEAPONS = {
	[PISTOL.ToolName] = { offset = PISTOL.ViewOffset, cues = { ShotAccepted = animatePistolFire } },
	[KNIFE.ToolName] = { offset = KNIFE.ViewOffset, draw = animateKnifeDraw, cues = { SwingAccepted = animateKnifeSlash } },
}

local current -- { tool, name, def, model, parts = {[part] = rest offset}, pivots = {} }
local anim -- { fn, start }

local function build(name)
	local template = ReplicatedStorage.Assets.Weapons:FindFirstChild(name)
	local grip = template and template:FindFirstChild("Grip", true)
	if not grip then
		warn("[Viewmodel] " .. name .. " template or its Grip attachment is missing")
		return nil
	end
	local gripWorld = grip.WorldCFrame
	local model = Instance.new("Model")
	model.Name = "WeaponViewmodel"
	local parts, pivots = {}, {}
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
		elseif source:IsA("Attachment") and source.Name:match("Pivot$") then
			pivots[source.Name] = gripWorld:ToObjectSpace(source.WorldCFrame).Position
		end
	end
	return model, parts, pivots
end

local function place()
	if not current then
		return
	end
	local rootAdjust, poses, camPose = CFrame.identity, nil, nil
	if anim then
		local adjust, partPoses, done, cameraPose = anim.fn(os.clock() - anim.start, current)
		if done then
			anim = nil -- finished: back to the exact rest pose
		else
			rootAdjust, poses, camPose = adjust or CFrame.identity, partPoses, cameraPose
		end
	end
	local offset = current.def.offset
	local root
	if camPose then
		-- move in camera axes and rotate about the weapon's grip
		root = workspace.CurrentCamera.CFrame * CFrame.new(offset.Position) * camPose * offset.Rotation * rootAdjust
	else
		root = workspace.CurrentCamera.CFrame * offset * rootAdjust
	end
	for part, offset in current.parts do
		local pose = poses and poses[part.Name]
		part.CFrame = root * (pose and pose * offset or offset)
	end
	for _, d in current.tool:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
		end
	end
end

local function hide()
	RunService:UnbindFromRenderStep(RENDER_NAME)
	anim = nil
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
	local model, parts, pivots = build(tool.Name)
	if not model then
		return
	end
	current = { tool = tool, name = tool.Name, def = WEAPONS[tool.Name], model = model, parts = parts, pivots = pivots }
	model.Parent = workspace.CurrentCamera
	if current.def.draw then
		anim = { fn = current.def.draw, start = os.clock() }
	end
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

local function onCue(cueName)
	if current then
		local fn = current.def.cues[cueName]
		if fn then
			anim = { fn = fn, start = os.clock() } -- restart from rest; poses are never stacked
		end
	end
end

function ViewmodelController.GetViewmodel()
	return current and current.model
end

function ViewmodelController.Start()
	Remotes:WaitForChild("ShotAccepted").OnClientEvent:Connect(function()
		onCue("ShotAccepted")
	end)
	Remotes:WaitForChild("SwingAccepted").OnClientEvent:Connect(function()
		onCue("SwingAccepted")
	end)
	PlayerState.OnArmedChanged(player, refresh)
	player.CharacterRemoving:Connect(hide)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return ViewmodelController
