return function(sr,api,reader,model,ui,options,ownership,log,hud_anchor,markers,positions)
    local C={next_poll=0,rows={},stopped=false}
    local function hide_markers() if markers then pcall(markers.hide,markers) end end
    function C:tick()
        if self.stopped then return end
        if options.enabled==0 then
            model:pause();self.rows={};self.next_poll=0;ui:hide();hide_markers();return
        end
        local world=sr.Application.main_world();local menu=sr.Window.show_cursor()==true
        if not world or world~=self.world then
            model:reset();self.rows={};self.next_poll=0;ui:hide();hide_markers();self.world=world
            if not world or menu then return end
        end
        if menu then
            model:pause();self.rows={};self.next_poll=0;ui:hide();hide_markers();return
        end
        local now=api.time()
        if now>=self.next_poll then
            self.next_poll=now+options.poll_interval
            local ok,snapshot=pcall(reader.sample,reader,world)
            if ok then
                self.rows=model:update(snapshot,now)
                local status=ownership.verified and 'observing' or ownership.reason
                if status~=self.status then self.status=status;log(status) end
            else
                model:pause();self.rows={}
                local reason=tostring(snapshot)
                if self.status~=reason then self.status=reason;log('waiting: '..reason) end
            end
        end
        -- Markers are independent of panel placement or Player Status availability.
        if markers then
            local good,err=pcall(markers.draw,markers,self.rows,options,world,now)
            if not good then
                hide_markers()
                if self.marker_error~=tostring(err) then self.marker_error=tostring(err);log('World markers: '..self.marker_error) end
            end
        end
        local anchor
        if options.layout==2 and positions then
            local ok,open=pcall(positions.map_open,positions)
            if not ok or open~=false then ui:hide();return end
        end
        local anchored=options.layout==1 or (options.layout==nil and options.anchor_player~=0)
        if anchored and #self.rows>0 then
            local ok,value=pcall(hud_anchor.sample,hud_anchor)
            if not ok or not value then
                ui:hide()
                if self.anchor_status~='unavailable' then log('Player Status anchor unavailable; HUD hidden') end
                self.anchor_status='unavailable';return
            end
            anchor=value
            if self.anchor_status~='ready' then
                log(string.format('Player Status anchor: right=%.1f bottom=%.1f scale=%.3f',anchor.right,anchor.bottom,anchor.scale))
            end
            self.anchor_status='ready'
        end
        ui:draw(self.rows,options,anchor)
    end
    function C:fail()
        model:pause();self.rows={};pcall(ui.hide,ui);hide_markers()
    end
    function C:shutdown()
        self.stopped=true;self.rows={};model:reset();ui:abandon()
        if markers then markers:abandon() end
    end
    return C
end
