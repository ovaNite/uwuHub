-- roblox_modPack v9 / snow.lua
-- 90 Hz LOCAL SNOW: six-arm microcrystals, wind/drag, ray-swept real hits,
-- pooled powder bursts and irregular wedge-grain snowbanks. No round plates.
return function(ctx)
    local W=ctx.Workspace
    local L=ctx.Lighting
    local player=ctx.Players.LocalPlayer
    local RNG=Random.new(95013)
    local floor=math.floor
    local function rnd(a,b) return RNG:NextNumber(a,b) end
    local cfg={Near=66,Cells=126,Grains=4,Quality=2,
        Range=175,SpawnRate=24,SimHz=90,SampleAttempts=9}
    local roots=ctx.Folder
    local near={}
    local cells={}
    local cellList={}
    local hitCount=0
    local rayCount=0
    local roofRejects=0
    local farHits=0
    local t=0
    local spawnAccumulator=0
    local stepNumber=0
    local probeClock=0
    local roofClock=0
    local outside=true
    local renderClock=0
    local currentCamera=W.CurrentCamera
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide=true
    rayParams.IgnoreWater=false
    local function ray(origin,dir)
        if dir.Magnitude<.0001 then return nil end
        rayCount+=1
        return W:Raycast(origin,dir,rayParams)
    end
    local function makePart(name,size,kind)
        local p=Instance.new(kind or "Part")
        p.Name=name;p.Size=size;p.Anchored=true;p.CanCollide=false
        p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Material=Enum.Material.SmoothPlastic
        p.Color=Color3.fromRGB(246,249,252)
        p.Transparency=1;p.CFrame=CFrame.new(0,-10000,0)
        p.Parent=roots;ctx.Track(p)
        return p
    end
    local function makeFx(name,texture)
        local node=makePart(name.."_Origin",Vector3.new(1,.1,1))
        local emitter=Instance.new("ParticleEmitter")
        emitter.Name=name
        emitter.Texture=texture
        emitter.Enabled=false
        emitter.Rate=0
        emitter.LockedToPart=false
        emitter.LightEmission=.05
        emitter.LightInfluence=.7
        emitter.Drag=1.8
        emitter.VelocityInheritance=0
        emitter.EmissionDirection=Enum.NormalId.Top
        emitter.Lifetime=NumberRange.new(.24,.54)
        emitter.Speed=NumberRange.new(.5,2.4)
        emitter.SpreadAngle=Vector2.new(165,165)
        emitter.Color=ColorSequence.new(
            Color3.fromRGB(248,251,255),Color3.fromRGB(226,232,239))
        emitter.Size=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.045),
            NumberSequenceKeypoint.new(.32,.12),
            NumberSequenceKeypoint.new(1,.04)})
        emitter.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.28),
            NumberSequenceKeypoint.new(.5,.62),
            NumberSequenceKeypoint.new(1,1)})
        emitter.Parent=node
        return node,emitter
    end
    -- Native particles for soft, non-geometric background snowfall.
    local distant={}
    local skyTextures={
        "rbxasset://textures/particles/sparkles_main.dds",
        "rbxasset://textures/particles/smoke_main.dds",
        "rbxasset://textures/particles/sparkles_main.dds"
    }
    for i,range in ipairs({24,62,112}) do
        local box=makePart("SnowField_"..i,Vector3.new(42+i*24,1,47+i*26))
        local emitter=Instance.new("ParticleEmitter")
        emitter.Name="SmallWindFlakes"
        emitter.Texture=skyTextures[i]
        emitter.EmissionDirection=Enum.NormalId.Bottom
        emitter.Enabled=false;emitter.Rate=0
        emitter.Lifetime=NumberRange.new(2.6+i*.6,4.2+i*1.1)
        emitter.Speed=NumberRange.new(.6,1.9)
        emitter.Acceleration=Vector3.new(0,-3.0,0)
        emitter.Drag=1.25
        emitter.VelocityInheritance=0
        emitter.LightInfluence=.68;emitter.LightEmission=0
        emitter.LockedToPart=false
        pcall(function() emitter.Shape=Enum.ParticleEmitterShape.Box end)
        pcall(function() emitter.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume end)
        pcall(function() emitter.WindAffectsDrag=true end)
        emitter.Size=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.035+i*.01),
            NumberSequenceKeypoint.new(.6,.055+i*.025),
            NumberSequenceKeypoint.new(1,.035+i*.01)})
        emitter.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,1),
            NumberSequenceKeypoint.new(.20,.55+i*.04),
            NumberSequenceKeypoint.new(.72,.62+i*.03),
            NumberSequenceKeypoint.new(1,1)})
        emitter.Color=ColorSequence.new(
            Color3.fromRGB(251,253,255),Color3.fromRGB(225,232,241))
        emitter.Rotation=NumberRange.new(0,360)
        emitter.RotSpeed=NumberRange.new(-45,45)
        emitter.Parent=box
        distant[i]={box=box,emitter=emitter,forward=range}
    end

    local powderNodes={}
    for i=1,14 do
        local p,e=makeFx("SnowPowderBurst_"..i,
            "rbxasset://textures/particles/smoke_main.dds")
        powderNodes[i]={p=p,e=e}
    end
    local powderCursor=0
    local function puff(pos,normal,amount)
        powderCursor=powderCursor%#powderNodes+1
        local particle=powderNodes[powderCursor]
        particle.p.CFrame=CFrame.lookAt(pos+normal*.03,pos+normal)
        pcall(function() particle.e:Emit(math.clamp(floor(3+amount*2),3,9)) end)
    end

    local function normalBasis(pos,n)
        local a=math.abs(n.X)<.88 and Vector3.xAxis or Vector3.zAxis
        local x=(a-n*a:Dot(n)).Unit
        return CFrame.fromMatrix(pos,x,n,x:Cross(n))
    end
    -- 6 crystal arms = three crossed tiny bars, not spheres or large squares.
    for i=1,cfg.Near do
        local d={active=false,pos=Vector3.zero,lastChecked=Vector3.zero,vel=Vector3.zero,age=0,
            spin=0,phase=0,size=.08,opacity=.2,step=0,
            target=Vector3.zero,windNoise=0,parts={}}
        for k=1,3 do
            local p=makePart("SixArmFlake",Vector3.new(.1,.006,.012))
            d.parts[k]=p
        end
        near[i]=d
    end
    local function conceal(d)
        d.active=false
        for _,p in ipairs(d.parts) do p.Transparency=1 end
    end

    -- Four sloped WEDGE grains make ragged powder islands; no cylinders,
    -- no ellipsoidal discs, no rigid square floor slabs.
    for i=1,cfg.Cells do
        local c={active=false,last=-1,mass=0,water=0,
            pos=Vector3.zero,normal=Vector3.yAxis,key="",
            shapes={},phase=rnd(0,200)}
        for j=1,cfg.Grains do
            local wedge=makePart("SnowPowderGrain",Vector3.new(.12,.025,.16),"WedgePart")
            wedge.Material=Enum.Material.Snow
            wedge.Color=Color3.fromRGB(
                floor(rnd(241,252)),floor(rnd(245,254)),255)
            c.shapes[j]={p=wedge,yaw=rnd(-math.pi,math.pi),
                x=rnd(-.75,.75),z=rnd(-.75,.75),width=rnd(.5,1.35),
                depth=rnd(.5,1.28),height=rnd(.65,1.30)}
        end
        cellList[i]=c
    end
    local sizeGrid=3.6
    local function hash(p)
        return floor(p.X/sizeGrid)..":"..floor(p.Y/2.8)..":"..floor(p.Z/sizeGrid)
    end
    local function hideCell(c)
        c.active=false
        for _,shape in ipairs(c.shapes) do shape.p.Transparency=1 end
    end
    local function alloc(pos,normal)
        local k=hash(pos)
        local c=cells[k]
        if c and (pos-c.pos).Magnitude<4 then return c end
        local oldest=math.huge
        local candidate
        for _,slot in ipairs(cellList) do
            if not slot.active then candidate=slot;break end
            if slot.last<oldest then oldest=slot.last;candidate=slot end
        end
        if not candidate then return nil end
        if candidate.key~="" then cells[candidate.key]=nil end
        hideCell(candidate)
        candidate.active=true;candidate.pos=pos;candidate.normal=normal
        candidate.key=k;candidate.last=t;candidate.mass=0
        candidate.phase=rnd(0,200)
        cells[k]=candidate
        return candidate
    end
    local function drawCell(c)
        if not c.active then return end
        local growth=math.sqrt(math.max(c.mass,.0001))
        local spread=math.clamp(.09+growth*.45,.09,1.3)
        local basis=normalBasis(c.pos,c.normal)
        for j,shape in ipairs(c.shapes) do
            local p=shape.p
            local layer=(j==1 and 1) or (j==2 and .82) or (j==3 and .67) or .48
            local width=(.13+spread*.24)*shape.width*layer
            local depth=(.18+spread*.28)*shape.depth*layer
            local height=(.008+growth*.025)*shape.height*layer
            p.Size=Vector3.new(width,height,depth)
            p.CFrame=basis*CFrame.new(
                shape.x*spread*.31,height*.15,shape.z*spread*.31)
                *CFrame.Angles(0,shape.yaw,.05*math.sin(t*.06+c.phase+j))
            p.Transparency=math.clamp(.48-growth*.16,.09,.52)
        end
    end

    local function landing(pos,normal)
        hitCount+=1
        local camera=W.CurrentCamera
        if camera and (camera.CFrame.Position-pos).Magnitude>70 then
            farHits+=1
        end
        local c=alloc(pos,normal)
        if c then
            c.mass=math.clamp(c.mass+rnd(.016,.06),0,4)
            c.last=t
            drawCell(c)
        end
        if camera and (camera.CFrame.Position-pos).Magnitude<90 then
            puff(pos,normal,c and c.mass or 0)
        end
    end

    local function visibleLanding(cam)
        local viewport=cam.ViewportSize
        if viewport.X<200 or viewport.Y<140 then return nil end
        local position=cam.CFrame.Position
        for attempt=1,cfg.SampleAttempts do
            local x=rnd(.04,.96)*viewport.X
            local y=rnd(.22,.96)*viewport.Y
            local vr=cam:ViewportPointToRay(x,y)
            local hit=ray(vr.Origin,vr.Direction.Unit*cfg.Range)
            if hit and hit.Normal.Y>.58 and hit.Material~=Enum.Material.Water then
                if hit.Instance==W.Terrain or (hit.Instance:IsA("BasePart") and
                    hit.Instance.Anchored and hit.Instance.Transparency<.45) then
                    -- roof-aware: don't accumulate under a nearby ceiling
                    local roof=ray(hit.Position+Vector3.yAxis*.14,Vector3.yAxis*18)
                    if not roof then return hit end
                    roofRejects+=1
                end
            end
            -- broad forward/side sampling; use occlusion check before accepting
            local depth=rnd(12,147)
            local location=position
                +cam.CFrame.LookVector*depth
                +cam.CFrame.RightVector*rnd(-.40,.40)*depth
            local p=ray(location+Vector3.yAxis*50,Vector3.new(0,-110,0))
            if p and p.Normal.Y>.58 and p.Material~=Enum.Material.Water then
                local screen,onScreen=cam:WorldToViewportPoint(p.Position)
                if onScreen and screen.Z>0 then
                    local d=p.Position-position
                    local visible=ray(position,d)
                    if visible and (visible.Position-p.Position).Magnitude<1.9 then
                        local roof=ray(p.Position+Vector3.yAxis*.14,Vector3.yAxis*18)
                        if not roof then return p end
                    end
                end
            end
        end
        return nil
    end
    local function spawn(d,cam)
        local target=visibleLanding(cam)
        if not target then return end
        d.active=true;d.age=0;d.step=0
        d.target=target.Position
        d.phase=rnd(0,math.pi*2);d.spin=rnd(-1.2,1.2)
        d.size=rnd(.07,.16)
        d.opacity=rnd(.13,.32)
        local height=rnd(4.2,12)
        local wind=Vector3.zero
        pcall(function() wind=W.GlobalWind end)
        local drift=Vector3.new(wind.X,0,wind.Z)*.12
        d.pos=target.Position+Vector3.new(rnd(-.6,.6),height,rnd(-.6,.6))
            -drift*(height/5)
        d.lastChecked=d.pos
        d.vel=Vector3.new(drift.X+rnd(-.7,.7),-rnd(2.2,4.5),
            drift.Z+rnd(-.7,.7))
    end

    local activeCount=0
    local function updateFlake(d,dt,cam)
        if not d.active then return end
        local wind=Vector3.zero
        pcall(function()wind=W.GlobalWind end)
        local sx,sz=wind.X*.15,wind.Z*.15
        local turbulence=Vector3.new(
            math.sin(t*.91+d.phase)*.95,0,
            math.cos(t*1.33+d.phase)*.81)
        local desired=Vector3.new(sx,0,sz)+turbulence
        local vx=d.vel.X+(desired.X-d.vel.X)*math.min(dt*1.1,1)
        local vz=d.vel.Z+(desired.Z-d.vel.Z)*math.min(dt*1.1,1)
        local vy=math.max(-8.2,d.vel.Y-(W.Gravity*.068)*dt)
        d.vel=Vector3.new(vx,vy,vz)
        local prior=d.pos
        local nextPos=prior+d.vel*dt
        d.age+=dt
        d.pos=nextPos
        d.step+=dt
        -- Math integrates at 90 Hz. Ray sweeps at ~12 Hz except within 1.7
        -- studs of the target, where a swept check runs on every substep.
        local close=(nextPos-d.target).Magnitude<1.8
        if d.step>.080 or close then
            d.step=0
            local hit=ray(d.lastChecked,nextPos-d.lastChecked)
            d.lastChecked=nextPos
            if hit then
                if hit.Normal.Y>.5 then landing(hit.Position,hit.Normal) end
                conceal(d);return
            end
            -- target is already verified from a prior camera ray. Check near-
            -- ground sweep longer to avoid tunneling on a low frame rate.
            if nextPos.Y<d.target.Y+.6 then
                local p=ray(nextPos+Vector3.yAxis*1.0,Vector3.new(0,-2.4,0))
                if p and p.Normal.Y>.5 and (p.Position-d.target).Magnitude<3.8 then
                    landing(p.Position,p.Normal)
                    conceal(d);return
                end
            end
        end
        if d.age>9 or nextPos.Y<d.target.Y-2.1 then
            conceal(d);return
        end
        activeCount+=1
    end
    local function renderFlake(d,cam)
        if not d.active then
            for _,part in ipairs(d.parts) do part.Transparency=1 end
            return
        end
        local vp,vis=cam:WorldToViewportPoint(d.pos)
        if not vis or vp.Z<0 then
            for _,part in ipairs(d.parts) do part.Transparency=1 end
            return
        end
        local base=CFrame.lookAt(d.pos,cam.CFrame.Position)
            *CFrame.Angles(math.sin(t*.6+d.phase)*.15,
                math.cos(t*.8+d.phase)*.12,d.phase+t*d.spin)
        local radius=d.size
        for i,p in ipairs(d.parts) do
            p.Size=Vector3.new(radius*(i==1 and 1 or .78),.008,
                radius*.095)
            p.CFrame=base*CFrame.Angles(0,0,(i-1)*math.pi/3)
            p.Transparency=d.opacity+(vp.Z>45 and .19 or 0)
        end
    end

    local function updateEmitters(cam,dt,mode)
        local strength=math.clamp(ctx.Base.weatherIntensity or .5,.01,1)
        local cameraPosition=cam.CFrame.Position
        for i,field in ipairs(distant) do
            local forward=cam.CFrame.LookVector*field.forward
            field.box.CFrame=CFrame.new(cameraPosition+forward
                +Vector3.new(0,18+i*5,0))
            field.emitter.Enabled=outside and mode=="SNOW"
            field.emitter.Rate=outside and
                (strength*(i==1 and 31 or i==2 and 55 or 95))*(cfg.Quality/2)
                or 0
            field.emitter.Acceleration=Vector3.new(0,-3.5,0)
        end
    end

    local snowSimSteps=0
    local lastStats=os.clock()
    local drawClock=0
    ctx.AddStep(function(dt,visual)
        t+=dt;drawClock+=dt;snowSimSteps+=1
        local cam=W.CurrentCamera
        if not cam then return end
        local mode=ctx.Base.enabled and ctx.Base.weatherMode or "OFF"
        if mode~="SNOW" then
            if activeCount>0 then
                for _,flake in ipairs(near) do conceal(flake) end
                activeCount=0
            end
            for _,field in ipairs(distant) do field.emitter.Enabled=false end
            return
        end
        rayParams.FilterDescendantsInstances={
            roots,cam,
        }
        local char=player.Character
        if char then
            rayParams.FilterDescendantsInstances={roots,cam,char}
        end
        roofClock+=dt
        if roofClock>.55 then
            roofClock=0
            local roof=ray(cam.CFrame.Position+Vector3.yAxis,
                Vector3.yAxis*42)
            outside=roof==nil
        end
        if not outside then
            for _,field in ipairs(distant) do field.emitter.Enabled=false end
        end
        local strength=math.clamp(ctx.Base.weatherIntensity or .5,.01,1)
        spawnAccumulator+=dt*cfg.SpawnRate*(strength^.65)
        local spawnBudget=math.min(3,floor(spawnAccumulator))
        spawnAccumulator-=spawnBudget
        for _=1,spawnBudget do
            for idx,d in ipairs(near) do
                if idx<=(cfg.Quality==1 and 28 or cfg.Quality==2 and 48 or 66)
                    and not d.active then
                    spawn(d,cam)
                    break
                end
            end
        end
        activeCount=0
        for _,flake in ipairs(near) do updateFlake(flake,dt,cam) end
        -- updates are visual only once per rendered frame; physics stays 90Hz.
        if visual and drawClock>=1/60 then
            drawClock=0
            for _,flake in ipairs(near) do renderFlake(flake,cam) end
            updateEmitters(cam,dt,mode)
            -- Large snow deposits melt more slowly, and wet weather melts
            -- faster. This is a visual mass model, not Terrain deformation.
            local sun=math.clamp(math.sin((L.ClockTime-6)*math.pi/12),0,1)
            local drawn=0
            for _,c in ipairs(cellList) do
                if c.active then
                    local meltRate=(.00012+sun*.00008)/(1+c.mass*4)
                    c.mass=math.max(0,c.mass-meltRate*dt)
                    if c.mass<.002 then
                        hideCell(c)
                        cells[c.key]=nil;c.key=""
                    else
                        drawn+=1
                        if drawn<=65 then drawCell(c) end
                    end
                end
            end
            ctx.Stats.SnowCells=drawn
        end
        if os.clock()-lastStats>=1 then
            ctx.Stats.SnowTracked=activeCount
            ctx.Stats.SnowImpacts=hitCount
            ctx.Stats.SnowFarLandings=farHits
            ctx.Stats.SnowRaycasts=rayCount
            ctx.Stats.SnowRoofRejected=roofRejects
            ctx.Stats.SnowSimulationHz=snowSimSteps/(os.clock()-lastStats)
            snowSimSteps=0;lastStats=os.clock()
        end
    end)
    ctx.Snow={
        SetQuality=function(value)
            cfg.Quality=math.clamp(math.floor(tonumber(value) or 2),1,3)
            ctx.Stats.SnowQuality=cfg.Quality
        end,
        CycleQuality=function()
            cfg.Quality=(cfg.Quality%3)+1
            ctx.Stats.SnowQuality=cfg.Quality
            return ({"ECO","BALANCED","ULTRA"})[cfg.Quality]
        end,
        GetQuality=function() return cfg.Quality end
    }
    ctx.Stats.SnowQuality=cfg.Quality
    ctx.Link(ctx.UserInputService.InputBegan,function(input,processed)
        if not processed and input.KeyCode==Enum.KeyCode.F5 then
            print("[RM9] Snow detail: "..ctx.Snow.CycleQuality())
        end
    end)
    ctx.AddStop(function()
        for _,flake in ipairs(near) do conceal(flake) end
        for _,c in ipairs(cellList) do hideCell(c) end
        for _,field in ipairs(distant) do field.emitter.Enabled=false end
    end)
    return {Name="90Hz six-arm snow / powder collisions / wedge accumulation"}
end