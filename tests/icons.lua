return function(make_engine,make_presentation,make_config,icons,catalog,make_model)
    local E=make_engine();local ui=make_presentation(E.sr,E.font_ids,nil,icons)
    local options=make_config('anchor_player=0')
    local function item(typ) return {type=typ,name=catalog[typ].name,hp=600,max=600,ammo=20,status='READY',remaining=10} end
    local types={};for typ in pairs(catalog)do types[#types+1]=typ;assert(icons.cells[typ],'missing native icon') end
    table.sort(types);assert(#types==10)
    local id,samples=nil,{}
    for _,typ in ipairs(types) do
        E.next_frame();ui:draw({item(typ)},options)
        local current=ui.bitmaps['1:icon:1'];assert(current and (not id or current==id),'bitmap not reused')
        id=current;local part=ui.gui.parts[id];local cell=icons.cells[typ];local sample={}
        local name=ui.gui.parts[ui.texts['1:name5']];local status=ui.gui.parts[ui.texts['1:status5']]
        assert(#cell>=2 and #cell<=3)
        for index,layer in ipairs(cell) do
            local p=ui.gui.parts[ui.bitmaps['1:icon:'..index]];assert(p)
            local uv,rgb=layer.uv,layer.color
            assert(p.lo.x==uv[1] and p.lo.y==uv[2] and p.hi.x==uv[3] and p.hi.y==uv[4])
            assert(p.tint.r==rgb[1] and p.tint.g==rgb[2] and p.tint.b==rgb[3] and p.tint.a==255)
            assert(p.at.z==951+index and p.at.z>ui.gui.parts[ui.rects['1:bg']].at.z and p.at.z<name.at.z)
            assert(p.at.x==part.at.x and p.at.y==part.at.y and p.size.x==part.size.x)
            sample[index]=p
        end
        assert(not ui.bitmaps['1:icon:'..(#cell+1)],'stale color layer after type change')
        samples[typ]=sample
        assert(part.at.x+part.size.x<name.at.x and name.at.x+name.size*#name.text*0.58<status.at.x)
        local calls=E.bitmap_calls;E.next_frame();ui:draw({item(typ)},options)
        assert(E.bitmap_calls==calls,'static icon re-uploaded each frame')
    end
    E.width,E.height=2560,1440;E.next_frame();ui:draw({item(types[1]),item(types[2])},options)
    assert(ui.gui.parts[ui.bitmaps['1:icon:1']].size.x==53)
    assert(ui.bitmaps['2:icon:1']);ui:draw({item(types[1])},options)
    for key in pairs(ui.bitmaps) do assert(not key:match('^2:'),'removed row retained a color layer') end
    local unknown=item(types[1]);unknown.type='UNKNOWN';ui:draw({unknown},options)
    assert(not next(ui.bitmaps) and not next(ui.icon_cache) and ui.gui.parts[ui.texts['1:name5']].text==unknown.name)
    ui:draw({item(types[1])},options);assert(ui.bitmaps['1:icon:1'],'stale cache prevented icon recreation')
    ui:hide();assert(not ui.visible)
    ui:draw({item(types[1])},options);assert(ui.visible)
    ui:dispose();assert(not next(ui.bitmaps))
    E=make_engine();E.bitmap_fail=true;ui=make_presentation(E.sr,E.font_ids,nil,icons)
    ui:draw({item(types[1])},options);assert(ui.visible and ui.icon_failed and not next(ui.bitmaps))
    assert(ui.gui.parts[ui.texts['1:hp5']].text=='HP 600 / 600','icons failure hid health')
    E.worlds={};ui:abandon();assert(E.destroyed==0 and not next(ui.bitmaps))
    E=make_engine();E.bitmap_fail_after=1;ui=make_presentation(E.sr,E.font_ids,nil,icons)
    ui:draw({item(types[1])},options)
    assert(E.bitmap_calls==1 and ui.icon_failed and not next(ui.bitmaps) and not next(ui.icon_cache),'partial icon survived layer failure')
    assert(ui.visible and ui.gui.parts[ui.texts['1:hp5']].text=='HP 600 / 600')
    E=make_engine();E.sr.Gui.bitmap_uv=nil;ui=make_presentation(E.sr,E.font_ids,nil,icons)
    ui:draw({item(types[1])},options);assert(ui.visible and not next(ui.bitmaps))
    local s=item(types[1]);s.owner='me';s.identity='one';s.life=0
    local rows=make_model():update({world='w',peer='me',sentries={s}},0)
    assert(rows[1].type==types[1],'native type lost between reader and renderer')
    return samples
end
