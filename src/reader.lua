-- Current-build read-only adapter. Returning candidate rows does not imply
-- player ownership: controller refuses them without the verified owner provider.
return function(api,B,catalog,ownership)
    local R={};local lifetime_checked=false
    local function read(at,n) local s=api.read(at,n);assert(s and #s==n,'unreadable snapshot');return s end
    local function ptr(at) return assert(B.ptr(read(at,8)),'invalid pointer') end
    local function tracked(guards,at,n)
        local b=read(at,n);guards[#guards+1]={at,b};return b
    end
    local function index_in(manager,map,id,guards)
        local h=tracked(guards,manager+map,20);local cap=B.u32(h,8)
        if cap==0 then return end
        local power=1;while power<cap do power=power*2 end
        assert(cap<=65536 and power==cap,'invalid component hash capacity')
        local table_at=assert(B.ptr(h),'invalid component table')
        local empty,mul=B.u32(h,12),B.u32(h,16);local start=B.mul32(id,mul)
        for probe=0,math.min(cap,128)-1 do
            local slot=table_at+((start+probe)%cap)*8;local row=read(slot,8);local entity=B.u32(row,0)
            if entity==empty then return end
            if entity==id then
                local index=B.u32(row,4);if index==0xffffffff then return end
                assert(index<16384,'invalid component index');guards[#guards+1]={slot,row};return index
            end
        end
        error('component lookup exceeded probe bound')
    end
    local function component(global,map,backref,id,descriptor,guards)
        local manager=B.ptr(tracked(guards,api.game+global,8));if not manager then return end
        local index=index_in(manager,map,id,guards);if not index then return end
        local ref=assert(B.ptr(tracked(guards,manager+backref,8)),'invalid component backref')
        assert(B.ptr(tracked(guards,ref+index*8,8))==descriptor,'component identity changed')
        return manager,index
    end
    local function magazine_settings(manager,s,guards)
        local index=index_in(manager,96,s.entity,guards)
        if index then
            local data=assert(B.ptr(tracked(guards,manager+160,8)))
            return read(data+index*160,160)
        end
        local root=assert(B.ptr(tracked(guards,api.game+0x346bf98,8)))
        local registry=assert(B.ptr(tracked(guards,root+0xf124a0,8)))
        local key=read(s.descriptor,8);local start=0
        for j=8,1,-1 do start=(start*256+key:byte(j))%540 end
        for probe=0,539 do
            local at=registry+((start+probe)%540)*16;local row=read(at,16)
            if row:sub(1,8)==string.rep('\0',8) then return nil end
            if row:sub(1,8)==key then
                guards[#guards+1]={at,row};local index=B.u32(row,8)
                assert(index<540,'invalid magazine setting index')
                return read(registry+8640+index*160,160)
            end
        end
        return nil
    end
    local function array(m,off,i,stride,guards)
        local p=assert(B.ptr(tracked(guards,m+off,8)),'invalid component array')
        return read(p+i*stride,stride)
    end
    local function lifetime(s,guards)
        local m,i=component(0x3326560,0x28,0x40,s.entity,s.descriptor,guards)
        if not m then return end
        if not lifetime_checked then
            local expected=('498b4650f30f1044c8040f2fc60f86d0020000f30f5cc70f2ff0f30f1144c804'):gsub('..',
                function(x)return string.char(tonumber(x,16))end)
            assert(read(api.game+0x93233a,32)==expected,'payload timer layout changed')
            lifetime_checked=true
        end
        local count=B.u32(tracked(guards,m+0x14,4),0)
        assert(count<=16384 and i<count,'invalid payload index')
        local remaining=B.f32(array(m,0x50,i,8,guards),4)
        local retract=B.f32(array(m,0x48,i,4,guards),0)
        assert(remaining and remaining>=-60 and remaining<=86400 and
            retract and retract>=-1 and retract<=86400,'invalid payload timer')
        -- These are game-owned counters, not time since this HUD first saw it.
        s.remaining=remaining;s.retiring=retract>=0
    end
    local function ammo(s,guards)
        local m,i=component(53634632,32,56,s.entity,s.descriptor,guards)
        if m then
            local a=array(m,80,i,12,guards);local a1=array(m,72,i,16,guards)
            local amount,reserve,chamber=B.u32(a,4),B.u32(a,0),B.u32(a1,8)
            assert(amount<1000000 and reserve<10000,'invalid magazine values')
            local setting=magazine_settings(m,s,guards)
            if not setting then return end
            local chambered=setting:byte(157)
            assert(chambered<=1,'invalid chamber setting')
            -- Runtime chamber_round is a projectile type, not a bullet count.
            local extra=(chambered==1 and chamber~=0) and 1 or 0
            -- setting+136 is BASE capacity, not the ship-upgraded capacity.
            -- Live MG262/base175 and Gatling750/base500 prove it cannot be used
            -- as upgraded capacity. The model uses the first observed count as
            -- the user-selected full-bar reference instead.
            s.ammo=amount+extra;s.reserve=reserve;s.feed='magazine';return
        end
        -- No validated sentry currently uses WeaponRounds in the live sample.
        -- Do not add its round-type selector/chamber id as ammunition.
        -- Beam/arc/heat values are not a conventional bullet count. Leave --
        -- until their consumption / heat semantics are validated for sentries.
    end
    function R:sample(world)
        local guards={}
        local user=ptr(api.game+0x347CEF0)
        local peer=B.hex64(read(user+0xB398,8))
        assert(peer~='0000000000000000' and peer~='FFFFFFFFFFFFFFFF','local player unavailable')
        local manager=assert(B.ptr(tracked(guards,api.game+0x3326688,8)),'health unavailable')
        local h=tracked(guards,manager+0x1010,88)
        local capacity,count=B.u32(h,0),B.u32(h,16)
        assert(capacity<=4096 and count<=capacity,'invalid health bounds')
        local out={world=world,peer=peer,sentries={},ownership_verified=ownership.verified}
        if count==0 then return out end
        local descriptors,records,ext=assert(B.ptr(h,56)),assert(B.ptr(h,72)),B.ptr(h,80)
        local pointers=read(descriptors,count*8)
        -- Read only known sentry records; enemy armies do not enlarge the health read.
        for i=0,count-1 do
            local descriptor=assert(B.ptr(pointers,i*8),'invalid health descriptor')
            local d=read(descriptor,24);local typ=B.hex64(d);local profile=catalog[typ]
            if profile then
                guards[#guards+1]={descriptor,d}
                local a=read(records+i*440,440)
                local hp=B.u32(a,20);if hp>=2147483648 then hp=hp-4294967296 end
                local s={name=profile.name,entity=B.u32(d,8),unit=B.u32(d,12),type=typ,
                    descriptor=descriptor,network=B.u32(d,16),life=B.u32(a,412),hp=hp,
                    identity=typ..':'..B.u32(d,8)..':'..B.u32(d,12)..':'..B.u32(d,16)..':'..descriptor}
                if ext then s.max=B.u32(read(ext+i*28,28),20) end
                if s.max and (s.max<=0 or s.max>10000000) then s.max=nil end
                if ownership.verified then s.owner=ownership.resolve(api,s,guards) end
                if s.owner==peer then
                    lifetime(s,guards)
                    if s.hp>0 and s.life<2 and not s.retiring and (s.remaining==nil or s.remaining>0) then ammo(s,guards) end
                end
                out.sentries[#out.sentries+1]=s
            end
        end
        assert(read(descriptors,count*8)==pointers,'health slots changed during read')
        assert(ptr(api.game+0x347CEF0)==user and B.hex64(read(user+0xB398,8))==peer,'local player changed')
        for _,g in ipairs(guards) do assert(read(g[1],#g[2])==g[2],'snapshot identity changed') end
        return out
    end
    return R
end
