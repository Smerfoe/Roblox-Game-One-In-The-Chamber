-- CameraController: first person while the player is armed (in a match round or in
-- the practice room), normal third-person camera otherwise.
-- The server sets the attributes (see Shared.PlayerState); this script only reacts to them.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local CameraController = {}

local ARRIVE_DISTANCE = 8 -- studs; how close the character must be to the spawn before we turn the camera
local ARRIVE_TIMEOUT = 3 -- seconds

local THIRD_PERSON_ZOOM = 12 -- studs; where the camera goes when first person ends
local defaultMinZoom
local wasFirstPerson = false

local function apply()
	local armed = PlayerState.IsArmed(player)
	if armed then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		if wasFirstPerson then
			-- leaving first person without a new character (practice -> lobby):
			-- push the zoom back out, then give the player their normal zoom range
			defaultMinZoom = defaultMinZoom or player.CameraMinZoomDistance
			player.CameraMinZoomDistance = THIRD_PERSON_ZOOM
			task.delay(0.1, function()
				if not PlayerState.IsArmed(player) then
					player.CameraMinZoomDistance = defaultMinZoom
				end
			end)
		end
	end
	wasFirstPerson = armed
end

-- The server moves a new character to its spawn point and records that spawn in
-- the SpawnCFrame attribute. Once the move has reached this client, turn the
-- camera to the spawn's facing so the player starts looking into the map
-- (in first person the body turns to follow the camera).
local function faceSpawn(character)
	local spawnCFrame = character:GetAttribute("SpawnCFrame")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not spawnCFrame or not root then
		return
	end

	local waited = 0
	while (root.Position - spawnCFrame.Position).Magnitude > ARRIVE_DISTANCE and waited < ARRIVE_TIMEOUT do
		waited += task.wait()
	end
	task.wait() -- let the default camera finish its own setup for this character

	local camera = workspace.CurrentCamera
	local from = camera.CFrame.Position
	local look = spawnCFrame.LookVector
	camera.CFrame = CFrame.lookAt(from, from + Vector3.new(look.X, 0, look.Z))
end

local function onCharacterAdded(character)
	character:WaitForChild("HumanoidRootPart")
	if character:GetAttribute("SpawnCFrame") then
		task.spawn(faceSpawn, character)
	end
	character:GetAttributeChangedSignal("SpawnCFrame"):Connect(function()
		task.spawn(faceSpawn, character)
	end)
end

function CameraController.Start()
	defaultMinZoom = player.CameraMinZoomDistance
	PlayerState.OnArmedChanged(player, apply)
	apply()

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return CameraController
