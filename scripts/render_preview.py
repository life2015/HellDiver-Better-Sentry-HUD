"""Rasterize the synthetic vector preview; no game screenshot is modified."""
from pathlib import Path
import base64
from io import BytesIO
import xml.etree.ElementTree as ET
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
root=ET.parse(ROOT/'build/layout-preview.svg').getroot()
image=Image.new('RGB',(1800,440),'#1b282a');d=ImageDraw.Draw(image)
font_path='/System/Library/Fonts/Supplemental/Arial.ttf'
def color(s):
    if s.startswith('rgb('):return tuple(map(int,s[4:-1].split(',')))
    return s
for el in root.iter():
    tag=el.tag.split('}')[-1];a=el.attrib
    if tag not in ['rect','text','image']:continue
    x=float(a.get('x',0))*2;y=(float(a.get('y',0))-860)*2
    fill=color(a.get('fill','#ffffff'))
    if tag=='rect':
        if float(a.get('width',0))==1920:continue
        d.rectangle((x,y,x+float(a['width'])*2,y+float(a['height'])*2),fill=fill)
    elif tag=='image':
        tile=Image.open(BytesIO(base64.b64decode(a['href'].split(',',1)[1]))).convert('RGBA')
        tile=tile.resize((round(float(a['width'])*2),round(float(a['height'])*2)),Image.Resampling.LANCZOS)
        image.paste(tile,(round(x),round(y)),tile)
    else:
        font=ImageFont.truetype(font_path,round(float(a.get('font-size',12))*2))
        d.text((x,y),el.text or '',font=font,fill=fill,anchor='ls')
d.text((26,16),'SIMULATED LAYOUT / NOT A GAME CAPTURE',font=ImageFont.truetype(font_path,20),fill='#a5afad')
image.save(ROOT/'build/layout-preview.png')
