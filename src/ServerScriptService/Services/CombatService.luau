-- CombatService: the server's authority over weapons.
-- A client only says "I pulled the trigger, aiming this way". The server checks
-- that the player is in a match, alive, within the fire rate and has a bullet,
-- then does its own raycast from the player's head to decide what was hit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MatchService = require(script.Parent.MatchService) -- decides who may attack whom
local FireRemote = ReplicatedStorage.Remotes.Fire
local ShotAcceptedRemote = ReplicatedStorage.Remotes.ShotAccepted
local MeleeRemote = ReplicatedStorage.Remotes.Melee
local SwingAcceptedRemote = ReplicatedStorage.Remotes.SwingAccepted
local WeaponEffectRemote = ReplicatedStorage.Remotes.WeaponEffect

local PISTOL = WeaponConfig.Pistol
local KNIFE = WeaponConfig.Knife
local LOG = RunService:IsStudio()

local CombatService = {}

local ammo = {} -- [player] = bullets; the server's copy is the only one that counts
local lastShot = {} -- [player] = os.clock() of the last accepted shot
local lastSwing = {} -- [player] = os.clock() of the last accepted knife swing
local pendingSwing = {} -- [player] = token of the swing waiting to land

local function log(...)
	if LOG then
		print("[Combat]", ...)
	end
end

-- Extra attack rules registered by other services (the practice room). Each policy
-- has CanAttack(player) and CanDamage(attacker, humanoid). Match rules are checked
-- first; a policy can only ever add permission for its own situation.
local policies = {}

local function canAttack(player)
	if MatchService.CanAttack(player) then
		return true
	end
	for _, policy in policies do
		if policy.CanAttack(player) then
			return true
		end
	end
	return false
end

local function canDamage(attacker, humanoid)
	if MatchService.CanDamage(attacker, humanoid) then
		return true
	end
	for _, policy in policies do
		if policy.CanDamage(attacker, humanoid) then
			return true
		end
	end
	return false
end

local function setAmmo(player, amount)
	ammo[player] = amount
	player:SetAttribute("Ammo", amount) -- read-only mirror for the HUD
end

local function isValidDirection(direction)
	if typeof(direction) ~= "Vector3" then
		return false
	end
	local length = direction.Magnitude
	return length == length and length > 0.9 and length < 1.1 -- length == length rejects NaN
end

-- Tell every other client that this player's attack went off, so they can play
-- it on the attacker's third-person weapon. Visual only; outcomes are decided here.
local function broadcastEffect(player, kind)
	local character = player.Character
	for _, other in Players:GetPlayers() do
		if other ~= player then
			WeaponEffectRemote:FireClient(other, character, kind)
		end
	end
end

local function findHumanoid(part)
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- The only way a target gets eliminated. Returns true only for the call that
-- actually ended the target's life, so the reward can never be paid twice.
local function eliminate(attacker, target)
	if target.Health <= 0 or target:GetAttribute("EliminatedBy") ~= nil then
		return false
	end
	target:SetAttribute("EliminatedBy", attacker.UserId)
	target.Health = 0
	return true
end

-- Reward for a confirmed elimination: one bullet back, never above MaxAmmo.
local function awardElimination(player)
	setAmmo(player, math.min((ammo[player] or 0) + 1, PISTOL.MaxAmmo))
end

-- Out of ammo after a shot that did not eliminate anyone: put the knife in hand.
local function switchToKnifeIfEmpty(player)
	if (ammo[player] or 0) > 0 then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not character:FindFirstChild(PISTOL.ToolName) then
		return -- dead, or already holding something else
	end
	local knife = player.Backpack:FindFirstChild(KNIFE.ToolName)
	if knife then
		humanoid:EquipTool(knife)
	end
end

local function onFire(player, direction)
	if not canAttack(player) then
		log(player.Name, "rejected: combat is not active for this player")
		return
	end
	if not isValidDirection(direction) then
		log(player.Name, "rejected: bad aim data")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and character:FindFirstChild("Head")
	if not humanoid or humanoid.Health <= 0 or not head then
		log(player.Name, "rejected: not alive")
		return
	end
	local tool = character:FindFirstChild(PISTOL.ToolName)
	if not tool or not tool:IsA("Tool") then
		log(player.Name, "rejected: pistol not equipped")
		return
	end

	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < PISTOL.FireCooldown then
		log(player.Name, "rejected: fire rate")
		return
	end
	if (ammo[player] or 0) < 1 then
		log(player.Name, "rejected: no ammo")
		return
	end

	-- the shot is accepted: it costs the bullet whatever it hits
	lastShot[player] = now
	setAmmo(player, ammo[player] - 1)
	ShotAcceptedRemote:FireClient(player) -- cue for the shooter's firing animation only
	broadcastEffect(player, "Fire")
	task.delay(PISTOL.AutoSwitchDelay, switchToKnifeIfEmpty, player)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(head.Position, direction.Unit * PISTOL.Range, params)

	if not result then
		log(player.Name, "shot: hit nothing")
		return
	end
	local target = findHumanoid(result.Instance)
	if not target then
		log(player.Name, "shot: blocked by", result.Instance.Name)
		return
	end
	if target.Health <= 0 then
		log(player.Name, "shot: hit", target.Parent.Name, "(already eliminated)")
		return
	end
	if not canDamage(player, target) then
		log(player.Name, "shot: hit", target.Parent.Name, "(not an opponent in this match, no effect)")
		return
	end
	local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
	local team = player:GetAttribute("Team")
	if targetPlayer and team ~= nil and targetPlayer:GetAttribute("Team") == team then
		log(player.Name, "shot: hit teammate", targetPlayer.Name, "(no friendly fire)")
		return
	end

	-- a pistol hit is always an elimination
	if eliminate(player, target) then
		awardElimination(player)
		log(player.Name, "shot: eliminated", target.Parent.Name, "- bullet restored")
	else
		log(player.Name, "shot: hit", target.Parent.Name, "(already eliminated)")
	end
