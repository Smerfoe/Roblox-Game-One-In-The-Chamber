-- MatchService: owns every match. The server alone decides who is in a match,
-- which team they are on, the round, the score, the phase and the winner.
-- Players see this through attributes the server sets on them:
--   MatchId, Team, Round, ScoreBlue, ScoreRed, MatchPhase, PhaseEndsAt (server time),
--   RoundResult (Won/Lost/Draw), MatchResult (Victory/Defeat/Draw/Cancelled), InMatch.
-- InMatch means "alive in the current round and holding weapons".
--
-- Phases per round: Starting (loading players) -> Countdown -> Combat -> RoundEnd,
-- then the next round, or Result -> back to the lobby when a team has won.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local LOG = RunService:IsStudio()
local SPAWN_LIFT = Vector3.new(0, 3, 0)
local PLACEMENT_TIMEOUT = 15 -- seconds to load everyone into the arena before giving up
local CLEAR_ATTRIBUTES = { "MatchId", "Team", "Round", "ScoreBlue", "ScoreRed", "MatchPhase", "PhaseEndsAt", "RoundResult", "MatchResult" }

local MatchService = {}

local active -- the match using the arena, or nil
local playerMatch = {} -- [player] = match
local matchCount = 0

local function log(...)
	if LOG then
		print("[Match]", ...)
	end
end

local function otherTeam(team)
	return team == "Blue" and "Red" or "Blue"
end

local function setPhase(match, phase, duration)
	match.phase = phase
	local endsAt = duration and (workspace:GetServerTimeNow() + duration) or 0
	for player in match.teams do
		if player.Parent then
			player:SetAttribute("MatchPhase", phase)
			player:SetAttribute("PhaseEndsAt", endsAt)
		end
	end
	log(match.id, "round", match.round, "phase", phase)
end

local function publishScore(match)
	for player in match.teams do
		if player.Parent then
			player:SetAttribute("Round", match.round)
			player:SetAttribute("ScoreBlue", match.score.Blue)
			player:SetAttribute("ScoreRed", match.score.Red)
		end
	end
end

local function clearPlayer(player)
	playerMatch[player] = nil
	if player.Parent then
		player:SetAttribute("InMatch", false)
		for _, name in CLEAR_ATTRIBUTES do
			player:SetAttribute(name, nil)
		end
	end
end

local function disconnectRound(match)
	for _, connection in match.roundConnections do
		connection:Disconnect()
	end
	table.clear(match.roundConnections)
end

local function spawnPoints(team)
	local map = workspace:FindFirstChild(MatchConfig.Map)
	local folder = map and map:FindFirstChild("Spawns") and map.Spawns:FindFirstChild(team)
	local points = folder and folder:GetChildren() or {}
	table.sort(points, function(a, b)
		return a.Name < b.Name
	end)
	return points
end

local function leader(match)
	if match.score.Blue > match.score.Red then
		return "Blue"
	elseif match.score.Red > match.score.Blue then
		return "Red"
	end
	return nil
end

-- Everyone goes back to the lobby with a fresh character and no match state.
local function closeMatch(match)
	if match.phase == "Closed" then
		return
	end
	match.phase = "Closed"
	match.roundToken = nil
	disconnectRound(match)
	for player in match.teams do
		clearPlayer(player)
		if player.Parent then
			task.spawn(function()
				player:LoadCharacter() -- spawns at the lobby's only SpawnLocation
			end)
		end
	end
	if active == match then
		active = nil
	end
	log(match.id, "closed; players returned to lobby")
end

-- Ends the whole match exactly once. winnerTeam nil = no winner (draw or cancelled).
local function finishMatch(match, winnerTeam, reason)
	if match.phase == "Result" or match.phase == "Closed" then
		return -- already finished: a second call never changes the winner
	end
	match.winner = winnerTeam
	match.roundToken = nil -- any pending round timers are now stale
	setPhase(match, "Result", MatchConfig.ResultTime)
	publishScore(match)
	for player, team in match.teams do
		if player.Parent then
			local result
			if winnerTeam then
				result = team == winnerTeam and "Victory" or "Defeat"
			else
				result = reason == "cancelled" and "Cancelled" or "Draw"
			end
			player:SetAttribute("MatchResult", result)
			player:SetAttribute("InMatch", false) -- weapons away, combat over
		end
	end
	log(match.id, "MATCH RESULT:", winnerTeam and (winnerTeam .. " wins") or "no winner",
		("(%s) %d-%d"):format(reason, match.score.Blue, match.score.Red))
	task.delay(MatchConfig.ResultTime, closeMatch, match)
