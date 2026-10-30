"""Deterministic, dependency-free Roblox XML model builder. Run from any directory."""
from pathlib import Path
import json
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PALETTE = {
    'concrete': (117, 116, 109), 'edge': (81, 83, 80), 'steel': (64, 72, 72),
    'blue': (56, 78, 91), 'red': (116, 61, 49), 'green': (66, 81, 68),
    'yellow': (172, 142, 67), 'brick': (111, 82, 67), 'lamp': (255, 218, 159),
    'dark': (39, 43, 43), 'ground': (88, 87, 81), 'white': (178, 174, 158),
}


def prop(parent, kind, name, value):
    node = ET.SubElement(parent, kind, name=name)
    node.text = str(value)
    return node


class Arena:
    def __init__(self, name, width, depth, theme):
        self.name, self.width, self.depth = name, width, depth
        self.xml = ET.Element('roblox', version='4')
        self.model = ET.SubElement(self.xml, 'Item', {'class': 'Model', 'referent': name})
        props = ET.SubElement(self.model, 'Properties')
        prop(props, 'string', 'Name', name)
        self.folders = {}
        self.parts = []
        self.lights = 0
        self.meta = dict(name=name, footprint=[width, depth], theme=theme, spawns={},
                         coordinates='X/Z horizontal; floor surface Y=0; pivot at world origin',
                         status='Generated; automated geometry checks only. Studio playtest required.')

    def folder(self, name):
        if name not in self.folders:
            node = ET.SubElement(self.model, 'Item', {'class': 'Folder', 'referent': self.name+name})
            prop(ET.SubElement(node, 'Properties'), 'string', 'Name', name)
            self.folders[name] = node
        return self.folders[name]

    def part(self, name, xyz, size, color='concrete', material='Concrete', folder='Architecture',
             collision=True, yaw=0, shape='Block', transparency=0):
        ident = f'{self.name}_{len(self.parts):04d}'
        node = ET.SubElement(self.folder(folder), 'Item', {'class': 'Part', 'referent': ident})
        p = ET.SubElement(node, 'Properties')
        prop(p, 'string', 'Name', name)
        for key, val in [('Anchored', True), ('CanCollide', collision), ('CanTouch', False),
                         ('CanQuery', collision), ('CastShadow', transparency == 0)]:
            prop(p, 'bool', key, str(val).lower())
        for key, val in [('Transparency', transparency), ('Reflectance', 0)]:
            prop(p, 'float', key, val)
        v = ET.SubElement(p, 'Vector3', name='size')
        for k, n in zip('XYZ', size): prop(v, k, None, n).attrib.clear()
        c = ET.SubElement(p, 'Color3', name='Color')
        for k, n in zip('RGB', PALETTE.get(color, color)):
            e = ET.SubElement(c, k); e.text = str(n/255)
        cf = ET.SubElement(p, 'CoordinateFrame', name='CFrame')
        for k, n in zip('XYZ', xyz): ET.SubElement(cf, k).text = str(n)
        # Cylinders have a local X axis; rotate it upright for tanks, pipes, drums.
        if shape == 'Cylinder':
            matrix = [0,-1,0, 1,0,0, 0,0,1]
        else:
            a = math.radians(yaw); c, s = math.cos(a), math.sin(a)
            matrix = [c,0,s, 0,1,0, -s,0,c]
        for k, n in zip(['R00','R01','R02','R10','R11','R12','R20','R21','R22'], matrix):
            ET.SubElement(cf,k).text = str(round(n,8))
        materials = dict(Plastic=256, SmoothPlastic=272, Concrete=816, Metal=1088,
                         CorrodedMetal=1040, Brick=848, Asphalt=1376, Neon=288)
        prop(p, 'token', 'Material', materials[material])
        prop(p, 'token', 'shape', 2 if shape == 'Cylinder' else 1)
        prop(p, 'token', 'TopSurface', 0); prop(p, 'token', 'BottomSurface', 0)
        world_size = [size[1],size[0],size[2]] if shape == 'Cylinder' else (
            [size[2],size[1],size[0]] if yaw % 180 == 90 else list(size))
        self.parts.append(dict(name=name, position=list(xyz), size=list(size),
                               world_size=world_size, collision=collision, folder=folder,
                               shape=shape, yaw=yaw))
        return node

    def wall(self, name, x, z, sx, sz, height=12, color='concrete', material='Concrete'):
        return self.part(name, (x,height/2,z), (sx,height,sz), color, material)

    def detail(self, name, xyz, size, color='steel', material='Metal'):
        return self.part(name, xyz, size, color, material, 'Details', False)

    def light(self, x, z, inward):
        # Fixtures mount on the inside of perimeter walls; no global Lighting edits.
        self.detail('BulkheadBracket', (x,9,z), (1.5,.25,1.1))
        node=self.detail('WarmBulkhead', (x,8.65,z+inward*.3), (1.1,.45,.45), 'lamp', 'Neon')
        light=ET.SubElement(node,'Item',{'class':'PointLight','referent':f'{self.name}_light{self.lights}'})
        self.lights+=1; p=ET.SubElement(light,'Properties')
        prop(p,'string','Name','LocalWarmLight'); prop(p,'float','Brightness',.65)
        prop(p,'float','Range',14); prop(p,'bool','Shadows','true')
        col=ET.SubElement(p,'Color3',name='Color')
        for k,n in zip('RGB',(1,.83,.61)): ET.SubElement(col,k).text=str(n)

    def base(self, material='Concrete', wall_material='Concrete'):
        w,d=self.width,self.depth
        self.part('Foundation', (0,-1,0), (w,2,d), 'ground',material,'Ground')
        self.wall('NorthBoundary',0,-d/2+.5,w,1,14,material=wall_material)
        self.wall('SouthBoundary',0,d/2-.5,w,1,14,material=wall_material)
        self.wall('WestBoundary',-w/2+.5,0,1,d-2,14,material=wall_material)
        self.wall('EastBoundary',w/2-.5,0,1,d-2,14,material=wall_material)
        for x in (-w/2+1,w/2-1):
            for z in range(-int(d/2)+8,int(d/2),12):
                self.detail('PerimeterPilaster',(x,7,z),(1,14,1.2),'edge','Concrete')
        for z,inward in ((-d/2+1,1),(d/2-1,-1)):
            for x in (-w/2+10,0,w/2-10): self.light(x,z,inward)
        # Thin floor inlays share a plane offset to avoid z-fighting.
        for x in (-w/2+3,w/2-3):
            self.detail('PerimeterSafetyLine',(x,.018,0),(.12,.035,d-6),'yellow','SmoothPlastic')

    def spawn(self, team, z):
        # Markers deliberately are Parts, not active SpawnLocations.
        self.part(team+'Spawn',(0,3,z),(2,2,2),team.lower(),'SmoothPlastic',
                  'Spawns',False,transparency=1)
        self.meta['spawns'][team] = dict(position=[0,3,z], facing=[0,3,0],
                                        note='Marker only; adapter must face toward arena center.')
        self.detail(team+'SpawnFloor',(0,.025,z),(8,.05,5),team.lower(),'SmoothPlastic')
        sign=-1 if z<0 else 1
        shield_z=z-sign*6
        self.wall(team+'SightlineShield',0,shield_z,10,1,9,'edge')
        self.detail(team+'ShieldStripe',(0,6,shield_z-sign*.52),(8,.22,.04),team.lower(),'SmoothPlastic')
        # Width 10 shield forces players to choose an exit instead of shooting from spawn.

    def cover(self, name, x,z, sx=7,sz=2):
        self.part(name,(x,1.6,z),(sx,3.2,sz),'concrete','Concrete','Cover')
        self.detail(name+'Top',(x,3.23,z),(sx+.08,.06,sz+.08),'edge','Concrete')

    def save(self):
        self.meta['part_count']=len(self.parts); self.meta['parts']=self.parts
        ET.indent(self.xml, space='  ')
        (ROOT/'models'/f'{self.name}.rbxmx').write_bytes(ET.tostring(self.xml,encoding='utf-8',xml_declaration=True))
        (ROOT/'models'/f'{self.name}.geometry.json').write_text(json.dumps(self.meta,indent=2)+'\n')


