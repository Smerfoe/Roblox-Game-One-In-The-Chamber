-- WeaponConfig: all weapon tuning numbers live here.

local WeaponConfig = {
	Pistol = {
		ToolName = "Service1911", -- Tool in ReplicatedStorage.Assets.Weapons
		StartAmmo = 1, -- bullets given on every spawn
		MaxAmmo = 1,
		FireCooldown = 0.35, -- seconds between accepted shots
		Range = 300, -- studs
		AutoSwitchDelay = 0.25, -- after an empty miss, switch to the knife this much later

		-- First-person view: where the gun's Grip sits relative to the camera
		-- (right, down, forward in studs).
		ViewOffset = CFrame.new(0.9, -0.85, -2.1),
	},

	Knife = {
		ToolName = "Karambit",
		FrontDamage = 50,
		BackDamage = 100, -- backstab
		BackstabHalfAngle = 45, -- attacker within a 90-degree cone at the target's back
		Range = 6, -- studs, horizontal distance between the two characters' centres
		HalfAngle = 50, -- target must be within this many degrees of where the attacker faces
		MaxHeightDifference = 4, -- studs
		Cooldown = 0.6, -- seconds between accepted swings
		HitDelay = 0.15, -- the server resolves a swing this long after accepting it

		-- turned 40 degrees so the hook is seen from the side instead of edge-on
		ViewOffset = CFrame.new(0.85, -0.8, -1.7) * CFrame.Angles(0, math.rad(40), 0),
	},
}

return table.freeze(WeaponConfig)
