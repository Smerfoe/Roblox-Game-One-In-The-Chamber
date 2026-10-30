"""Appearance-only Eclipse study: no geometry, joint, timing or game-state changes."""
from pathlib import Path
import xml.etree.ElementTree as E
import hashlib
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'models/PythonMagnum_Prototype.rbxmx'
OUTPUT=ROOT/'skins/PythonEclipse_MaterialStudy.rbxmx'
source=E.parse(SOURCE);root=source.getroot();model=root.find('Item')
old=model.get('referent');new='PythonEclipse_MaterialStudy'
model.find("Properties/string[@name='Name']").text=new
# Rename all referents and matching Ref values so both models can coexist.
refs={n.get('referent'):n.get('referent').replace(old,new,1) for n in root.findall('.//Item')}
for node in root.findall('.//Item'):node.set('referent',refs[node.get('referent')])
for ref in root.findall('.//Ref'):
 if ref.text in refs:ref.text=refs[ref.text]
changed=0
for node in root.findall(".//Item[@class='Part']"):
 p=node.find('Properties');name=p.find("string[@name='Name']").text
 if float(p.find("float[@name='Transparency']").text)==1 or name in ('SingleCartridge','CartridgeTip'):continue
 color=(31,36,41);reflectance=.07;material=1088
 if name in ('FrontSight','RearSight','MuzzleBore','EmptyChamberRecess'):
  color=(26,29,31);reflectance=0;material=272
 elif name=='WalnutGrip':color=(25,28,30);reflectance=0;material=272
 elif name=='GripCheckering':color=(43,46,47);reflectance=0;material=272
 elif name in ('GripMedallion','CranePivotCap'):color=(185,155,82);reflectance=.10
 elif name=='CylinderFlute':color=(117,107,73);reflectance=.04
 elif name=='VentRibTop':color=(50,54,57);reflectance=.07
 elif name in ('HammerBody','CylinderRelease','HammerSpur'):color=(70,76,80);reflectance=.04
 for k,n in zip('RGB',color):p.find(f"Color3[@name='Color']/{k}").text=str(n/255)
 p.find("token[@name='Material']").text=str(material)
 node=p.find("float[@name='Reflectance']")
 if node is None:node=E.SubElement(p,'float',name='Reflectance')
 node.text=str(reflectance)
 changed+=1
folder=E.SubElement(model,'Item',{'class':'Folder','referent':new+'StudyMetadata'})
p=E.SubElement(folder,'Properties');E.SubElement(p,'string',name='Name').text='MaterialStudyMetadata'
for name,value in [('Status','Color/material study only; no engraving or unlock'),('SourceSHA256',hashlib.sha256(SOURCE.read_bytes()).hexdigest()),('ProposedSkinId','python.eclipse')]:
 n=E.SubElement(folder,'Item',{'class':'StringValue','referent':new+name});p=E.SubElement(n,'Properties')
 E.SubElement(p,'string',name='Name').text=name;E.SubElement(p,'string',name='Value').text=value
E.indent(root,space='  ');OUTPUT.write_bytes(E.tostring(root,encoding='utf-8',xml_declaration=True))
print(f'Built {OUTPUT.name}; {changed} visible parts recolored; zero geometry changes.')
