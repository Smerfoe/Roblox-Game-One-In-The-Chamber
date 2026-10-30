"""Run real Luau animation state logic with explicit lightweight engine mocks.
Usage: python3 weapons/tests/run_animation_checks.py /path/to/luau
Tests lifecycle, not Roblox rendering, physics, hand animation or CFrame fidelity.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
ROOT=Path(__file__).resolve().parents[1]
MOCKS=r'''
local CF = {}; CF.__index = CF
function CF:Lerp(other, a)
 return setmetatable({x=self.x+(other.x-self.x)*a,y=self.y+(other.y-self.y)*a,z=self.z+(other.z-self.z)*a},CF)
end
CF.__mul=function(a,b) return setmetatable({x=a.x+b.x,y=a.y+b.y,z=a.z+b.z},CF) end
local CFrame={}
function CFrame.new(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},CF) end
function CFrame.Angles(...) return CFrame.new() end
CFrame.identity=CFrame.new()
local Enum={EasingStyle={Sine=1},EasingDirection={InOut=1}}
local connection
local RunService={IsClient=function() return true end,RenderStepped={Connect=function(_,fn)
 connection={Connected=true,Disconnect=function(self) self.Connected=false end};return connection
end}}
local TweenService={GetValue=function(_,alpha) return alpha end}
local game={GetService=function(_,name) return name=='RunService' and RunService or TweenService end}
'''
CHECKS=r'''
local function rig(pistol, revolver, overrides)
 local list={};local anchor={Name='Anchor',CFrame=CFrame.identity,IsA=function(_,n) return n=='BasePart' end}
 table.insert(list,anchor)
 for _,name in (overrides or (pistol and {'Presentation','Slide','Hammer','Magazine','Cartridge'} or revolver and {'Presentation','Cylinder','Hammer','Cartridge'} or {'Presentation'})) do
  table.insert(list,{Name=name,C0=CFrame.identity,IsA=function(_,n) return n=='Motor6D' end})
 end
 for _,name in {'SingleCartridge','CartridgeTip'} do
  table.insert(list,{Name=name,Transparency=0,IsA=function(_,n) return n=='BasePart' end})
 end
 return {FindFirstChild=function(_,n) return n=='Anchor' and anchor or nil end,GetDescendants=function() return list end}
end
local camera={CFrame=CFrame.new(1,2,3)}
local function advance(a,n) for _=1,n do a:_step(.01) end end
local a=Animator.new(rig(true),'Pistol',camera)
assert(not a:Play('Unknown'))
assert(a:Play('Inspect'));assert(not a:Play('Inspect'))
advance(a,30);assert(a.active.name=='Inspect')
assert(a:Play('Fire'));assert(a.active.name=='Fire')
advance(a,35);assert(a.active==nil)
a:SetLocomotion('Sprint');assert(not a:Play('Inspect'))
a:SetLocomotion('Idle');assert(a:Play('Reload'))
advance(a,50);assert(a.cartridges[1].Transparency==0)
advance(a,50);assert(a.cartridges[1].Transparency==1)
a:Cancel();assert(a.active==nil and a.cartridges[1].Transparency==1)
assert(a:Play('Inspect'));a:SetLocomotion('Slide');assert(a.active==nil)
a:SetLocomotion('Idle')
for _=1,10 do assert(a:Play('Inspect'));advance(a,280) end
for _,joint in a.joints do
 assert(math.abs(joint.C0.x)<.001 and math.abs(joint.C0.z)<.001,'accumulated positional drift')
end
local oldConnection=a.connection;a:Destroy();a:Destroy()
assert(not oldConnection.Connected and not a:Play('Fire'))
local b=Animator.new(rig(false),'Knife',camera)
assert(not b:Play('Reload'));assert(b:Play('Attack'));advance(b,60);assert(b.active==nil)
assert(b:Play('Inspect'));b:Cancel();assert(b.active==nil)
b:SetCamera({CFrame=CFrame.new(4,5,6)});advance(b,1);assert(b.anchor.CFrame.x>4)
b:Destroy()

local revolver=Animator.new(rig(false,true),'Revolver',camera)
assert(revolver:Play('Reload'));advance(revolver,65)
assert(revolver.cartridges[1].Transparency==0)
assert(revolver.joints.Slide==nil and revolver.joints.Magazine==nil)
advance(revolver,60);assert(revolver.cartridges[1].Transparency==1)
revolver:Cancel();assert(revolver.cartridges[1].Transparency==1)
assert(revolver:Play('Inspect'));advance(revolver,310);assert(revolver.active==nil)
assert(revolver:Play('Fire'));advance(revolver,40);assert(revolver.active==nil)
revolver:Destroy()
for _,kind in {'Machete','ButterKnife'} do
 local blade=Animator.new(rig(false),kind,camera)
 assert(not blade:Play('Reload') and not blade:Play('Fire'))
 assert(blade:Play('Attack'));advance(blade,60);assert(blade.active==nil)
 assert(blade:Play('Inspect'));blade:SetLocomotion('Sprint');assert(blade.active==nil)
 blade:SetLocomotion('Idle');assert(blade:Play('Inspect'));advance(blade,280);assert(blade.active==nil)
 blade:Destroy()
end


local cases = {
 {'Repeater', {'Presentation','Lever','Breech','Hammer','Cartridge'}, true},
 {'OldWest', {'Presentation','Cylinder','LoadingGate','Hammer','Cartridge'}, true},
 {'HeavyPistol', {'Presentation','Slide','Hammer','Magazine','Cartridge'}, true},
 {'Butterfly', {'Presentation','HandleA','HandleB'}, false},
 {'Bowie', {'Presentation'}, false},
}
for _,case in cases do
 local kind,names,firearm=case[1],case[2],case[3]
 local c=Animator.new(rig(false,false,names),kind,camera)
 for _,action in {'Equip','Inspect',firearm and 'Fire' or 'Attack'} do
  assert(c:Play(action),kind..' missing '..action)
  local track=c.active.track
  for joint,keys in track.joints do
   assert(c.joints[joint],kind..' unknown animated joint '..joint)
   assert(keys[1].time==0 and keys[#keys].time==track.duration)
   for i=2,#keys do assert(keys[i].time>keys[i-1].time,'Nonmonotonic keyframes') end
  end
  advance(c,math.ceil(track.duration*100)+20);assert(c.active==nil)
 end
 if firearm then
  assert(c:Play('Reload'));local track=c.active.track
  assert(track.cartridgeWindow[1]<track.cartridgeWindow[2])
  advance(c,math.ceil((track.cartridgeWindow[1]+.05)*100));assert(c.cartridges[1].Transparency==0)
  c:Cancel();assert(c.cartridges[1].Transparency==1)
 else assert(not c:Play('Reload')) end
 assert(c:Play('Inspect'));c:SetLocomotion('Sprint');assert(c.active==nil)
 c:SetLocomotion('Idle');assert(c:Play('Equip'));c:Cancel();c:Destroy()
 local ok=pcall(function() Animator.new(rig(false),kind,camera) end)
 assert(ok==(kind=='Bowie'),'Missing required joint accepted for '..kind)
 print('PASS '..kind..' action/joint/timing and lifecycle checks')
end
print('PASS animation state checks: action availability, inspection gating/interruption, cartridge timing, cancellation, locomotion, repeatability, knife attack, camera swap and idempotent cleanup.')
print('Mocks do not validate real Roblox rotations, motor evaluation, import, rendering, timing feel or hands.')
'''
source=(ROOT/'animations'/'WeaponAnimator.luau').read_text()
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(MOCKS+'\nlocal Animator=(function()\n'+source+'\nend)()\n'+CHECKS);f.flush()
 subprocess.run([sys.argv[1],f.name],check=True)
