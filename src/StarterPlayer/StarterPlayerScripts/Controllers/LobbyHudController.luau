-- LobbyHudController: the lobby screen.
--   * Top-left profile group: avatar, display name, level, XP bar, coins.
--     Progression and coins do not exist yet, so those fields say so instead of
--     showing made-up numbers. Clicking the profile opens the Profile menu.
--   * Bottom centre: PLAY GAME above the five tiles STORE / INVENTORY / MODES /
--     STATS / SETTINGS. Tiles open menus through MenuController (INVENTORY opens
--     InventoryController's skins screen). PLAY GAME and
--     MODES open the same mode screen ("Play"). Features that do not exist yet
--     are shown disabled with a SOON tag.
--   * Profile menu ("Profile", also the STATS tile): statistics and equipped
--     cosmetics, again only real data.
-- Everything is hidden outside the lobby (match, practice, dead), and PLAY GAME
-- is hidden while a menu is open.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local SkinCatalog = require(ReplicatedStorage.Shared.Config.SkinCatalog)
local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Components = require(UI.Components)
local Icons = require(UI.Icons)
local MenuController = require(script.Parent.MenuController)

local player = Players.LocalPlayer
local new = Components.new
local C = Theme.Color

local UNAVAILABLE = "Not available yet"

-- tile name, icon, menu it opens (nil = not implemented yet)
local TILES = {
	{ Name = "Store", Icon = "Store", Menu = "Store" },
	{ Name = "Inventory", Icon = "Inventory", Menu = "Inventory" },
	{ Name = "Modes", Icon = "Modes", Menu = "Play" },
	{ Name = "Stats", Icon = "Stats", Menu = "Profile" },
	{ Name = "Settings", Icon = "Settings", Menu = nil },
}

local LobbyHudController = {}

local gui, profileButton, hotbar, playButton
local tiles = {} -- [menuName] = tile frame
local profilePanel

local function buildProfile()
	profileButton = new("TextButton", {
		Name = "Profile",
		Text = "",
		AutoButtonColor = true,
		Position = UDim2.fromOffset(Theme.Space.M, Theme.Space.M),
		Size = UDim2.fromOffset(330, 92),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = Theme.Transparency.Panel,
		Parent = gui,
	}, { Components.corner(8), Components.stroke() })
	local avatar = new("ImageLabel", {
		Name = "Avatar",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = C.Panel,
		Parent = profileButton,
	}, { Components.corner(4) })
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			avatar.Image = image
		end
	end)
	local x = 94
	Components.label(profileButton, {
		Name = "DisplayName",
		Text = string.upper(player.DisplayName),
		Font = Theme.Font.Bold,
		Position = UDim2.fromOffset(x, 8),
		Size = UDim2.new(1, -x - 28, 0, 22),
	})
	Components.label(profileButton, {
		Name = "Level",
		Text = "LEVEL  -",
		TextSize = Theme.TextSize.Small,
		TextColor3 = C.TextSecondary,
		Position = UDim2.fromOffset(x, 32),
		Size = UDim2.new(0, 70, 0, 16),
	})
	local bar = new("Frame", {
		Name = "XPBar",
		Position = UDim2.fromOffset(x + 70, 37),
		Size = UDim2.new(1, -x - 80, 0, 6),
		BackgroundColor3 = C.PanelRaised,
		BorderSizePixel = 0,
		Parent = profileButton,
	}, { Components.corner(3) })
	new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Parent = bar }, { Components.corner(3) })
	Components.label(profileButton, {
		Name = "XP",
		Text = "XP  -  progression not available yet",
		TextSize = 12,
		TextColor3 = C.TextDisabled,
		Position = UDim2.fromOffset(x, 48),
		Size = UDim2.new(1, -x - 10, 0, 14),
	})
	Components.label(profileButton, {
		Name = "Coins",
		Text = "COINS  -  " .. string.lower(UNAVAILABLE),
		TextSize = Theme.TextSize.Small,
		TextColor3 = C.TextSecondary,
		Position = UDim2.fromOffset(x, 66),
		Size = UDim2.new(1, -x - 10, 0, 16),
	})
	Components.label(profileButton, {
		Text = ">",
		Font = Theme.Font.Bold,
		TextColor3 = C.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 10),
		Size = UDim2.fromOffset(18, 20),
	})
	profileButton.Activated:Connect(function()
		MenuController.Toggle("Profile")
	end)
end

local function buildTile(parent, info, order)
	local tile = new("TextButton", {
		Name = info.Name,
		Text = "",
		LayoutOrder = order,
		Size = UDim2.fromOffset(92, 84),
		BackgroundColor3 = C.TileLight,
		AutoButtonColor = info.Menu ~= nil,
		Parent = parent,
	}, { Components.corner(4), Components.stroke(C.Border, 1) })
	local enabled = info.Menu ~= nil
	local iconColor = enabled and C.TileIcon or Color3.fromRGB(140, 146, 152)
	local icon = new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		Parent = tile,
	})
	Icons.draw(info.Icon, icon, iconColor, C.TileLight)
	Components.label(tile, {
		Text = string.upper(info.Name),
		Font = Theme.Font.Bold,
		TextSize = 12,
		TextColor3 = iconColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 16),
	})
	if enabled then
		tiles[info.Menu] = tile
		tile.Activated:Connect(function()
			MenuController.Toggle(info.Menu)
		end)
	else
		Components.tag(tile, "SOON")
	end
	return tile
