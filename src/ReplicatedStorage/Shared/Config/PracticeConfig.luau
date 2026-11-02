-- PracticeConfig: tuning for the practice room (seconds unless noted).

local PracticeConfig = {
	TargetRespawnTime = 3, -- an eliminated target comes back this much later
	ResetCooldown = 1, -- per player, between uses of the reset station
	TransferCooldown = 1, -- per player, between lobby <-> practice moves
	ZonePollInterval = 0.1, -- how often entrance / return doors are checked
}

return table.freeze(PracticeConfig)
