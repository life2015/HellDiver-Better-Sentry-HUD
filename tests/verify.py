import html
import base64
from io import BytesIO
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile
from lupa.lua51 import LuaRuntime
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.dont_write_bytecode=True
l=LuaRuntime(unpack_returned_tuples=True)
def module(name): return l.execute((ROOT/'src'/f'{name}.lua').read_text())
compile=l.eval('function(s) local f,e=loadstring(s);assert(f,e) end')
for p in [*sorted((ROOT/'src').glob('*.lua')),ROOT/'build/sentry_hud.lua']:compile(p.read_text())
engine=l.eval('function(s) return function()return assert(loadstring(s))() end end')((ROOT/'tests/engine.lua').read_text())
l.execute((ROOT/'tests/ownership.lua').read_text())(module('bytes'),module('ownership'))
l.execute((ROOT/'tests/icons.lua').read_text())(engine,module('presentation'),module('config'),module('icons'),module('catalog'),module('model'))
print('PASS: all 10 native icon mappings; retained bitmap updates; title/status spacing; scaling; removal; failure fallback; shutdown')
print('PASS: native layout pin; full peer identity; collision overflow; cycle/bounds/empty session rejection')
e=l.execute((ROOT/'tests/test.lua').read_text())(module('bytes'),module('reader'),module('catalog'),module('model'),module('controller'),module('presentation'),module('config'),engine,module('ownership'),module('icons'))
bundle=(ROOT/'build/sentry_hud.lua').read_text()
hook_test=bundle.replace((ROOT/'src/windows.lua').read_text(),'return function() return _G._test_api end')
assert hook_test!=bundle
l.execute((ROOT/'tests/addon.lua').read_text())(hook_test,engine)
print('PASS: bundled addon update/shutdown forwarding; duplicate load; render-error isolation (OS boundary mocked)')
print('PASS: Lua 5.1 syntax; ownership exclusion; health/ammo/countdown byte fixtures; expiry/retraction hiding; partial reads; identity bounds; firing/refill; multi-target order; menus/world/read resets; rendering at 5 resolutions x 3 scales; shutdown without native calls')
r=json.loads((ROOT/'build/build-report.json').read_text())
with zipfile.ZipFile(ROOT/'dist'/r['release']) as z:
 assert z.testzip() is None
 patch=z.read('Addon/9ba626afa44a3aa3.patch_0')
 nt,nr=struct.unpack_from('<II',patch,4)
 assert nt==nr==3
 entries=[struct.unpack_from('<7Q6I',patch,72+nt*32+i*80) for i in range(nr)]
 lua_entry=next(e for e in entries if e[0]==int(r['resource'],16) and e[1]==0xa14e8dfa2cd117e2)
 assert r['resource']!='0cdb2ce39c96e9a4'
 payload=patch[lua_entry[2]:lua_entry[2]+lua_entry[7]]
 assert struct.unpack_from('<II',payload)==(len(payload)-8,2)
 source=payload[8:].decode()
 assert source.startswith('-- HD2-Addon: mods/retrox/sentry_hud\n')
 assert source==(ROOT/'build/sentry_hud.lua').read_text()
 assert 'WriteProcessMemory' not in source
 assert len(z.namelist())==8
 gpu=z.read('Addon/9ba626afa44a3aa3.patch_0.gpu_resources')
 assert z.read('Addon/9ba626afa44a3aa3.patch_0.stream')==b''
 for row in entries:
  assert row[2]+row[7]<=len(patch) and row[4]+row[9]<=len(gpu) and row[4]%64==0
 texture=next(e for e in entries if e[1]==0xcd4238c6a0c69e32)
 dds=patch[texture[2]+192:texture[2]+texture[7]]+gpu[texture[4]:texture[4]+texture[9]]
 atlas=Image.open(BytesIO(dds)).convert('RGBA');assert atlas.size==(512,512)
 assert struct.unpack_from('<I',dds,28)[0]==10 and texture[9]==349552
 art=json.loads((ROOT/'assets/icons/manifest.json').read_text())
 assert texture[0]==int(art['texture_hash'],16) and len(art['cells'])==10
 material=next(e for e in entries if e[1]==0xeac0b497876adedf)
 assert material[0]==int(art['material_hash'],16)
 assert struct.unpack_from('<Q',patch,material[2]+140)[0]==texture[0]
 assert json.loads(z.read('manifest.json'))['Guid']!='fe6c0ed7-c93c-4cac-96d3-5d52b2602b37'
