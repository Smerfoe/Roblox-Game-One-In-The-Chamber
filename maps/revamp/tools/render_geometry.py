"""Blender background: render XML geometry with simple color/metal proxies.
Does not emulate Roblox built-in material textures, Lighting, or SurfaceGui layout.
"""
import bpy, math, sys, os, xml.etree.ElementTree as E
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
name=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'Foundry'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
xml=E.parse(ROOT/'models'/f'{name}.rbxmx')
C=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
mats={};batches={}
def getcolor(p):
 c=p.find("Color3[@name='Color']")
 if c is not None:return tuple(float(c.find(a).text) for a in 'RGB')
 c=p.find("Color3uint8[@name='Color3uint8']")
 if c is None:c=p.find("Color3uint8[@name='Color']")
 if c is not None:
  n=int(c.text);return ((n>>16&255)/255,(n>>8&255)/255,(n&255)/255)
 return (.4,.42,.4)
for n in xml.findall(".//Item[@class='Part']"):
 p=n.find('Properties');t=p.find("float[@name='Transparency']")
 if t is not None and float(t.text)>.9:continue
 cf=p.find("CoordinateFrame[@name='CFrame']");s=p.find("Vector3[@name='size']")
 pos=Vector([float(cf.find(a).text) for a in 'XYZ']);size=Vector([float(s.find(a).text) for a in 'XYZ'])
 R=Matrix([[float(cf.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)])
 color=getcolor(p);mat=int(p.find("token[@name='Material']").text);key=(color,mat)
 if key not in mats:
  m=bpy.data.materials.new(str(key));m.diffuse_color=(*color,1);m.use_nodes=True
  bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
  bs.inputs['Roughness'].default_value=.65;bs.inputs['Metallic'].default_value=.45 if mat in (1088,1040,1056) else 0
  if mat==288:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=.5
  mats[key]=m;batches[key]=[[],[]]
 shape=p.find("token[@name='shape']");shape=int(shape.text) if shape is not None else 1
 if shape==2:
  count=16;verts=[Vector((sx*size.x/2,math.cos(a*2*math.pi/count)*size.y/2,math.sin(a*2*math.pi/count)*size.z/2)) for sx in (-1,1) for a in range(count)]
  faces=[tuple(reversed(range(count))),tuple(range(count,count*2))]+[(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
 else:
  verts=[Vector((x*size.x/2,y*size.y/2,z*size.z/2)) for x in (-1,1) for y in (-1,1) for z in (-1,1)]
  faces=[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]
 v,f=batches[key];offset=len(v);v.extend([tuple(C@(R@q+pos)) for q in verts]);f.extend([tuple(i+offset for i in face) for face in faces])
for key,(v,f) in batches.items():
 mesh=bpy.data.meshes.new('ExportedParts');mesh.from_pydata(v,[],f);mesh.update();obj=bpy.data.objects.new('ExportedParts',mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(mats[key])
# SurfaceGui text is approximated with Blender's built-in font; actual text is from XML.
for n in xml.findall(".//Item[@class='Part']"):
 gui=n.find("Item[@class='SurfaceGui']")
 if gui is None:continue
 label=gui.find("Item[@class='TextLabel']/Properties/string[@name='Text']")
 if label is None or not label.text:continue
 p=n.find('Properties');cf=p.find("CoordinateFrame[@name='CFrame']");sz=p.find("Vector3[@name='size']")
 if cf is None:continue
 pos=Vector([float(cf.find(a).text) for a in 'XYZ']);size=Vector([float(sz.find(a).text) for a in 'XYZ'])
 R=Matrix([[float(cf.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)])
 face=gui.find("Properties/token[@name='Face']");face=int(face.text) if face is not None else 5
 if face not in (0,2,3,5):continue
 normal=Vector({0:(1,0,0),2:(0,0,1),3:(-1,0,0),5:(0,0,-1)}[face]);up=Vector((0,1,0));right=up.cross(normal)
 facewidth=size.z if face in (0,3) else size.x;facedepth=size.x if face in (0,3) else size.z
 rot=Matrix((C@(R@right),C@(R@up),C@(R@normal))).transposed()
 bpy.ops.object.text_add();obj=bpy.context.object;obj.data.body=label.text;obj.data.align_x='CENTER';obj.data.align_y='CENTER';obj.data.size=1
 obj.location=C@(pos+R@(normal*(facedepth/2+.015)));obj.rotation_euler=rot.to_euler()
 bpy.context.view_layer.update();scale=min(facewidth*.9/max(obj.dimensions.x,.01),size.y*.85/max(obj.dimensions.y,.01));obj.scale=(scale,scale,scale)
 m=bpy.data.materials.get('SignInk')
 if m is None:m=bpy.data.materials.new('SignInk');m.diffuse_color=(.87,.85,.74,1)
 obj.data.materials.append(m)
world=bpy.context.scene.world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.43,.52,.62,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.light_add(type='SUN',location=(40,-50,80));sun=bpy.context.object;sun.rotation_euler=(.5,-.4,-.5);sun.data.energy=2.3;sun.data.angle=.08
bpy.ops.object.camera_add();cam=bpy.context.object;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.studiolight_rotate_z=.4
scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH'
scene.display.shading.curvature_ridge_factor=1.2;scene.display.shading.curvature_valley_factor=1.0
scene.display.shading.background_type='WORLD';scene.world.color=(.12,.15,.18)
scene.display.render_aa='16'
scene.render.resolution_x=1120;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
views={'overview':((112,105,105),(0,0,3)), 'blue_route':((-43,37,4.6),(-18,-3,7)), 'machine_aisle':((-36,-20,4.6),(-18,15,8)), 'red_route':((44,-37,4.6),(18,3,7))}
if name=='ContainerYard':views={'overview':((126,115,110),(0,0,4)), 'yard_route':((-47,42,4.6),(10,-10,8)), 'centre':((-12,9,4.6),(18,-20,9)), 'cargo_edge':((46,-38,4.6),(-10,9,8))}
if name not in ('Foundry','ContainerYard'):
 views={'overview':((128,116,108),(0,0,3))}
 for team in ('Blue','Red'):
  for n in xml.findall(".//Item[@class='Part']"):
   p=n.find('Properties');nn=p.find("string[@name='Name']")
   if nn is None or not nn.text.startswith(team+'Spawn') or 'Floor' in nn.text or 'Tile' in nn.text:continue
   tr=p.find("float[@name='Transparency']")
   if tr is None or float(tr.text)<.9:continue
   cf=p.find("CoordinateFrame[@name='CFrame']");pos=Vector([float(cf.find(a).text) for a in 'XYZ']);pos.y+=1.5
   look=Vector([-float(cf.find(f'R{i}2').text) for i in range(3)])
   target=pos+look*28;target.y=6
   views[team.lower()+'_spawn']=(tuple(C@pos),tuple(C@target));break
for label,(at,target) in views.items():
 cam.location=at;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=22 if label!='overview' else 42;cam.data.clip_end=1000
 scene.render.filepath=str(ROOT/'previews'/f'{name}_{label}.png');bpy.ops.render.render(write_still=True)
