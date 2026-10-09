-- HD2-Addon: mods/retrox/sentry_hud
local REVISION='sentry-hud-0.3.1'
local existing=rawget(_G,'SentryHUD')
if existing then return existing end
local state={revision=REVISION,status='starting'}
rawset(_G,'SentryHUD',state)
local function log(message)
    print('[SentryHUD] '..tostring(message))
    local base=os.getenv('LOCALAPPDATA')
    if base then
        local f=io.open(base..'/SentryHUD.log','a')
        if f then f:write(tostring(message)..'\n');f:close() end
    end
end
--[[MODULES]]
local sr=rawget(_G,'stingray')
if not sr then state.status='engine unavailable';return state end
local ok,api=pcall(make_windows,bytes)
if not ok then state.status=tostring(api);log(state.status);return state end
local content
local base=os.getenv('LOCALAPPDATA')
local f=base and io.open(base..'/sentry_hud.cfg','r')
if f then content=f:read('*a');f:close() end
local options=make_config(content)
local settings=make_settings(options,_G,log)
local ownership=make_ownership(bytes)
local positions=make_positions(api,bytes)
local markers=make_markers(sr,positions,make_presentation,marker_icons,api.font_ids,log)
local controller=make_controller(sr,api,make_reader(api,bytes,catalog,ownership),
    make_model(),make_presentation(sr,api.font_ids,log,icons),options,ownership,log,make_hud_anchor(api,bytes),markers,positions)
local update=rawget(_G,'update');local shutdown=rawget(_G,'shutdown')
if type(update)~='function' then state.status='update unavailable';return state end
local function settings_step()
    local good,err=pcall(settings.step,settings)
    if not good and state.settings_error~=tostring(err) then
        state.settings_error=tostring(err);log('Settings unavailable: '..state.settings_error)
    end
end
local loader=rawget(_G,'CowboyBingusModLoader')
if type(loader)=='table' and type(loader.after_startup)=='function' then
    pcall(loader.after_startup,settings_step)
end
rawset(_G,'update',function(...)
    settings_step()
    local good,err=pcall(controller.tick,controller)
    if not good then
        controller:fail()
        if state.error~=tostring(err) then state.error=tostring(err);log(state.error) end
    end
    return update(...)
end)
if type(shutdown)=='function' then
    rawset(_G,'shutdown',function(...)
        settings:shutdown()
        controller:shutdown()
        return shutdown(...)
    end)
end
state.status=ownership.verified and 'active' or 'offline prototype: '..ownership.reason
state.controller=controller;state.settings=settings;state.options=options;state.markers=markers
log(REVISION..'; '..state.status)
return state