end

------------------------------------------------------------------ knife
-- The client only says "I swung". The server checks the swing, then decides on
-- its own timer (HitDelay) whether it lands, using its own range, angle and
-- line-of-sight tests. Nothing about the target comes from the client.

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

local function isBehind(attackerRoot, targetRoot)
	local toAttacker = flat(attackerRoot.Position - targetRoot.Position)
	local facing = flat(targetRoot.CFrame.LookVector)
	if toAttacker.Magnitude < 0.01 or facing.Magnitude < 0.01 then
		return false
	end
	return facing.Unit:Dot(toAttacker.Unit) <= -math.cos(math.rad(KNIFE.BackstabHalfAngle))
end

local function findMeleeTarget(player, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local head = character:FindFirstChild("Head")
	if not root or not head then
		return nil
	end
	local forward = flat(root.CFrame.LookVector).Unit
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local checked, best, bestDistance = {}, nil, math.huge
	for _, part in workspace:GetPartBoundsInRadius(root.Position, KNIFE.Range + 3, overlap) do
		local humanoid = findHumanoid(part)
		if humanoid and not checked[humanoid] and humanoid.Health > 0 and canDamage(player, humanoid) then
			checked[humanoid] = true
			local model = humanoid.Parent
			local targetRoot = rootOf(model)
			if targetRoot then
				local offset = targetRoot.Position - root.Position
				local distance = flat(offset).Magnitude
				local inFront = distance < 0.01 or forward:Dot(flat(offset).Unit) >= math.cos(math.rad(KNIFE.HalfAngle))
				if distance <= KNIFE.Range and math.abs(offset.Y) <= KNIFE.MaxHeightDifference and inFront then
					local hit = workspace:Raycast(head.Position, targetRoot.Position - head.Position, rayParams)
					if hit and not hit.Instance:IsDescendantOf(model) then
						log(player.Name, "swing: path to", model.Name, "blocked by", hit.Instance.Name)
					elseif distance < bestDistance then
						best, bestDistance = humanoid, distance
					end
				end
			end
		end
	end
	return best
end

local function resolveSwing(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not canAttack(player) then
		log(player.Name, "swing: cancelled (not alive / combat not active)")
		return
	end
	local knife = character:FindFirstChild(KNIFE.ToolName)
	if not knife or not knife:IsA("Tool") then
		log(player.Name, "swing: cancelled (knife put away)")
		return
	end

	local target = findMeleeTarget(player, character)
	if not target then
		log(player.Name, "swing: missed")
		return
	end
	local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
	local team = player:GetAttribute("Team")
	if targetPlayer and team ~= nil and targetPlayer:GetAttribute("Team") == team then
		log(player.Name, "swing: hit teammate", targetPlayer.Name, "(no friendly fire)")
		return
	end

	local backstab = isBehind(character.HumanoidRootPart, rootOf(target.Parent))
	local damage = backstab and KNIFE.BackDamage or KNIFE.FrontDamage
	local how = backstab and "backstab" or "front"
	if target.Health - damage <= 0 then
		if eliminate(player, target) then
			awardElimination(player)
			log(player.Name, "swing:", how, "eliminated", target.Parent.Name, "- bullet restored")
		end
	else
		target.Health -= damage
		log(player.Name, "swing:", how, "hit", target.Parent.Name, "for", damage, "- health now", target.Health)
	end
end

local function onMelee(player)
	-- any arguments a client sends are ignored
	if not canAttack(player) then
		log(player.Name, "swing rejected: combat is not active for this player")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		log(player.Name, "swing rejected: not alive")
		return
	end
	local knife = character:FindFirstChild(KNIFE.ToolName)
	if not knife or not knife:IsA("Tool") then
		log(player.Name, "swing rejected: knife not equipped")
		return
	end
	local now = os.clock()
	if lastSwing[player] and now - lastSwing[player] < KNIFE.Cooldown then
		log(player.Name, "swing rejected: cooldown")
		return
	end

	lastSwing[player] = now
	local token = {}
	pendingSwing[player] = token
	SwingAcceptedRemote:FireClient(player) -- cue for the attacker's slash animation only
	broadcastEffect(player, "Swing")
	task.delay(KNIFE.HitDelay, function()
		if pendingSwing[player] ~= token then
			return -- cancelled by respawn
		end
		pendingSwing[player] = nil
		resolveSwing(player)
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		lastShot[player] = nil
		pendingSwing[player] = nil -- a swing from the previous life never lands
		setAmmo(player, PISTOL.StartAmmo)
	end)
	if player.Character then
		setAmmo(player, PISTOL.StartAmmo)
	end
end

function CombatService.AddPolicy(policy)
	assert(type(policy.CanAttack) == "function" and type(policy.CanDamage) == "function", "policy needs CanAttack and CanDamage")
	table.insert(policies, policy)
end

-- Server-side bullet refill (practice room entry and reset station).
function CombatService.RefillAmmo(player)
	setAmmo(player, PISTOL.StartAmmo)
end

function CombatService.Start()
	FireRemote.OnServerEvent:Connect(onFire)
	MeleeRemote.OnServerEvent:Connect(onMelee)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ammo[player] = nil
		lastShot[player] = nil
		lastSwing[player] = nil
		pendingSwing[player] = nil
	end)
end

return CombatService
