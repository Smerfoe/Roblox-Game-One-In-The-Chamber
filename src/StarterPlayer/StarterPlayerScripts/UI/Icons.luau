-- Icons: one original, flat icon set drawn from plain Frames (no image assets).
-- Icons.draw(name, parent, color, background) fills a square parent.
-- Names: Store, Inventory, Modes (two pistols), Stats, Settings.

local Components = require(script.Parent.Components)

local new = Components.new

local Icons = {}

-- rect in 0..1 icon space: x, y = centre; w, h = size; r = rotation (degrees)
local function rect(parent, color, x, y, w, h, r, round)
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = r or 0,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if round then
		new("UICorner", { CornerRadius = round, Parent = frame })
	end
	return frame
end

local function ring(parent, color, x, y, size, thickness)
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIStroke", { Color = color, Thickness = thickness }),
	})
	return frame
end

local function pistol(parent, color, rotation, mirror)
	local holder = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Rotation = rotation,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local s = mirror and -1 or 1
	rect(holder, color, 0.5 + 0.02 * s, 0.42, 0.62, 0.13, 0, UDim.new(0, 2)) -- slide
	rect(holder, color, 0.5 - 0.17 * s, 0.6, 0.14, 0.3, -12 * s, UDim.new(0, 2)) -- grip
	return holder
end

local DRAW = {}

function DRAW.Store(parent, color)
	rect(parent, color, 0.52, 0.45, 0.6, 0.32, 0, UDim.new(0, 3)) -- basket
	rect(parent, color, 0.16, 0.26, 0.2, 0.07, 0) -- handle
	rect(parent, color, 0.4, 0.78, 0.13, 0.13, 0, UDim.new(1, 0)) -- wheels
	rect(parent, color, 0.68, 0.78, 0.13, 0.13, 0, UDim.new(1, 0))
end

function DRAW.Inventory(parent, color)
	rect(parent, color, 0.5, 0.58, 0.8, 0.5, 0, UDim.new(0, 4)) -- case
	ring(parent, color, 0.5, 0.3, 0.28, 3) -- handle
	rect(parent, color, 0.5, 0.5, 0.8, 0.04, 0) -- seam
end

function DRAW.Modes(parent, color)
	pistol(parent, color, 30, false)
	pistol(parent, color, -30, true)
end

function DRAW.Stats(parent, color)
	rect(parent, color, 0.26, 0.66, 0.16, 0.36, 0, UDim.new(0, 2))
	rect(parent, color, 0.5, 0.54, 0.16, 0.6, 0, UDim.new(0, 2))
	rect(parent, color, 0.74, 0.42, 0.16, 0.84, 0, UDim.new(0, 2))
end

function DRAW.Settings(parent, color, background)
	for i = 0, 3 do
		rect(parent, color, 0.5, 0.5, 0.18, 0.86, i * 45, UDim.new(0, 2)) -- teeth
	end
	rect(parent, color, 0.5, 0.5, 0.64, 0.64, 0, UDim.new(1, 0)) -- body
	rect(parent, background, 0.5, 0.5, 0.26, 0.26, 0, UDim.new(1, 0)) -- hole
end

function Icons.draw(name, parent, color, background)
	local fn = DRAW[name]
	assert(fn, "unknown icon " .. tostring(name))
	fn(parent, color, background)
end

return Icons