# Test actual BSL v15 discovery against our packaged archive.
spec=importlib.util.spec_from_file_location('archive',ROOT.parent/'BingusSharedLoader/scripts/archive.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
assert a.resource_hash(r['entry'])==int(r['resource'],16)
p=ROOT/'build/9ba626afa44a3aa3.patch_0';p.write_bytes(patch)
discovery=l.execute(subprocess.check_output(['git','show','v15:src/discover.lua'],cwd=ROOT.parent/'BingusSharedLoader',text=True))
escaped=''.join('\\%03d'%v for v in struct.pack('<Q',int(r['resource'],16)))
hashfn=l.eval('function(s) assert(s=="'+r['entry']+'");return "'+escaped+'" end')
entries,warnings=discovery.scan(l.table_from([str(p)]),hashfn,l.globals().io.open)
assert list(entries.values())==[r['entry']] and len(warnings)==0
print('PASS: actual BSL v15 discovery; unique addon resource/manifest; ZIP integrity; no native memory writes')
subprocess.run([sys.executable,str(ROOT/'tests/verify_hud.py')],check=True)
# Preview uses actual renderer output; it is explicitly a simulated layout.
parts=[]
for _,gui in e['guis'].items():
 for _,v in gui['parts'].items():
  c=v['tint'];color=f'rgb({c["r"]},{c["g"]},{c["b"]})';opacity=c['a']/255
  x,y=v['at']['x'],1080-v['at']['y']
  if v['kind']=='rect':
   w,h=v['size']['x'],v['size']['y'];parts.append((v['at']['z'],f'<rect x="{x}" y="{y-h}" width="{w}" height="{h}" fill="{color}" opacity="{opacity}"/>'))
  elif v['kind']=='bitmap':
   lo,hi=v['lo'],v['hi'];icon=atlas.crop(tuple(round(t*512) for t in [lo['x'],lo['y'],hi['x'],hi['y']]))
   png=BytesIO();icon.save(png,format='PNG');url='data:image/png;base64,'+base64.b64encode(png.getvalue()).decode()
   w,h=v['size']['x'],v['size']['y']
   parts.append((v['at']['z'],f'<image x="{x}" y="{y-h}" width="{w}" height="{h}" href="{url}"/>'))
  else:parts.append((v['at']['z'],f'<text x="{x}" y="{y}" font-size="{v["size"]}" fill="{color}" opacity="{opacity}">{html.escape(v["text"])}</text>'))
svg='<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#1b282a"/><g font-family="Arial,sans-serif"><text x="70" y="80" font-size="26" fill="#eee">SENTRY HUD — SIMULATED LAYOUT / NOT A GAME CAPTURE</text><rect x="43.2" y="932.4" width="318.6" height="45" fill="#111c20"/><text x="55" y="962" font-size="14" fill="#ddd">PLAYER STATUS / WEAPON</text><rect x="43.2" y="977.4" width="373.5" height="45" fill="#111c20"/><text x="55" y="999" font-size="12" fill="#ddd">HEALTH / CONSUMABLES</text><rect x="55" y="1010" width="180" height="6" fill="#e4d397"/>'+''.join(p for _,p in sorted(parts,key=lambda x:x[0]))+'</g></svg>'
(ROOT/'build/layout-preview.svg').write_text(svg)
print('PREVIEW: build/layout-preview.svg (synthetic, real renderer geometry)')
print('NOT VERIFIED IN GAME: HUD placement; multiplayer/host migration; additional sentry types and beam/arc behavior')

(ROOT/'build/layout-detail.svg').write_text(svg.replace('width="1920" height="1080" viewBox="0 0 1920 1080"','width="1800" height="400" viewBox="0 880 900 200"'))
