"""Build importable Studio folder and LocalScript; source kept readable alongside."""
from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as E
ROOT=Path(__file__).resolve().parents[1]
def named(node,name):
 p=E.SubElement(node,'Properties');E.SubElement(p,'string',name='Name').text=name;return p
root=E.Element('roblox',version='4')
folder=E.SubElement(root,'Item',{'class':'Folder','referent':'WeaponPreviewPack'});named(folder,'WeaponPreviewPack')
for path in sorted((ROOT/'models').glob('*.rbxmx')):
 folder.append(deepcopy(E.parse(path).getroot().find('Item')))
module=E.SubElement(folder,'Item',{'class':'ModuleScript','referent':'WeaponAnimatorModule'})
p=named(module,'WeaponAnimator');E.SubElement(p,'ProtectedString',name='Source').text=(ROOT/'animations'/'WeaponAnimator.luau').read_text()
E.indent(root,space='  ');(ROOT/'WeaponPreviewPack.rbxmx').write_bytes(E.tostring(root,encoding='utf-8',xml_declaration=True))
root=E.Element('roblox',version='4');script=E.SubElement(root,'Item',{'class':'LocalScript','referent':'WeaponPreviewClient'})
p=named(script,'WeaponPreviewClient');E.SubElement(p,'bool',name='Disabled').text='false'
E.SubElement(p,'ProtectedString',name='Source').text=(ROOT/'Preview.client.luau').read_text()
E.indent(root,space='  ');(ROOT/'WeaponPreviewClient.rbxmx').write_bytes(E.tostring(root,encoding='utf-8',xml_declaration=True))
print('Packaged importable preview folder and Studio-only LocalScript.')
