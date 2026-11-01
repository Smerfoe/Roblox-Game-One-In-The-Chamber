"""Produce reviewable Roblox import models locally. Never connects to Studio."""
from pathlib import Path
import re, xml.etree.ElementTree as E
root=Path(__file__).resolve().parents[1]
names=('Catalog','Schema','Transactions','Coordinator','RequestRouter','OwnerAdapter')
target=root/'studio'
target.mkdir(exist_ok=True)
pack=E.Element('roblox',version='4')
folder=E.SubElement(pack,'Item',{'class':'Folder','referent':'PersistentArmoryCandidate'})
properties=E.SubElement(folder,'Properties')
E.SubElement(properties,'string',name='Name').text='PersistentArmoryCandidate'
for name in names:
    text=(root/(name+'.luau')).read_text(encoding='utf8')
    text=re.sub(r'require\("\./(\w+)"\)',r'require(script.Parent.\1)',text)
    (target/(name+'.luau')).write_text(text,encoding='utf8')
    item=E.SubElement(folder,'Item',{'class':'ModuleScript','referent':name})
    props=E.SubElement(item,'Properties')
    E.SubElement(props,'string',name='Name').text=name
    E.SubElement(props,'ProtectedString',name='Source').text=text
E.indent(pack)
E.ElementTree(pack).write(target/'PersistentArmoryCandidate.rbxmx',encoding='utf-8',xml_declaration=True)
print('Built inert review-only package with',len(names),'ModuleScripts; no auto-start scripts')
