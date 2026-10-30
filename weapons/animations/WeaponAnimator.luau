--!strict
-- Client-only procedural WEAPON animation. No arms, damage, ammo or remotes.
-- Use these standalone rigs or adapt the joint names after reviewing current rigs.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Animator = {}
Animator.__index = Animator
local IDENTITY = CFrame.identity
local function pose(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end
local function key(time: number, frame: CFrame)
	return { time = time, frame = frame }
end
local function sample(keys: any, time: number): CFrame
	if time <= keys[1].time then return keys[1].frame end
	for i = 2, #keys do
		local b, a = keys[i], keys[i - 1]
		if time <= b.time then
			local alpha = (time - a.time) / (b.time - a.time)
			return a.frame:Lerp(b.frame, TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		end
	end
	return keys[#keys].frame
end

-- All tracks are DELTAS from authored Motor6D C0. Each ends exactly at rest.
local PistolTracks = {
	Equip = { duration = 0.48, joints = {
		Presentation = {key(0, pose(.12,-.72,.35,25,-12,18)),key(.32,pose(0,.025,0,-2,0,-2)),key(.48,IDENTITY)},
	}},
	Fire = { duration = 0.24, joints = {
		Presentation = {key(0,IDENTITY),key(.045,pose(0,.035,.12,7,0,-1)),key(.24,IDENTITY)},
		Slide = {key(0,IDENTITY),key(.035,pose(0,0,.23)),key(.105,IDENTITY),key(.24,IDENTITY)},
		Hammer = {key(0,IDENTITY),key(.035,pose(0,0,0,-28)),key(.11,IDENTITY),key(.24,IDENTITY)},
	}},
	Reload = { duration = 1.55, cartridgeWindow = {.42,.91}, joints = {
		Presentation = {key(0,IDENTITY),key(.22,pose(-.10,.06,.12,0,-15,-22)),key(1.25,pose(-.10,.06,.12,0,-15,-22)),key(1.55,IDENTITY)},
		Magazine = {key(0,IDENTITY),key(.23,pose(-.04,-.55,.04)),key(.82,pose(-.04,-.55,.04)),key(1.03,IDENTITY),key(1.55,IDENTITY)},
		Cartridge = {key(0,IDENTITY),key(.42,IDENTITY),key(.82,pose(.65,-.02,.04)),key(.91,pose(.65,-.10,.04)),key(1.55,IDENTITY)},
		Slide = {key(0,IDENTITY),key(1.08,IDENTITY),key(1.22,pose(0,0,.23)),key(1.34,IDENTITY),key(1.55,IDENTITY)},
	}},
	Inspect = { duration = 2.65, joints = {
		Presentation = {key(0,IDENTITY),key(.38,pose(-.24,.16,.08,-12,-28,-18)),key(.95,pose(-.24,.16,.08,-12,-28,-18)),key(1.48,pose(-.10,.12,.06,8,32,14)),key(1.95,pose(-.10,.12,.06,8,32,14)),key(2.30,pose(-.06,.05,0,-3,-10,-7)),key(2.65,IDENTITY)},
	}},
}
local KnifeTracks = {
	Equip = { duration = .42, joints = {
		Presentation = {key(0,pose(.1,-.7,.25,10,0,35)),key(.26,pose(0,.025,0,0,0,-5)),key(.42,IDENTITY)},
	}},
	Attack = { duration = .46, joints = {
		Presentation = {key(0,IDENTITY),key(.09,pose(.12,.08,.05,-8,-15,20)),key(.15,pose(-.32,-.06,-.34,18,30,-50)),key(.28,pose(-.22,-.1,-.15,12,20,-30)),key(.46,IDENTITY)},
	}},
	Inspect = { duration = 2.35, joints = {
		Presentation = {key(0,IDENTITY),key(.32,pose(-.22,.16,.10,-12,-25,-30)),key(.82,pose(-.22,.16,.10,-12,-25,-30)),key(1.23,pose(-.12,.17,.06,8,35,85)),key(1.48,pose(-.04,.12,.04,5,15,165)),key(1.78,pose(0,.06,0,0,-10,30)),key(2.35,IDENTITY)},
	}},
}

local RevolverTracks = {
	Equip = { duration = .55, joints = {
		Presentation = {key(0,pose(.12,-.65,.30,18,-10,18)),key(.35,pose(0,.02,0,-2,0,-2)),key(.55,IDENTITY)},
	}},
	Fire = { duration = .28, joints = {
		Presentation = {key(0,IDENTITY),key(.045,pose(0,.04,.12,8,0,-1)),key(.28,IDENTITY)},
		Hammer = {key(0,IDENTITY),key(.035,pose(0,0,0,-27)),key(.16,IDENTITY),key(.28,IDENTITY)},
	}},
	Reload = { duration = 2.0, cartridgeWindow = {.55,1.15}, joints = {
		Presentation = {key(0,IDENTITY),key(.25,pose(-.10,.06,.12,0,-16,-15)),key(1.50,pose(-.10,.06,.12,0,-16,-15)),key(2,IDENTITY)},
		Cylinder = {key(0,IDENTITY),key(.18,IDENTITY),key(.45,pose(0,0,0,0,0,90)),key(1.20,pose(0,0,0,0,0,90)),key(1.48,IDENTITY),key(2,IDENTITY)},
		Cartridge = {key(0,IDENTITY),key(.55,IDENTITY),key(.88,pose(.39,.13,-.50)),key(1.15,pose(.39,.13,-.62)),key(2,IDENTITY)},
		Hammer = {key(0,IDENTITY),key(1.51,IDENTITY),key(1.65,pose(0,0,0,22)),key(1.82,IDENTITY),key(2,IDENTITY)},
	}},
	Inspect = { duration = 2.85, joints = {
		Presentation = {key(0,IDENTITY),key(.40,pose(-.22,.13,.16,-8,-30,-18)),key(.95,pose(-.22,.13,.16,-8,-30,-18)),key(1.40,pose(-.05,.16,.18,8,38,23)),key(1.90,pose(-.05,.16,.18,8,38,23)),key(2.25,pose(.02,.08,.08,-5,-18,-25)),key(2.85,IDENTITY)},
	}},
}
local MacheteTracks = {
	Equip = { duration = .50, joints = {
		Presentation = {key(0,pose(.15,-.9,.30,-8,0,25)),key(.32,pose(0,.02,0,0,0,-2)),key(.50,IDENTITY)},
	}},
	Attack = { duration = .50, joints = {
		Presentation = {key(0,IDENTITY),key(.08,pose(.10,.04,.06,-6,-12,18)),key(.15,pose(-.25,-.12,-.22,12,25,-45)),key(.30,pose(-.16,-.08,-.10,8,16,-25)),key(.50,IDENTITY)},
	}},
	Inspect = { duration = 2.50, joints = {
		Presentation = {key(0,IDENTITY),key(.38,pose(-.22,-.10,.12,-8,-30,-42)),key(1.05,pose(-.22,-.10,.12,-8,-30,-42)),key(1.55,pose(-.12,-.10,.14,6,30,15)),key(1.95,pose(-.12,-.10,.14,6,30,15)),key(2.50,IDENTITY)},
	}},
}
local ButterKnifeTracks = {
	Equip = { duration = .35, joints = {
		Presentation = {key(0,pose(.02,-.5,.10,0,0,10)),key(.35,IDENTITY)},
	}},
	Attack = { duration = .42, joints = {
		Presentation = {key(0,IDENTITY),key(.08,pose(.04,.03,.03,-4,-8,10)),key(.15,pose(-.18,-.05,-.21,8,22,-32)),key(.42,IDENTITY)},
	}},
	Inspect = { duration = 2.10, joints = {
		Presentation = {key(0,IDENTITY),key(.32,pose(-.20,.12,.08,-6,-22,-10)),key(.90,pose(-.20,.12,.08,-6,-22,-10)),key(1.25,pose(-.08,.13,.10,4,48,6)),key(1.65,pose(-.08,.13,.10,4,48,6)),key(2.10,IDENTITY)},
	}},
}
local TRACKS = { Pistol = PistolTracks, Knife = KnifeTracks, Revolver = RevolverTracks,
	Machete = MacheteTracks, ButterKnife = ButterKnifeTracks }
local OFFSETS = { Pistol = CFrame.new(.65,-.63,-1.05), Knife = CFrame.new(.70,-.65,-1.20),
	Revolver = CFrame.new(.64,-.65,-.85), Machete = CFrame.new(.72,-.86,-1.35),
	ButterKnife = CFrame.new(.66,-.71,-1.20) }

function Animator.new(model: Model, kind: string, camera: Camera)
	assert(RunService:IsClient(), "WeaponAnimator must run on the client")
	assert(TRACKS[kind] ~= nil, "Unknown weapon presentation kind")
	local anchor = model:FindFirstChild("Anchor")
	assert(anchor and anchor:IsA("BasePart"), "Rig requires Anchor BasePart")
	local self: any = setmetatable({}, Animator)
	self.model, self.anchor, self.camera, self.kind = model, anchor, camera, kind
	self.joints, self.rest, self.cartridges = {}, {}, {}
	self.time, self.state, self.active, self.destroyed = 0, "Idle", nil, false
	self.offset = OFFSETS[kind]
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") then
			assert(self.joints[item.Name] == nil, "Duplicate joint name: " .. item.Name)
			self.joints[item.Name], self.rest[item.Name] = item, item.C0
		elseif item:IsA("BasePart") then
			item.CanCollide, item.CanTouch, item.CanQuery, item.CastShadow = false, false, false, false
			if item.Name == "SingleCartridge" or item.Name == "CartridgeTip" then
				table.insert(self.cartridges, item)
				item.Transparency = 1
			end
		end
	end
	assert(self.joints.Presentation, "Rig requires Presentation Motor6D")
	if kind == "Pistol" then
		for _, name in {"Slide", "Hammer", "Magazine", "Cartridge"} do
			assert(self.joints[name], "Missing pistol joint " .. name)
		end
	elseif kind == "Revolver" then
		for _, name in {"Cylinder", "Hammer", "Cartridge"} do
			assert(self.joints[name], "Missing revolver joint " .. name)
		end
	end
	self.connection = RunService.RenderStepped:Connect(function(dt) self:_step(dt) end)
	return self
end

function Animator:Play(action: string): boolean
	if self.destroyed then return false end
	local tracks = TRACKS[self.kind]
	local track = tracks[action]
	if not track then return false end
	if action == "Inspect" and (self.state ~= "Idle" or self.active ~= nil) then return false end
	-- Gameplay code decides whether an action is legal; this is presentation only.
	-- Fire/Attack/Equip may interrupt inspection. No combat timers are changed here.
	self.active = { name = action, track = track, elapsed = 0 }
	return true
end

function Animator:SetLocomotion(state: string)
	assert(state == "Idle" or state == "Sprint" or state == "Slide", "Unknown locomotion")
	if self.destroyed then return end
	self.state = state
	if state ~= "Idle" and self.active and self.active.name == "Inspect" then self:Cancel() end
end

function Animator:SetCamera(camera: Camera)
	if not self.destroyed then self.camera = camera end
end

function Animator:Cancel()
	self.active = nil
	for name, joint in self.joints do joint.C0 = self.rest[name] end
	for _, part in self.cartridges do part.Transparency = 1 end
end

function Animator:_step(dt: number)
	if self.destroyed then return end
	self.time += dt
	self.anchor.CFrame = self.camera.CFrame * self.offset
	local active = self.active
	if active then active.elapsed += dt end
	local movement = IDENTITY
	if self.state == "Sprint" then
		movement = pose(.06 + math.sin(self.time*11)*.018,-.18 + math.cos(self.time*22)*.012,.09,-14,12,14)
	elseif self.state == "Slide" then
		movement = pose(.04,-.24,.04,-8,-8,-19)
	elseif not active then
		movement = pose(0,math.sin(self.time*1.8)*.003,0)
	end
	for name, joint in self.joints do
		local delta = IDENTITY
		if active and active.track.joints[name] then delta = sample(active.track.joints[name], active.elapsed) end
		local target = self.rest[name] * (name == "Presentation" and movement or IDENTITY) * delta
		-- Blend interruption/locomotion changes without accumulating transforms.
		joint.C0 = joint.C0:Lerp(target, 1-math.exp(-35*dt))
	end
	for _, part in self.cartridges do
		local window = active and active.track.cartridgeWindow
		part.Transparency = window and active.elapsed >= window[1] and active.elapsed <= window[2] and 0 or 1
	end
	if active and active.elapsed >= active.track.duration then self.active = nil end
end

function Animator:Destroy()
	if self.destroyed then return end
	self:Cancel()
	self.destroyed = true
	self.connection:Disconnect()
end

return Animator
