-- MenuController: the single owner of which lobby menu is open.
--   * At most one menu is open. Opening one closes the current one first.
--   * Menus register Open/Close callbacks; only this module calls them.
--   * Lobby menus are only for living lobby players. The moment the player is
--     in a match (MatchId), armed, in practice or dead, the open menu closes.
--   * Menus never lock the camera, mouse or movement, so closing has nothing to
--     restore; anything a menu does change must be undone in its Close callback.
-- Changed fires (menuName or nil) after every change.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local MenuController = {}

local menus = {} -- [name] = { Open = fn(context), Close = fn() }
local current -- name of the open menu
local changed = Instance.new("BindableEvent")
MenuController.Changed = changed.Event

function MenuController.Register(name, callbacks)
	assert(not menus[name], "menu registered twice: " .. name)
	menus[name] = callbacks
end

-- True while the player may use lobby menus.
function MenuController.IsLobbyEligible()
	if player:GetAttribute("MatchId") ~= nil or player:GetAttribute("InMatch") == true then
		return false
	end
	local location = player:GetAttribute("Location")
	if location ~= nil and location ~= "Lobby" then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function MenuController.Current()
	return current
end

function MenuController.Close(name)
	if current == nil or (name ~= nil and current ~= name) then
		return
	end
	local closing = current
	current = nil
	menus[closing].Close()
	changed:Fire(nil)
end

function MenuController.Open(name, context)
	assert(menus[name], "unknown menu: " .. tostring(name))
	if current == name or not MenuController.IsLobbyEligible() then
		return false
	end
	if current then
		local closing = current
		current = nil
		menus[closing].Close()
	end
	current = name
	menus[name].Open(context)
	changed:Fire(name)
	return true
end

function MenuController.Toggle(name, context)
	if current == name then
		MenuController.Close(name)
	else
		MenuController.Open(name, context)
	end
end

function MenuController.Start()
	-- one cheap check per frame catches every way of leaving the lobby state
	-- (match start, practice, death, respawn) without extra connections per life
	RunService.Heartbeat:Connect(function()
		if current and not MenuController.IsLobbyEligible() then
			MenuController.Close()
		end
	end)
end

return MenuController
