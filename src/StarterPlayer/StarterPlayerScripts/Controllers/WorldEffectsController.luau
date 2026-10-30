-- WorldEffectsController: plays OTHER players' attacks on their third-person
-- weapons, so you can see someone else shoot (slide and hammer cycle) or slash
-- (arm sweep). Purely visual: the server has already decided the outcome.
-- Each pose is computed from the time since the cue, and every joint we move is
-- put back exactly when the effect ends or is interrupted.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WeaponEffect")

local PISTOL = WeaponConfig.Pistol
local player = Players.LocalPlayer

local WorldEffectsController = {}

-- same timing as the first-person firing animation in ViewmodelController
local FIRE = { Duration = 0.22, SlideTravel = 0.25, SlideBack = 0.05, SlideReturn = 0.13,
	HammerFall = -32, HammerDrop = 0.02, HammerRecock = 0.12 }
-- arm sweep for a slash, same length as the first-person slash
local SWING = { Duration = 0.38, Keys = {
	{ 0.00, 0, 0 },
	{ 0.07, 25, 35 }, -- wind up: raise and pull out to the right
	{ 0.19, -10, -55 }, -- sweep across the body
	{ 0.38, 0, 0 },
} }

local active = {} -- [character] = { kind, start, joints = {...} }

local function lerp(a, b, t)
	return a + (b - a) * math.clamp(t, 0, 1)
end
local function smooth(k)
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end
local function pulse(t, peak, finish)
	if t <= 0 or t >= finish then
		return 0
	elseif t < peak then
		return t / peak
	end
	local k = (t - peak) / (finish - peak)
	return 1 - k * k * (3 - 2 * k)
end

local function finish(character)
	local entry = active[character]
	active[character] = nil
	if not entry then
		return
	end
	for _, joint in entry.toolJoints or {} do
		if joint.Parent then
			joint.Transform = CFrame.identity -- the gun's moving parts go back to rest
		end
	end
	-- shoulder: if no animation has overwritten our last value, put back the exact pose we started from
	local shoulder = entry.shoulder
	if shoulder and shoulder.Parent and entry.lastWritten and shoulder.Transform:FuzzyEq(entry.lastWritten, 1e-4) then
		shoulder.Transform = entry.base
	end
end

local function stepFire(entry, t)
	local tool, slideJoint, hammerJoint = entry.tool, entry.toolJoints[1], entry.toolJoints[2]
	local handle = tool:FindFirstChild("Handle")
	local grip = handle and handle:FindFirstChild("Grip")
	local pivot = handle and handle:FindFirstChild("HammerPivot")
	if not grip then
		return false
	end
	local gunBack = grip.WorldCFrame.ZVector -- +Z of the gun = toward the shooter
	local gunRight = grip.WorldCFrame.XVector
	if slideJoint then
		local frame = handle.CFrame * slideJoint.C0
		local slideZ = FIRE.SlideTravel * pulse(t, FIRE.SlideBack, FIRE.SlideReturn)
		slideJoint.Transform = CFrame.new(frame:VectorToObjectSpace(gunBack) * slideZ)
	end
	if hammerJoint and pivot then
		local angle
		if t < FIRE.HammerDrop then
			angle = lerp(0, FIRE.HammerFall, t / FIRE.HammerDrop)
		elseif t < FIRE.SlideBack then
			angle = FIRE.HammerFall
		else
			angle = lerp(FIRE.HammerFall, 0, (t - FIRE.SlideBack) / (FIRE.HammerRecock - FIRE.SlideBack))
		end
		local frame = handle.CFrame * hammerJoint.C0
		local p = frame:PointToObjectSpace(pivot.WorldPosition)
		local axis = frame:VectorToObjectSpace(gunRight)
		hammerJoint.Transform = CFrame.new(p) * CFrame.fromAxisAngle(axis, math.rad(angle)) * CFrame.new(-p)
	end
	return true
end

local function stepSwing(entry, t)
	local shoulder = entry.shoulder
	if not shoulder or not shoulder.Parent then
		return false
	end
	local keys = SWING.Keys
	local pitch, yaw = 0, 0
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			local k = smooth((t - a[1]) / (b[1] - a[1]))
			pitch, yaw = lerp(a[2], b[2], k), lerp(a[3], b[3], k)
			break
		end
	end
	local extra = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
	-- add the sweep on top of the pose the character's animation set this frame.
	-- If nothing overwrote our last value, keep using the exact base we stored,
	-- so the sweep never accumulates.
	if not (entry.lastWritten and shoulder.Transform:FuzzyEq(entry.lastWritten, 1e-4)) then
		entry.base = shoulder.Transform
	end
	local written = entry.base * extra
	shoulder.Transform = written
	entry.lastWritten = written
	return true
end

local function onEffect(character, kind)
	if typeof(character) ~= "Instance" or character == player.Character then
		return -- your own attacks are shown by the first-person viewmodel
	end
	finish(character) -- restart from rest, never stack
	local entry = { kind = kind, start = os.clock() }
	if kind == "Fire" then
		local tool = character:FindFirstChild(PISTOL.ToolName)
		local handle = tool and tool:FindFirstChild("Handle")
		if not handle then
			return
		end
		entry.tool = tool
		entry.toolJoints = { handle:FindFirstChild("SlideJoint"), handle:FindFirstChild("HammerJoint") }
		entry.duration = FIRE.Duration
	elseif kind == "Swing" then
		local arm = character:FindFirstChild("RightUpperArm")
		entry.shoulder = (arm and arm:FindFirstChild("RightShoulder"))
			or (character:FindFirstChild("Torso") and character.Torso:FindFirstChild("Right Shoulder"))
		entry.duration = SWING.Duration
	else
		return
	end
	active[character] = entry
end

local function step()
	local now = os.clock()
	for character, entry in active do
		local t = now - entry.start
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local alive = character.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0
		local stillHeld = entry.kind ~= "Fire" or (entry.tool and entry.tool.Parent == character)
		local ok = alive and stillHeld and t < entry.duration
		if ok then
			if entry.kind == "Fire" then
				ok = stepFire(entry, t)
			else
				ok = stepSwing(entry, t)
			end
		end
		if not ok then
			finish(character)
		end
	end
end

function WorldEffectsController.Start()
	WeaponEffect.OnClientEvent:Connect(onEffect)
	-- after the character animations have been applied, before physics/render
	local signal = RunService.PreSimulation or RunService.Stepped
	signal:Connect(step)
end

return WorldEffectsController
