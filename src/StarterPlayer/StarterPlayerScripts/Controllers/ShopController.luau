-- ShopController: the lobby shop menu.
--   * Opens when the local player's character walks into Lobby ... 03_Shop.ShopZone,
--     closes when they walk out. Position is checked every frame against the
--     zone box (not Touched events) with a margin, so standing on the edge
--     does not make the menu flicker.
--   * The X button (or B on a controller) closes it and keeps it closed until
--     the player has left the shop and come back in.
--   * Only for living lobby players: dying, respawning, practice or a match closes it.
--   * Movement and the camera are never locked; the panel sits at the side.
-- The catalog is a preview (see Shared.Config.ShopCatalog); nothing can be bought.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopCatalog = require(ReplicatedStorage.Shared.Config.ShopCatalog)

local player = Players.LocalPlayer

local ENTER_INSET = 0.5 -- studs: the root must be this far inside the zone to count as entering
local EXIT_MARGIN = 1.5 -- studs: and this far outside it to count as having left
local CLOSE_ACTION = "ShopClose"

local ShopController = {}

local zone
local gui, panel, closeButton
local isOpen = false
local inside = false -- hysteresis state: currently counted as inside the shop
local suppressed = false -- closed with X; stays closed until the player leaves

local function findZone()
	if zone and zone.Parent then
		return zone
	end
	local lobby = workspace:FindFirstChild("Lobby")
	zone = lobby and lobby:FindFirstChild("ShopZone", true)
	return zone
end

local function inZone(position, margin)
	local rel = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X + margin and math.abs(rel.Y) <= half.Y + margin and math.abs(rel.Z) <= half.Z + margin
end

-- the root of a living lobby character, or nil
local function eligibleRoot()
	if player:GetAttribute("MatchId") ~= nil or player:GetAttribute("InMatch") then
		return nil
	end
	local location = player:GetAttribute("Location")
	if location ~= nil and location ~= "Lobby" then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	gui.Enabled = false
	ContextActionService:UnbindAction(CLOSE_ACTION)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
end

local function dismiss() -- X button / controller B: close and stay closed until reentry
	suppressed = true
	close()
end

local function open()
	if isOpen then
		return
	end
	isOpen = true
	gui.Enabled = true
	ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			dismiss()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)
end

local function reset() -- new life / not eligible: forget everything
	inside = false
	suppressed = false
	close()
end

local function update()
	local root = eligibleRoot()
	if not root or not findZone() then
		reset()
		return
	end
	if inside then
		if not inZone(root.Position, EXIT_MARGIN) then
			inside = false
			suppressed = false
			close()
		end
	elseif inZone(root.Position, -ENTER_INSET) then
		inside = true
	end
	if inside and not suppressed then
		open()
	end
end

local function text(parent, name, props)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = Color3.fromRGB(225, 228, 232)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	for key, value in props do
		label[key] = value
	end
	label.Parent = parent
	return label
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "ShopGui"
	gui.ResetOnSpawn = false -- one copy for the whole session; never stacked
	gui.Enabled = false

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -24, 0.5, 0)
	panel.Size = UDim2.fromOffset(360, 420)
	panel.BackgroundColor3 = Color3.fromRGB(24, 26, 30)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
	local pad = Instance.new("UIPadding", panel)
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16), UDim.new(0, 14), UDim.new(0, 14)

	text(panel, "Title", { Text = "QUARTERMASTER", Font = Enum.Font.GothamBold, TextSize = 24, Size = UDim2.new(1, -48, 0, 30) })
	text(panel, "Notice", {
		Text = ShopCatalog.Notice, TextSize = 14, TextColor3 = Color3.fromRGB(240, 190, 90),
		Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 20),
	})

	closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, 0, 0, 0)
	closeButton.Size = UDim2.fromOffset(36, 36)
	closeButton.BackgroundColor3 = Color3.fromRGB(60, 63, 70)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 20
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Text = "X"
	closeButton.Parent = panel
	Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)
	closeButton.Activated:Connect(dismiss)

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.Position = UDim2.fromOffset(0, 62)
	list.Size = UDim2.new(1, 0, 1, -92)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout", list)
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	for index, item in ShopCatalog.Items do
		local row = Instance.new("Frame")
		row.Name = item.Id
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -6, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(36, 39, 44)
		row.BorderSizePixel = 0
		row.Parent = list
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
		text(row, "Name", { Text = item.Name, Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -120, 0, 20) })
		text(row, "Info", {
			Text = item.Category .. "  -  " .. item.Note, TextSize = 13, TextColor3 = Color3.fromRGB(160, 165, 172),
			Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -120, 0, 30), TextYAlignment = Enum.TextYAlignment.Top,
		})
		local status = Instance.new("TextButton") -- selectable for controller navigation; does nothing
		status.Name = "Status"
		status.AnchorPoint = Vector2.new(1, 0.5)
		status.Position = UDim2.new(1, -10, 0.5, 0)
		status.Size = UDim2.fromOffset(98, 30)
		status.AutoButtonColor = false
		status.BackgroundColor3 = Color3.fromRGB(52, 55, 61)
		status.BorderSizePixel = 0
		status.Font = Enum.Font.GothamBold
		status.TextSize = 12
		status.TextColor3 = Color3.fromRGB(150, 154, 160)
		status.Text = "UNAVAILABLE"
		status.Parent = row
		Instance.new("UICorner", status).CornerRadius = UDim.new(0, 4)
	end

	text(panel, "Hint", {
		Text = "Walk out of the shop to close  -  X / B closes until you come back",
		TextSize = 12, TextColor3 = Color3.fromRGB(140, 145, 152),
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 24),
	})

	gui.Parent = player:WaitForChild("PlayerGui")
end

function ShopController.IsOpen()
	return isOpen
end

function ShopController.Start()
	build()
	player.CharacterAdded:Connect(reset)
	player.CharacterRemoving:Connect(reset)
	RunService.Heartbeat:Connect(update)
	gui.Destroying:Connect(function()
		ContextActionService:UnbindAction(CLOSE_ACTION)
	end)
end

return ShopController
