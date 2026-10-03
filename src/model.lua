-- Pure presentation state. Ownership comes only from a verified network owner peer.
return function()
    local M = {records={}, serial=0}
    function M:reset() self.records={}; self.world=nil; self.peer=nil; self.last=nil end
    function M:update(snapshot, now)
        if not snapshot or not snapshot.peer or not snapshot.world then self:reset(); return {} end
        if self.world~=snapshot.world or self.peer~=snapshot.peer or (self.last and now<self.last) then self:reset() end
        self.world,self.peer,self.last=snapshot.world,snapshot.peer,now
        local current,rows={},{}
        for _,s in ipairs(snapshot.sentries) do
            if s.owner==snapshot.peer and s.hp and s.hp>0 and s.life<2 and
                not s.retiring and (s.remaining==nil or s.remaining>0) then
                local key=s.identity
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
                    ammo=s.ammo,reserve=s.reserve,unlimited=s.unlimited,status=status,remaining=s.remaining}
            end
        end
        self.records=current
        table.sort(rows,function(a,b)return a.order<b.order end)
        return rows
    end
    return M
end
