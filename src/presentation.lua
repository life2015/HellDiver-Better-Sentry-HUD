-- Sentry HUD presentation, adapted from our Enemy HP HUD+ renderer. Native font, outlined numerals, slim health gauge.
-- Visual reference: HD2 HUD+ 0.1.13 by DDRK1NG
-- https://www.nexusmods.com/helldivers2/mods/15298
-- This module owns only its screen GUI; it does not read or write game memory.
return function(sr, font_ids, log, icons)
    local Gui, World, App = sr.Gui, sr.World, sr.Application
    local V2, V3, Color, I = sr.Vector2, sr.Vector3, sr.Color, sr.IdString64
    local ui = { rects = {}, texts = {}, metrics = {}, bitmaps = {}, icon_cache = {} }
    local WHITE, MUTED, WARNING = {240, 240, 226}, {170, 176, 174}, {235, 140, 110}
    local function round(n) return math.floor(n + 0.5) end
    local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
    local function live(world)
        for _, w in ipairs(App.worlds()) do if w == world then return true end end
        return false
    end

    function ui:dispose()
        if self.gui and live(self.world) then
            if Gui.set_visible then pcall(Gui.set_visible, self.gui, false) end
            if World.destroy_gui then
                pcall(World.destroy_gui, self.world, self.gui)
            else
                for _, id in pairs(self.rects) do pcall(Gui.destroy_rect, self.gui, id) end
                for _, id in pairs(self.texts) do pcall(Gui.destroy_text, self.gui, id) end
                for _, id in pairs(self.bitmaps) do pcall(Gui.destroy_bitmap, self.gui, id) end
            end
        end
        self.gui, self.world, self.font_key = nil, nil, nil
        self.font_hex, self.material_hex, self.first_draw_logged = nil, nil, nil
        self.rects, self.texts, self.metrics = {}, {}, {}
        self.bitmaps,self.icon_cache,self.icon_bound,self.icon_failed={},{},nil,nil
        self.key, self.visible = nil, false
    end

    function ui:hide()
        if self.gui and self.visible then
            if live(self.world) and Gui.set_visible then
                Gui.set_visible(self.gui, false)
            else
                self:dispose()
            end
        end
        self.visible, self.key = false, nil
    end

    function ui:ensure()
        local main, overlay = App.main_world(), nil
        for _, w in ipairs(App.worlds()) do if w ~= main then overlay = w break end end
        if self.gui and self.world ~= overlay then self:dispose() end
        if not overlay then return false end
        local fh, mh, ah = font_ids()
        if not fh or not mh or not ah then self:hide() return false end
        if not self.gui then
            self.gui = World.create_screen_gui(overlay, "scale", 1, 1)
            if not self.gui then return false end
            self.world = overlay
            -- New GUIs default to visible; track that before any drawing can fail.
            self.visible = true
        end
        local key = fh .. mh .. ah
        if self.font_key ~= key then
            -- IdString64 values live in the engine's temporary allocation pool.
            -- Retain only hex strings; resolve native IDs immediately at each
            -- call, just as the original renderer refreshed them on each draw.
            self.font_hex, self.material_hex = fh, mh
            local ink = assert(Gui.material(self.gui, I.from_hex(mh)), "Font material unavailable")
            local function slot(x) return I.from_hex(x .. "00000000") end
            -- Preserve Enemy HP's binding of the live game's font material/atlas.
            for _, x in ipairs({"8035c266", "5e8455fe", "309e7783", "82b803a8"}) do
                sr.Material.set_scalar(ink, slot(x), 0)
            end
            sr.Material.set_vector2(ink, slot("e13777ce"), V2(1, -1))
            sr.Material.set_vector4(ink, slot("7701209e"), Color(0, 0, 0, 0))
            sr.Material.set_texture(ink, slot("88bac99b"), I.from_hex(ah))
            self.font_key, self.metrics = key, {}
            if log then log("UI font bound: " .. fh .. " material " .. mh .. "; native IDs are not cached") end
        end
        return true
    end

    function ui:rect(key, x, y, w, h, layer, rgb, alpha)
        local at, size = V3(round(x), round(y), layer), V2(math.max(0, round(w)), math.max(0, round(h)))
        local tint = Color(round(alpha), rgb[1], rgb[2], rgb[3])
        local id = self.rects[key]
        if id then Gui.update_rect(self.gui, id, at, size, tint)
        else self.rects[key] = assert(Gui.rect(self.gui, at, size, tint)) end
    end

    function ui:icon(key,typ,x,y,size,alpha)
        local cell=icons and icons.cells[typ]
        if not cell or self.icon_failed or not Gui.bitmap_uv or not Gui.update_bitmap_uv or
            not Gui.destroy_bitmap then return false end
        if not self.icon_bound then
            local ink=assert(Gui.material(self.gui,I.from_hex(icons.material)),'Icon material unavailable')
            sr.Material.set_texture(ink,I.from_hex('3aa8b87e00000000'),I.from_hex(icons.texture))
            self.icon_bound=true
            if log then log('Native sentry icon masks bound; per-layer color tint') end
        end
        x,y,size=round(x),round(y),math.max(1,round(size))
        alpha=clamp(round(alpha or 255),0,255)
        local opacity=icons.opacity
        local level=opacity and clamp(round(alpha/255*20),1,20)
        -- This HUD material uses the texture as a monochrome mask. Preserve
        -- native artwork colors explicitly, including overlapping path order.
        for index,layer in ipairs(cell) do
            local slot=key..':'..index
            local old=self.icon_cache[slot]
            if not (old and old.type==typ and old.x==x and old.y==y and old.size==size and old.alpha==alpha) then
                local uv,rgb=layer.uv,layer.color
                if opacity then
                    local cell=(level-1)*opacity.count+layer.cell
                    local u=(cell%opacity.columns)*opacity.pitch+opacity.inset
                    local v=math.floor(cell/opacity.columns)*opacity.pitch+opacity.inset
                    uv={u/opacity.size,v/opacity.size,(u+opacity.edge)/opacity.size,(v+opacity.edge)/opacity.size}
                end
                local lo,hi=V2(uv[1],uv[2]),V2(uv[3],uv[4])
                local at,dimensions,tint=V3(x,y,951+index),V2(size,size),Color(opacity and 255 or alpha,rgb[1],rgb[2],rgb[3])
                local id=self.bitmaps[slot]
                if id then Gui.update_bitmap_uv(self.gui,id,I.from_hex(icons.material),lo,hi,at,dimensions,tint)
                else self.bitmaps[slot]=assert(Gui.bitmap_uv(self.gui,I.from_hex(icons.material),lo,hi,at,dimensions,tint)) end
                self.icon_cache[slot]={type=typ,x=x,y=y,size=size,alpha=alpha}
            end
        end
        return true
    end

    function ui:measure(key, text, size)
        local m = self.metrics[key]
        if m and m.text == text and m.size == size then return m end
        m = {text = text, size = size, left = 0, width = #text * size * 0.6}
        -- Hidden labels have no width and need no native layout call.
        if text == "" then self.metrics[key] = m return m end
        local ok, lo, hi = pcall(Gui.text_extents, self.gui, text, I.from_hex(self.font_hex), size)
        if ok and lo and hi then
            -- HUD+ reads these Vector2 userdata through their native string form;
            -- Vector2.x is not a guaranteed API in the game's Lua bindings.
            local l = tonumber(string.match(tostring(lo), "^Vector2%(%s*([-%d%.]+)"))
            local r = tonumber(string.match(tostring(hi), "^Vector2%(%s*([-%d%.]+)"))
            if type(l) == "number" and type(r) == "number" and r >= l then
                m.left, m.width = l, r - l
            end
        end
        self.metrics[key] = m
        return m
    end

    function ui:text(key, value, size, x, y, rgb, alpha, outline)
        local m = self:measure(key, value, size)
        if value == "" then value, alpha = " ", 0 end
        x = x - m.left
        local steps = {{outline, 0}, {-outline, 0}, {0, outline}, {0, -outline}, {0, 0}}
        for index, delta in ipairs(steps) do
            local front = index == 5
            local c = front and rgb or {20, 23, 24}
            local tint = Color(round(front and alpha or alpha * 0.85), c[1], c[2], c[3])
            local at = V3(round(x + delta[1]), round(y + delta[2]), front and 956 or 955)
            local slot = key .. index
            local id = self.texts[slot]
            if id then Gui.update_text(self.gui, id, value, I.from_hex(self.font_hex), size,
                                       I.from_hex(self.material_hex), at, tint)
            else self.texts[slot] = assert(Gui.text(self.gui, value, I.from_hex(self.font_hex), size,
                                                   I.from_hex(self.material_hex), at, tint)) end
        end
    end

    -- Screen-right layout is independent of Player Status visibility/geometry.
    -- The whole group is vertically centered, with an optional screen offset.
    function ui:draw(rows, options, anchor)
        local opacity=clamp(round((options.hud_opacity or 100)/5)*5,0,100)/100
        if #rows==0 or options.enabled==0 or opacity==0 then self:hide(); return end
        local layout=options.layout or (options.anchor_player==0 and 3 or 1)
        local anchored=layout==1
        if anchored and (not anchor or anchor.shown<=0) then self:hide(); return end
        if not self:ensure() then return end
        local sw,sh=Gui.resolution()
        if not sw or not sh or sw<=0 or sh<=0 then self:hide(); return end
        local screen_scale=math.min(sw/1920,sh/1080)
        local scale=(anchored and anchor.scale or screen_scale)*(options.scale or 1)
        local width=274*scale
        if width>sw or 64*scale>sh then self:hide();return end
        local x,bottom,count
        if anchored then
            x=anchor.right+(options.panel_gap or 12)*anchor.scale
            bottom=anchor.bottom
            -- Never clamp back over the player panel if the requested layout cannot fit.
            if x<0 or bottom<0 or x+width>sw or bottom+64*scale>sh then self:hide();return end
        elseif layout==2 then
            x=clamp(sw-(options.right_margin or 48)*screen_scale-width,0,sw-width)
            count=math.min(#rows,options.max_rows or 6,math.max(1,math.floor((sh-26*scale)/(70*scale))))
            local group_height=(count-1)*70*scale+64*scale+(#rows>count and 26*scale or 0)
            bottom=clamp((sh-group_height)/2+(options.right_vertical_offset or 0)*screen_scale,
                0,math.max(0,sh-group_height))
        else
            x=clamp((options.x or 540)*scale,0,math.max(0,sw-width))
            bottom=clamp((options.y or 48)*scale,0,math.max(0,sh-70*scale))
        end
        count=count or math.min(#rows,options.max_rows or 6,math.max(1,math.floor((sh-bottom-26*scale)/(70*scale))))
        local active_rects,active_texts,active_bitmaps={},{},{}
        local function rect(k,rx,ry,rw,rh,rgb,a)
            active_rects[k]=true;self:rect(k,rx,ry,rw,rh,951,rgb,a*opacity)
        end
        local function label(k,value,rx,ry,size,rgb)
            for i=1,5 do active_texts[k..i]=true end
            self:text(k,value,size,rx,ry,rgb,235*opacity,math.max(1,scale))
        end
        local accent={221,199,112}
        for i=1,count do
            local r=rows[i];local y=bottom+(i-1)*70*scale;local k=tostring(i)..':'
            rect(k..'bg',x,y,width,64*scale,{16,23,25},155)
            rect(k..'edge',layout==2 and x+width-2*scale or x,y,2*scale,64*scale,accent,200)
            local icon_ok,has_icon=pcall(self.icon,self,k..'icon',r.type,x+10*scale,y+20*scale,40*scale,255*opacity)
            if not icon_ok then
                self.icon_failed=true
                if log then log('Icons unavailable; keeping text HUD: '..tostring(has_icon)) end
                has_icon=false
            end
            if has_icon then
                for layer=1,#icons.cells[r.type] do active_bitmaps[k..'icon:'..layer]=true end
            end
            -- The icon spans the name and HP rows; their text shares a column.
            local content_x=x+(has_icon and 58 or 10)*scale
            label(k..'name',r.name,content_x,y+44*scale,13*scale,WHITE)
            local rgb=r.status=='FIRING' and accent or (r.status=='EMPTY' and WARNING or MUTED)
            label(k..'status',r.status,x+188*scale,y+44*scale,10*scale,rgb)
            local maxhp=r.max and r.max>0 and r.max or nil
            local hptext='HP '..string.format('%.0f',r.hp)..(maxhp and (' / '..string.format('%.0f',maxhp)) or '')
            label(k..'hp',hptext,content_x,y+26*scale,12*scale,WHITE)
            local ammo=r.unlimited and 'UNLIMITED' or (r.ammo and string.format('%.0f',r.ammo) or '--')
            if r.reserve and r.reserve>0 then ammo=ammo..' +'..r.reserve..' MAG' end
            label(k..'ammo','AMMO '..ammo,x+156*scale,y+26*scale,12*scale,WHITE)
            local duration='--:--'
            if r.remaining then
                local seconds=math.max(0,math.ceil(r.remaining))
                duration=string.format('%02d:%02d',math.floor(seconds/60),seconds%60)
            end
            label(k..'time','TIME '..duration,x+181*scale,y+8*scale,11*scale,MUTED)
            local track_x=x+10*scale
            local track_width=150*scale
            rect(k..'track',track_x,y+10*scale,track_width,4*scale,{80,88,86},140)
            local ratio=maxhp and clamp(r.hp/maxhp,0,1) or 0
            rect(k..'fill',track_x,y+10*scale,track_width*ratio,4*scale,
                ratio<0.25 and WARNING or WHITE,225)
        end
        if #rows>count then label('overflow','+'..(#rows-count)..' SENTRIES',x,bottom+count*70*scale,11*scale,MUTED) end
        for k,id in pairs(self.rects) do if not active_rects[k] then Gui.destroy_rect(self.gui,id);self.rects[k]=nil end end
        for k,id in pairs(self.texts) do if not active_texts[k] then Gui.destroy_text(self.gui,id);self.texts[k]=nil end end
        for k,id in pairs(self.bitmaps) do
            if not active_bitmaps[k] then Gui.destroy_bitmap(self.gui,id);self.bitmaps[k]=nil;self.icon_cache[k]=nil end
        end
        if not self.visible and Gui.set_visible then Gui.set_visible(self.gui,true) end
        self.visible=true
    end
    -- At process shutdown the engine owns world destruction. Drop Lua references
    -- without invoking native GUI methods on a possibly tearing-down world.
    function ui:abandon()
        self.gui,self.world,self.font_key=nil,nil,nil
        self.rects,self.texts,self.metrics={},{},{}
        self.bitmaps,self.icon_cache,self.icon_bound,self.icon_failed={},{},nil,nil
        self.visible=false
    end
    return ui
end
