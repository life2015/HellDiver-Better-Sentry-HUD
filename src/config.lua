return function(text)
    local c={anchor_player=1,panel_gap=12,x=540,y=48,scale=1,max_rows=6,poll_interval=0.125}
    local limits={anchor_player={0,1},panel_gap={0,160},x={0,1800},y={0,1000},scale={0.5,2},max_rows={1,10},poll_interval={0.05,1}}
    for line in (text or ''):gmatch('[^\r\n]+') do
        local k,v=line:match('^%s*([%a_]+)%s*=%s*([%d%.]+)%s*$');v=tonumber(v)
        local range=k and limits[k]
        if range and v and v>=range[1] and v<=range[2] then
            if k~='anchor_player' or v==0 or v==1 then c[k]=k=='max_rows' and math.floor(v) or v end
        end
    end
    return c
end
