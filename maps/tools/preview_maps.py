"""Render measured overhead previews from the exported geometry (optional matplotlib)."""
import json
import os
from pathlib import Path
os.environ.setdefault('MPLCONFIGDIR','/tmp/oitc-matplotlib')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle

root=Path(__file__).resolve().parents[1]
fig,axes=plt.subplots(1,3,figsize=(16,7),facecolor='#171d22')
for ax,name in zip(axes,['TestingGrounds','ContainerYard','PumpHouse']):
 data=json.loads((root/'models'/f'{name}.geometry.json').read_text())
 w,d=data['footprint']; ax.set_facecolor('#777970')
 for p in sorted(data['parts'],key=lambda p:p['position'][1]):
  if not p['collision'] or p['folder']=='Ground': continue
  x,y,z=p['position']; sx,sy,sz=p['world_size']
  color='#b2b0a3' if p['folder']=='Architecture' else '#d6bf82'
  if 'Container' in p['name']: color='#657d87' if x<0 else '#986e5d'
  if 'Tank' in p['name']: color='#b5b8aa'
  shape=Circle((x,z),sx/2,facecolor=color,edgecolor='#343d41',lw=.6) if p['shape']=='Cylinder' else Rectangle((x-sx/2,z-sz/2),sx,sz,facecolor=color,edgecolor='#343d41',lw=.6)
  ax.add_patch(shape)
 for team,color in [('Blue','#72b9ed'),('Red','#ff9983')]:
  x,y,z=data['spawns'][team]['position']; ax.scatter([x],[z],c=color,s=75,zorder=50)
  ax.text(x,z+(-3 if z<0 else 4),team.upper(),color=color,ha='center',va='center',weight='bold',fontsize=9,zorder=51)
 ax.set_xlim(-w/2-2,w/2+2);ax.set_ylim(d/2+2,-d/2-2);ax.set_aspect('equal')
 ax.set_title(f'{name}\n{w} × {d} studs · {data["part_count"]} parts',color='white',fontsize=13,pad=15)
 ax.set_xlabel('X (studs)',color='#ccd3d8');ax.set_ylabel('Z (studs)',color='#ccd3d8');ax.tick_params(colors='#ccd3d8',labelsize=8)
 for spine in ax.spines.values():spine.set_color('#59656e')
fig.suptitle('ONE IN THE CHAMBER — EXPORTED MAP GEOMETRY',color='white',fontsize=17,y=.96)
fig.text(.5,.04,'Measured build previews • Native Roblox parts • Studio visual and gameplay review pending',ha='center',color='#ccd3d8',fontsize=11)
fig.subplots_adjust(left=.055,right=.98,bottom=.17,top=.8,wspace=.26)
fig.savefig(root/'LayoutPreviews.png',dpi=160,facecolor=fig.get_facecolor())
print(root/'LayoutPreviews.png')
