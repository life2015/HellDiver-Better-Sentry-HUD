-- Read-only OS adapter. No injection, gameplay writes or native game function calls.
return function(bytes)
    local ffi=require('ffi')
    assert(ffi.abi('64bit'),'Windows x64 required')
    ffi.cdef[[
        void *GetCurrentProcess(void);
        void *GetModuleHandleA(const char *name);
        uint64_t GetTickCount64(void);
        int ReadProcessMemory(void *process,const void *address,void *buffer,size_t size,size_t *read);
    ]]
    local K=ffi.load('kernel32')
    local process,buffer,got=K.GetCurrentProcess(),ffi.new('uint8_t[1048576]'),ffi.new('size_t[1]')
    local A={}
    function A.read(at,n)
        if not at or at<65536 or at+n>=0x800000000000 or n<1 or n>1048576 then return nil end
        if K.ReadProcessMemory(process,ffi.cast('const void *',at),buffer,n,got)==0 or tonumber(got[0])~=n then return nil end
        return ffi.string(buffer,n)
    end
    function A.pointer(at) local s=A.read(at,8);return s and bytes.ptr(s) end
    function A.time() return tonumber(K.GetTickCount64())/1000 end
    A.game=tonumber(ffi.cast('uintptr_t',K.GetModuleHandleA('game.dll')))
    A.exe=tonumber(ffi.cast('uintptr_t',K.GetModuleHandleA(nil)))
    local function matches(base,wanted)
        local d=A.read(base,64);if not d or d:sub(1,2)~='MZ' then return false end
        local off=bytes.u32(d,60);if off<64 or off>4096 then return false end
        local h=A.read(base+off,96)
        return h and h:sub(1,4)=='PE\0\0' and bytes.u32(h,8)==wanted[1]
            and bytes.u32(h,80)==wanted[2] and bytes.u32(h,88)==wanted[3]
    end
    assert(matches(A.game,{0x6AB3B43F,0x4744000,0xECDA6F}) and
        matches(A.exe,{0x6AB382E4,0x39E8000,0xE48B1D}),'Unsupported game build')
    function A.font_ids()
        local f=A.read(A.game+0x3772268,8);local a=A.read(A.game+0x3772ee8,8)
        local p=A.pointer(A.game+0x37c5478);local m=p and A.read(p+24,8)
        if not f or not a or not m then return end
        f,a,m=bytes.hex64(f),bytes.hex64(a),bytes.hex64(m)
        if f=='0000000000000000' or a=='0000000000000000' or m=='0000000000000000' then return end
        return f,m,a
    end
    return A
end
