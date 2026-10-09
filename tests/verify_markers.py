"""Byte fixtures for unit identity/pose, plus actual world-marker Lua rendering."""
from pathlib import Path
import struct
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True,encoding='latin-1')
def module(name): return lua.execute((ROOT/'src'/f'{name}.lua').read_text())
def table(value): return lua.table_from(value,recursive=True)
memory={}
exe,game,reg,gens,units,obj,vt,getter,bones,desc,hud=[0x10000000+i*0x1000000 for i in range(11)]
unit=0x400007
def u32(at,n):memory[at]=struct.pack('<I',n)
def ptr(at,n):memory[at]=struct.pack('<Q',n)
def reset():
    memory.clear()
    ptr(exe+0x1a100f0,reg);u32(reg+0x98,8);ptr(reg+0xa0,gens);memory[gens+7]=b'\1'
    ptr(reg+0x88,units);ptr(units+7*8,obj);u32(obj+8,unit);ptr(obj,vt);ptr(vt+0xe8,getter)
    memory[getter]=bytes.fromhex('488d4160c3');ptr(obj+0x88,bones)
    memory[bones+48]=struct.pack('<fff',12,30,2)
    memory[desc]=struct.pack('<QIIII',0xef85d6cf58e31d70,123,unit,456,0)
    ptr(game+0x346d538,hud);memory[hud+0x3ef168+0x195]=b'\0'
def read(at,n):
    at,n=int(at),int(n)
    for address,data in memory.items():
        off=at-address
        if 0<=off and off+n<=len(data):return data[off:off+n]
row=table(dict(type='EF85D6CF58E31D70',descriptor=desc,entity=123,network=456,unit=unit))
positions=module('positions')(table(dict(exe=exe,game=game,read=read)),module('bytes'))
sample=lua.eval('function(p,r) return pcall(p.sample,p,r) end')
map_open=lua.eval('function(p) return pcall(p.map_open,p) end')
reset();point=positions.sample(positions,row)
assert [point[k] for k in ['x','y','z']]==[12,30,2]
assert positions.map_open(positions) is False
memory[hud+0x3ef168+0x195]=b'\1';assert positions.map_open(positions) is True
memory[hud+0x3ef168+0x195]=b'\2';assert map_open(positions)[0] is False
for address,data in [
    (gens+7,b'\2'),(obj+8,struct.pack('<I',unit+1)),(reg+0x98,struct.pack('<I',7)),
    (getter,bytes.fromhex('488d4161c3')),(bones+48,struct.pack('<fff',float('nan'),30,2)),
    (bones+48,struct.pack('<fff',12,float('inf'),2)),(bones+48,b'\0'*8),
    (desc,struct.pack('<QIIII',0xef85d6cf58e31d70,124,unit,456,0)),
    (desc,struct.pack('<QIIII',0xef85d6cf58e31d70,123,unit,457,0)),
]:
    reset();memory[address]=data;assert sample(positions,row)[0] is False,(hex(address),'accepted invalid identity/pose')
reset();calls=0
def changed(at,n):
    global calls
    if int(at)==exe+0x1a100f0:
        calls+=1
        if calls>1:return struct.pack('<Q',reg+4096)
    return read(at,n)
unstable=module('positions')(table(dict(exe=exe,game=game,read=changed)),module('bytes'))
assert sample(unstable,row)[0] is False
print('PASS: world-position byte fixtures; descriptor/entity/network/generation/object guards; pose signature; finite coordinates; map state; torn reads')

engine=lua.eval('function(s) return function()return assert(loadstring(s))() end end')((ROOT/'tests/engine.lua').read_text())
lua.execute((ROOT/'tests/markers.lua').read_text())(engine,module('markers'),module('presentation'),module('config'),module('marker_icons'),module('controller'),module('model'))
print('PASS: white sentry silhouettes; health and ammo/unknown bars; live movement, range, clipping, behind-camera, map/menu hiding; stale marker cleanup; failure isolation; shutdown')
import json
fixture=table(json.loads((ROOT/'tests/camera_view.json').read_text()))
lua.execute((ROOT/'tests/camera_view.lua').read_text())(engine,module('markers'),module('presentation'),module('config'),module('marker_icons'),fixture)
print('PASS: 3 real camera snapshots x 5 enumeration orders; view-matched player camera; exclude 4 overhead cameras; hide when player camera is missing; explicit GUI viewport; small reverse-Z depth does not hide visible sentries')
