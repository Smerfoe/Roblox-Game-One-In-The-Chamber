-- PlayerState: shared reading of the attributes the server sets on each player.
-- "Armed" = the player is holding match weapons and plays in first person:
--   InMatch (alive in a match round, set by MatchService) or
--   Location == "Practice" (in the practice room, set by LocationService).
-- Read-only helpers; only the server ever changes these attributes.

local PlayerState = {}

function PlayerState.IsArmed(player)
	return player:GetAttribute("InMatch") == true or player:GetAttribute("Location") == "Practice"
end

-- Calls callback whenever IsArmed might have changed. Returns the connections.
function PlayerState.OnArmedChanged(player, callback)
	return {
		player:GetAttributeChangedSignal("InMatch"):Connect(callback),
		player:GetAttributeChangedSignal("Location"):Connect(callback),
	}
end

return PlayerState
