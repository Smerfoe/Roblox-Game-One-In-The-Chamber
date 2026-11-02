-- ShopCatalog: what the lobby shop shows. PREVIEW ONLY.
-- There is no currency, no prices, no ownership and no purchasing yet, so every
-- entry is shown as unavailable. Nothing here changes gameplay.
-- Rule for later: cosmetics must never change damage, hitboxes, reach, fire rate
-- or visibility, and any future purchase/equip must be validated on the server
-- (item id, price, balance, ownership, eligibility). The menu never authorizes anything.

local ShopCatalog = {
	Preview = true, -- purchases are not implemented
	Notice = "PREVIEW CATALOG - purchases are not available yet",
	Items = {
		{ Id = "pistol_standard", Name = "Service 1911 - Standard", Category = "Pistol", Note = "The match pistol everyone uses" },
		{ Id = "knife_standard", Name = "Karambit - Standard", Category = "Knife", Note = "The match knife everyone uses" },
		{ Id = "pistol_finishes", Name = "Pistol finishes", Category = "Cosmetic", Note = "Planned - not available yet" },
		{ Id = "knife_finishes", Name = "Knife finishes", Category = "Cosmetic", Note = "Planned - not available yet" },
	},
}

return table.freeze(ShopCatalog)
