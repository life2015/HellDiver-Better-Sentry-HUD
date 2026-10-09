-- Real player and four overhead camera poses. Exercise every cyclic ordering:
-- World.units_by_resource does not promise the player camera is first.
return function(engine,markers,presentation,config,icons,fixture)
    for _,sample in ipairs(fixture.samples) do
        local E=engine();local meta={};local V={}
        setmetatable(V,{__call=function(_,x,y,z)return setmetatable({x=x,y=y,z=z},meta)end})
        meta.__sub=function(a,b)return V(a.x-b.x,a.y-b.y,a.z-b.z)end
        V.x=function(p)return p.x end;V.y=function(p)return p.y end
        V.dot=function(a,b)return a.x*b.x+a.y*b.y+a.z*b.z end
        E.sr.Vector3=V
        E.sr.Matrix4x4={translation=function(m)return V(m[13],m[14],m[15])end,
            forward=function(m)return V(m[5],m[6],m[7])end}
        local poses,order={},{}
        for _,c in ipairs(sample.cameras) do poses[c.id]=c.pose;order[#order+1]=c.id end
        E.sr.World.debug_camera_pose=function()return sample.view end
        E.sr.World.units_by_resource=function()return order end
        E.sr.Unit={camera=function(id)return id end}
        local chosen
        E.sr.Camera={world_pose=function(id)return poses[id] end,
            world_to_screen=function(id,p,window,viewport)
                chosen=id;assert(id==sample.player,'selected the stationary overhead camera')
                assert(viewport.x==E.width and viewport.y==E.height)
                return V(500,300,0),0.001
            end}
        local positions={map_open=function()return false end,sample=function()
            -- Target choice is synthetic; this regression validates selection
            -- from real camera poses, not native projection accuracy.
            local m=sample.view
            return {x=m[13]+50*m[5],y=m[14]+50*m[6],z=m[15]+50*m[7]}
        end}
        local M=markers(E.sr,positions,presentation,icons,E.font_ids)
        local row={key='own',type='37CDE43876BA26BB',hp=300,max=600,ammo=10}
        for i=1,#order do
            E.next_frame();M:draw({row},config(''), 'main')
            assert(M.ui.visible and chosen==sample.player)
            local first=table.remove(order,1);order[#order+1]=first
        end
        for i=#order,1,-1 do if order[i]==sample.player then table.remove(order,i) end end
        chosen=nil;E.next_frame();M:draw({row},config(''),'main')
        assert(not M.ui.visible and chosen==nil,'projected with map camera after player camera disappeared')
    end
end
