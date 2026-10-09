-- Screen-space markers: intentionally no raycast/occlusion test, so the owner's
-- sentries remain marked through terrain. Native vectors/cameras live one draw.
return function(sr,positions,make_presentation,icons,font_ids,log)
    -- Dedicated white silhouettes provide selectable baked mask coverage.
    local white_icons=icons
    local ui=make_presentation(sr,font_ids,log,white_icons)
    local M={ui=ui}
    local WHITE={255,255,255}
    local AMMO={221,199,112} -- Same accent as the card's FIRING status.
    local FIRING={100,220,125}
    local function finite(v) return type(v)=='number' and v==v and math.abs(v)<1e8 end
    local function ratio(n,max)
        if not finite(n) or not finite(max) or max<=0 then return nil end
        return math.max(0,math.min(1,n/max))
    end
    local function camera_for_view(world)
        local V,Mat,C=sr.Vector3,sr.Matrix4x4,sr.Camera
        local view=sr.World.debug_camera_pose(world)
        local at,fwd=Mat.translation(view),Mat.forward(view)
        local cameras=sr.World.units_by_resource(world,'core/units/camera')
        if type(cameras)~='table' or #cameras>64 then return end
        local best,origin,forward,score,matched_distance,matched_alignment
        for _,unit in ipairs(cameras) do
            local ok,cam,pos,dir,d2,alignment=pcall(function()
                local candidate=sr.Unit.camera(unit,1)
                if not candidate then return end
                local pose=C.world_pose(candidate)
                local position=Mat.translation(pose)
                local direction=Mat.forward(pose)
                local delta=position-at
                return candidate,position,direction,V.dot(delta,delta),V.dot(direction,fwd)
            end)
            -- Resource enumeration also includes map/preview cameras. Match the
            -- rendered view, with room for the native camera's one-frame lag.
            -- Never fall back to the first camera when the view is unavailable.
            if ok and cam and finite(d2) and finite(alignment) and d2<=16 and alignment>=0.98 then
                local s=d2+100*math.max(0,1-alignment)
                if not score or s<score then
                    best,origin,forward,score=cam,pos,dir,s
                    matched_distance,matched_alignment=math.sqrt(d2),alignment
                end
            end
        end
        if best and not M.camera_reported then
            if log then log(string.format('World markers: view-matched camera; candidates=%d offset=%.3fm alignment=%.5f',
                #cameras,matched_distance,matched_alignment)) end
            M.camera_reported=true
        end
        return best,origin,forward
    end
    function M:hide() ui:hide() end
    function M:abandon() ui:abandon() end
    function M:draw(rows,options,world)
        local opacity=math.max(0,math.min(100,math.floor((options.marker_opacity or 60)/5+0.5)*5))/100
        if options.enabled==0 or options.markers_enabled==0 or opacity==0 or #rows==0 then self:hide();return end
        local ok,open=pcall(positions.map_open,positions)
        -- Do not draw world markers over the map or at an unknown HUD state.
        if not ok or open~=false then self:hide();return end
        local sw,sh=sr.Gui.resolution()
        if not finite(sw) or not finite(sh) or sw<=0 or sh<=0 then self:hide();return end
        local camera,origin,forward=camera_for_view(world)
        if not camera then self:hide();return end
        local V=sr.Vector3
        local scale=math.min(sw/1920,sh/1080)*(options.marker_scale or 1)
        local width,height=40*scale,46*scale
        local show_distance=options.marker_show_distance~=0
        local markers={}
        for i=1,math.min(#rows,32) do
            local row=rows[i]
            local good,p=pcall(positions.sample,positions,row)
            if good and p then
                -- Anchor the silhouette itself to the sentry root, as a location
                -- ping. A world-height offset drifts away from the deployment
                -- point with distance/pitch; a screen offset moves the icon too.
                local target=V(p.x,p.y,p.z)
                local delta=target-origin
                local depth=V.dot(delta,forward)
                local distance=math.sqrt(V.dot(delta,delta))
                if finite(depth) and depth>0.5 and finite(distance) and distance<=(options.marker_distance or 300) then
                    -- Explicit viewport uses the same pixel space as our GUI.
                    -- HD2's second return is clip-space depth, not metres. Use
                    -- the selected camera's forward dot for the front test.
                    local projected,clip_depth=sr.Camera.world_to_screen(camera,target,nil,sr.Vector2(sw,sh))
                    local px,py=V.x(projected),V.y(projected)
                    if not M.projection_reported then
                        if log then log(string.format('World markers projection: viewport=%.0fx%.0f screen=(%.1f,%.1f) forward=%.2fm clip=%s',
                            sw,sh,px,py,depth,tostring(clip_depth))) end
                        M.projection_reported=true
                    end
                    if finite(px) and finite(py) then
                        -- Icon center is (20, 30) in the 40x46 marker. Bars
                        -- remain beneath it; scaling must not move the anchor.
                        local x,y=px-width/2,py-30*scale
                        -- No edge clamping: it would suggest a false world position.
                        if x>=0 and y>=0 and x+width<=sw and y+height<=sh then
                            markers[#markers+1]={row=row,x=x,y=y,distance=distance}
                        end
                    end
                end
            end
        end
        if #markers==0 then self:hide();return end
        if not ui:ensure() then return end
        local rects,bitmaps,texts={},{},{}
        local drawn=0
        local function rect(k,x,y,w,h,color,alpha,layer)
            rects[k]=true;ui:rect(k,x,y,w,h,layer or 951,color,alpha*opacity)
        end
        local function firing_dot(k,cx,cy)
            -- Pixel-aligned scanlines form a small filled circle using the
            -- existing rect API. No font glyph or new native material needed.
            local diameter=math.max(2,math.floor(6*scale+0.5))
            local radius=diameter/2
            local left=math.floor(cx-radius+0.5)
            local bottom=math.floor(cy-radius+0.5)
            for row=0,diameter-1 do
                local dy=row+0.5-radius
                local half=math.sqrt(radius*radius-dy*dy)
                local start=math.max(0,math.ceil(radius-half-0.5))
                rect(k..'firing:'..row,left+start,bottom+row,diameter-2*start,1,FIRING,255,954)
            end
        end
        for _,m in ipairs(markers) do
            local r=m.row;local k=r.key..':'
            local x,y=m.x,m.y
            local good,shown=pcall(ui.icon,ui,k..'icon',r.type,x+4*scale,y+14*scale,32*scale,255*opacity)
            if good and shown then
                for layer=1,#white_icons.cells[r.type] do bitmaps[k..'icon:'..layer]=true end
                drawn=drawn+1
                if r.status=='FIRING' then
                    firing_dot(k,x+34*scale,y+17*scale)
                end
                local function bar(id,value,by,color)
                    if value then
                        rect(k..id..'track',x,by,width,3*scale,color,55)
                        rect(k..id..'fill',x,by,width*value,3*scale,color,235)
                    else
                        -- A dashed bar means the reading or its baseline is
                        -- unavailable, rather than full or empty.
                        for dash=0,4 do
                            rect(k..id..'unknown'..dash,x+dash*8*scale,by,4*scale,3*scale,color,105)
                        end
                    end
                end
                bar('hp',ratio(r.hp,r.max),y+8*scale,WHITE)
                bar('ammo',r.ammo==0 and 0 or ratio(r.ammo,r.ammo_max),y+2*scale,AMMO)
                if show_distance and y>=16*scale then
                    local label=string.format('%d m',math.floor(m.distance+0.5))
                    local key=k..'distance'
                    local size=12*scale
                    local metrics=ui:measure(key,label,size)
                    local tx=x+width/2-metrics.width/2
                    -- Keep the icon's world anchor fixed. Omit only the label
                    -- if there is no room below the bars or at the screen edge.
                    if tx>=scale and tx+metrics.width+scale<=sw then
                        ui:text(key,label,size,tx,y-11*scale,WHITE,235*opacity,scale)
                        for layer=1,5 do texts[key..layer]=true end
                    end
                end
            end
        end
        for k,id in pairs(ui.rects) do if not rects[k] then sr.Gui.destroy_rect(ui.gui,id);ui.rects[k]=nil end end
        for k,id in pairs(ui.texts) do
            if not texts[k] then sr.Gui.destroy_text(ui.gui,id);ui.texts[k]=nil end
        end
        for k in pairs(ui.metrics) do if not texts[k..5] then ui.metrics[k]=nil end end
        for k,id in pairs(ui.bitmaps) do
            if not bitmaps[k] then sr.Gui.destroy_bitmap(ui.gui,id);ui.bitmaps[k]=nil;ui.icon_cache[k]=nil end
        end
        if drawn==0 then self:hide();return end
        if not ui.visible and sr.Gui.set_visible then sr.Gui.set_visible(ui.gui,true) end
        ui.visible=true
    end
    return M
end