def testing():
    a=Arena('TestingGrounds',76,68,'Weathered concrete tactical training compound')
    a.base()
    for team,z in [('Blue',-27),('Red',27)]: a.spawn(team,z)
    # Roofless 26 x 24 training house; opposing doors staggered by 12 studs.
    a.wall('TrainingWestWall',-13,0,1,24,11)
    a.wall('TrainingEastWall',13,0,1,24,11)
    for sign in (-1,1):
        z=sign*12; door_x=sign*6
        left=(-13,door_x-3); right=(door_x+3,13)
        for label,(lo,hi) in [('Left',left),('Right',right)]:
            a.wall(f'Entry{sign}{label}',(lo+hi)/2,z,hi-lo,1,11)
        a.part('DoorLintel',(door_x,9.5,z),(6,3,1),'edge')
        # Flush floor threshold, with no raised lip to catch players.
        a.detail('DoorThreshold',(door_x,.025,z),(6,.05,1),'steel')
    # A single internal baffle breaks the door-to-door diagonal; paths around both ends.
    a.wall('InteriorSightlineBaffle',0,0,8,1,9,'edge')
    for x,z in [(-25,-9),(25,9),(-23,13),(23,-13)]:
        a.cover('FlankConcreteBarrier',x,z,7,2)
    for z in (-12,12):
        a.detail('TrainingWallCap',(0,11.08,z),(27,.16,1.2),'edge','Concrete')
    for x in (-13,13):
        a.detail('TrainingWallCap',(x,11.08,0),(1.2,.16,24),'edge','Concrete')
    # Deterministic cast-concrete joint pattern. Nothing scattered or randomized.
    for x in (-13.52,13.52):
        for z in (-8,0,8):
            a.detail('FormworkSeam',(x,5.5,z),(.025,10,.055),'edge','SmoothPlastic')
    for z in (-17,17):
        for x in (-8,-4,0,4,8):
            a.detail('CrossingDash',(x,.025,z),(1.6,.05,.15),'yellow','SmoothPlastic')
    a.meta['design_notes']=['No accessible roofs or stairs.','6-stud doorways; 11-stud central walls.',
                            'Staggered entrances and interior baffle break central sightline.']
    a.save()


