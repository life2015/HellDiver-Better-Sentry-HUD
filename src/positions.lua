-- Read-only unit root position, build 25480438. Registry/pose layout follows
-- Enemy HP 1.1.2 (Stim Homing port method); no native pointer calls are made.
-- Verify descriptor, generation, object ID, pose getter bytes and read stability.
return function(api,B)
    local P={}
    local function read(at,n)
        local s=api.read(at,n);assert(s and #s==n,'position unreadable');return s
    end
    local function pointer(at) return assert(B.ptr(read(at,8)),'position pointer unavailable') end
    function P:sample(row)
        local unit=row.unit
        assert(type(unit)=='number' and unit>=0 and unit<4294967296 and unit==math.floor(unit),'invalid unit ID')
        local descriptor=read(row.descriptor,24)
        assert(B.hex64(descriptor)==row.type and B.u32(descriptor,8)==row.entity and
            B.u32(descriptor,12)==unit and B.u32(descriptor,16)==row.network,'sentry identity changed')
        local root=read(api.exe+0x1a100f0,8);local registry=assert(B.ptr(root))
        local index,generation=unit%0x400000,math.floor(unit/0x400000)%256
        local count=B.u32(read(registry+0x98,4),0)
        assert(count<=0x400000 and index<count,'unit index out of bounds')
        local genptr=pointer(registry+0xa0);local gen=read(genptr+index,1)
        assert(gen:byte()==generation,'unit generation changed')
        local tableptr=pointer(registry+0x88);local object=pointer(tableptr+index*8)
        assert(B.u32(read(object+8,4),0)==unit,'unit object changed')
        local vtable=pointer(object);local getter=pointer(vtable+0xe8)
        assert(read(getter,5)==string.char(0x48,0x8d,0x41,0x60,0xc3),'unit pose layout changed')
        local bones=pointer(object+0x88);local xyz=read(bones+48,12)
        local x,y,z=B.f32(xyz,0),B.f32(xyz,4),B.f32(xyz,8)
        assert(x and y and z and math.abs(x)<=100000 and math.abs(y)<=100000 and math.abs(z)<=100000,
            'invalid world coordinates')
        assert(read(api.exe+0x1a100f0,8)==root and pointer(registry+0xa0)==genptr and
            read(genptr+index,1)==gen and pointer(registry+0x88)==tableptr and
            pointer(tableptr+index*8)==object and B.u32(read(object+8,4),0)==unit and
            pointer(object+0x88)==bones and read(row.descriptor,24)==descriptor,'position identity changed during read')
        return {x=x,y=y,z=z}
    end
    function P:map_open()
        local root=read(api.game+0x346d538,8);local hud=assert(B.ptr(root))
        local flag=read(hud+0x3ef168+0x195,1):byte()
        assert(flag==0 or flag==1,'invalid map state')
        assert(read(api.game+0x346d538,8)==root,'HUD changed during map read')
        return flag==1
    end
    return P
end
