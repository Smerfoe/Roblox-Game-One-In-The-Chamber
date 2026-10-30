"""Build original, editable native-part viewmodel rigs. Standard library only."""
from pathlib import Path
import math
import xml.etree.ElementTree as E

ROOT=Path(__file__).resolve().parents[1]
STEEL=(154,162,167); FRAME=(61,66,70); BLACK=(26,29,31); WOOD=(92,57,39)


def v(parent,kind,name,val):
 n=E.SubElement(parent,kind,name=name);n.text=str(val);return n


def vector(p,name,xyz):
 n=E.SubElement(p,'Vector3',name=name)
 for k,x in zip('XYZ',xyz):E.SubElement(n,k).text=str(x)


def cf(p,name,pos=(0,0,0),rot=(0,0,0)):
 x,y,z=[math.radians(a) for a in rot];cx,sx=math.cos(x),math.sin(x);cy,sy=math.cos(y),math.sin(y);cz,sz=math.cos(z),math.sin(z)
 # Rz * Ry * Rx
 mat=[cz*cy,cz*sy*sx-sz*cx,cz*sy*cx+sz*sx,sz*cy,sz*sy*sx+cz*cx,sz*sy*cx-cz*sx,-sy,cy*sx,cy*cx]
 n=E.SubElement(p,'CoordinateFrame',name=name)
 for k,a in zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],list(pos)+mat):E.SubElement(n,k).text=str(round(a,8))


class Rig:
 def __init__(self,name):
  self.name=name;self.count=0;self.parts=[];self.groups={};self.xml=E.Element('roblox',version='4')
  self.model=E.SubElement(self.xml,'Item',{'class':'Model','referent':name})
  p=E.SubElement(self.model,'Properties');v(p,'string','Name',name)
  self.anchor=self.part('Anchor',(0,0,0),(.05,.05,.05),BLACK,invisible=True,anchored=True,parent=self.model)
  v(p,'Ref','PrimaryPart',self.anchor[1])
  self.group('Body',(0,0,0),'Presentation')

 def part(self,name,pos,size,color,group='Body',rot=(0,0,0),cylinder=False,invisible=False,anchored=False,parent=None,material=1088,wedge=False):
  parent=self.groups[group][0] if parent is None else parent
  self.count+=1;ref=f'{self.name}_{self.count:03d}'
  n=E.SubElement(parent,'Item',{'class':'WedgePart' if wedge else 'Part','referent':ref});p=E.SubElement(n,'Properties')
  v(p,'string','Name',name);vector(p,'size',size);cf(p,'CFrame',pos,rot)
  col=E.SubElement(p,'Color3',name='Color')
  for key,c in zip('RGB',color):E.SubElement(col,key).text=str(c/255)
  for key,val in [('Anchored',anchored),('CanCollide',False),('CanTouch',False),('CanQuery',False),('Massless',True),('CastShadow',False)]:v(p,'bool',key,str(val).lower())
  v(p,'float','Transparency',1 if invisible else 0);v(p,'token','Material',material);
  if not wedge:v(p,'token','shape',2 if cylinder else 1)
  v(p,'token','TopSurface',0);v(p,'token','BottomSurface',0)
  self.parts.append((n,ref,pos,size))
  if not invisible and group in self.groups:
   self.weld(self.groups[group][1],ref,n)
  return n,ref

 def weld(self,root,part,parent):
  n=E.SubElement(parent,'Item',{'class':'WeldConstraint','referent':part+'Weld'});p=E.SubElement(n,'Properties')
  v(p,'string','Name','AssemblyWeld');v(p,'Ref','Part0',root);v(p,'Ref','Part1',part)

 def group(self,name,pivot,motor_name):
  folder=E.SubElement(self.model,'Item',{'class':'Model','referent':self.name+name})
  v(E.SubElement(folder,'Properties'),'string','Name',name)
  node,ref=self.part(name+'Pivot',pivot,(.04,.04,.04),BLACK,invisible=True,parent=folder)
  self.groups[name]=(folder,ref,pivot)
  n=E.SubElement(node,'Item',{'class':'Motor6D','referent':ref+'Joint'});p=E.SubElement(n,'Properties')
  v(p,'string','Name',motor_name);v(p,'Ref','Part0',self.anchor[1] if name=='Body' else self.groups['Body'][1]);v(p,'Ref','Part1',ref)
  cf(p,'C0',pivot);cf(p,'C1');
  return folder

 def rod(self,name,a,b,radius,color,group='Body'):
  # Rod along local X, world direction constrained to YZ plane.
  x=(a[0]+b[0])/2;y=(a[1]+b[1])/2;z=(a[2]+b[2])/2
  dy=b[1]-a[1];dz=b[2]-a[2];length=math.hypot(dy,dz)
  # local X -> (0, cos(theta), sin(theta)) via Rz90 * Rx? use Ry then Rz90
  theta=math.degrees(math.atan2(dz,dy))
  self.part(name,(x,y,z),(length,radius*2,radius*2),color,group,rot=(0,-theta,90),cylinder=True)

 def save(self):
  E.indent(self.xml,space='  ');path=ROOT/'models'/f'{self.name}.rbxmx'
  path.write_bytes(E.tostring(self.xml,encoding='utf-8',xml_declaration=True))
  print(f'{path.name}: {len(self.parts)} parts')


