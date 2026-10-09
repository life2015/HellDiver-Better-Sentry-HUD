-- Optional Mod Options Menu API 1 adapter. No native menu hooks or file writes.
-- Registration may happen before or after this addon; get() restores saved values
-- because on_change only fires when the player applies a new value.
return function(options,globals,log)
    local S={stopped=false}
    local function note(message) if log then log('Settings: '..tostring(message)) end end
    -- MOM observes the game's Text Language before refreshing text callbacks.
    -- Read its shared plain-data protocol; never use Steam/OS language or a
    -- translation pack's forced override in place of the player's game setting.
    local function chinese()
        local registry=rawget(globals,'BingusTranslations')
        if type(registry)~='table' or rawget(registry,'version')~=1 then return false end
        local tag=rawget(registry,'game_language')
        if type(tag)~='string' then return false end
        tag=tag:lower()
        return tag=='zh' or tag:match('^zh[-_]')~=nil
    end
    local zh={
        enabled={'显示炮台 HUD','显示自己召唤的自动哨戒炮的生命、弹药和剩余部署时间。'},
        layout={'HUD 布局','屏幕右侧布局将整组卡片垂直居中，竖直颜色条位于卡片右边。查看地图时隐藏卡片，文字和图标保持正常阅读方向。'},
        scale={'HUD 大小','调整卡片大小。玩家状态栏旁的布局同时跟随游戏 HUD 缩放，其他布局按屏幕分辨率缩放。'},
        hud_opacity={'炮台 HUD 不透明度 (%)','统一调整卡片图标、文字、状态条和背景的不透明度。默认 100%；0% 隐藏卡片，不影响炮台位置标记。'},
        max_rows={'最大炮台显示数量','最多显示的卡片数量。卡片向上排列，超出的炮台显示为额外数量。'},
        panel_gap={'玩家状态栏间距','与玩家状态栏右边缘的间距，仅用于玩家状态栏旁的布局。'},
        right_margin={'右侧边距','屏幕右侧布局与屏幕右边缘的距离，以 1920 × 1080 为基准，不随卡片大小变化。'},
        right_vertical_offset={'右侧布局上下偏移','相对屏幕中间上下移动整组卡片，以 1920 × 1080 为基准。正数上移，负数下移；默认 0，垂直居中。'},
        x={'手动水平位置','距屏幕左侧的水平位置，仅用于手动位置布局，同时跟随 HUD 大小缩放。'},
        y={'手动垂直位置','距屏幕底部的垂直位置，仅用于手动位置布局，同时跟随 HUD 大小缩放。'},
        markers_enabled={'炮台位置标记','以白色炮台图标和两条细条透视显示炮台位置。上方为生命，下方为相对初始余弹的弹药量。每座炮台首次读到的余弹记为满弹，中途识别则以当时余弹为准。虚线表示无法读取；无背景，查看地图时隐藏。'},
        marker_show_distance={'显示炮台距离','在位置标记下方居中显示距离（米），默认开启。按当前玩家视角位置到炮台的直线距离计算，随标记大小和不透明度调整。'},
        marker_scale={'位置标记大小','调整白色炮台图标、生命条、弹药条及距离文字的大小。'},
        marker_opacity={'位置标记不透明度 (%)','统一调整位置图标、开火圆点、两条状态条及距离文字的不透明度。默认 60%；0% 隐藏位置标记，不影响炮台卡片。'},
        marker_distance={'位置标记距离','位置标记的最远显示距离，单位为米。镜头背后或屏幕外的炮台不显示标记。'},
    }
    local zh_choices={'玩家状态栏旁','屏幕右侧','手动位置'}
    local function localized(english,translated,dynamic)
        local function text() return chinese() and translated or english end
        return dynamic and text or text()
    end
    local specs={
        {key='enabled',type='toggle',label='Show Sentry HUD',
            description='Show health, ammunition and deployment time for your automatic sentries.'},
        {key='layout',type='choice',label='HUD Layout',
            choices={'Beside Player Status','Screen Right','Manual Position'},
            description='Screen Right centers the card group vertically at the right edge, with the accent stripe on the right. Cards hide while viewing the map. Text and icons keep their normal reading direction.'},
        {key='scale',type='slider',label='HUD Scale',min=0.5,max=2,step=0.05,
            description='Card size. Player Status layout also follows the native HUD scale. Other layouts scale with screen resolution.'},
        {key='hud_opacity',type='slider',label='Sentry HUD Opacity (%)',min=0,max=100,step=5,
            description='Opacity of sentry cards, including icons, text, bars and background. Default: 100%. 0% hides cards while keeping world markers independent.'},
        {key='max_rows',type='slider',label='Maximum Sentries',min=1,max=10,step=1,
            description='Maximum visible cards. Cards stack upward; extra sentries are shown as a count.'},
        {key='panel_gap',type='slider',label='Player Status Gap',min=0,max=160,step=1,gap=true,
            description='Space after the player panel. Used only by Beside Player Status.'},
        {key='right_margin',type='slider',label='Right Edge Margin',min=0,max=400,step=1,gap=true,
            description='Distance from the right screen edge in Screen Right layout, at 1920 x 1080. Independent of card size.'},
        {key='right_vertical_offset',type='slider',label='Right Layout Vertical Offset',min=-450,max=450,step=1,
            description='Move the right-side card group relative to screen center, at 1920 x 1080. Positive moves up; negative moves down. Default: 0 (centered).'},
        {key='x',type='slider',label='Manual X',min=0,max=1800,step=1,gap=true,
            description='Horizontal position from the left. Used only by Manual Position; follows HUD Scale.'},
        {key='y',type='slider',label='Manual Y',min=0,max=1000,step=1,
            description='Vertical position from the bottom. Used only by Manual Position; follows HUD Scale.'},
        {key='markers_enabled',type='toggle',label='Sentry World Markers',gap=true,
            description='White sentry icons with two thin bars, visible through terrain. Upper: health. Lower: ammo relative to the first observed count for each sentry (100%). Late discovery uses remaining ammo. Dashed means unreadable. No panel. Hidden on the map.'},
        {key='marker_show_distance',type='toggle',label='Show Sentry Distance',
            description='Center distance in metres below each world marker. Enabled by default. Uses straight-line distance from the current player camera to the sentry; follows marker scale and opacity.'},
        {key='marker_scale',type='slider',label='World Marker Scale',min=0.5,max=2,step=0.05,
            description='Size of the white sentry icons, health/ammo bars and distance labels.'},
        {key='marker_opacity',type='slider',label='World Marker Opacity (%)',min=0,max=100,step=5,
            description='Opacity of world marker icons, firing dots, bars and distance labels. Default: 60%. 0% hides markers while keeping sentry cards independent.'},
        {key='marker_distance',type='slider',label='World Marker Range',min=25,max=500,step=1,
            description='Maximum world marker distance in metres. Sentries behind the camera or outside the screen are not marked.'},
    }
    local function apply(spec,value)
        if S.stopped then return end
        if spec.type=='toggle' then
            if type(value)=='boolean' then options[spec.key]=value and 1 or 0 end
        elseif type(value)=='number' and value==value then
            local lo,hi=spec.min or 1,spec.max or #spec.choices
            if value>=lo and value<=hi and (spec.type~='choice' or value==math.floor(value)) then
                options[spec.key]=spec.key=='max_rows' and math.floor(value) or value
                if spec.key=='hud_opacity' or spec.key=='marker_opacity' then
                    options[spec.key]=math.floor(value/5+0.5)*5
                end
                if spec.key=='layout' then options.anchor_player=value==1 and 1 or 0 end
            end
        end
    end
    function S:step()
        if self.stopped or self.menu then return end
        local menu=rawget(globals,'ModOptionsMenu')
        if type(menu)~='table' or menu.api~=1 or type(menu.register_option)~='function' or
            type(menu.get)~='function' or type(menu.on_change)~='function' then return end
        -- A refusal is final for this session (e.g. category limit). Do not
        -- repeatedly register rejected options or duplicate callbacks each frame.
        self.menu=menu;self.registered=0
        local dynamic=type(menu.version)=='number' and menu.version>=2
        for _,spec in ipairs(specs) do
            local current=spec
            local id='retrox.sentry_hud.'..current.key
            local descriptor={mod=localized('Sentry HUD','炮台 HUD',dynamic),mod_id='retrox.sentry_hud',default=options[current.key]}
            for k,v in pairs(current) do if k~='key' then descriptor[k]=v end end
            descriptor.label=localized(current.label,zh[current.key][1],dynamic)
            descriptor.description=localized(current.description,zh[current.key][2],dynamic)
            if current.choices then
                descriptor.choices={}
                for i,value in ipairs(current.choices) do descriptor.choices[i]=localized(value,zh_choices[i],dynamic) end
            end
            if current.type=='toggle' then descriptor.default=options[current.key]~=0 end
            local ok,err=pcall(function()
                local accepted,reason=menu.register_option(id,descriptor)
                if not accepted then error(reason or 'registration refused') end
                local subscribed,why=menu.on_change(id,function(value) apply(current,value) end)
                if not subscribed then error(why or 'callback registration refused') end
                apply(current,menu.get(id))
                self.registered=self.registered+1
            end)
            if not ok then note(id..': '..tostring(err)) end
        end
        note(tostring(self.registered)..' options registered; changes take effect on APPLY')
    end
    function S:shutdown() self.stopped=true end
    return S
end
