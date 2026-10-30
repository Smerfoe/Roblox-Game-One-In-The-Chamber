-- TestModeService: while DevConfig.TestMode is on, every spawn or respawn
-- puts the player at the test map's team spawn points and marks them InMatch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local TestModeService = {}

local SPAWN_LIFT = Vector3.new(0, 3, 0) -- start slightly above the marker so the character drops onto the floor
local nextSpawn = 0

local function getSpawnPoints()
	local map = workspace:FindFirstChild(DevConfig.TestMap)
	local spawns = map and map:FindFirstChild("Spawns")
	local team = spawns and spawns:FindFirstChild(DevConfig.TestTeam)
	if not team then
		return nil
	end
	local points = team:GetChildren()
	table.sort(points, function(a, b)
		return a.Name < b.Name
	end)
	return points
end

local function onCharacterAdded(player, character)
	local points = getSpawnPoints()
	if not points or #points == 0 then
		warn(`[TestMode] No spawn points found at {DevConfig.TestMap}.Spawns.{DevConfig.TestTeam}`)
		return
	end

	nextSpawn = nextSpawn % #points + 1
	local point = points[nextSpawn]

	character:WaitForChild("HumanoidRootPart")
	task.wait() -- let Roblox finish its default spawn placement first
	character:PivotTo(point.CFrame + SPAWN_LIFT)
	-- tell the client which way to point the camera (in first person the body follows the camera)
	character:SetAttribute("SpawnCFrame", point.CFrame)

	player:SetAttribute("InMatch", true)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function TestModeService.Start()
	if not DevConfig.TestMode then
		return
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	print(`[TestMode] ON - players spawn in {DevConfig.TestMap} ({DevConfig.TestTeam})`)
end

return TestModeService
