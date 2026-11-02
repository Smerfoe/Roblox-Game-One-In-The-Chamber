-- HudController: the HUD.
--   In a match (InMatch): crosshair and ammo count.
--   Any time: one centre message for the queue, countdown and match result,
--   driven by attributes the server sets on the player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local PlayerState = require(game:GetService("ReplicatedStorage").Shared.PlayerState)

local HudController = {}

local gui, combatFrame, ammoLabel, message, subMessage, scoreLabel
local fightShownUntil = 0
local lastPhase

local ROUND_TEXT = {
	Won = { "ROUND WON", Color3.fromRGB(110, 200, 255) },
	Lost = { "ROUND LOST", Color3.fromRGB(255, 110, 110) },
	Draw = { "ROUND DRAW", Color3.new(1, 1, 1) },
}

local RESULT_TEXT = {
	Victory = { "VICTORY", Color3.fromRGB(110, 200, 255) },
	Defeat = { "DEFEAT", Color3.fromRGB(255, 110, 110) },
	Draw = { "DRAW", Color3.new(1, 1, 1) },
	Cancelled = { "MATCH CANCELLED", Color3.new(1, 1, 1) },
}

local function textLabel(name, parent, size, position, textSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = position
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Text = ""
	l.Parent = parent
	return l
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "MatchHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	combatFrame = Instance.new("Frame")
	combatFrame.Name = "Combat"
	combatFrame.Size = UDim2.fromScale(1, 1)
	combatFrame.BackgroundTransparency = 1
	combatFrame.Parent = gui

	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.fromScale(0.5, 0.5)
	crosshair.Size = UDim2.fromOffset(4, 4)
	crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
	crosshair.BorderSizePixel = 0
	crosshair.Parent = combatFrame

	ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "Ammo"
	ammoLabel.AnchorPoint = Vector2.new(1, 1)
	ammoLabel.Position = UDim2.new(1, -32, 1, -32)
	ammoLabel.Size = UDim2.fromOffset(160, 48)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.TextSize = 32
	ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	ammoLabel.TextStrokeTransparency = 0.6
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
	ammoLabel.Parent = combatFrame

	message = textLabel("Message", gui, UDim2.fromOffset(600, 80), UDim2.fromScale(0.5, 0.3), 56)
	subMessage = textLabel("SubMessage", gui, UDim2.fromOffset(700, 40), UDim2.new(0.5, 0, 0.3, 52), 22)
	scoreLabel = textLabel("Score", gui, UDim2.fromOffset(500, 36), UDim2.new(0.5, 0, 0, 34), 24)

	gui.Parent = player:WaitForChild("PlayerGui")
end

local function refreshCombat()
	combatFrame.Visible = PlayerState.IsArmed(player)
	local ammo = player:GetAttribute("Ammo") or 0
	ammoLabel.Text = "AMMO  " .. ammo
	ammoLabel.TextColor3 = ammo > 0 and Color3.new(1, 1, 1) or Color3.fromRGB(255, 90, 90)
end

local function refreshMessage()
	local phase = player:GetAttribute("MatchPhase")
	local remaining = math.max(0, (player:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
	local text, sub, color = "", "", Color3.new(1, 1, 1)

	if phase ~= lastPhase then
		if phase == "Combat" then
			fightShownUntil = os.clock() + 1
		end
		lastPhase = phase
	end

	if phase then
		scoreLabel.Text = ("BLUE  %d  -  %d  RED      Round %d"):format(
			player:GetAttribute("ScoreBlue") or 0, player:GetAttribute("ScoreRed") or 0, player:GetAttribute("Round") or 1)
	else
		scoreLabel.Text = ""
	end

	if phase == "Starting" then
		text = "ROUND " .. tostring(player:GetAttribute("Round") or 1)
		sub = "Team " .. tostring(player:GetAttribute("Team"))
	elseif phase == "Countdown" then
		text = tostring(math.max(1, math.ceil(remaining)))
		sub = "Round " .. tostring(player:GetAttribute("Round") or 1) .. "  -  Team " .. tostring(player:GetAttribute("Team"))
	elseif phase == "RoundEnd" then
		local result = ROUND_TEXT[player:GetAttribute("RoundResult") or ""]
		if result then
			text, color = result[1], result[2]
		end
		sub = "Next round starting..."
	elseif phase == "Combat" then
		if os.clock() < fightShownUntil then
			text = "FIGHT"
		end
		sub = ("%d:%02d"):format(math.floor(remaining / 60), math.floor(remaining % 60))
	elseif phase == "Result" then
		local result = RESULT_TEXT[player:GetAttribute("MatchResult") or ""]
		if result then
			text, color = result[1], result[2]
		end
		sub = "Returning to lobby..."
	elseif player:GetAttribute("Location") == "Practice" then
		sub = "PRACTICE  -  reset station restores targets and ammo  -  LOBBY door to leave"
	elseif player:GetAttribute("Queue") then
		sub = "Queued: " .. player:GetAttribute("Queue") .. " - waiting for an opponent"
	end
	message.Text = text
	message.TextColor3 = color
	subMessage.Text = sub
end

function HudController.Start()
	build()
	PlayerState.OnArmedChanged(player, refreshCombat)
	player:GetAttributeChangedSignal("Ammo"):Connect(refreshCombat)
	refreshCombat()
	RunService.Heartbeat:Connect(refreshMessage)
end

return HudController
