"""Structural checks only; not Roblox Studio visual, movement or perf tests."""
from pathlib import Path
import xml.etree.ElementTree as E
import json,math,hashlib
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[1]
report=[]
for path in sorted((ROOT/'models').glob('*.rbxmx')):
 xml=E.parse(path);nodes=xml.findall('.//Item');refs={n.get('referent'):n for n in nodes}
 assert len(refs)==len(nodes),f'{path.stem}: duplicate referents'
 assert not any(n.get('class') in ('Script','LocalScript','ModuleScript','SpawnLocation') for n in nodes)
 meta=json.loads(path.with_suffix('.manifest.json').read_text())
 if meta['source']:
  source=REPO/meta['source'];assert hashlib.sha256(source.read_bytes()).hexdigest()==meta['source_sha256']
  for n in E.parse(source).findall('.//Item'):
   assert n.get('referent') in refs
   # Whitespace is not a Roblox property; normalize it before comparison.
   def values(p):
    return (p.tag,tuple(sorted(p.attrib.items())),(p.text or '').strip(),tuple(values(c) for c in p))
   assert values(n.find('Properties'))==values(refs[n.get('referent')].find('Properties')), (path.stem,n.get('referent'))
 for n in nodes:
  for r in n.findall('Properties/Ref'):
   assert r.text in refs or r.text in ('null','nil'),(path.stem,r.text)
  if n.get('class')!='Part':continue
  p=n.find('Properties');cf=p.find("CoordinateFrame[@name='CFrame']");s=p.find("Vector3[@name='size']")
  assert p.find("bool[@name='Anchored']").text=='true'
  assert all(math.isfinite(float(c.text)) for c in cf)
  assert all(float(c.text)>0 for c in s)
  R=[[float(cf.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)]
  for i in range(3):
   for j in range(3):assert abs(sum(R[k][i]*R[k][j] for k in range(3))-(i==j))<1e-5
  det=R[0][0]*(R[1][1]*R[2][2]-R[1][2]*R[2][1])-R[0][1]*(R[1][0]*R[2][2]-R[1][2]*R[2][0])+R[0][2]*(R[1][0]*R[2][1]-R[1][1]*R[2][0]);assert abs(det-1)<1e-5
  if n.get('referent').startswith('ENV_'):
   collide=p.find("bool[@name='CanCollide']").text;query=p.find("bool[@name='CanQuery']").text
   assert collide==query
   if path.stem!='ContainerYard':assert collide=='false'
 report.append(f'{path.stem}: PASS — {len(nodes)} instances; {meta["added_parts"]} new parts; original instance properties preserved' if meta['source'] else f'{path.stem}: PASS — {len(nodes)} instances; new collision layout (Studio tests required)')
# Rebuild determinism is checked by caller, independently of model traversal.
print('\n'.join(report));(ROOT/'VALIDATION.txt').write_text('\n'.join(report)+'\n\nNo Studio tests were run by this validator.\n')
# New Container Yard: conservative 3-stud-wide ground routes and initial spawn LOS.
from collections import deque
xml=E.parse(ROOT/'models/ContainerYard.rbxmx');boxes=[]
for n in xml.findall(".//Item[@class='Part']"):
 p=n.find('Properties')
 if p.find("bool[@name='CanCollide']").text!='true':continue
 cf=p.find("CoordinateFrame[@name='CFrame']");s=p.find("Vector3[@name='size']")
 pos=[float(cf.find(a).text) for a in 'XYZ'];size=[float(s.find(a).text) for a in 'XYZ']
 ext=[sum(abs(float(cf.find(f'R{i}{j}').text))*size[j]/2 for j in range(3)) for i in range(3)]
 boxes.append(([pos[i]-ext[i] for i in range(3)],[pos[i]+ext[i] for i in range(3)]))
walk=set()
for x in range(-65,66):
 for z in range(-65,66):
  if not any(lo[1]<5.5 and hi[1]>.3 and lo[0]-1.5<x<hi[0]+1.5 and lo[2]-1.5<z<hi[2]+1.5 for lo,hi in boxes):walk.add((x,z))
start=(-58,-58);goal=(58,58);assert start in walk and goal in walk
seen={start};q=deque([start])
while q:
 x,z=q.popleft()
 for t in ((x-1,z),(x+1,z),(x,z-1),(x,z+1)):
  if t in walk and t not in seen:seen.add(t);q.append(t)
assert goal in seen,'No route between spawn bays'
# Only reachable interior routes are required; sealed container shells intentionally enclose voids.
def intersect(a,b,lo,hi):
 t0,t1=0,1
 for i in range(3):
  d=b[i]-a[i]
  if abs(d)<1e-9:
   if a[i]<lo[i] or a[i]>hi[i]:return False
  else:
   aa,bb=sorted(((lo[i]-a[i])/d,(hi[i]-a[i])/d));t0=max(t0,aa);t1=min(t1,bb)
   if t0>t1:return False
 return True
rays=0
for y in (4.5,10.8):
 for dx in (-.75,0,.75):
  for dz in (-.75,0,.75):
   a=(-58+dx,y,-58+dz);b=(58-dx,y,58-dz)
   assert any(intersect(a,b,lo,hi) for lo,hi in boxes),'Open initial spawn ray'
   rays+=1
text=f'ContainerYard: PASS — 3-stud-wide ground connection between spawns; {rays}/{rays} sampled initial rays blocked.\n'
print(text,end='')
with (ROOT/'VALIDATION.txt').open('a') as f:f.write(text)