def pistol():
 r=Rig('Service1911_Prototype')
 r.group('Slide',(0,.28,-.48),'Slide')
 r.group('Hammer',(0,.24,.37),'Hammer')
 r.group('Magazine',(0,-.68,.26),'Magazine')
 r.group('Cartridge',(-.65,-.72,.25),'Cartridge')
 # Fixed lower receiver, short dust cover and separate grip panels.
 r.part('Receiver',(0,-.025,-.48),(.40,.26,1.77),FRAME)
 r.part('DustCover',(0,-.14,-.95),(.34,.16,.73),FRAME)
 r.part('GripFrame',(0,-.69,.30),(.37,1.08,.49),FRAME,rot=(-16,0,0))
 for side in (-1,1):
  r.part('SeparateWoodGrip',(side*.205,-.68,.30),(.055,.83,.40),WOOD,rot=(-16,0,0),material=512)
  for y in (-.40,-.94):
   z=.30+(-y-.68)*.287
   r.part('GripScrew',(side*.238,y,z),(.015,.065,.065),STEEL,cylinder=True)
  for j in range(7):
   y=-.42-j*.073;z=.30+(-y-.68)*.287
   r.part('GripCheckering',(side*.237,y,z),(.008,.018,.31),(68,43,31),rot=(-16,0,0),material=512)
 r.part('Beavertail',(0,.11,.41),(.36,.10,.30),FRAME)
 # U-shaped rounded trigger guard surrounding an actual open space.
 for i in range(10):
  t1=math.pi*i/10;t2=math.pi*(i+1)/10
  a=(0,-.17-.41*math.sin(t1),-.18-.31*math.cos(t1))
  b=(0,-.17-.41*math.sin(t2),-.18-.31*math.cos(t2))
  r.rod('RoundedTriggerGuard',a,b,.035,FRAME)
 r.part('Trigger',(0,-.285,-.17),(.15,.22,.07),STEEL,rot=(-14,0,0))
 # Long continuous slide with repeatable rear serrations; no fake attachments.
 r.part('SlideBody',(0,.285,-.54),(.44,.35,1.92),STEEL,'Slide')
 r.part('SlideTopRib',(0,.48,-.54),(.34,.05,1.78),STEEL,'Slide')
 for side in (-1,1):r.part('SlideBevel',(side*.195,.475,-.54),(1.92,.05,.05),STEEL,'Slide',rot=(0,side*90,0),wedge=True)
 for side in (-1,1):
  for j in range(7):
   r.part('RearSlideSerration',(side*.224,.285,.03-j*.055),(.012,.25,.018),(98,106,112),'Slide')
 # Dark recess and metal breech insert are thin surface details, not a floating prop.
 r.part('EjectionPortRecess',(.224,.32,-.57),(.012,.19,.35),BLACK,'Slide')
 r.part('BreechFace',(.232,.30,-.57),(.012,.08,.27),(126,135,142),'Slide')
 r.part('RearSightBase',(0,.53,.26),(.36,.06,.15),BLACK,'Slide')
 for side in (-1,1):r.part('RearSightEar',(side*.12,.59,.26),(.09,.08,.12),BLACK,'Slide')
 r.part('FrontSight',(0,.555,-1.33),(.06,.10,.10),BLACK,'Slide')
 # Cylinders along Z, tiny darker muzzle inset to read as a bore, not a second barrel.
 r.part('Barrel',(0,.26,-1.50),(.10,.21,.21),(118,126,132),rot=(0,90,0),cylinder=True)
 r.part('Bore',(0,.26,-1.556),(.014,.125,.125),BLACK,rot=(0,90,0),cylinder=True)
 r.part('RecoilPlug',(0,-.01,-1.39),(.035,.13,.13),(115,123,130),rot=(0,90,0),cylinder=True)
 r.part('HammerSpur',(0,.32,.46),(.15,.12,.19),(101,110,117),'Hammer',rot=(-24,0,0))
 r.part('HammerStem',(0,.24,.40),(.14,.20,.10),FRAME,'Hammer')
 r.part('MagazineBody',(0,-.70,.30),(.29,.91,.35),(77,84,90),'Magazine',rot=(-16,0,0))
 r.part('MagazineBase',(0,-1.20,.45),(.40,.07,.48),BLACK,'Magazine',rot=(-16,0,0))
 # One prop cartridge is shown only during Reload presentation.
 r.part('SingleCartridge',(-.65,-.72,.25),(.22,.09,.09),(165,130,61),'Cartridge',rot=(0,90,0),cylinder=True)
 r.part('CartridgeTip',(-.65,-.72,.12),(.05,.08,.08),(159,112,74),'Cartridge',rot=(0,90,0),cylinder=True)
 r.save()


