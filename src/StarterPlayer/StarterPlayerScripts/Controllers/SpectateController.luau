-- SpectateController: what an eliminated player sees until their next life.
-- While the local player is in a match, has no living character, and the round
-- is still being fought (Combat) or has just ended (RoundEnd):
--   * if teammates are still alive: follow one of them; Q / E (or the arrow
--     keys, or a click) switches between them.
--   * otherwise (always the case in 1v1): a fixed overview of the arena.
-- The normal camera comes back as soon as the player has a living character
-- again (next round), or when the match moves to its result / the lobby.
-- Everything is read from attributes the server sets; nothing here affects combat.
-- On touch screens, on-screen arrow buttons switch teammates.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MatchConfig = require(ReplicatedStorage.Shared.Config.MatchConfig)

local player = Players.LocalPlayer

local SPECTATE_PHASES = { Combat = true, RoundEnd = true }
local NEXT_KEYS = { [Enum.KeyCode.E] = true, [Enum.KeyCode.Right] = true, [Enum.KeyCode.ButtonR1] = true }
local PREVIOUS_KEYS = { [Enum.KeyCode.Q] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.ButtonL1] = true }

local ENTER_DELAY = 0.2 -- seconds of being eliminated before the camera switches (avoids a
-- one-frame cut when the final round ends the whole match in the same moment)

local SpectateController = {}

local spectating = false
local eligibleSince -- os.clock() when spectating first became possible
local target -- Player being followed, or nil for the arena overview
local gui, title, status, previousButton, nextButton

local function aliveHumanoid(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function shouldSpectate()
	return player:GetAttribute("MatchId") ~= nil
		and SPECTATE_PHASES[player:GetAttribute("MatchPhase")] == true
		and aliveHumanoid(player.Character) == nil
end

-- A living teammate in the same match (the server's InMatch flag means "alive this round").
local function isLivingTeammate(other)
	return other ~= player
		and other.Parent ~= nil
		and other:GetAttribute("MatchId") == player:GetAttribute("MatchId")
		and other:GetAttribute("Team") == player:GetAttribute("Team")
		and other:GetAttribute("InMatch") == true
		and aliveHumanoid(other.Character) ~= nil
end

local function livingTeammates()
	local list = {}
	for _, other in Players:GetPlayers() do
		if isLivingTeammate(other) then
			table.insert(list, other)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	return list
end

-- step 0 keeps the current target if it is still valid; +1 / -1 cycle.
local function choose(step)
	local list = livingTeammates()
	if #list == 0 then
		target = nil
		return
	end
	local index = table.find(list, target)
	if not index then
		target = list[1]
	elseif step ~= 0 then
		target = list[(index - 1 + step) % #list + 1]
	end
end

local function overviewCFrame()
	local map = workspace:FindFirstChild(MatchConfig.Map)
	if not map then
		return nil
	end
	local box, size = map:GetBoundingBox()
	local center = box.Position
	local span = math.max(size.X, size.Z)
	local eye = center + Vector3.new(0, span * 0.75, span * 0.55)
	return CFrame.lookAt(eye, center)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "SpectateHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	local function label(name, y, textSize)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.new(0.5, 0, 1, y)
		l.Size = UDim2.fromOffset(700, textSize + 10)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBold
		l.TextSize = textSize
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.5
		l.Parent = gui
		return l
	end
	title = label("Title", -70, 26)
	status = label("Status", -40, 18)

	local function arrow(name, text, xOffset, step)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, xOffset, 1, -62)
		b.Size = UDim2.fromOffset(48, 40)
		b.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
		b.BackgroundTransparency = 0.35
		b.BorderSizePixel = 0
		b.Font = Enum.Font.GothamBold
		b.TextSize = 24
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = text
		b.Visible = false
		b.Parent = gui
		b.Activated:Connect(function()
			if spectating then
				SpectateController.Cycle(step)
			end
		end)
		return b
	end
	previousButton = arrow("Previous", "<", -330, -1)
	nextButton = arrow("Next", ">", 330, 1)
	gui.Parent = player:WaitForChild("PlayerGui")
end

local function roundStatus()
	local phase = player:GetAttribute("MatchPhase")
	local round = player:GetAttribute("Round") or 1
	local score = ("BLUE %d - %d RED"):format(player:GetAttribute("ScoreBlue") or 0, player:GetAttribute("ScoreRed") or 0)
	if phase == "Combat" then
		local remaining = math.max(0, (player:GetAttribute("PhaseEndsAt") or 0) - workspace:GetServerTimeNow())
		return ("Round %d  -  %d:%02d left  -  %s"):format(round, math.floor(remaining / 60), math.floor(remaining % 60), score)
	end
	return ("Round %d over  -  %s"):format(round, score)
end

local function stop()
	if not spectating then
		return
	end
	spectating = false
	target = nil
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	else
		camera.CameraSubject = nil -- Roblox points the camera at the next character when it loads
	end
end

local function update()
	if not shouldSpectate() then
		eligibleSince = nil
		stop()
		return
	end
	if not spectating then
		eligibleSince = eligibleSince or os.clock()
		if os.clock() - eligibleSince < ENTER_DELAY then
			return
		end
		spectating = true
		target = nil
	end
	choose(0) -- drops a target that died or left, picks up one that is available
	local camera = workspace.CurrentCamera
	local humanoid = target and aliveHumanoid(target.Character)
	if humanoid then
		camera.CameraType = Enum.CameraType.Custom
		if camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
		local count = #livingTeammates()
		title.Text = "SPECTATING  " .. target.DisplayName
		status.Text = roundStatus() .. (count > 1 and "   |   Q / E to switch" or "")
		previousButton.Visible = count > 1
		nextButton.Visible = count > 1
	else
		local view = overviewCFrame()
		if view then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = view
		end
		title.Text = "SPECTATING  -  Arena overview"
		status.Text = roundStatus()
		previousButton.Visible = false
		nextButton.Visible = false
	end
	gui.Enabled = true
end

function SpectateController.Cycle(step)
	choose(step)
end

function SpectateController.GetTarget()
	return spectating, target
end

function SpectateController.Start()
	build()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not spectating or gameProcessed then
			return
		end
		if NEXT_KEYS[input.KeyCode] or input.UserInputType == Enum.UserInputType.MouseButton1 then
			choose(1)
		elseif PREVIOUS_KEYS[input.KeyCode] then
			choose(-1)
		end
	end)
	-- after the default camera has run, so our choice wins this frame
	RunService:BindToRenderStep("Spectate", Enum.RenderPriority.Camera.Value + 2, update)
end

return SpectateController
