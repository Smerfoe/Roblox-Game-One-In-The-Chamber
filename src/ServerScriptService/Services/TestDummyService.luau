-- TestDummyService: while DevConfig.TestMode is on, places practice dummies in
-- the test map and brings each one back a few seconds after it is eliminated.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DevConfig = require(ReplicatedStorage.Shared.Config.DevConfig)

local TestDummyService = {}

local FACE_BLUE = CFrame.Angles(0, math.rad(90), 0) -- dummies look toward -X (the Blue side)

local folder

local function spawnDummy(worldCFrame)
	local dummy = ServerStorage.Dev.TestDummy:Clone()
	dummy:PivotTo(worldCFrame)
	dummy.Parent = folder
	dummy:FindFirstChildOfClass("Humanoid").Died:Connect(function()
		task.wait(DevConfig.DummyRespawnTime)
		dummy:Destroy()
		spawnDummy(worldCFrame)
	end)
end

function TestDummyService.Start()
	if not DevConfig.TestMode then
		return
	end
	local map = workspace:FindFirstChild(DevConfig.TestMap)
	local floor = map and map.PrimaryPart
	if not floor then
		warn("[TestDummy] Test map or its floor not found")
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "TestDummies"
	folder.Parent = workspace

	local floorTop = floor.Position + Vector3.new(0, floor.Size.Y / 2, 0)
	for _, offset in DevConfig.Dummies do
		spawnDummy(CFrame.new(floorTop + offset) * FACE_BLUE)
	end
end

return TestDummyService