def knife():
 r=Rig('Karambit_Prototype')
 r.part('GripCore',(0,-.05,.10),(.17,.67,.23),BLACK,rot=(-12,0,0))
 for side in (-1,1):
  r.part('GripScale',(side*.10,-.04,.10),(.045,.56,.20),(56,61,65),rot=(-12,0,0))
  for j in range(5):r.part('GripRidge',(side*.126,.14-j*.09,.10),(.012,.025,.19),(37,42,46),rot=(-12,0,0))
 for y in (-.23,.15):r.part('ScalePin',(0,y,.10),(.25,.055,.055),STEEL,cylinder=True)
 # Finger ring uses continuous small segments, with an actual central opening.
 center_y=-.59;center_z=.19;radius=.205
 for i in range(20):
  a=2*math.pi*i/20;b=2*math.pi*(i+1)/20
  r.rod('FingerRing',(0,center_y+radius*math.cos(a),center_z+radius*math.sin(a)),(0,center_y+radius*math.cos(b),center_z+radius*math.sin(b)),.035,STEEL)
 # A continuous hooked profile, triangulated into exact wedge prisms.
 # Both sides share the same contour: no separated rectangular blade facets.
 outer=[(.27,-.02),(.44,-.09),(.59,-.20),(.71,-.35),(.78,-.52),(.80,-.70),(.77,-.88)]
 inner=[(.28,.16),(.50,.10),(.71,-.01),(.89,-.18),(1.00,-.40),(.98,-.65),(.77,-.88)]
 def triangle(a,b,c):
  # Split longest triangle edge at its perpendicular foot, yielding right wedges.
  pts=[a,b,c]
  pairs=[(0,1,2),(1,2,0),(2,0,1)]
  i,j,k=max(pairs,key=lambda t:(pts[t[0]][0]-pts[t[1]][0])**2+(pts[t[0]][1]-pts[t[1]][1])**2)
  A,B,C=pts[i],pts[j],pts[k];dy=B[0]-A[0];dz=B[1]-A[1];l2=dy*dy+dz*dz
  t=((C[0]-A[0])*dy+(C[1]-A[1])*dz)/l2
  D=(A[0]+t*dy,A[1]+t*dz);h=math.hypot(C[0]-D[0],C[1]-D[1])
  if h<1e-7:return
  ey=((C[0]-D[0])/h,(C[1]-D[1])/h)
  for P in (A,B):
   length=math.hypot(D[0]-P[0],D[1]-P[1])
   if length<1e-7:continue
   ez=((D[0]-P[0])/length,(D[1]-P[1])/length)
   ex=ey[0]*ez[1]-ey[1]*ez[0]
   y=D[0]+ey[0]*h/2-ez[0]*length/2;z=D[1]+ey[1]*h/2-ez[1]*length/2
   n,_=r.part('ContinuousBlade',(0,y,z),(.09,h,length),STEEL,wedge=True)
   frame=n.find("Properties/CoordinateFrame[@name='CFrame']")
   matrix=[ex,0,0, 0,ey[0],ez[0], 0,ey[1],ez[1]]
   for key,value in zip(['R00','R01','R02','R10','R11','R12','R20','R21','R22'],matrix):frame.find(key).text=str(round(value,8))
 for i in range(len(outer)-1):
  triangle(outer[i],inner[i],outer[i+1]);triangle(inner[i],inner[i+1],outer[i+1])
 r.save()


