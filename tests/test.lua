return function(bytes,make_reader,catalog,make_model,make_controller,make_presentation,make_config,make_engine,make_ownership,icons)
    local peer='123456789ABCDEF0'
    local function item(k,ammo,owner)
        return {identity=k,name='GATLING',type='EF85D6CF58E31D70',hp=280,max=300,life=0,ammo=ammo,owner=owner or peer,remaining=87.2}
    end
    local M=make_model()
    local function step(rows,t,world,p) return M:update({sentries=rows,world=world or 'w',peer=p or peer},t) end
    assert(#step({item('a',100,'999999999ABCDEF0')},0)==0,'other player shown')
    local a=step({item('a',100)},0);assert(a[1].status=='READY')
    assert(step({item('a',99)},0.1)[1].status=='FIRING')
    assert(step({item('a',99)},0.5)[1].status=='READY')
    assert(step({item('a',0)},0.6)[1].status=='EMPTY')
    assert(step({item('a',100)},0.7)[1].status=='READY','refill counted as firing')
    assert(step({item('a',90)},1,'new')[1].status=='READY','world carried history')
    local b=step({item('b',50),item('a',90)},1.1,'new');assert(b[1].key=='a','order unstable')
    local unknown=item('c',10);unknown.owner=nil;assert(#step({unknown},1.2)==0,'unowned leaked')
    local dead=item('a',10);dead.hp=0;assert(#step({dead},1.3)==0)
    assert(#M:update(nil,1.4)==0)
    assert(step({item('a',1)},1.5)[1].status=='READY','read gap created false shot')
    local expired=item('expired',200);expired.remaining=-0.0065
    assert(#step({expired},1.6)==0,'expired sentry kept its HUD')
    expired.remaining=0;assert(#step({expired},1.7)==0,'zero timer still visible')
    expired.remaining=100;expired.retiring=true
    assert(#step({expired},1.8)==0,'retraction kept its HUD before lifetime expiry')
    local late=item('late',100);late.remaining=21.1
    assert(step({late},1.9)[1].remaining==21.1,'late discovery restarted countdown')
    -- Real reader exercised with byte-addressed, build-layout fixtures (synthetic).
    local mem={};local function put(a,s) for i=1,#s do mem[a+i-1]=s:sub(i,i) end end
    local function word(n,nbytes) local t={};for i=1,nbytes or 4 do t[i]=string.char(n%256);n=math.floor(n/256) end;return table.concat(t) end
    local function w(a,n,nbytes) put(a,word(n,nbytes)) end
    local function zero(a,n) put(a,string.rep('\0',n)) end
    local api={game=0x10000000}
    function api.read(a,n) local t={};for i=0,n-1 do if not mem[a+i] then return end;t[#t+1]=mem[a+i] end;return table.concat(t) end
    local user,hm,desc,records,ext,pointers=0x20000000,0x21000000,0x22000000,0x23000000,0x24000000,0x25000000
    w(api.game+0x347CEF0,user,8);w(user+0xB398,0x9ABCDEF0);w(user+0xB39C,0x12345678)
    w(api.game+0x3326688,hm,8);zero(hm+0x1010,88);w(hm+0x1010,4);w(hm+0x1020,1)
    w(hm+0x1048,pointers,8);w(hm+0x1058,records,8);w(hm+0x1060,ext,8);w(pointers,desc,8)
    zero(desc,24);w(desc,0x58E31D70);w(desc+4,0xEF85D6CF);w(desc+8,123);w(desc+12,456);w(desc+16,789)
    zero(records,440);w(records+20,280);zero(ext,28);w(ext+20,300)
    local wm,buckets,back,net,run=0x26000000,0x27000000,0x28000000,0x29000000,0x2A000000
    w(api.game+53634632,wm,8);zero(wm+32,56)
    w(wm+32,buckets,8);w(wm+40,8);w(wm+44,0xFFFFFFFF);w(wm+48,1)
    put(buckets,string.rep('\255',64));w(buckets+3*8,123);w(buckets+3*8+4,0)
    w(wm+56,back,8);w(back,desc,8);w(wm+72,run,8);w(wm+80,net,8)
    zero(net,12);w(net+4,120);zero(run,16);w(run+8,148)
    -- Entity override settings; chamber_round is a projectile ID, never a count.
    local overrides,settings=0x2B000000,0x2C000000
    zero(wm+96,20);w(wm+96,overrides,8);w(wm+104,8);w(wm+108,0xFFFFFFFF);w(wm+112,1)
    put(overrides,string.rep('\255',64));w(overrides+3*8,123);w(overrides+3*8+4,0)
    w(wm+160,settings,8);zero(settings,160);w(settings+136,100);w(settings+156,1,1)
    -- Payload lifetime and retraction are distinct native counters.
    local pm,pmap,pback,pnet,pret=0x30000000,0x31000000,0x32000000,0x33000000,0x34000000
    w(api.game+0x3326560,pm,8);w(pm+0x14,1);zero(pm+0x28,20)
    w(pm+0x28,pmap,8);w(pm+0x30,8);w(pm+0x34,0xFFFFFFFF);w(pm+0x38,1)
    put(pmap,string.rep('\255',64));w(pmap+3*8,123);w(pmap+3*8+4,0)
    w(pm+0x40,pback,8);w(pback,desc,8);w(pm+0x50,pnet,8);w(pm+0x48,pret,8)
    zero(pnet,8);w(pnet+4,0x42960000);w(pret,0xBF800000) -- 75 seconds, -1 inactive
    local signature=('498b4650f30f1044c8040f2fc60f86d0020000f30f5cc70f2ff0f30f1144c804'):gsub('..',function(x)return string.char(tonumber(x,16))end)
    put(api.game+0x93233a,signature)
    local O={verified=true,resolve=function()return peer end}
    local reader=make_reader(api,bytes,catalog,O)
    local snap=reader:sample('world');local s=snap.sentries[1]
    assert(s.hp==280 and s.max==300 and s.ammo==121 and s.owner==peer)
    assert(s.remaining==75 and not s.retiring)
    w(pnet+4,0xBBC00000);w(pret,0x40000000) -- negative expiry, 2 seconds retraction
    local ended=reader:sample('world');assert(ended.sentries[1].remaining<0)
    assert(#make_model():update(ended,0)==0,'live expiry/retraction not filtered')
    w(pnet+4,0x42960000);w(pret,0xBF800000)
    w(pback,desc+24,8);assert(not pcall(reader.sample,reader,'world'),'wrong timer identity accepted');w(pback,desc,8)
    w(pnet+4,0x7FC00000);assert(not pcall(reader.sample,reader,'world'),'NaN timer accepted');w(pnet+4,0x42960000)
    w(api.game+0x93233a,0,1)
    local changed=make_reader(api,bytes,catalog,O);assert(not pcall(changed.sample,changed,'world'),'wrong timer layout accepted')
    put(api.game+0x93233a,signature)
    w(api.game+0x3326560,0,8);assert(reader:sample('world').sentries[1].remaining==nil,'missing timer invented');w(api.game+0x3326560,pm,8)
    local guard=make_reader(api,bytes,catalog,{verified=false}):sample('world')
    assert(guard.sentries[1].owner==nil and #make_model():update(guard,0)==0)
    w(settings+156,0,1);assert(reader:sample('world').sentries[1].ammo==120,'unchambered feed gained a shot')
    w(settings+156,1,1);w(run+8,0);assert(reader:sample('world').sentries[1].ammo==120)
    w(run+8,242);w(net,1);assert(reader:sample('world').sentries[1].reserve==1)
    -- Static fallback is keyed by the exact 64-bit type, with a linear collision.
    w(wm+104,0);local root,registry=0x2D000000,0x2E000000
    w(api.game+0x346BF98,root,8);w(root+0xF124A0,registry,8)
    -- 0xEF85D6CF58E31D70 % 540 = 244 (computed with integer arithmetic).
    zero(registry+244*16,32);w(registry+244*16,1)
    put(registry+245*16,word(0x58E31D70)..word(0xEF85D6CF));w(registry+245*16+8,2)
    zero(registry+8640+2*160,160);w(registry+8640+2*160+156,1,1)
    assert(reader:sample('world').sentries[1].ammo==121,'full type fallback failed')
    zero(registry+244*16,16);assert(reader:sample('world').sentries[1].ammo==nil,'missing feed fabricated ammo')
    w(wm+104,8)
    local foreign=make_reader(api,bytes,catalog,{verified=true,resolve=function()return '999999999ABCDEF0' end}):sample('world')
    assert(foreign.sentries[1].ammo==nil and #make_model():update(foreign,0)==0,'foreign sentry exposed')
    w(back,desc+24,8);assert(not pcall(reader.sample,reader,'world'),'wrong weapon identity accepted');w(back,desc,8)
    local read=api.read
    api.read=function(at,n) if at==net then return end;return read(at,n) end
    assert(not pcall(reader.sample,reader,'world'),'partial ammo read accepted');api.read=read
    w(hm+0x1020,4097);assert(not pcall(reader.sample,reader,'world'));w(hm+0x1020,1)
    -- Byte-exact full peer IDs and u32 multiplication beyond floating precision.
    assert(bytes.f32(word(0x3f800000),0)==1 and bytes.f32(word(0xbf800000),0)==-1)
    assert(bytes.f32(word(1),0)==2^-149 and bytes.f32(word(0x7f800000),0)==nil)
    assert(bytes.mul32(0xFFFFFFFF,0xFFFFFFFF)==1)
    -- Real renderer: retained handles, resizing, row shrink, font pool recycling.
    local E=make_engine();local ui=make_presentation(E.sr,E.font_ids,nil,icons)
    local rows=step({item('a',88),item('b',70)},2)
    local c=make_config('anchor_player=0\nscale=1\nx=540\ny=48\nmax_rows=6')
    assert(make_config('max_rows=0\nscale=nan').max_rows==6)
    for _,size in ipairs({{1280,720},{1920,1080},{2560,1440},{3440,1440},{3840,2160}}) do
        for _,scale in ipairs({0.5,1,2}) do
            E.width,E.height=size[1],size[2];c.scale=scale
            for frame=1,3 do E.next_frame();ui:draw(rows,c) end
            for _,p in pairs(ui.gui.parts) do
                if p.kind=='rect' then assert(p.at.x>=0 and p.at.y>=0 and p.at.x+p.size.x<=E.width+1 and p.at.y+p.size.y<=E.height+1) end
            end
        end
    end
    E.width,E.height=1920,1080;c.scale=1
    E.next_frame();ui:draw(rows,c);local full=0;for _ in pairs(ui.gui.parts)do full=full+1 end
    ui:draw({rows[1]},c);local short=0;for _ in pairs(ui.gui.parts)do short=short+1 end
    assert(short<full,'removed sentry retained stale labels')
    ui:draw({},c);assert(not ui.visible)
    E.next_frame();ui:draw(rows,c)
    E.worlds={};ui:abandon();assert(E.destroyed==0,'shutdown invoked native GUI cleanup')
    -- Controller restores no stale targets after menus/world changes/read errors.
    E=make_engine();local now,menu,broken=0,false,false;local polls=0
    E.sr.Window={show_cursor=function()return menu end}
    local U={hide=function()end,draw=function(self,r)self.rows=r end,abandon=function(self)self.abandoned=true end}
    local C=make_controller(E.sr,{time=function()return now end},
        {sample=function()polls=polls+1;if broken then error('gone') end;return {peer=peer,world='world',sentries={item('x',12)}} end},
        make_model(),U,c,O,function()end)
    C:tick();now=0.01;C:tick();assert(polls==1)
    now=0.2;broken=true;C:tick();assert(#U.rows==0)
    broken=false;menu=true;C:tick();menu=false;C:tick();assert(#U.rows==1)
    C:shutdown();C:tick();assert(U.abandoned)
    -- Produce preview from actual native draw calls using synthetic input.
    E=make_engine();ui=make_presentation(E.sr,E.font_ids,nil,icons)
    c=make_config('')
    ui:draw({{name='GATLING',type='EF85D6CF58E31D70',hp=280,max=300,ammo=184,status='FIRING',remaining=86.5},
        {name='ROCKET',type='37079568DC86E9C6',hp=600,max=600,ammo=22,reserve=1,status='READY',remaining=9.5}},c,
        {right=416.7,bottom=57.6,top=147.6,scale=0.9,shown=1})
    assert(ui.gui.parts[ui.texts['1:time5']].text=='TIME 01:27')
    assert(ui.gui.parts[ui.texts['2:time5']].text=='TIME 00:10')
    return E
end
