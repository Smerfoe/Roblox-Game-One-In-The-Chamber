"""Six deliberately different, measured 2D arena proposals; no Roblox files changed.
Run from any directory. Requires numpy/matplotlib only for drawing and grid checks.
"""
from pathlib import Path
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/oitc-layouts-mpl')
import json
import math
import heapq
from collections import deque
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle

ROOT=Path(__file__).resolve().parents[1]

def layout(name,mode,size,spawn,rooms,links,blocks,routes,notes,labels,studded=False):
 return dict(name=name,mode=mode,size=size,spawns=spawn,rooms=rooms,links=links,blocks=blocks,
             routes=routes,notes=notes,labels=labels,studded=studded)

def block(x1,y1,x2,y2,low=False):return [x1,y1,x2,y2,3.2 if low else 12]

def definitions():
 return [
 layout('Freight Terminal','2v2',(112,88),[(9,44),(103,44)],
  [[0,32,22,56],[18,12,94,64],[24,56,88,84],[90,32,112,56]],[],
  [block(17,39,19,49),block(93,39,95,49),
   block(24,57,39,59),block(49,57,63,59),block(74,57,88,59),
   block(31,27,46,44),block(68,41,82,53),block(55,16,62,34),
   block(25,16,31,20,True),block(78,23,85,27,True)],
  [[(9,44),(22,54),(44,66),(70,68),(89,54),(103,44)],
   [(9,44),(24,28),(48,21),(67,31),(86,33),(103,44)]],
  ['One offset warehouse + a broad broken yard.','Fast dock doors trade safety for predictable exits.','Longer truck-end flank creates side pressure.'],
  [(55,75,'LOADING HALL'),(39,35,'OFFICE'),(75,47,'CARGO'),(72,17,'TRUCK-END FLANK')]),
 layout('Foundry','2v2',(104,92),[(10,10),(94,82)],
  [[0,0,22,22],[10,18,48,74],[56,18,94,74],[34,14,70,28],
   [34,64,70,78],[40,40,64,52],[82,70,104,92],[16,10,39,23],[65,71,89,84]],[],
  [block(25,30,32,54),block(72,38,79,62),block(45,40,49,45),block(55,47,59,52),
   block(11,16,18,18),block(86,74,93,76),
   block(12,58,18,62,True),block(86,30,92,34,True)],
  [[(10,10),(37,20),(59,22),(63,46),(88,69),(94,82)],
   [(10,10),(20,29),(18,65),(43,70),(66,72),(94,82)]],
  ['Two machine halls, not a center building.','Upper/lower transfers + a tight dogleg connector.','Pairs can trade across halls or isolate one room.'],
  [(21,48,'HALL A'),(85,50,'HALL B'),(52,46,'DOGLEG'),(52,72,'NORTH TRANSFER')]),
 layout('Canal Works','3v3',(138,114),[(12,16),(125,98)],
  [[0,2,27,30],[13,45,35,78],[103,52,126,82],[111,84,138,112]],
  [[14,[[12,16],[48,16],[48,58],[88,58],[88,98],[125,98]]],
   [12,[[24,16],[24,70],[64,70],[64,58]]],
   [12,[[72,58],[72,40],[114,40],[114,98],[125,98]]],
   [10,[[48,42],[72,42]]]],
  [block(20,11,22,21),block(116,93,118,103),
   block(15,55,21,61,True),block(117,66,123,72,True),
   block(47,29,50,33,True),block(86,78,89,82,True)],
  [[(12,16),(37,16),(48,42),(63,42),(72,55),(88,58),(88,91),(125,98)],
   [(12,16),(24,39),(27,70),(64,70),(72,40),(114,40),(113,88),(125,98)]],
  ['A winding S route with two side loops.','Cross-link lets teams cut ahead or double back.','Blind bends; open pockets only at pump yards.'],
  [(23,68,'PUMP YARD'),(55,42,'CROSS-LINK'),(108,73,'VALVE YARD'),(91,97,'FINAL BEND')]),
 layout('Metro Exchange','3v3',(120,96),[(11,78),(99,11)],
  [[0,65,25,92],[18,60,114,90],[84,12,114,90],[85,0,113,25],
   [30,24,50,72],[42,22,96,38],[58,32,74,70]],[],
  [block(19,73,21,83),block(94,21,104,23),
   block(36,65,42,71),block(78,77,84,83),block(98,62,103,71),
   block(44,42,48,54),block(61,45,65,55),
   block(87,47,91,52,True),block(51,80,59,83,True)],
  [[(11,78),(29,78),(65,74),(92,77),(108,58),(108,30),(99,11)],
   [(11,78),(32,62),(37,37),(54,29),(82,29),(90,29),(99,11)]],
  ['L-shaped public concourse around an inner void.','Maintenance cuts the elbow, with sharp door turns.','Broad public route vs two narrow internal cuts.'],
  [(58,86,'PUBLIC CONCOURSE'),(99,44,'EAST ARM'),(40,42,'SERVICE'),(70,29,'MAINTENANCE CUT')]),
 layout('Skyline','4v4',(144,96),[(13,12),(131,84)],
  [[0,0,28,26],[12,12,48,40],[16,28,40,78],[24,62,94,94],
   [36,24,108,74],[52,4,120,34],[108,20,132,72],[96,58,132,84],[116,70,144,96]],[],
  [block(22,8,24,18),block(120,78,122,88),
   block(42,41,61,58),block(84,41,105,57),block(68,24,73,43),
   block(63,66,75,73),block(27,68,33,73,True),block(110,25,116,30,True),
   block(83,9,91,14,True)],
  [[(13,12),(25,31),(26,56),(38,82),(78,82),(110,75),(131,84)],
   [(13,12),(38,26),(56,17),(84,24),(97,31),(119,42),(119,68),(131,84)]],
  ['Staggered roof wings form two linked courtyards.','Teams enter the contested space on diagonal approaches.','Center pockets support trades; edges are rotations.'],
  [(51,49,'WEST PLANT'),(94,49,'EAST PLANT'),(68,86,'UPPER COURT'),(88,18,'LOWER COURT')]),
 layout('Crosscut','4v4',(128,112),[(15,99),(113,13)],
  [[0,24,96,112],[32,0,128,88]],[],
  [block(26,92,28,106),block(100,6,102,20),
   block(42,22,46,42),block(42,54,46,88),block(66,56,84,60),block(96,56,118,60),
   block(80,10,84,34),block(19,39,27,47),block(103,72,111,80),
   block(59,82,67,86,True),block(60,19,67,23,True)],
  [[(15,99),(34,96),(52,95),(87,83),(89,65),(90,45),(103,32),(113,13)],
   [(15,99),(25,78),(28,51),(39,48),(55,48),(66,37),(74,30),(89,38),(113,13)]],
  ['Classic studded blocks; no Alpine/snow theme.','Broken wall runs create four different crossing gaps.','No center room: corners and small open courts.'],
  [(22,67,'WEST COURT'),(61,48,'CROSSCUT'),(103,46,'EAST COURT')],True),
 ]


