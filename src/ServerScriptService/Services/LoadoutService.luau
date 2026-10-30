-- LoadoutService: gives the pistol and the knife to armed players (in a match round,
-- or in the practice room; see Shared.PlayerState) and takes them away when that
-- ends. The pistol is equipped when the loadout is given.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local PlayerState = require(ReplicatedStorage.Shared.PlayerState)

local PISTOL_NAME = WeaponConfig.Pistol.ToolName
local LOADOUT = { PISTOL_NAME, WeaponConfig.Knife.ToolName }

local LoadoutService = {}

local function owns(player, toolName)
	local character = player.Character
	return player.Backpack:FindFirstChild(toolName) ~= nil
		or (character ~= nil and character:FindFirstChild(toolName) ~= nil)
end

local function removeLoadout(player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		for _, toolName in LOADOUT do
			local tool = container and container:FindFirstChild(toolName)
			if tool then
				tool:Destroy()
			end
		end
	end
end

local function giveLoadout(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 or not PlayerState.IsArmed(player) then
		return
	end
	local hadPistol = owns(player, PISTOL_NAME)
	for _, toolName in LOADOUT do
		if not owns(player, toolName) then
			local template = ReplicatedStorage.Assets.Weapons:FindFirstChild(toolName)
			if template then
				template:Clone().Parent = player.Backpack
			else
				warn(`[Loadout] {toolName} not found in ReplicatedStorage.Assets.Weapons`)
			end
		end
	end
	if not hadPistol then
		local pistol = player.Backpack:FindFirstChild(PISTOL_NAME)
		if pistol then
			humanoid:EquipTool(pistol)
		end
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		task.wait() -- let Roblox finish resetting the Backpack for the new life
		giveLoadout(player)
	end)
	PlayerState.OnArmedChanged(player, function()
		if PlayerState.IsArmed(player) then
			giveLoadout(player)
		else
			removeLoadout(player)
		end
	end)
end

function LoadoutService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return LoadoutService
