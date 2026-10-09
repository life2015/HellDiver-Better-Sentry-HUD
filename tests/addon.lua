-- Exercise the packaged global hooks; only the Windows OS boundary is replaced.
return function(source,make_engine)
    local E=make_engine();local called,shutdowns=0,0
    E.sr.Window={show_cursor=function()return false end}
    local env={stingray=E.sr,os={getenv=function()return nil end},print=function()end}
    env._G=env;setmetatable(env,{__index=_G})
    env._test_api={game=0x10000000,exe=0x20000000,time=function()return 0 end,
        read=function()return nil end,font_ids=E.font_ids}
    env.update=function(...)called=called+1;return 'base-update',nil,select('#',...),... end
    env.shutdown=function(...)shutdowns=shutdowns+1;return 'base-shutdown',... end
    local chunk=assert(loadstring(source));setfenv(chunk,env)
    local state=chunk();assert(state.status=='active')
    local hook=env.update
    local a,b,c,d,e=hook(1,nil)
    assert(a=='base-update' and b==nil and c==2 and d==1 and e==nil and called==1)
    assert(chunk()==state and env.update==hook,'duplicate load installed hooks twice')
    local callbacks={};local registered=0
    env.ModOptionsMenu={api=1,register_option=function()registered=registered+1;return true end,
        get=function(id)if id=='retrox.sentry_hud.layout' then return 2 end end,
        on_change=function(id,fn)callbacks[id]=fn;return true end}
    hook();assert(registered==15 and state.options.layout==2,'late menu not connected to bundled update')
    state.controller.tick=function()error('simulated render failure')end
    hook();assert(called==3 and state.error:find('simulated render failure'))
    E.worlds={}
    local x,y=env.shutdown('arg')
    assert(x=='base-shutdown' and y=='arg' and shutdowns==1 and E.destroyed==0)
    assert(state.controller.stopped,'shutdown left polling enabled')
    callbacks['retrox.sentry_hud.layout'](1);assert(state.options.layout==2,'settings changed after shutdown')
    -- BSL v19 runs this after all addons initialize; older loaders use update.
    local scheduled
    env.SentryHUD=nil
    env.CowboyBingusModLoader={after_startup=function(fn)scheduled=fn;return true end}
    state=chunk();assert(type(scheduled)=='function')
    scheduled();assert(state.settings.registered==15 and state.options.layout==2)
end
