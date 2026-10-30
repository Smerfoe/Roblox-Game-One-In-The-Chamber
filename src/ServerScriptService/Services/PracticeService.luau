-- PracticeService: the rules inside the practice room (workspace.PracticeArea).
--   * Registers a combat policy with CombatService: a living player whose
--     Location is "Practice" (and who is not in a match) may shoot and swing,
--     and may damage ONLY practice targets: dummies this service placed inside
--     PracticeArea, marked PracticeTarget. Players are never damaged by practice.
--     Weapons themselves come from LoadoutService (Location = Practice counts as armed).
--   * Places a dummy at every marker in PracticeArea.TargetMarkers (pistol lanes
--     and the knife bay); an eliminated dummy comes back after TargetRespawnTime.
--   * Reset station (ProximityPrompt in PracticeArea.ResetStation): restores every
--     target and the player's bullet. Entering practice also restores the bullet.
-- Nothing here touches the queue, matches, scores, rewards or any stats; the only
-- "reward" for a dummy elimination is CombatService's normal one-bullet refill.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PracticeConfig = require(ReplicatedStorage.Shared.Config.PracticeConfig)
local MatchService = require(script.Parent.MatchService)
local CombatService = require(script.Parent.CombatService)

local PracticeService = {}

local area
local activeFolder
local dummies = {} -- [marker] = current dummy model
local lastReset = {} -- [player] = os.clock()

local function isPracticing(player)
	if player:GetAttribute("Location") ~= "Practice" or MatchService.IsInMatch(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function spawnDummy(marker)
	local template = ServerStorage:FindFirstChild("Dev") and ServerStorage.Dev:FindFirstChild("TestDummy")
	if not template then
		warn("[Practice] ServerStorage.Dev.TestDummy missing; no targets")
		return
	end
	local dummy = template:Clone()
	dummy.Name = marker.Name
	dummy:SetAttribute("InMatch", nil) -- only meaningful to the old TestMode
	dummy:SetAttribute("PracticeTarget", true)
	dummy:PivotTo(marker.CFrame)
	dummy.Parent = activeFolder
	dummies[marker] = dummy
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	humanoid.Died:Connect(function()
		task.wait(PracticeConfig.TargetRespawnTime)
		if dummies[marker] == dummy then -- not already replaced by a reset
			dummy:Destroy()
			spawnDummy(marker)
		end
	end)
end

function PracticeService.ResetTargets()
	for marker, dummy in dummies do
		dummies[marker] = nil
		dummy:Destroy()
	end
	for _, marker in area.TargetMarkers:GetChildren() do
		if marker:IsA("BasePart") then
			spawnDummy(marker)
		end
	end
end

local function onReset(player)
	if not isPracticing(player) then
		return
	end
	if lastReset[player] and os.clock() - lastReset[player] < PracticeConfig.ResetCooldown then
		return
	end
	lastReset[player] = os.clock()
	PracticeService.ResetTargets()
	CombatService.RefillAmmo(player)
end

local policy = {}

function policy.CanAttack(player)
	return isPracticing(player)
end

function policy.CanDamage(attacker, humanoid)
	if not isPracticing(attacker) then
		return false
	end
	local model = humanoid.Parent
	return model ~= nil
		and Players:GetPlayerFromCharacter(model) == nil
		and model:GetAttribute("PracticeTarget") == true
		and activeFolder ~= nil
		and model:IsDescendantOf(activeFolder)
end

function PracticeService.Start()
	area = workspace:FindFirstChild("PracticeArea")
	if not area or not area:FindFirstChild("TargetMarkers") then
		warn("[Practice] workspace.PracticeArea (with TargetMarkers) not found; practice is off")
		return
	end
	activeFolder = Instance.new("Folder")
	activeFolder.Name = "ActiveTargets"
	activeFolder.Parent = area
	PracticeService.ResetTargets()
	CombatService.AddPolicy(policy)

	local station = area:FindFirstChild("ResetStation", true)
	local prompt = station and station:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(onReset)
	else
		warn("[Practice] ResetStation prompt missing")
	end

	local function watch(player)
		player:GetAttributeChangedSignal("Location"):Connect(function()
			if player:GetAttribute("Location") == "Practice" then
				CombatService.RefillAmmo(player) -- everyone starts practice with their bullet
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastReset[player] = nil
	end)
end

return PracticeService
