return function(sr,api,reader,model,ui,options,ownership,log,hud_anchor)
    local C={next_poll=0,rows={},stopped=false}
    function C:tick()
        if self.stopped then return end
        local world=sr.Application.main_world();local menu=sr.Window.show_cursor()==true
        if not world or menu or world~=self.world then
            model:reset();self.rows={};self.next_poll=0;ui:hide();self.world=world
            if not world or menu then return end
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
                model:reset();self.rows={}
                local reason=tostring(snapshot)
                if self.status~=reason then self.status=reason;log('waiting: '..reason) end
            end
        end
        local anchor
        if options.anchor_player~=0 and #self.rows>0 then
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
        model:reset();self.rows={};pcall(ui.hide,ui)
    end
    function C:shutdown()
        self.stopped=true;self.rows={};model:reset();ui:abandon()
    end
    return C
end
