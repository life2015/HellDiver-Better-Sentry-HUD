"""Draw both layouts from the actual Lua GUI calls; synthetic input, no game capture."""
from pathlib import Path
from io import BytesIO
from PIL import Image, ImageDraw, ImageFont
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
lua = LuaRuntime(unpack_returned_tuples=True)


def module(name):
    return lua.execute((ROOT / 'src' / (name + '.lua')).read_text())


dds = (ROOT / 'assets/icons/card-opacity.texture.main').read_bytes()[192:]
dds += (ROOT / 'assets/icons/card-opacity.texture.gpu_resources').read_bytes()
atlas = Image.open(BytesIO(dds)).convert('RGBA')
rows = lua.table_from([
    dict(name='GATLING', type='EF85D6CF58E31D70', hp=280, max=300, ammo=184,
         status='FIRING', remaining=86.5),
    dict(name='ROCKET', type='37079568DC86E9C6', hp=600, max=600, ammo=22,
         reserve=1, status='READY', remaining=9.5),
], recursive=True)
anchor = lua.table_from(dict(right=463, bottom=64, scale=1, shown=1))


def render(layout):
    engine = lua.execute((ROOT / 'tests/engine.lua').read_text())
    ui = module('presentation')(engine['sr'], engine['font_ids'], None, module('icons'))
    options = module('config')(f'layout={layout}')
    ui.draw(ui, rows, options, anchor)
    canvas = Image.new('RGBA', (1920, 1080), '#1b282a')
    draw = ImageDraw.Draw(canvas)
    draw.line((948, 540, 972, 540), fill='#64716d', width=2)
    draw.line((960, 528, 960, 552), fill='#64716d', width=2)
    draw.rounded_rectangle((48, 916, 463, 1016), radius=3, fill='#101b20')
    draw.text((62, 936), 'PLAYER STATUS', font=ImageFont.truetype(FONT, 16), fill='#aeb6b2')
    draw.rectangle((62, 988, 283, 994), fill='#ddc770')
    for part in sorted(ui['gui']['parts'].values(), key=lambda p: p['at']['z']):
        x, y = part['at']['x'], 1080 - part['at']['y']
        tint = part['tint']
        rgba = tuple(round(tint[c]) for c in ['r', 'g', 'b', 'a'])
        layer = Image.new('RGBA', canvas.size)
        d = ImageDraw.Draw(layer)
        if part['kind'] == 'rect':
            w, h = part['size']['x'], part['size']['y']
            if w and h:
                d.rectangle((x, y-h, x+w-1, y-1), fill=rgba)
        elif part['kind'] == 'bitmap':
            w, h = part['size']['x'], part['size']['y']
            lo, hi = part['lo'], part['hi']
            mask = atlas.crop(tuple(round(v*atlas.width) for v in
                [lo['x'], lo['y'], hi['x'], hi['y']])).getchannel('A')
            tile = Image.new('RGBA', (w, h), rgba)
            tile.putalpha(mask.resize((w, h), Image.Resampling.LANCZOS))
            layer.paste(tile, (x, y-h))
        else:
            font = ImageFont.truetype(FONT, max(1, round(part['size'])))
            d.text((x, y), part['text'], font=font, fill=rgba, anchor='ls')
        canvas = Image.alpha_composite(canvas, layer)
    bg = ui['gui']['parts'][ui['rects']['1:bg']]
    x, bottom = bg['at']['x'], bg['at']['y']
    detail = canvas.crop((x-8, 1080-bottom-142, x+282, 1080-bottom+8))
    return canvas.convert('RGB'), detail.convert('RGB')


out = ROOT / 'build'
out.mkdir(exist_ok=True)
comparison = Image.new('RGB', (1920, 980), '#111b1e')
draw = ImageDraw.Draw(comparison)
for layout, label in [(1, '01  BESIDE PLAYER STATUS'), (2, '02  SCREEN RIGHT')]:
    screen, detail = render(layout)
    screen.save(out / f'layout-{layout}-screen.png')
    offset = (layout-1)*960
    draw.text((offset+30, 20), label, font=ImageFont.truetype(FONT, 25), fill='#ececde')
    comparison.paste(screen.resize((960, 540), Image.Resampling.LANCZOS), (offset, 62))
    comparison.paste(detail.resize((580, 300), Image.Resampling.LANCZOS), (offset+190, 640))
    draw.text((offset+30, 609), 'CARD DETAIL / 2x', font=ImageFont.truetype(FONT, 16), fill='#a5afad')
draw.line((960, 12, 960, 944), fill='#41504f', width=1)
draw.text((30, 950), 'SIMULATED LAYOUT - actual Lua renderer, synthetic sentry data; not a game screenshot.',
          font=ImageFont.truetype(FONT, 17), fill='#a5afad')
comparison.save(out / 'layout-menu-comparison.png')
print(out / 'layout-menu-comparison.png')