def build_grid(m):
 w,h=m['size'];xs=np.arange(w)+.5;ys=np.arange(h)+.5;X,Y=np.meshgrid(xs,ys)
 floor=np.zeros((h,w),dtype=bool)
 def rect(mask,r):
  x1,y1,x2,y2=r;mask|=(X>=x1)&(X<x2)&(Y>=y1)&(Y<y2)
 for room in m['rooms']:rect(floor,room)
 for width,path in m['links']:
  for a,b in zip(path,path[1:]):
   assert a[0]==b[0] or a[1]==b[1], 'Use axis-aligned measured corridors'
   rect(floor,[min(a[0],b[0])-width/2,min(a[1],b[1])-width/2,max(a[0],b[0])+width/2,max(a[1],b[1])+width/2])
 solid=np.zeros_like(floor);tall=np.zeros_like(floor)
 for r in m['blocks']:
  rect(solid,r[:4])
  if r[4]>4.5:rect(tall,r[:4])
 floor&=~solid
 # Conservative 3-stud body footprint at standing ground; square erosion.
 padded=np.pad(floor,2,constant_values=False);free=np.ones_like(floor)
 for dy in range(-2,3):
  for dx in range(-2,3):free&=padded[2+dy:2+dy+h,2+dx:2+dx+w]
 return floor,free,tall,solid


def point(p):return (int(p[0]),int(p[1]))