def blade_strip(r,outer,inner,thickness=.08,color=STEEL):
 """Triangulate a continuous Y/Z profile into exact nonoverlapping right wedges."""
 def triangle(a,b,c):
  pts=[a,b,c];pairs=[(0,1,2),(1,2,0),(2,0,1)]
  i,j,k=max(pairs,key=lambda t:sum((pts[t[0]][q]-pts[t[1]][q])**2 for q in (0,1)))
  A,B,C=pts[i],pts[j],pts[k];dy=B[0]-A[0];dz=B[1]-A[1];length2=dy*dy+dz*dz
  if length2<1e-10:return
  t=((C[0]-A[0])*dy+(C[1]-A[1])*dz)/length2;D=(A[0]+t*dy,A[1]+t*dz)
  h=math.hypot(C[0]-D[0],C[1]-D[1])
  if h<1e-7:return
  ey=((C[0]-D[0])/h,(C[1]-D[1])/h)
  for P in (A,B):
   length=math.hypot(D[0]-P[0],D[1]-P[1])
   if length<1e-7:continue
   ez=((D[0]-P[0])/length,(D[1]-P[1])/length);ex=ey[0]*ez[1]-ey[1]*ez[0]
   y=D[0]+ey[0]*h/2-ez[0]*length/2;z=D[1]+ey[1]*h/2-ez[1]*length/2
   n,_=r.part('BladeSurface',(0,y,z),(thickness,h,length),color,wedge=True)
   frame=n.find("Properties/CoordinateFrame[@name='CFrame']")
   for key,val in zip(['R00','R01','R02','R10','R11','R12','R20','R21','R22'],[ex,0,0,0,ey[0],ez[0],0,ey[1],ez[1]]):frame.find(key).text=str(round(val,8))
 for i in range(len(outer)-1):
  triangle(outer[i],inner[i],outer[i+1]);triangle(inner[i],inner[i+1],outer[i+1])


def revolver():
 r=Rig('PythonMagnum_Prototype')
 r.group('Cylinder',(-.18,-.12,.08),'Cylinder')
 r.group('Hammer',(0,.30,.42),'Hammer')
 r.group('Cartridge',(-.85,.10,.85),'Cartridge')
 silver=(169,176,181)
 # Open frame window with continuous top strap; cylinder fills window at rest.
 r.part('LowerFrame',(0,-.15,-.16),(.29,.20,.91),silver)
 r.part('TopStrap',(0,.52,-.16),(.30,.12,.98),silver)
 r.part('FrontFrame',(0,.18,-.59),(.30,.65,.12),silver)
 r.part('RearFrame',(0,.13,.32),(.29,.63,.14),silver)
 # A long fixed barrel, underlug and vented rib, not a pistol slide.
 r.part('LongBarrel',(0,.30,-1.58),(1.90,.29,.29),silver,rot=(0,90,0),cylinder=True)
 r.part('FullUnderlug',(0,.09,-1.58),(.27,.22,1.90),silver)
 r.part('VentRibTop',(0,.57,-1.58),(.20,.055,1.92),silver)
 for z in (-.75,-1.06,-1.37,-1.68,-1.99,-2.30):
  r.part('VentRibBridge',(0,.49,z),(.18,.14,.09),silver)
 r.part('MuzzleFace',(0,.30,-2.54),(.025,.30,.30),silver,rot=(0,90,0),cylinder=True)
 r.part('MuzzleBore',(0,.30,-2.556),(.012,.16,.16),BLACK,rot=(0,90,0),cylinder=True)
 r.part('FrontSight',(0,.64,-2.35),(.065,.12,.15),BLACK)
 r.part('RearSight',(0,.62,.20),(.24,.08,.15),BLACK)
 # The cylinder/crane is one articulated assembly. The six chamber discs are
 # native-part recess illustrations, not real CSG bores or six loaded rounds.
 r.part('CylinderShell',(0,.16,-.12),(.62,.62,.62),silver,'Cylinder',rot=(0,90,0),cylinder=True)
 for i in range(6):
  angle=2*math.pi*i/6;x=.17*math.cos(angle);y=.16+.17*math.sin(angle)
  r.part('EmptyChamberRecess',(x,y,.198),(.012,.10,.10),BLACK,'Cylinder',rot=(0,90,0),cylinder=True)
  # Long thin flat flute accents sit tangent to the shell on each side.
  x=.302*math.cos(angle);y=.16+.302*math.sin(angle)
  r.part('CylinderFlute',(x,y,-.12),(.012,.075,.42),(110,120,128),'Cylinder',rot=(0,0,math.degrees(angle)),material=1088)
 r.part('CraneArm',(-.14,-.08,-.12),(.12,.10,.64),silver,'Cylinder')
 r.part('CranePivotCap',(-.185,-.12,.08),(.08,.10,.10),FRAME,'Cylinder',cylinder=True)
 r.part('ExtractorRod',(0,.16,-.54),(.20,.06,.06),silver,'Cylinder',rot=(0,90,0),cylinder=True)
 r.part('CylinderRelease',(.166,.15,.27),(.045,.13,.18),FRAME)
 r.part('HammerBody',(0,.33,.43),(.13,.22,.12),FRAME,'Hammer')
 r.part('HammerSpur',(0,.46,.49),(.18,.09,.22),silver,'Hammer',rot=(-22,0,0))
 r.part('GripTang',(0,-.61,.42),(.26,.95,.40),silver,rot=(-19,0,0))
 for side in (-1,1):
  r.part('WalnutGrip',(side*.16,-.61,.45),(.10,.87,.43),WOOD,rot=(-19,0,0),material=512)
  r.part('GripMedallion',(side*.217,-.48,.40),(.018,.10,.10),(152,132,83),cylinder=True)
  for j in range(6):r.part('GripCheckering',(side*.216,-.50-j*.065,.46+j*.022),(.009,.012,.30),(63,41,30),rot=(-19,0,0),material=512)
 # Trigger guard curve in the Y/Z plane, with open interior.
 for i in range(12):
  a=math.pi*i/12;b=math.pi*(i+1)/12
  r.rod('RoundedTriggerGuard',(0,-.22-.31*math.sin(a),-.07-.27*math.cos(a)),(0,-.22-.31*math.sin(b),-.07-.27*math.cos(b)),.032,silver)
 r.part('Trigger',(0,-.31,-.05),(.10,.20,.055),silver,rot=(-18,0,0))
 r.part('SingleCartridge',(-.85,.10,.85),(.28,.09,.09),(168,132,62),'Cartridge',rot=(0,90,0),cylinder=True)
 r.part('CartridgeTip',(-.85,.10,.68),(.055,.08,.08),(155,108,68),'Cartridge',rot=(0,90,0),cylinder=True)
 r.save()


