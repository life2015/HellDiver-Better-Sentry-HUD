-- Retained GUI fake. Rejects dead-world access, invalid IDs and non-finite geometry.
local E = { width = 1920, height = 1080, worlds = {"main", "overlay"},
            guis = {}, created = 0, destroyed = 0, next_id = 0, binds = 0, epoch = 0 }
-- Native IdString64.from_hex uses the game's temporary allocation pool, not
-- durable Lua strings. Recycle it between simulated frames to catch caching.
function E.next_frame() E.epoch = E.epoch + 1 end
local function native_id(value)
    assert(type(value) == "table" and value.epoch == E.epoch,
           "expired temporary IdString64 used by native GUI")
    return value.hex
end
local function finite(x) assert(type(x) == "number" and x == x and math.abs(x) < 1e9) return x end
local function V2(x, y)
    return setmetatable({x=finite(x), y=finite(y), kind=2},
                        {__tostring=function(v) return string.format("Vector2(%f, %f)", v.x,v.y) end})
end
local V3 = setmetatable({x = function(v) assert(v.kind == 3) return v.x end,
                         y = function(v) assert(v.kind == 3) return v.y end},
                        {__call = function(_, x, y, z) return {x=finite(x), y=finite(y), z=finite(z), kind=3} end})
local function check(gui)
    assert(gui and not gui.dead, "dead GUI accessed")
    local found = false
    for _, w in ipairs(E.worlds) do if w == gui.world then found = true end end
    assert(found, "dead world accessed")
end
local function put(gui, id, part)
    check(gui)
    if id then assert(gui.parts[id], "invalid retained ID")
    else E.next_id = E.next_id + 1; id = E.next_id end
    gui.parts[id] = part
    return id
end
local Gui = {}
function Gui.bitmap_uv(gui,material,lo,hi,at,size,tint)
    native_id(material)
    if E.bitmap_fail or (E.bitmap_fail_after and (E.bitmap_calls or 0)>=E.bitmap_fail_after) then error('simulated missing icon material') end
    E.bitmap_calls=(E.bitmap_calls or 0)+1
    return put(gui,nil,{kind='bitmap',lo=lo,hi=hi,at=at,size=size,tint=tint})
end
function Gui.update_bitmap_uv(gui,id,material,lo,hi,at,size,tint)
    native_id(material)
    if E.bitmap_fail or (E.bitmap_fail_after and (E.bitmap_calls or 0)>=E.bitmap_fail_after) then error('simulated missing icon material') end
    E.bitmap_calls=(E.bitmap_calls or 0)+1
    return put(gui,id,{kind='bitmap',lo=lo,hi=hi,at=at,size=size,tint=tint})
end
function Gui.resolution() return E.width, E.height end
function Gui.rect(gui, at, size, tint) return put(gui, nil, {kind="rect", at=at, size=size, tint=tint}) end
function Gui.update_rect(gui, id, at, size, tint) return put(gui, id, {kind="rect", at=at, size=size, tint=tint}) end
function Gui.text(gui, text, font, size, material, at, tint)
    native_id(font); native_id(material)
    return put(gui, nil, {kind="text", text=text, font=font, size=size, at=at, tint=tint})
end
function Gui.update_text(gui, id, text, font, size, material, at, tint)
    native_id(font); native_id(material)
    return put(gui, id, {kind="text", text=text, font=font, size=size, at=at, tint=tint})
end
function Gui.text_extents(gui, text, font, size)
    check(gui)
    native_id(font)
    if E.metrics_fail then error("font not measurable") end
    if E.measure then return V2(0, 0), V2(E.measure(text, size), size) end
    return V2(1, -size * 0.2), V2(1 + #text * size * 0.58, size * 0.8)
end
function Gui.set_visible(gui, visible) check(gui) gui.visible = visible end
function Gui.material(gui, material) check(gui) native_id(material) return {material=true} end
local function destroy_part(gui, id) check(gui) assert(gui.parts[id]) gui.parts[id] = nil end
Gui.destroy_rect, Gui.destroy_text = destroy_part, destroy_part
Gui.destroy_bitmap=destroy_part
E.sr = { Gui = Gui, Vector2 = V2, Vector3 = V3,
         IdString64 = {from_hex = function(x) return {hex=x, epoch=E.epoch} end},
         Color = function(a,r,g,b)
             for _, v in ipairs({a,r,g,b}) do finite(v) assert(v >= 0 and v <= 255) end
             return {a=a,r=r,g=g,b=b}
         end,
         Application = { main_world = function() return "main" end, worlds = function() return E.worlds end },
         World = {
             create_screen_gui = function(world)
                 if E.create_fail then return nil end
                 local gui = {world=world, parts={}, visible=true}
                 E.guis[#E.guis+1] = gui; E.created = E.created + 1
                 return gui
             end,
             destroy_gui = function(world, gui)
                 check(gui) assert(gui.world == world) gui.dead = true E.destroyed = E.destroyed + 1
             end,
         },
         Material = {set_scalar=function() end, set_vector2=function() end,
                     set_vector4=function() end, set_texture=function() E.binds=E.binds+1 end} }
E.font_ids = function() if E.no_font then return nil end return "font", "material", E.atlas or "atlas" end
return E
