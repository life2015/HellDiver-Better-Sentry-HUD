"""Convert the 10 native XAML sentry icons into a standalone BC3 GUI atlas.
Run after extract_icons.ps1, with Pillow and resvg-py installed. No game writes.
The regular addon build uses the generated assets, without these dependencies.
"""
import hashlib
from io import BytesIO
import json
from pathlib import Path
import re
import struct
import xml.etree.ElementTree as ET
from PIL import Image
import resvg_py
from build import resource_hash

ROOT=Path(__file__).resolve().parents[1]
SOURCE_SHA='deda7000592065f14d79d41c5d153ec1041fff7a58d6a607def232add7702eae'
NAMES=[('EF85D6CF58E31D70','StratagemTurretsGatling'),
       ('37CDE43876BA26BB','StratagemTurretsMachinegun'),
       ('54D86057F5DACFB9','StratagemTurretsAutocannon'),
       ('37079568DC86E9C6','StratagemTurretsRocket'),
       ('51A0812E3BCE2D74','StratagemTurretsMortar'),
       ('B2053A1838092F8B','StratagemTurretsMortarStaticfield'),
       ('299C0D3DFD2F0994','StratagemTurretsGassentry'),
       ('820CC3BAFE962858','StratagemTurretFlamethrower'),
       ('56070F36CFFFA8A8','StratagemTurretLaserCannon'),
       ('74599E56F72F9D7E','StratagemEmplacementsTeslatower')]
TEXTURE='mods/retrox/sentry_hud/icons_atlas'
MATERIAL='mods/retrox/sentry_hud/icons_material'

def build():
    raw=(ROOT/'build/stratagem_icons.bin').read_bytes()
    assert hashlib.sha256(raw).hexdigest()==SOURCE_SHA
    size=struct.unpack_from('<I',raw)[0];assert len(raw)==16+size
    tree=ET.fromstring(raw[16:].decode())
    templates={t.attrib.get('{http://schemas.microsoft.com/winfx/2006/xaml}Key'):t for t in tree}
    out=ROOT/'assets/icons';out.mkdir(parents=True,exist_ok=True)
    atlas=Image.new('RGBA',(512,512));cells={}
    for i,(typ,key) in enumerate(NAMES):
        paths=[]
        for p in templates[key].iter():
            if p.tag.split('}')[-1]!='Path':continue
            a=p.attrib;fill=a['Fill'];data=a['Data']
            if fill=='#FF2B2B2B':continue # Remove native square backing; retain actual symbol/colors.
            if a.get('Stretch'):
                # Only MG's rectangular base uses Stretch; its native coordinates
                # already equal the specified dimensions and Canvas position.
                assert data=='F1M88,148h80v28h-80z' and a['Canvas.Left']=='88' and a['Canvas.Top']=='148'
            rule='nonzero' if data.startswith('F1') else 'evenodd'
            data=re.sub(r'^F[01]','',data)
            assert re.fullmatch(r'[MLHVCSQTAZmlhvcsqtaz\d\s.,+\-Ee]+',data)
            if fill.startswith('#FF'):fill='#'+fill[3:]
            paths.append(f'<path d="{data}" fill="{fill}" fill-rule="{rule}"/>')
        assert paths
        svg='<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'+''.join(paths)+'</svg>'
        (out/(typ+'.svg')).write_text(svg+'\n')
        icon=Image.open(BytesIO(resvg_py.svg_to_bytes(svg_string=svg,width=112,height=112,skip_system_fonts=True))).convert('RGBA')
        x,y=(i%4)*128+8,(i//4)*128+8
        atlas.alpha_composite(icon,(x,y));cells[typ]={'key':key,'uv':[x/512,y/512,(x+112)/512,(y+112)/512]}
    atlas.save(out/'atlas.png')
    # Keep the reviewed Stingray texture prefix and DX10 BC3 header, with a full
    # mip chain. DDS data is stored in the archive's GPU companion, like HUD+.
    template=ROOT.parent/'EnemyHPHud/unpacked/hud_plus/COMMON/9ba626afa44a3aa3.patch_2'
    header=bytearray((template/'254deec0e6c38888.texture.main').read_bytes())
    assert len(header)==340 and header[192:196]==b'DDS ' and struct.unpack_from('<I',header,320)[0]==77
    for at,value in [(204,512),(208,512),(212,512*512),(220,10)]:struct.pack_into('<I',header,at,value)
    gpu=bytearray();mip=atlas
    while True:
        buffer=BytesIO();mip.save(buffer,format='DDS',pixel_format='DXT5');encoded=buffer.getvalue()
        assert encoded[:4]==b'DDS ' and encoded[84:88]==b'DXT5'
        expected=max(1,(mip.width+3)//4)*max(1,(mip.height+3)//4)*16
        assert len(encoded)==128+expected;gpu+=encoded[128:]
        if mip.size==(1,1):break
        mip=mip.resize((max(1,mip.width//2),max(1,mip.height//2)),Image.Resampling.LANCZOS)
    # Reuse HUD+'s non-curved icon shader definition under our own resource IDs.
    material=bytearray((template/'1040c4e00c5ab27e.material.main').read_bytes())
    assert hashlib.sha256(material).hexdigest()=='f937fb982c8d53f201f1103f52b1bb04b25c968b73e3c8664aaae5bfb743aa92'
    assert struct.unpack_from('<Q',material,140)[0]==resource_hash('mods/hd2_hud/native_icon_atlas')
    struct.pack_into('<Q',material,140,resource_hash(TEXTURE))
    for name,data in [('icons.texture.main',header),('icons.texture.gpu_resources',gpu),('icons.material.main',material)]:
        (out/name).write_bytes(data)
    decoded=Image.open(BytesIO(header[192:]+gpu)).convert('RGBA');assert decoded.size==atlas.size
    decoded.save(ROOT/'build/icons-decoded.png')
    doc={'source':'content/ui/shared/resources/generated_icons/stratagem_icons','source_sha256':SOURCE_SHA,
         'texture':TEXTURE,'material':MATERIAL,'texture_hash':f'{resource_hash(TEXTURE):016x}',
         'material_hash':f'{resource_hash(MATERIAL):016x}','size':[512,512],'mips':10,'cells':cells,
         'artwork':'Helldivers 2 / Arrowhead Game Studios; native sentry symbols, square background removed',
         'material_basis':'HD2 HUD+ 0.1.13 by DDRK1NG, cell_integrated_reserve_icon (non-curved)'}
    (out/'manifest.json').write_text(json.dumps(doc,indent=2)+'\n')
    lua='-- Generated by scripts/build_icons.py from the current game icon library.\nreturn {\n'
    lua+=f'    material="{doc["material_hash"]}", texture="{doc["texture_hash"]}",\n    cells={{\n'
    for typ,cell in cells.items():lua+='        ["'+typ+'"]={'+','.join(str(n) for n in cell['uv'])+'},\n'
    (ROOT/'src/icons.lua').write_text(lua+'    },\n}\n')
    print('Built',len(cells),'native sentry icons;',len(gpu),'GPU bytes')
if __name__=='__main__':build()
