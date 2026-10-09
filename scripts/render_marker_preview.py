"""Synthetic marker preview using real Lua draw calls and packaged icon masks."""
from pathlib import Path
from io import BytesIO
from lupa.lua51 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
FONT='/System/Library/Fonts/Supplemental/Arial.ttf'
lua=LuaRuntime(unpack_returned_tuples=True)
def module(name):return lua.execute((ROOT/'src'/f'{name}.lua').read_text())
engine=lua.execute((ROOT/'tests/engine.lua').read_text())
lua.execute('''return function(E)
    local meta={};local V={}
    setmetatable(V,{__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},meta)end})
    meta.__sub=function(a,b)return V(a.x-b.x,a.y-b.y,a.z-b.z)end
    V.x=function(p)return p.x end;V.y=function(p)return p.y end
    V.dot=function(a,b)return a.x*b.x+a.y*b.y+a.z*b.z end
    E.sr.Vector3=V
    E.sr.World.units_by_resource=function()return {'camera'}end
    E.sr.World.debug_camera_pose=function()return {}end
    E.sr.Unit={camera=function()return 'cam'end}
    E.sr.Matrix4x4={translation=function()return V(0,0,0)end,forward=function()return V(0,1,0)end}
    E.sr.Camera={world_pose=function()return {}end,world_to_screen=function(_,p)return V(300+p.x*10,170+p.z*10,0)end}
end''')(engine)
positions=lua.eval('''function()return {
    map_open=function()return false end,
    sample=function(_,r)return {x=r.x,y=r.distance,z=0}end
}end''')()
marker=module('markers')(engine['sr'],positions,module('presentation'),module('marker_icons'),engine['font_ids'])
rows=lua.table_from([
    dict(key='a',type='37CDE43876BA26BB',name='MACHINE GUN',hp=420,max=600,ammo=262,ammo_max=350,status='FIRING',x=0,distance=42),
    dict(key='b',type='37079568DC86E9C6',name='ROCKET',hp=260,max=600,ammo=7,ammo_max=10,status='READY',x=30,distance=76),
],recursive=True)
marker.draw(marker,rows,module('config')('marker_scale=2'),'main')
atlas=Image.open(BytesIO((ROOT/'assets/icons/marker-opacity.texture.main').read_bytes()[192:]+(ROOT/'assets/icons/marker-opacity.texture.gpu_resources').read_bytes())).convert('RGBA')
im=Image.new('RGBA',(960,430),'#1b282a');d=ImageDraw.Draw(im)
d.text((28,22),'SENTRY WORLD MARKERS',font=ImageFont.truetype(FONT,24),fill='#ebede5')
d.text((28,57),'Firing / idle, with centered distance labels enabled by default.',font=ImageFont.truetype(FONT,17),fill='#abb9b2')
# Abstract obstruction is illustrative. Markers are screen GUI parts, not depth-tested geometry.
d.polygon([(20,340),(130,272),(255,306),(380,249),(520,304),(650,276),(835,319),(960,270),(960,430),(20,430)],fill='#34403b')
d.text((28,373),'SIMULATED: no in-game projection or terrain capture.',font=ImageFont.truetype(FONT,16),fill='#bbc5bc')
d.text((28,401),'Upper: health. Lower: ammo; dashed when ammo or its baseline is unavailable.',font=ImageFont.truetype(FONT,16),fill='#bbc5bc')
for p in sorted(marker['ui']['gui']['parts'].values(),key=lambda p:p['at']['z']):
    x,y=p['at']['x'],430-p['at']['y'];c=p['tint'];color=tuple(round(c[k]) for k in ['r','g','b','a'])
    layer=Image.new('RGBA',im.size);draw=ImageDraw.Draw(layer)
    if p['kind']=='rect':
        w,h=p['size']['x'],p['size']['y']
        if w and h:draw.rectangle((x,y-h,x+w-1,y-1),fill=color)
    elif p['kind']=='bitmap':
        w,h=p['size']['x'],p['size']['y'];lo,hi=p['lo'],p['hi']
        mask=atlas.crop(tuple(round(v*atlas.width) for v in [lo['x'],lo['y'],hi['x'],hi['y']])).getchannel('A')
        tile=Image.new('RGBA',(w,h),color);tile.putalpha(mask.resize((w,h),Image.Resampling.LANCZOS));layer.paste(tile,(x,y-h))
    else:draw.text((x,y),p['text'],font=ImageFont.truetype(FONT,max(1,round(p['size']))),fill=color,anchor='ls')
    im=Image.alpha_composite(im,layer)
out=ROOT/'build/world-markers-preview.png';im.convert('RGB').save(out);print(out)