end

local startRound -- defined below

-- Ends the current round exactly once and decides what happens next.
local function endRound(match, winnerTeam, reason)
	if match.phase ~= "Combat" and match.phase ~= "Countdown" then
		return
	end
	match.roundToken = {} -- invalidates this round's timers and death handlers
	if winnerTeam then
		match.score[winnerTeam] += 1
	end
	setPhase(match, "RoundEnd", MatchConfig.RoundEndTime)
	publishScore(match)
	for player, team in match.teams do
		if player.Parent then
			player:SetAttribute("RoundResult", winnerTeam == nil and "Draw" or (team == winnerTeam and "Won" or "Lost"))
			player:SetAttribute("InMatch", false) -- weapons away between rounds
		end
	end
	log(match.id, "round", match.round, "result:", winnerTeam and (winnerTeam .. " wins") or "draw",
		("(%s) score %d-%d"):format(reason, match.score.Blue, match.score.Red))

	if winnerTeam and match.score[winnerTeam] >= MatchConfig.RoundsToWin then
		finishMatch(match, winnerTeam, ("first to %d"):format(MatchConfig.RoundsToWin))
	elseif match.round >= MatchConfig.MaxRounds then
		finishMatch(match, leader(match), "round limit")
	else
		local token = match.roundToken
		task.delay(MatchConfig.RoundEndTime, function()
			if match.phase == "RoundEnd" and match.roundToken == token then
				startRound(match)
			end
		end)
	end
end

local function aliveCount(match, team)
	local n = 0
	for player, t in match.teams do
		if t == team and match.alive[player] then
			n += 1
		end
	end
	return n
end

-- Decide the round from who is still alive. Runs deferred after a death so that
-- deaths in the same moment are counted together (both out = drawn round).
local function evaluate(match, token)
	if match.phase ~= "Combat" or match.roundToken ~= token then
		return
	end
	local blue, red = aliveCount(match, "Blue"), aliveCount(match, "Red")
	if blue == 0 and red == 0 then
		endRound(match, nil, "both eliminated")
	elseif blue == 0 then
		endRound(match, "Red", "elimination")
	elseif red == 0 then
		endRound(match, "Blue", "elimination")
	end
end

local function onDeath(match, player, token)
	if match.roundToken ~= token or not match.alive[player] then
		return -- a death from an earlier round, or already counted
	end
	match.alive[player] = nil
	if player.Parent then
		player:SetAttribute("InMatch", false)
	end
	log(match.id, player.Name, "was eliminated in round", match.round)
	if match.phase == "Combat" then
		task.defer(evaluate, match, token)
	elseif match.phase == "Countdown" or match.phase == "Starting" then
		if match.round == 1 then
			finishMatch(match, nil, "cancelled") -- nobody has played yet
		elseif match.phase == "Countdown" then
			endRound(match, otherTeam(match.teams[player]), "died before the round started")
		end
	end
end

local function beginCombat(match, token)
	if match.phase ~= "Countdown" or match.roundToken ~= token then
		return
	end
	setPhase(match, "Combat", MatchConfig.RoundTime)
	task.delay(MatchConfig.RoundTime, function()
		if match.phase ~= "Combat" or match.roundToken ~= token then
			return
		end
		local blue, red = aliveCount(match, "Blue"), aliveCount(match, "Red")
		endRound(match, blue > red and "Blue" or (red > blue and "Red" or nil), "timeout")
	end)
end

-- Load one participant into the arena at their team spawn for this round.
local function placePlayer(match, player, team, token)
	player:LoadCharacter()
	if match.roundToken ~= token or match.phase ~= "Starting" or not player.Parent then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local points = spawnPoints(team)
	local point = points[1]
	if not humanoid or not point then
		return -- the placement timeout handles it
	end
	task.wait() -- let Roblox finish its own spawn placement first
	if match.roundToken ~= token then
		return
	end
	character:PivotTo(point.CFrame + SPAWN_LIFT)
	character:SetAttribute("SpawnCFrame", point.CFrame) -- the client turns the camera to face the map
	match.alive[player] = true
	table.insert(match.roundConnections, humanoid.Died:Connect(function()
		onDeath(match, player, token)
	end))
	player:SetAttribute("InMatch", true) -- LoadoutService hands out the weapons
	-- the countdown starts only when everyone is in the arena, however long loading took
	match.placed += 1
	if match.placed == match.size and match.phase == "Starting" then
		setPhase(match, "Countdown", MatchConfig.CountdownTime)
		task.delay(MatchConfig.CountdownTime, beginCombat, match, token)
	end