def container(a,name,x,z,color,tunnel=False):
    width,length,height=14,16,12
    # Walls are individual aligned shells; tunnel interiors remain walkable.
    a.wall(name+'WestShell',x-width/2+.25,z,.5,length,height,color,'Metal')
    a.wall(name+'EastShell',x+width/2-.25,z,.5,length,height,color,'Metal')
    a.part(name+'Roof',(x,height-.2,z),(width,.4,length),color,'Metal')
    if not tunnel:
        for sign in (-1,1):
            a.wall(name+'ClosedEnd',x,z+sign*(length/2-.25),width-1,.5,height,color,'Metal')
            for dx in (-2,2):
                a.detail(name+'LockingBar',(x+dx,5.8,z+sign*(length/2+.08)),(.12,10,.12),'steel')
    else:
        for sign in (-1,1):
            a.part(name+'OpenEndHeader',(x,11,z+sign*7.75),(13,2,.5),color,'Metal')
            # No swinging doors intruding into the already compact routes.
            a.detail(name+'Threshold',(x,.035,z+sign*7.75),(13,.07,.5),'steel')
    for side in (-1,1):
        for dz in range(-7,8,2):
            a.detail(name+'Corrugation',(x+side*7.03,5.9,z+dz),(.12,11.4,.16),color)
        for y in (.2,11.8):
            a.detail(name+'SideRail',(x+side*7.04,y,z),(.16,.25,16), 'steel')
    a.detail(name+'RoofSpine',(x,12.03,z),(width-.8,.06,.12),'steel')


