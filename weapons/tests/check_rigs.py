"""Validate export joints, rigid assembly membership and deterministic generation."""
from pathlib import Path
import hashlib
import math
import subprocess
import sys
import xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[1]
for file in sorted((ROOT/'models').glob('*.rbxmx')):
 tree=E.parse(file);nodes=tree.findall('.//Item');refs={n.attrib['referent']:n for n in nodes}
 assert len(refs)==len(nodes),'Duplicate referents'
 assert not any('Script' in n.attrib['class'] for n in nodes)
 parts={r:n for r,n in refs.items() if n.attrib['class'] in ('Part','WedgePart')}
 joints=[];welds=[];anchored=[]
 for r,n in parts.items():
  p=n.find('Properties');name=p.find("string[@name='Name']").text
  if p.find("bool[@name='Anchored']").text=='true':anchored.append(r)
  for key in ('CanCollide','CanTouch','CanQuery'):
   assert p.find(f"bool[@name='{key}']").text=='false',(name,key)
  size=[float(p.find(f"Vector3[@name='size']/{axis}").text) for axis in 'XYZ']
  assert all(math.isfinite(x) and x>0 for x in size)
  for axis in ['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22']:
   assert math.isfinite(float(p.find(f"CoordinateFrame[@name='CFrame']/{axis}").text))
  frame=p.find("CoordinateFrame[@name='CFrame']")
  rotation=[[float(frame.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)]
  for i in range(3):
   for j in range(3):
    assert abs(sum(rotation[k][i]*rotation[k][j] for k in range(3))-(1 if i==j else 0))<1e-6,'Invalid rotation'
 assert len(anchored)==1
 graph={r:[] for r in parts};incoming={r:0 for r in parts}
 for n in nodes:
  if n.attrib['class'] not in ('Motor6D','WeldConstraint'):continue
  p=n.find('Properties');a=p.find("Ref[@name='Part0']").text;b=p.find("Ref[@name='Part1']").text
  assert a in parts and b in parts and a!=b
  graph[a].append(b);incoming[b]+=1
  if n.attrib['class']=='Motor6D':joints.append(p.find("string[@name='Name']").text)
 assert len(set(joints))==len(joints)
 expected=({'Presentation','Slide','Hammer','Magazine','Cartridge'} if file.stem.startswith('Service') else {'Presentation','Cylinder','Hammer','Cartridge'} if file.stem.startswith('Python') else {'Presentation'})
 assert set(joints)==expected,(file,set(joints))
 assert all(incoming[r]==(0 if r in anchored else 1) for r in parts),'Unattached or overconstrained part'
 seen=set();stack=anchored.copy()
 while stack:
  r=stack.pop();assert r not in seen,'Cycle';seen.add(r);stack.extend(graph[r])
 assert len(seen)==len(parts),'Disconnected geometry'
 # Every rigid part begins at the exact same position as its motor C0 rest contract.
 for n in nodes:
  if n.attrib['class']!='Motor6D':continue
  p=n.find('Properties');target=refs[p.find("Ref[@name='Part1']").text].find('Properties')
  for axis in 'XYZ':
   assert float(p.find(f"CoordinateFrame[@name='C0']/{axis}").text)==float(target.find(f"CoordinateFrame[@name='CFrame']/{axis}").text)
 print(f'PASS {file.name}: {len(parts)} noncolliding parts; connected acyclic single-anchor rig; correct unique motor names; no scripts')
files=sorted((ROOT/'models').glob('*.rbxmx'));before=[hashlib.sha256(p.read_bytes()).hexdigest() for p in files]
subprocess.run([sys.executable,str(ROOT/'tools'/'build_weapons.py')],check=True,stdout=subprocess.DEVNULL)
assert before==[hashlib.sha256(p.read_bytes()).hexdigest() for p in files]
print('PASS byte-identical rebuild. Roblox engine import/appearance/animation still require Studio testing.')
