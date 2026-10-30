-- InventoryController: the Inventory screen (MenuController menu "Inventory").
-- Flow: choose a weapon -> its SKINS (only skins you own, plus the default) ->
-- select one to preview -> EQUIP.
--   * Selecting only previews. Nothing changes until the server accepts EQUIP.
--   * The server checks ownership, weapon compatibility and that you're in the
--     lobby; this screen only shows its answer (pending / equipped / reason).
--   * Ownership and the equipped skin come from the server's snapshot; the
--     screen never assumes it owns something.
--   * Equipped skins are used from your next match round or practice visit.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SkinCatalog = require(ReplicatedStorage.Shared.Config.SkinCatalog)
local SkinAppearance = require(ReplicatedStorage.Shared.SkinAppearance)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local new = Components.new
local C = Theme.Color

local MENU = "Inventory"
local CLOSE_ACTION = "InventoryClose"
local PENDING_TIMEOUT = 4
local SPIN_SPEED = 0.6 -- radians per second for the large preview

local InventoryController = {}

local remote
local panel, weaponList, skinGrid, skinTitle, emptyNote
local previewFrame, previewName, previewState, equipButton, statusLabel
local weaponButtons = {} -- [weaponId] = button
local snapshot = { Status = "Loading", Owned = {}, Equipped = {} }
local ownedSet = {}
local selectedWeapon, selectedSkin
local pending -- { id, weaponId, skinId, since }
local message -- { text, color, untilTime }
local nextRequestId = 0
local spin -- { model, pivot, camera, angle }

------------------------------------------------------------------ weapon model previews
local function weaponModel(weaponId, skinId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Weapons") and assets.Weapons:FindFirstChild(weaponId)
	if not template then
		return nil
	end
	local model = Instance.new("Model")
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
	SkinAppearance.Apply(model, weaponId, skinId)
	return model
end

-- fills `parent` with a ViewportFrame showing the weapon in that skin
local function viewport(parent, weaponId, skinId, zoom)
	for _, child in parent:GetChildren() do
		if child:IsA("ViewportFrame") then
			child:Destroy()
		end
	end
	local frame = new("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 150, 155),
		LightColor = Color3.fromRGB(255, 250, 240),
		LightDirection = Vector3.new(-1, -1, -0.6),
		Parent = parent,
	})
	local world = new("WorldModel", { Parent = frame })
	local model = weaponModel(weaponId, skinId)
	if not model then
		return nil
	end
	model.Parent = world
	local box, size = model:GetBoundingBox()
	local camera = new("Camera", { FieldOfView = 30, Parent = frame })
	frame.CurrentCamera = camera
	local longest = math.max(size.X, size.Y, size.Z)
	local side = size.X >= size.Z and box.LookVector or box.RightVector
	camera.CFrame = CFrame.lookAt(box.Position + side * longest * (zoom or 2.4) + Vector3.new(0, longest * 0.15, 0), box.Position)
	return { model = model, pivot = box, camera = camera, base = model:GetPivot() }
end

------------------------------------------------------------------ state helpers
local function isOwned(skinId)
	local skin = SkinCatalog.GetSkin(skinId)
	return skin ~= nil and (skin.Default == true or ownedSet[skinId] == true)
end

local function equippedFor(weaponId)
	return snapshot.Equipped[weaponId] or SkinCatalog.DefaultSkin(weaponId)
end

local function dataUsable()
	return snapshot.Status == "Ready"
end

local function setMessage(text, color)
	message = { text = text, color = color or C.TextSecondary, untilTime = os.clock() + 4 }
end

------------------------------------------------------------------ rendering
local refresh

local function selectSkin(skinId)
	selectedSkin = skinId
	spin = viewport(previewFrame, selectedWeapon, skinId, 2.0)
	if spin then
		spin.angle = 0
	end
	refresh()
end

local function skinCard(skinId, order)
	local skin = SkinCatalog.GetSkin(skinId)
	local card = new("TextButton", {
		Name = skinId,
		Text = "",
		LayoutOrder = order,
		AutoButtonColor = true,
		BackgroundColor3 = C.Panel,
		Parent = skinGrid,
	}, { Components.corner(), Components.stroke() })
	local art = new("Frame", {
		Name = "Art",
		BackgroundColor3 = C.Background,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -34),
		Parent = card,
	}, { Components.corner() })
	viewport(art, selectedWeapon, skinId)
	Components.label(card, {
		Text = string.upper(skin.Name),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 18),
	})
	card.Activated:Connect(function()
		selectSkin(skinId)
	end)
	return card
end

local function rebuildSkins()
	for _, child in skinGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not selectedWeapon then
		return
	end
	local weapon = SkinCatalog.Weapons[selectedWeapon]
	skinTitle.Text = "SKINS  -  " .. string.upper(weapon.Name)
	local shown = 0
	for i, skinId in SkinCatalog.SkinsFor(selectedWeapon) do
		if isOwned(skinId) then
			skinCard(skinId, i)
			shown += 1
		end
	end
	emptyNote.Visible = shown <= 1
	if not selectedSkin or SkinCatalog.GetSkin(selectedSkin).Weapon ~= selectedWeapon or not isOwned(selectedSkin) then
		selectSkin(equippedFor(selectedWeapon))
	end