end

local function buildHotbar()
	hotbar = new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Space.M),
		Size = UDim2.fromOffset(5 * 92 + 4 * Theme.Space.S, 84),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.Space.S),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for index, info in TILES do
		buildTile(hotbar, info, index)
	end
	playButton = Components.button(gui, {
		Name = "PlayGame",
		Text = "PLAY GAME",
		TextSize = 24,
		Style = "primary",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(Theme.Space.M + 84 + Theme.Space.S)),
		Size = UDim2.fromOffset(276, 52),
	})
	-- PLAY GAME and the MODES tile open the same mode screen (PlayController)
	playButton.Activated:Connect(function()
		MenuController.Open("Play")
	end)
end

local function statRow(parent, order, name, value, nameWidth)
	nameWidth = nameWidth or 0.5
	local row = new("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), Parent = parent })
	Components.label(row, { Text = name, TextColor3 = C.TextSecondary, Size = UDim2.new(nameWidth, 0, 1, 0) })
	return Components.label(row, {
		Text = value,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = value == UNAVAILABLE and C.TextDisabled or C.Text,
		Position = UDim2.fromScale(nameWidth, 0),
		Size = UDim2.new(1 - nameWidth, 0, 1, 0),
	})
end

local function column(parent, x, title)
	local frame = new("Frame", {
		BackgroundColor3 = C.Panel,
		Position = UDim2.new(x, x > 0 and Theme.Space.S or 0, 0, 0),
		Size = UDim2.new(0.5, -Theme.Space.S, 1, 0),
		Parent = parent,
	}, {
		Components.corner(),
		Components.stroke(),
		Components.padding(Theme.Space.M),
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Components.label(frame, { Text = title, Font = Theme.Font.Bold, LayoutOrder = 0 })
	return frame
end

local function buildProfileMenu()
	profilePanel = Components.menuPanel(gui, { Name = "ProfileMenu", Title = "PROFILE", Width = 760, Height = 400 })
	profilePanel.Close.Activated:Connect(function()
		MenuController.Close("Profile")
	end)
	Components.label(profilePanel.Tabs, {
		Text = string.upper(player.DisplayName) .. "  (@" .. player.Name .. ")",
		TextColor3 = C.TextSecondary,
		Size = UDim2.new(1, 0, 1, 0),
	})
	local stats = column(profilePanel.Content, 0, "STATISTICS")
	for i, name in { "Level", "Matches played", "Wins", "Eliminations", "Win streak", "Coins" } do
		statRow(stats, i, name, UNAVAILABLE)
	end
	Components.label(stats, {
		LayoutOrder = 99,
		Text = "Stats and progression are not recorded yet.",
		TextSize = Theme.TextSize.Small,
		TextColor3 = C.TextSecondary,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 36),
	})
	local equipped = column(profilePanel.Content, 0.5, "EQUIPPED")
	-- equipped skins come from the server (player attributes Skin_<weapon>)
	for i, slot in { { "Pistol", WeaponConfig.Pistol.ToolName }, { "Knife", WeaponConfig.Knife.ToolName } } do
		local weaponId = slot[2]
		local valueLabel = statRow(equipped, i, slot[1], "", 0.3)
		local function refresh()
			local weapon = SkinCatalog.Weapons[weaponId]
			local skin = SkinCatalog.GetSkin(player:GetAttribute("Skin_" .. weaponId))
				or SkinCatalog.GetSkin(SkinCatalog.DefaultSkin(weaponId))
			valueLabel.Text = (weapon and weapon.Name or weaponId) .. " (" .. (skin and skin.Name or "Factory") .. ")"
		end
		refresh()
		player:GetAttributeChangedSignal("Skin_" .. weaponId):Connect(refresh)
	end
	statRow(equipped, 3, "Player card", UNAVAILABLE, 0.3)

	MenuController.Register("Profile", {
		Open = function()
			profilePanel.Frame.Visible = true
		end,
		Close = function()
			profilePanel.Frame.Visible = false
		end,
	})
end

local function refresh()
	local eligible = MenuController.IsLobbyEligible()
	local open = MenuController.Current()
	profileButton.Visible = eligible
	hotbar.Visible = eligible and open ~= "Play" -- the mode screen is a focused screen
	playButton.Visible = eligible and open == nil
	for menu, tile in tiles do
		local stroke = tile:FindFirstChildOfClass("UIStroke")
		local selected = open == menu
		stroke.Color = selected and C.Accent or C.Border
		stroke.Thickness = selected and 3 or 1
	end
end

function LobbyHudController.Start()
	gui = Components.screenGui("LobbyHud", 5)
	buildProfile()
	buildHotbar()
	buildProfileMenu()
	MenuController.Changed:Connect(refresh)
	RunService.Heartbeat:Connect(refresh) -- cheap; follows match/practice/death without extra connections
	refresh()
end

return LobbyHudController
