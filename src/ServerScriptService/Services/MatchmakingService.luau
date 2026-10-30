-- MatchmakingService: the lobby's 1v1 pads. A player standing on the Blue or Red
-- pad holds that side's slot; stepping off, dying or leaving frees it. When both
-- slots hold two different players and the arena is free, the match starts.
-- The pads are checked on a timer (not Touched events) so the queue always
-- reflects who is actually standing there, and a player can hold only one slot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local MatchService = require(script.Parent.MatchService)

local LOG = RunService:IsStudio()
local SIDES = { "Blue", "Red" }

local MatchmakingService = {}

local pads = {} -- [side] = pad part
local label -- the station's queue text
local slots = {} -- [side] = player

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

local function setSlot(side, player)
	local old = slots[side]
	if old == player then
		return
	end
	if old and old.Parent then
		old:SetAttribute("Queue", nil)
	end
	slots[side] = player
	if player then
		player:SetAttribute("Queue", "1v1 " .. side)
	end
	log(side, "slot:", old and old.Name or "empty", "->", player and player.Name or "empty")
end

local function updateLabel()
	if not label then
		return
	end
	local blue = slots.Blue and slots.Blue.Name or "open"
	local red = slots.Red and slots.Red.Name or "open"
	local text = ("BLUE: %s   |   RED: %s"):format(blue, red)
	if slots.Blue and slots.Red and MatchService.IsBusy() then
		text ..= "   (arena busy)"
	elseif not slots.Blue and not slots.Red then
		text = "STAND ON A TEAM PAD"
	end
	label.Text = text
end

local function poll()
	-- free slots whose player stepped off, died, left or got into a match
	for _, side in SIDES do
		local player = slots[side]
		if player and (not player.Parent or MatchService.IsInMatch(player) or player:GetAttribute("Location") == "Practice"
			or not standingOn(player, pads[side])) then
			setSlot(side, nil)
		end
	end
	-- fill empty slots
	for _, player in Players:GetPlayers() do
		if not MatchService.IsInMatch(player) and player:GetAttribute("MatchId") == nil
			and player:GetAttribute("Location") ~= "Practice"
			and slots.Blue ~= player and slots.Red ~= player then
			for _, side in SIDES do
				if not slots[side] and standingOn(player, pads[side]) then
					setSlot(side, player)
					break
				end
			end
		end
	end
	-- start when both sides hold different players and the arena is free
	local blue, red = slots.Blue, slots.Red
	if blue and red and blue ~= red and not MatchService.IsBusy() then
		setSlot("Blue", nil)
		setSlot("Red", nil)
		MatchService.StartMatch(blue, red)
	end
	updateLabel()
end

-- Takes a player off the queue right away (used before moving them to practice).
function MatchmakingService.Release(player)
	for _, side in SIDES do
		if slots[side] == player then
			setSlot(side, nil)
		end
	end
	updateLabel()
end

function MatchmakingService.GetSlots()
	return slots.Blue, slots.Red
end

function MatchmakingService.Start()
	local station = workspace:FindFirstChild("1v1_Station", true)
	pads.Blue = station and station:FindFirstChild("BLUE_TeamPad")
	pads.Red = station and station:FindFirstChild("RED_TeamPad")
	if not pads.Blue or not pads.Red then
		warn("[Queue] 1v1 pads not found; matchmaking is off")
		return
	end
	local queueLabel = station:FindFirstChild("Queue_Label")
	local gui = queueLabel and queueLabel:FindFirstChildOfClass("SurfaceGui")
	label = gui and gui:FindFirstChildOfClass("TextLabel")

	Players.PlayerRemoving:Connect(function(player)
		for _, side in SIDES do
			if slots[side] == player then
				setSlot(side, nil)
			end
		end
	end)
	task.spawn(function()
		while true do
			poll()
			task.wait(MatchConfig.QueuePollInterval)
		end
	end)
end

return MatchmakingService
