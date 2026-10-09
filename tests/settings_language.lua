-- Run against MOM's real option validation/API/refresh and UTF-8 helpers.
-- Only native descriptor allocation and disk access are substituted.
return function(make_settings,make_config,T,options_source,api_source)
    -- Host Lua 5.1 uses libc character classes; match the game's LuaJIT ASCII
    -- byte classes so macOS UTF-8 locale does not classify continuation bytes
    -- as control characters inside MOM's display_text sanitizer.
    local previous_locale=os.setlocale(nil,'ctype');assert(os.setlocale('C','ctype'))
    local prefix='retrox.sentry_hud.'
    local function session(tag)
        local state={mods={},options={},values={},callbacks={},option_count=0,revision=0,
            refused={},refused_count=0}
        local globals={BingusTranslations={version=1,game_language=tag}}
        local mom={state=state,note=function()end,translation={T=T,tr=function(k)return k end},
            TEXT_TEMPLATE=123,MAX_MODS=112,MAX_ROWS=32,descriptor=function()return 0,{}end}
        assert(loadstring(options_source))(mom)
        local saved={[prefix..'layout']='2',[prefix..'hud_opacity']='35',[prefix..'marker_opacity']='85',[prefix..'hud_background_opacity']='29'}
        mom.saved_values=function()return saved end
        assert(loadstring(api_source))(mom)
        globals.ModOptionsMenu=mom.api
        local options=make_config('');local S=make_settings(options,globals)
        S:step();assert(S.registered==16 and #state.mods==1)
        assert(options.layout==2 and options.hud_opacity==35 and options.marker_opacity==85 and options.hud_background_opacity==29)
        return globals,mom,options,S
    end
    local globals,mom,options,S=session(nil)
    local state=mom.state
    assert(state.options[prefix..'enabled'].label=='Show Sentry HUD')
    local english={}
    for id,option in pairs(state.options) do english[id]={label=option.label,description=option.description} end
    local function refresh(tag)
        globals.BingusTranslations={version=1,game_language=tag,steam_language='zh-Hans',override='zh-Hans'}
        mom.translation.refresh();S:step()
        assert(state.option_count==16 and #state.mods==1 and #state.mods[1].order==16)
        assert(state.values[prefix..'layout']==2 and options.hud_opacity==35 and options.marker_opacity==85 and options.hud_background_opacity==29)
        for _,callbacks in pairs(state.callbacks) do assert(#callbacks==1,'language switch duplicated callbacks') end
    end
    for _,tag in ipairs({'zh-Hans','zh-Hant','zh-CN','zh-TW','zh','ZH-hans'}) do
        refresh(tag)
        assert(state.mods[1].title=='炮台 HUD',tag..' title='..state.mods[1].title..' source='..state.mods[1].source())
        assert(state.options[prefix..'enabled'].label=='显示炮台 HUD')
        local choice=state.options[prefix..'layout'].choices
        assert(choice[1]=='玩家状态栏旁' and choice[2]=='屏幕右侧' and choice[3]=='手动位置')
        for id,option in pairs(state.options) do
            assert(T.check(option.label) and T.length(option.label)<=64)
            assert(T.check(option.description) and T.length(option.description)<=400)
            assert(option.label~=english[id].label and option.description~=english[id].description,'untranslated option: '..id)
        end
    end
    -- Only game text language controls this mod; a Chinese Steam locale or
    -- forced pack cannot turn a non-Chinese game into Chinese menu labels.
    for _,tag in ipairs({'en','ja','ko','fr','de','ru','pseudo','unknown',''}) do
        refresh(tag);assert(state.mods[1].title=='SENTRY HUD')
        for id,option in pairs(state.options) do
            assert(option.label==english[id].label and option.description==english[id].description)
        end
    end
    refresh('zh-Hans');globals.BingusTranslations.override='en';mom.translation.refresh()
    assert(state.options[prefix..'enabled'].label=='显示炮台 HUD')
    for _,registry in ipairs({false,{}, {version=2,game_language='zh-Hans'}, {version=1,game_language=42}}) do
        globals.BingusTranslations=registry;mom.translation.refresh()
        assert(state.options[prefix..'enabled'].label=='Show Sentry HUD')
    end
    -- Registration also works if the game language is already known at boot.
    local _,zh_mom=session('zh-Hant')
    assert(zh_mom.state.mods[1].title=='炮台 HUD')
    os.setlocale(previous_locale,'ctype')
end