def machete():
 r=Rig('Machete_Prototype')
 r.part('FullTang',(0,-.15,.05),(.11,.93,.30),FRAME)
 for side in (-1,1):
  r.part('HandleScale',(side*.085,-.17,.05),(.07,.81,.28),(63,66,55))
 for y in (-.45,-.10,.20):r.part('HandleRivet',(0,y,.05),(.20,.065,.065),(124,130,125),cylinder=True)
 r.part('GuardStop',(0,.31,.03),(.20,.065,.46),FRAME)
 outer=[(.31,-.12),(.75,-.15),(1.30,-.20),(1.85,-.28),(2.12,-.39),(2.27,-.54)]
 inner=[(.31,.21),(.75,.25),(1.30,.27),(1.85,.22),(2.12,.07),(2.27,-.54)]
 blade_strip(r,outer,inner,.07,(147,151,145))
 r.save()


def butter_knife():
 r=Rig('ButterKnife_Prototype');silver=(182,187,189)
 r.part('FlatHandle',(0,-.29,.04),(.07,.85,.19),silver)
 r.part('RoundedHandleEnd',(0,-.72,.04),(.07,.18,.19),silver,cylinder=True)
 r.part('HandleNeck',(0,.20,.02),(.065,.22,.16),silver)
 # Deliberately rounded table-knife silhouette, not a butterfly knife.
 outer=[(.28,-.07),(.50,-.13),(.92,-.16),(1.17,-.15),(1.28,-.11),(1.32,-.02)]
 inner=[(.28,.11),(.50,.16),(.92,.17),(1.17,.15),(1.28,.09),(1.32,-.02)]
 blade_strip(r,outer,inner,.055,silver)
 r.save()


