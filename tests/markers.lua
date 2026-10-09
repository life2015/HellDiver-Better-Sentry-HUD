return function(make_engine,make_markers,presentation,config,icons,controller,model)
    local E=make_engine()
    local meta={}
    local V={}
    setmetatable(V,{__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},meta)end})
    meta.__sub=function(a,b)return V(a.x-b.x,a.y-b.y,a.z-b.z)end
    V.x=function(p)return p.x end;V.y=function(p)return p.y end;V.z=function(p)return p.z end
    V.dot=function(a,b)return a.x*b.x+a.y*b.y+a.z*b.z end
    E.sr.Vector3=V
    local camera_calls=0;local camera_missing=false;local view_missing=false
    local eye={x=0,y=0,z=0};local yaw=0;local zoom=1
    local camera_list={'map1','broken','opposite','camera','map2'}
    E.sr.World.units_by_resource=function(world,name)
        assert(world=='main' and name=='core/units/camera');camera_calls=camera_calls+1
        return camera_missing and {} or camera_list
    end
    E.sr.World.debug_camera_pose=function()
        return {at=V(eye.x,eye.y,eye.z),fwd=V(math.sin(yaw),math.cos(yaw),0)}
    end
    E.sr.Unit={camera=function(unit)return unit end}
    E.sr.Matrix4x4={translation=function(p)return p.at end,forward=function(p)return p.fwd end}
    local projected_target,projected_point
    local function project(p)
        local dx,dy,dz=p.x-eye.x,p.y-eye.y,p.z-eye.z
        local right=dx*math.cos(yaw)-dy*math.sin(yaw)
        local depth=dx*math.sin(yaw)+dy*math.cos(yaw)
        return V(E.width/2+right/depth*E.height/2*zoom,E.height/2+dz/depth*E.height/2*zoom,0),depth
    end
    E.sr.Camera={world_pose=function(cam)
        if cam=='broken' then error('stale camera') end
        if cam=='camera' and not view_missing then return E.sr.World.debug_camera_pose() end
        if cam=='opposite' then return {at=V(eye.x,eye.y,eye.z),fwd=V(-math.sin(yaw),-math.cos(yaw),0)} end
        return {at=V(0,0,501),fwd=V(0,0,-1)}
    end,world_to_screen=function(cam,p,window,viewport)
        assert(cam=='camera','selected a map/preview camera instead of the current view')
        assert(window==nil and viewport.x==E.width and viewport.y==E.height,'projection/GUI viewport mismatch')
        projected_target={x=p.x,y=p.y,z=p.z};local depth
        projected_point,depth=project(p)
        -- HD2 returns reverse-Z clip depth, not distance in metres.
        return projected_point,0.05/depth
    end}
    local point={x=0,y=30,z=0};local map=false;local bad=false
    local positions={sample=function()if bad then error('stale entity')end;return point end,
        map_open=function()return map end}
    local M=make_markers(E.sr,positions,presentation,icons,E.font_ids)
    local row={key='sentry-a',name='MACHINE GUN',type='37CDE43876BA26BB',hp=300,max=600,
        ammo=262,remaining=20}
    local options=config('layout=2')
    local now=0
    local function draw()E.next_frame();M:draw({row},options,'main',now)end
    local function rect(key)return M.ui.gui.parts[M.ui.rects[row.key..':'..key]]end
    local function distance_label()
        local key=row.key..':distance'
        local part=M.ui.gui.parts[M.ui.texts[key..5]]
        local dx,dy,dz=point.x-eye.x,point.y-eye.y,point.z-eye.z
        assert(part and part.text==string.format('%d m',math.floor(math.sqrt(dx*dx+dy*dy+dz*dz)+0.5)),
            'distance is not the rounded 3D distance from the active player view')
        local metrics=M.ui.metrics[key]
        local bar=rect('hptrack')
        assert(math.abs(part.at.x+metrics.left+metrics.width/2-(bar.at.x+bar.size.x/2))<=1.5,
            'distance label is not centered')
        assert(part.at.y<bar.at.y-3,'distance label is not below the bars')
        assert(part.tint.a==math.floor(235*options.marker_opacity/100+0.5),'distance opacity differs from bars')
    end
    local function anchored()
        assert(projected_target.x==point.x and projected_target.y==point.y and projected_target.z==point.z,
            'projection target is offset from the deployment point')
        local part=M.ui.gui.parts[M.ui.bitmaps[row.key..':icon:1']]
        assert(math.abs(part.at.x+part.size.x/2-projected_point.x)<=1 and
            math.abs(part.at.y+part.size.y/2-projected_point.y)<=1,
            'icon center is not anchored to the projected deployment point')
    end
    draw();assert(M.ui.visible and rect('ammounknown0'))
    assert(rect('hpfill').tint.a==141 and rect('hptrack').tint.a==33 and
        rect('ammounknown0').tint.a==63,'marker bars did not apply 60% opacity')
    camera_list={'map2','camera','opposite','map1','broken'};draw();assert(M.ui.visible)
    view_missing=true;draw();assert(not M.ui.visible,'fell back to an unrelated camera')
    view_missing=false;draw();assert(M.ui.visible)
    assert(not M.ui.rects['sentry-a:bg'],'minimal marker retained panel')
    assert(M.ui.gui.parts[M.ui.texts[row.key..':distance5']].text=='30 m')
    options.marker_show_distance=0;draw();assert(next(M.ui.texts)==nil,'distance toggle left text visible')
    options.marker_show_distance=1;draw();assert(M.ui.texts[row.key..':distance5'])
    assert(not M.ui.rects['sentry-a:ammofill'],'fabricated a capacity for a ship-upgraded magazine')
    assert(math.abs(rect('hpfill').size.x/rect('hptrack').size.x-0.5)<0.02)
    -- Feed the actual model's observed baseline through the marker renderer.
    local original=row;local tracked=model()
    local observation={identity=row.key,owner='me',name=row.name,type=row.type,hp=300,max=600,
        life=0,remaining=20,ammo=750}
    local snapshot={world='main',peer='me',sentries={observation}}
    row=tracked:update(snapshot,0)[1];draw()
    assert(rect('ammofill').size.x==rect('ammotrack').size.x,'first observed count did not fill the bar')
    observation.ammo=375;row=tracked:update(snapshot,1)[1];draw()
    assert(rect('ammofill').size.x==rect('ammotrack').size.x/2,'consumption did not shrink the observed-ammo bar')
    assert(row.status=='FIRING' and rect('ammofill').tint.a==141)
    local ammo_tint=rect('ammofill').tint
    assert(ammo_tint.r==221 and ammo_tint.g==199 and ammo_tint.b==112,'ammo does not match FIRING accent')
    local function dot()
        local count=0
        local icon=M.ui.gui.parts[M.ui.bitmaps[row.key..':icon:1']]
        for key,id in pairs(M.ui.rects) do
            if key:find(row.key..':firing:',1,true)==1 then
                count=count+1
                local part=M.ui.gui.parts[id]
                assert(part.tint.r==100 and part.tint.g==220 and part.tint.b==125)
                assert(part.tint.a==math.floor(255*options.marker_opacity/100+0.5),'dot ignored marker opacity')
                assert(part.at.x>=icon.at.x+icon.size.x/2 and part.at.y<icon.at.y+icon.size.y/2,
                    'firing dot is not at the bottom right of the icon')
                assert(part.at.y>rect('hptrack').at.y+rect('hptrack').size.y,'dot overlaps health bar')
                assert(part.at.z>icon.at.z and part.size.x>0 and part.size.y==1)
            end
        end
        assert(count>0,'firing sentry has no green dot')
    end
    dot()
    for _,time in ipairs({0.2,0.4,2.1,9.9}) do
        now=time;draw();dot()
        assert(rect('ammofill').tint.a==141 and rect('ammofill').size.x==20,'ammo bar still flashes')
        assert(rect('hpfill').tint.a==141 and rect('hpfill').tint.r==255)
    end
    row=tracked:update(snapshot,1.4)[1];draw()
    assert(row.status=='READY' and not rect('firing:0'),'stopped sentry retained firing dot')
    for _,status in ipairs({'EMPTY','READY','UNKNOWN'}) do
        row.status=status;draw();assert(not rect('firing:0'))
    end
    row.status='FIRING';draw();dot()
    M:hide();row.status='READY';draw();assert(not rect('firing:0'),'hidden marker retained stale firing dot')
    row=original;draw()
    for _,id in pairs(M.ui.bitmaps)do
        local tint=M.ui.gui.parts[id].tint
        assert(tint.r==255 and tint.g==255 and tint.b==255 and tint.a==255,'marker icon tint must be white/full alpha for the baked 60% texture')
    end
    -- Each baked silhouette includes all native paths in a single bitmap.
    for typ,layers in pairs(icons.cells)do
        row.type=typ;draw();local count=0;local expected=#layers;assert(expected==1)
        for _ in pairs(M.ui.bitmaps)do count=count+1 end
        assert(count==expected,'native sentry body/base was stripped')
        for index,layer in ipairs(layers)do
            local part=M.ui.gui.parts[M.ui.bitmaps[row.key..':icon:'..index]]
            local o=icons.opacity;local cell=11*o.count+layer.cell
            assert(part.lo.x==((cell%o.columns)*o.pitch+o.inset)/o.size and
                part.hi.y==(math.floor(cell/o.columns)*o.pitch+o.inset+o.edge)/o.size)
            assert(part.tint.r==255 and part.tint.g==255 and part.tint.b==255 and part.tint.a==255)
        end
    end
    row.type='37CDE43876BA26BB'
    local old_part=M.ui.gui.parts[M.ui.bitmaps[row.key..':icon:1']]
    local old_u,old_v=old_part.lo.x,old_part.lo.y
    row.status='FIRING'
    options.marker_opacity=100;draw();dot()
    local part=M.ui.gui.parts[M.ui.bitmaps[row.key..':icon:1']]
    assert((part.lo.x~=old_u or part.lo.y~=old_v) and rect('hpfill').tint.a==235)
    assert(options.hud_opacity==100,'marker opacity changed cards')
    options.marker_opacity=0;draw();assert(not M.ui.visible)
    options.marker_opacity=60;draw();dot();assert(M.ui.visible and rect('hpfill').tint.a==141)
    anchored();distance_label()
    local before=rect('hptrack').at.x;point.x=4;draw();anchored()
    assert(rect('hptrack').at.x>before,'marker did not follow unit')
    -- Independent camera translation, yaw, zoom and target elevation change the
    -- projected location; the icon must stay on that location in every frame.
    for _,scene in ipairs({{2,-10,1,0.1,1},{-3,2,2,-0.2,1.5},{1,-25,0,0.25,0.7}})do
        eye={x=scene[1],y=scene[2],z=scene[3]};yaw=scene[4];zoom=scene[5]
        point.z=4;draw();assert(M.ui.visible);anchored();distance_label()
    end
    eye={x=0,y=0,z=0};yaw=0;zoom=1;point.z=0
    local old_gui=M.ui.gui
    for _,size in ipairs({{1280,720},{1920,1080},{2560,1440},{3440,1440},{3840,2160}})do
        E.width,E.height=size[1],size[2]
        for _,scale in ipairs({0.5,1,2})do
            options.marker_scale=scale;draw();assert(M.ui.visible);anchored();dot();distance_label()
        end
    end
    E.width,E.height=1920,1080;options.marker_scale=1;draw()
    assert(M.ui.gui==old_gui,'unnecessarily recreated marker GUI')
    row.ammo=0;draw();assert(rect('ammofill').size.x==0 and not M.ui.rects['sentry-a:ammounknown0'])
    -- Future verified capacity supports filled bars without changing projection.
    row.ammo=50;row.ammo_max=100;draw();assert(math.abs(rect('ammofill').size.x/40-0.5)<0.02)
    row.ammo_max=nil;row.ammo=nil;draw();assert(rect('ammounknown0'))
    assert(not M.ui.rects['sentry-a:ammofill'],'stale ammo fill left visible')
    row.key='sentry-b';draw();assert(not M.ui.rects['sentry-a:hptrack'],'reused entity left a marker')
    assert(not M.ui.texts['sentry-a:distance5'] and not M.ui.metrics['sentry-a:distance'],'reused entity left distance text')
    assert(not M.ui.rects['sentry-a:firing:0'],'reused entity left a firing dot');dot()
    for _,p in ipairs({{x=0,y=-30,z=0},{x=0,y=0.2,z=0},{x=0,y=600,z=0},{x=10000,y=30,z=0}})do
        point=p;draw();assert(not M.ui.visible,'behind/out-of-range/offscreen marker remained')
    end
    point={x=0,y=30,z=0};draw();assert(M.ui.visible)
    point.z=-28;draw();assert(M.ui.visible and next(M.ui.texts)==nil,'clipped label not omitted');anchored()
    point.z=0;draw();assert(M.ui.texts[row.key..':distance5'])
    map=true;draw();assert(not M.ui.visible)
    map=nil;draw();assert(not M.ui.visible,'unknown map state drawn')
    map=false;bad=true;draw();assert(not M.ui.visible)
    bad=false;camera_missing=true;draw();assert(not M.ui.visible)
    camera_missing=false;options.markers_enabled=0
    local calls=camera_calls;draw();assert(camera_calls==calls and not M.ui.visible)
    options.markers_enabled=1;draw();M:draw({},options,'main');assert(not M.ui.visible)
    -- An unavailable silhouette hides the marker without fallback text.
    E.bitmap_fail=true;point.x=1;draw();assert(not M.ui.visible)
    assert(next(M.ui.bitmaps)==nil and next(M.ui.rects)==nil and next(M.ui.texts)==nil);E.bitmap_fail=false
    E.worlds={};M:abandon();assert(E.destroyed==0,'shutdown destroyed native GUI')

    -- Marker errors never prevent the card renderer or native update from running.
    E=make_engine();local menu=false;E.sr.Window={show_cursor=function()return menu end}
    local card_draws,marker_draws,hides,abandoned=0,0,0,0
    local marker={draw=function()marker_draws=marker_draws+1;error('camera unavailable')end,
        hide=function()hides=hides+1 end,abandon=function()abandoned=abandoned+1 end}
    local sample={world='main',peer='me',sentries={
        {identity='mine',name='GATLING',owner='me',life=0,hp=100,max=300,ammo=50,remaining=100},
        {identity='foreign',name='GATLING',owner='other',life=0,hp=100,max=300,ammo=50,remaining=100}}}
    local c=controller(E.sr,{time=function()return 0 end},{sample=function()return sample end},model(),
        {hide=function()end,draw=function(_,r)assert(#r==1 and r[1].key=='mine');card_draws=card_draws+1 end,
            abandon=function()end},config('layout=2'),{verified=true},function()end,nil,marker)
    c:tick();assert(marker_draws==1 and card_draws==1 and hides>0)
    menu=true;c:tick();assert(marker_draws==1 and #c.rows==0)
    c:shutdown();assert(abandoned==1)
end
