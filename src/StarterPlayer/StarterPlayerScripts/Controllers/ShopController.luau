-- ShopController: the Store menu (registered with MenuController as "Store").
-- Opened two ways, same menu either way:
--   * the STORE tile on the lobby hotbar;
--   * walking into Lobby ... 03_Shop.ShopZone (checked every frame against the
--     zone box with a margin, so standing on the edge does not flicker).
-- Closing it while standing in the shop (X, controller B, another menu)
-- keeps it closed until the player has left the shop and come back in.
-- The catalog is a PREVIEW (Shared.Config.ShopCatalog): nothing can be bought,
-- there is no currency or price, and the menu authorizes nothing.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopCatalog = require(ReplicatedStorage.Shared.Config.ShopCatalog)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local new = Components.new
local C = Theme.Color

local ENTER_INSET = 0.5 -- studs: the root must be this far inside the zone to count as entering
local EXIT_MARGIN = 1.5 -- studs: and this far outside it to count as having left
local CLOSE_ACTION = "StoreClose"
local MENU = "Store"

-- catalog item id -> tool shown in its preview
local PREVIEW_TOOL = {
	pistol_standard = WeaponConfig.Pistol.ToolName,
	knife_standard = WeaponConfig.Knife.ToolName,
}

local ShopController = {}

local zone
local gui, panel
local isOpen = false
local inside = false -- hysteresis state: currently counted as inside the shop
local suppressed = false -- closed while inside; stays closed until the player leaves

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

local function onOpen()
	isOpen = true
	panel.Frame.Visible = true
	ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin then
			MenuController.Close(MENU)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)
end

local function onClose()
	isOpen = false
	panel.Frame.Visible = false
	ContextActionService:UnbindAction(CLOSE_ACTION)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	if inside then
		suppressed = true -- closed in the shop: don't pop back open
	end
end

local function update()
	local root = MenuController.IsLobbyEligible() and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not findZone() then
		inside = false
		suppressed = false
		return -- MenuController closes the menu itself when the player is not eligible
	end
	if inside then
		if not inZone(root.Position, EXIT_MARGIN) then
			inside = false
			suppressed = false
			MenuController.Close(MENU)
		end
	elseif inZone(root.Position, -ENTER_INSET) then
		inside = true
	end
	if inside and not suppressed and not isOpen then
		MenuController.Open(MENU, { Source = "Zone" })
	end
end

local function preview(parent, toolName)
	local template = toolName and ReplicatedStorage:FindFirstChild("Assets")
		and ReplicatedStorage.Assets:FindFirstChild("Weapons")
		and ReplicatedStorage.Assets.Weapons:FindFirstChild(toolName)
	if not template then
		return
	end
	local viewport = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 155),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1, -0.6),
		Parent = parent,
	})
	local world = new("WorldModel", { Parent = viewport })
	local model = new("Model", { Parent = world })
	for _, child in template:Clone():GetChildren() do
		if child:IsA("BasePart") or child:IsA("Model") then
			child.Parent = model
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	local box, size = model:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	local longest = math.max(size.X, size.Y, size.Z)
	-- look at the weapon's side (its longest horizontal axis runs across the card)
	local side = size.X >= size.Z and box.LookVector or box.RightVector
	camera.CFrame = CFrame.lookAt(box.Position + side * longest * 2.4 + Vector3.new(0, longest * 0.15, 0), box.Position)
end

local function card(parent, item, order)
	local frame = new("Frame", {
		Name = item.Id,
		LayoutOrder = order,
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Components.corner(), Components.stroke() })
	local art = new("Frame", {
		Name = "Art",
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundColor3 = C.Background,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Components.corner() })
	preview(art, PREVIEW_TOOL[item.Id])
	if not PREVIEW_TOOL[item.Id] then
		Components.label(art, {
			Text = item.Note,
			TextColor3 = C.TextSecondary,
			TextSize = Theme.TextSize.Secondary,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Size = UDim2.fromScale(1, 1),
		})
	end
	Components.label(frame, {
		Text = string.upper(item.Name),
		Font = Theme.Font.Bold,
		Position = UDim2.new(0, 12, 1, -40),
		Size = UDim2.new(1, -24, 0, 20),
	})
	Components.label(frame, {
		Text = item.Category,
		TextSize = Theme.TextSize.Small,
		TextColor3 = C.TextSecondary,
		Position = UDim2.new(0, 12, 1, -20),
		Size = UDim2.new(1, -24, 0, 16),
	})
	Components.button(frame, {
		Name = "Status",
		Text = "UNAVAILABLE",
		Style = "disabled",
		TextSize = 11,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(96, 24),
		ZIndex = 3,
	})
end

local function build()
	gui = Components.screenGui("StoreGui", 10)
	panel = Components.menuPanel(gui, { Name = "Store", Title = "STORE", Width = 900, Height = 520 })
	local previewTag = Components.tag(panel.Title, "PREVIEW")
	previewTag.AnchorPoint = Vector2.new(0, 0.5)
	previewTag.Position = UDim2.new(0, 100, 0.5, 0)
	panel.Close.Activated:Connect(function()
		MenuController.Close(MENU)
	end)
	Components.label(panel.Tabs, {
		Text = ShopCatalog.Notice,
		TextColor3 = C.Warning,
		TextSize = Theme.TextSize.Small,
		Size = UDim2.new(1, 0, 1, 0),
	})

	local grid = new("ScrollingFrame", {
		Name = "Items",
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel.Content,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -11, 0, 176),
			CellPadding = UDim2.fromOffset(Theme.Space.M, Theme.Space.M),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	})
	for index, item in ShopCatalog.Items do
		card(grid, item, index)
	end
	Components.label(panel.Content, {
		Text = "Cosmetic items only  -  no gameplay advantages",
		TextColor3 = C.TextSecondary,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
	})
end

function ShopController.IsOpen()
	return isOpen
end

function ShopController.Start()
	build()
	MenuController.Register(MENU, { Open = onOpen, Close = onClose })
	player.CharacterAdded:Connect(function()
		inside = false
		suppressed = false
	end)
	RunService.Heartbeat:Connect(update)
end

return ShopController