def repeater():
 r=Rig('FrontierRepeater_Prototype');iron=(75,77,73);wood=(79,49,31)
 r.group('Lever',(0,-.17,-.16),'Lever')
 r.group('Breech',(0,.18,-.16),'Breech')
 r.group('Hammer',(0,.25,.36),'Hammer')
 r.group('Cartridge',(-.7,-.05,.60),'Cartridge')
 r.part('Receiver',(0,.08,-.20),(.36,.52,.88),iron)
 r.part('ReceiverTop',(0,.37,-.20),(.30,.06,.88),FRAME)
 for side in (-1,1):
  r.part('ReceiverInset',(side*.184,.08,-.20),(.012,.31,.56),(58,60,57))
  for z in (-.46,.05):r.part('FrameScrew',(side*.195,.07,z),(.012,.06,.06),(125,124,112),cylinder=True)
 r.part('LoadingPortRecess',(.195,.16,-.12),(.012,.12,.31),BLACK)
 r.part('BreechBlock',(0,.405,-.20),(.22,.02,.40),(130,131,121),'Breech')
 r.part('Barrel',(0,.27,-2.10),(2.96,.19,.19),iron,rot=(0,90,0),cylinder=True)
 r.part('MuzzleRim',(0,.27,-3.595),(.025,.20,.20),iron,rot=(0,90,0),cylinder=True)
 r.part('Bore',(0,.27,-3.611),(.012,.11,.11),BLACK,rot=(0,90,0),cylinder=True)
 r.part('MagazineTube',(0,.02,-2.05),(2.85,.12,.12),iron,rot=(0,90,0),cylinder=True)
 r.part('ForeEndWood',(0,-.01,-1.20),(.30,.27,1.12),wood,material=512)
 for z in (-.73,-1.65):r.part('ForeEndBand',(0,.06,z),(.33,.34,.06),(95,96,85))
 r.part('FrontSight',(0,.415,-3.44),(.055,.11,.10),BLACK)
 r.part('RearSightLeaf',(0,.41,-.84),(.20,.04,.25),BLACK)
 for side in (-1,1):r.part('RearSightEar',(side*.075,.45,-.91),(.04,.06,.08),BLACK)
 # Side profile stock is a continuous wedge-prism surface, not floating blocks.
 blade_strip(r,[(.19,.25),(.08,.65),(-.09,1.15),(-.18,1.78)],
                [(-.19,.25),(-.30,.65),(-.67,1.15),(-.79,1.78)],.31,wood)
 r.part('ButtPlate',(0,-.48,1.81),(.33,.63,.055),(105,106,98),rot=(-8,0,0))
 for y in (-.25,-.69):r.part('ButtPlateScrew',(0,y,1.85),(.055,.055,.012),BLACK)
 # Distinct articulated oval lever; stays separate from trigger and receiver.
 for i in range(16):
  a=2*math.pi*i/16;b=2*math.pi*(i+1)/16
  r.rod('LeverLoop',(0,-.36+.18*math.cos(a),.04+.30*math.sin(a)),
        (0,-.36+.18*math.cos(b),.04+.30*math.sin(b)),.028,iron,'Lever')
 r.rod('LeverNeck',(0,-.17,-.16),(0,-.29,-.19),.032,iron,'Lever')
 r.part('Trigger',(0,-.22,.02),(.08,.20,.045),(105,106,99))
 r.part('HammerStem',(0,.28,.34),(.11,.19,.11),iron,'Hammer')
 r.part('HammerSpur',(0,.40,.39),(.16,.065,.19),iron,'Hammer',rot=(-20,0,0))
 r.part('SingleCartridge',(-.7,-.05,.60),(.32,.085,.085),(164,128,65),'Cartridge',rot=(0,90,0),cylinder=True)
 r.part('CartridgeTip',(-.7,-.05,.41),(.055,.075,.075),(151,106,64),'Cartridge',rot=(0,90,0),cylinder=True)
 r.save()


