-- Pure presentation state. Ownership comes only from a verified network owner peer.
return function()
    local M = {records={}, initial_ammo={}, serial=0}
    -- Menus, toggles and a failed read hide presentation, but must not turn a
    -- half-empty magazine into a newly observed full one on the next frame.
    function M:pause() self.records={} end
    function M:reset()
        self:pause();self.initial_ammo={};self.world=nil;self.peer=nil;self.last=nil
    end
    function M:update(snapshot, now)
        if not snapshot or not snapshot.peer or not snapshot.world then self:pause(); return {} end
        if self.world~=snapshot.world or self.peer~=snapshot.peer or (self.last and now<self.last) then self:reset() end
        self.world,self.peer,self.last=snapshot.world,snapshot.peer,now
        local current,rows,initial_ammo={},{},{}
        for _,s in ipairs(snapshot.sentries) do
            if s.owner==snapshot.peer and s.hp and s.hp>0 and s.life<2 and
                not s.retiring and (s.remaining==nil or s.remaining>0) then
                local key=s.identity
                local full=self.initial_ammo[key]
                -- Per-instance first positive observation is the user-selected
                -- full-bar reference, not a claim about the game's capacity.
                -- Zero/unknown during initialization cannot be a denominator.
                if not full and not s.unlimited and type(s.ammo)=='number' and
                    s.ammo>0 and s.ammo<1000000 and s.ammo==math.floor(s.ammo) then full=s.ammo end
                initial_ammo[key]=full
                local r=self.records[key]
                if not r then self.serial=self.serial+1; r={order=self.serial} end
                local previous=r.sample
                -- Ammo consumption is evidence of a shot; acquiring a target is not.
                if previous and s.ammo and previous.ammo then
                    if s.ammo<previous.ammo then r.firing_until=now+0.3
                    elseif s.ammo>previous.ammo then r.firing_until=nil end
                end
                if s.firing==true then r.firing_until=now+0.2 end
                local status='READY'
                if s.ammo==0 and not s.unlimited then status='EMPTY'
                elseif r.firing_until and now<r.firing_until then status='FIRING'
                elseif s.reloading then status='RELOADING'
                elseif s.ammo==nil and not s.unlimited then status='UNKNOWN' end
                r.sample={ammo=s.ammo};current[key]=r
                rows[#rows+1]={key=key,order=r.order,name=s.name,type=s.type,hp=s.hp,max=s.max,
                    ammo=s.ammo,ammo_max=full,reserve=s.reserve,unlimited=s.unlimited,status=status,remaining=s.remaining,
                    unit=s.unit,entity=s.entity,network=s.network,descriptor=s.descriptor}
            end
        end
        self.records=current;self.initial_ammo=initial_ammo
        table.sort(rows,function(a,b)return a.order<b.order end)
        return rows
    end
    return M
end
