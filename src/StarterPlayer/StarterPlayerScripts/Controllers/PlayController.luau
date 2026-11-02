-- PlayController: the Play Game / Modes screen (MenuController menu "Play").
--   * Four mode cards; only modes the server has enabled (MatchConfig.Modes)
--     can be selected. The others say COMING SOON.
--   * QUEUE FOR MATCH / LEAVE QUEUE send a request to the server's single queue
--     (the same queue the lobby pads use). The server decides; this screen only
--     shows the result: the Queue / QueueSource attributes, or a rejection.
--   * No team choice: the server assigns teams when the match starts.
--   * No fake wait times or player counts.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local Icons = require(UI.Icons)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local new = Components.new
local C = Theme.Color

local MENU = "Play"
local CLOSE_ACTION = "PlayClose"
local PENDING_TIMEOUT = 4 -- seconds before a silent request is treated as failed

local PlayController = {}

local remote
local panel, statusLabel, queueButton
local cards = {} -- [modeId] = { frame, mode }
local selected -- mode id
local pending = nil -- { action, since }
local rejection = nil -- { text, untilTime }

local function modeText(mode)
	return ("%d vs %d  -  best of five"):format(mode.TeamSize, mode.TeamSize)
end

local function refresh()
	if not panel then
		return
	end
	local queued = player:GetAttribute("Queue")
	local source = player:GetAttribute("QueueSource")
	if pending and (os.clock() - pending.since > PENDING_TIMEOUT
		or (pending.action == "Join" and queued) or (pending.action == "Leave" and not queued)) then
		if os.clock() - pending.since > PENDING_TIMEOUT then
			rejection = { text = "No answer from the server - try again", untilTime = os.clock() + 4 }
		end
		pending = nil
	end
	for modeId, card in cards do
		local stroke = card.frame:FindFirstChildOfClass("UIStroke")
		local isSelected = modeId == selected
		stroke.Color = isSelected and C.Accent or C.Border
		stroke.Thickness = isSelected and 3 or 1
	end

	local text, color = "Choose a mode and queue. Teams are assigned by the server.", C.TextSecondary
	if pending then
		text = pending.action == "Join" and "Joining queue..." or "Leaving queue..."
	elseif rejection and os.clock() < rejection.untilTime then
		text, color = "Couldn't do that: " .. rejection.text, C.Red
	elseif queued then
		text = ("In the %s queue (%s) - waiting for an opponent"):format(queued, source == "Pad" and "joined on a pad" or "joined here")
		color = C.Text
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = color

	if pending then
		queueButton.Text = "PLEASE WAIT"
		Components.applyStyle(queueButton, "disabled")
	elseif queued then
		queueButton.Text = "LEAVE QUEUE"
		Components.applyStyle(queueButton, "secondary")
	else
		queueButton.Text = "QUEUE FOR MATCH"
		Components.applyStyle(queueButton, selected and "primary" or "disabled")
	end
end

local function send(action, modeId)
	if pending then
		return -- one request at a time; no duplicate joins from rapid clicks
	end
	pending = { action = action, since = os.clock() }
	rejection = nil
	remote:FireServer(action, modeId)
	refresh()
end

local function buildCard(parent, mode, order)
	local frame = new("TextButton", {
		Name = mode.Id,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = mode.Enabled,
		BackgroundColor3 = mode.Enabled and C.Panel or C.Background,
		Parent = parent,
	}, { Components.corner(), Components.stroke() })
	local icon = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Icons.draw("Modes", icon, mode.Enabled and C.Text or C.TextDisabled, C.Panel)
	Components.label(frame, {
		Text = mode.Id,
		Font = Theme.Font.Bold,
		TextSize = 40,
		TextColor3 = mode.Enabled and C.Text or C.TextDisabled,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 100),
		Size = UDim2.new(1, 0, 0, 46),
	})
	Components.label(frame, {
		Text = mode.Enabled and modeText(mode) or "COMING SOON",
		TextSize = Theme.TextSize.Small,
		TextColor3 = mode.Enabled and C.TextSecondary or C.Warning,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 0, 150),
		Size = UDim2.new(1, 0, 0, 18),
	})
	cards[mode.Id] = { frame = frame, mode = mode }
	if mode.Enabled then
		frame.Activated:Connect(function()
			if not player:GetAttribute("Queue") then
				selected = mode.Id
				refresh()
			end
		end)
	end
end

local function build()
	local gui = Components.screenGui("PlayGui", 10)
	panel = Components.menuPanel(gui, { Name = "Play", Title = "PLAY GAME", Width = 860, Height = 420 })
	panel.Close.Activated:Connect(function()
		MenuController.Close(MENU)
	end)
	Components.label(panel.Tabs, {
		Text = "SELECT A MODE",
		TextColor3 = C.TextSecondary,
		TextSize = Theme.TextSize.Secondary,
		Size = UDim2.new(1, 0, 1, 0),
	})
	local grid = new("Frame", {
		Name = "Modes",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 200),
		Parent = panel.Content,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.new(0.25, -12, 1, 0),
			CellPadding = UDim2.fromOffset(Theme.Space.M, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, mode in MatchConfig.Modes do
		buildCard(grid, mode, index)
		if mode.Enabled and not selected then
			selected = mode.Id
		end
	end

	statusLabel = Components.label(panel.Content, {
		Name = "Status",
		TextWrapped = true,
		TextSize = Theme.TextSize.Secondary,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -360, 0, 44),
	})
	local back = Components.button(panel.Content, {
		Name = "Back",
		Text = "BACK",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -196, 1, 0),
		Size = UDim2.fromOffset(140, 44),
	})
	back.Activated:Connect(function()
		MenuController.Close(MENU)
	end)
	queueButton = Components.button(panel.Content, {
		Name = "Queue",
		Text = "QUEUE FOR MATCH",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(180, 44),
	})
	queueButton.Activated:Connect(function()
		if queueButton:GetAttribute("Style") == "disabled" then
			return
		end
		if player:GetAttribute("Queue") then
			send("Leave")
		elseif selected then
			send("Join", selected)
		end
	end)
end

function PlayController.Start()
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Queue")
	build()
	remote.OnClientEvent:Connect(function(kind, reason)
		if kind == "Rejected" then
			pending = nil
			rejection = { text = tostring(reason), untilTime = os.clock() + 4 }
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("Queue"):Connect(refresh)
	MenuController.Register(MENU, {
		Open = function()
			panel.Frame.Visible = true
			ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
				if state == Enum.UserInputState.Begin then
					MenuController.Close(MENU)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.ButtonB)
			refresh()
		end,
		Close = function()
			panel.Frame.Visible = false
			ContextActionService:UnbindAction(CLOSE_ACTION)
		end,
	})
	-- keep pending / rejection timers honest while the screen is open
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.Frame.Visible then
				refresh()
			end
		end
	end)
end

return PlayController
