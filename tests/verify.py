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
from PIL import Image, ImageChops, ImageStat
ROOT=Path(__file__).resolve().parents[1]
sys.dont_write_bytecode=True
l=LuaRuntime(unpack_returned_tuples=True)
def module(name): return l.execute((ROOT/'src'/f'{name}.lua').read_text())
compile=l.eval('function(s) local f,e=loadstring(s);assert(f,e) end')
for p in [*sorted((ROOT/'src').glob('*.lua')),ROOT/'build/sentry_hud.lua']:compile(p.read_text())
engine=l.eval('function(s) return function()return assert(loadstring(s))() end end')((ROOT/'tests/engine.lua').read_text())
l.execute((ROOT/'tests/ammo_baseline.lua').read_text())(module('model'),module('controller'),module('config'),engine)
print('PASS: per-sentry first-observed ammo baseline; consumption/refill; delayed/invalid ammo; lifecycle/ownership cleanup; menu/toggle/read-error preservation; session reset')
l.execute((ROOT/'tests/ownership.lua').read_text())(module('bytes'),module('ownership'))
l.execute((ROOT/'tests/settings.lua').read_text())(module('settings'),module('config'))
print('PASS: optional menu discovery; cfg migration; saved values; APPLY semantics; callback isolation; registration refusal; shutdown')
mom=ROOT.parent/'EnemyHPHud/research/vendor/ModOptionsMenu/src'
l.execute((ROOT/'tests/settings_language.lua').read_text())(module('settings'),module('config'),
 l.execute((mom/'bingus_text.lua').read_text()),(mom/'options.lua').read_text(),(mom/'api.lua').read_text())
