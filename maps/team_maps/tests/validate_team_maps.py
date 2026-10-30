"""Validate real XML geometry against approved floor/obstacle/slot definitions.
No Roblox engine or gameplay is simulated. Requires numpy for raster checks.
"""
from pathlib import Path
from collections import deque
import json
import math
import hashlib
import subprocess
import sys
import xml.etree.ElementTree as E
import numpy as np

ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1]
plans=json.loads((REPO/'maps/concepts/v2/layouts.json').read_text())

def xyz(p,name):return [float(p.find(f"Vector3[@name='{name}']/{k}").text) for k in 'XYZ']
def pos(p):return [float(p.find(f"CoordinateFrame[@name='CFrame']/{k}").text) for k in 'XYZ']
def boolprop(p,name):return p.find(f"bool[@name='{name}']").text=='true'

for plan in plans:
 name=plan['name'].replace(' ','');w,h=plan['size'];path=ROOT/'models'/f'{name}.rbxmx'
 tree=E.parse(path);data=json.loads(path.with_suffix('.geometry.json').read_text())
 items=tree.findall('.//Item');refs=[n.get('referent') for n in items]
 assert len(set(refs))==len(refs),'Duplicate referents'
 assert not any('Script' in n.get('class','') or n.get('class')=='SpawnLocation' for n in items)
 nodes=tree.findall(".//Item[@class='Part']");assert len(nodes)==data['part_count']
 assert data['part_count']<600,'Part budget exceeded'
 byref={n.get('referent'):n for n in nodes}
 primary=tree.find("./Item/Properties/Ref[@name='PrimaryPart']").text
 assert primary in byref and pos(byref[primary].find('Properties'))==[0,0,0]
 X,Z=np.meshgrid(np.arange(w)+.5,np.arange(h)+.5)
 actual_floor=np.zeros((h,w),dtype=int);actual_blocks=np.zeros((h,w),dtype=bool);tall=np.zeros((h,w),dtype=bool)
 manifest_parts=data['parts']
 # Parts are emitted in folder groups, not insertion order; compare unique referent IDs.
 for i,row in enumerate(manifest_parts):
  node=byref[f'{name}_{i:04d}'];p=node.find('Properties')
  assert p.find("string[@name='Name']").text==row['name']
  center=pos(p);size=xyz(p,'size')
  assert center==row['position'] and size==row['size']
  assert all(math.isfinite(n) for n in center+size) and min(size)>0
  assert boolprop(p,'Anchored') and not boolprop(p,'CanTouch')
  collide=boolprop(p,'CanCollide');query=boolprop(p,'CanQuery')
  assert collide==row['collision'] and query==collide
  if row['folder']=='Details':assert not collide
  if plan['studded']:assert p.find("token[@name='TopSurface']").text=='3'
  # Only source-aligned axis boxes collide; verify orientation instead of trusting manifest.
  if not collide:continue
  assert p.find("token[@name='shape']").text=='1'
  cf=p.find("CoordinateFrame[@name='CFrame']")
  for a in range(3):
   for b in range(3):assert abs(float(cf.find(f'R{a}{b}').text)-(1 if a==b else 0))<1e-6
  x,y,z=center;sx,sy,sz=size
  assert abs(x)+sx/2<=w/2+1.01 and abs(z)+sz/2<=h/2+1.01
  mask=(abs(X-(x+w/2))<sx/2+1e-6)&(abs(Z-(z+h/2))<sz/2+1e-6)
  if row['folder']=='Ground':
   assert abs(y+sy/2)<1e-6 and sy==2
   actual_floor+=mask
  elif y-sy/2<5 and y+sy/2>.1:
   actual_blocks|=mask
   if y+sy/2>4.5:tall|=mask
 assert actual_floor.max()==1,'Overlapping foundation parts'
 expected_floor=np.zeros((h,w),dtype=bool)
 rectangles=list(plan['rooms'])
 for width,points in plan['links']:
  for a,b in zip(points,points[1:]):rectangles.append([min(a[0],b[0])-width/2,min(a[1],b[1])-width/2,max(a[0],b[0])+width/2,max(a[1],b[1])+width/2])
 for x1,z1,x2,z2 in rectangles:expected_floor|=(X>=x1)&(X<x2)&(Z>=z1)&(Z<z2)
 assert np.array_equal(actual_floor>0,expected_floor),'Built floor differs from approved plan'
 expected_blocks=np.zeros((h,w),dtype=bool)
 for x1,z1,x2,z2,height in plan['blocks']:expected_blocks|=(X>=x1)&(X<x2)&(Z>=z1)&(Z<z2)
 assert np.array_equal(actual_blocks&expected_floor,expected_blocks&expected_floor),'Collision added or removed from planned routes'
 free=expected_floor&~actual_blocks;padded=np.pad(free,2,constant_values=False);body=np.ones_like(free)
 for dz in range(-2,3):
  for dx in range(-2,3):body&=padded[2+dz:2+dz+h,2+dx:2+dx+w]
 # From first real XML marker, flood all conservative body-clear ground cells.
 slots=[]
 for t,team in enumerate(('Blue','Red')):
  entries=tree.findall(f"./Item/Item/Item/Properties/string[@name='Name']")
  team_slots=[]
  expected_slots=plan['spawn_slots'][t]
  assert len(data['spawns'][team])==int(plan['mode'][0])
  for i,source in enumerate(expected_slots,1):
   candidates=[n for n in nodes if n.find("Properties/string[@name='Name']").text==f'{team}Spawn{i:02d}']
   assert len(candidates)==1
   node=candidates[0];p=node.find('Properties');x,y,z=pos(p)
   assert abs(y-3)<1e-6 and not boolprop(p,'CanCollide')
   assert float(p.find("float[@name='Transparency']").text)==1
   assert np.allclose([x+w/2,z+h/2],[source[0]+.5,source[1]+.5])
   cell=(int(x+w/2),int(z+h/2));assert body[cell[1],cell[0]],'Blocked spawn'
   target=plan['spawns'][1-t];origin=plan['spawns'][t];direction=np.array([target[0]-origin[0],target[1]-origin[1]],float);direction/=np.linalg.norm(direction)
   cf=p.find("CoordinateFrame[@name='CFrame']");look=np.array([-float(cf.find('R02').text),-float(cf.find('R22').text)])
   assert float(look@direction)>.999999,'Wrong spawn facing'
   team_slots.append(cell)
  slots.append(team_slots)
 start=slots[0][0];seen={start};q=deque([start])
 while q:
  x,z=q.popleft()
  for n in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
   if 0<=n[0]<w and 0<=n[1]<h and body[n[1],n[0]] and n not in seen:seen.add(n);q.append(n)
 assert len(seen)==int(body.sum()),'Isolated body-clear ground pocket'
 assert all(p in seen for team in slots for p in team)
 # Real boundary runs must cover every exposed floor unit edge, with solid height.
 segments=data['boundary_segments'];edges=set()
 for seg in segments:
  x1,z1,x2,z2=seg['rect'];direction=seg['direction']
  if direction in ('W','E'):
   c=x2 if direction=='W' else x1
   for z in range(int(z1),int(z2)):edges.add((direction,int(c),z))
  else:
   c=z2 if direction=='S' else z1
   for x in range(int(x1),int(x2)):edges.add((direction,int(c),x))
 for z in range(h):
  for x in range(w):
   if not expected_floor[z,x]:continue
   for direction,dx,dz in [('W',-1,0),('E',1,0),('S',0,-1),('N',0,1)]:
    nx,nz=x+dx,z+dz
    if 0<=nx<w and 0<=nz<h and expected_floor[nz,nx]:continue
    key=(direction,x if direction=='W' else x+1 if direction=='E' else z if direction=='S' else z+1,z if direction in ('W','E') else x)
    assert key in edges,'Open perimeter edge'
 for a in slots[0]:
  for b in slots[1]:
   # Tall solids or enclosing floor boundaries occlude, low cover does not.
   ray=[(int(round(a[0]*(1-t)+b[0]*t)),int(round(a[1]*(1-t)+b[1]*t))) for t in np.linspace(0,1,1500)]
   assert any(tall[z,x] or not expected_floor[z,x] for x,z in ray),'Direct initial spawn sightline'
 print(f'PASS {name}: {len(nodes)} parts; exact plan floor/collision; enclosed perimeter; {plan["mode"]} real spawn markers/facing; body-clear connectivity; initial eye-level sightline occlusion.')

# Bundle must contain the exact six built model trees and zero scripts.
pack=E.parse(ROOT/'TeamMapTemplates.rbxmx');models=pack.findall("./Item/Item[@class='Model']")
assert len(models)==6
for m in models:
 name=m.find("Properties/string[@name='Name']").text
 individual=E.parse(ROOT/'models'/f'{name}.rbxmx').getroot().find('Item')
 # Formatting-only trailing whitespace differs by nesting. Compare element structure recursively.
 def signature(n):return (n.tag,tuple(sorted(n.attrib.items())),(n.text or '').strip(),tuple(signature(c) for c in n))
 assert signature(m)==signature(individual)
assert not any('Script' in n.get('class','') for n in pack.findall('.//Item'))
files=sorted((ROOT/'models').glob('*'))+[ROOT/'TeamMapTemplates.rbxmx']
before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
subprocess.run([sys.executable,str(ROOT/'tools/build_team_maps.py')],check=True,stdout=subprocess.DEVNULL)
assert before=={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
print('PASS exact six-model bundle, zero scripts, byte-identical rebuild. Studio checks remain unrun.')
