-- MatchmakingService: the ONE queue. Lobby pads and the Play Game menu both put
-- players into the same server-owned queue for a mode (currently only 1v1 is
-- enabled). The server picks the teams; nobody chooses Blue or Red.
--
--   Joining:
--     * Menu: the client sends Remotes.Queue ("Join", modeId) / ("Leave").
--     * Pads: standing on either pad of a mode's station joins that mode's queue.
--       The pad colour is decoration only; it no longer decides the team.
--     * A player is in at most one queue, once. A second join (pad or menu) while
--       already queued is ignored, so pad + menu can never double-queue.
--   Leaving:
--     * Menu Leave, death, disconnect, entering practice, or being put in a match.
--     * A PAD-joined player also leaves when they step off the pads.
--       A MENU-joined player is not affected by pads.
--     * Pressing Leave while standing on a pad does not requeue them: the pads
--       ignore that player until they have stepped off all pads once.
--   Starting: when a mode's queue holds enough eligible players and the arena is
--     free, the longest-waiting players are shuffled and split into teams; the
--     match keeps those teams for every round (MatchService owns them).
--
-- Players see their state through attributes: Queue = mode id (or nil) and
-- QueueSource = "Pad" / "Menu". Rejected menu requests get a reply on the same
-- remote: ("Rejected", reason).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchService = require(script.Parent.MatchService)

local LOG = RunService:IsStudio()

local MatchmakingService = {}

local modes = {} -- [modeId] = mode config
local queues = {} -- [modeId] = { players in join order }
local members = {} -- [player] = { Mode = id, Source = "Pad"/"Menu" }
local padBlocked = {} -- [player] = true: left while on a pad; ignore pads until they step off
local stations = {} -- [modeId] = { pads = { part, ... }, label = TextLabel? }
local lastRequest = {} -- [player] = os.clock()
local random = Random.new()
local remote

local function log(...)
	if LOG then
		print("[Queue]", ...)
	end
end

local function standingOn(player, pad)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	local rel = pad.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= pad.Size.X / 2 and math.abs(rel.Z) <= pad.Size.Z / 2
		and rel.Y >= 0 and rel.Y <= MatchConfig.PadHeight
end

-- which enabled mode's pads the player is standing on, or nil
local function padModeOf(player)
	for modeId, station in stations do
		for _, pad in station.pads do
			if standingOn(player, pad) then
				return modeId
			end
		end
	end
	return nil
end

local function onAnyPad(player)
	for _, station in stations do
		for _, pad in station.pads do
			if standingOn(player, pad) then
				return true
			end
		end
	end
	return false
end

-- may this player be queued right now?
local function eligible(player)
	if not player.Parent or MatchService.IsInMatch(player) or player:GetAttribute("MatchId") ~= nil then
		return false, "You are in a match"
	end
	local location = player:GetAttribute("Location")
	if location ~= nil and location ~= "Lobby" then
		return false, "Return to the lobby to queue"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "Wait until you respawn"
	end
	return true
end

local function updateLabels()
	for modeId, station in stations do
		if station.label then
			local n = #queues[modeId]
			local needed = modes[modeId].TeamSize * 2
			local text
			if n == 0 then
				text = "STAND ON A PAD OR PRESS PLAY GAME"
			else
				text = ("%s QUEUE: %d / %d"):format(modeId, n, needed)
				if n >= needed and MatchService.IsBusy() then
					text ..= "   (arena busy)"
				end
			end
			station.label.Text = text
		end
	end
end

