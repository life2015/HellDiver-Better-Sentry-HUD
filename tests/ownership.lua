return function(B,make_owner)
    local memory={}
    local function put(at,s)for i=1,#s do memory[at+i-1]=s:sub(i,i) end end
    local function word(at,n,size)
        for i=0,(size or 4)-1 do memory[at+i]=string.char(n%256);n=math.floor(n/256) end
    end
    local function raw(s)return (s:gsub('..',function(x)return string.char(tonumber(x,16))end))end
    local api={exe=0x10000000}
    function api.read(at,n)
        local parts={};for i=0,n-1 do if not memory[at+i] then return nil end;parts[#parts+1]=memory[at+i] end
        return table.concat(parts)
    end
    local root,object,vtable,data=0x20000000,0x21000000,0x22000000,0x23000000
    put(api.exe+0x29aea0,raw('83b95806000000448bca4c8bd941b8ffffff7f'))
    word(api.exe+0x1a10278,root,8);word(root+0xa8,object,8);word(object,vtable,8)
    word(vtable+0x178,api.exe+0x29aea0,8)
    word(object+0x640,12);word(object+0x648,data,8);word(object+0x658,2);word(object+0x65c,7)
    -- Hash for GOID 789: 0x6b69de14 % 7 == 0. Collision target lies beyond bucket count.
    local slot=0
    word(data+slot*0x248,100);word(data+slot*0x248+0x240,9)
    word(data+9*0x248,789);word(data+9*0x248+0x240,0x7fffffff)
    put(data+9*0x248+16,raw('f0debc9a78563412'))
    local O=make_owner(B);local guards={}
    assert(O.verified and O.resolve(api,{network=789},guards)=='123456789ABCDEF0')
    for _,g in ipairs(guards)do assert(api.read(g[1],#g[2])==g[2])end
    put(data+9*0x248+16,raw('f0debc9a99999999'))
    assert(O.resolve(api,{network=789},{})=='999999999ABCDEF0','owner high bits lost')
    put(data+9*0x248+16,string.rep('\0',8));assert(O.resolve(api,{network=789},{})==nil)
    put(data+9*0x248+16,string.rep('\255',8));assert(O.resolve(api,{network=789},{})==nil)
    word(data+slot*0x248+0x240,0xfffffffe);assert(O.resolve(api,{network=789},{})==nil)
    word(data+slot*0x248+0x240,slot);assert(not pcall(O.resolve,api,{network=789},{}),'cycle accepted')
    word(data+slot*0x248+0x240,12);assert(not pcall(O.resolve,api,{network=789},{}),'out-of-range chain accepted')
    word(data+slot*0x248+0x240,9)
    word(object+0x658,0);assert(O.resolve(api,{network=789},{})==nil);word(object+0x658,2)
    word(vtable+0x178,api.exe+0x29aea1,8);assert(not pcall(O.resolve,api,{network=789},{}),'wrong session accepted')
    word(vtable+0x178,api.exe+0x29aea0,8);word(api.exe+0x29aea0,0,1)
    assert(not pcall(make_owner(B).resolve,api,{network=789},{}),'wrong native layout accepted')
end
