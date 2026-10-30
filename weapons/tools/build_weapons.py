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


if __name__=='__main__':
 (ROOT/'models').mkdir(exist_ok=True);pistol();knife();revolver();machete();butter_knife()
