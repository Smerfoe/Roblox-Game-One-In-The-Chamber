"""Deterministic environment additions. No live scripts or gameplay integration.
Original XML instances are preserved. ContainerYard is a separately reviewed rebuild.
"""
from pathlib import Path
import xml.etree.ElementTree as E
import math, json, hashlib, copy
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[1]
PAL=dict(steel=(65,72,73),dark=(31,37,39),paint=(86,98,92),yellow=(185,145,48),
         white=(188,186,167),rust=(113,69,46),brick=(111,86,72),wood=(120,98,68),
         blue=(49,77,102),red=(129,56,45),green=(75,88,60),cream=(154,151,126),
         concrete=(116,115,105),light=(220,207,160),black=(22,25,25),glass=(57,79,83))
MAT=dict(Plastic=256,SmoothPlastic=272,Neon=288,WoodPlanks=528,Concrete=816,Brick=848,
         Metal=1088,DiamondPlate=1056,CorrodedMetal=1040,Asphalt=1376)

def pval(p,kind,name,v):
 n=E.SubElement(p,kind,name=name);n.text=str(v).lower() if isinstance(v,bool) else str(v);return n

def props(n):return n.find('Properties')
def pname(n):return props(n).find("string[@name='Name']").text

def info(n):
 p=props(n);cf=p.find("CoordinateFrame[@name='CFrame']");s=p.find("Vector3[@name='size']")
 return ([float(cf.find(a).text) for a in 'XYZ'],[float(s.find(a).text) for a in 'XYZ'])

