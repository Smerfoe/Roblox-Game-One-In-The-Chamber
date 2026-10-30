"""Build six native Roblox models from the reviewed v2 route footprints.
No random layout, dependencies, imported assets or changes to game scripts.
"""
from pathlib import Path
import importlib.util
import sys
sys.dont_write_bytecode = True
import json
import math
from copy import deepcopy
import xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
PLAN=REPO/'maps/concepts/v2/layouts.json'
# Reuse XML writer only; original 1v1 files are never regenerated here.
spec=importlib.util.spec_from_file_location('arena_xml',REPO/'maps/tools/build_maps.py')
base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)

THEMES={
 'Freight Terminal':dict(floor=(112,111,102),wall=(133,123,108),accent=(74,87,88),material='Asphalt',wallmaterial='Brick'),
 'Foundry':dict(floor=(100,98,91),wall=(113,90,76),accent=(85,91,89),material='Concrete',wallmaterial='Brick'),
 'Canal Works':dict(floor=(145,146,135),wall=(151,151,137),accent=(82,106,95),material='Concrete',wallmaterial='Concrete'),
 'Metro Exchange':dict(floor=(183,183,166),wall=(167,166,145),accent=(66,81,82),material='Concrete',wallmaterial='Concrete'),
 'Skyline':dict(floor=(82,87,90),wall=(124,129,128),accent=(89,101,107),material='Concrete',wallmaterial='Concrete'),
 'Crosscut':dict(floor=(157,166,149),wall=(168,175,170),accent=(111,123,129),material='Plastic',wallmaterial='Plastic'),
}


def floor_mask(plan):
 w,h=plan['size'];mask=[[False]*w for _ in range(h)]
 rects=list(plan['rooms'])
 for width,points in plan['links']:
  for a,b in zip(points,points[1:]):
   assert a[0]==b[0] or a[1]==b[1]
   rects.append([min(a[0],b[0])-width/2,min(a[1],b[1])-width/2,max(a[0],b[0])+width/2,max(a[1],b[1])+width/2])
 for x1,z1,x2,z2 in rects:
  for z in range(h):
   for x in range(w):
    if x1<=x+.5<x2 and z1<=z+.5<z2:mask[z][x]=True
 return mask


def greedy_rects(mask):
 """Exact, nonoverlapping integer rectangles; stable row-major order."""
 work=[row.copy() for row in mask];h=len(work);w=len(work[0]);out=[]
 for z in range(h):
  for x in range(w):
   if not work[z][x]:continue
   x2=x+1
   while x2<w and work[z][x2]:x2+=1
   z2=z+1
   while z2<h and all(work[z2][j] for j in range(x,x2)):z2+=1
   for k in range(z,z2):
    for j in range(x,x2):work[k][j]=False
   out.append((x,z,x2,z2))
 return out


def boundary_runs(mask):
 """Exterior half-stud wall centers, so no reviewed passage is narrowed."""
 h=len(mask);w=len(mask[0]);edges={}
 for z in range(h):
  for x in range(w):
   if not mask[z][x]:continue
   for direction,dx,dz in [('W',-1,0),('E',1,0),('S',0,-1),('N',0,1)]:
    nx,nz=x+dx,z+dz
    if 0<=nx<w and 0<=nz<h and mask[nz][nx]:continue
    coord=x if direction=='W' else x+1 if direction=='E' else z if direction=='S' else z+1
    edges.setdefault((direction,coord),[]).append(z if direction in ('W','E') else x)
 out=[]
 for (direction,coord),values in sorted(edges.items()):
  values=sorted(values);start=last=values[0]
  for n in values[1:]+[None]:
   if n is not None and n==last+1:last=n;continue
   out.append((direction,coord,start,last+1))
   if n is not None:start=last=n
 return out