def old_west():
 r=Rig('OldWestRevolver_Prototype');brass=(169,145,79);ivory=(205,195,157);iron=(85,84,74)
 r.group('Cylinder', (0,.12,-.11), 'Cylinder')
 r.group('LoadingGate',(.29,.12,.22),'LoadingGate')
 r.group('Hammer',(0,.29,.36),'Hammer')
 r.group('Cartridge',(.78,.12,.81),'Cartridge')
 r.part('LowerFrame',(0,-.17,-.08),(.28,.17,.86),brass)
 r.part('RearFrame',(0,.13,.28),(.27,.63,.12),brass)
 r.part('TopStrap',(0,.49,-.11),(.26,.12,.92),brass)
 r.part('FrontFrame',(0,.13,-.52),(.28,.65,.11),brass)
 r.part('Barrel',(0,.28,-1.35),(1.64,.24,.24),brass,rot=(0,90,0),cylinder=True)
 r.part('MuzzleRim',(0,.28,-2.18),(.026,.25,.25),brass,rot=(0,90,0),cylinder=True)
 r.part('MuzzleBore',(0,.28,-2.198),(.012,.13,.13),BLACK,rot=(0,90,0),cylinder=True)
 r.part('EjectorHousing',(.13,.10,-1.24),(1.36,.085,.085),brass,rot=(0,90,0),cylinder=True)
 r.part('FrontBladeSight',(0,.455,-2.04),(.05,.12,.15),iron)
 for side in (-1,1):r.part('RearNotchEar',(side*.08,.565,.26),(.04,.06,.10),iron)
 r.part('CylinderShell',(0,.12,-.11),(.59,.57,.57),iron,'Cylinder',rot=(0,90,0),cylinder=True)
 for i in range(6):
  angle=2*math.pi*i/6
  r.part('CylinderFlute',(.277*math.cos(angle),.12+.277*math.sin(angle),-.11),(.01,.08,.37),(118,117,103),'Cylinder',rot=(0,0,math.degrees(angle)))
  r.part('EmptyChamberRecess',(.16*math.cos(angle),.12+.16*math.sin(angle),.192),(.012,.09,.09),BLACK,'Cylinder',rot=(0,90,0),cylinder=True)
 r.part('GatePlate',(.20,.12,.212),(.16,.23,.035),brass,'LoadingGate')
 r.part('GateTab',(.29,.23,.212),(.10,.045,.07),brass,'LoadingGate')
 r.part('GripTang',(0,-.61,.39),(.20,.94,.36),brass,rot=(-19,0,0))
 for side in (-1,1):
  r.part('IvoryGrip',(side*.14,-.61,.42),(.085,.85,.39),ivory,rot=(-19,0,0),material=272)
  r.part('GripScrew',(side*.19,-.66,.43),(.014,.065,.065),iron,cylinder=True)
  # Restrained horizontal grip texture is authored, not a copied eagle insignia.
  for j in range(7):r.part('GripFineLine',(side*.187,-.40-j*.07,.36+j*.024),(.006,.008,.24),(179,170,134),rot=(-19,0,0),material=272)
 for i in range(12):
  a=math.pi*i/12;b=math.pi*(i+1)/12
  r.rod('TriggerGuard',(0,-.24-.29*math.sin(a),-.03-.25*math.cos(a)),
        (0,-.24-.29*math.sin(b),-.03-.25*math.cos(b)),.027,brass)
 r.part('Trigger',(0,-.32,-.02),(.08,.19,.045),iron,rot=(-17,0,0))
 r.part('HammerStem',(0,.33,.38),(.11,.23,.10),iron,'Hammer')
 r.part('HammerSpur',(0,.46,.43),(.16,.07,.19),iron,'Hammer',rot=(-20,0,0))
 r.part('SingleCartridge',(.78,.12,.81),(.25,.085,.085),(163,125,61),'Cartridge',rot=(0,90,0),cylinder=True)
 r.part('CartridgeTip',(.78,.12,.66),(.05,.075,.075),(148,102,63),'Cartridge',rot=(0,90,0),cylinder=True)
 r.save()


def heavy_pistol():
 r=Rig('HeavyEagle_Prototype');silver=(167,172,175);dark=(53,57,59)
 r.group('Slide',(0,.30,-.25),'Slide')
 r.group('Hammer',(0,.28,.45),'Hammer')
 r.group('Magazine',(0,-.72,.32),'Magazine')
 r.group('Cartridge',(-.68,-.70,.28),'Cartridge')
 r.part('Receiver',(0,-.07,-.46),(.48,.25,1.95),dark)
 r.part('GripFrame',(0,-.73,.34),(.45,1.15,.58),dark,rot=(-14,0,0))
 for side in (-1,1):
  r.part('GripPanel',(side*.25,-.73,.34),(.055,.99,.49),BLACK,rot=(-14,0,0),material=272)
  for j in range(8):r.part('GripRidge',(side*.28,-.43-j*.078,.29+j*.019),(.008,.02,.38),(42,45,47),rot=(-14,0,0),material=272)
  for y,z in [(-.43,.27),(-1.03,.42)]:r.part('GripScrew',(side*.284,y,z),(.015,.07,.07),(99,104,107),cylinder=True)
 # Fixed barrel shroud/front sights are separate from the rear-moving slide.
 r.part('FixedBarrelShroud',(0,.30,-1.28),(.52,.40,1.14),silver)
 r.part('ShroudTopRib',(0,.525,-1.28),(.32,.05,1.10),silver)
 r.part('RearSlide',(0,.30,-.19),(.54,.39,1.06),silver,'Slide')
 for side in (-1,1):
  for j in range(7):r.part('SlideSerration',(side*.274,.30,.17-j*.07),(.012,.29,.025),(99,106,110),'Slide',rot=(14,0,0))
 r.part('EjectionRecess',(.276,.35,-.35),(.012,.16,.34),BLACK,'Slide')
 r.part('RearSightBase',(0,.54,.20),(.35,.06,.16),BLACK,'Slide')
 for side in (-1,1):r.part('RearSightEar',(side*.12,.60,.20),(.085,.08,.12),BLACK,'Slide')
 r.part('FrontSight',(0,.60,-1.69),(.065,.12,.13),BLACK)
 r.part('BarrelMouth',(0,.30,-1.865),(.04,.25,.25),(118,125,130),rot=(0,90,0),cylinder=True)
 r.part('Bore',(0,.30,-1.89),(.012,.15,.15),BLACK,rot=(0,90,0),cylinder=True)
 for z in (-1.65,-1.44,-1.23,-1.02):r.part('TopRailLand',(0,.566,z),(.30,.03,.07),silver)
 for z in (-1.65,-1.45,-1.25,-1.05,-.85):r.part('UnderRailLand',(0,-.235,z),(.40,.05,.07),dark)
 r.part('Beavertail',(0,.08,.52),(.40,.10,.30),dark)
 for i in range(10):
  a=math.pi*i/10;b=math.pi*(i+1)/10
  r.rod('TriggerGuard',(0,-.20-.37*math.sin(a),-.13-.32*math.cos(a)),(0,-.20-.37*math.sin(b),-.13-.32*math.cos(b)),.035,dark)
 r.part('Trigger',(0,-.30,-.11),(.14,.20,.065),silver,rot=(-15,0,0))
 r.part('HammerStem',(0,.31,.45),(.15,.22,.12),dark,'Hammer')
 r.part('HammerSpur',(0,.43,.50),(.19,.075,.19),dark,'Hammer',rot=(-20,0,0))
 r.part('MagazineBody',(0,-.73,.34),(.35,1.01,.43),(77,84,88),'Magazine',rot=(-14,0,0))
 r.part('MagazineBase',(0,-1.29,.48),(.49,.08,.56),BLACK,'Magazine',rot=(-14,0,0))
 r.part('SingleCartridge',(-.68,-.70,.28),(.25,.10,.10),(163,127,62),'Cartridge',rot=(0,90,0),cylinder=True)
 r.part('CartridgeTip',(-.68,-.70,.13),(.05,.085,.085),(148,104,65),'Cartridge',rot=(0,90,0),cylinder=True)
 r.save()


