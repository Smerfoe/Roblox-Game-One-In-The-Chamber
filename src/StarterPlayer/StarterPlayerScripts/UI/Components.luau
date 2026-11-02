-- Components: small native UI building blocks shared by every controller.
-- Nothing here holds game state; controllers own their state and the server
-- owns everything that matters.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local Components = {}

local C = Theme.Color

-- Instance.new with properties and children in one call.
function Components.new(className, props, children)
	local instance = Instance.new(className)
	for key, value in props or {} do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end
local new = Components.new

function Components.corner(radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Corner) })
end

function Components.stroke(color, thickness)
	return new("UIStroke", {
		Color = color or C.Border,
		Thickness = thickness or Theme.BorderThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Components.padding(all)
	local u = UDim.new(0, all)
	return new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

-- One ScreenGui per feature, created once (ResetOnSpawn off), kept inside the
-- device safe area, scaled down uniformly on small viewports.
function Components.screenGui(name, displayOrder)
	local gui = new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = displayOrder or 0,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	local scale = new("UIScale", { Parent = gui })
	local function rescale()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Theme.BaseViewport
		local s = math.min(size.X / Theme.BaseViewport.X, size.Y / Theme.BaseViewport.Y)
		scale.Scale = math.clamp(s, Theme.MinScale, 1)
	end
	rescale()
	local cameraConnection
	local function watchCamera()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
		rescale()
	end
	watchCamera()
	local workspaceConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	gui.Destroying:Connect(function()
		workspaceConnection:Disconnect()
		if cameraConnection then
			cameraConnection:Disconnect()
		end
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function Components.label(parent, props)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font.Medium,
		TextSize = Theme.TextSize.Body,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, Theme.TextSize.Body + 6),
		Parent = parent,
	})
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

-- Button styles: "primary" (blue), "secondary" (dark), "disabled" (can't be used,
-- still readable). Returns the button; set Components.setEnabled to change style.
local STYLES = {
	primary = { bg = C.Accent, text = C.Text, stroke = C.Accent },
	secondary = { bg = C.PanelRaised, text = C.Text, stroke = C.Border },
	disabled = { bg = C.Panel, text = C.TextDisabled, stroke = C.Border },
}

function Components.applyStyle(button, style)
	local s = STYLES[style]
	button.BackgroundColor3 = s.bg
	button.TextColor3 = s.text
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = s.stroke
	end
	button.AutoButtonColor = style ~= "disabled"
	button.Active = style ~= "disabled"
	button:SetAttribute("Style", style)
end

function Components.button(parent, props)
	local button = new("TextButton", {
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Secondary,
		Size = UDim2.fromOffset(160, 40),
		BorderSizePixel = 0,
		Parent = parent,
	}, { Components.corner(), Components.stroke() })
	local style = props.Style or "secondary"
	props.Style = nil
	for key, value in props do
		button[key] = value
	end
	Components.applyStyle(button, style)
	return button
end

-- Standard menu window: title, optional tab row, X close button, content area.
-- Returns { Frame, Content, Tabs, Close, Title }.
function Components.menuPanel(parent, props)
	local width, height = props.Width or 820, props.Height or 500
	local frame = new("Frame", {
		Name = props.Name or "MenuPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = props.Position or UDim2.new(0.5, 0, 0.5, -30),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = Theme.Transparency.Panel,
		Visible = false,
		Parent = parent,
	}, { Components.corner(8), Components.stroke(), Components.padding(Theme.Space.L) })
	new("UISizeConstraint", { MaxSize = Vector2.new(width, height), Parent = frame })

	local header = new("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = frame,
	})
	local title = Components.label(header, {
		Name = "Title",
		Text = props.Title or "",
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Title,
		Size = UDim2.new(0, 260, 1, 0),
	})
	local tabs = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(270, 2),
		Size = UDim2.new(1, -330, 1, -4),
		Parent = header,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, Theme.Space.S),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local close = Components.button(header, {
		Name = "Close",
		Text = "X",
		TextSize = 20,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(44, 44),
	})
	local content = new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 44 + Theme.Space.M),
		Size = UDim2.new(1, 0, 1, -(44 + Theme.Space.M)),
		Parent = frame,
	})
	return { Frame = frame, Content = content, Tabs = tabs, Close = close, Title = title }
end

-- A tab button inside menuPanel's tab row. setSelected(true/false) restyles it.
function Components.tab(tabs, text, order)
	local tab = Components.button(tabs, {
		Text = string.upper(text),
		LayoutOrder = order or 0,
		Size = UDim2.fromOffset(150, 36),
	})
	local function setSelected(selected)
		Components.applyStyle(tab, selected and "primary" or "secondary")
	end
	return tab, setSelected
end

-- Small "COMING SOON" / "UNAVAILABLE" tag in a corner of a frame.
function Components.tag(parent, text)
	return new("TextLabel", {
		Name = "Tag",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.15,
		Font = Theme.Font.Bold,
		TextSize = 10,
		TextColor3 = C.Warning,
		Text = text,
		ZIndex = 5,
		Parent = parent,
	}, { Components.corner(3), new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }) })
end

return Components