local function add(player, modeId, source)
	if members[player] then
		return false, "Already queued for " .. members[player].Mode
	end
	members[player] = { Mode = modeId, Source = source }
	table.insert(queues[modeId], player)
	player:SetAttribute("Queue", modeId)
	player:SetAttribute("QueueSource", source)
	log(player.Name, "joined", modeId, "via", source, ("(%d queued)"):format(#queues[modeId]))
	updateLabels()
	return true
end

local function remove(player, reason)
	local entry = members[player]
	if not entry then
		return false
	end
	members[player] = nil
	local list = queues[entry.Mode]
	local index = table.find(list, player)
	if index then
		table.remove(list, index)
	end
	if player.Parent then
		player:SetAttribute("Queue", nil)
		player:SetAttribute("QueueSource", nil)
	end
	log(player.Name, "left", entry.Mode, "(" .. reason .. ")")
	updateLabels()
	return true
end

local function shuffle(list)
	for i = #list, 2, -1 do
		local j = random:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function tryStart(modeId)
	local mode = modes[modeId]
	local list = queues[modeId]
	local needed = mode.TeamSize * 2
	if #list < needed or MatchService.IsBusy() then
		return
	end
	local picked = {}
	for i = 1, needed do
		picked[i] = list[i]
	end
	shuffle(picked) -- random, and with equal team sizes always balanced by count
	for _, player in picked do
		remove(player, "match found")
	end
	if mode.TeamSize == 1 then
		local match = MatchService.StartMatch(picked[1], picked[2])
		if not match then
			log("StartMatch refused", picked[1].Name, picked[2].Name)
		end
	end
	-- team sizes above 1 are not enabled yet (MatchService is 1v1 only)
end

local function poll()
	-- drop anyone who stopped being eligible, and pad players who stepped off
	for player, entry in members do
		if not eligible(player) then
			remove(player, "not eligible")
		elseif entry.Source == "Pad" and padModeOf(player) ~= entry.Mode then
			remove(player, "stepped off the pad")
		end
	end
	-- pads: join anyone eligible standing on one (unless they pressed Leave there)
	for _, player in Players:GetPlayers() do
		if padBlocked[player] then
			if not onAnyPad(player) then
				padBlocked[player] = nil
			end
		elseif not members[player] and eligible(player) then
			local modeId = padModeOf(player)
			if modeId then
				add(player, modeId, "Pad")
			end
		end
	end
	for modeId in queues do
		tryStart(modeId)
	end
	updateLabels()
end

local function onRequest(player, action, modeId)
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < MatchConfig.QueueRequestCooldown then
		remote:FireClient(player, "Rejected", "Too fast - try again")
		return
	end
	lastRequest[player] = now
	if action == "Join" then
		if type(modeId) ~= "string" or not modes[modeId] then
			remote:FireClient(player, "Rejected", "That mode is not available yet")
			return
		end
		local ok, why = eligible(player)
		if not ok then
			remote:FireClient(player, "Rejected", why)
			return
		end
		ok, why = add(player, modeId, "Menu")
		if not ok then
			remote:FireClient(player, "Rejected", why)
		end
	elseif action == "Leave" then
		if remove(player, "left") and onAnyPad(player) then
			padBlocked[player] = true -- standing on a pad: don't requeue until they step off
		end
	end
end

-- Takes a player off the queue right away (used before moving them to practice).
function MatchmakingService.Release(player)
	remove(player, "released")
end

function MatchmakingService.GetQueue(modeId)
	return table.clone(queues[modeId] or {})
end

function MatchmakingService.Start()
	for _, mode in MatchConfig.Modes do
		if mode.Enabled then
			modes[mode.Id] = mode
			queues[mode.Id] = {}
			local station = workspace:FindFirstChild(mode.Station, true)
			local pads = {}
			if station then
				for _, name in { "BLUE_TeamPad", "RED_TeamPad" } do
					local pad = station:FindFirstChild(name)
					if pad then
						table.insert(pads, pad)
					end
				end
			end
			local queueLabel = station and station:FindFirstChild("Queue_Label")
			local gui = queueLabel and queueLabel:FindFirstChildOfClass("SurfaceGui")
			stations[mode.Id] = { pads = pads, label = gui and gui:FindFirstChildOfClass("TextLabel") }
			if #pads == 0 then
				warn("[Queue] no pads found for", mode.Id, "- menu queueing only")
			end
		end
	end

	remote = ReplicatedStorage.Remotes:FindFirstChild("Queue")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Queue"
		remote.Parent = ReplicatedStorage.Remotes
	end
	remote.OnServerEvent:Connect(onRequest)

	Players.PlayerRemoving:Connect(function(player)
		remove(player, "disconnected")
		padBlocked[player] = nil
		lastRequest[player] = nil
	end)
	task.spawn(function()
		while true do
			poll()
			task.wait(MatchConfig.QueuePollInterval)
		end
	end)
end

return MatchmakingService
