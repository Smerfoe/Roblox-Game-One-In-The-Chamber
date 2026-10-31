-- AvatarArms: first-person arms that hold the viewmodel weapon.
-- Uses the player's own arm parts so skin colour, shirt and SurfaceAppearance
-- match the avatar, but resizes them to slim viewmodel proportions (avatar arm
-- packages can be very bulky and would fill the screen). Layered clothing and
-- accessories are left out.
--
-- Placement (every frame, from ViewmodelController):
--   * Right hand sits on the weapon grip, palm and fingers following the grip.
--   * Pistol: left hand supports from under / beside the grip (two-hand hold).
--   * Knife: one-handed; the left arm is kept out of view.
--   * Elbows and shoulders are solved from fixed segment lengths, so the arms
--     never stretch while the weapon recoils, slashes or is inspected.
-- Purely visual and local: nothing here touches the real Tool or combat.

local Arms = {}

local R15 = { "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperArm", "LeftLowerArm", "LeftHand" }
local R6 = { "Right Arm", "Left Arm" }
local KEEP = {}
for _, n in R15 do
	KEEP[n] = true
end
for _, n in R6 do
	KEEP[n] = true
end

-- viewmodel proportions (studs): thickness X/Z, length Y
local SIZE = {
	UpperArm = Vector3.new(0.36, 0.95, 0.36),
	LowerArm = Vector3.new(0.3, 0.9, 0.3),
	Hand = Vector3.new(0.3, 0.32, 0.26),
	R6Arm = Vector3.new(0.32, 1.7, 0.32),
}

-- Hand and elbow placement. Grip offsets are in the weapon grip's axes; elbow
-- directions are in camera axes (x right, y up, z back toward the player).
local POSE = {
	Pistol = {
		Right = { grip = Vector3.new(0.03, -0.06, 0.05), elbow = Vector3.new(0.35, -0.55, 0.75) },
		Left = { grip = Vector3.new(-0.1, -0.05, 0.02), elbow = Vector3.new(-0.6, -0.45, 0.65) },
	},
	Knife = {
		Right = { grip = Vector3.new(0.02, -0.03, 0.04), elbow = Vector3.new(0.3, -0.6, 0.75) },
	},
	ShoulderDrop = Vector3.new(0, -0.35, 0.6), -- upper arm continues down and back, off the bottom of the screen
}

local function resize(part, size)
	if part:IsA("MeshPart") or part:IsA("Part") then
		part.Size = size
	end
end

function Arms.Build(character)
	if not character then
		return nil
	end
	local old = character.Archivable
	character.Archivable = true
	local model = character:Clone()
	character.Archivable = old
	if not model then
		return nil
	end
	model.Name = "AvatarViewArms"
	for _, v in model:GetDescendants() do
		if v:IsA("LuaSourceContainer") or v:IsA("Tool") or v:IsA("Accessory") or v:IsA("JointInstance")
			or v:IsA("Constraint") or v:IsA("WeldConstraint") or v:IsA("WrapLayer") then
			v:Destroy()
		end
	end
	-- the Humanoid stays so the shirt still renders, but it must not re-apply the
	-- avatar's body scaling over the viewmodel sizes below
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutomaticScalingEnabled = false
	end
	local parts = {}
	for _, v in model:GetChildren() do
		if v:IsA("BasePart") then
			v.Anchored = true
			v.CanCollide = false
			v.CanTouch = false
			v.CanQuery = false
			v.CastShadow = false
			v.Massless = true
			v.LocalTransparencyModifier = 0
			if KEEP[v.Name] then
				parts[v.Name] = v
				v.Transparency = 0
				if v.Name:find("UpperArm") then
					resize(v, SIZE.UpperArm)
				elseif v.Name:find("LowerArm") then
					resize(v, SIZE.LowerArm)
				elseif v.Name:find("Hand") then
					resize(v, SIZE.Hand)
				else
					resize(v, SIZE.R6Arm)
				end
			else
				v:Destroy() -- torso, head, legs: not needed
			end
		elseif v:IsA("Humanoid") then
			v.EvaluateStateMachine = false
			v.RequiresNeck = false
			v.BreakJointsOnDeath = false
			v.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif not (v:IsA("Shirt") or v:IsA("BodyColors") or v:IsA("CharacterMesh")) then
			v:Destroy()
		end
	end
	return { model = model, parts = parts }
end

-- Orient a limb so its +Y (top) end is at `top` and its -Y end at `bottom`.
local function limb(part, top, bottom, right)
	if not part then
		return
	end
	local up = top - bottom
	if up.Magnitude < 1e-4 then
		return
	end
	up = up.Unit
	local r = (right - up * right:Dot(up))
	if r.Magnitude < 1e-4 then
		r = up:Cross(Vector3.new(0, 0, 1))
	end
	part.CFrame = CFrame.fromMatrix((top + bottom) / 2, r.Unit, up)
end

local function hide(part, camera)
	if part then
		part.CFrame = camera * CFrame.new(0, -50, 0)
	end
end

function Arms.Place(arms, camera, grip, knife)
	if not arms then
		return
	end
	local pose = knife and POSE.Knife or POSE.Pistol
	local camRight = camera.RightVector
	for _, side in { "Right", "Left" } do
		local p = arms.parts
		local upper, lower, hand = p[side .. "UpperArm"], p[side .. "LowerArm"], p[side .. "Hand"]
		local r6 = p[side .. " Arm"]
		local spec = pose[side]
		if not spec then
			hide(upper, camera)
			hide(lower, camera)
			hide(hand, camera)
			hide(r6, camera)
			continue
		end
		-- hand centre on the grip; the wrist is behind it along the forearm
		local handCentre = grip:PointToWorldSpace(spec.grip)
		local elbowDir = camera:VectorToWorldSpace(spec.elbow).Unit
		local handLen = (hand and hand.Size.Y or 0.3)
		local wrist = handCentre + elbowDir * (handLen / 2)
		if upper and lower then
			local elbow = wrist + elbowDir * lower.Size.Y
			local shoulderDir = (elbowDir + camera:VectorToWorldSpace(POSE.ShoulderDrop)).Unit
			local shoulder = elbow + shoulderDir * upper.Size.Y
			limb(upper, shoulder, elbow, camRight)
			limb(lower, elbow, wrist, camRight)
			-- the hand continues the forearm, fingers pointing toward the grip
			limb(hand, wrist, wrist - elbowDir * handLen, grip.RightVector)
		elseif r6 then
			local top = wrist + elbowDir * r6.Size.Y
			limb(r6, top, handCentre - elbowDir * 0.1, camRight)
		end
	end
end

return Arms
