-- CameraController: first person while the player is armed (in a match round or in
-- the practice room), normal third-person camera otherwise.
-- The server sets the attributes (see Shared.PlayerState); this script only reacts to them.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local CameraController = {}

local ARRIVE_DISTANCE = 8 -- studs; how close the character must be to the spawn before we turn the camera
local ARRIVE_TIMEOUT = 3 -- seconds
local CAMERA_ARRIVE_DISTANCE = 20 -- studs; the camera must also have caught up (third person sits further back)

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

-- Cover screen: while the player is being loaded into a round (MatchPhase
-- "Starting") or a server move has not reached this client yet, the camera can
-- still show the old place for a moment. A plain dark screen hides that; the
-- match HUD (higher DisplayOrder) still shows "ROUND n" on top of it.
local cover
local arrivalToken -- the latest faceSpawn call; older ones must not clear the cover

local function needsCover()
	if arrivalToken ~= nil then
		return true
	end
	local phase = player:GetAttribute("MatchPhase")
	if phase == "Starting" then
		return true
	end
	if phase == "Countdown" then
		-- the phase can reach this client a frame before the move does
		local character = player.Character
		local spawnCFrame = character and character:GetAttribute("SpawnCFrame")
		local camera = workspace.CurrentCamera
		return spawnCFrame == nil or camera == nil
			or (camera.CFrame.Position - spawnCFrame.Position).Magnitude > CAMERA_ARRIVE_DISTANCE
	end
	return false
end

local function updateCover()
	cover.Enabled = needsCover()
end

local function buildCover()
	cover = Instance.new("ScreenGui")
	cover.Name = "SpawnCover"
	cover.ResetOnSpawn = false
	cover.IgnoreGuiInset = true
	cover.DisplayOrder = -1
	cover.Enabled = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 17, 21)
	frame.BorderSizePixel = 0
	frame.Parent = cover
	cover.Parent = player:WaitForChild("PlayerGui")
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
	local token = {}
	arrivalToken = token
	updateCover()

	-- wait until both the character AND the camera are at the spawn: right after
	-- a new character loads, the camera can still be following the old one
	local camera = workspace.CurrentCamera
	local waited = 0
	while ((root.Position - spawnCFrame.Position).Magnitude > ARRIVE_DISTANCE
		or (camera.CFrame.Position - spawnCFrame.Position).Magnitude > CAMERA_ARRIVE_DISTANCE)
		and waited < ARRIVE_TIMEOUT do
		waited += task.wait()
		camera = workspace.CurrentCamera
	end
	task.wait() -- let the default camera finish its own setup for this character

	if arrivalToken == token and player.Character == character then
		camera = workspace.CurrentCamera
		local from = camera.CFrame.Position
		local look = spawnCFrame.LookVector
		camera.CFrame = CFrame.lookAt(from, from + Vector3.new(look.X, 0, look.Z))
	end
	if arrivalToken == token then
		arrivalToken = nil
		updateCover()
	end
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
	buildCover()
	-- checked every frame after the camera has moved, so the cover is never a frame late
	game:GetService("RunService"):BindToRenderStep("SpawnCover", Enum.RenderPriority.Last.Value, updateCover)
	player.CharacterRemoving:Connect(function()
		arrivalToken = nil -- a pending move belonged to the old character
		updateCover()
	end)
	defaultMinZoom = player.CameraMinZoomDistance
	PlayerState.OnArmedChanged(player, apply)
	apply()

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

return CameraController
