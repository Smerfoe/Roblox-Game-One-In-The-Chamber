-- FoundryDetail: builds the full detail pass for the Foundry team map.
-- Run in Studio's command bar / plugin context with `map` = the Foundry Model.
-- Everything goes into two folders so it can be reviewed or removed in one go:
--   Details/DetailPass_v2   decoration only: CanCollide/CanQuery/CanTouch = false.
--                           Anything inside the playable space is flush (<= 0.3
--                           stud proud) or above 8 studs, so it can't block
--                           movement, stop bullets or hide a player.
--   Cover_Proposed          solid props (collision + bullet blocking) in spawn-bay
--                           corners only. These ARE gameplay changes and are
--                           flagged for approval; delete the folder to drop them.
-- Coordinates are relative to the map pivot (MapOrigin), floor top = 0.

return function(map)
	local origin = map:GetPivot()
	assert(not map.Details:FindFirstChild("DetailPass_v2"), "DetailPass_v2 already exists")
	local old = map.Details:FindFirstChild("DetailPass_v1")
	if old then
		old:Destroy() -- the first furnace pass is rebuilt below as part of v2
	end

	local pass = Instance.new("Folder")
	pass.Name = "DetailPass_v2"
	pass:SetAttribute("Note", "Decoration only (no collision/query/touch). Flush or above head height inside the arena.")
	pass.Parent = map.Details
	local proposed = Instance.new("Folder")
	proposed.Name = "Cover_Proposed"
	proposed:SetAttribute("Note", "NEW GAMEPLAY COVER awaiting approval: solid props in spawn-bay corners. Delete to remove.")
	proposed.Parent = map

	local areas = {}
	local function area(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = pass
		areas[name] = f
		return f
	end

	local count, solidCount = 0, 0
	local function deco(parent, name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = origin * cf
		p.Color = color
		p.Material = material or Enum.Material.Metal
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		count += 1
		return p
	end
	local function solid(name, size, cf, color, material, shape)
		local p = deco(proposed, name, size, cf, color, material, shape)
		p.CanCollide = true
		p.CanQuery = true
		p.CastShadow = true
		count -= 1
		solidCount += 1
		return p
	end
	local function grime(parent, name, size, cf, transparency)
		local p = deco(parent, name, size, cf, Color3.fromRGB(26, 22, 20), Enum.Material.SmoothPlastic)
		p.Transparency = transparency or 0.55
		return p
	end
	local function light(parent, kind, color, range, brightness, face)
		local l = Instance.new(kind)
		l.Color = color
		l.Range = range
		l.Brightness = brightness
		l.Shadows = false
		if face then
			l.Face = face
		end
		l.Parent = parent
		return l
	end
	-- flat item on a wall: point on the wall face, outward normal, size (width, height, depth)
	local function onWall(point, normal)
		return CFrame.lookAt(point, point + normal)
	end
	local function vertical(pos)
		return CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	end
	local function alongZ(pos)
		return CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0)
	end
	local function sign(parent, name, point, normal, width, height, text, bg, fg)
		local p = deco(parent, name, Vector3.new(width, height, 0.08), onWall(point + normal * 0.06, normal), bg, Enum.Material.SmoothPlastic)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = fg
		label.Text = text
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
		pad.Parent = label
		label.Parent = gui
		gui.Parent = p
		return p
	end

	local C = {
		Steel = Color3.fromRGB(58, 56, 54),
		SteelLight = Color3.fromRGB(96, 92, 86),
		SteelDark = Color3.fromRGB(34, 33, 32),
		Safety = Color3.fromRGB(214, 168, 46),
		SafetyDark = Color3.fromRGB(36, 32, 26),
		Ember = Color3.fromRGB(255, 120, 40),
		Copper = Color3.fromRGB(150, 92, 60),
		PipeGrey = Color3.fromRGB(110, 112, 112),
		PipeGreen = Color3.fromRGB(70, 96, 72),
		PipeRed = Color3.fromRGB(128, 48, 40),
		Concrete = Color3.fromRGB(70, 62, 58),
		ConcreteLight = Color3.fromRGB(150, 146, 138),
		Blue = Color3.fromRGB(64, 116, 180),
		Red = Color3.fromRGB(176, 64, 56),
		White = Color3.fromRGB(226, 224, 216),
		Warm = Color3.fromRGB(255, 214, 160),
		Glass = Color3.fromRGB(40, 52, 60),
	}

	------------------------------------------------------------------ 1 machines
	local machines = area("Machines")
	-- Furnace 1 (west, Machine_00) and Furnace 2 (east, Machine_01): 7 x 12 x 24.
	-- side = which long face carries the operator console (+1 = east face).
	local units = {
		{ name = "FURNACE 1", x = -23.5, z = -4, glassZ = -5, consoleSide = 1, consoleZ = 6.5 },
		{ name = "FURNACE 2", x = 23.5, z = 4, glassZ = 3, consoleSide = -1, consoleZ = -6.5 },
	}
	for _, u in units do
		local hw, hd = 3.5, 12
		for _, y in { 2.2, 10.2 } do
			deco(machines, "MachineBand", Vector3.new(7.3, 0.5, 24.3), CFrame.new(u.x, y, u.z), C.SteelLight, Enum.Material.DiamondPlate)
		end
		deco(machines, "MachineBaseStripe", Vector3.new(7.2, 0.45, 24.2), CFrame.new(u.x, 0.3, u.z), C.Safety, Enum.Material.SmoothPlastic)
		-- panel seams on the long faces, every 6 studs, between the bands
		for _, side in { -1, 1 } do
			for k = -2, 2 do
				local sz = u.z + k * 6
				deco(machines, "PanelSeam", Vector3.new(0.06, 7.4, 0.08), CFrame.new(u.x + side * (hw + 0.03), 6.2, sz), C.SteelDark)
			end
			-- sight-glass under the vent row, warm glow
			local fx = u.x + side * 3.56
			deco(machines, "SightGlassFrame", Vector3.new(0.12, 1.2, 3.4), CFrame.new(fx, 4.0, u.glassZ), C.SteelDark)
			local glow = deco(machines, "SightGlass", Vector3.new(0.14, 0.7, 2.8), CFrame.new(fx + side * 0.02, 4.0, u.glassZ), C.Ember, Enum.Material.Neon)
			light(glow, "PointLight", C.Ember, 8, 0.6)
			-- heat soot above the vents and a rust run under the glass (restrained wear)
			grime(machines, "SootBand", Vector3.new(0.05, 1.2, 20), CFrame.new(u.x + side * (hw + 0.05), 9.3, u.z), 0.6)
			grime(machines, "RustRun", Vector3.new(0.05, 1.4, 0.5), CFrame.new(u.x + side * (hw + 0.05), 2.9, u.glassZ + 0.9), 0.5).Color = Color3.fromRGB(92, 50, 30)
		end
		-- operator console on one long face, below the vents
		local cx = u.x + u.consoleSide * (hw + 0.14)
		local n = Vector3.new(u.consoleSide, 0, 0)
		deco(machines, "ControlConsole", Vector3.new(3.2, 2.2, 0.26), onWall(Vector3.new(cx, 3.4, u.z + u.consoleZ), n), C.SteelDark)
		for i, color in { Color3.fromRGB(60, 200, 90), Color3.fromRGB(230, 180, 40), Color3.fromRGB(220, 60, 50) } do
			deco(machines, "ConsoleLamp", Vector3.new(0.28, 0.28, 0.08), onWall(Vector3.new(cx + u.consoleSide * 0.15, 4.1, u.z + u.consoleZ - 1 + (i - 1) * 0.5), n), color, Enum.Material.Neon)
		end
		for i = 0, 1 do
			deco(machines, "ConsoleGauge", Vector3.new(0.1, 0.7, 0.7), CFrame.new(cx + u.consoleSide * 0.15, 3.0, u.z + u.consoleZ + 0.5 + i * 0.9) * CFrame.Angles(0, 0, 0), C.White, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		sign(machines, "FurnaceName", Vector3.new(u.x + u.consoleSide * hw, 11.2, u.z), Vector3.new(u.consoleSide, 0, 0), 7, 1.2, u.name, C.SteelDark, C.Safety)
		-- access doors at both ends (existing panels): hinges and a hazard label
		for _, endSide in { -1, 1 } do
			local ez = u.z + endSide * (hd + 0.05)
			local en = Vector3.new(0, 0, endSide)
			for _, hy in { 2.6, 6.4 } do
				deco(machines, "DoorHinge", Vector3.new(0.3, 0.7, 0.14), onWall(Vector3.new(u.x - 2.75, hy, ez), en), C.SteelLight)
			end
			sign(machines, "HotSurfaceLabel", Vector3.new(u.x, 7.6, ez), en, 3.2, 0.7, "HOT SURFACE", C.Safety, C.SafetyDark)
		end
		-- exhaust stack and the hot-gas pipe from the top up to the overhead header
		deco(machines, "ExhaustStack", Vector3.new(3.4, 1.4, 1.4), vertical(Vector3.new(u.x, 13.7, u.z + 7)), C.Steel, Enum.Material.Metal, Enum.PartType.Cylinder)
		deco(machines, "ExhaustCollar", Vector3.new(0.3, 1.7, 1.7), vertical(Vector3.new(u.x, 12.2, u.z + 7)), C.SteelLight, Enum.Material.Metal, Enum.PartType.Cylinder)
		local riserZ = u.z - 8
		deco(machines, "GasRiser", Vector3.new(1.6, 0.7, 0.7), vertical(Vector3.new(u.x, 12.8, riserZ)), C.PipeRed, Enum.Material.Metal, Enum.PartType.Cylinder)
		deco(machines, "RiserFlange", Vector3.new(0.2, 1.0, 1.0), vertical(Vector3.new(u.x, 12.15, riserZ)), C.SteelLight, Enum.Material.Metal, Enum.PartType.Cylinder)
		-- floor: keep-clear outline, steel plates in front of both access doors, heat stain
		local ox, oz = hw + 1.2, hd + 1.2
		deco(machines, "FloorSafetyLine", Vector3.new(0.35, 0.04, 2 * oz), CFrame.new(u.x - ox, 0.02, u.z), C.Safety, Enum.Material.SmoothPlastic)
		deco(machines, "FloorSafetyLine", Vector3.new(0.35, 0.04, 2 * oz), CFrame.new(u.x + ox, 0.02, u.z), C.Safety, Enum.Material.SmoothPlastic)
		deco(machines, "FloorSafetyLine", Vector3.new(2 * ox, 0.04, 0.35), CFrame.new(u.x, 0.02, u.z - oz), C.Safety, Enum.Material.SmoothPlastic)
		deco(machines, "FloorSafetyLine", Vector3.new(2 * ox, 0.04, 0.35), CFrame.new(u.x, 0.02, u.z + oz), C.Safety, Enum.Material.SmoothPlastic)
		for _, endSide in { -1, 1 } do
			deco(machines, "DoorFloorPlate", Vector3.new(6, 0.03, 1.0), CFrame.new(u.x, 0.015, u.z + endSide * (hd + 0.6)), C.SteelLight, Enum.Material.DiamondPlate)
		end
		grime(machines, "HeatStain", Vector3.new(9, 0.02, 4), CFrame.new(u.x, 0.012, u.glassZ), 0.7)
	end

	------------------------------------------------------------------ 2 overhead
	local overhead = area("Overhead")
	-- existing runway beams: y 14.4 (0.8 deep), z = -14 and 12, x from +-3.5 to +-42.5
	for _, sx in { -1, 1 } do
		for _, z in { -14, 12 } do
			for _, x in { 3.5, 42.5 } do
				local wx = sx * x
				local inward = Vector3.new(-sx * (x > 4 and 1 or -1), 0, 0)
				-- bearing plate + knee brace where each runway lands on a wall
				deco(overhead, "BearingPlate", Vector3.new(0.9, 1.4, 0.25), onWall(Vector3.new(wx + inward.X * 0.13, 13.6, z), inward), C.SteelDark)
				deco(overhead, "KneeBrace", Vector3.new(0.25, 2.6, 0.25), CFrame.new(wx + inward.X * 0.9, 13.0, z) * CFrame.Angles(0, 0, inward.X * math.rad(35)), C.Steel)
			end
		end
		-- bridge crane: girder across both runways, end trucks, trolley, hoist line, hook block
		local bx = sx * 23.5
		local trolleyZ = sx < 0 and -1 or 7
		deco(overhead, "CraneGirder", Vector3.new(1.2, 1.0, 28), CFrame.new(bx, 15.3, -1), C.Safety, Enum.Material.Metal)
		for _, z in { -14, 12 } do
			deco(overhead, "CraneEndTruck", Vector3.new(3.2, 0.7, 1.2), CFrame.new(bx, 15.15, z), C.SafetyDark, Enum.Material.Metal)
		end
		deco(overhead, "CraneTrolley", Vector3.new(2.2, 0.9, 2.0), CFrame.new(bx, 16.1, trolleyZ), C.SteelDark, Enum.Material.Metal)
		deco(overhead, "HoistCable", Vector3.new(0.12, 2.6, 0.12), CFrame.new(bx, 13.6, trolleyZ), C.SteelDark)
		deco(overhead, "HookBlock", Vector3.new(0.7, 0.9, 0.5), CFrame.new(bx, 12.4, trolleyZ), C.Safety, Enum.Material.Metal)
		sign(overhead, "CraneCapacity", Vector3.new(bx, 15.3, 12.6), Vector3.new(0, 0, 1), 3.4, 0.8, "SWL 10 T", C.SafetyDark, C.Safety)
		-- hanging high-bay lamps from the runways (2 per runway)
		for _, z in { -14, 12 } do
			for _, x in { 14, 33 } do
				local lx = sx * x
				deco(overhead, "LampRod", Vector3.new(0.1, 1.2, 0.1), CFrame.new(lx, 13.4, z), C.SteelDark)
				local shade = deco(overhead, "LampShade", Vector3.new(0.5, 1.6, 1.6), vertical(Vector3.new(lx, 12.65, z)), C.Steel, Enum.Material.Metal, Enum.PartType.Cylinder)
				local bulb = deco(overhead, "LampBulb", Vector3.new(0.1, 1.2, 1.2), vertical(Vector3.new(lx, 12.38, z)), C.Warm, Enum.Material.Neon, Enum.PartType.Cylinder)
				light(bulb, "SpotLight", C.Warm, 26, 1.1, Enum.NormalId.Left) -- cylinder Left face points down when rotated
			end
		end
	end
	-- process piping: hot gas header along the west south runway, cooling water along the east north runway
	local function pipeRun(parent, name, x1, x2, y, z, color, d)
		local len = math.abs(x2 - x1)
		deco(parent, name, Vector3.new(len, d, d), CFrame.new((x1 + x2) / 2, y, z), color, Enum.Material.Metal, Enum.PartType.Cylinder)
		for x = math.min(x1, x2) + 3, math.max(x1, x2) - 1, 6 do
			deco(parent, name .. "Hanger", Vector3.new(0.08, 14.0 - y - d / 2 + 0.4, 0.08), CFrame.new(x, (14.0 + y + d / 2) / 2 - 0.2, z), C.SteelDark)
			deco(parent, name .. "Clamp", Vector3.new(0.18, d + 0.12, d + 0.12), CFrame.new(x, y, z), C.SteelDark, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	pipeRun(overhead, "GasHeader", -41.8, -6, 13.2, -14.9, C.PipeRed, 0.8)
	pipeRun(overhead, "CoolingHeader", 6, 41.8, 13.2, 12.9, C.PipeGreen, 0.7)
	-- furnace risers tie into the headers
	deco(overhead, "GasRiserBranch", Vector3.new(0.6, 0.7, 2.9), CFrame.new(-23.5, 13.2, -13.4), C.PipeRed, Enum.Material.Metal)
	deco(overhead, "GasRiserBranch", Vector3.new(0.6, 0.7, 7.5), CFrame.new(23.5, 13.2, -7.8), C.PipeRed, Enum.Material.Metal)

	------------------------------------------------------------------ 3 central core
	local core = area("CentralCore")
	-- two closed brick blocks (x -4..4; z -18..-6 and 6..18) read as the furnace
	-- houses: chimney on each, louvres high up, stencils facing the crossing
	for _, b in { { z = -12, label = "FURNACE HOUSE 1", face = -18 }, { z = 12, label = "FURNACE HOUSE 2", face = 18 } } do
		deco(core, "ChimneyBase", Vector3.new(5, 3, 5), CFrame.new(0, 15.5, b.z), C.Concrete, Enum.Material.Concrete)
		deco(core, "Chimney", Vector3.new(22, 3.2, 3.2), vertical(Vector3.new(0, 28, b.z)), Color3.fromRGB(110, 74, 60), Enum.Material.Brick, Enum.PartType.Cylinder)
		for _, y in { 22, 30, 37 } do
			deco(core, "ChimneyBand", Vector3.new(0.5, 3.5, 3.5), vertical(Vector3.new(0, y, b.z)), C.SteelDark, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		grime(core, "ChimneySoot", Vector3.new(2.5, 3.3, 3.3), vertical(Vector3.new(0, 38, b.z)), 0.35).Shape = Enum.PartType.Cylinder
		local n = Vector3.new(0, 0, b.face > 0 and 1 or -1)
		sign(core, "HouseSign", Vector3.new(0, 10.4, b.face), n, 6.5, 1.2, b.label, C.SteelDark, C.White)
		for _, x in { -2, 2 } do
			deco(core, "Louvre", Vector3.new(1.6, 1.6, 0.12), onWall(Vector3.new(x, 12.4, b.face + n.Z * 0.06), n), C.SteelDark)
		end
	end
	-- central crossing between the houses (x -4..4, z -6..6): trench drain + corner guards on the pillars
	deco(core, "TrenchDrainFrame", Vector3.new(7.8, 0.03, 0.9), CFrame.new(0, 0.015, 0), C.SteelDark, Enum.Material.Metal)
	for x = -3.5, 3.5, 0.5 do
		deco(core, "TrenchGrateBar", Vector3.new(0.12, 0.04, 0.7), CFrame.new(x, 0.03, 0), C.SteelLight, Enum.Material.Metal)
	end
	for _, w in { { x = -5, z = -3.5 }, { x = 5, z = 3.5 } } do
		for _, cx in { -2, 2 } do
			for _, cz in { -2.5, 2.5 } do
				deco(core, "CornerGuard", Vector3.new(0.3, 1.2, 0.3), CFrame.new(w.x + cx, 0.6, w.z + cz), C.Safety, Enum.Material.SmoothPlastic)
			end
		end
	end

	------------------------------------------------------------------ 4 west aisle (cooling line)
	local west = area("WestAisle")
	-- x -42..-30, z -24..28 along the west wall (face x = -42)
	local wf = Vector3.new(1, 0, 0)
	for i, y in { 9.2, 10.2 } do
		deco(west, "CoolingPipe", Vector3.new(50, 0.55, 0.55), alongZ(Vector3.new(-41.55, y, 2)), i == 1 and C.PipeGreen or C.PipeGrey, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	for z = -22, 26, 6 do
		deco(west, "PipeBracket", Vector3.new(0.9, 1.6, 0.18), CFrame.new(-41.6, 9.7, z), C.SteelDark)
	end
	deco(west, "ValveWheel", Vector3.new(0.1, 1.0, 1.0), CFrame.new(-41.1, 9.2, -6), C.Red, Enum.Material.Metal, Enum.PartType.Cylinder)
	sign(west, "LineSign", Vector3.new(-42, 7.6, 8), wf, 4.2, 0.8, "COOLING WATER", C.PipeGreen, C.White)
	deco(west, "PressureGauge", Vector3.new(0.1, 0.8, 0.8), CFrame.new(-41.9, 5.2, -6), C.White, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	deco(west, "GaugeRiser", Vector3.new(0.12, 3.8, 0.12), CFrame.new(-41.85, 7.2, -6), C.PipeGrey)
	-- low cover block: stencilled slag bin, chipped corner wear
	sign(west, "SlagBinStencil", Vector3.new(-37, 1.8, 16), Vector3.new(0, 0, 1), 3.4, 0.7, "SLAG BIN 03", C.SafetyDark, C.Safety)
	-- floor: walkway edge line along the aisle, expansion joints across it
	deco(west, "WalkwayLine", Vector3.new(0.25, 0.03, 46), CFrame.new(-31.2, 0.015, 2), C.White, Enum.Material.SmoothPlastic)
	for z = -18, 26, 11 do
		deco(west, "ExpansionJoint", Vector3.new(11.6, 0.02, 0.12), CFrame.new(-36, 0.01, z), C.SteelDark, Enum.Material.SmoothPlastic)
	end

	------------------------------------------------------------------ 5 east aisle (electrical / compressed air)
	local east = area("EastAisle")
	-- x 30..42, z -28..24 along the east wall (face x = 42)
	local ef = Vector3.new(-1, 0, 0)
	deco(east, "CableTray", Vector3.new(0.5, 0.25, 50), CFrame.new(41.6, 10.6, -2), C.SteelLight, Enum.Material.DiamondPlate)
	for z = -26, 22, 6 do
		deco(east, "TrayBracket", Vector3.new(0.7, 0.9, 0.15), CFrame.new(41.7, 10.2, z), C.SteelDark)
	end
	for i, z in { -22, -19.5, -17 } do
		deco(east, "BreakerPanel", Vector3.new(2.0, 2.8, 0.24), onWall(Vector3.new(42 - 0.12, 4.6, z), ef), Color3.fromRGB(150, 150, 140))
		deco(east, "PanelConduit", Vector3.new(0.18, 5.6, 0.18), CFrame.new(41.8, 8.8, z), C.SteelLight)
		if i == 2 then
			sign(east, "PanelLabel", Vector3.new(42 - 0.24, 6.4, z), ef, 1.8, 0.4, "DB-2", C.White, C.SafetyDark)
		end
	end
	sign(east, "DangerSign", Vector3.new(42, 7.4, -19.5), ef, 3.6, 0.9, "DANGER 415 V", C.Safety, C.SafetyDark)
	sign(east, "SlagBinStencil", Vector3.new(37, 1.8, -16), Vector3.new(0, 0, -1), 3.4, 0.7, "SLAG BIN 04", C.SafetyDark, C.Safety)
	deco(east, "WalkwayLine", Vector3.new(0.25, 0.03, 46), CFrame.new(31.2, 0.015, -2), C.White, Enum.Material.SmoothPlastic)
	for z = -22, 22, 11 do
		deco(east, "ExpansionJoint", Vector3.new(11.6, 0.02, 0.12), CFrame.new(36, 0.01, z), C.SteelDark, Enum.Material.SmoothPlastic)
	end
	grime(east, "OilStain", Vector3.new(2.4, 0.02, 1.6), CFrame.new(40.2, 0.012, -19.5), 0.6)

	------------------------------------------------------------------ 6 south bay (loading door)
	local south = area("SouthLoading")
	-- x -13..18, z -32..-18; south wall face z = -32
	local sf = Vector3.new(0, 0, 1)
	deco(south, "RollerDoor", Vector3.new(10, 9.5, 0.2), onWall(Vector3.new(2.5, 4.75, -32 + 0.1), sf), Color3.fromRGB(120, 118, 110), Enum.Material.CorrodedMetal)
	for y = 0.6, 9.2, 0.6 do
		deco(south, "DoorSlat", Vector3.new(10, 0.06, 0.06), CFrame.new(2.5, y, -31.76), C.SteelDark)
	end
	deco(south, "DoorHeadBox", Vector3.new(11, 1.0, 0.3), onWall(Vector3.new(2.5, 10.1, -32 + 0.15), sf), C.SteelDark)
	for _, x in { -2.65, 7.65 } do
		deco(south, "DoorGuide", Vector3.new(0.3, 9.6, 0.28), CFrame.new(x, 4.8, -31.86), C.Safety, Enum.Material.SmoothPlastic)
	end
	sign(south, "DoorSign", Vector3.new(2.5, 11.4, -32), sf, 5, 0.9, "LOADING DOOR 3", C.SteelDark, C.White)
	-- hatched keep-clear box in front of the door (flush paint)
	deco(south, "KeepClearEdge", Vector3.new(10, 0.03, 0.3), CFrame.new(2.5, 0.015, -27.5), C.Safety, Enum.Material.SmoothPlastic)
	for i = 0, 6 do
		deco(south, "KeepClearHatch", Vector3.new(0.3, 0.03, 5.6), CFrame.new(-1.5 + i * 1.4, 0.016, -29.8) * CFrame.Angles(0, math.rad(35), 0), C.Safety, Enum.Material.SmoothPlastic)
	end
	grime(south, "TyreWear", Vector3.new(1.2, 0.02, 12), CFrame.new(0.5, 0.012, -24), 0.75)
	grime(south, "TyreWear", Vector3.new(1.2, 0.02, 12), CFrame.new(4.5, 0.012, -24), 0.75)
	-- fire point on the short wall west of the bay (x = -13 face, z -32..-36 is outside; use z -31 on the south wall)
	deco(south, "ExtinguisherBox", Vector3.new(1.1, 1.8, 0.28), onWall(Vector3.new(-10.5, 2.4, -32 + 0.14), sf), C.Red)
	sign(south, "FirePointSign", Vector3.new(-10.5, 4.0, -32), sf, 1.6, 0.5, "FIRE POINT", C.Red, C.White)

	------------------------------------------------------------------ 7 north strip (shift office + electrical alcove)
	local north = area("NorthOffice")
	-- x -18..13, z 18..32; north wall face z = 32
	local nf = Vector3.new(0, 0, -1)
	deco(north, "OfficeWindow", Vector3.new(12, 3.2, 0.12), onWall(Vector3.new(-3, 7.4, 32 - 0.06), nf), C.Glass, Enum.Material.Glass)
	for x = -9, 3, 3 do
		deco(north, "WindowMullion", Vector3.new(0.2, 3.4, 0.2), CFrame.new(x, 7.4, 31.88), C.SteelDark)
	end
	deco(north, "WindowSill", Vector3.new(12.4, 0.25, 0.3), CFrame.new(-3, 5.7, 31.85), C.ConcreteLight, Enum.Material.Concrete)
	deco(north, "WindowHead", Vector3.new(12.4, 0.25, 0.3), CFrame.new(-3, 9.1, 31.85), C.SteelDark)
	local blinds = deco(north, "Blinds", Vector3.new(11.6, 1.4, 0.05), onWall(Vector3.new(-3, 8.3, 32 - 0.03), nf), C.White, Enum.Material.SmoothPlastic)
	blinds.Transparency = 0.2
	deco(north, "OfficeDoor", Vector3.new(3.2, 7, 0.16), onWall(Vector3.new(7.5, 3.5, 32 - 0.08), nf), Color3.fromRGB(80, 90, 96), Enum.Material.Metal)
	deco(north, "DoorHandle", Vector3.new(0.5, 0.12, 0.12), CFrame.new(6.4, 3.4, 31.8), C.SteelLight)
	sign(north, "OfficeSign", Vector3.new(7.5, 7.7, 32), nf, 3.6, 0.7, "SHIFT OFFICE", C.SteelDark, C.White)
	sign(north, "SafetyBoard", Vector3.new(-12.5, 4.4, 32), nf, 3.6, 2.2, "DAYS WITHOUT\nINCIDENT\n0", C.White, C.SafetyDark)
	-- electrical alcove (x -18..-13, z 28..32): switch room door + conduit bundle
	deco(north, "SwitchRoomDoor", Vector3.new(3, 7, 0.16), onWall(Vector3.new(-15.5, 3.5, 32 - 0.08), nf), Color3.fromRGB(100, 104, 80), Enum.Material.Metal)
	sign(north, "SwitchRoomSign", Vector3.new(-15.5, 7.6, 32), nf, 3.6, 0.7, "SWITCH ROOM", C.Safety, C.SafetyDark)
	for i = 0, 2 do
		deco(north, "ConduitBundle", Vector3.new(0.2, 13, 0.2), CFrame.new(-17.7, 6.5, 29 + i * 0.35), C.SteelLight)
	end
	deco(north, "FloorDrain", Vector3.new(1.2, 0.03, 1.2), CFrame.new(-2, 0.015, 25), C.SteelDark, Enum.Material.DiamondPlate)
	for x = -9, 9, 9 do
		deco(north, "ExpansionJoint", Vector3.new(0.12, 0.02, 13.6), CFrame.new(x, 0.01, 25), C.SteelDark, Enum.Material.SmoothPlastic)
	end
	-- alcove by the red side (x 13..18, z 32..38): hose reel station + first aid
	local af = Vector3.new(1, 0, 0) -- wall face x = 13
	deco(north, "HoseReel", Vector3.new(0.3, 1.8, 1.8), CFrame.new(13.2, 3.6, 35), C.Red, Enum.Material.Metal, Enum.PartType.Cylinder)
	deco(north, "HoseReelHub", Vector3.new(0.36, 0.7, 0.7), CFrame.new(13.22, 3.6, 35), C.White, Enum.Material.Metal, Enum.PartType.Cylinder)
	deco(north, "FirstAidBox", Vector3.new(1.2, 1.2, 0.22), onWall(Vector3.new(13 + 0.11, 5.6, 36.8), af), Color3.fromRGB(40, 140, 80))
	sign(north, "HoseSign", Vector3.new(13, 6.4, 35), af, 2.2, 0.5, "FIRE HOSE", C.Red, C.White)

	------------------------------------------------------------------ 8 spawn bays
	local spawns = area("SpawnBays")
	-- Blue bay A (x -52..-30, z -46..-24): tool crib; Red bay B (x 30..52, z 24..46): electrical stores
	sign(spawns, "BayASign", Vector3.new(-52, 10.2, -40), Vector3.new(1, 0, 0), 5, 1.1, "BAY A  -  TOOL CRIB", C.Blue, C.White)
	deco(spawns, "ToolBoard", Vector3.new(5, 3, 0.1), onWall(Vector3.new(-52 + 0.05, 5.2, -44.0 + 5.5), Vector3.new(1, 0, 0)), Color3.fromRGB(64, 72, 82), Enum.Material.SmoothPlastic)
	for i = 0, 4 do
		deco(spawns, "ToolSilhouette", Vector3.new(0.4, 1.6 - (i % 2) * 0.5, 0.06), onWall(Vector3.new(-52 + 0.12, 5.3, -40.5 + i * 0.95), Vector3.new(1, 0, 0)), C.White, Enum.Material.SmoothPlastic)
	end
	sign(spawns, "BayBSign", Vector3.new(52, 10.2, 40), Vector3.new(-1, 0, 0), 5, 1.1, "BAY B  -  STORES", C.Red, C.White)
	for i = 0, 1 do
		deco(spawns, "IsolatorSwitch", Vector3.new(1.4, 1.8, 0.24), onWall(Vector3.new(52 - 0.12, 4.8, 38.5 + i * 2.4), Vector3.new(-1, 0, 0)), Color3.fromRGB(150, 150, 140))
		deco(spawns, "IsolatorHandle", Vector3.new(0.2, 0.7, 0.2), CFrame.new(52 - 0.32, 4.8, 38.5 + i * 2.4), C.Red, Enum.Material.SmoothPlastic)
	end
	deco(spawns, "StoresConduit", Vector3.new(0.2, 8, 0.2), CFrame.new(51.8, 9.6, 39.7), C.SteelLight)
	-- painted direction arrows toward the bay exits (flush)
	for _, a in { { x = -41, z = -27, r = 0 }, { x = -33, z = -30, r = 90 }, { x = 41, z = 27, r = 180 }, { x = 33, z = 30, r = -90 } } do
		local cf = CFrame.new(a.x, 0.016, a.z) * CFrame.Angles(0, math.rad(a.r), 0)
		deco(spawns, "ArrowShaft", Vector3.new(0.4, 0.03, 2.2), cf, C.White, Enum.Material.SmoothPlastic)
		deco(spawns, "ArrowHead", Vector3.new(1.2, 0.03, 0.4), cf * CFrame.new(0, 0, 1.2), C.White, Enum.Material.SmoothPlastic)
	end
	-- PROPOSED COVER (solid): spawn-bay corners only, mirrored for fairness, 4 studs tall max
	-- Blue: tool cabinet in the SW corner, two secured drums on a pallet in the SE corner
	solid("ToolCabinet", Vector3.new(1.2, 4, 3), CFrame.new(-51.4, 2, -43.8), Color3.fromRGB(60, 80, 120), Enum.Material.Metal)
	deco(spawns, "CabinetHandle", Vector3.new(0.1, 1.2, 0.12), CFrame.new(-50.76, 2.3, -43.8), C.SteelLight)
	deco(spawns, "Pallet", Vector3.new(4.6, 0.3, 2.6), CFrame.new(-32.6, 0.15, -44.6), Color3.fromRGB(120, 92, 60), Enum.Material.WoodPlanks)
	for _, x in { -31.5, -33.7 } do
		solid("SecuredDrum", Vector3.new(3, 2, 2), vertical(Vector3.new(x, 1.8, -44.6)), Color3.fromRGB(46, 76, 120), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	deco(spawns, "DrumStrap", Vector3.new(4.6, 0.12, 2.2), CFrame.new(-32.6, 2.4, -44.6), C.Safety, Enum.Material.SmoothPlastic)
	-- Red: locker bank in the NE corner, two secured drums in the NW corner (same footprints)
	solid("LockerBank", Vector3.new(1.2, 4, 3), CFrame.new(51.4, 2, 43.8), Color3.fromRGB(120, 60, 52), Enum.Material.Metal)
	for i = -1, 1 do
		deco(spawns, "LockerVent", Vector3.new(0.06, 0.5, 0.7), CFrame.new(50.77, 3.4, 43.8 + i * 0.95), C.SteelDark)
	end
	deco(spawns, "Pallet", Vector3.new(4.6, 0.3, 2.6), CFrame.new(32.6, 0.15, 44.6), Color3.fromRGB(120, 92, 60), Enum.Material.WoodPlanks)
	for _, x in { 31.5, 33.7 } do
		solid("SecuredDrum", Vector3.new(3, 2, 2), vertical(Vector3.new(x, 1.8, 44.6)), Color3.fromRGB(150, 64, 48), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	deco(spawns, "DrumStrap", Vector3.new(4.6, 0.12, 2.2), CFrame.new(32.6, 2.4, 44.6), C.Safety, Enum.Material.SmoothPlastic)

	------------------------------------------------------------------ 9 perimeter walls (all segments)
	local walls = area("Perimeter")
	for _, f in { map.Boundary, map.Architecture } do
		for _, w in f:GetChildren() do
			if w:IsA("BasePart") and (w.Name:find("Boundary") or w.Name:find("Wall")) then
				local rel = origin:ToObjectSpace(w.CFrame)
				deco(walls, "WallPlinth", Vector3.new(w.Size.X + 0.3, 0.9, w.Size.Z + 0.3), CFrame.new(rel.X, 0.45, rel.Z), C.Concrete, Enum.Material.Concrete)
				if w.Name:find("Boundary") then
					-- steel ledger angle under the coping on long walls, a little weathering at the top
					deco(walls, "LedgerAngle", Vector3.new(w.Size.X + 0.2, 0.3, w.Size.Z + 0.2), CFrame.new(rel.X, 12.6, rel.Z), C.SteelDark)
					grime(walls, "RainStreak", Vector3.new(w.Size.X + 0.06, 1.6, w.Size.Z + 0.06), CFrame.new(rel.X, 13.1, rel.Z), 0.75)
				end
			end
		end
	end
	-- wall exhaust fans high on the long walls (one per side, not repeated)
	for _, fpos in { { p = Vector3.new(-42, 11.4, -14), n = Vector3.new(1, 0, 0) }, { p = Vector3.new(42, 11.4, 14), n = Vector3.new(-1, 0, 0) } } do
		deco(walls, "FanHousing", Vector3.new(2.6, 2.6, 0.28), onWall(fpos.p + fpos.n * 0.14, fpos.n), C.SteelDark)
		local hub = deco(walls, "FanGrille", Vector3.new(0.1, 2.2, 2.2), CFrame.lookAt(fpos.p + fpos.n * 0.3, fpos.p + fpos.n * 2) * CFrame.Angles(0, math.pi / 2, 0), C.SteelLight, Enum.Material.Metal, Enum.PartType.Cylinder)
	end

	------------------------------------------------------------------ 10 outside: the rest of the works
	local outside = area("Backdrop")
	local function block(name, size, pos, color, material)
		return deco(outside, name, size, CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)), color, material)
	end
	-- yard surface so the void doesn't show around the walls
	deco(outside, "YardSurface", Vector3.new(260, 0.2, 240), CFrame.new(0, -1.1, 0), Color3.fromRGB(58, 58, 60), Enum.Material.Asphalt)
	-- west: smelter hall with two stacks
	block("SmelterHall", Vector3.new(26, 26, 60), Vector3.new(-76, 0, -6), Color3.fromRGB(96, 70, 60), Enum.Material.Brick)
	block("SmelterRoof", Vector3.new(27, 1, 61), Vector3.new(-76, 26, -6), C.SteelDark, Enum.Material.CorrodedMetal)
	for _, z in { -24, 12 } do
		deco(outside, "SmelterStack", Vector3.new(60, 4.5, 4.5), vertical(Vector3.new(-80, 30, z)), Color3.fromRGB(120, 80, 64), Enum.Material.Brick, Enum.PartType.Cylinder)
		deco(outside, "StackCap", Vector3.new(1.2, 5, 5), vertical(Vector3.new(-80, 60.4, z)), C.SteelDark, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	-- south: ore silos and a conveyor gantry running toward the hall
	for i, x in { -6, 6, 18 } do
		deco(outside, "Silo", Vector3.new(30, 9, 9), vertical(Vector3.new(x, 15, -62)), Color3.fromRGB(150, 150, 146), Enum.Material.Metal, Enum.PartType.Cylinder)
		deco(outside, "SiloCone", Vector3.new(3, 9.2, 9.2), vertical(Vector3.new(x, 30.8, -62)), C.SteelLight, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	deco(outside, "ConveyorGantry", Vector3.new(3, 2.5, 40), CFrame.new(-20, 24, -50) * CFrame.Angles(math.rad(-12), 0, 0), C.Safety, Enum.Material.Metal)
	-- east: cooling towers and pump house
	for _, z in { -10, 18 } do
		deco(outside, "CoolingTower", Vector3.new(24, 16, 16), vertical(Vector3.new(78, 12, z)), C.ConcreteLight, Enum.Material.Concrete, Enum.PartType.Cylinder)
	end
	block("PumpBuilding", Vector3.new(14, 12, 18), Vector3.new(64, 0, -32), Color3.fromRGB(110, 112, 104), Enum.Material.Concrete)
	-- north: warehouse with a sawtooth roof line
	block("Warehouse", Vector3.new(70, 18, 24), Vector3.new(0, 0, 68), Color3.fromRGB(88, 92, 96), Enum.Material.CorrodedMetal)
	for x = -30, 30, 12 do
		deco(outside, "SawtoothRoof", Vector3.new(11, 4, 24), CFrame.new(x, 20, 68) * CFrame.Angles(0, 0, math.rad(-18)), C.SteelDark, Enum.Material.CorrodedMetal)
	end
	-- a single gantry crane over the yard to the south-west for silhouette
	for _, z in { -70, -54 } do
		block("YardCraneLeg", Vector3.new(1.5, 22, 1.5), Vector3.new(-50, 0, z), C.Safety, Enum.Material.Metal)
	end
	block("YardCraneBeam", Vector3.new(2, 2, 20), Vector3.new(-50, 22, -62), C.Safety, Enum.Material.Metal)

	return count, solidCount, areas
end
