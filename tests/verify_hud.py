"""Player Status reader and placement, including failures and captured live geometry."""
import base64
import json
from pathlib import Path
import struct
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True,encoding='latin-1')
def module(name): return lua.execute((ROOT/'src'/f'{name}.lua').read_text())
B=module('bytes');factory=module('hud_anchor');config=module('config')
def table(value): return lua.table_from(value,recursive=True)
game,hud=0x10000000,0x20000000
root=game+0x346d538;panel=hud+0x24e340+0x60
def widget(x,y,w,h,scale,shown=1):
    b=bytearray(160)
    for offset,value in [(148,x),(156,y),(36,w),(40,h),(100,scale),(84,shown)]:
        struct.pack_into('<f',b,offset,value)
    return bytes(b)
memory={}
def reset(scale=1):
    memory.clear();memory[root]=struct.pack('<Q',hud)
    memory[panel+0x7b0]=widget(48*scale,114*scale,354,50,scale)
    memory[panel+0xb30]=widget(48*scale,64*scale,415,50,scale)
def read(at,n):
    for base,chunk in memory.items():
        off=int(at)-base
        if 0<=off and off+int(n)<=len(chunk):return chunk[off:off+int(n)]
api=table({'game':game,'read':read});reader=factory(api,B)
sample=lambda:reader.sample(reader)
safe=lua.eval('function(h) return pcall(h.sample,h) end')
reset();anchor=sample();assert anchor['right']==463 and anchor['bottom']==64
assert config('x=540')['anchor_player']==1 # Existing ui2 config migrates without a write.
assert config('anchor_player=0.5')['anchor_player']==1

engine=lua.execute((ROOT/'tests/engine.lua').read_text())
ui=module('presentation')(engine['sr'],engine['font_ids'])
rows=table([{'name':'MACHINE GUN','hp':600,'max':600,'ammo':263,'status':'READY','remaining':100}])
options=config('')
for w,h in [(1280,720),(1920,1080),(2560,1440),(3440,1440),(3840,2160)]:
    engine['width'],engine['height']=w,h
    for hud_setting in [0.75,0.9,1,1.25]:
        scale=min(w/1920,h/1080)*hud_setting;reset(scale);anchor=sample()
        engine.next_frame();ui.draw(ui,rows,options,anchor)
        bg=ui['gui']['parts'][ui['rects']['1:bg']]
        assert abs(bg['at']['x']-(463+12)*scale)<=0.51
        assert abs(bg['at']['y']-64*scale)<=0.51
        assert abs(bg['size']['x']-246*scale)<=0.51
        assert bg['at']['x']>anchor['right'] and bg['at']['x']+bg['size']['x']<=w
# Native HUD movement, independent of resolution and mod scale.
reset();memory[panel+0xb30]=widget(148,84,415,50,1)
memory[panel+0x7b0]=widget(148,134,480,50,1) # Weapon wider than health.
anchor=sample();assert anchor['right']==628 and anchor['bottom']==84
options['scale']=1.5;ui.draw(ui,rows,options,anchor)
bg=ui['gui']['parts'][ui['rects']['1:bg']]
assert bg['at']['x']==640 and bg['at']['y']==84 and bg['size']['x']==369
reset();memory[panel+0xb30]=widget(48,64,415,50,1,0)
memory[panel+0x7b0]=widget(48,114,354,50,1,0)
ui.draw(ui,rows,options,sample());assert not ui['visible']
ui.draw(ui,rows,options,None);assert not ui['visible']
reset();engine['width']=500
ui.draw(ui,rows,options,sample());assert not ui['visible'], 'clamped across Player Status'
for field,value in [(148,float('nan')),(36,float('inf')),(100,0),(84,2)]:
    reset();blob=bytearray(memory[panel+0xb30]);struct.pack_into('<f',blob,field,value)
    memory[panel+0xb30]=bytes(blob);assert safe(reader)[0] is False
reset();memory[panel+0xb30]=memory[panel+0xb30][:100];assert safe(reader)[0] is False
reset();memory[root]=struct.pack('<Q',0);assert safe(reader)[0] is False
reset();memory[panel+0x7b0]=widget(48,114,354,50,2);assert safe(reader)[0] is False
reset();count=0
def changed(at,n):
    global count
    if int(at)==root:
        count+=1
        if count>1:return struct.pack('<Q',hud+4096)
    return read(at,n)
assert safe(factory(table({'game':game,'read':changed}),B))[0] is False
print('PASS: Player Status geometry; 5 resolutions x 4 native HUD scales; wider weapon row; live offsets; hidden/unreadable/invalid/changed root; no overlap on insufficient space')

lua.execute('''return function(controller,model,engine,config)
    local E=engine();E.sr.Window={show_cursor=function()return false end}
    local now,missing,hidden,draws=0,false,0,0
    local hud={sample=function()
        if missing then error('HUD rebuilding') end
        return {right=555.6,bottom=76.8,scale=1.2,shown=1}
    end}
    local ui={hide=function()hidden=hidden+1 end,
        draw=function(self,rows,options,anchor)
            assert(#rows==1 and anchor.right==555.6);draws=draws+1
        end}
    local reader={sample=function()return {world='w',peer='owner',sentries={
        {identity='a',name='GATLING',hp=100,max=100,owner='owner',remaining=10,ammo=10,life=0}}} end}
    local c=controller(E.sr,{time=function()return now end},reader,model(),ui,
        config(''),{verified=true},function()end,hud)
    c:tick();assert(draws==1)
    missing=true;now=0.01;c:tick();assert(draws==1 and hidden>=1)
    missing=false;now=0.02;c:tick();assert(draws==2 and #c.rows==1)
end''')(module('controller'),module('model'),lua.eval('function(s) return function() return assert(loadstring(s))() end end')((ROOT/'tests/engine.lua').read_text()),config)
print('PASS: controller uses live anchor; temporary HUD read failure hides and recovers without losing sentries')

captures=sorted((ROOT/'build/live-hud').glob('hud-sample-*.json'))
report=[]
for path in captures:
    s=json.loads(path.read_text(encoding='utf-8-sig'))
    memory.clear();memory.update({int(k):base64.b64decode(v) for k,v in s['memory'].items()})
    live=factory(table({'game':s['game'],'read':read}),B);a=live.sample(live)
    expected=max(b['x']+b['width']*b['scale'] for b in s['boxes'])
    assert abs(a['right']-expected)<0.001
    engine['width'],engine['height']=2560,1440;options['scale']=1
    engine.next_frame();ui.draw(ui,rows,options,a)
    bg=ui['gui']['parts'][ui['rects']['1:bg']]
    assert bg['at']['x']==570 and bg['at']['y']==77 and bg['size']['x']==295
    report.append({'sample':path.name,'player_status_right':a['right'],
                   'player_status_bottom':a['bottom'],'native_scale':a['scale'],
                   'sentry_left':bg['at']['x'],'sentry_bottom':bg['at']['y']})
if report:
    (ROOT/'build/hud-anchor-replay-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('PASS:',len(report),'live Player Status snapshots; actual Lua renderer x=570, bottom=77 at 2560x1440')
