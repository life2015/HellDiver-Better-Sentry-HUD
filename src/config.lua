return function(text)
    local c={enabled=1,layout=1,anchor_player=1,panel_gap=12,x=540,y=48,
        right_margin=48,right_vertical_offset=0,scale=1,max_rows=6,poll_interval=0.125,
        markers_enabled=1,marker_show_distance=1,marker_scale=1,marker_distance=300,hud_opacity=100,marker_opacity=60}
    local limits={enabled={0,1},layout={1,3},anchor_player={0,1},panel_gap={0,160},
        x={0,1800},y={0,1000},right_margin={0,400},right_vertical_offset={-450,450},
        scale={0.5,2},max_rows={1,10},poll_interval={0.05,1},
        markers_enabled={0,1},marker_show_distance={0,1},marker_scale={0.5,2},marker_distance={25,500},hud_opacity={0,100},marker_opacity={0,100}}
    local explicit_layout=false
    for line in (text or ''):gmatch('[^\r\n]+') do
        local k,v=line:match('^%s*([%a_]+)%s*=%s*([%-]?[%d%.]+)%s*$');v=tonumber(v)
        local range=k and limits[k]
        if range and v and v>=range[1] and v<=range[2] then
            local integer=k=='anchor_player' or k=='enabled' or k=='layout' or k=='markers_enabled' or k=='marker_show_distance'
            if not integer or v==math.floor(v) then
                c[k]=k=='max_rows' and math.floor(v) or v
                if k=='hud_opacity' or k=='marker_opacity' then c[k]=math.floor(v/5+0.5)*5 end
                if k=='layout' then explicit_layout=true end
            end
        end
    end
    if not explicit_layout then c.layout=c.anchor_player==0 and 3 or 1 end
    c.anchor_player=c.layout==1 and 1 or 0
    return c
end
