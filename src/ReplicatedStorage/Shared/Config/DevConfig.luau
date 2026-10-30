-- DevConfig: development-only switches.

local DevConfig = {
	-- TestMode skips the lobby and spawns every player straight into TestMap with
	-- weapons and practice dummies (free-for-all). Off now that matches exist.
	TestMode = false,
	TestMap = "TestingGrounds",
	TestTeam = "Blue",

	-- Practice dummies spawned in TestMap while TestMode is on.
	-- Offsets are in studs from the centre of the map's floor; dummies face the Blue side.
	Dummies = { Vector3.new(18, 0, -8) },
	DummyRespawnTime = 3, -- seconds after a dummy is eliminated
}

return table.freeze(DevConfig)
