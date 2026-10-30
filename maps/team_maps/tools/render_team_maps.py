"""Plot actual exported XML geometry. Not a Roblox engine/PBR screenshot."""
from pathlib import Path
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/oitc-team-mpl')
import json
import math
import xml.etree.ElementTree as E
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

ROOT=Path(__file__).resolve().parents[1]
ORDER=['FreightTerminal','Foundry','CanalWorks','MetroExchange','Skyline','Crosscut']
LABELS=['FREIGHT TERMINAL','FOUNDRY','CANAL WORKS','METRO EXCHANGE','SKYLINE','CROSSCUT']


def scene(ax,name,label):
 meta=json.loads((ROOT/'models'/f'{name}.geometry.json').read_text());w,d=meta['footprint']
 tree=E.parse(ROOT/'models'/f'{name}.rbxmx');refs={n.get('referent'):n for n in tree.findall(".//Item[@class='Part']")}
 polygons=[];colors=[]
 for index,part in enumerate(meta['parts']):
  p=refs[f'{name}_{index:04d}'].find('Properties')
  if float(p.find("float[@name='Transparency']").text)>.9:continue
  pos=np.array(part['position']);size=np.array(part['size'])
  frame=p.find("CoordinateFrame[@name='CFrame']");R=np.array([[float(frame.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)])
  color=np.array([float(p.find(f"Color3[@name='Color']/{a}").text) for a in 'RGB'])
  faces=[]
  if part['shape']=='Cylinder':
   rings=[]
   for sign in (-1,1):rings.append([np.array([sign*size[0]/2,math.cos(t)*size[1]/2,math.sin(t)*size[2]/2]) for t in np.linspace(0,2*math.pi,13)[:-1]])
   faces=[rings[0],rings[1]]+[[rings[0][i],rings[0][(i+1)%12],rings[1][(i+1)%12],rings[1][i]] for i in range(12)]
  else:
   verts=[np.array([x,y,z])*size/2 for x in (-1,1) for y in (-1,1) for z in (-1,1)]
   faces=[[verts[i] for i in f] for f in [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]]
  for i,face in enumerate(faces):
   points=[R@v+pos for v in face];polygons.append([[v[0],v[2],v[1]] for v in points])
   # Simple directional shading only, no claim to reproduce Roblox materials.
   colors.append(np.clip(color*[.72,.87,.66,1.08,.81,.76][i%6],0,1))
 poly=Poly3DCollection(polygons,facecolors=colors,edgecolor=(.08,.10,.11,.12),linewidth=.15,zsort='average')
 ax.add_collection3d(poly)
 if name=='Crosscut':
  # Native stud surfaces are engine-rendered; the XML sets SurfaceType.Studs.
  # Dots here are a plan-style indication, not individual exported stud meshes.
  pts=[]
  for row in meta['floor_rectangles']:
   x1,z1,x2,z2=row
   for x in range(math.ceil(x1)+2,math.floor(x2),4):
    for z in range(math.ceil(z1)+2,math.floor(z2),4):
     if not any(b[0]<=x<=b[2] and b[1]<=z<=b[3] for b in meta['source_blocks']):pts.append((x-w/2,z-d/2))
  if pts:
   x,z=zip(*pts);ax.scatter(x,z,[.10]*len(pts),s=1,c='#67735e',depthshade=False)
 ax.set_facecolor('#1b242c');ax.set_proj_type('ortho');ax.view_init(elev=57,azim=-63)
 ax.set_xlim(-w/2-3,w/2+3);ax.set_ylim(-d/2-3,d/2+3);ax.set_zlim(-2,19)
 ax.set_box_aspect((w,d,25));ax.set_axis_off()
 ax.set_title(f'{label}\n{meta["primary_mode"]} · {w} × {d} studs · {meta["part_count"]} parts',color='#e9e8e0',fontsize=13,pad=-2)
 return meta


def main():
 (ROOT/'previews').mkdir(exist_ok=True)
 for mode,offset in [('2v2',0),('3v3',2),('4v4',4)]:
  fig=plt.figure(figsize=(16,9),facecolor='#1b242c')
  for i in range(2):scene(fig.add_subplot(1,2,i+1,projection='3d'),ORDER[offset+i],LABELS[offset+i])
  fig.suptitle(f'ONE IN THE CHAMBER — {mode} MODEL BUILDS',color='#e9e8e0',fontsize=19,y=.95)
  fig.text(.5,.06,'ACTUAL EXPORTED GEOMETRY • Plotted preview, not a Studio render\nBuilt-in materials, signs and native studs must be inspected in Roblox Studio',color='#afbec9',fontsize=10,ha='center')
  fig.subplots_adjust(left=.015,right=.985,bottom=.12,top=.86,wspace=.02)
  fig.savefig(ROOT/'previews'/f'Built_{mode}.png',dpi=150,facecolor=fig.get_facecolor());plt.close(fig)
 print('Rendered three paired boards from actual model XML.')

if __name__=='__main__':main()