def astar(free,start,goal):
 w,h=free.shape[1],free.shape[0];start,goal=point(start),point(goal)
 assert free[start[1],start[0]],f'Blocked start waypoint {start}'
 assert free[goal[1],goal[0]],f'Blocked destination waypoint {goal}'
 q=[(0,0,start)];came={};cost={start:0}
 while q:
  _,g,n=heapq.heappop(q)
  if n==goal:
   out=[n]
   while n in came:n=came[n];out.append(n)
   return out[::-1]
  if g!=cost[n]:continue
  for nx,ny in ((n[0]+1,n[1]),(n[0]-1,n[1]),(n[0],n[1]+1),(n[0],n[1]-1)):
   if 0<=nx<w and 0<=ny<h and free[ny,nx] and g+1<cost.get((nx,ny),10**9):
    nxt=(nx,ny);cost[nxt]=g+1;came[nxt]=n
    heapq.heappush(q,(g+1+abs(nx-goal[0])+abs(ny-goal[1]),g+1,nxt))
 raise AssertionError(f'No ground path {start} to {goal}')


def paths_and_checks(m,free,floor,tall):
 paths=[]
 for route in m['routes']:
  out=[]
  for a,b in zip(route,route[1:]):out+=astar(free,a,b)[:-1]
  out.append(point(route[-1]))
  # Remove any tiny path loop introduced by chained waypoint segments.
  simple=[];indices={}
  for cell in out:
   if cell in indices:
    cut=indices[cell]
    for old in simple[cut+1:]:indices.pop(old)
    simple=simple[:cut+1]
   else:indices[cell]=len(simple);simple.append(cell)
  paths.append(simple)
 # Full ground connectivity and exact team spawn slot clearance.
 start=point(m['spawns'][0]);q=deque([start]);seen={start}
 while q:
  x,y=q.popleft()
  for n in ((x+1,y),(x-1,y),(x,y+1),(x,y-1)):
   if 0<=n[0]<free.shape[1] and 0<=n[1]<free.shape[0] and free[n[1],n[0]] and n not in seen:seen.add(n);q.append(n)
 assert len(seen)==int(free.sum()),'Isolated walkable pocket'
 slots=[];nplayers=int(m['mode'][0])
 offsets=[(-3,-3),(3,3),(-3,3),(3,-3)][:nplayers]
 for center in m['spawns']:
  team=[]
  for dx,dy in offsets:
   pos=(center[0]+dx,center[1]+dy);assert free[pos[1],pos[0]],f'Spawn slot blocked {pos}'
   team.append(pos)
  slots.append(team)
 # All initial eye-level slot pairs must be occluded by tall cover or enclosing wall/void.
 for a in slots[0]:
  for b in slots[1]:
   ray=[(round(a[0]*(1-t)+b[0]*t),round(a[1]*(1-t)+b[1]*t)) for t in np.linspace(0,1,1000)]
   assert any(not floor[y,x] and (tall[y,x] or not any(r[0]<=x<r[2] and r[1]<=y<r[3] for r in m['blocks'])) for x,y in ray),'Direct spawn shot'
 m['spawn_slots']=slots
 m['example_route_lengths_studs']=[len(p)-1 for p in paths]
 return paths


