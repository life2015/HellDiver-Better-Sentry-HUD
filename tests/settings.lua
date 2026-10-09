return function(make_settings,make_config)
    local prefix='retrox.sentry_hud.'
    local function text(value)return type(value)=='function' and value() or value end
    local function menu(saved,reject)
        local M={api=1,version=3,specs={},values={},callbacks={},calls=0,subscriptions=0}
        function M.register_option(id,spec)
            M.calls=M.calls+1
            if reject and id==prefix..reject then return false,'category full' end
            assert(not M.specs[id],'duplicate registration')
            assert(spec.mod_id=='retrox.sentry_hud' and text(spec.mod)=='Sentry HUD')
            assert(#text(spec.label)<=64 and #text(spec.description)<=400)
            if spec.type=='toggle' then assert(type(spec.default)=='boolean')
            elseif spec.type=='choice' then assert(spec.default>=1 and spec.default<=#spec.choices)
            else assert(spec.default>=spec.min and spec.default<=spec.max and spec.step>0) end
            M.specs[id]=spec
            M.values[id]=saved[id]
            if M.values[id]==nil then M.values[id]=spec.default end
            return true
        end
        function M.get(id) return M.values[id] end
        function M.on_change(id,fn)
            assert(not M.callbacks[id],'duplicate callback')
            M.subscriptions=M.subscriptions+1;M.callbacks[id]=fn;return true
        end
        function M.edit(key,value) M.pending={key,value} end
        function M.apply()
            local id=prefix..M.pending[1];local value=M.pending[2]
            M.values[id]=value;M.callbacks[id](value,id);M.pending=nil
        end
        return M
    end
    assert(make_config('').layout==1)
    assert(make_config('').hud_background_opacity==100)
    assert(make_config('hud_background_opacity=29').hud_background_opacity==29)
    assert(make_config('hud_background_opacity=101').hud_background_opacity==100)
    assert(make_config('').marker_show_distance==1)
    assert(make_config('marker_show_distance=0').marker_show_distance==0)
    assert(make_config('marker_show_distance=0.5').marker_show_distance==1)
    assert(make_config('right_bottom=48').right_vertical_offset==0,'legacy bottom margin prevents centering')
    assert(make_config('right_vertical_offset=-120').right_vertical_offset==-120)
    assert(make_config('right_vertical_offset=-451').right_vertical_offset==0)
    assert(make_config('').hud_opacity==100 and make_config('').marker_opacity==60)
    assert(make_config('hud_opacity=42\nmarker_opacity=0').hud_opacity==40)
    assert(make_config('hud_opacity=101\nmarker_opacity=101').marker_opacity==60)
    assert(make_config('anchor_player=0').layout==3,'old manual config lost')
    assert(make_config('layout=2\nanchor_player=1').layout==2,'explicit layout lost')
    assert(make_config('layout=2.5\nenabled=0.5').layout==1)
    assert(make_config('layout=0\nright_margin=9999\nscale=nan').right_margin==48)
    local options=make_config('scale=1.25\nmax_rows=4\nanchor_player=0\nx=300')
    local globals={};local logs={};local S=make_settings(options,globals,function(m)logs[#logs+1]=m end)
    for _=1,10 do S:step() end
    assert(not S.menu and options.layout==3,'missing dependency changed config')
    globals.ModOptionsMenu={api=2};S:step();assert(not S.menu)
    globals.ModOptionsMenu={api=1};S:step();assert(not S.menu,'partial API latched')
    local saved={[prefix..'layout']=2,[prefix..'enabled']=false,[prefix..'right_margin']=72}
    local M=menu(saved);globals.ModOptionsMenu=M;S:step()
    assert(S.registered==16 and M.calls==16 and M.subscriptions==16)
    assert(options.layout==2 and options.anchor_player==0 and options.enabled==0 and options.right_margin==72,
        'saved values were not restored at registration')
    assert(options.scale==1.25 and options.x==300 and options.max_rows==4,'cfg defaults lost')
    for _=1,100 do S:step() end
    assert(M.calls==16 and M.subscriptions==16)
    M.edit('layout',1);assert(options.layout==2,'unapplied edit took effect')
    M.apply();assert(options.layout==1 and options.anchor_player==1)
    M.edit('enabled',true);M.apply();assert(options.enabled==1)
    M.edit('scale',1.75);M.apply();assert(options.scale==1.75 and options.x==300)
    M.edit('markers_enabled',false);M.apply();assert(options.markers_enabled==0)
    assert(M.specs[prefix..'marker_show_distance'].default==true)
    M.edit('marker_show_distance',false);assert(options.marker_show_distance==1);M.apply()
    assert(options.marker_show_distance==0)
    M.edit('marker_scale',1.5);M.apply();assert(options.marker_scale==1.5)
    M.edit('marker_distance',200);M.apply();assert(options.marker_distance==200)
    M.edit('right_vertical_offset',-120);M.apply();assert(options.right_vertical_offset==-120)
    assert(M.specs[prefix..'hud_opacity'].default==100 and M.specs[prefix..'marker_opacity'].default==60)
    assert(M.specs[prefix..'hud_background_opacity'].default==100)
    M.edit('hud_background_opacity',29);assert(options.hud_background_opacity==100);M.apply()
    assert(options.hud_background_opacity==29 and options.hud_opacity==100 and options.marker_opacity==60)
    M.edit('hud_opacity',35);assert(options.hud_opacity==100);M.apply()
    assert(options.hud_opacity==35 and options.marker_opacity==60)
    M.edit('marker_opacity',85);M.apply();assert(options.marker_opacity==85 and options.hud_opacity==35)
    for _,value in ipairs({0/0,math.huge,-5,105,'60'}) do
        M.callbacks[prefix..'hud_opacity'](value);M.callbacks[prefix..'marker_opacity'](value);M.callbacks[prefix..'hud_background_opacity'](value)
    end
    assert(options.hud_opacity==35 and options.marker_opacity==85 and options.hud_background_opacity==29)
    for _,value in ipairs({0/0,math.huge,-1,3,'1'}) do M.callbacks[prefix..'scale'](value) end
    assert(options.scale==1.75,'invalid value accepted')
    M.callbacks[prefix..'layout'](2.5);assert(options.layout==1)
    S:shutdown();M.edit('enabled',false);M.apply();assert(options.enabled==1)
    -- Reopening the game restores applied values even without an APPLY callback.
    local next_options=make_config('')
    local next_menu=menu(M.values)
    local next_session=make_settings(next_options,{ModOptionsMenu=next_menu})
    next_session:step();assert(next_options.enabled==0 and next_options.scale==1.75)
    assert(next_options.hud_background_opacity==29,'background setting did not persist')
    assert(next_options.right_vertical_offset==-120 and next_options.marker_show_distance==0)
    assert(next_options.hud_opacity==35 and next_options.marker_opacity==85,'opacity settings did not persist')
    -- One refused option does not stop the HUD or block other settings.
    local rejected=menu({},'layout');local fallback=make_config('')
    local limited=make_settings(fallback,{ModOptionsMenu=rejected},function(m)logs[#logs+1]=m end)
    limited:step();limited:step()
    assert(limited.registered==15 and rejected.calls==16 and fallback.layout==1)
    assert(not rejected.callbacks[prefix..'layout'])
    -- A dependency exception is isolated to that option, without retry storms.
    local throwing=menu({});throwing.register_option=function()error('dependency failed')end
    local isolated=make_settings(fallback,{ModOptionsMenu=throwing})
    isolated:step();assert(isolated.registered==0 and fallback.enabled==1)
end
