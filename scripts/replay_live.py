"""Read-only replay of locally retained, non-distributed diagnostic snapshots."""
import base64
from datetime import datetime
import json
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
l=LuaRuntime(unpack_returned_tuples=True,encoding='latin-1')
def module(name):return l.execute((ROOT/'src'/f'{name}.lua').read_text())
B=module('bytes');catalog=module('catalog');factory=module('reader');owner_factory=module('ownership')
exe=(ROOT.parent/'EnemyHPHud/build/crash-20261002/crashed-exe-memory.bin').read_bytes()
game=(ROOT/'build/game-code.bin').read_bytes()
model=module('model')(); previous={};stable_order=None;sample_count=0;observed_shots=0;types=set();hidden_expired=0
for path in sorted((Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'build/live-lifetime').glob('*sample-*.json'),key=lambda p:int(p.stem.split('-')[-1])):
 s=json.loads(path.read_text(encoding='utf-8-sig'));memory={}
 chunks=sorted(((int(k),base64.b64decode(v)) for k,v in s['memory'].items()),key=lambda x:-len(x[1]))
 for a,b in chunks:
  for i,v in enumerate(b):memory[a+i]=v
 def read(at,n):
  at,n=int(at),int(n)
  if all(at+i in memory for i in range(n)):return bytes(memory[at+i] for i in range(n))
  for base,image in [(s['exe'],exe),(s['game'],game)]:
   # Only code fallback: never replace uncaptured live data by an old module dump.
   off=at-base
   if 0x1000<=off and off+n<0x1600000:return image[off:off+n]
  print('MISSING',hex(at),'size',n,'game+',hex(at-s['game']),'exe+',hex(at-s['exe']))
  return None
 api=l.table_from({'game':s['game'],'exe':s['exe'],'read':read})
 reader=factory(api,B,catalog,owner_factory(B))
 result=reader.sample(reader,'captured-world')
 rows=list(result['sentries'].values())
 print(path.name,[(x['name'],x['hp'],x['max'],x['ammo'],x['reserve'],x['remaining'],x['retiring'],x['owner']==result['peer']) for x in rows])
 assert rows and all(x['owner']==result['peer'] for x in rows)
 now=datetime.fromisoformat(s['utc']).timestamp()
 shown=list(model.update(model,result,now).values())
 order=[r['key'] for r in shown]
 if stable_order is not None:assert [k for k in order if k in stable_order]==[k for k in stable_order if k in order], 'health array reorder moved HUD rows'
 stable_order=order
 expected={r['entity']:r for r in s['sentries']}
 for row in rows:
  timer=expected[row['entity']].get('lifetime')
  if timer:
   assert abs(row['remaining']-timer['remaining'])<0.0001
   expired=timer['remaining']<=0 or timer['retract']>=0
   assert (row['identity'] not in order)==expired
   if expired:hidden_expired+=1
 for row in shown:assert row['ammo'] is not None
 engine=l.execute((ROOT/'tests/engine.lua').read_text())
 ui=module('presentation')(engine['sr'],engine['font_ids'])
 ui.draw(ui,l.table_from(shown),module('config')('anchor_player=0'))
 for i,row in enumerate(shown,1):
  label=ui['gui']['parts'][ui['texts'][f'{i}:time5']]['text']
  import math
  sec=math.ceil(row['remaining'])
  assert label==f'TIME {sec//60:02d}:{sec%60:02d}'

 for row in shown:
  key=row['key'];types.add(row['name'])
  if key in previous and row['ammo']<previous[key]:
   assert row['status']=='FIRING';observed_shots+=previous[key]-row['ammo']
  previous[key]=row['ammo']
 sample_count+=1
assert sample_count>0
assert hidden_expired>=2, 'expiry sequence missing from replay'
print('PASS:',sample_count,'live snapshots;',hidden_expired,'expired/retracting rows hidden;',observed_shots,'observed ammo decreases; stable multi-sentry ordering; types:',sorted(types))
(ROOT/'build/live-replay-report.json').write_text(json.dumps({'samples':sample_count,'observed_ammo_decrease':observed_shots,'expired_rows_hidden':hidden_expired,'types':sorted(types),'in_game_hud_verified':False},indent=2)+'\n')