def butterfly():
 r=Rig('ButterflyKnife_Prototype');dark=(43,49,53);blue=(53,109,139)
 r.group('HandleA',(0,.04,-.11),'HandleA');r.group('HandleB',(0,.04,.11),'HandleB')
 outer=[(.08,-.11),(.50,-.16),(.95,-.20),(1.32,-.20),(1.60,-.11)]
 inner=[(.08,.12),(.50,.14),(.95,.13),(1.32,.06),(1.60,-.11)]
 blade_strip(r,outer,inner,.07,(151,158,161))
 for z,group in [(-.11,'HandleA'),(.11,'HandleB')]:
  r.part('HandleSpine',(0,-.53,z),(.16,1.14,.15),dark,group)
  for side in (-1,1):
   r.part('InsetPanel',(side*.086,-.53,z),(.012,.88,.09),blue,group,material=272)
  for y in (-.19,-.85):r.part('HandleFastener',(0,y,z),(.18,.045,.045),(153,161,165),group,cylinder=True)
  r.part('HingePin',(0,.04,z),(.19,.10,.10),(167,174,177),group,cylinder=True)
  r.part('HandleEnd',(0,-1.12,z),(.17,.06,.16),dark,group)
 r.part('Latch',(0,-1.19,.11),(.07,.14,.06),(119,126,131),'HandleB')
 r.save()


def bowie():
 r=Rig('TrailBowie_Prototype');iron=(48,54,58);silver=(158,164,166)
 r.part('CylindricalGrip',(0,-.28,.03),(.93,.28,.28),BLACK,rot=(0,0,90),cylinder=True)
 for y in (-.65,-.54,-.43,-.32,-.21,-.10,.01,.12):
  r.part('GripRing',(0,y,.03),(.035,.296,.296),(38,43,46),rot=(0,0,90),cylinder=True)
 r.part('Pommel',(0,-.80,.03),(.12,.32,.32),silver,rot=(0,0,90),cylinder=True)
 r.part('CrossGuard',(0,.24,0),(.18,.075,.65),iron)
 outer=[(.28,-.20),(.75,-.22),(1.35,-.23),(1.85,-.24),(2.22,-.31)]
 inner=[(.28,.23),(.75,.23),(1.35,.23),(1.85,.18),(2.22,-.31)]
 blade_strip(r,outer,inner,.075,iron)
 # Narrow exposed edge follows the blade, with no added collision/hit region.
 edge=[(y,z+.055) for y,z in outer];edge[-1]=outer[-1]
 blade_strip(r,outer,edge,.079,silver)
 for j in range(9):
  y=.39+j*.13
  blade_strip(r,[(y,.23),(y+.06,.31),(y+.12,.23)],[(y,.23),(y+.06,.23),(y+.12,.23)],.075,silver)
 r.save()


if __name__=='__main__':
 (ROOT/'models').mkdir(exist_ok=True);pistol();knife();revolver();machete();butter_knife();repeater();old_west();heavy_pistol();butterfly();bowie()
