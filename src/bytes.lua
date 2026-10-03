return {
    u32=function(s,o)
        local a,b,c,d=s:byte(o+1,o+4);return a+b*256+c*65536+d*16777216
    end,
    f32=function(s,o)
        local a,b,c,d=s:byte(o+1,o+4)
        local bits=a+b*256+c*65536+d*16777216
        local sign=bits>=2147483648 and -1 or 1
        local exponent=math.floor(bits/8388608)%256;local fraction=bits%8388608
        if exponent==255 then return nil end -- NaN / infinity are not timer values.
        if exponent==0 then return sign*fraction*2^-149 end
        return sign*(1+fraction/8388608)*2^(exponent-127)
    end,
    ptr=function(s,o)
        o=o or 0;local n=0
        for i=8,1,-1 do n=n*256+s:byte(o+i) end
        if n>=65536 and n<0x800000000000 then return n end
    end,
    hex64=function(s,o)
        o=o or 0;local out={}
        for i=8,1,-1 do out[#out+1]=string.format('%02X',s:byte(o+i)) end
        return table.concat(out)
    end,
    mul32=function(a,b)
        return (a*(b%65536)+((a*math.floor(b/65536))%65536)*65536)%4294967296
    end
}
