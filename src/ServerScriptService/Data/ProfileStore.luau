-- ProfileStore: loads and saves one record per player with a session lock.
--
-- Stored record (one DataStore key per player):
--   { Data = <Schema data>, Lock = { Session = id, Time = os.time() } | nil,
--     SavedAt = time, SaveCount = n }
--
-- Guarantees:
--   * Every read-modify-write goes through UpdateAsync, so concurrent writers
--     can't silently overwrite each other.
--   * Load takes the lock in the same UpdateAsync. If another live session holds
--     it, we wait and retry; we only take over a lock that has gone stale.
--   * A save only writes while WE still hold the lock. If another session took
--     over, the save is cancelled and this profile stops saving for good.
--   * A failed or refused load returns no profile. Nothing is ever written for
--     it, so existing data can't be replaced by defaults.
--   * Unreadable records and data from a newer schema are left untouched.
--
-- `store` is any object with UpdateAsync(key, transform, userIds?) (a real
-- DataStore wrapper or MemoryStore). The clock and wait are injectable for tests.

local Schema = require(script.Parent.Schema)

local function validRecord(record)
	if record == nil then
		return true
	end
	if type(record) ~= "table" or type(record.Data) ~= "table" then
		return false
	end
	local version = record.Data.SchemaVersion
	if version ~= nil and (type(version) ~= "number" or version ~= version
		or version == math.huge or version % 1 ~= 0 or version < 1) then
		return false
	end
	local count = record.SaveCount
	if count ~= nil and (type(count) ~= "number" or count ~= count
		or count == math.huge or count < 0 or count % 1 ~= 0) then
		return false
	end
	local lock = record.Lock
	if lock ~= nil and (type(lock) ~= "table" or type(lock.Session) ~= "string" or lock.Session == ""
		or type(lock.Time) ~= "number" or lock.Time ~= lock.Time or math.abs(lock.Time) == math.huge) then
		return false
	end
	return true
end

local ProfileStore = {}
ProfileStore.__index = ProfileStore

function ProfileStore.new(options)
	assert(options.store and options.sessionId and options.config, "store, sessionId and config are required")
	return setmetatable({
		store = options.store,
		loadSequence = 0,
		sessionId = options.sessionId,
		config = options.config,
		now = options.now or os.time,
		wait = options.wait or task.wait,
		log = options.log or function() end,
	}, ProfileStore)
end

function ProfileStore:backoff(attempt)
	local c = self.config
	return math.min(c.RetryBaseDelay * 2 ^ (attempt - 1), c.RetryMaxDelay)
end

-- Load(key, userIds?) -> result, profileOrInfo
--   "Ok", profile           profile = { Key, Data, Active = true, Session }
--   "Locked", lockInfo      another live session still holds the lock
--   "Failed", errorMessage  store errors on every attempt
--   "Incompatible", nil     saved by a newer schema version (left untouched)
--   "Corrupt", nil          stored value isn't a record (left untouched)
function ProfileStore:Load(key, userIds)
	local c = self.config
	-- A server may have an old load/release still in flight when a player rejoins.
	-- Each acquisition needs its own identity; sharing only a server GUID lets the
	-- old handle overwrite or release the new handle's record.
	self.loadSequence += 1
	local session = self.sessionId .. ":" .. tostring(self.loadSequence)
	local errorAttempts, lockAttempts = 0, 0
	local lastError
	while true do
		local outcome
		local ok, err = pcall(function()
			self.store:UpdateAsync(key, function(record)
				outcome = nil -- the transform may run more than once
				if not validRecord(record) then
					outcome = { kind = "Corrupt" }
					return nil
				end
				record = record or {}
				if Schema.IsNewer(record.Data) then
					outcome = { kind = "Incompatible" }
					return nil
				end
				local lock = record.Lock
				local now = self.now()
				if type(lock) == "table" and lock.Session ~= session
					and type(lock.Time) == "number" and now - lock.Time < c.LockStaleAfter then
					outcome = { kind = "Locked", lock = { Session = lock.Session, Age = now - lock.Time } }
					return nil
				end
				local data = Schema.Migrate(record.Data)
				record.Data = data
				record.Lock = { Session = session, Time = now }
				outcome = {
					kind = "Ok",
					data = Schema.DeepCopy(data),
					tookStaleLock = type(lock) == "table" and lock.Session ~= session,
					isNew = record.SaveCount == nil,
				}
				return record
			end, userIds)
		end)
		if ok and outcome then
			if outcome.kind == "Ok" then
				if outcome.tookStaleLock then
					self.log("took over a stale session lock for", key)
				end
				return "Ok", { Key = key, Data = outcome.data, Active = true, Session = session, IsNew = outcome.isNew }
			elseif outcome.kind == "Locked" then
				lockAttempts += 1
				if lockAttempts >= c.LockWaitAttempts then
					return "Locked", outcome.lock
				end
				self.wait(c.LockRetryDelay)
			else
				return outcome.kind, nil
			end
		else
			lastError = ok and "transform did not run" or tostring(err)
			errorAttempts += 1
			self.log("load attempt", errorAttempts, "failed for", key, lastError)
			if errorAttempts >= c.LoadAttempts then
				return "Failed", lastError
			end
			self.wait(self:backoff(errorAttempts))
		end
	end
end

-- Save(profile, release?) -> result
--   "Ok"        written (and the lock released if release = true)
--   "LostLock"  another session owns this data now; profile deactivated, nothing written
--   "Failed"    store errors on every attempt (profile stays active; try again later)
--   "Inactive"  profile was already released or lost
function ProfileStore:Save(profile, release, userIds)
	if not profile.Active then
		return "Inactive"
	end
	local c = self.config
	local snapshot = Schema.DeepCopy(profile.Data)
	local lastError
	for attempt = 1, c.SaveAttempts do
		local outcome
		local ok, err = pcall(function()
			self.store:UpdateAsync(profile.Key, function(record)
				outcome = nil
				if type(record) ~= "table" or type(record.Lock) ~= "table" or record.Lock.Session ~= profile.Session then
					outcome = "LostLock"
					return nil
				end
				record.Data = Schema.DeepCopy(snapshot)
				if release then
					record.Lock = nil
				else
					record.Lock = { Session = profile.Session, Time = self.now() }
				end
				record.SavedAt = self.now()
				record.SaveCount = (record.SaveCount or 0) + 1
				outcome = "Ok"
				return record
			end, userIds)
		end)
		if ok and outcome == "Ok" then
			if release then
				profile.Active = false
			end
			return "Ok"
		elseif ok and outcome == "LostLock" then
			profile.Active = false
			self.log("session lock lost for", profile.Key, "- saving stopped")
			return "LostLock"
		end
		lastError = ok and "transform did not run" or tostring(err)
		self.log("save attempt", attempt, "failed for", profile.Key, lastError)
		if attempt < c.SaveAttempts then
			self.wait(self:backoff(attempt))
		end
	end
	return "Failed", lastError
end

return ProfileStore
