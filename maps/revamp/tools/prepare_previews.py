"""Label external geometry previews and make a compact review board (requires Pillow)."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'previews'
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(n):
 try:return ImageFont.truetype(FONT,n)
 except OSError:return ImageFont.load_default()
for p in sorted(OUT.glob('*.png')):
 im=Image.open(p).convert('RGB');w,h=im.size;board=Image.new('RGB',(w,h+62),'#172029');board.paste(im,(0,0));d=ImageDraw.Draw(board)
 d.text((14,h+8),p.stem.replace('_',' / '),font=font(17),fill='#edf0ee')
 d.text((14,h+32),'EXPORTED GEOMETRY / BLENDER VIEWPORT / NOT A STUDIO SCREENSHOT',font=font(13),fill='#b6c5cd')
 board.save(p.with_suffix('.jpg'),quality=90)
names=['Foundry','ContainerYard','FreightTerminal','CanalWorks','MetroExchange','Skyline','Crosscut','TestingGrounds','PumpHouse']
board=Image.new('RGB',(1500,1150),'#172029');d=ImageDraw.Draw(board)
d.text((18,12),'ENVIRONMENT REVIEW BUILDS / ACTUAL EXPORTED GEOMETRY',font=font(23),fill='white')
for i,name in enumerate(names):
 p=OUT/f'{name}_overview.png';assert p.exists(),p
 im=Image.open(p).convert('RGB');im.thumbnail((492,308));x=i%3*500+4;y=i//3*354+62
 d.text((x+8,y),name,font=font(21),fill='white');board.paste(im,(x,y+32))
d.text((18,1120),'Blender viewport previews. Roblox materials, lights, studs and gameplay require Studio review.',font=font(17),fill='#c5d0d5')
board.save(OUT/'AllMaps_GeometryReview.jpg',quality=92)
print('Prepared labelled JPEG previews and nine-map overview board.')
