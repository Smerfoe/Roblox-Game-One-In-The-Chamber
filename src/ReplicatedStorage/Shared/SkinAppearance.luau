-- SkinAppearance: the one place a skin is applied to a weapon model.
-- Used by the server (the real Tool other players see), the first-person
-- viewmodel and the inventory preview, so all three always match.
--
-- Only Color and Material are changed. Sizes, positions, joints, scripts,
-- attachments and Tool settings are never touched, so a skin cannot affect
-- hitboxes, muzzle position, ammo or anything else in combat.
-- Always apply to a fresh copy of the base model: skins replace, never stack.

local SkinCatalog = require(script.Parent.Config.SkinCatalog)

local SkinAppearance = {}

-- Resolve what to show: a valid skin for this weapon, otherwise its default.
function SkinAppearance.Resolve(weaponId, skinId)
	if SkinCatalog.IsValidFor(weaponId, skinId) then
		return skinId
	end
	return SkinCatalog.DefaultSkin(weaponId)
end

-- Apply skinId to every BasePart under model (named like the base weapon parts).
-- Returns the skin id actually applied.
function SkinAppearance.Apply(model, weaponId, skinId)
	local resolved = SkinAppearance.Resolve(weaponId, skinId)
	local skin = resolved and SkinCatalog.GetSkin(resolved)
	local parts = skin and skin.Appearance and skin.Appearance.Parts
	if parts then
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				local look = parts[part.Name]
				if look then
					if typeof(look.Color) == "Color3" then
						part.Color = look.Color
					end
					if typeof(look.Material) == "EnumItem" and look.Material.EnumType == Enum.Material then
						part.Material = look.Material
					end
				end
			end
		end
	end
	return resolved
end

return SkinAppearance
