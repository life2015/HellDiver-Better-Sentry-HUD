"""Build a separate BSL v15-discoverable addon; no Enemy HP resources replaced."""
import hashlib
import json
from pathlib import Path
import struct
import zipfile

ROOT=Path(__file__).resolve().parents[1]
ENTRY='mods/retrox/sentry_hud'
ARCHIVE='9ba626afa44a3aa3.patch_0'
DISPLAY_NAME='炮台 HUD 优化'
RELEASE=DISPLAY_NAME+' 0.1.0-ui4-BSL15-test.zip'

def resource_hash(name):
    data=name.encode();mask=(1<<64)-1;mix=0xC6A4A7935BD1E995;value=len(data)*mix&mask
    end=len(data)//8*8
    for (word,) in struct.iter_unpack('<Q',data[:end]):
        word=word*mix&mask;word^=word>>47
        value=(value^(word*mix&mask))*mix&mask
    if data[end:]:value=(value^int.from_bytes(data[end:],'little'))*mix&mask
    value^=value>>47;value=value*mix&mask
    return value^(value>>47)

def build():
    embedded=''
    for name in ['bytes','catalog','icons','windows','ownership','reader','hud_anchor','model','presentation','config','controller']:
        binding=name if name in ['bytes','catalog','icons'] else 'make_'+name
        embedded+='local '+binding+'=(function()\n'+(ROOT/'src'/f'{name}.lua').read_text()+'\nend)()\n'
    source=(ROOT/'src/addon.lua').read_text().replace('--[[MODULES]]',embedded)
    out=ROOT/'build';out.mkdir(exist_ok=True)
    (out/'sentry_hud.lua').write_text(source)
    resource=struct.pack('<II',len(source.encode()),2)+source.encode()
    art=ROOT/'assets/icons';icon_manifest=json.loads((art/'manifest.json').read_text())
    resources=sorted([
        (0xA14E8DFA2CD117E2,resource_hash(ENTRY),resource,b''),
        (0xCD4238C6A0C69E32,resource_hash(icon_manifest['texture']),
         (art/'icons.texture.main').read_bytes(),(art/'icons.texture.gpu_resources').read_bytes()),
        (0xEAC0B497876ADEDF,resource_hash(icon_manifest['material']),
         (art/'icons.material.main').read_bytes(),b''),
    ])
    kinds=sorted(set(r[0] for r in resources));count=len(resources)
    start=(72+32*len(kinds)+80*count+15)&~15
    archive=bytearray(start);gpu=bytearray();entries=bytearray();resource_report=[]
    for index,(kind,name,data,pixels) in enumerate(resources):
        at,gat=len(archive),len(gpu)
        entries+=struct.pack('<7Q6I',name,kind,at,0,gat,0,0,len(data),0,len(pixels),16,64,index)
        archive+=data;archive+=b'\0'*(-len(archive)%16)
        gpu+=pixels;gpu+=b'\0'*(-len(gpu)%64)
        resource_report.append({'name':f'{name:016x}','type':f'{kind:016x}',
                                'main_offset':at,'main_size':len(data),'gpu_offset':gat,'gpu_size':len(pixels)})
    header=struct.pack('<III20sQQ24s',0xF0000011,len(kinds),count,b'',len(archive),0,b'')
    types=b''.join(struct.pack('<IIQIIII',0,0,kind,sum(r[0]==kind for r in resources),0,16,64) for kind in kinds)
    archive[:72+len(types)+len(entries)]=header+types+entries
    archive,gpu=bytes(archive),bytes(gpu)
    manifest={'Version':1,'Guid':'75e2be2c-9110-40a1-bb29-a5b634a84e28','Name':DISPLAY_NAME,
        'Description':'Shows locally owned automatic sentry health, ammo, deployment countdown and observed firing beside the player panel. Expired or retracting sentries disappear. BSL v15 / API 1.',
        'Options':[{'Name':DISPLAY_NAME,'Description':'Automatic sentry HP, ammunition, deployment countdown and observed firing status.','Include':['Addon']}]}
    files={f'Addon/{ARCHIVE}':archive,f'Addon/{ARCHIVE}.stream':b'',f'Addon/{ARCHIVE}.gpu_resources':gpu,
        'manifest.json':(json.dumps(manifest,indent=2)+'\n').encode()}
    for name in ['README.txt','THIRD_PARTY.txt','sentry_hud.cfg.example','dependencies.json']:files[name]=(ROOT/name).read_bytes()
    dist=ROOT/'dist';dist.mkdir(exist_ok=True)
    with zipfile.ZipFile(dist/RELEASE,'w',zipfile.ZIP_DEFLATED) as z:
        for name,data in sorted(files.items()):
            i=zipfile.ZipInfo(name,(2026,10,3,0,0,0));i.compress_type=zipfile.ZIP_DEFLATED;i.external_attr=0o100644<<16;z.writestr(i,data)
    report={'entry':ENTRY,'resource':f'{resource_hash(ENTRY):016x}','source_sha256':hashlib.sha256(source.encode()).hexdigest(),
        'zip_sha256':hashlib.sha256((dist/RELEASE).read_bytes()).hexdigest(),'runtime_loader_minimum':15,
        'live_data_verified':True,'ownership_verified':True,'lifetime_data_verified':True,'in_game_hud_verified':False,'release':RELEASE,
        'resources':resource_report,'patch_sha256':hashlib.sha256(archive).hexdigest(),
        'gpu_sha256':hashlib.sha256(gpu).hexdigest(),'native_icons':len(icon_manifest['cells'])}
    (out/'build-report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(dist/RELEASE)
if __name__=='__main__':build()
