-- HD2-Addon: mods/retrox/sentry_hud
local REVISION='sentry-hud-0.2.0'
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
local ownership=make_ownership(bytes)
local controller=make_controller(sr,api,make_reader(api,bytes,catalog,ownership),
    make_model(),make_presentation(sr,api.font_ids,log,icons),options,ownership,log,make_hud_anchor(api,bytes))
local update=rawget(_G,'update');local shutdown=rawget(_G,'shutdown')
if type(update)~='function' then state.status='update unavailable';return state end
rawset(_G,'update',function(...)
    local good,err=pcall(controller.tick,controller)
    if not good then
        controller:fail()
        if state.error~=tostring(err) then state.error=tostring(err);log(state.error) end
    end
    return update(...)
end)
if type(shutdown)=='function' then
    rawset(_G,'shutdown',function(...)
        controller:shutdown()
        return shutdown(...)
    end)
end
state.status=ownership.verified and 'active' or 'offline prototype: '..ownership.reason
state.controller=controller;log(REVISION..'; '..state.status)
return state
