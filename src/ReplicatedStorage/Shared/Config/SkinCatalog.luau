-- SkinCatalog: the one authoritative list of weapon skins (cosmetic only).
--
-- Rules:
--   * Skin ids are permanent. Never rename or reuse one; retire it with Enabled = false.
--   * A skin only changes how parts look (Color / Material). It must never hold
--     damage, ammo, range, cooldown, hitbox, size or any other gameplay value.
--     SkinAppearance only reads Color and Material, so nothing else here can
--     reach the game even by mistake.
--   * Every weapon has a Default skin that everyone owns.
--   * Ownership lives in the server's player data (DataService). Being listed
--     here does NOT mean a player owns a skin.
--
-- The current finishes are plain colour/material proofs on the existing weapon
-- models (Proof = true). Production finishes with real textures come later.

local Catalog = {}

-- Weapons that can wear skins. Keys are the Tool names in ReplicatedStorage.Assets.Weapons.
Catalog.Weapons = {
	Service1911 = { Name = "Service 1911", Slot = "Pistol", DefaultSkin = "service1911.default", Order = 1 },
	Karambit = { Name = "Karambit", Slot = "Knife", DefaultSkin = "karambit.default", Order = 2 },
}

-- Appearance: Parts[partName] = { Color = Color3, Material = Enum.Material }.
-- Parts not listed keep the base model's look.
Catalog.Skins = {
	-- Service 1911 (parts: Slide, Handle (frame), Barrel, Hammer, Trigger, Magazine)
	["service1911.default"] = {
		Weapon = "Service1911", Name = "Factory", Default = true, Enabled = true, Order = 1,
		Appearance = { Parts = {} },
	},
	["service1911.slate"] = {
		Weapon = "Service1911", Name = "Slate", Enabled = true, Proof = true, Order = 2,
		Appearance = { Parts = {
			Slide = { Color = Color3.fromRGB(58, 72, 92), Material = Enum.Material.Metal },
			Handle = { Color = Color3.fromRGB(34, 38, 44), Material = Enum.Material.Metal },
		} },
	},
	["service1911.desert"] = {
		Weapon = "Service1911", Name = "Desert", Enabled = true, Proof = true, Order = 3,
		Appearance = { Parts = {
			Slide = { Color = Color3.fromRGB(176, 150, 108), Material = Enum.Material.SmoothPlastic },
			Handle = { Color = Color3.fromRGB(150, 126, 88), Material = Enum.Material.SmoothPlastic },
			Magazine = { Color = Color3.fromRGB(60, 58, 54), Material = Enum.Material.Metal },
		} },
	},
	["service1911.crimson"] = {
		Weapon = "Service1911", Name = "Crimson", Enabled = true, Proof = true, Order = 4,
		Appearance = { Parts = {
			Slide = { Color = Color3.fromRGB(118, 30, 34), Material = Enum.Material.Metal },
			Handle = { Color = Color3.fromRGB(40, 32, 32), Material = Enum.Material.Metal },
		} },
	},

	-- Karambit (parts: Blade, Handle, Ring)
	["karambit.default"] = {
		Weapon = "Karambit", Name = "Factory", Default = true, Enabled = true, Order = 1,
		Appearance = { Parts = {} },
	},
	["karambit.forest"] = {
		Weapon = "Karambit", Name = "Forest", Enabled = true, Proof = true, Order = 2,
		Appearance = { Parts = {
			Handle = { Color = Color3.fromRGB(56, 78, 52), Material = Enum.Material.SmoothPlastic },
			Ring = { Color = Color3.fromRGB(56, 78, 52), Material = Enum.Material.SmoothPlastic },
		} },
	},
	["karambit.ember"] = {
		Weapon = "Karambit", Name = "Ember", Enabled = true, Proof = true, Order = 3,
		Appearance = { Parts = {
			Handle = { Color = Color3.fromRGB(196, 84, 36), Material = Enum.Material.SmoothPlastic },
			Ring = { Color = Color3.fromRGB(196, 84, 36), Material = Enum.Material.SmoothPlastic },
			Blade = { Color = Color3.fromRGB(46, 44, 44), Material = Enum.Material.Metal },
		} },
	},
	["karambit.ivory"] = {
		Weapon = "Karambit", Name = "Ivory", Enabled = true, Proof = true, Order = 4,
		Appearance = { Parts = {
			Handle = { Color = Color3.fromRGB(226, 220, 204), Material = Enum.Material.SmoothPlastic },
			Ring = { Color = Color3.fromRGB(226, 220, 204), Material = Enum.Material.SmoothPlastic },
		} },
	},
}

-- helpers -------------------------------------------------------------------

function Catalog.GetSkin(skinId)
	return type(skinId) == "string" and Catalog.Skins[skinId] or nil
end

-- true when skinId is a known, enabled skin made for weaponId
function Catalog.IsValidFor(weaponId, skinId)
	local skin = Catalog.GetSkin(skinId)
	return skin ~= nil and skin.Enabled == true and skin.Weapon == weaponId and Catalog.Weapons[weaponId] ~= nil
end

function Catalog.DefaultSkin(weaponId)
	local weapon = Catalog.Weapons[weaponId]
	return weapon and weapon.DefaultSkin or nil
end

-- enabled skins for one weapon, sorted for display
function Catalog.SkinsFor(weaponId)
	local list = {}
	for id, skin in Catalog.Skins do
		if skin.Weapon == weaponId and skin.Enabled then
			table.insert(list, id)
		end
	end
	table.sort(list, function(a, b)
		return Catalog.Skins[a].Order < Catalog.Skins[b].Order
	end)
	return list
end

-- deep-freeze so no script can change the catalog at runtime
local function freeze(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			freeze(v)
		end
	end
	return table.freeze(t)
end
freeze(Catalog.Weapons)
freeze(Catalog.Skins)

return table.freeze(Catalog)
