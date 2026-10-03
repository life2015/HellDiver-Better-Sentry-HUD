-- Read-only Player Status geometry, Steam build 25480438 (guarded by windows.lua).
-- Widget field layout identified in HD2 HUD+ 0.1.13 and verified in live snapshots.
-- Coordinates already include native HUD scale and screen offset, bottom-left origin.
return function(api,B)
    local H={}
    local function read(at,n)
        local s=api.read(at,n);assert(s and #s==n,'Player Status unreadable');return s
    end
    local function box(at)
        local s=read(at,160)
        local x,y,w,h,scale,shown=B.f32(s,148),B.f32(s,156),B.f32(s,36),B.f32(s,40),B.f32(s,100),B.f32(s,84)
        assert(x and y and w and h and scale and shown,'invalid Player Status geometry')
        assert(x>=0 and y>=0 and x<32768 and y<32768 and w>=16 and w<=2048 and
            h>=8 and h<=512 and scale>=0.25 and scale<=4 and shown>=0 and shown<=1,
            'Player Status geometry out of range')
        return {x=x,y=y,right=x+w*scale,top=y+h*scale,scale=scale,shown=shown}
    end
    function H:sample()
        local root=read(api.game+0x346d538,8)
        local hud=assert(B.ptr(root),'Player Status unavailable')
        local panel=hud+0x24e340+0x60
        local weapon,health=box(panel+0x7b0),box(panel+0xb30)
        assert(read(api.game+0x346d538,8)==root,'Player Status changed during read')
        assert(math.abs(weapon.scale-health.scale)<0.005 and
            math.abs(weapon.x-health.x)<4*health.scale,'Player Status layout changing')
        return {right=math.max(weapon.right,health.right),bottom=math.min(weapon.y,health.y),
            top=math.max(weapon.top,health.top),scale=health.scale,
            shown=math.max(weapon.shown,health.shown)}
    end
    return H
end
