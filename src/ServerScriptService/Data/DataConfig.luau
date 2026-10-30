-- DataConfig: player-data settings (server only).

local DataConfig = {
	-- Separate stores so Studio testing can never touch live player data.
	StoreName = "OITC_PlayerData_v1",
	StudioStoreName = "OITC_PlayerData_STUDIO_v1",
	KeyPrefix = "u_", -- key = KeyPrefix .. UserId

	-- In Studio without "Enable Studio Access to API Services", DataStores are
	-- unavailable; an in-memory store is used instead (lost when the test stops).
	-- Live servers always use the real DataStore.
	StudioFallbackToMemory = true,

	-- Session lock: one server owns a player's data at a time. The owner refreshes
	-- the lock on every save; a lock older than this is treated as abandoned
	-- (for example a crashed server) and may be taken over.
	LockStaleAfter = 300, -- seconds
	LockWaitAttempts = 6, -- while another live server holds the lock
	LockRetryDelay = 5, -- seconds between those attempts

	-- Retries with exponential backoff for DataStore errors.
	LoadAttempts = 5,
	SaveAttempts = 4,
	RetryBaseDelay = 1, -- 1, 2, 4, 8 ... seconds
	RetryMaxDelay = 10,

	AutosaveInterval = 60, -- also refreshes the session lock
	SaveDelayAfterChange = 5, -- batch quick changes into one write

	-- Developer test grants (server-only functions; there is no remote for them).
	-- Studio: always allowed (Studio uses its own store).
	-- Live servers: only for these UserIds, and only if AllowLiveDevGrants is true.
	DeveloperUserIds = { 127009333 },
	AllowLiveDevGrants = false,
}

return table.freeze(DataConfig)
