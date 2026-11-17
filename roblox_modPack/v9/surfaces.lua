-- roblox_modPack v9 / wet_finish.lua | NO ROUND PUDDLE PARTS
-- Reversible local materials for static floors/walls + impact-linked wet lenses.
-- No replacement of existing Texture, Decal, SurfaceAppearance or game geometry.
return function(ctx)
    local W,L=ctx.Workspace,ctx.Lighting
    local player=ctx.Players.LocalPlayer
    local original,watched,wallSeen={}, {}, {}
    local lensPool,cellMap={},{}
    local MAX_LENSES=0 -- no spherical puddles; surface specular only
    local wetHits=0
    local totalFloors,totalWalls=0,0
    local rand=Random.new(6132)
    local timer=0
    local previousWeather=nil
    local function r(a,b)return rand:NextNumber(a,b) end
    local function own(part,prop,value)
        local values=original[part]
        if not values then values={};original[part]=values end
        if values[prop]==nil then
            local ok,old=pcall(function()return part[prop]end)
            if not ok then return end
            values[prop]=old
        end
        pcall(function()part[prop]=value end)
    end
    local function restoreAll()
        for inst,values in pairs(original) do
            for property,value in pairs(values) do
                pcall(function()inst[property]=value end)
            end
        end
        table.clear(original)
        table.clear(watched)
        table.clear(wallSeen)
    end
    local function isStatic(part)
        if not part or not part:IsA("BasePart") or not part.Anchored
            or not part.CanCollide or part.Transparency>.30 then return false end
        local char=player.Character
        if char and part:IsDescendantOf(char) then return false end
        if part:IsDescendantOf(ctx.Folder) then return false end
        return true
    end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.IgnoreWater=false
    local function scan()
        if not ctx.Base.enabled or not ctx.Options.WorldFinish then return end
        local camera=W.CurrentCamera
        if not camera then return end
        rp.FilterDescendantsInstances={ctx.Folder,player.Character}
        local focus=camera.CFrame.Position
        local horizontal=Vector3.new(camera.CFrame.LookVector.X,0,camera.CFrame.LookVector.Z)
        if horizontal.Magnitude<.01 then horizontal=Vector3.zAxis end
        horizontal=horizontal.Unit
        local right=Vector3.new(-horizontal.Z,0,horizontal.X)
        for i=1,18 do
            local forward=r(-21,21)
            local sideways=r(-22,22)
            local origin=focus+horizontal*forward+right*sideways+Vector3.new(0,13,0)
            local hit=W:Raycast(origin,Vector3.new(0,-60,0),rp)
            if hit and isStatic(hit.Instance) and hit.Normal.Y>.75 then
                local part=hit.Instance
                if not watched[part] and part.Size.Magnitude>5 then
                    watched[part]=true
                    totalFloors+=1
                    local wet=ctx.Base.weatherMode=="RAIN"
                    own(part,"Material",wet and Enum.Material.SmoothPlastic
                        or (part.Material==Enum.Material.Plastic and Enum.Material.Concrete
                        or part.Material))
                    -- Real visible engine specular response. Material does not
                    -- give realtime SSR; underlying game decals stay as they are.
                    own(part,"Reflectance",wet and .23 or .045)
                    if wet then
                        local c=part.Color
                        own(part,"Color",c:Lerp(Color3.fromRGB(40,45,50),.075))
                    end
                end
            end
        end
        for i=1,11 do
            local a=(i/11)*math.pi*2
            local direct=Vector3.new(math.cos(a),r(-.12,.18),math.sin(a))*26
            local hit=W:Raycast(focus,direct,rp)
            if hit and isStatic(hit.Instance) and math.abs(hit.Normal.Y)<.4 then
                local part=hit.Instance
                if not wallSeen[part] and part.Size.Magnitude>7 then
                    wallSeen[part]=true
                    totalWalls+=1
                    -- Keep decals & original grid. Refine only underlying
                    -- material for untextured static neutral structure.
                    local _,s,v=part.Color:ToHSV()
                    if s<.28 and v>.19 and v<.98 and
                        (part.Material==Enum.Material.Plastic
                        or part.Material==Enum.Material.SmoothPlastic) then
                        own(part,"Material",Enum.Material.Concrete)
                        own(part,"Reflectance",.025)
                    end
                end
            end
        end
        ctx.Stats.WetFloors=totalFloors
        ctx.Stats.WallCandidates=totalWalls
    end
    local function makeLens()
        local part=Instance.new("Part")
        part.Name="RM6_ImpactWetLens"
        part.Size=Vector3.one
        part.Anchored=true
        part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
        part.CastShadow=false
        part.Material=Enum.Material.Glass
        part.Reflectance=.18
        part.Color=Color3.fromRGB(100,124,135)
        part.Transparency=1
        part.Parent=ctx.Folder
        ctx.Track(part)
        local mesh=Instance.new("SpecialMesh")
        mesh.MeshType=Enum.MeshType.Sphere
        mesh.Scale=Vector3.new(1,.012,1)
        mesh.Parent=part
        return {p=part,mesh=mesh,r=0,depth=0,life=0,key=nil,pos=Vector3.zero,normal=Vector3.yAxis}
    end
    for i=1,MAX_LENSES do lensPool[i]=makeLens() end
    local function key(pos)
        return math.floor(pos.X/2.6)..":"..math.floor(pos.Y/3.0)..":"..math.floor(pos.Z/2.6)
    end
    local function basis(pos,normal)
        local n=normal.Unit
        local axis=math.abs(n.X)<.85 and Vector3.xAxis or Vector3.zAxis
        local x=(axis-n*axis:Dot(n)).Unit
        return CFrame.fromMatrix(pos,x,n,x:Cross(n))
    end
    local function acceptImpact(pos,normal,isSnow,amount,part)
        if isSnow or not ctx.Base.enabled or not ctx.Options.WorldFinish then return end
        if not normal or normal.Y<.78 then return end
        local camera=W.CurrentCamera
        if not camera or (camera.CFrame.Position-pos).Magnitude>55 then return end
        local k=key(pos)
        local slot=cellMap[k]
        if slot and slot.life>0 then
            slot.r=math.min(slot.r+.018,2.0)
            slot.life=math.max(slot.life,12)
            wetHits+=1
            return
        end
        for _,x in ipairs(lensPool) do
            if x.life<=0 then slot=x;break end
        end
        if not slot then return end
        if slot.key then cellMap[slot.key]=nil end
        slot.key=k;cellMap[k]=slot;slot.life=11;slot.r=r(.22,.42)
        slot.depth=r(.008,.018)
        slot.pos=pos;slot.normal=normal
        slot.p.Transparency=.78
        wetHits+=1
    end
    if type(ctx.Base.AddWeatherImpactListener)=="function" then
        ctx.AddStop(ctx.Base.AddWeatherImpactListener(acceptImpact))
    end
    local doRender=0
    ctx.AddStep(function(dt,render)
        local mode=ctx.Base.weatherMode
        if mode~=previousWeather then
            previousWeather=mode
            if next(original) then restoreAll() end
            totalFloors=0;totalWalls=0
        end
        timer+=dt
        doRender+=dt
        if timer>.68 then timer=0;scan() end
        local active=0
        local wet=ctx.Base.enabled and ctx.Options.WorldFinish and
            ctx.Base.weatherMode=="RAIN"
        for _,lens in ipairs(lensPool) do
            if lens.life>0 then
                lens.life-=dt*(wet and .10 or .8)
                if lens.life<=0 then
                    lens.p.Transparency=1
                    if lens.key then cellMap[lens.key]=nil;lens.key=nil end
                else
                    active+=1
                    if render and doRender>=.04 then
                        local radius=lens.r*math.clamp(1+(11-lens.life)*.075,1,1.6)
                        lens.mesh.Scale=Vector3.new(radius*2,lens.depth*1.3,radius*1.75)
                        lens.p.CFrame=basis(lens.pos+lens.normal*.016,lens.normal)
                        lens.p.Transparency=wet and (.74+math.min(.20,(11-lens.life)*.014)) or 1
                    end
                end
            end
        end
        if doRender>.04 then doRender=0 end
        ctx.Stats.WetPuddles=active
        ctx.Stats.WetImpactHits=wetHits
    end)
    ctx.AddRender(function()
        if not ctx.Base.enabled or not ctx.Options.WorldFinish then
            if next(original) then restoreAll() end
            for _,lens in ipairs(lensPool) do lens.p.Transparency=1 end
        end
    end)
    ctx.AddStop(function()
        restoreAll()
        for _,lens in ipairs(lensPool) do lens.p.Transparency=1 end
    end)
    return {Name="Real local static materials and wet lenses"}
end