class Build:
 def __init__(self,name,source=None,size=None):
  self.name=name;self.source=source;self.parts=[];self.i=0;self.zones={};self.before={}
  if source:
   self.tree=E.parse(source);self.xml=self.tree.getroot();self.model=self.xml.find('Item')
   for n in self.model.iter('Item'):self.before[n.get('referent')]=E.tostring(n.find('Properties'))
  else:
   self.xml=E.Element('roblox',version='4');self.tree=E.ElementTree(self.xml)
   self.model=E.SubElement(self.xml,'Item',{'class':'Model','referent':'new_map'})
   pval(E.SubElement(self.model,'Properties'),'string','Name',name)
  self.base_parts=list(self.model.findall(".//Item[@class='Part']"))
  self.addroot=self.folder('EnvironmentRevamp',self.model);self.size=size
 def folder(self,name,parent=None):
  parent=parent if parent is not None else self.addroot
  for n in parent.findall('Item'):
   if n.get('class')=='Folder' and pname(n)==name:return n
  n=E.SubElement(parent,'Item',{'class':'Folder','referent':self.ref()})
  pval(E.SubElement(n,'Properties'),'string','Name',name);return n
 def ref(self):
  self.i+=1;return f'ENV_{self.name}_{self.i:06d}'
 def part(self,name,pos,size,color='steel',mat='Metal',zone='SurfaceDetails',solid=False,shape=1,R=None,trans=0):
  assert all(x>0 for x in size),(name,size)
  par=self.folder(zone);n=E.SubElement(par,'Item',{'class':'Part','referent':self.ref()});p=E.SubElement(n,'Properties')
  pval(p,'string','Name',name)
  for k,v in [('Anchored',True),('CanCollide',solid),('CanQuery',solid),('CanTouch',False),('CastShadow',trans<1)]:pval(p,'bool',k,v)
  for k,v in [('Transparency',trans),('Reflectance',0)]:pval(p,'float',k,v)
  pval(p,'token','Material',MAT[mat]);pval(p,'token','shape',shape)
  for k in ('TopSurface','BottomSurface'):pval(p,'token',k,0)
  v=E.SubElement(p,'Vector3',name='size')
  for k,x in zip('XYZ',size):E.SubElement(v,k).text=str(round(x,5))
  c=E.SubElement(p,'Color3',name='Color')
  for k,x in zip('RGB',PAL.get(color,color)):E.SubElement(c,k).text=str(x/255)
  cf=E.SubElement(p,'CoordinateFrame',name='CFrame')
  for k,x in zip('XYZ',pos):E.SubElement(cf,k).text=str(round(x,5))
  R=R or [1,0,0,0,1,0,0,0,1]
  for k,x in zip([f'R{i}{j}' for i in range(3) for j in range(3)],R):E.SubElement(cf,k).text=str(round(x,8))
  self.parts.append(dict(name=name,position=pos,size=size,color=PAL.get(color,color),material=mat,zone=zone,solid=solid,shape=shape,R=R))
  self.zones[zone]=self.zones.get(zone,0)+1;return n
 def rod(self,name,a,b,d=.16,color='steel',zone='Services'):
  # Cylinder local X follows the segment. Right handed orthonormal frame.
  v=[b[i]-a[i] for i in range(3)];length=math.sqrt(sum(x*x for x in v));u=[x/length for x in v]
  up=[0,1,0] if abs(u[1])<.95 else [0,0,1]
  cross=lambda a,b:[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
  z=cross(u,up);l=math.sqrt(sum(x*x for x in z));z=[x/l for x in z];y=cross(z,u)
  return self.part(name,[(a[i]+b[i])/2 for i in range(3)],[length,d,d],color,zone=zone,shape=2,R=[u[0],y[0],z[0],u[1],y[1],z[1],u[2],y[2],z[2]])
 def sign(self,text,pos,size=(5,1.6,.08),face=5,zone='Wayfinding',color='dark'):
  n=self.part('Sign_'+text.replace('\n','_'),pos,size,color,zone=zone)
  self.label(n,text,face)
 def label(self,n,text,face=5):
  gui=E.SubElement(n,'Item',{'class':'SurfaceGui','referent':self.ref()});p=E.SubElement(gui,'Properties')
  pval(p,'string','Name','ReadableSign');pval(p,'token','Face',face);pval(p,'bool','AlwaysOnTop',False)
  pval(p,'token','SizingMode',1);pval(p,'float','PixelsPerStud',45);pval(p,'float','LightInfluence',1)
  label=E.SubElement(gui,'Item',{'class':'TextLabel','referent':self.ref()});p=E.SubElement(label,'Properties')
  pval(p,'string','Name','Label');pval(p,'string','Text',text);pval(p,'float','BackgroundTransparency',1)
  pval(p,'bool','TextScaled',True);pval(p,'token','Font',4)
  c=E.SubElement(p,'Color3',name='TextColor3')
  for a,v in zip('RGB',(0.88,.86,.76)):E.SubElement(c,a).text=str(v)
  u=E.SubElement(p,'UDim2',name='Size')
  for a,v in [('XS',1),('XO',0),('YS',1),('YO',0)]:E.SubElement(u,a).text=str(v)
 def fixture(self,pos,size=(3,.3,1),zone='FunctionalLighting',brightness=1.2,range=24):
  n=self.part('IndustrialLuminaire',pos,size,'light','Neon',zone)
  light=E.SubElement(n,'Item',{'class':'PointLight','referent':self.ref()});p=E.SubElement(light,'Properties')
  pval(p,'string','Name','MapLuminaire');pval(p,'float','Brightness',brightness);pval(p,'float','Range',range);pval(p,'bool','Shadows',True)
  c=E.SubElement(p,'Color3',name='Color')
  for k,v in zip('RGB',(1,.94,.82)):E.SubElement(c,k).text=str(v)
  return n
 def panel(self,x,y,z,w=3,h=3,zone='ServicePanels',normal=-1):
  self.part('ServicePanel',(x,y,z),(w,h,.12),'paint',zone=zone)
  for dx in (-w/2+.15,w/2-.15):
   for dy in (-h/2+.15,h/2-.15):self.part('PanelFastener',(x+dx,y+dy,z+normal*.08),(.10,.10,.05),'steel',zone=zone)
  self.part('RecessedHandle',(x+w*.31,y,z+normal*.08),(.08,.5,.05),'dark',zone=zone)
  for dy in (-.6,-.3,0,.3):self.part('PanelVent',(x-w*.15,y+dy,z+normal*.08),(w*.5,.055,.04),'dark',zone=zone)
 def pallet(self,x,z,y=0,zone='ExteriorCargo'):
  for dx in (-1.25,0,1.25):self.part('PalletRunner',(x+dx,y+.25,z),(.35,.5,3.5),'wood','WoodPlanks',zone)
  for dz in (-1.5,-.9,-.3,.3,.9,1.5):self.part('PalletDeck',(x,y+.59,z+dz),(3.5,.18,.42),'wood','WoodPlanks',zone)
 def crate(self,x,z,y=0,w=3,h=3,d=3,zone='ExteriorCargo'):
  self.part('ShippingCrate',(x,y+h/2,z),(w,h,d),'wood','WoodPlanks',zone)
  for dx in (-w/2+.2,w/2-.2):self.part('CrateStile',(x+dx,y+h/2,z-d/2-.055),(.25,h,.11),'cream',zone=zone)
  for yy in (.18,h-.18):self.part('CrateRail',(x,y+yy,z-d/2-.06),(w,.25,.12),'cream',zone=zone)
  self.sign('HANDLE WITH CARE',(x,y+h*.55,z-d/2-.13),(w*.7,.7,.025),zone=zone)
 def drum(self,x,z,y=0,color='blue',zone='ExteriorCargo'):
  self.rod('SteelDrum',(x,y,z),(x,y+2.7,z),1.8,color,zone)
  for yy in (.15,.8,1.9,2.6):self.rod('DrumHoop',(x,y+yy-.055,z),(x,y+yy+.055,z),1.86,'steel',zone)
  self.rod('DrumLid',(x,y+2.7,z),(x,y+2.75,z),1.73,'dark',zone)
  self.rod('DrumBung',(x+.38,y+2.75,z+.28),(x+.38,y+2.79,z+.28),.19,'steel',zone)
 def exterior_building(self,x,z,w,d,h,theme='brick',zone='Backdrop'):
  self.part('IndustrialBuilding',(x,h/2,z),(w,h,d),theme,'Brick' if theme=='brick' else 'Concrete',zone)
  self.part('RoofCoping',(x,h+.175,z),(w+.5,.35,d+.5),'steel',zone=zone)
  for dx in (-w/2+.6,w/2-.6):self.part('CornerColumn',(x+dx,h/2,z-d/2-.1),(.5,h,.3),'concrete',zone=zone)
  for yy in (7,14,21):
   if yy+2>h:continue
   for dx in range(-int(w/2)+4,int(w/2)-2,7):
    self.part('FactoryWindow',(x+dx,yy,z-d/2-.17),(4,3.1,.12),'glass',zone=zone)
    self.part('WindowMullion',(x+dx,yy,z-d/2-.25),(.09,3.2,.06),'steel',zone=zone)
    self.part('WindowSill',(x+dx,yy-1.65,z-d/2-.3),(4.4,.18,.5),'concrete',zone=zone)
 def service_door(self,x,z,label='SERVICE',zone='WallDetails',normal=-1):
  # Flush facade, 0.22 total depth; doesn't pretend to be a usable doorway.
  self.part('ClosedSteelDoor',(x,3.6,z),(3.5,7.2,.12),'paint',zone=zone)
  for dx in (-1.82,1.82):self.part('DoorJamb',(x+dx,3.65,z+normal*.04),(.12,7.3,.15),'steel',zone=zone)
  self.part('DoorHeader',(x,7.3,z+normal*.04),(3.8,.14,.15),'steel',zone=zone)
  self.part('DoorLever',(x+1.1,3.4,z+normal*.13),(.45,.08,.07),'white',zone=zone)
  self.sign(label,(x,8.1,z+normal*.05),(4.6,.9,.08),face=5 if normal<0 else 2,zone=zone)
 def roof_equipment(self,x,z,y=12,w=5,d=5):
  self.part('RoofEquipmentCurb',(x,y+.18,z),(w+.4,.36,d+.4),'dark',zone='RoofEquipment')
  self.part('AirHandlingUnit',(x,y+1.1,z),(w,1.6,d),'white',zone='RoofEquipment')
  for dx in (-w*.25,w*.25):
   self.rod('FanCowl',(x+dx,y+1.9,z),(x+dx,y+2.08,z),min(w*.37,d*.8),'dark','RoofEquipment')
   for angle in (0,45,90,135):
    a=math.radians(angle);r=min(w*.17,d*.35)
    self.rod('FanGuard',(x+dx-r*math.cos(a),y+2.1,z-r*math.sin(a)),(x+dx+r*math.cos(a),y+2.1,z+r*math.sin(a)),.045,'steel','RoofEquipment')
 def save(self):
  dress_existing_cover(self)
  E.indent(self.xml,space='  ');out=ROOT/'models'/f'{self.name}.rbxmx';self.tree.write(out,encoding='utf-8',xml_declaration=True)
  meta=dict(name=self.name,source=str(self.source.relative_to(REPO)) if self.source else None,
   source_sha256=hashlib.sha256(self.source.read_bytes()).hexdigest() if self.source else None,
   baseline_instances=len(self.before),added_parts=len(self.parts),zones=self.zones,parts=self.parts,
   status='External build. Not imported or tested in Roblox Studio.',footprint=self.size)
  (ROOT/'models'/f'{self.name}.manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
  return meta

def foundry():
 b=Build('Foundry',ROOT/'sources/Foundry_Current.rbxmx',[104,92])
 # Closed service doors on the two central void-box facades; no routes altered.
 for x,z in [(0,-18.62),(0,18.62)]:
  b.service_door(x,z,'ELECTRICAL / AUTHORIZED STAFF',normal=1 if z>0 else -1)
  b.panel(x+2.5,4.5,z,1.15,2.2,normal=1 if z>0 else -1)
 # Both furnaces receive assembled plates, recessed controls and high connected ductwork.
 for x,z,num in [(-23.5,-4,'01'),(23.5,4,'02')]:
  zone='Furnace_'+num
  for side in (-1,1):
   sx=x+side*3.57
   # horizontal seam and bolts along panels, all within 0.22 studs of original shell.
   for zz in (-10,-5,0,5,10):
    b.part('PlateSeam',(sx,6,z+zz),(.035,10.8,.045),'dark',zone=zone)
    for yy in (1.3,9.8):b.part('PanelBolt',(sx+side*.035,yy,z+zz),(.07,.13,.13),'white',zone=zone)
   b.part('ServiceAccessPlate',(sx,2.7,z+7),(.09,2.4,4),'paint',zone=zone)
   for dz in (-1.7,1.7):b.part('AccessLatch',(sx+side*.065,2.7,z+7+dz),(.07,.5,.1),'white',zone=zone)
   b.part('ControlRecess',(sx,6,z-9.3),(.13,2.6,2.7),'dark',zone=zone)
   for dz,col in [(-.75,'green'),(0,'yellow'),(.75,'red')]:b.part('ControlIndicator',(sx+side*.085,6.6,z-9.3+dz),(.05,.22,.22),col,zone=zone)
   b.part('ControlDisplay',(sx+side*.085,5.8,z-9.3),(.05,.6,1.6),'glass',zone=zone)
  for end in (-1,1):
   zz=z+end*12.09
   b.part('FurnaceEndAccessDoor',(x,4.8,zz),(4.5,6.8,.12),'paint',zone=zone)
   for dx in (-2.35,2.35):b.part('EndDoorJamb',(x+dx,4.8,zz+end*.06),(.14,7,.12),'steel',zone=zone)
   for yy in (1.3,8.3):b.part('EndDoorRail',(x,yy,zz+end*.06),(4.8,.16,.12),'steel',zone=zone)
   for yy in (2,4.8,7.6):
    b.part('EndDoorHinge',(x-2.1,yy,zz+end*.12),(.3,.4,.08),'white',zone=zone)
   b.part('EndDoorLatch',(x+1.6,4.5,zz+end*.12),(.15,.6,.08),'white',zone=zone)
  b.sign('CASTING UNIT '+num,(x,9.3,z-12.12),(5.7,1.25,.10),zone=zone)
  b.rod('ExtractionRiser',(x,12.1,z+6),(x,18.5,z+6),2,'steel','OverheadExtraction')
  b.rod('ExtractionMain',(x,18.5,z+6),(x,18.5,-47),2,'steel','OverheadExtraction')
  for zz in range(-42,int(z+6),8):
   b.rod('DuctFlange',(x,18.5,zz-.10),(x,18.5,zz+.10),2.22,'dark','OverheadExtraction')
   b.rod('DuctHanger',(x,19.6,zz),(x,23,zz),.1,'steel','OverheadExtraction')
  b.rod('ExtractionDrop',(x,18.5,-47),(x,6,-47),2,'steel','ExteriorPlant')
 # Real framing over machine halls, open central light strip.
 for x in (-46,-12,12,46):
  for z in (-34,34):
   # Supports are outside the boundary or above existing shell, not in walkways.
   b.part('PortalColumn',(x,12,-47.4 if z<0 else 47.4),(.7,24,.7),'steel',zone='Structure')
  b.part('LongitudinalIBeamWeb',(x,22,0),(.2,1.1,96),'steel',zone='Structure')
  for yy in (21.45,22.55):b.part('IBeamFlange',(x,yy,0),(.8,.15,96),'steel',zone='Structure')
 for z in (-34,-12,12,34):
  b.part('CrossBeamWeb',(0,22,z),(94,.9,.18),'steel',zone='Structure')
  for yy in (21.55,22.45):b.part('CrossBeamFlange',(0,yy,z),(94,.12,.6),'steel',zone='Structure')
  # Roof sections leave the centre and edges open to daylight; no invisible geometry.
  for x in (-29,29):b.part('CorrugatedCanopy',(x,23.05,z),(33,.18,20),'paint',zone='Structure')
 for xx in (-29,29):
  for zz in (-24,0,24):b.fixture((xx,20.8,zz),brightness=1.2,range=26)
 # Electrical services follow actual wall segments, including irregular spawn bays.
 for n in b.base_parts:
  side=pname(n)
  if side not in ('Boundary_N','Boundary_S'):continue
  (x,y,z),(w,h,d)=info(n)
  if w<7:continue
  normal=1 if side=='Boundary_N' else -1;zz=z+normal*.59
  b.panel(x,5,zz,2.4,3.2,zone='WallServices',normal=normal)
  b.rod('CableRiser',(x+1.3,6.7,zz),(x+1.3,10.8,zz),.12,'steel','WallServices')
  b.rod('WallConduit',(x-w/2+.3,10.8,zz),(x+w/2-.3,10.8,zz),.16,'steel','WallServices')
  for xx in range(math.ceil(x-w/2)+2,math.floor(x+w/2),5):b.part('ConduitClip',(xx,10.8,zz),(.14,.35,.19),'dark',zone='WallServices')
 # Flush joints follow real floor rectangles, no lines drawn across missing-floor holes.
 for n in b.base_parts:
  if pname(n)!='FoundationSlab':continue
  (x,y,z),(w,h,d)=info(n)
  for xx in range(math.ceil(x-w/2)+6,math.floor(x+w/2)-1,10):b.part('FloorExpansionJoint',(xx,.012,z),(.035,.024,d-.2),'dark','SmoothPlastic','FloorFinish')
  for zz in range(math.ceil(z-d/2)+6,math.floor(z+d/2)-1,10):b.part('FloorExpansionJoint',(x,.013,zz),(w-.2,.026,.035),'dark','SmoothPlastic','FloorFinish')
 # Convincing grounds, rear workshops, tanks, switchgear and staged supplies outside walls.
 b.part('FacilityGround',(0,-.2,0),(240,.3,220),'concrete','Asphalt','Backdrop')
 for x,z,w,d,h in [(-72,-15,28,66,27),(72,12,28,60,24),(0,-77,104,30,32),(0,78,90,26,22)]:b.exterior_building(x,z,w,d,h)
 for x in (-42,0,42):b.service_door(x,-62.1,'PLANT SERVICES','ExteriorWorkshop')
 for x,z in [(-59,-42),(-59,26),(60,-25),(60,38)]:
  b.pallet(x,z);b.crate(x,z,.7)
  for dx in (-3,3):b.drum(x+dx,z+5,color='green')
 for x in (-34,34):
  b.rod('CycloneBody',(x,0,-55),(x,18,-55),6,'white','ExteriorPlant')
  for y in (1,8,17):b.rod('CycloneBand',(x,y,-55),(x,y+.15,-55),6.2,'steel','ExteriorPlant')
  b.rod('ExhaustChimney',(x,18,-55),(x,40,-55),2.2,'steel','ExteriorPlant')
 for x in (-8,8):b.roof_equipment(x,-76,32,9,7)
 return b.save()


def shipping_container(b,x,z,color='red',y=0,yaw=0,opened=False,zone='ContainerConstruction',solid=True,length=28):
 """10 x 28 x 12, jointed shell. Local Z is the long axis."""
 a=math.radians(yaw);c,s=math.cos(a),math.sin(a);R=[c,0,s,0,1,0,-s,0,c]
 def P(name,xx,yy,zz,ww,hh,dd,col=color,mat='Metal',collide=False):
  if zone=='PortBackdrop' and name in ('DoorLockRod','LockHandle','RodKeeper','DoorHinge','CornerCastingSocket','LowerRailWear'):return None
  return b.part(name,(x+c*xx+s*zz,y+yy,z-s*xx+c*zz),(ww,hh,dd),col,mat,zone,collide,R=R)
 L=length
 P('ContainerFloor',0,.11,0,10,.22,L,'steel',collide=solid)
 P('ContainerRoof',0,11.85,0,10,.3,L,collide=solid)
 for side in (-1,1):
  P('ContainerSide',side*4.86,6,0,.28,12,L,collide=solid)
  for dz in range(-int(L/2)+1,int(L/2),2 if zone=='PortBackdrop' else 1):
   P('PressedCorrugation',side*5.055,6,dz,.11,11.1,.22)
  for yy in (.27,11.72):P('WeldedSideRail',side*5.02,yy,0,.18,.25,L,'steel')
  for end in (-1,1):
   P('CornerPost',side*4.8,6,end*(L/2-.2),.42,12,.42)
   for yy in (.3,11.7):
    P('CornerCasting',side*4.8,yy,end*(L/2-.2),.6,.6,.6,'steel')
    P('CornerCastingSocket',side*5.12,yy,end*(L/2-.2),.035,.22,.3,'dark')
 for side in (-1,1):
  panel=P('FreightIdentityPanel',side*5.15,8.4,1.5,.045,1.8,8.5,color)
  b.label(panel,'NORTH DOCK / INTERMODAL',0 if side>0 else 3)
 for xx in range(-4,5,2 if zone=='PortBackdrop' else 1):P('RoofRib',xx,12.035,0,.16,.07,L-.6)
 for end in (-1,1):
  if opened and end==-1:
   P('OpenDoorHeader',0,11.35,-L/2+.1,9.5,1.1,.28,collide=solid)
   # Leaves are folded flat along the outer side walls; no lane-spanning leaf.
   for side in (-1,1):
    P('FoldedDoorLeaf',side*5.21,5.7,-L/2+2.55,.18,11.2,4.8,collide=solid)
    for yy in (1,5.7,10.5):P('FoldedDoorHinge',side*5.34,yy,-L/2+.4,.16,.3,.5,'steel')
   P('InteriorTimberFloor',0,.245,0,9.4,.045,L-.5,'wood','WoodPlanks')
  else:
   for side in (-1,1):
    P('ContainerDoor',side*2.38,5.8,end*(L/2-.1),4.65,11.5,.2,collide=solid)
    for dx in (side*1.35,side*3.35):
     P('DoorLockRod',dx,5.7,end*(L/2+.10),.10,10.7,.10,'steel')
     P('LockHandle',dx+.22,3.5,end*(L/2+.18),.50,.09,.08,'white')
     for yy in (.7,5.7,10.8):P('RodKeeper',dx,yy,end*(L/2+.16),.24,.19,.12,'steel')
    for yy in (1,5.8,10.6):P('DoorHinge',side*4.5,yy,end*(L/2+.1),.32,.35,.20,'steel')
 for side in (-1,1):
  for dz in (-9,-3,4,10):
   # Small localized exposed-metal patches, no randomized noise or fake texture.
   P('LowerRailWear',side*5.13,.7,dz,.025,.1,.6,'rust')
 return b

def forklift(b,x,z,zone='ExteriorForklift'):
 b.part('Counterweight',(x,1.6,z+1.7),(3.8,2.8,2.4),'yellow',zone=zone)
 b.part('ForkliftChassis',(x,.95,z),(3.8,.7,5.7),'dark',zone=zone)
 for side in (-1,1):
  for dz in (-1.7,1.7):b.rod('RubberTyre',(x+side*1.6,.85,z+dz),(x+side*2.05,.85,z+dz),1.65,'black',zone)
  for dz in (-1.2,1.1):b.part('CabUpright',(x+side*1.55,4,z+dz),(.16,5,.16),'dark',zone=zone)
  b.part('ForkBlade',(x+side*.95,.3,z-4.2),(.35,.18,4.5),'steel',zone=zone)
  b.part('MastRail',(x+side*1.2,4.2,z-2.6),(.32,7.5,.4),'steel',zone=zone)
 b.part('OverheadGuard',(x,6.55,z),(3.5,.18,3),'dark',zone=zone)
 b.part('Seat',(x,2.3,z+.5),(1.8,.35,1.4),'black',zone=zone)
 b.part('SeatBack',(x,3,z+1.1),(1.8,1.4,.3),'black',zone=zone)
 b.rod('SteeringColumn',(x,1.8,z-.9),(x,3.5,z-1.1),.13,'steel',zone)

def container_yard():
 b=Build('ContainerYard',size=[136,136]);zone='GameplayShell'
 b.part('AsphaltYard',(0,-1,0),(136,2,136),(69,72,69),'Asphalt',zone,True)
 # Entire layout is new and requires match testing; no live replacement is attempted.
 for sign in (-1,1):
  b.part('SolidBoundary',(sign*68.5,12,0),(1,24,138),'dark',zone=zone,solid=True)
  b.part('SolidBoundary',(0,12,sign*68.5),(136,24,1),'dark',zone=zone,solid=True)
 # The perimeter reads as two levels of container stacks, not blank arena walls.
 for side in (-1,1):
  for k,centre in enumerate((-54,-27,0,27,54)):
   for level in (0,1):
    col=('blue','cream','red','green','cream')[(k+level)%5];yy=6+12*level
    b.part('PerimeterContainerSkin',(side*67.93,yy,centre),(.12,11.8,26.7),col,zone='PerimeterContainerFacade')
    b.part('PerimeterContainerSkin',(centre,yy,side*67.93),(26.7,11.8,.12),col,zone='PerimeterContainerFacade')
    for offset in range(-12,13):
     b.part('PerimeterCorrugation',(side*67.80,yy,centre+offset),(.12,11.2,.18),col,zone='PerimeterContainerFacade')
     b.part('PerimeterCorrugation',(centre+offset,yy,side*67.80),(.18,11.2,.12),col,zone='PerimeterContainerFacade')
    for end in (-1,1):
     b.part('PerimeterCornerPost',(side*67.76,yy,centre+end*13.1),(.20,12,.28),'steel',zone='PerimeterContainerFacade')
     b.part('PerimeterCornerPost',(centre+end*13.1,yy,side*67.76),(.28,12,.20),'steel',zone='PerimeterContainerFacade')
    for height in (yy-5.85,yy+5.85):
     b.part('PerimeterRail',(side*67.75,height,centre),(.24,.25,26.8),'steel',zone='PerimeterContainerFacade')
     b.part('PerimeterRail',(centre,height,side*67.75),(26.8,.25,.24),'steel',zone='PerimeterContainerFacade')
 for x,z,col,opened in [(-27,-22,'red',False),(-17,-22,'blue',True),(17,-22,'green',False),(27,-22,'red',False),(-27,22,'cream',False),(-17,22,'green',False),(17,22,'blue',True),(27,22,'red',False)]:
  shipping_container(b,x,z,col,opened=opened)
 for x,z,yaw,col in [(-57,0,0,'blue'),(-47,0,0,'cream'),(47,0,0,'red'),(57,0,0,'blue'),(0,-57,90,'red'),(0,-47,90,'blue'),(0,47,90,'cream'),(0,57,90,'green')]:shipping_container(b,x,z,col,yaw=yaw,opened=(x==-57 or x==57))
 # A small number of upper stacks, placed directly on load-bearing lower shells.
 for x,z,col in [(-27,-22,'green'),(27,22,'cream'),(-57,0,'red'),(57,0,'blue')]:shipping_container(b,x,z,col,y=12)
 # Spawn markers follow the current team-map HRP convention. Ground clearance / LOS checked externally.
 for team,sign in [('Blue',-1),('Red',1)]:
  # LookVector into the arena. Roblox look = negative local Z.
  u=-sign/math.sqrt(2);vals=[-u,0,-u,0,1,0,u,0,-u]
  marker=b.part(team+'Spawn01',(sign*58,3,sign*58),(1,1,1),'blue' if sign<0 else 'red',zone='SpawnMarkers',trans=1,R=vals)
  b.folder('SpawnMarkers').remove(marker)
  b.folder(team,b.folder('Spawns',b.model)).append(marker)
  # Diagonal exits from a protected corner; no tiny freestanding spawn shield.
  b.part('SpawnScreen',(sign*48,6,sign*52),(1,12,16),'green',zone=zone,solid=True)
 # Markings have deliberate interruptions instead of perfect bright graphic outlines.
 for z in (-39,39):
  for x in (-51,-39,-27,-15,15,27,39,51):b.part('FadedLoadingMark',(x,.015,z),(5,.03,.18),'yellow','SmoothPlastic','YardSurface')
 for x,z in [(-38,-45),(38,45),(-38,45),(38,-45)]:
  b.part('DrainFrame',(x,.018,z),(1.5,.036,5),'steel',zone='YardSurface')
  for dz in (-2,-1.6,-1.2,-.8,-.4,0,.4,.8,1.2,1.6,2):b.part('DrainSlot',(x,.043,z+dz),(1.1,.014,.10),'dark',zone='YardSurface')
 for x in (-36,36):
  for z in (-54,-27,0,27,54):b.part('AsphaltJoint',(x,.008,z),(.025,.016,20),'dark',zone='YardSurface')
 # Deliberate solid cargo groups on the new layout's perimeter, away from spawn exits.
 for x,z in [(58,35),(-58,35),(58,-35)]:
  start=len(b.parts);b.pallet(x,z,zone='NewGameplayCargo');b.crate(x,z,.7,zone='NewGameplayCargo')
  b.drum(x+(-4 if x>0 else 4),z,color='blue',zone='NewGameplayCargo')
  # Parts are visible collision geometry, not invisible proxy shields.
  # NewGameplayCargo is wholly solid; no large non-solid decorations in movement paths.
  for n in b.folder('NewGameplayCargo').findall('Item'):
   if n.get('class')=='Part':
    for key in ('CanCollide','CanQuery'):props(n).find(f"bool[@name='{key}']").text='true'
  for item in b.parts[start:]:item['solid']=True
 # A parked forklift is deliberate new gameplay geometry in the west loading recess.
 forklift(b,-58,-35,zone='NewGameplayForklift')
 for n in b.folder('NewGameplayForklift').findall('Item'):
  if n.get('class')=='Part':
   for key in ('CanCollide','CanQuery'):props(n).find(f"bool[@name='{key}']").text='true'
 for item in b.parts:
  if item['zone']=='NewGameplayForklift':item['solid']=True
 # Additional cargo props are outside the solid boundary.

 b.part('PortApron',(0,-.2,0),(300,.3,280),(83,85,78),'Asphalt','PortBackdrop')
 for x in (-84,84):
  for z,col in [(-48,'green'),(-18,'cream'),(12,'blue'),(42,'red')]:
   shipping_container(b,x,z,col,zone='PortBackdrop',solid=False)
   shipping_container(b,x,z,'red' if col=='green' else 'cream',y=12,zone='PortBackdrop',solid=False)
   if x==84:shipping_container(b,x,z,'green',y=24,zone='PortBackdrop',solid=False)
 for x,z in [(-77,-62),(-76,59),(77,-62),(76,61),(-31,-77),(29,78)]:
  b.pallet(x,z);b.crate(x,z,.7)
  b.drum(x+4,z,color='blue');b.drum(x+4,z+2,color='green')
 forklift(b,-77,37);forklift(b,34,-78)
 b.exterior_building(-115,0,36,134,29,'concrete','PortBackdrop')
 for x in (-40,40):b.exterior_building(x,105,65,32,22,'concrete','PortBackdrop')
 # Gantry cranes define the port skyline; cross-braced frames, trolley, cables.
 for cx,cz in [(-96,-82),(92,80)]:
  for dx in (-13,13):
   for dz in (-9,9):b.part('GantryLeg',(cx+dx,30,cz+dz),(1.8,60,1.8),'yellow',zone='PortCranes')
   b.rod('GantryDiagonal',(cx+dx,4,cz-9),(cx+dx,54,cz+9),.5,'yellow','PortCranes')
   b.rod('GantryDiagonal',(cx+dx,4,cz+9),(cx+dx,54,cz-9),.5,'yellow','PortCranes')
  for dz in (-9,9):b.part('GantryHeadBeam',(cx,59,cz+dz),(58,2,1.8),'yellow',zone='PortCranes')
  b.part('CraneTrolley',(cx,58,cz),(7,2,16),'steel',zone='PortCranes')
  for dx in (-2,2):b.rod('HoistCable',(cx+dx,57,cz),(cx+dx,35,cz),.1,'steel','PortCranes')
  b.part('ContainerSpreader',(cx,34.5,cz),(9,1,4),'yellow',zone='PortCranes')
 # Floodlight towers outside each corner.
 for x,z in [(-76,-76),(76,76),(-76,76),(76,-76)]:
  b.rod('LightMast',(x,0,z),(x,34,z),.45,'steel','PortLighting')
  b.part('FloodlightCrossarm',(x,34,z),(6,.2,.25),'steel',zone='PortLighting')
  for dx in (-2,0,2):
   b.part('FloodlightHousing',(x+dx,33.6,z),(1.4,.9,.65),'dark',zone='PortLighting')
   b.part('FloodlightLens',(x+dx,33.6,z-.35),(1.2,.7,.05),'light',zone='PortLighting')
 origin=b.part('MapOrigin',(0,0,0),(1,1,1),zone='OriginMarker',trans=1)
 b.folder('OriginMarker').remove(origin);metadata=b.folder('Metadata',b.model);metadata.append(origin)
 pval(props(b.model),'Ref','PrimaryPart',origin.get('referent'))
 for key,value in [('MapId','ContainerYard'),('PrimaryMode','1v1'),('BuildVersion','environment-review-v1')]:
  n=E.SubElement(metadata,'Item',{'class':'StringValue','referent':b.ref()});p=E.SubElement(n,'Properties');pval(p,'string','Name',key);pval(p,'string','Value',value)
 return b.save()


def boundary_services(b,theme):
 """Attach to each actual boundary segment, including internal courtyard edges.
 Use local frame with local -Z facing into playable space; max protrusion .22.
 """
 for n in b.base_parts:
  name=pname(n)
  if not name.startswith('Boundary_'):continue
  (x,y,z),(w,h,d)=info(n);side=name.split('_')[1];length=d if side in ('E','W') else w
  yaw={'N':180,'S':0,'E':90,'W':-90}[side];a=math.radians(yaw);c,s=math.cos(a),math.sin(a);R=[c,0,s,0,1,0,-s,0,c]
  # -Z local points inward; start at the existing face.
  fx=x-s*.5;fz=z-c*.5
  def P(label,u,yy,out,ww,hh,depth,col='steel',mat='Metal'):
   return b.part(label,(fx+c*u-s*out,yy,fz-s*u-c*out),(ww,hh,depth),col,mat,'BoundaryFinish',R=R)
  if theme=='metro':
   P('StationColourBand',0,5,.06,length,.27,.08,'blue')
   P('Skirting',0,.45,.07,length,.65,.1,'dark')
   for u in range(-int(length/2)+2,int(length/2),3):P('TileJoint',u,3,.08,.025,5,.035,'steel','SmoothPlastic')
   if length>9:
    P('InsetAdvertisingFrame',0,8,.1,5,2.4,.12,'steel')
    P('StationMapPanel',0,8,.18,4.7,2.1,.035,'cream')
    for yy in (7.5,8,8.5):P('TransitLine',0,yy,.205,3.9,.075,.02,'blue')
  elif theme=='canal':
   P('TideStain',0,1.2,.035,length,1.8,.035,'paint','Concrete')
   P('ConcretePourJoint',0,6,.04,.04,11,.04,'dark','SmoothPlastic')
   P('WallCopingDrip',0,12.8,.055,length,.12,.06,'white')
   if length>7:
    P('UtilityCabinet',0,4.5,.1,2.4,3,.15,'paint')
    P('CabinetLatch',.8,4.5,.2,.06,.5,.06,'dark')
    P('CableConduit',1.2,8,.1,.12,4,.12,'steel')
  elif theme=='freight':
   P('WallBaseProtection',0,1.2,.075,length,2,.12,'dark')
   if length>10:
    for u in range(-int(length/2)+3,int(length/2),7):
     P('WallDockNumberPlate',u,9,.1,1.8,1.4,.12,'cream')
     P('DockBumper',u,1.7,.12,.7,2.3,.14,'dark')
    P('HighCableTray',0,10.6,.1,length,.25,.16,'steel')
  elif theme=='skyline':
   P('FlashingDripEdge',0,13.5,.1,length,.18,.16,'steel')
   P('RenderControlJoint',0,6,.04,.04,12,.04,'dark','SmoothPlastic')
   if length>10:
    P('RecessedServiceDoor',0,3.6,.07,3.2,7,.1,'paint')
    P('DoorLever',1,3.5,.15,.4,.06,.06,'steel')
  else:
   P('FormworkJoint',0,6,.04,.035,10,.04,'dark','SmoothPlastic')

def floor_finish(b,theme):
 # Metro already has an exact clipped floor grid; avoid duplicate coplanar joints.
 if theme=='metro':return
 for n in b.base_parts:
  if pname(n) not in ('FoundationSlab','Foundation'):continue
  (x,y,z),(w,h,d)=info(n)
  for xx in range(math.ceil(x-w/2)+5,math.floor(x+w/2)-1,10):b.part('ExpansionJoint',(xx,.01,z),(.025,.02,d-.3),'dark','SmoothPlastic','FloorFinish')
  if theme=='metro':
   for zz in range(math.ceil(z-d/2)+3,math.floor(z+d/2)-1,5):b.part('FloorTileJoint',(x,.012,zz),(w-.3,.024,.025),'steel','SmoothPlastic','FloorFinish')

def freight():
 b=Build('FreightTerminal',REPO/'maps/team_maps/models/FreightTerminal.rbxmx',[112,88]);boundary_services(b,'freight');floor_finish(b,'freight')
 for x,z,w,d in [(19,3,14,12),(2.5,-19,7,18)]:
  for side in (-1,1):
   for dz in range(-int(d/2)+1,int(d/2)):
    b.part('CargoPressedRib',(x+side*(w/2+.08),6,z+dz),(.12,11.3,.15),'paint',zone='CargoConstruction')
  for xx in (-w*.3,w*.3):
   b.part('CargoDoorLock',(x+xx,5.8,z-d/2-.15),(.12,10.8,.12),'steel',zone='CargoConstruction')
  b.sign('FREIGHT / SEALED LOAD',(x,8,z-d/2-.12),(w*.8,1,.08),zone='CargoConstruction')
 b.service_door(-17.5,-17.12,'DISPATCH OFFICE');b.roof_equipment(-17.5,-8.5,12,7,7)
 # Warehouse canopy over the northern cargo room, supported behind the boundary.
 for x in (-33,33):b.part('WarehouseColumn',(x,10,-45),(.8,20,.8),'steel',zone='WarehouseStructure')
 for x in (-33,0,33):
  b.part('WarehouseTruss',(x,19.8,-20),(.3,1,50),'steel',zone='WarehouseStructure')
  for z in (-40,-28,-16,-4):b.rod('TrussBrace',(x,19,z-5),(x,21,z+5),.15,'steel','WarehouseStructure')
 b.part('WarehouseCanopy',(0,21.1,-21),(68,.2,50),'paint',zone='WarehouseStructure')
 for x in (-26,0,26):b.fixture((x,19.2,-20),brightness=1.4,range=26)
 b.part('DistributionApron',(0,-.15,0),(240,.2,190),'concrete','Asphalt','Backdrop')
 for x in (-84,84):
  b.exterior_building(x,0,38,120,27,'concrete')
  for z in (-32,0,32):
   b.pallet(x-24,z);b.crate(x-24,z,.7);b.drum(x-20,z+4,color='blue')
 for x,z in [(-30,64),(8,65),(43,65)]:shipping_container(b,x,z,'blue' if x<0 else 'red',yaw=90,solid=False,zone='Backdrop')
 forklift(b,-65,30);forklift(b,65,-30)
 b.exterior_building(0,-78,120,32,31,'brick')
 return b.save()

def canal():
 b=Build('CanalWorks',REPO/'maps/team_maps/models/CanalWorks.rbxmx',[138,114]);boundary_services(b,'canal');floor_finish(b,'canal')
 # High pipe run follows each north/south boundary. The supports stay against concrete.
 for n in b.base_parts:
  if pname(n) not in ('Boundary_N','Boundary_S'):continue
  (x,y,z),(w,h,d)=info(n)
  if w<8:continue
  inward=1 if pname(n)=='Boundary_N' else -1
  zz=z+inward*.58
  b.rod('WaterMain',(x-w/2+.3,10.8,zz),(x+w/2-.3,10.8,zz),.25,'green','WaterInfrastructure')
  for xx in range(math.ceil(x-w/2)+2,math.floor(x+w/2),6):b.part('PipeBracket',(xx,10.8,zz),(.13,.6,.28),'steel',zone='WaterInfrastructure')
 # Canal and service paths are beyond the playable complex. Solid boundary prevents entry.
 b.part('UtilityGround',(0,-.55,0),(156,1,250),'concrete','Concrete','Backdrop')
 for xx in (-119,119):b.part('CanalServiceGround',(xx,-.55,0),(38,1,250),'concrete','Concrete','Backdrop')
 for x in (-89,89):
  b.part('CanalWater',(x,-1,0),(19,.2,190),(50,74,68),'SmoothPlastic','CanalBackdrop')
  for dx in (-11,11):b.part('CanalRetainingWall',(x+dx,1,0),(2,6,195),'concrete','Concrete','CanalBackdrop')
  for z in (-75,0,75):
   b.part('MaintenanceBridge',(x,4,z),(25,1.2,7),'steel',zone='CanalBackdrop')
   for zz in (-3.3,3.3):
    b.rod('BridgeHandrail',(x-12,7,z+zz),(x+12,7,z+zz),.12,'steel','CanalBackdrop')
    for dx in (-11,0,11):b.rod('BridgeRailPost',(x+dx,4.6,z+zz),(x+dx,7,z+zz),.10,'steel','CanalBackdrop')
 b.exterior_building(0,-88,110,35,24,'brick')
 for x in (-30,0,30):
  b.rod('PumpSump',(x,0,82),(x,9,82),8,'green','PumpStation')
  b.rod('DischargeRiser',(x,8,82),(x,18,82),1.2,'steel','PumpStation')
  b.rod('DischargePipe',(x,18,82),(x,18,65),1.2,'steel','PumpStation')
  for y in (1,4,8):b.rod('TankFlange',(x,y,82),(x,y+.15,82),8.25,'steel','PumpStation')
  b.pallet(x-7,74);b.drum(x-7,74,.7,'green')
 return b.save()

def metro():
 b=Build('MetroExchange',REPO/'maps/team_maps/models/MetroExchange.rbxmx',[120,96]);boundary_services(b,'metro');floor_finish(b,'metro')
 # A glazed clerestory and repeated beams establish an enclosed transport building.
 for x in (-48,-24,0,24,48):
  b.part('StationRoofGirder',(x,20,0),(.5,1.4,102),'steel',zone='StationRoof')
  for z in (-38,-14,10,34):
   b.part('CeilingLuminaire',(x,19,z),(1.2,.2,7),'white',zone='StationRoof')
   b.fixture((x,18.86,z),(1,.06,6.8),zone='StationRoof',brightness=.8,range=20)
 for x in (-46,46):b.part('StationRoofPanel',(x,21.2,0),(30,.25,104),'cream',zone='StationRoof')
 for z in range(-46,48,8):b.part('SkylightFrame',(0,21.3,z),(62,.16,.12),'steel',zone='StationRoof')
 # Suspended signs are above head height and use actual station naming.
 for x,z,label in [(-20,18,'CONCOURSE A'),(20,30,'PLATFORM ACCESS'),(0,0,'MAINTENANCE'),(32,-22,'CONCOURSE B')]:
  b.sign(label,(x,11,z),(8,1.8,.12),zone='StationWayfinding')
  for dx in (-3,3):b.rod('SignSuspension',(x+dx,12,z),(x+dx,19,z),.06,'steel','StationWayfinding')
 b.part('StationGround',(0,-.2,0),(260,.3,230),'concrete','Concrete','Backdrop')
 # Closed platform tracks behind the arena walls, never active gameplay routes.
 for x in (-87,87):
  for dx in (-2.4,2.4):b.part('Rail',(x+dx,.1,0),(.18,.25,180),'steel',zone='PlatformBackdrop')
  for z in range(-85,90,3):b.part('RailSleeper',(x,-.08,z),(7,.25,.5),'wood','WoodPlanks','PlatformBackdrop')
  b.part('TrainCar',(x,4,10),(10,7,52),'cream',zone='PlatformBackdrop')
  b.part('TrainRoof',(x,7.7,10),(10.3,.5,52),'steel',zone='PlatformBackdrop')
  for zz in (-8,28):
   for side in (-1,1):b.rod('TrainWheel',(x+side*3.7,.8,zz),(x+side*4.5,.8,zz),1.4,'dark','PlatformBackdrop')
  for side in (-1,1):
   b.part('TrainStripe',(x+side*5.05,2.2,10),(.08,.5,51),'blue',zone='PlatformBackdrop')
   for z in (-10,-4,2,8,14,20,26):b.part('TrainWindow',(x+side*5.08,5,z),(.08,2.2,4),'glass',zone='PlatformBackdrop')
 for x in (-36,36):b.exterior_building(x,82,60,32,33,'concrete')
 return b.save()

def skyline():
 b=Build('Skyline',REPO/'maps/team_maps/models/Skyline.rbxmx',[144,96]);boundary_services(b,'skyline');floor_finish(b,'skyline')
 for x,z,w,d in [(-20.5,1.5,19,17),(22.5,1,21,16)]:
  b.roof_equipment(x,z,12,w-3,d-4)
  for side in (-1,1):
   for dz in range(-int(d/2)+2,int(d/2)-1):b.part('PlantLouver',(x+side*(w/2+.08),6,z+dz),(.12,7,.12),'dark',zone='PlantFacades')
  b.sign('MECHANICAL SERVICES',(x,9,z-d/2-.12),(w*.8,1.2,.1),zone='PlantFacades')
  b.rod('RoofDuctRiser',(x,12,z),(x,17,z),1.4,'steel','RoofDucts')
  b.rod('RoofDuctRun',(x,17,z),(x,17,z-12),1.4,'steel','RoofDucts')
 # The enclosing roof belongs to an actual tower: supporting facade extends downward.
 b.part('TowerBelow',(0,-25,0),(146,48,98),'concrete','Concrete','TowerFacade')
 for y in (-6,-15,-24,-33,-42):
  for x in range(-65,68,8):b.part('FacadeGlazing',(x,y,49.08),(5.8,5,.12),'glass',zone='TowerFacade')
  for x in range(-65,68,8):b.part('FacadeGlazing',(x,y,-49.08),(5.8,5,.12),'glass',zone='TowerFacade')
 for x,z,w,d,h in [(-116,-25,42,60,30),(110,20,44,55,44),(-40,-103,55,45,27),(40,100,60,46,33)]:
  b.exterior_building(x,z,w,d,h,'concrete','CityBackdrop')
  b.roof_equipment(x,z,h,w*.45,d*.4)
 for x,z in [(-64,41),(64,-41)]:
  # Antennas are high and rooted behind boundary, not ladders in the arena.
  b.rod('AntennaMast',(x,14,z),(x,36,z),.20,'steel','RoofAntennas')
  for yy in (24,28,32):b.rod('AntennaCrossarm',(x-3,yy,z),(x+3,yy,z),.09,'steel','RoofAntennas')
 return b.save()

def crosscut():
 b=Build('Crosscut',REPO/'maps/team_maps/models/Crosscut.rbxmx',[128,112])
 # Intentionally simple studded arena; no realism pass or added collision.
 for n in b.base_parts:
  if not pname(n).startswith('Wall_'):continue
  (x,y,z),(w,h,d)=info(n)
  if h<10:continue
  b.part('SimpleWallCap',(x,y+h/2+.06,z),(w,.12,d),(105,120,126),'Plastic','SimpleAccents')
 b.part('StuddedBackdropBase',(0,-2.5,0),(168,1,152),(116,132,110),'Plastic','SimpleAccents')
 # Native studs, not thousands of individual cylinders.
 for n in b.addroot.findall(".//Item[@class='Part']"):
  if pname(n)=='StuddedBackdropBase':props(n).find("token[@name='TopSurface']").text='3'
 return b.save()

def testing():
 b=Build('TestingGrounds',REPO/'maps/models/TestingGrounds.rbxmx',[76,68]);floor_finish(b,'training')
 for z in (-12.62,12.62):
  for x in (-10,-2,6,11):
   # Joints are on solid wall intervals only; never bridge the offset door openings.
   if z<0 and -9<x<-3:continue
   if z>0 and 3<x<9:continue
   b.part('ConcreteTieMark',(x,6,z),(.12,.12,.025),'dark',zone='TrainingStructure')
 for z in (-33.9,33.9):
  for x in (-23,0,23):
   b.sign('TRAINING SECTOR '+str(x+24),(x,9,z),(7,1.2,.08),zone='TrainingWayfinding')
 b.part('CompoundGround',(0,-.2,0),(210,.3,190),'concrete','Concrete','Backdrop')
 for x in (-62,62):
  b.exterior_building(x,0,30,100,22,'concrete')
  for z in (-28,0,28):b.pallet(x-18,z);b.crate(x-18,z,.7)
 b.exterior_building(0,-68,90,32,26,'brick')
 for x in (-25,25):shipping_container(b,x,62,'green',yaw=90,solid=False,zone='CompoundStorage')
 for x in (-42,42):
  for z in (-43,43):
   b.rod('CompoundLightPole',(x,0,z),(x,23,z),.25,'steel','CompoundLighting')
   b.part('CompoundLamp',(x,23,z),(2,.5,1),'light',zone='CompoundLighting')
 return b.save()

def pump_house():
 b=Build('PumpHouse',REPO/'maps/models/PumpHouse.rbxmx',[76,68]);floor_finish(b,'pump')
 for x,z in [(-20,-4),(20,4)]:
  for angle in range(0,360,45):
   a=math.radians(angle);xx=x+7.16*math.cos(a);zz=z+7.16*math.sin(a)
   b.rod('TankWeldSeam',(xx,1.5,zz),(xx,12.5,zz),.05,'steel','TankConstruction')
  b.rod('RoofVentRiser',(x,13,z),(x,17,z),.65,'steel','TankConstruction')
  b.rod('VentCap',(x,17,z),(x,17.25,z),1.3,'steel','TankConstruction')
  b.rod('TankHighOutlet',(x,13.6,z),(x,13.6,-35),.7,'green','HighPipelines')
  for zz in (-28,-14,0):b.rod('PipeFlange',(x,13.6,zz-.08),(x,13.6,zz+.08),.95,'steel','HighPipelines')
 b.sign('PUMP CONTROL',(0,8,-6.15),(7,1.3,.12),zone='PumpControls')
 b.panel(0,4.5,-6.12,4,3)
 b.part('WaterworksGround',(0,-.25,0),(220,.4,210),'concrete','Concrete','Backdrop')
 for x in (-65,65):
  b.exterior_building(x,0,30,92,24,'brick')
  for z in (-24,24):b.pallet(x-18,z);b.drum(x-18,z,.7,'green')
 for x in (-25,0,25):
  b.rod('ExternalReservoir',(x,0,-64),(x,22,-64),18,'white','WaterworksBackdrop')
  for yy in (1,11,21):b.rod('ReservoirBand',(x,yy,-64),(x,yy+.2,-64),18.3,'steel','WaterworksBackdrop')
 b.exterior_building(0,67,96,30,23,'brick')
 return b.save()


def dress_existing_cover(b):
 """Furniture skins hug tested low cover; collision volume stays exactly as exported."""
 if b.name in ('ContainerYard','Crosscut'):return
 for n in b.base_parts:
  p=props(n);v=p.find("bool[@name='CanCollide']")
  if v is None or v.text!='true':continue
  (x,y,z),(w,h,d)=info(n)
  if h<2 or h>4 or y-h/2<-.05:continue
  if b.name=='FreightTerminal':
   for side in (-1,1):
    b.part('CargoCrateFacing',(x,y,z+side*(d/2+.035)),(w,h,.06),'wood','WoodPlanks','CoverFurniture')
    for dx in (-w/2+.2,w/2-.2):b.part('CrateStrapping',(x+dx,y,z+side*(d/2+.08)),(.18,h,.04),'steel',zone='CoverFurniture')
   b.part('CargoCrateLid',(x,y+h/2+.035,z),(w,.06,d),'wood','WoodPlanks','CoverFurniture')
  elif b.name in ('Foundry','CanalWorks','Skyline'):
   color='paint' if b.name!='Skyline' else 'white'
   for side in (-1,1):
    b.part('ServiceCabinetSkin',(x,y,z+side*(d/2+.04)),(w,h,.07),color,zone='CoverFurniture')
    for yy in (-h*.3,0,h*.3):
     b.part('DrawerSeam',(x,y+yy,z+side*(d/2+.09)),(w-.3,.035,.035),'dark',zone='CoverFurniture')
     b.part('RecessedDrawerPull',(x,y+yy+.2,z+side*(d/2+.13)),(min(w*.35,1.5),.1,.05),'steel',zone='CoverFurniture')
   for side in (-1,1):b.part('CabinetEnd',(x+side*(w/2+.035),y,z),(.06,h,d),color,zone='CoverFurniture')
   b.part('WorkbenchTop',(x,y+h/2+.045,z),(w+.12,.08,d+.12),'steel',zone='CoverFurniture')
  elif b.name=='MetroExchange':
   for dz in range(-int(d*5)+2,int(d*5),3):
    b.part('BenchTimberSlat',(x,y+h/2+.06,z+dz/10),(w,.10,.22),'wood','WoodPlanks','CoverFurniture')
  else:
   for side in (-1,1):
    for dx in (-w*.35,w*.35):b.part('BarrierTiePoint',(x+dx,y,z+side*(d/2+.025)),(.14,.14,.035),'dark',zone='CoverFurniture')

if __name__=='__main__':
 report=[]
 for f in (foundry,container_yard,freight,canal,metro,skyline,crosscut,testing,pump_house):
  m=f();report.append({k:v for k,v in m.items() if k!='parts'});print(m['name'],m['added_parts'],'added parts')
 (ROOT/'BUILD_REPORT.json').write_text(json.dumps(report,indent=2)+'\n')
