-- InventoryService: lets players equip skins they own. The server decides.
--
-- Remotes.Inventory (RemoteEvent)
--   client -> server  ("Get")                                   ask for my inventory
--                     ("Equip", requestId, weaponId, skinId)     equip a skin
--   server -> client  ("Snapshot", { Status, Owned = {ids}, Equipped = {[weapon] = skin} })
--                     ("EquipResult", requestId, ok, reason?)
--
-- Equip is accepted only when:
--   the request is well formed and not too fast; the player's data is loaded;
--   the weapon and skin are known and enabled; the skin is made for that weapon;
--   the player owns it (default skins are free); the player is in the lobby
--   (not in a match round or practice: the choice applies to the next loadout).
-- The client only ever sends ids; appearances come from the shared catalog.
--
-- Public: player attribute "Skin_<weaponId>" = the skin shown on that weapon
-- (always a valid id; the default if nothing valid is equipped). The full owned
-- list is sent only to its owner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinCatalog = require(ReplicatedStorage.Shared.Config.SkinCatalog)
local SkinAppearance = require(ReplicatedStorage.Shared.SkinAppearance)
local PlayerState = require(ReplicatedStorage.Shared.PlayerState)
local DataService = require(script.Parent.DataService)

local REQUEST_COOLDOWN = 0.25 -- seconds between equip requests per player
local GET_COOLDOWN = 1

local InventoryService = {}

local remote
local lastRequest = {} -- [player] = os.clock()
local lastGet = {}
local lastRateReply = {}

-- the skin each weapon should show for this player (always valid)
function InventoryService.GetSkin(player, weaponId)
	local stored = DataService.GetEquippedSkin(player, weaponId)
	local skinId = SkinAppearance.Resolve(weaponId, stored)
	-- an equipped skin that is no longer owned (e.g. revoked) falls back to the default
	local skin = SkinCatalog.GetSkin(skinId)
	if skin and not skin.Default and not DataService.OwnsSkin(player, skinId) then
		return SkinCatalog.DefaultSkin(weaponId)
	end
	return skinId
end

local function snapshot(player)
	local status = DataService.GetStatus(player)
	local owned = {}
	local data = DataService.Get(player)
	if data then
		for id in data.Inventory.Skins do
			table.insert(owned, id)
		end
		table.sort(owned)
	end
	local equipped = {}
	for weaponId in SkinCatalog.Weapons do
		equipped[weaponId] = InventoryService.GetSkin(player, weaponId)
	end
	return { Status = status, Owned = owned, Equipped = equipped }
end

local function publish(player)
	if not player.Parent then
		return
	end
	local snap = snapshot(player)
	for weaponId, skinId in snap.Equipped do
		player:SetAttribute("Skin_" .. weaponId, skinId)
	end
	remote:FireClient(player, "Snapshot", snap)
end

local function equip(player, weaponId, skinId)
	local status = DataService.GetStatus(player)
	if status == "Loading" then
		return false, "Your data is still loading"
	elseif status ~= "Ready" or not DataService.IsReady(player) then
		return false, "Saved data is unavailable this session - skins can't be changed"
	end
	if not SkinCatalog.Weapons[weaponId] then
		return false, "Unknown weapon"
	end
	local skin = SkinCatalog.GetSkin(skinId)
	if not skin or not skin.Enabled then
		return false, "Unknown skin"
	end
	if skin.Weapon ~= weaponId then
		return false, "That skin doesn't fit this weapon"
	end
	if not skin.Default and not DataService.OwnsSkin(player, skinId) then
		return false, "You don't own that skin"
	end
	if PlayerState.IsArmed(player) or player:GetAttribute("MatchId") ~= nil then
		return false, "Return to the lobby to change skins"
	end
	if InventoryService.GetSkin(player, weaponId) == skinId then
		return true -- already equipped
	end
	local changed = DataService.Update(player, function(data)
		if skin.Default then
			data.Equipped[weaponId] = nil -- default needs no entry
		else
			data.Equipped[weaponId] = skinId
		end
		return true
	end)
	if not changed then
		return false, "Couldn't save the change - try again"
	end
	return true
end

local function onRequest(player, action, ...)
	if action == "Get" then
		local now = os.clock()
		if lastGet[player] and now - lastGet[player] < GET_COOLDOWN then
			return
		end
		lastGet[player] = now
		publish(player)
	elseif action == "Equip" then
		local requestId, weaponId, skinId = ...
		if type(requestId) ~= "number" or requestId ~= requestId or math.abs(requestId) > 2 ^ 31 then
			return -- malformed; no reply possible
		end
		local now = os.clock()
		local ok, reason
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			-- Bound rejection replies as well as successful mutations.
			if lastRateReply[player] and now - lastRateReply[player] < REQUEST_COOLDOWN then return end
			lastRateReply[player] = now
			ok, reason = false, "Too fast - try again"
		else
			lastRequest[player] = now -- malformed requests consume the same budget
			if type(weaponId) ~= "string" or type(skinId) ~= "string" or #weaponId > 64 or #skinId > 64 then
				ok, reason = false, "Invalid request"
			else
				ok, reason = equip(player, weaponId, skinId)
			end
		end
		remote:FireClient(player, "EquipResult", requestId, ok, reason)
		if ok then
			publish(player)
		end
	end
end

function InventoryService.Start()
	remote = ReplicatedStorage.Remotes:FindFirstChild("Inventory")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Inventory"
		remote.Parent = ReplicatedStorage.Remotes
	end
	remote.OnServerEvent:Connect(onRequest)
	DataService.Changed:Connect(publish)
	Players.PlayerAdded:Connect(publish) -- defaults (status Loading) until data loads
	for _, player in Players:GetPlayers() do
		publish(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		lastGet[player] = nil
		lastRateReply[player] = nil
	end)
end

return InventoryService
