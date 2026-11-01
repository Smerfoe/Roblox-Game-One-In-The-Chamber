-- Client-only sound/visual helpers. Never apply damage or change ammo.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config.PolishConfig)
local Effects = {}
local function part(name, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false
	p.CastShadow = false; p.Material = Enum.Material.Neon
	p.Parent = workspace.CurrentCamera
	return p
end
function Effects.Sound(kind, parent)
	local def = Config.Sounds[kind] or (kind=="Draw" and Config.Sounds.Swing)
	if not def or not parent then return end
	local s = Instance.new("Sound")
	s.Name = "Polish_" .. kind; s.SoundId = def.Id; s.Volume = def.Volume
	s.RollOffMinDistance = 8; s.RollOffMaxDistance = def.Range
	s.Parent = parent; s:Play(); Debris:AddItem(s, 5)
	return s
end
function Effects.Muzzle(muzzle)
 if not muzzle then return end
	local flash = part("MuzzleFlash", Vector3.new(0.13, 0.13, 0.42), muzzle.WorldCFrame * CFrame.new(0,0,-0.15), Color3.fromRGB(255,205,104))
	local light = Instance.new("PointLight"); light.Brightness=2; light.Range=9; light.Parent=flash
	Debris:AddItem(flash,0.045)
	local shell = part("EjectedCasing", Vector3.new(0.07,0.07,0.17), muzzle.WorldCFrame*CFrame.new(0.12,0,0.6), Color3.fromRGB(183,139,57))
	shell.Material=Enum.Material.Metal
	TweenService:Create(shell,TweenInfo.new(0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=shell.CFrame*CFrame.new(1.5,-2,0.5)*CFrame.Angles(4,2,3),Transparency=1}):Play()
	Debris:AddItem(shell,0.5)
end
function Effects.Shot(muzzle, endpoint, hit,skipMuzzle)
	if not muzzle or typeof(endpoint) ~= "Vector3" then return end
	local start = muzzle.WorldPosition
	local length = (endpoint - start).Magnitude
	if length > 0.05 then
		local beam = part("BulletTracer", Vector3.new(0.045, 0.045, length), CFrame.lookAt((start + endpoint)/2, endpoint), Color3.fromRGB(255, 218, 135))
		TweenService:Create(beam, TweenInfo.new(0.09), {Transparency = 1}):Play()
		Debris:AddItem(beam, 0.1)
	end
	if not skipMuzzle then Effects.Muzzle(muzzle) end
	if hit then
		local spark = part("BulletImpact", Vector3.new(0.12,0.12,0.12), CFrame.new(endpoint), Color3.fromRGB(255,225,160))
		spark.Shape=Enum.PartType.Ball
		Effects.Sound("Impact",spark)
		task.delay(0.12,function() if spark.Parent then spark.Transparency=1 end end)
		Debris:AddItem(spark,2)
	end

end
return Effects