print('PASS: real Mod Options Menu API/UTF-8/refresh; Chinese text-language detection; all 16 labels/descriptions and layout choices; English fallback; stable category and saved values')
l.execute((ROOT/'tests/layouts.lua').read_text())(engine,module('presentation'),module('config'),module('icons'),module('controller'),module('model'))
print('PASS: screen-right layout at 5 resolutions x 3 scales; vertical centering/offsets; map hiding; right accent; runtime layout switching; disable/enable; menu hiding')
icon_samples=l.execute((ROOT/'tests/icons.lua').read_text())(engine,module('presentation'),module('config'),module('icons'),module('catalog'),module('model'))
print('PASS: all 10 native icon mappings and ordered color tints; retained bitmap updates; title/status spacing; scaling; layer removal; partial failure fallback; shutdown')
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
 assert nt==3 and nr==5
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
 art=json.loads((ROOT/'assets/icons/manifest.json').read_text())
 texture=next(e for e in entries if e[0]==int(art['texture_hash'],16))
 dds=patch[texture[2]+192:texture[2]+texture[7]]+gpu[texture[4]:texture[4]+texture[9]]
 atlas=Image.open(BytesIO(dds)).convert('RGBA');assert atlas.size==(2048,2048)
 assert struct.unpack_from('<I',dds,28)[0]==12
 assert texture[9]==sum(max(1,(2048>>level)//4)**2*16 for level in range(12))
 art=json.loads((ROOT/'assets/icons/manifest.json').read_text())
 assert texture[0]==int(art['texture_hash'],16) and len(art['cells'])==10
 material=next(e for e in entries if e[0]==int(art['material_hash'],16))
 assert material[0]==int(art['material_hash'],16)
 assert struct.unpack_from('<Q',patch,material[2]+140)[0]==texture[0]
 marker_art=json.loads((ROOT/'assets/icons/marker-opacity.json').read_text())
 marker_texture=next(e for e in entries if e[0]==int(marker_art['texture_hash'],16))
 marker_material=next(e for e in entries if e[0]==int(marker_art['material_hash'],16))
 assert struct.unpack_from('<Q',patch,marker_material[2]+140)[0]==marker_texture[0]
 marker_dds=patch[marker_texture[2]+192:marker_texture[2]+marker_texture[7]]+gpu[marker_texture[4]:marker_texture[4]+marker_texture[9]]
 marker_atlas=Image.open(BytesIO(marker_dds)).convert('RGBA')
 assert json.loads(z.read('manifest.json'))['Guid']!='fe6c0ed7-c93c-4cac-96d3-5d52b2602b37'
# Emulate the single-color material: ignore texture RGB entirely and apply the
# actual Lua bitmap tint to the packaged DDS alpha. The old white-tinted atlas
# fails this regression even though its texture pixels themselves were colored.
def mask_bitmap(part,size,channel='A'):
 lo,hi=part['lo'],part['hi'];tint=part['tint']
 uv=[lo['x'],lo['y'],hi['x'],hi['y']]
 coverage=atlas.crop(tuple(round(t*atlas.width) for t in uv)).getchannel(channel).resize((size,size),Image.Resampling.LANCZOS)
 result=Image.new('RGBA',(size,size),tuple(tint[c] for c in ['r','g','b']))
 result.putalpha(coverage.point(lambda a:round(a*tint['a']/255)));return result
reference=Image.open(ROOT/'assets/icons/atlas.png').convert('RGBA')
# Check every menu opacity against both sampled mask channels, in the ZIP.
card_art=json.loads((ROOT/'assets/icons/card-opacity.json').read_text())
original_masks=Image.open(ROOT/'assets/icons/mask-atlas.png').convert('RGBA')
for definition,packed,is_marker in [(card_art,atlas,False),(marker_art,marker_atlas,True)]:
 o=definition['opacity'];module_icons=module('marker_icons' if is_marker else 'icons')
 for typ,layers in definition['cells'].items():
  assert len(module_icons['cells'][typ])==len(layers)
  for index,layer in enumerate(layers):
   source_uv=art['cells'][typ]['uv'] if is_marker else art['cells'][typ]['layers'][index]['uv']
   original=(reference if is_marker else original_masks).crop(tuple(round(t*512) for t in source_uv)).getchannel('A').resize((88,88),Image.Resampling.LANCZOS)
   for level in range(1,21):
    cell=(level-1)*o['count']+layer['cell'];x=cell%o['columns']*o['pitch']+o['inset'];y=cell//o['columns']*o['pitch']+o['inset']
    actual=packed.crop((x,y,x+o['edge'],y+o['edge']))
    expected=original.point(lambda a:round(a*level/20))
    for channel in ['A','R']:
     mask=actual.getchannel(channel)
     assert abs(mask.getextrema()[1]-expected.getextrema()[1])<=8,(typ,level,channel,mask.getextrema(),expected.getextrema())
     assert ImageStat.Stat(ImageChops.difference(expected,mask)).mean[0]<4,(typ,level,channel)
print('PASS: packaged card/marker icon coverage at every 5% step, both alpha and RGB mask channels; all native artwork retained')
max_error=0
for typ,sample in icon_samples.items():
 cell=art['cells'][typ];assert len(sample)==len(cell['layers'])
 source=reference.crop(tuple(round(t*512) for t in cell['uv']))
 for size in [24,32,48]:
  actual=Image.new('RGBA',(size,size))
  for _,part in sorted(sample.items()):actual.alpha_composite(mask_bitmap(part,size))
  pixels=list(actual.get_flattened_data())
  assert sum(a>220 and g>r+20 and g>b+20 for r,g,b,a in pixels)>5,(typ,'missing green')
  # The laser's very thin white barrel has only two opaque pixels at 24px.
  assert sum(a>220 and min(r,g,b)>220 for r,g,b,a in pixels)>0,(typ,'missing white')
  bg=Image.new('RGBA',(size,size),(16,23,25,255))
  expected=Image.alpha_composite(bg,source.resize((size,size),Image.Resampling.LANCZOS)).convert('RGB')
  rendered=Image.alpha_composite(bg,actual).convert('RGB')
  error=max(ImageStat.Stat(ImageChops.difference(expected,rendered)).mean);max_error=max(max_error,error)
  assert error<4,(typ,size,error,'layer colors/coverage differ from native SVG raster')
  red_mask=Image.new('RGBA',(size,size))
  for _,part in sorted(sample.items()):red_mask.alpha_composite(mask_bitmap(part,size,'R'))
  red_rendered=Image.alpha_composite(bg,red_mask).convert('RGB')
  assert max(ImageStat.Stat(ImageChops.difference(expected,red_rendered)).mean)<4,(typ,'RGB coverage differs')
print(f'PASS: packaged mask-only shader simulation preserves green/white for all 10 icons at 24/32/48px; max mean channel error {max_error:.2f}/255')
# Test actual supported loader discovery against our packaged archive.
spec=importlib.util.spec_from_file_location('archive',ROOT.parent/'BingusSharedLoader/scripts/archive.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
assert a.resource_hash(r['entry'])==int(r['resource'],16)
p=ROOT/'build/9ba626afa44a3aa3.patch_0';p.write_bytes(patch)
escaped=''.join('\\%03d'%v for v in struct.pack('<Q',int(r['resource'],16)))
hashfn=l.eval('function(s) assert(s=="'+r['entry']+'");return "'+escaped+'" end')
for version in ['v15','v18']:
 discovery=l.execute(subprocess.check_output(['git','show',version+':src/discover.lua'],cwd=ROOT.parent/'BingusSharedLoader',text=True))
 entries,warnings=discovery.scan(l.table_from([str(p)]),hashfn,l.globals().io.open)
 assert list(entries.values())==[r['entry']] and len(warnings)==0
print('PASS: actual BSL v15/v18 discovery; unique addon resource/manifest; ZIP integrity; no native memory writes')
subprocess.run([sys.executable,str(ROOT/'tests/verify_hud.py')],check=True)
subprocess.run([sys.executable,str(ROOT/'tests/verify_markers.py')],check=True)
# Preview uses actual renderer output; it is explicitly a simulated layout.
parts=[]
for _,gui in e['guis'].items():
 for _,v in gui['parts'].items():
  c=v['tint'];color=f'rgb({c["r"]},{c["g"]},{c["b"]})';opacity=c['a']/255
  x,y=v['at']['x'],1080-v['at']['y']
  if v['kind']=='rect':
   w,h=v['size']['x'],v['size']['y'];parts.append((v['at']['z'],f'<rect x="{x}" y="{y-h}" width="{w}" height="{h}" fill="{color}" opacity="{opacity}"/>'))
  elif v['kind']=='bitmap':
   icon=mask_bitmap(v,88)
   png=BytesIO();icon.save(png,format='PNG');url='data:image/png;base64,'+base64.b64encode(png.getvalue()).decode()
   w,h=v['size']['x'],v['size']['y']
   parts.append((v['at']['z'],f'<image x="{x}" y="{y-h}" width="{w}" height="{h}" href="{url}"/>'))
  else:parts.append((v['at']['z'],f'<text x="{x}" y="{y}" font-size="{v["size"]}" fill="{color}" opacity="{opacity}">{html.escape(v["text"])}</text>'))
svg='<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080"><rect width="1920" height="1080" fill="#1b282a"/><g font-family="Arial,sans-serif"><text x="70" y="80" font-size="26" fill="#eee">SENTRY HUD — SIMULATED LAYOUT / NOT A GAME CAPTURE</text><rect x="43.2" y="932.4" width="318.6" height="45" fill="#111c20"/><text x="55" y="962" font-size="14" fill="#ddd">PLAYER STATUS / WEAPON</text><rect x="43.2" y="977.4" width="373.5" height="45" fill="#111c20"/><text x="55" y="999" font-size="12" fill="#ddd">HEALTH / CONSUMABLES</text><rect x="55" y="1010" width="180" height="6" fill="#e4d397"/>'+''.join(p for _,p in sorted(parts,key=lambda x:x[0]))+'</g></svg>'
(ROOT/'build/layout-preview.svg').write_text(svg)
print('PREVIEW: build/layout-preview.svg (synthetic, real renderer geometry)')
print('NOT VERIFIED IN GAME: HUD placement; multiplayer/host migration; additional sentry types and beam/arc behavior')

(ROOT/'build/layout-detail.svg').write_text(svg.replace('width="1920" height="1080" viewBox="0 0 1920 1080"','width="1800" height="400" viewBox="0 880 900 200"'))
