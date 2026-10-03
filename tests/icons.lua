return function(make_engine,make_presentation,make_config,icons,catalog,make_model)
    local E=make_engine();local ui=make_presentation(E.sr,E.font_ids,nil,icons)
    local options=make_config('anchor_player=0')
    local function item(typ) return {type=typ,name=catalog[typ].name,hp=600,max=600,ammo=20,status='READY',remaining=10} end
    local types={};for typ in pairs(catalog)do types[#types+1]=typ;assert(icons.cells[typ],'missing native icon') end
    table.sort(types);assert(#types==10)
    local id,seen
    for _,typ in ipairs(types) do
        E.next_frame();ui:draw({item(typ)},options)
        local current=ui.bitmaps['1:icon'];assert(current and (not id or current==id),'bitmap not reused')
        id=current;local part=ui.gui.parts[id];local cell=icons.cells[typ]
        assert(part.lo.x==cell[1] and part.lo.y==cell[2] and part.hi.x==cell[3] and part.hi.y==cell[4])
        assert(part.at.z>ui.gui.parts[ui.rects['1:bg']].at.z)
        local name=ui.gui.parts[ui.texts['1:name5']];local status=ui.gui.parts[ui.texts['1:status5']]
        assert(part.at.x+part.size.x<name.at.x and name.at.x+name.size*#name.text*0.58<status.at.x)
        local calls=E.bitmap_calls;E.next_frame();ui:draw({item(typ)},options)
        assert(E.bitmap_calls==calls,'static icon re-uploaded each frame')
    end
    E.width,E.height=2560,1440;E.next_frame();ui:draw({item(types[1]),item(types[2])},options)
    assert(ui.gui.parts[ui.bitmaps['1:icon']].size.x==32)
    assert(ui.bitmaps['2:icon']);ui:draw({item(types[1])},options);assert(not ui.bitmaps['2:icon'])
    local unknown=item(types[1]);unknown.type='UNKNOWN';ui:draw({unknown},options)
    assert(not ui.bitmaps['1:icon'] and ui.gui.parts[ui.texts['1:name5']].text==unknown.name)
    ui:draw({item(types[1])},options);ui:hide();assert(not ui.visible)
    ui:draw({item(types[1])},options);assert(ui.visible)
    ui:dispose();assert(not next(ui.bitmaps))
    E=make_engine();E.bitmap_fail=true;ui=make_presentation(E.sr,E.font_ids,nil,icons)
    ui:draw({item(types[1])},options);assert(ui.visible and ui.icon_failed and not next(ui.bitmaps))
    assert(ui.gui.parts[ui.texts['1:hp5']].text=='HP 600 / 600','icons failure hid health')
    E.worlds={};ui:abandon();assert(E.destroyed==0 and not next(ui.bitmaps))
    E=make_engine();E.sr.Gui.bitmap_uv=nil;ui=make_presentation(E.sr,E.font_ids,nil,icons)
    ui:draw({item(types[1])},options);assert(ui.visible and not next(ui.bitmaps))
    local s=item(types[1]);s.owner='me';s.identity='one';s.life=0
    local rows=make_model():update({world='w',peer='me',sentries={s}},0)
    assert(rows[1].type==types[1],'native type lost between reader and renderer')
end
