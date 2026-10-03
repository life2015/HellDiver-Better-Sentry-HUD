-- Network game-object owner: the same full peer the game uses for damage credit.
-- Confirmed against four user-summoned sentry types on build 25480438.
-- Simulation-authority flags are deliberately not used. Host migration and
-- multiplayer ownership transfers still need in-game validation.
return function(B)
    local checked=false
    local O={verified=true,reason='network owner reader available'}
    local function xor8(a,b)
        local value,p=0,1
        for i=1,8 do if a%2~=b%2 then value=value+p end;a=math.floor(a/2);b=math.floor(b/2);p=p*2 end
        return value
    end
    function O.resolve(api,s,guards)
        local function take(a,n,guard)
            local bytes=assert(api.read(a,n),'ownership read unavailable')
            assert(#bytes==n,'partial ownership read')
            if guard then guards[#guards+1]={a,bytes} end
            return bytes
        end
        local function pointer(a)return assert(B.ptr(take(a,8,true)),'ownership pointer unavailable')end
        if not checked then
            local function raw(h)return (h:gsub('..',function(p)return string.char(tonumber(p,16))end))end
            assert(take(api.exe+0x29aea0,19)==raw('83b95806000000448bca4c8bd941b8ffffff7f'), 'network owner layout changed')
            checked=true
        end
        local root=pointer(api.exe+0x1a10278);local object=pointer(root+0xa8)
        local vtable=pointer(object)
        assert(pointer(vtable+0x178)==api.exe+0x29aea0,'unsupported network session layout')
        local allocation=B.u32(take(object+0x640,4,true),0)
        local data=pointer(object+0x648)
        local count=B.u32(take(object+0x658,4),0)
        local buckets=B.u32(take(object+0x65c,4,true),0)
        assert(allocation>0 and allocation<=131072 and buckets>0 and buckets<=allocation and count<=allocation,'network bounds')
        if count==0 or s.network==0x7fff then return nil end
        local hash=B.mul32(s.network,0x5bd1e995)
        hash=hash-hash%256+xor8(hash%256,math.floor(hash/16777216))
        local slot=B.mul32(hash,0x5bd1e995)%buckets
        local seen={}
        for attempt=1,128 do
            if slot==0x7fffffff then return nil end
            assert(slot<allocation and not seen[slot],'network chain invalid');seen[slot]=true
            local at=data+slot*0x248
            local next_slot=B.u32(take(at+0x240,4,true),0)
            if next_slot==0xfffffffe then return nil end
            if B.u32(take(at,4,true),0)==s.network then
                local peer=B.hex64(take(at+16,8,true))
                if peer~='0000000000000000' and peer~='FFFFFFFFFFFFFFFF' then return peer end
                return nil
            end
            slot=next_slot
        end
        error('network chain exceeds bound')
    end
    return O
end
