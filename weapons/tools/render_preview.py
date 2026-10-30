"""Optional matplotlib geometry preview; this is NOT a Studio render."""
from pathlib import Path
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/oitc-matplotlib')
import math
import sys
import xml.etree.ElementTree as E
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
ROOT=Path(__file__).resolve().parents[1]
expanded='--new' in sys.argv
items=([('PythonMagnum_Prototype','PYTHON-STYLE MAGNUM'),('Machete_Prototype','MACHETE'),('ButterKnife_Prototype','BUTTER KNIFE')] if expanded else [('Service1911_Prototype','SERVICE 1911'),('Karambit_Prototype','KARAMBIT')])
fig=plt.figure(figsize=(18 if expanded else 14,6),facecolor='#1c2228')
for idx,(name,label) in enumerate(items,1):
 ax=fig.add_subplot(1,len(items),idx,projection='3d');ax.set_facecolor('#1c2228')
 for p in [n.find('Properties') for n in E.parse(ROOT/'models'/f'{name}.rbxmx').findall('.//Item') if n.get('class') in ('Part','WedgePart')]:
  if float(p.find("float[@name='Transparency']").text)==1:continue
  if p.find("string[@name='Name']").text in ('SingleCartridge','CartridgeTip'):continue
  size=np.array([float(p.find(f"Vector3[@name='size']/{a}").text) for a in 'XYZ'])
  cf=p.find("CoordinateFrame[@name='CFrame']")
  pos=np.array([float(cf.find(a).text) for a in 'XYZ']);mat=np.array([[float(cf.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)])
  color=np.array([float(p.find(f"Color3[@name='Color']/{a}").text) for a in 'RGB'])
  faces=[]
  if p.find("token[@name='shape']") is None:
   vertices=[np.array([x,y,z])*size/2 for x in (-1,1) for y,z in [(-1,-1),(-1,1),(1,1)]]
   faces=[[vertices[i] for i in f] for f in [(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(0,2,5,3)]]
  elif p.find("token[@name='shape']").text=='2':
   ring=[]
   for sign in (-1,1):ring.append([np.array([sign*size[0]/2,math.cos(t)*size[1]/2,math.sin(t)*size[2]/2]) for t in np.linspace(0,2*math.pi,21)[:-1]])
   faces=[ring[0],ring[1]]
   faces += [[ring[0][i],ring[0][(i+1)%20],ring[1][(i+1)%20],ring[1][i]] for i in range(20)]
  else:
   vertices=[np.array([x,y,z])*size/2 for x in (-1,1) for y in (-1,1) for z in (-1,1)]
   faces=[[vertices[i] for i in f] for f in [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]]
  transformed=[]
  for face in faces:
   pts=[mat@v+pos for v in face];transformed.append([[v[2],v[0],v[1]] for v in pts])
  colors=[np.clip(color*(.76+.20*(i%3)/2),0,1) for i in range(len(faces))]
  poly=Poly3DCollection(transformed,facecolors=colors,edgecolor=(0,0,0,.15),linewidth=.2)
  ax.add_collection3d(poly)
 ax.set_proj_type('ortho');ax.view_init(elev=7,azim=-78)
 if name.startswith('Python'):ax.set_xlim(-2.8,.85);ax.set_ylim(-.6,.6);ax.set_zlim(-1.3,.85);ax.set_box_aspect((3.65,1.2,2.15))
 elif name.startswith('Machete'):ax.set_xlim(-.9,.65);ax.set_ylim(-.6,.6);ax.set_zlim(-.9,2.5);ax.set_box_aspect((1.55,1.2,3.4))
 elif name.startswith('Butter'):ax.set_xlim(-.65,.65);ax.set_ylim(-.5,.5);ax.set_zlim(-.95,1.5);ax.set_box_aspect((1.3,1,2.45))
 elif name.startswith('Service'):ax.set_xlim(-1.8,.8);ax.set_ylim(-.65,.65);ax.set_zlim(-1.4,.8);ax.set_box_aspect((2.6,1.3,2.2))
 else:ax.set_xlim(-1,.65);ax.set_ylim(-.6,.6);ax.set_zlim(-1,.98);ax.set_box_aspect((1.65,1.2,1.98))
 ax.set_axis_off();ax.set_title(label,color='#e6e8e9',fontsize=16,pad=-5)
fig.suptitle('EDITABLE WEAPON RIGS — ACTUAL EXPORTED GEOMETRY',color='#e6e8e9',fontsize=16,y=.95)
fig.text(.5,.045,'Native-part prototypes • No arms included • Studio review pending',ha='center',color='#aeb8c0',fontsize=12)
fig.subplots_adjust(left=.03,right=.97,bottom=.10,top=.84,wspace=.05)
output=ROOT/('NewWeaponGeometryPreview.png' if expanded else 'GeometryPreview.png')
fig.savefig(output,dpi=150,facecolor=fig.get_facecolor())
print(output)
