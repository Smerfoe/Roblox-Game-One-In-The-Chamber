-- KnifeController: turns a click into a swing request while the knife is held.
-- The request carries no data; the server decides if and what it hits.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local MeleeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Melee")

local KNIFE = WeaponConfig.Knife
local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local KnifeController = {}

local lastSwing = 0

function KnifeController.TrySwing()
	if not PlayerState.IsArmed(player) then
		return false
	end
	local character = player.Character
	if not character or not character:FindFirstChild(KNIFE.ToolName) then
		return false
	end
	local now = os.clock()
	if now - lastSwing < KNIFE.Cooldown then
		return false
	end
	lastSwing = now
	MeleeRemote:FireServer()
	return true
end

function KnifeController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			KnifeController.TrySwing()
		end
	end)
end

return KnifeController
