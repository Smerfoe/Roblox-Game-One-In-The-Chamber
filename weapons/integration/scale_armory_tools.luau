-- scale_armory_tools: one-time Studio command (Edit mode) that brings the armory
-- prototypes down to the size of the production Service 1911 (longest side 1.30)
-- and Karambit (1.31). Applied 2026-11-01; backup of the unscaled tools:
-- ServerStorage.Backups.BeforeArmoryScaleFix_2026_11_01.
--
-- Model:ScaleTo scales parts, meshes, attachments and Motor6D C0/C1 together, so
-- joints, Grip and Muzzle stay aligned. Each Tool records the factor in
-- attribute "ViewScale"; ViewmodelController multiplies the ArmoryAnimator
-- joint translations by it (the tracks were authored at prototype size).
-- Running it twice does nothing (tools that already have ViewScale are skipped).

local TARGET = { -- longest dimension in studs
	OldWestRevolver = 1.5, HeavyEagle = 1.45, PythonMagnum = 1.6, FrontierRepeater = 2.9,
	BasicKnife = 1.15, ButterflyKnife = 1.35, Machete = 1.9, TrailBowie = 1.6,
}

for _, tool in game.ReplicatedStorage.Assets.ArmoryTools:GetChildren() do
	local target = TARGET[tool.Name]
	if target and not tool:GetAttribute("ViewScale") then
		local model = Instance.new("Model")
		local children = tool:GetChildren()
		for _, child in children do
			child.Parent = model
		end
		local _, size = model:GetBoundingBox()
		local factor = target / math.max(size.X, size.Y, size.Z)
		model:ScaleTo(model:GetScale() * factor)
		for _, child in children do
			child.Parent = tool
		end
		model:Destroy()
		tool:SetAttribute("ViewScale", factor)
		print(("[ScaleArmory] %s x%.3f"):format(tool.Name, factor))
	end
end
