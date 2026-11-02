-- WeaponController: turns the player's click into a fire request.
-- It only sends the aim direction; the server decides whether the shot happens
-- and what it hits. The local checks just avoid sending pointless requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local FireRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fire")

local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local WeaponController = {}

local lastShot = 0

function WeaponController.TryFire()
	if not PlayerState.IsArmed(player) then
		return false
	end
	local character = player.Character
	if not character or not character:FindFirstChild(WeaponConfig.Pistol.ToolName) then
		return false -- pistol not equipped
	end
	if (player:GetAttribute("Ammo") or 0) < 1 then
		return false
	end
	local now = os.clock()
	if now - lastShot < WeaponConfig.Pistol.FireCooldown then
		return false
	end
	lastShot = now
	FireRemote:FireServer(workspace.CurrentCamera.CFrame.LookVector)
	return true
end

function WeaponController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			WeaponController.TryFire()
		end
	end)
end

return WeaponController