class TeamArena(base.Arena):
 def __init__(self,plan):
  self.plan=plan;self.theme=THEMES[plan['name']];w,d=plan['size']
  super().__init__(plan['name'].replace(' ',''),w,d,plan['name'])
  self.meta.update(primary_mode=plan['mode'],team_size=int(plan['mode'][0]),
   plan_source='maps/concepts/v2/layouts.json',version='team-build-v1',
   source_footprint=plan['size'],coordinates='Original plan X/Z minus half footprint; Y=0 floor surface. Spawn slot integer cells exported at +0.5 cell center.',
   boundary_policy='Opaque 14-stud boundary walls are placed entirely OUTSIDE the plan floor, including inner voids.',
   spawns={},source_blocks=plan['blocks'],floor_rectangles=[],boundary_segments=[])
  self.spawn_records=[]
  self.node_parts=[]

 def part(self,*args,**kwargs):
  node=super().part(*args,**kwargs);self.node_parts.append(node)
  if self.plan['studded']:
   p=node.find('Properties');p.find("token[@name='TopSurface']").text='3'
  return node

 def box(self,name,rect,height=12,color=None,material=None,folder='Architecture',collision=True,base_y=0):
  x1,z1,x2,z2=rect
  return self.part(name,((x1+x2)/2-self.width/2,base_y+height/2,(z1+z2)/2-self.depth/2),
   (x2-x1,height,z2-z1),self.theme['wall'] if color is None else color,
   self.theme['wallmaterial'] if material is None else material,folder,collision)

 def trim(self,name,x,y,z,sx,sy,sz,color='steel',material='Metal',yaw=0):
  return self.part(name,(x-self.width/2,y,z-self.depth/2),(sx,sy,sz),color,material,'Details',False,yaw=yaw)

 def sign(self,text,x,y,z,width=5,yaw=0,color='white'):
  node=self.trim('Sign_'+text.replace(' ','_'),x,y,z,width,1.2,.07,'dark',yaw=yaw)
  for face in (5,2):
   sg=E.SubElement(node,'Item',{'class':'SurfaceGui','referent':f'{self.name}_sign{len(self.parts)}_{face}'})
   p=E.SubElement(sg,'Properties');base.prop(p,'string','Name','ArchitecturalSign')
   base.prop(p,'token','Face',face);base.prop(p,'bool','AlwaysOnTop','false')
   v=E.SubElement(p,'Vector2',name='CanvasSize');E.SubElement(v,'X').text='600';E.SubElement(v,'Y').text='128'
   label=E.SubElement(sg,'Item',{'class':'TextLabel','referent':f'{self.name}_text{len(self.parts)}_{face}'})
   p=E.SubElement(label,'Properties');base.prop(p,'string','Name','Label');base.prop(p,'string','Text',text)
   base.prop(p,'float','BackgroundTransparency',1);base.prop(p,'bool','TextScaled','true')
   base.prop(p,'bool','TextWrapped','true');base.prop(p,'token','Font',4)
   s=E.SubElement(p,'UDim2',name='Size')
   for k,n in [('XS',1),('XO',0),('YS',1),('YO',0)]:E.SubElement(s,k).text=str(n)
   c=E.SubElement(p,'Color3',name='TextColor3')
   for k,n in zip('RGB',base.PALETTE.get(color,(230,229,215))):E.SubElement(c,k).text=str(n/255)

 def bulkhead(self,x,z,dx,dz):
  # Bracket is mounted directly on wall, light is not floating in the room.
  self.trim('BulkheadMount',x,9.4,z,1.25,.65,.18,'steel',yaw=90 if dx else 0)
  node=self.trim('WarmDiffuser',x+dx*.12,9.4,z+dz*.12,.85,.30,.12,'lamp','Neon',yaw=90 if dx else 0)
  light=E.SubElement(node,'Item',{'class':'PointLight','referent':f'{self.name}_lamp_{len(self.parts)}'})
  p=E.SubElement(light,'Properties');base.prop(p,'string','Name','WarmLocalLight')
  base.prop(p,'float','Brightness',.6);base.prop(p,'float','Range',15);base.prop(p,'bool','Shadows','true')
  c=E.SubElement(p,'Color3',name='Color')
  for k,n in zip('RGB',(1,.87,.69)):E.SubElement(c,k).text=str(n)

 def build_floor(self,mask):
  for rect in greedy_rects(mask):
   self.box('FoundationSlab',rect,2,self.theme['floor'],self.theme['material'],'Ground',base_y=-2)
   self.meta['floor_rectangles'].append(rect)

 def build_boundary(self,mask):
  runs=boundary_runs(mask);lamp_candidates=[]
  for i,(direction,c,start,end) in enumerate(runs):
   vertical=direction in ('W','E');out=-1 if direction in ('W','S') else 1
   length=end-start
   rect=[c-1 if out<0 else c,start,c if out<0 else c+1,end] if vertical else [start,c-1 if out<0 else c,end,c if out<0 else c+1]
   self.box('Boundary_'+direction,rect,14,folder='Boundary')
   self.meta['boundary_segments'].append(dict(direction=direction,rect=rect,height=14))
   if self.plan['studded']:continue
   x=c+out*.5 if vertical else (start+end)/2
   z=(start+end)/2 if vertical else c+out*.5
   # Coping has same footprint as wall; it never projects into the lane.
   self.trim('BoundaryCoping',x,14.08,z,rect[2]-rect[0],.16,rect[3]-rect[1],'edge','Concrete')
   # Aligned wainscot on room-facing surface; noncolliding and no bullet query.
   wx=c-out*.015 if vertical else (start+end)/2
   wz=(start+end)/2 if vertical else c-out*.015
   if self.plan['name']=='Metro Exchange':
    self.trim('TileWainscot',wx,1.15,wz,.025 if vertical else length,2.3,length if vertical else .025,self.theme['accent'],'SmoothPlastic')
   # Pilasters remain on the boundary footprint, not arbitrary ground obstacles.
   if length>=12:
    for along in range(start+4,end-2,12):
     px=c+out*.45 if vertical else along
     pz=along if vertical else c+out*.45
     self.trim('BoundaryPier',px,7,pz,.90 if vertical else .5,14,.5 if vertical else .90,'edge','Concrete')
    lamp_candidates.append((wx,wz,(-out if vertical else 0),(0 if vertical else -out)))
  for args in lamp_candidates[::max(1,math.ceil(len(lamp_candidates)/14))]:self.bulkhead(*args)

 def build_blocks(self):
  name=self.plan['name']
  for i,rect in enumerate(self.plan['blocks']):
   x1,z1,x2,z2,height=rect;sx=x2-x1;sz=z2-z1;x=(x1+x2)/2;z=(z1+z2)/2
   low=height<4.5;style='Wall';color=self.theme['wall'];material=self.theme['wallmaterial']
   if not self.plan['studded']:
    if name=='Freight Terminal' and i==5:style='Office'
    elif name=='Freight Terminal' and i in (6,7):style='Cargo';color=self.theme['accent'];material='Metal'
    elif name=='Foundry' and i in (0,1):style='Machine';color=self.theme['accent'];material='Metal'
    elif name=='Metro Exchange' and i in (2,3):style='Column'
    elif name=='Skyline' and i in (2,3):style='Plant';color=self.theme['accent'];material='Metal'
    if low:color=(133,131,117);material='Concrete'
   node=self.box(f'{style}_{i:02d}',rect[:4],height,color,material,'Cover' if low else 'Architecture')
   self.parts[-1]['source_block_index']=i
   if self.plan['studded']:continue
   self.trim(style+'Cap',x,height+.04,z,sx,.08,sz,'edge','Concrete' if material!='Metal' else 'Metal')
   if low:
    # Sparse consistent safety marks on one face, not random damage paint.
    if sx>=4:self.trim('CoverSafetyInset',x,2.4,z1-.018,sx*.5,.12,.025,'yellow','SmoothPlastic')
    continue
   if style=='Office':
    for side in (-1,1):
     wz=z1-.025 if side<0 else z2+.025
     for wx in (x-3.5,x+3.5):
      self.trim('OfficeWindow',wx,7.7,wz,4.6,2.6,.04,(53,68,72),'SmoothPlastic')
      self.trim('WindowMullion',wx,7.7,wz+side*.026,.07,2.6,.025,'steel')
      self.trim('WindowSill',wx,6.35,wz,4.8,.10,.20,'steel')
    self.sign('DISPATCH',x,10.4,z1-.08,8)
   elif style=='Cargo':
    # Corrugation and framing belong to the same solid cargo footprint.
    for edge in (x1-.025,x2+.025):
     for wz in range(math.ceil(z1)+1,math.floor(z2),2):
      self.trim('CargoRib',edge,height/2,wz,.06,height-.7,.12,color)
    for edge in (z1-.025,z2+.025):
     self.trim('CargoFrameRail',x,height-.3,edge,sx,.16,.08,'steel')
   elif style in ('Machine','Plant'):
    # Opaque rectangular machine base preserves the checked collision silhouette.
    for edge in (x1-.03,x2+.03):
     for wz in range(math.ceil(z1)+2,math.floor(z2)-1,3):
      self.trim('VentPanel',edge,7,wz,.05,3,1.8,'dark')
      for yy in (6,6.5,7,7.5,8):self.trim('VentSlat',edge+(-.03 if edge<x else .03),yy,wz,.04,.07,1.6,'steel')
    for edge in (z1-.03,z2+.03):
     self.trim('MachineAccessPanel',x,4.5,edge,max(1,sx-1.2),5,.04,(65,76,76))
     self.trim('MachinePanelHandle',x,4.5,edge+.03,.12,.8,.08,'steel')
    if style=='Plant':
     # Roof vents stay inside an inaccessible 12-stud housing footprint.
     for vx in (x-4,x+4):
      self.part('PlantExhaustRing',(vx-self.width/2,12.18,z-self.depth/2),(.20,3.4,3.4),'steel','Metal','Details',False,shape='Cylinder')
   elif style=='Column':
    for side in (-1,1):
     self.trim('ColumnBase',x1-.025 if side<0 else x2+.025,1.1,z,.035,2.2,sz,(71,83,83),'SmoothPlastic')
   elif sx>2 and sz>2:
    # Subtle cast joints on selected solid faces, without debris or floating decals.
    self.trim('ConcreteJoint',x,height*.52,z1-.012,sx,.045,.025,'edge','SmoothPlastic')

 def paint_floor(self,mask):
  if self.plan['studded']:return
  w,h=self.plan['size']
  if self.plan['name']=='Metro Exchange':
   # Exact flush joint lines clipped to real floor; no overlapping floor slabs.
   for z in range(4,h,8):
    row=mask[z];start=None
    for x,on in enumerate(row+[False]):
     if on and start is None:start=x
     elif not on and start is not None:
      self.trim('TileJoint',(start+x)/2,.012,z,x-start,.024,.035,(137,141,132),'SmoothPlastic');start=None
   for x in range(4,w,8):
    start=None
    for z in range(h+1):
     on=z<h and mask[z][x]
     if on and start is None:start=z
     elif not on and start is not None:
      self.trim('TileJoint',x,.012,(start+z)/2,.035,.024,z-start,(137,141,132),'SmoothPlastic');start=None
  if self.plan['name']=='Canal Works':
   # Two logical service drain runs, clipped to valid floor, all flush.
   for x in (24,114):
    for z in range(12,h-4,4):
     if mask[z][x]:
      self.trim('DrainGrate',x+.5,.025,z+.5,.8,.05,2,'dark')
  if self.plan['name']=='Freight Terminal':
   for x in (44,69):
    self.trim('DockThreshold',x,.02,58,8,.04,.18,'yellow','SmoothPlastic')
  if self.plan['name']=='Skyline':
   for rect in self.meta['floor_rectangles']:
    x1,z1,x2,z2=rect
    if x2-x1>=12 and z2-z1>=8:
     self.trim('RoofExpansionSeam',(x1+x2)/2,.012,z1+3,x2-x1,.024,.04,'dark','SmoothPlastic')

 def architectural_finish(self):
  name=self.plan['name']
  if name=='Foundry':
   for z in (32,58):
    for x1,x2 in ((9.5,48.5),(55.5,94.5)):
     self.trim('SupportedRoofBeam',(x1+x2)/2,14.4,z,x2-x1,.8,.38,'steel')
  if name=='Metro Exchange':
   # Lightweight overhead frame supports only where corresponding boundary walls exist.
   for x in (54,76):
    self.trim('ConcourseRoofBeam',x,14.4,75,.35,.8,31,'steel')
   self.sign('MAINTENANCE',70,9,22.05,8)
  if name=='Canal Works':
   # High service conduit runs on one real exterior wall, above movement height.
   for segment in self.meta['boundary_segments']:
    direction=segment['direction'];x1,z1,x2,z2=segment['rect']
    if direction=='W' and z2-z1>=20:
     x=x2+.08
     self.trim('WallServiceConduit',x,10.6,(z1+z2)/2,.14,.14,z2-z1,self.theme['accent'])
     for z in range(math.ceil(z1)+3,math.floor(z2)-1,8):
      self.trim('ConduitBracket',x,10.6,z,.25,.5,.12,'steel')
     break

 def build_spawns(self):
  for team,zone,slots,opponent in zip(('Blue','Red'),self.plan['spawns'],self.plan['spawn_slots'],reversed(self.plan['spawns'])):
   team_folder=E.SubElement(self.folder('Spawns'),'Item',{'class':'Folder','referent':self.name+team})
   base.prop(E.SubElement(team_folder,'Properties'),'string','Name',team)
   yaw=math.degrees(math.atan2(-(opponent[0]-zone[0]),-(opponent[1]-zone[1])))
   self.meta['spawns'][team]=[]
   for i,(x,z) in enumerate(slots,1):
    position=(x+.5-self.width/2,3,z+.5-self.depth/2)
    node=self.part(f'{team}Spawn{i:02d}',position,(1,1,1),team.lower(),'SmoothPlastic','Spawns',False,yaw=yaw,transparency=1)
    # Move markers under team folder; referents stay unique and are registered in manifest.
    self.folder('Spawns').remove(node);team_folder.append(node)
    self.meta['spawns'][team].append(dict(name=f'{team}Spawn{i:02d}',position=list(position),yaw=yaw))
   self.trim(team+'SpawnTile',zone[0]+.5,.025,zone[1]+.5,10,.05,10,team.lower(),'Plastic' if self.plan['studded'] else 'SmoothPlastic')
   if not self.plan['studded']:
    # No in-world portal; painted tile and small stencil identify the pocket.
    candidates=[]
    for segment in self.meta['boundary_segments']:
     direction=segment['direction'];x1,z1,x2,z2=segment['rect'];vertical=direction in ('W','E')
     length=(z2-z1) if vertical else (x2-x1)
     if length<6:continue
     inward={'W':(1,0),'E':(-1,0),'S':(0,1),'N':(0,-1)}[direction]
     wx=(x1+x2)/2+inward[0]*.55 if vertical else min(max(zone[0]+.5,x1+3),x2-3)
     wz=min(max(zone[1]+.5,z1+3),z2-3) if vertical else (z1+z2)/2+inward[1]*.55
     candidates.append(((wx-zone[0])**2+(wz-zone[1])**2,wx,wz,inward))
    _,wx,wz,inward=min(candidates)
    sign_yaw=math.degrees(math.atan2(-inward[0],-inward[1]))
    self.sign(team.upper()+' / '+self.plan['mode'],wx,7,wz,5.5,yaw=sign_yaw)

 def finish(self):
  # Origin establishes a reliable map pivot without affecting traversal or spawning.
  origin=self.part('MapOrigin',(0,0,0),(.1,.1,.1),'dark','SmoothPlastic','Metadata',False,transparency=1)
  ref=origin.attrib['referent'];base.prop(self.model.find('Properties'),'Ref','PrimaryPart',ref)
  folder=self.folder('Metadata')
  for name,value,kind in [('MapId',self.name,'StringValue'),('PrimaryMode',self.plan['mode'],'StringValue'),('TeamSize',int(self.plan['mode'][0]),'IntValue'),('BuildVersion','team-build-v1','StringValue')]:
   node=E.SubElement(folder,'Item',{'class':kind,'referent':self.name+name});p=E.SubElement(node,'Properties')
   base.prop(p,'string','Name',name);base.prop(p,'int' if kind=='IntValue' else 'string','Value',value)
  self.meta['part_count']=len(self.parts);self.meta['parts']=self.parts
  self.meta['status']='Built and geometrically checked outside Roblox. Studio import, visuals and gameplay untested.'
  E.indent(self.xml,space='  ')
  (ROOT/'models'/f'{self.name}.rbxmx').write_bytes(E.tostring(self.xml,encoding='utf-8',xml_declaration=True))
  (ROOT/'models'/f'{self.name}.geometry.json').write_text(json.dumps(self.meta,indent=2)+'\n')


def main():
 (ROOT/'models').mkdir(exist_ok=True)
 maps=json.loads(PLAN.read_text());built=[]
 for plan in maps:
  arena=TeamArena(plan);mask=floor_mask(plan)
  arena.build_floor(mask);arena.build_boundary(mask);arena.build_blocks();arena.paint_floor(mask);arena.architectural_finish();arena.build_spawns();arena.finish()
  built.append(arena)
  print(f'Built {arena.name}: {len(arena.parts)} parts; {len(arena.meta["floor_rectangles"])} exact floor rectangles; {len(arena.meta["boundary_segments"])} exterior wall runs')
 root=E.Element('roblox',version='4');folder=E.SubElement(root,'Item',{'class':'Folder','referent':'TeamMapTemplates'})
 base.prop(E.SubElement(folder,'Properties'),'string','Name','TeamMapTemplates')
 for arena in built:folder.append(deepcopy(arena.model))
 E.indent(root,space='  ');(ROOT/'TeamMapTemplates.rbxmx').write_bytes(E.tostring(root,encoding='utf-8',xml_declaration=True))

if __name__=='__main__':main()