end

startRound = function(match)
	if match.phase == "Result" or match.phase == "Closed" then
		return
	end
	disconnectRound(match)
	local token = {}
	match.roundToken = token
	match.round += 1
	match.placed = 0
	match.alive = {}
	for player in match.teams do
		if player.Parent then
			player:SetAttribute("RoundResult", nil)
		end
	end
	setPhase(match, "Starting")
	publishScore(match)
	for player, team in match.teams do
		task.spawn(placePlayer, match, player, team, token)
	end
	task.delay(PLACEMENT_TIMEOUT, function()
		if match.phase == "Starting" and match.roundToken == token then
			if match.round == 1 then
				finishMatch(match, nil, "cancelled")
			else
				finishMatch(match, leader(match), "players could not be loaded")
			end
		end
	end)
end

local function onLeave(match, player)
	if match.phase == "Result" or match.phase == "Closed" then
		return
	end
	match.alive[player] = nil
	log(match.id, player.Name, "left the game in round", match.round)
	if match.round == 1 and (match.phase == "Starting" or match.phase == "Countdown") then
		finishMatch(match, nil, "cancelled") -- nobody has played yet
	else
		finishMatch(match, otherTeam(match.teams[player]), "opponent left")
	end
end

function MatchService.IsBusy()
	return active ~= nil
end

function MatchService.IsInMatch(player)
	return playerMatch[player] ~= nil
end

function MatchService.GetMatch(player)
	return playerMatch[player]
end

-- Starts a best-of-five 1v1 between two different players who are not in a match.
function MatchService.StartMatch(bluePlayer, redPlayer)
	if active or bluePlayer == redPlayer or playerMatch[bluePlayer] or playerMatch[redPlayer] then
		return nil
	end
	if bluePlayer:GetAttribute("Location") == "Practice" or redPlayer:GetAttribute("Location") == "Practice" then
		return nil -- someone walked into the practice room first; LocationService owns that
	end
	matchCount += 1
	local match = {
		id = ("M%d-%s"):format(matchCount, HttpService:GenerateGUID(false):sub(1, 8)),
		teams = { [bluePlayer] = "Blue", [redPlayer] = "Red" },
		score = { Blue = 0, Red = 0 },
		round = 0,
		alive = {},
		phase = "Starting",
		roundConnections = {},
		placed = 0,
		size = 2,
	}
	active = match
	for player, team in match.teams do
		playerMatch[player] = match
		player:SetAttribute("MatchId", match.id)
		player:SetAttribute("Team", team)
		player:SetAttribute("MatchResult", nil)
	end
	log(match.id, "started:", bluePlayer.Name, "(Blue) vs", redPlayer.Name, "(Red)")
	startRound(match)
	return match
end

-- Server-side combat rules. TestMode keeps the old free-for-all practice rules.
function MatchService.CanAttack(player)
	if DevConfig.TestMode then
		return player:GetAttribute("InMatch") == true
	end
	local match = playerMatch[player]
	return match ~= nil and match.phase == "Combat" and match.alive[player] == true
end

function MatchService.CanDamage(attacker, humanoid)
	local model = humanoid.Parent
	local target = Players:GetPlayerFromCharacter(model)
	if DevConfig.TestMode then
		if target then
			return target:GetAttribute("InMatch") == true
		end
		return model ~= nil and model:GetAttribute("InMatch") == true
	end
	if not target then
		return false -- outside test mode only players can be damaged
	end
	local match = playerMatch[attacker]
	return match ~= nil
		and match.phase == "Combat"
		and playerMatch[target] == match
		and match.alive[target] == true
		and match.teams[attacker] ~= match.teams[target]
end

function MatchService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local match = playerMatch[player]
		if match then
			onLeave(match, player)
			playerMatch[player] = nil
		end
	end)
end

return MatchService
