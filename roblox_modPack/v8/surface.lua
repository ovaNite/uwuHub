-- roblox_modPack / surface v8: distant impacts and soft layered accumulation
-- Organic, evolving local snow mounds and rounded puddles. No square tiles.
-- Deposits are triggered by verified weather collisions from the 90Hz core.
return function(ctx)
    local W,L=ctx.Workspace,ctx.Lighting
    local rng=Random.new()
    local N=104
    local grid=3.2
    local cells,slots={},{}
    local time=0
    local useCount=0
    local farImpactCount=0
    local function random(a,b) return rng:NextNumber(a,b) end
    local function createLens(name,material,color)
        local p=Instance.new("Part")
        p.Name=name;p.Size=Vector3.one;p.Shape=Enum.PartType.Block
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
        p.CastShadow=false;p.Material=material;p.Color=color;p.Reflectance=0
        p.Transparency=1;p.CFrame=CFrame.new(0,-10000,0)
        p.Parent=ctx.Folder;ctx.Track(p)
        local mesh=Instance.new("SpecialMesh")
        mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=Vector3.one
        mesh.Parent=p
        return p,mesh
    end
    for i=1,N do
        local slot={used=false,water=0,snow=0,last=0,seed=random(0,200),lumps={}}
        slot.wet,slot.wetMesh=createLens("RM5_OrganicPuddle",Enum.Material.Glass,
            Color3.fromRGB(94,110,120))
        slot.wet.Reflectance=.12
        for j=1,4 do
            local colors={
                Color3.fromRGB(248,251,254),
                Color3.fromRGB(238,245,251),
                Color3.fromRGB(251,253,255),
                Color3.fromRGB(243,247,250)}
            local p,m=createLens("RM5_OrganicSnowMound",Enum.Material.Snow,colors[j])
            slot.lumps[j]={
                part=p,mesh=m,
                radius=random(.46,1.15),
                depth=random(.47,1.06),
                offset=Vector2.new(random(-.46,.46),random(-.46,.46)),
                height=random(.54,1.40),
                rotation=random(-math.pi,math.pi),
            }
        end
        slots[i]=slot
    end
    local function key(position)
        return math.floor(position.X/grid)..":"
            ..math.floor(position.Y/2.6)..":"
            ..math.floor(position.Z/grid)
    end
    local function disappear(c)
        c.wet.Transparency=1
        for _,l in ipairs(c.lumps) do l.part.Transparency=1 end
    end
    local function pop()
        local target=nil
        local oldest=math.huge
        for _,c in ipairs(slots) do
            if not c.used then return c end
            if c.last<oldest then target=c;oldest=c.last end
        end
        if target then
            cells[target.key]=nil
            disappear(target)
        end
        return target
    end
    local function startCell(position,normal)
        local k=key(position)
        local c=cells[k]
        if c and (c.pos-position).Magnitude<grid*1.5 then return c end
        c=pop();if not c then return end
        c.key=k;c.used=true;c.snow=0;c.water=0;c.last=time
        c.pos=position;c.normal=normal.Unit;c.seed=random(0,200)
        c.width=random(.86,1.28)
        c.windDrift=Vector2.new(0,0)
        for _,l in ipairs(c.lumps) do
            l.offset=Vector2.new(random(-.6,.6),random(-.6,.6))
            l.radius=random(.54,1.06);l.depth=random(.56,1.20)
            l.height=random(.60,1.42)
            l.rotation=random(-math.pi,math.pi)
        end
        cells[k]=c
        return c
    end
    local accepted,impacts=0,0
    local function deposit(position,normal,isSnow,amount,object)
        local camera=W.CurrentCamera
        if not camera or (position-camera.CFrame.Position).Magnitude>180 then return end
        if normal.Y<.61 then return end
        if object and object:IsA("BasePart") and (
            not object.Anchored or object.Transparency>.42) then return end
        -- Cap expensive new cells and decouple visual density from physics events.
        impacts+=1
        if (position-camera.CFrame.Position).Magnitude>78 then farImpactCount+=1 end
        local chance=isSnow and .94 or .54
        if random(0,1)>chance then return end
        local c=startCell(position,normal)
        if not c then return end
        c.last=time;accepted+=1
        local weatherStrength=math.clamp(ctx.Base.weatherIntensity or 1,.01,1)
        if isSnow then
            local fall=math.max(.006,amount or .012)
            c.snow=math.clamp(c.snow+fall*random(.7,1.5)*weatherStrength,0,3.8)
            -- Small wind-driven avalanches redistribute mass, not free-floating tiles.
            local wind=Vector3.zero
            pcall(function() wind=W.GlobalWind end)
            local drift=Vector2.new(wind.X,wind.Z)
            if drift.Magnitude>.1 then
                c.windDrift=Vector2.new(
                    math.clamp(c.windDrift.X+drift.X*.00016,-.44,.44),
                    math.clamp(c.windDrift.Y+drift.Y*.00016,-.44,.44))
            end
        else
            c.water=math.clamp(c.water+math.max(.01,amount or .016)*random(.6,1.3),0,2.8)
        end
    end
    local stopListen=nil
    if type(ctx.Base.AddWeatherImpactListener)=="function" then
        stopListen=ctx.Base.AddWeatherImpactListener(deposit)
    end
    if stopListen then ctx.AddStop(stopListen) end
    local function plane(c)
        local n=c.normal
        local axis=math.abs(n.X)<.9 and Vector3.xAxis or Vector3.zAxis
        local right=(axis-n*axis:Dot(n)).Unit
        local depth=right:Cross(n)
        return CFrame.fromMatrix(c.pos,right,n,depth)
    end
    local function draw(c)
        if not c.used then return end
        local basis=plane(c)
        local mass=c.snow
        local wet=c.water
        if wet<.018 then
            c.wet.Transparency=1
        else
            local radius=.15+math.sqrt(wet)*c.width*1.20
            local height=.01+.010*math.sqrt(wet)
            c.wetMesh.Scale=Vector3.new(radius*2,height,radius*1.65)
            c.wet.CFrame=basis*CFrame.new(0,height*.13,0)
            c.wet.Transparency=math.clamp(.88-wet*.12,.58,.90)
        end
        if mass<.012 then
            for _,l in ipairs(c.lumps) do l.part.Transparency=1 end
        else
            local growth=math.clamp(mass/2.8,0,1.25)
            local broad=.17+math.sqrt(mass)*.17
            -- Four overlapping smooth, differently tilted ellipsoids form one mound.
            -- There are no rectangular edges or flat snow planes.
            for index,l in ipairs(c.lumps) do
                local share=(index==1 and 1 or index==2 and .80 or index==3 and .60 or .43)
                local width=(broad+.16)*l.radius*c.width*share
                local depth=(broad+.11)*l.depth*c.width*share
                local height=(.012+math.sqrt(mass)*.10)*l.height*share
                local dx=l.offset.X*broad+c.windDrift.X*share
                local dz=l.offset.Y*broad+c.windDrift.Y*share
                l.mesh.Scale=Vector3.new(width*2,height*2,depth*2)
                l.part.CFrame=basis*CFrame.new(dx,height*.07,dz)
                    * CFrame.Angles(0,l.rotation,.02*math.sin(c.seed+index))
                l.part.Transparency=math.clamp(.70-mass*.12,.25,.70)
            end
        end
    end
    local renderAccum=0
    local rainMelting=0
    ctx.AddStep(function(dt,visual)
        time+=dt;renderAccum+=dt
        if not ctx.Base.enabled then
            if visual then for _,c in ipairs(slots) do disappear(c) end end
            return
        end
        local mode=ctx.Base.weatherMode
        local clock=L.ClockTime
        local sun=math.clamp(math.sin((clock-6)*math.pi/12),0,1)
        local active=0
        local wetCells=0
        local snowCells=0
        for _,c in ipairs(slots) do
            if c.used then
                active+=1
                -- More thickness -> smaller exposed surface / mass ratio -> slower melting.
                -- Rain accelerates melting, but does not erase mounds instantly.
                local meltBase=(mode=="RAIN" and .0011 or .00007)+sun*.00026
                local melt=meltBase*dt/(1+c.snow*2.5)
                local lost=math.min(c.snow,melt)
                c.snow-=lost
                c.water=math.min(2.8,c.water+lost*.87)
                rainMelting+=lost
                -- Gentle evaporation and slope-dependent runoff
                local slope=math.sqrt(math.max(0,1-c.normal.Y*c.normal.Y))
                c.water=math.max(0,c.water-dt*(.0006+slope*.010))
                if c.snow>.015 then snowCells+=1 end
                if c.water>.02 then wetCells+=1 end
                if time-c.last>240 and c.snow<.008 and c.water<.012 then
                    c.used=false;cells[c.key]=nil;disappear(c)
                end
            end
        end
        if renderAccum>.12 then
            renderAccum=0
            for _,c in ipairs(slots) do if c.used then draw(c) end end
        end
        ctx.Stats.SurfacePatches=active
        ctx.Stats.OrganicSnowMounds=snowCells
        ctx.Stats.OrganicPuddles=wetCells
        ctx.Stats.WeatherImpacts=impacts
        ctx.Stats.OrganicDeposits=accepted
        ctx.Stats.FarSnowHits=farImpactCount
        ctx.Stats.SnowMeltMass=rainMelting
    end)
    return {Name="Rounded hills, melt and water",Stop=function()
        if stopListen then pcall(stopListen) end
        for _,c in ipairs(slots) do disappear(c) end
    end}
end