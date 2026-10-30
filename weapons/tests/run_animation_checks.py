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
local function rig(pistol)
 local list={};local anchor={Name='Anchor',CFrame=CFrame.identity,IsA=function(_,n) return n=='BasePart' end}
 table.insert(list,anchor)
 for _,name in (pistol and {'Presentation','Slide','Hammer','Magazine','Cartridge'} or {'Presentation'}) do
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
print('PASS animation state checks: action availability, inspection gating/interruption, cartridge timing, cancellation, locomotion, repeatability, knife attack, camera swap and idempotent cleanup.')
print('Mocks do not validate real Roblox rotations, motor evaluation, import, rendering, timing feel or hands.')
'''
source=(ROOT/'animations'/'WeaponAnimator.luau').read_text()
with tempfile.NamedTemporaryFile(mode='w',suffix='.luau') as f:
 f.write(MOCKS+'\nlocal Animator=(function()\n'+source+'\nend)()\n'+CHECKS);f.flush()
 subprocess.run([sys.argv[1],f.name],check=True)