def yard():
    a=Arena('ContainerYard',76,76,'Dense overcast dockside container arena')
    a.base('Asphalt')
    for team,z in [('Blue',-31),('Red',31)]: a.spawn(team,z)
    # 180-degree symmetric collision layout: 7-stud lanes between banks,
    # 8-stud central crossing, two opposing through-containers.
    for x,z,color,tunnel in [(-21,-12,'blue',True),(0,-12,'red',False),(21,-12,'green',False),
                             (-21,12,'green',False),(0,12,'blue',False),(21,12,'red',True)]:
        container(a,f'Container_{x}_{z}',x,z,color,tunnel)
    # Upper containers sit directly on ground containers; all tops are >=12 studs.
    for x,z,color in [(-21,-12,'green'),(21,12,'blue')]:
        # Same detailed shell pattern translated upward as one controlled operation.
        first=len(a.parts); container(a,f'UpperContainer_{x}_{z}',x,z,color,False)
        for part in a.parts[first:]: part['position'][1]+=12
        # Update XML coordinates to match the manifest.
        for node in list(a.folders['Architecture'])+list(a.folders['Details']):
            p=node.find('Properties')
            if p is None: continue
            n=p.find("string[@name='Name']")
            if n is not None and n.text.startswith(f'UpperContainer_{x}_{z}'):
                cy=p.find("CoordinateFrame[@name='CFrame']/Y"); cy.text=str(float(cy.text)+12)
    # Sparse low cargo cover only at perimeter, away from the seven-stud lanes.
    for x,z in [(-32,9),(32,-9)]:
        a.part('SecuredCargoCrate',(x,1.75,z),(3,3.5,5),'edge','Metal','Cover')
        for y in (.4,3.1): a.detail('CargoBand',(x,y,z),(3.08,.15,5.08),'steel')
    for z in (-23,23):
        for x in (-21,0,21):
            a.detail('LoadingBayMark',(x,.025,z),(10,.05,.14),'yellow','SmoothPlastic')
    a.meta['design_notes']=['Footprint expanded to 76 x 76 for character clearance.',
        'Six ground containers plus two sealed upper containers; ground-level play only.',
        '7-stud inter-container lanes and 8-stud central cross lane.',
        'Two open-through containers; no door leaf blocks a lane.',
        'Shipment-inspired atmosphere; original measured layout.']
    a.save()


def tank(a,name,x,z):
    # Cylinder length is local X; exported transform rotates it onto world Y.
    for suffix,y,h,d,col,mat in [('Plinth',.5,1,16,'concrete','Concrete'),
        ('Body',7,12,14,'white','Metal'),('BaseRing',1.2,.4,14.4,'steel','Metal'),
        ('UpperRing',12.8,.4,14.4,'steel','Metal'),('Lid',13.15,.3,14.1,'edge','Metal')]:
        a.part(name+suffix,(x,y,z),(h,d,d),col,mat,shape='Cylinder')
    for angle in range(0,360,45):
        r=math.radians(angle)
        a.detail(name+'VerticalSeam',(x+7.02*math.cos(r),7,z+7.02*math.sin(r)),(.1,11.4,.1),'edge')
    for y in (4,8):
        a.part(name+'Band',(x,y,z),(.12,14.1,14.1),'steel','Metal','Details',False,shape='Cylinder')


def pump():
    a=Arena('PumpHouse',76,68,'Decommissioned brick and steel water utility courtyard')
    a.base(wall_material='Brick')
    for team,z in [('Blue',-27),('Red',27)]: a.spawn(team,z)
    for x,z in [(-20,-4),(20,4)]: tank(a,'WestTank' if x<0 else 'EastTank',x,z)
    # Solid central equipment housing keeps collision simple and eliminates tiny gaps.
    a.part('PumpHousing',(0,6,0),(10,12,12),'green','Metal')
    a.part('PumpHousingCap',(0,12.2,0),(10.4,.4,12.4),'steel','Metal')
    for x in (-5.05,5.05):
        for z in (-4,-2,0,2,4):
            a.detail('VentSlat',(x,4,z),(.12,2.5,.18),'dark')
    for x,z in [(-12,17),(12,-17)]: a.cover('UtilityBarrier',x,z,7,2)
    # Wall-mounted pipes are above jump height and never form ladders or roof access.
    for x in (-35,35):
        a.part('HighUtilityMain',(x,10,0),(1.5,1.5,54),'green','Metal','Details',False)
        for z in (-22,-11,0,11,22):
            a.detail('PipeMount',(x,10,z),(2.6,2.4,.3),'steel')
    # Flush grates, no water hazards or foot-catching drainage trenches.
    for x in (-9,9):
        a.detail('FlushDrainBed',(x,.018,0),(.8,.035,30),'dark','Metal')
        for z in range(-14,15,2):
            a.detail('DrainGrate',(x,.045,z),(.8,.035,.12),'steel')
    a.meta['design_notes']=['Two tank landmarks with asymmetric appearance and rotationally symmetric collision.',
        'No climbable ladders, elevated routes, or water hazards.',
        'Tank-to-housing lanes have at least 7 studs of clear width.',
        'Local warm light fixtures only; existing global Lighting is untouched.']
    a.save()


if __name__ == '__main__':
    (ROOT/'models').mkdir(exist_ok=True)
    testing(); yard(); pump()
    for path in sorted((ROOT/'models').glob('*.rbxmx')):
        print(f'Built {path.name}: {path.stat().st_size:,} bytes')
