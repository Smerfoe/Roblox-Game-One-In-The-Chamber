"""Check actual XML against manifest, human-sized ground paths and spawn occlusion."""
from collections import deque
from pathlib import Path
import hashlib
import json
import math
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]
RADIUS=1.5


def run():
    checks=0
    for file in sorted((ROOT/'models').glob('*.geometry.json')):
        data=json.loads(file.read_text()); name=data['name']; w,d=data['footprint']
        xml=ET.parse(ROOT/'models'/f'{name}.rbxmx')
        nodes=xml.findall(".//Item[@class='Part']")
        parts=data['parts']; assert len(nodes)==len(parts)==data['part_count']
        assert not any('Script' in i.get('class','') for i in xml.findall('.//Item'))
        by_name={}
        for node in nodes:
            props=node.find('Properties'); key=props.find("string[@name='Name']").text
            by_name.setdefault(key,[]).append(props)
        for p in parts:
            assert all(math.isfinite(n) for n in p['position']+p['size'])
            assert all(n>0 for n in p['size'])
            props=by_name[p['name']].pop(0)
            xyz=[float(props.find(f"CoordinateFrame[@name='CFrame']/{k}").text) for k in 'XYZ']
            assert xyz==p['position'],(name,p['name'],'XML differs from geometry manifest')
            size=[float(props.find(f"Vector3[@name='size']/{k}").text) for k in 'XYZ']
            assert size==p['size']
            assert props.find("bool[@name='Anchored']").text=='true'
            assert props.find("bool[@name='CanCollide']").text==str(p['collision']).lower()
            x,y,z=p['position']; sx,sy,sz=p['world_size']
            assert abs(x)+sx/2<=w/2+.001,(name,p['name'],'outside X boundary')
            assert abs(z)+sz/2<=d/2+.001,(name,p['name'],'outside Z boundary')
            checks+=1
        # Check collisions intersecting standing body height (floor excluded).
        obstacles=[p for p in parts if p['collision'] and
                   p['position'][1]+p['world_size'][1]/2>.1 and
                   p['position'][1]-p['world_size'][1]/2<5]
        def blocked(x,z):
            if abs(x)>w/2-1-RADIUS or abs(z)>d/2-1-RADIUS: return True
            for p in obstacles:
                px,_,pz=p['position']; sx,_,sz=p['world_size']
                if p['shape']=='Cylinder':
                    if (x-px)**2+(z-pz)**2<(sx/2+RADIUS)**2: return True
                elif abs(x-px)<sx/2+RADIUS and abs(z-pz)<sz/2+RADIUS:
                    return True
            return False
        def flood(start):
            assert not blocked(*start),(name,'blocked spawn',start)
            seen={start}; q=deque([start])
            while q:
                x,z=q.popleft()
                for n in ((x+1,z),(x-1,z),(x,z+1),(x,z-1)):
                    if n not in seen and not blocked(*n): seen.add(n);q.append(n)
            return seen
        blue=tuple(data['spawns']['Blue']['position'][::2]); red=tuple(data['spawns']['Red']['position'][::2])
        reachable=flood(blue); assert red in reachable,(name,'spawns disconnected')
        gates={'TestingGrounds':[(-25,0),(6,0),(25,0)],
               'ContainerYard':[(-32,0),(0,0),(32,0)],
               'PumpHouse':[(-32,0),(9,0),(32,0)]}[name]
        for gate in gates: assert gate in reachable,(name,'route inaccessible',gate)
        # Eye-level direct spawn shot must hit a colliding sightline shield.
        occluded=False
        for step in range(1,201):
            t=step/201; x=blue[0]*(1-t)+red[0]*t; z=blue[1]*(1-t)+red[1]*t
            for p in obstacles:
                px,py,pz=p['position']; sx,sy,sz=p['world_size']
                if abs(x-px)<sx/2 and abs(z-pz)<sz/2 and py-sy/2<4.5<py+sy/2: occluded=True
        assert occluded,(name,'direct spawn sightline')
        checks+=6
        print(f'PASS {name}: {len(parts)} anchored parts; XML/manifest match; 3-stud-wide player paths to both spawns and three route checkpoints; direct spawn shot blocked; no scripts.')
    # Rebuilding must produce byte-identical deliverables.
    files=sorted((ROOT/'models').glob('*'))
    before={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    subprocess.run([sys.executable,str(ROOT/'tools'/'build_maps.py')],check=True,stdout=subprocess.DEVNULL)
    assert before=={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
    print(f'PASS deterministic rebuild. {checks} part/route assertions completed. Studio visual, jump and combat checks remain unrun.')


if __name__=='__main__': run()
