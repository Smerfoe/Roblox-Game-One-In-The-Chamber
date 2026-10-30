-- MatchConfig: timings and rules for matches (seconds unless noted).

local MatchConfig = {
	Map = "TestingGrounds", -- arena in Workspace that matches use (one match at a time).
	-- Also integrated and tested: "TestingGroundsNew", "ContainerYard", "PumpHouse".

	RoundsToWin = 3, -- best of five: first team to win 3 rounds wins the match
	MaxRounds = 9, -- safety cap for drawn rounds; after this the higher score wins (equal = draw)

	CountdownTime = 3, -- combat is disabled during the countdown
	RoundTime = 180, -- a round that runs this long ends; more players alive wins, equal is a draw
	RoundEndTime = 3, -- the round result is shown this long before the next round
	ResultTime = 4, -- how long the match result is shown before everyone returns to the lobby

	RespawnDelay = 3, -- outside a match, a player who dies gets a new character this much later
	QueuePollInterval = 0.2, -- how often the lobby pads are checked
	PadHeight = 8, -- studs above a pad that still count as standing on it
}

return table.freeze(MatchConfig)