end

local function selectWeapon(weaponId)
	selectedWeapon = weaponId
	selectedSkin = nil
	rebuildSkins()
	refresh()
end

function refresh()
	if not panel then
		return
	end
	if pending and os.clock() - pending.since > PENDING_TIMEOUT then
		pending = nil
		setMessage("No answer from the server - try again", C.Red)
	end
	for weaponId, button in weaponButtons do
		local stroke = button:FindFirstChildOfClass("UIStroke")
		stroke.Color = weaponId == selectedWeapon and C.Accent or C.Border
		stroke.Thickness = weaponId == selectedWeapon and 3 or 1
		local sub = button:FindFirstChild("Equipped")
		local skin = SkinCatalog.GetSkin(equippedFor(weaponId))
		sub.Text = "Equipped: " .. (skin and skin.Name or "Factory")
	end
	for _, card in skinGrid:GetChildren() do
		if card:IsA("TextButton") then
			local stroke = card:FindFirstChildOfClass("UIStroke")
			local isSelected = card.Name == selectedSkin
			stroke.Color = isSelected and C.Accent or C.Border
			stroke.Thickness = isSelected and 3 or 1
			local isEquipped = selectedWeapon and card.Name == equippedFor(selectedWeapon)
			local tag = card:FindFirstChild("Tag")
			if isEquipped and not tag then
				Components.tag(card, "EQUIPPED").TextColor3 = C.Accent
			elseif not isEquipped and tag then
				tag:Destroy()
			end
		end
	end

	local skin = selectedSkin and SkinCatalog.GetSkin(selectedSkin)
	previewName.Text = skin and string.upper(skin.Name) or ""
	local equippedNow = skin and selectedWeapon and equippedFor(selectedWeapon) == selectedSkin
	if pending then
		previewState.Text = "Equipping..."
		equipButton.Text = "PLEASE WAIT"
		Components.applyStyle(equipButton, "disabled")
	elseif not dataUsable() then
		previewState.Text = "Preview only"
		equipButton.Text = "EQUIP"
		Components.applyStyle(equipButton, "disabled")
	elseif equippedNow then
		previewState.Text = "Equipped"
		equipButton.Text = "EQUIPPED"
		Components.applyStyle(equipButton, "disabled")
	else
		previewState.Text = "Previewing - not equipped"
		equipButton.Text = "EQUIP"
		Components.applyStyle(equipButton, skin and "primary" or "disabled")
	end
	previewState.TextColor3 = equippedNow and C.Accent or C.TextSecondary

	local text, color = "Equipped skins are used from your next match or practice visit.", C.TextSecondary
	if snapshot.Status == "Loading" then
		text, color = "Loading your inventory...", C.TextSecondary
	elseif snapshot.Status ~= "Ready" then
		text, color = "Your saved inventory couldn't be loaded this session, so skins can't be changed. Rejoin to try again.", C.Warning
	elseif message and os.clock() < message.untilTime then
		text, color = message.text, message.color
	end
	statusLabel.Text = text
	statusLabel.TextColor3 = color
end

------------------------------------------------------------------ server messages
local function onSnapshot(snap)
	snapshot = snap
	ownedSet = {}
	for _, id in snap.Owned do
		ownedSet[id] = true
	end
	if panel and panel.Frame.Visible then
		rebuildSkins()
	end
	refresh()
end

local function onEquipResult(requestId, ok, reason)
	if not pending or pending.id ~= requestId then
		return -- an old request; the latest one decides
	end
	pending = nil
	if ok then
		setMessage("Equipped. You'll use it from your next match or practice visit.", C.Text)
	else
		setMessage("Couldn't equip: " .. tostring(reason), C.Red)
	end
	refresh()
end

local function equip()
	if pending or not selectedWeapon or not selectedSkin or not dataUsable() then
		return
	end
	if equippedFor(selectedWeapon) == selectedSkin then
		return
	end
	nextRequestId += 1
	pending = { id = nextRequestId, weaponId = selectedWeapon, skinId = selectedSkin, since = os.clock() }
	message = nil
	remote:FireServer("Equip", nextRequestId, selectedWeapon, selectedSkin)
	refresh()
end

