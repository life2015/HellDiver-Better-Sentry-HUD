return function(make_model,make_controller,make_config,make_engine)
    local function sentry(id,ammo)
        return {identity=id,owner='me',type='EF85D6CF58E31D70',name='GATLING',
            hp=300,max=300,life=0,remaining=100,ammo=ammo}
    end
    local M=make_model();local time=0
    local function sample(rows,world,peer)
        time=time+1
        return M:update({world=world or 'main',peer=peer or 'me',sentries=rows},time)
    end
    local rows=sample({sentry('a',750),sentry('b',500)})
    assert(rows[1].ammo_max==750 and rows[2].ammo_max==500,'same type shared a baseline')
    rows=sample({sentry('a',375),sentry('b',100)})
    assert(rows[1].ammo/rows[1].ammo_max==0.5 and rows[2].ammo/rows[2].ammo_max==0.2)
    M:pause();rows=sample({sentry('a',300),sentry('b',50)})
    assert(rows[1].ammo_max==750 and rows[1].status=='READY','pause reset baseline or replayed a shot')
    assert(#M:update(nil,time)==0)
    rows=sample({sentry('a',100)});assert(rows[1].ammo_max==750,'read gap reset baseline')
    assert(M.initial_ammo.b==nil,'removed sentry retained baseline')
    rows=sample({sentry('a',0)});assert(rows[1].ammo_max==750)
    rows=sample({sentry('a',900)});assert(rows[1].ammo_max==750,'refill changed initial observation')
    rows=sample({sentry('a',nil)});assert(rows[1].ammo==nil and rows[1].ammo_max==750)
    local dead=sentry('a',600);dead.hp=0
    sample({dead});assert(M.initial_ammo.a==nil)
    rows=sample({sentry('a:next-generation',262)});assert(rows[1].ammo_max==262)
    sample({});assert(next(M.initial_ammo)==nil)
    local expired=sentry('a',600);expired.remaining=0
    sample({sentry('a',600)});sample({expired});assert(next(M.initial_ammo)==nil)
    local retiring=sentry('a',600);retiring.retiring=true
    sample({sentry('a',600)});sample({retiring});assert(next(M.initial_ammo)==nil)
    local foreign=sentry('a',750);foreign.owner='other'
    sample({foreign});assert(next(M.initial_ammo)==nil)
    -- Deployment may initially report zero, or ammo may be temporarily unreadable.
    rows=sample({sentry('a',nil)});assert(rows[1].ammo_max==nil)
    rows=sample({sentry('a',0)});assert(rows[1].ammo_max==nil)
    rows=sample({sentry('a',24)});assert(rows[1].ammo_max==24)
    for _,invalid in ipairs({-1,0/0,math.huge,1.5,1000000}) do
        sample({});rows=sample({sentry('invalid',invalid)});assert(rows[1].ammo_max==nil)
    end
    sample({sentry('a',24)})
    rows=sample({sentry('a',16)},'new-world');assert(rows[1].ammo_max==16)
    local owned=sentry('a',8);owned.owner='new-peer'
    rows=sample({owned},'new-world','new-peer');assert(rows[1].ammo_max==8)
    rows=M:update({world='new-world',peer='new-peer',sentries={sentry('a',7)}},0)
    assert(#rows==0 and next(M.initial_ammo)==nil,'time rollback retained session data')
    M:reset();assert(next(M.initial_ammo)==nil)

    -- Real controller paths: settings/menu, disable, read failures, render
    -- failures, and changing world. None may silently refill the ammo bar.
    local E=make_engine();local menu,broken=false,false;local world='main';local ammo=750
    local options=make_config('layout=2');local now=0
    E.sr.Application.main_world=function()return world end
    E.sr.Window={show_cursor=function()return menu end}
    local ui={hide=function()end,draw=function()end,abandon=function()end}
    local reader={sample=function()
        if broken then error('temporary unreadable snapshot') end
        return {world=world,peer='me',sentries={sentry('own',ammo)}}
    end}
    local C=make_controller(E.sr,{time=function()return now end},reader,make_model(),
        ui,options,{verified=true},function()end)
    local function tick()now=now+1;C:tick()end
    tick();assert(C.rows[1].ammo_max==750)
    ammo=375;menu=true;tick();assert(#C.rows==0)
    menu=false;tick();assert(C.rows[1].ammo_max==750 and C.rows[1].ammo==375)
    options.enabled=0;tick();assert(#C.rows==0)
    ammo=300;options.enabled=1;tick();assert(C.rows[1].ammo_max==750)
    broken=true;tick();assert(#C.rows==0)
    broken=false;ammo=250;tick();assert(C.rows[1].ammo_max==750)
    C:fail();ammo=200;tick();assert(C.rows[1].ammo_max==750)
    world='next';ammo=150;tick();assert(C.rows[1].ammo_max==150)
    C:shutdown();assert(#C.rows==0)
end
