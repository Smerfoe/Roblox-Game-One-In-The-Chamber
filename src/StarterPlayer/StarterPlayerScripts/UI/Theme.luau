-- Theme: shared look for every custom menu and HUD (see ui/README.md).
-- Colours, spacing and text sizes are desktop baselines; Components scales
-- whole ScreenGuis down on small screens instead of shrinking text one by one.

local function hex(value)
	return Color3.fromHex(value)
end

local Theme = {
	Color = {
		Background = hex("#171C22"),
		Panel = hex("#222930"),
		PanelRaised = hex("#2A323A"),
		Text = hex("#F0F1ED"),
		TextSecondary = hex("#B8C0C8"),
		TextDisabled = hex("#7C858E"),
		Border = hex("#55616C"),
		Blue = hex("#4D9DD5"),
		Red = hex("#D06B6B"),
		Accent = hex("#4D9DD5"), -- selected / primary action
		Warning = hex("#E3B45A"),
		TileLight = hex("#D9DDE0"), -- lobby hotbar tiles
		TileIcon = hex("#23292F"),
	},
	Transparency = {
		Panel = 0.08,
		Overlay = 0.35,
	},
	Space = { S = 8, M = 16, L = 24 },
	TextSize = { Title = 28, Body = 18, Secondary = 16, Small = 14 },
	Font = {
		Bold = Enum.Font.GothamBold,
		Medium = Enum.Font.GothamMedium,
		Regular = Enum.Font.Gotham,
	},
	Corner = 6,
	BorderThickness = 1,
	-- design resolution: GUIs are drawn for this and scaled down below it
	BaseViewport = Vector2.new(1280, 720),
	MinScale = 0.6,
}

return table.freeze(Theme)
