-- RespawnService: the server decides when characters load (Players.CharacterAutoLoads
-- is off), so nobody is auto-respawned into the lobby in the middle of a match.
--   * Joining players get their first character in the lobby.
--   * Outside a match, a player who dies gets a new character after RespawnDelay.
--   * Match participants are loaded by MatchService (next round or back to the lobby).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchService = require(script.Parent.MatchService)

local RespawnService = {}

local function watch(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		task.wait(MatchConfig.RespawnDelay)
		-- still the same dead character, and not someone the match is handling
		if player.Parent and player.Character == character and not MatchService.IsInMatch(player) then
			player:LoadCharacter()
		end
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		watch(player, character)
	end)
	if player.Character then
		task.spawn(watch, player, player.Character)
	else
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

function RespawnService.Start()
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RespawnService
