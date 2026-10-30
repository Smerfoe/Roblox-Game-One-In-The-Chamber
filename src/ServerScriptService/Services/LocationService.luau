-- LocationService: the single owner of where each player is. It sets the player
-- attribute Location = "Lobby" | "Practice" | "Match", and it is the only code
-- that moves players between the lobby and the practice room (same place, the
-- server pivots the character; no teleporting to another place).
--
--   Lobby -> Practice: a living lobby player walks into the lobby's PracticeEntrance
--     zone. They are taken off the queue and marked Practice before being moved,
--     with no yield in between, so matchmaking can never grab them halfway.
--     A player who is in a match (or was just put in one) is refused.
--   Practice -> Lobby: walking into PracticeArea's PracticeReturn zone (the LOBBY
--     door) moves them to the lobby's LobbyReturn marker. Dying or resetting in
--     practice also ends practice: RespawnService loads the new character in the
--     lobby and this service marks it Lobby.
--   Match: mirrors MatchService (MatchId set). MatchService.StartMatch and the
--     queue both refuse Practice players.
-- Zones are checked by root position on a timer, like the queue pads.
-- Markers: Lobby...PracticeEntrance, Lobby...LobbyReturn,
--          PracticeArea...PracticeSpawn, PracticeArea...PracticeReturn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PracticeConfig = require(ReplicatedStorage.Shared.Config.PracticeConfig)
local MatchService = require(script.Parent.MatchService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local LOG = RunService:IsStudio()
local LIFT = Vector3.new(0, 3, 0)

local LocationService = {}

local transferring = {} -- [player] = true while being moved (never left set: see transfer)
local lastTransfer = {} -- [player] = os.clock()

local function log(...)
	if LOG then
		print("[Location]", ...)
	end
end

local function setLocation(player, location)
	if player.Parent and player:GetAttribute("Location") ~= location then
		player:SetAttribute("Location", location)
		log(player.Name, "->", location)
	end
end

local function livingRoot(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character, character:FindFirstChild("HumanoidRootPart")
end

local function markers()
	local lobby = workspace:FindFirstChild("Lobby")
	local area = workspace:FindFirstChild("PracticeArea")
	return {
		entrance = lobby and lobby:FindFirstChild("PracticeEntrance", true),
		lobbyReturn = lobby and lobby:FindFirstChild("LobbyReturn", true),
		spawn = area and area:FindFirstChild("PracticeSpawn", true),
		exit = area and area:FindFirstChild("PracticeReturn", true),
	}
end

local function inside(zone, position)
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function place(character, point)
	character:PivotTo(point.CFrame + LIFT)
	character:SetAttribute("SpawnCFrame", point.CFrame) -- the client turns the camera to face it
end

-- Runs move() with the player marked as transferring; the mark is always cleared.
local function transfer(player, move)
	transferring[player] = true
	local ok, err = pcall(move)
	transferring[player] = nil
	lastTransfer[player] = os.clock()
	return ok, err
end

-- Returns true, or false and a reason. Never yields.
function LocationService.EnterPractice(player)
	if transferring[player] then
		return false, "already moving"
	end
	if lastTransfer[player] and os.clock() - lastTransfer[player] < PracticeConfig.TransferCooldown then
		return false, "cooldown"
	end
	if player:GetAttribute("Location") ~= "Lobby" then
		return false, "not in the lobby"
	end
	if MatchService.IsInMatch(player) or player:GetAttribute("MatchId") ~= nil then
		return false, "in a match" -- the match got them first
	end
	local character, root = livingRoot(player)
	if not root then
		return false, "not alive"
	end
	local spawnPoint = markers().spawn
	if not spawnPoint then
		warn("[Location] PracticeArea.PracticeSpawn missing; practice entry refused")
		return false, "practice spawn missing"
	end
	local ok, err = transfer(player, function()
		MatchmakingService.Release(player) -- off the queue first
		setLocation(player, "Practice") -- from here the queue and StartMatch refuse them
		place(character, spawnPoint)
	end)
	if not ok then
		setLocation(player, "Lobby")
		warn("[Location] practice entry failed for", player.Name, err)
		return false, "move failed"
	end
	return true
end

function LocationService.ReturnToLobby(player)
	if transferring[player] then
		return false, "already moving"
	end
	if player:GetAttribute("Location") ~= "Practice" then
		return false, "not in practice"
	end
	local character, root = livingRoot(player)
	local point = markers().lobbyReturn
	local ok, err = transfer(player, function()
		setLocation(player, "Lobby") -- LoadoutService takes the weapons, the camera goes third person
		if root and point then
			place(character, point)
		else
			task.spawn(function() -- no marker or no living character: a fresh lobby character
				player:LoadCharacter()
			end)
		end
	end)
	if not ok then
		warn("[Location] return to lobby failed for", player.Name, err)
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
	return ok
end

local function poll()
	local m = markers()
	for _, player in Players:GetPlayers() do
		if not transferring[player] then
			local _, root = livingRoot(player)
			if root then
				local location = player:GetAttribute("Location")
				if location == "Lobby" and m.entrance and inside(m.entrance, root.Position) then
					LocationService.EnterPractice(player)
				elseif location == "Practice" and m.exit and inside(m.exit, root.Position) then
					LocationService.ReturnToLobby(player)
				end
			end
		end
	end
end

local function onPlayerAdded(player)
	setLocation(player, player:GetAttribute("MatchId") and "Match" or "Lobby")
	player:GetAttributeChangedSignal("MatchId"):Connect(function()
		if player:GetAttribute("MatchId") ~= nil then
			setLocation(player, "Match")
		elseif player:GetAttribute("Location") == "Match" then
			setLocation(player, "Lobby")
		end
	end)
	player.CharacterAdded:Connect(function()
		-- practice moves never replace the character, so a new character outside a
		-- match is always a lobby character (RespawnService loads it there)
		if player:GetAttribute("Location") == "Practice" then
			setLocation(player, "Lobby")
		end
	end)
end

function LocationService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		transferring[player] = nil
		lastTransfer[player] = nil
	end)
	task.spawn(function()
		while true do
			poll()
			task.wait(PracticeConfig.ZonePollInterval)
		end
	end)
end

return LocationService
