return function(make_engine,make_presentation,make_config,icons,make_controller,make_model)
    local E=make_engine();local ui=make_presentation(E.sr,E.font_ids,nil,icons)
    local rows={}
    for i=1,12 do rows[i]={name='GATLING',type='EF85D6CF58E31D70',hp=280,max=300,
        ammo=184,status='FIRING',remaining=86.5} end
    local options=make_config('layout=2')
    local function part(key) return ui.gui.parts[ui.rects[key]] end
    for _,size in ipairs({{1280,720},{1920,1080},{2560,1440},{3440,1440},{3840,2160}}) do
        E.width,E.height=size[1],size[2]
        local resolution_scale=math.min(E.width/1920,E.height/1080)
        for _,scale in ipairs({0.5,1,2}) do
            options.scale=scale
            for _,margin in ipairs({0,48,400}) do
                options.right_margin=margin
                for _,offset in ipairs({-450,0,450}) do
                    options.right_vertical_offset=offset
                    E.next_frame();ui:draw(rows,options,nil)
                    assert(ui.visible,'right layout depends on unavailable Player Status')
                    local bg,edge=part('1:bg'),part('1:edge')
                    if offset==0 then
                        local count=0;for k in pairs(ui.rects) do if k:match(':bg$') then count=count+1 end end
                        local height=(count-1)*70*resolution_scale*scale+64*resolution_scale*scale+26*resolution_scale*scale
                        assert(math.abs(bg.at.y+height/2-E.height/2)<=1,'right card group not centered')
                    end
                    assert(math.abs(bg.at.x+bg.size.x-(E.width-margin*resolution_scale))<=1)
                    assert(math.abs(edge.at.x+edge.size.x-(bg.at.x+bg.size.x))<=1,
                        'accent stripe is not on the card right edge')
                    for _,p in pairs(ui.gui.parts) do
                        if p.kind=='rect' then
                            assert(p.at.x>=0 and p.at.y>=0 and p.at.x+p.size.x<=E.width+1 and
                                p.at.y+p.size.y<=E.height+1,'card extends outside viewport')
                        end
                    end
                    local name=ui.gui.parts[ui.texts['1:name5']]
                    local status=ui.gui.parts[ui.texts['1:status5']]
                    assert(name.at.x<status.at.x,'text order mirrored')
                    assert(ui.gui.parts[ui.texts['overflow5']].at.y<E.height,'overflow label off screen')
                end
            end
        end
    end
    -- Switching modes reuses retained GUI parts; no stale stripe or second GUI.
    E.width,E.height=1920,1080;options=make_config('layout=2')
    E.next_frame();ui:draw({rows[1]},options)
    local edge_id=ui.rects['1:edge'];local gui=ui.gui
    assert(not ui.texts['overflow5'] and not ui.rects['2:bg'])
    assert(part('1:bg').at.y+part('1:bg').size.y/2==540,'single sentry not vertically centered')
    ui:draw({rows[1],rows[2]},options)
    assert(part('1:bg').at.y+(part('2:bg').at.y+part('2:bg').size.y-part('1:bg').at.y)/2==540,'two sentries not centered')
    ui:draw({rows[1]},options)
    options.layout=1;options.anchor_player=1
    E.next_frame();ui:draw({rows[1]},options,{right=463,bottom=64,scale=1,shown=1})
    assert(ui.rects['1:edge']==edge_id and ui.gui==gui)
    assert(part('1:bg').at.x==475 and part('1:edge').at.x==475)
    options.layout=2
    E.next_frame();ui:draw({rows[1]},options,{shown=0})
    assert(ui.visible and part('1:bg').at.x==1598 and part('1:edge').at.x==1870)
    options.layout=3;options.x=540;options.y=48
    E.next_frame();ui:draw({rows[1]},options)
    assert(part('1:bg').at.x==540 and part('1:edge').at.x==540)
    options.enabled=0;ui:draw(rows,options);assert(not ui.visible)
    options.enabled=1;ui:draw(rows,options);assert(ui.visible)
    E.width,E.height=100,50;options.layout=2;options.scale=2
    -- At tiny sizes the resolution scaling still keeps geometry finite.
    E.next_frame();ui:draw({rows[1]},options)

    -- Right layout never samples Player Status; disabling stops reads, enabling
    -- resumes immediately with a fresh firing baseline and no stale rows.
    E=make_engine();local menu=false;E.sr.Window={show_cursor=function()return menu end}
    local reads,hides,draws=0,0,0
    local map=false;local bad_map=false
    local coptions=make_config('layout=2')
    local reader={sample=function()
        reads=reads+1
        return {peer='me',world='main',sentries={{identity='one',name='GATLING',owner='me',
            hp=100,max=300,ammo=50,remaining=100,life=0}}}
    end}
    local C=make_controller(E.sr,{time=function()return 0 end},reader,make_model(),
        {hide=function()hides=hides+1 end,draw=function(_,r,o,a)
            draws=draws+1;assert(#r==1 and r[1].status=='READY' and a==nil)
        end},coptions,{verified=true},function()end,
        {sample=function()error('right layout read Player Status')end},nil,
        {map_open=function()if bad_map then error('map unreadable')end;return map end})
    C:tick();assert(reads==1 and draws==1)
    coptions.enabled=0;C:tick();C:tick();assert(reads==1 and #C.rows==0)
    coptions.enabled=1;C:tick();assert(reads==2 and draws==2)
    menu=true;C:tick();assert(#C.rows==0 and draws==2 and hides>0)
    menu=false;C:tick();assert(reads==3 and draws==3)
    map=true;C:tick();assert(draws==3 and #C.rows==1,'map did not hide cards independently of tracking')
    map=nil;C:tick();assert(draws==3,'unknown map state rendered')
    bad_map=true;C:tick();assert(draws==3,'failed map read rendered')
    bad_map=false;map=false;C:tick();assert(draws==4,'closing map did not restore cards')
end