------------------------------------------------------------------ build
local function build()
	local gui = Components.screenGui("InventoryGui", 10)
	panel = Components.menuPanel(gui, { Name = "Inventory", Title = "INVENTORY", Width = 980, Height = 500 })
	panel.Close.Activated:Connect(function()
		MenuController.Close(MENU)
	end)
	Components.label(panel.Tabs, {
		Text = "WEAPON SKINS",
		TextColor3 = C.TextSecondary,
		TextSize = Theme.TextSize.Secondary,
		Size = UDim2.new(1, 0, 1, 0),
	})
	local content = panel.Content

	-- left: weapons
	weaponList = new("Frame", {
		Name = "Weapons",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 200, 1, -52),
		Parent = content,
	}, { new("UIListLayout", { Padding = UDim.new(0, Theme.Space.S), SortOrder = Enum.SortOrder.LayoutOrder }) })
	Components.label(weaponList, { Text = "WEAPONS", Font = Theme.Font.Bold, TextColor3 = C.TextSecondary, LayoutOrder = 0 })
	local ordered = {}
	for weaponId, weapon in SkinCatalog.Weapons do
		table.insert(ordered, { id = weaponId, weapon = weapon })
	end
	table.sort(ordered, function(a, b)
		return a.weapon.Order < b.weapon.Order
	end)
	for _, entry in ordered do
		local button = new("TextButton", {
			Name = entry.id,
			Text = "",
			LayoutOrder = entry.weapon.Order,
			BackgroundColor3 = C.Panel,
			Size = UDim2.new(1, 0, 0, 64),
			Parent = weaponList,
		}, { Components.corner(), Components.stroke(), Components.padding(10) })
		Components.label(button, { Text = string.upper(entry.weapon.Name), Font = Theme.Font.Bold })
		Components.label(button, {
			Text = string.upper(entry.weapon.Slot),
			TextSize = Theme.TextSize.Small,
			TextColor3 = C.TextSecondary,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		Components.label(button, {
			Name = "Equipped",
			TextSize = Theme.TextSize.Small,
			TextColor3 = C.TextSecondary,
			Position = UDim2.fromOffset(0, 24),
		})
		button.Activated:Connect(function()
			selectWeapon(entry.id)
		end)
		weaponButtons[entry.id] = button
	end

	-- middle: owned skins for the selected weapon
	local middle = new("Frame", {
		Name = "Skins",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(200 + Theme.Space.M, 0),
		Size = UDim2.new(1, -(200 + 320 + 2 * Theme.Space.M), 1, -52),
		Parent = content,
	})
	skinTitle = Components.label(middle, { Text = "SKINS", Font = Theme.Font.Bold, TextColor3 = C.TextSecondary })
	skinGrid = new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		Parent = middle,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(128, 120),
			CellPadding = UDim2.fromOffset(Theme.Space.S, Theme.Space.S),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	emptyNote = Components.label(middle, {
		Text = "Only skins you own are shown. You don't own other skins for this weapon yet.",
		TextSize = Theme.TextSize.Small,
		TextColor3 = C.TextSecondary,
		TextWrapped = true,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 36),
		Visible = false,
	})

	-- right: large preview + equip
	local right = new("Frame", {
		Name = "Preview",
		BackgroundColor3 = C.Panel,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 320, 1, -52),
		Parent = content,
	}, { Components.corner(), Components.stroke(), Components.padding(Theme.Space.M) })
	previewFrame = new("Frame", {
		Name = "Model",
		BackgroundColor3 = C.Background,
		Size = UDim2.new(1, 0, 1, -112),
		Parent = right,
	}, { Components.corner() })
	previewName = Components.label(right, {
		Font = Theme.Font.Bold,
		TextSize = 22,
		Position = UDim2.new(0, 0, 1, -104),
		Size = UDim2.new(1, 0, 0, 26),
	})
	previewState = Components.label(right, {
		TextSize = Theme.TextSize.Small,
		Position = UDim2.new(0, 0, 1, -76),
		Size = UDim2.new(1, 0, 0, 18),
	})
	equipButton = Components.button(right, {
		Name = "Equip",
		Text = "EQUIP",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
	})
	equipButton.Activated:Connect(function()
		if equipButton:GetAttribute("Style") ~= "disabled" then
			equip()
		end
	end)

	statusLabel = Components.label(content, {
		Name = "Status",
		TextWrapped = true,
		TextSize = Theme.TextSize.Secondary,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 40),
	})
end

function InventoryController.Start()
	remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Inventory")
	build()
	remote.OnClientEvent:Connect(function(kind, ...)
		if kind == "Snapshot" then
			onSnapshot(...)
		elseif kind == "EquipResult" then
			onEquipResult(...)
		end
	end)
	remote:FireServer("Get")

	MenuController.Register(MENU, {
		Open = function()
			panel.Frame.Visible = true
			remote:FireServer("Get")
			selectWeapon(selectedWeapon or "Service1911")
			ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
				if state == Enum.UserInputState.Begin then
					MenuController.Close(MENU)
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.ButtonB)
		end,
		Close = function()
			panel.Frame.Visible = false
			ContextActionService:UnbindAction(CLOSE_ACTION)
		end,
	})

	-- slow turntable for the large preview, only while the screen is open
	RunService.RenderStepped:Connect(function(dt)
		if spin and panel.Frame.Visible and spin.model.Parent then
			spin.angle += dt * SPIN_SPEED
			local p = spin.pivot.Position
			spin.model:PivotTo(CFrame.new(p) * CFrame.Angles(0, spin.angle, 0) * CFrame.new(-p) * spin.base)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if panel.Frame.Visible then
				refresh()
			end
		end
	end)
end

return InventoryController