def draw(ax,m,grid,paths,compact=False):
 floor,free,tall,solid=grid;w,h=m['size'];ax.set_facecolor('#1b2229')
 rgba=np.zeros((h,w,4));rgba[:]=(.106,.133,.161,1);rgba[floor]=(.80,.80,.74,1)
 # Restore low cover cells separately; footprint void stays dark.
 for r in m['blocks']:
  x1,y1,x2,y2,height=r;rgba[y1:y2,x1:x2]=(.25,.29,.31,1) if height>4.5 else (.69,.55,.30,1)
 ax.imshow(rgba,origin='lower',extent=(0,w,0,h),interpolation='nearest')
 # Outline walkable surface (cover notches are also represented).
 ax.contour(np.arange(w)+.5,np.arange(h)+.5,floor.astype(float),levels=[.5],colors=['#e9e8dc'],linewidths=.55)
 if m['studded']:
  xx,yy=np.meshgrid(np.arange(2,w,4),np.arange(2,h,4));xx,yy=xx.ravel(),yy.ravel()
  valid=floor[yy,xx];ax.scatter(xx[valid],yy[valid],s=2,c='#aaaa9e',alpha=.65,zorder=2)
 for r in m['blocks']:
  x1,y1,x2,y2,height=r
  if height<=4.5:ax.add_patch(Rectangle((x1,y1),x2-x1,y2-y1,fill=False,hatch='///',edgecolor='#dec28e',lw=.4))
 for route,color in zip(paths,('#4c94ad','#b27e55')):
  pts=np.array(route)+.5;ax.plot(pts[:,0],pts[:,1],color=color,linewidth=1.25,alpha=.85,linestyle=(0,(4,3)),zorder=4)
 for i,(x,y) in enumerate(m['spawns']):
  color='#51a5dc' if i==0 else '#e47d77'
  ax.add_patch(Rectangle((x-5,y-5),10,10,facecolor=color,edgecolor='white',lw=.7,zorder=5))
  ax.text(x,y,'B' if i==0 else 'R',color='white',weight='bold',ha='center',va='center',fontsize=10,zorder=6)
  for sx,sy in m['spawn_slots'][i]:ax.scatter(sx+.5,sy+.5,s=7,facecolor='#172027',zorder=7)
 if not compact:
  for x,y,label in m['labels']:
   ax.text(x,y,label,ha='center',va='center',fontsize=6.7,color='#f5f2e7',bbox=dict(facecolor='#1a2229',edgecolor='none',alpha=.8,pad=2),zorder=8)
 ax.set_xlim(-2,w+2);ax.set_ylim(-2,h+2);ax.set_aspect('equal')
 ax.set_xticks(np.arange(0,w+1,20));ax.set_yticks(np.arange(0,h+1,20));ax.tick_params(colors='#b5c0c7',labelsize=7)
 for spine in ax.spines.values():spine.set_color('#46515c')
 ax.set_title(f'{m["name"].upper()}  |  {m["mode"]}\n{w} × {h} studs · proposed',color='#f1eee5',fontsize=12 if compact else 13,pad=12)
 ax.set_xlabel('X (studs)',color='#b5c0c7',fontsize=8);ax.set_ylabel('Z (studs)',color='#b5c0c7',fontsize=8)


def main():
 maps=definitions();grids=[];paths=[]
 for m in maps:
  grid=build_grid(m);routes=paths_and_checks(m,grid[1],grid[0],grid[2]);grids.append(grid);paths.append(routes)
  print(f'PASS {m["name"]}: connected 3-stud ground clearance; {m["mode"]} spawn slots; initial spawn sightlines blocked; example routes {m["example_route_lengths_studs"]} studs')
  fig,ax=plt.subplots(figsize=(10,9),facecolor='#1b2229');draw(ax,m,grid,routes)
  fig.text(.5,.08,'\n'.join(m['notes']),color='#d8dedf',ha='center',va='center',fontsize=10)
  fig.text(.5,.025,'MEASURED CONCEPT v2 • pale = floor / dark = solid or void / gold = low cover\nDashed lines are two example paths, not fixed lanes • Studio validation still required',ha='center',color='#99aab6',fontsize=8)
  fig.subplots_adjust(left=.09,right=.96,bottom=.20,top=.88)
  fig.savefig(ROOT/(m['name'].replace(' ','')+'_Plan.png'),dpi=150,facecolor=fig.get_facecolor());plt.close(fig)
 for index,mode in enumerate(('2v2','3v3','4v4')):
  fig,axes=plt.subplots(1,2,figsize=(16,9),facecolor='#1b2229')
  for ax,j in zip(axes,range(index*2,index*2+2)):draw(ax,maps[j],grids[j],paths[j])
  for x,j in zip((.27,.76),range(index*2,index*2+2)):
   fig.text(x,.115,'\n'.join(maps[j]['notes']),color='#d8dedf',ha='center',va='center',fontsize=10)
  fig.suptitle(f'ONE IN THE CHAMBER — {mode} LAYOUT REDESIGN',color='#f1eee5',fontsize=19,y=.96)
  fig.text(.5,.035,'Measured concepts, not built maps • Pale floor / dark solids or outside / hatched gold low cover\nTwo sample ground paths shown; no scenery pass • Studio jump, sightline and balance testing remains required',color='#99aab6',ha='center',fontsize=9)
  fig.subplots_adjust(left=.055,right=.98,bottom=.24,top=.84,wspace=.17)
  fig.savefig(ROOT/f'Layouts_{mode}.png',dpi=150,facecolor=fig.get_facecolor());plt.close(fig)
 (ROOT/'layouts.json').write_text(json.dumps(maps,indent=2)+'\n')

if __name__=='__main__':main()
