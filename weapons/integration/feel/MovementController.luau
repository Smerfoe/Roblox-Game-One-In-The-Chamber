local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Effects=require(RS.Shared.PolishEffects)
local player=Players.LocalPlayer
local remote=RS.Remotes:WaitForChild("Movement")
local Controller={}
local held=false
local posing={}
local lastStep=0
local cameraHumanoid,baseCameraOffset
local fovCamera,baseFov
local PlayerState=require(RS.Shared.PlayerState)
local function clearPose(ch)
	local entry=posing[ch]
	if entry then for joint,data in entry do if joint.Parent and joint.Transform:FuzzyEq(data.last,0.0001) then joint.Transform=data.base end end end
	posing[ch]=nil
end
local function pose(ch,joint,extra)
	if not joint then return end
	local entry=posing[ch]; if not entry then entry={}; posing[ch]=entry end
	local data=entry[joint]
	if not data then data={base=joint.Transform}; entry[joint]=data
	elseif not joint.Transform:FuzzyEq(data.last,0.0001) then data.base=joint.Transform end
	data.last=data.base*extra; joint.Transform=data.last
end
function Controller.Start()
	UIS.InputBegan:Connect(function(input,processed)
		if processed or UIS:GetFocusedTextBox() then return end
		if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then held=true; remote:FireServer("Sprint")
		elseif input.KeyCode==Enum.KeyCode.C then remote:FireServer("Slide") end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.LeftShift or input.KeyCode==Enum.KeyCode.RightShift then held=false; remote:FireServer("Walk") end
	end)
	UIS.WindowFocusReleased:Connect(function() held=false; remote:FireServer("Walk") end)
	UIS.TextBoxFocused:Connect(function() held=false; remote:FireServer("Walk") end)
	for _,attribute in {"Location","MatchPhase"} do
		player:GetAttributeChangedSignal(attribute):Connect(function() held=false; remote:FireServer("Walk") end)
	end
	local function watch(p)
		p:GetAttributeChangedSignal("MovementState"):Connect(function()
			local ch=p.Character; local root=ch and ch:FindFirstChild("HumanoidRootPart")
			if p:GetAttribute("MovementState")=="Slide" then Effects.Sound("Slide",root)
			elseif p==player and held and p:GetAttribute("MovementState")=="Walk" then
				task.delay(0.12,function() if held then remote:FireServer("Sprint") end end)
			end
		end)
		p.CharacterRemoving:Connect(function(ch) clearPose(ch); if p==player then held=false end end)
	end
	Players.PlayerAdded:Connect(watch); for _,p in Players:GetPlayers() do watch(p) end
	RunService.PreSimulation:Connect(function()
		local now=os.clock()
		for _,p in Players:GetPlayers() do
			local ch=p.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid")
			local mode=p:GetAttribute("MovementState")
			if not h or h.Health<=0 or (mode~="Slide" and mode~="Sprint") then if ch then clearPose(ch) end; continue end
			local sliding=mode=="Slide"
			local root=ch:FindFirstChild("HumanoidRootPart")
			local moving=root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude>2
			if not moving and not sliding then clearPose(ch); continue end
			local torso=ch:FindFirstChild("LowerTorso") or ch:FindFirstChild("Torso")
			local rootJoint=torso and torso:FindFirstChild("Root") or (root and root:FindFirstChild("RootJoint"))
			pose(ch,rootJoint,sliding and CFrame.new(0,-0.65,0)*CFrame.Angles(math.rad(-25),0,0) or CFrame.Angles(math.rad(-8),0,0))
			for _,side in {"Left","Right"} do
				local sign=side=="Left" and 1 or -1
				local thigh=ch:FindFirstChild(side.."UpperLeg")
				local hip=thigh and thigh:FindFirstChild(side.."Hip") or (torso and torso:FindFirstChild(side.." Hip"))
				local shin=ch:FindFirstChild(side.."LowerLeg")
				pose(ch,hip,CFrame.Angles(sliding and math.rad(side=="Left" and -65 or -100) or math.sin(now*14)*0.2*sign,0,0))
				if shin then pose(ch,shin:FindFirstChild(side.."Knee"),CFrame.Angles(sliding and math.rad(side=="Left" and 85 or 25) or 0,0,0)) end
			end
			if p==player and moving and not sliding and h.FloorMaterial~=Enum.Material.Air and now-lastStep>0.28 then Effects.Sound("Step",root); lastStep=now end
		end
	end)
	RunService:BindToRenderStep("PolishSlideCamera",Enum.RenderPriority.Camera.Value-1,function(dt)
		local ch=player.Character; local h=ch and ch:FindFirstChildOfClass("Humanoid")
		if cameraHumanoid~=h then
			if cameraHumanoid and cameraHumanoid.Parent then cameraHumanoid.CameraOffset=baseCameraOffset end
			cameraHumanoid=h; baseCameraOffset=h and h.CameraOffset
		end
		local cam=workspace.CurrentCamera
  if cam and cam~=fovCamera then
   if fovCamera then fovCamera.FieldOfView=baseFov end
   fovCamera=cam;baseFov=cam.FieldOfView
  end
  if cam and h then
   local mode=player:GetAttribute("MovementState")
   local extra=PlayerState.IsArmed(player) and h.Health>0 and ((mode=="Sprint" and h.MoveDirection.Magnitude>0.1 and 4) or (mode=="Slide" and 2) or 0) or 0
   cam.FieldOfView+=(baseFov+extra-cam.FieldOfView)*(1-math.exp(-9*dt))
  end
  if h then
			local target=baseCameraOffset+(player:GetAttribute("MovementState")=="Slide" and Vector3.new(0,-1.1,0) or Vector3.zero)
			h.CameraOffset=h.CameraOffset:Lerp(target,1-math.exp(-18*dt))
		end
	end)
end
return Controller
