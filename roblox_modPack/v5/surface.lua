-- roblox_modPack v5 / surface.lua
-- 90Hz local shallow snowpack & melt on nearby fixed roofs, ledges, and floors.
-- Small, reversible visual patches. This is not terrain voxel/rigid body physics.
return function(ctx)
    local W,L=ctx.Workspace,ctx.Lighting
    local pool,cells={},{}
    local rng=Random.new()
    local MAX=95
    local t,probeAccum,renderAccum,footAccum=0,0,0,0
    local snowSound=Instance.new("Sound")
    snowSound.Name="RM5_SnowSteps"
    snowSound.Volume=.18
    snowSound.Parent=ctx.Folder
    ctx.Track(snowSound)
    local cellSize=3.1
    local function rand(a,b)return rng:NextNumber(a,b)end
    local function key(v)
        return math.floor(v.X/cellSize)..":"..math.floor(v.Y/3)..":"..math.floor(v.Z/cellSize)
    end
    local function part(name,material,color)
        local p=Instance.new("Part")
        p.Name=name;p.Anchored=true;p.CanCollide=false
        p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Material=material;p.Color=color;p.Transparency=1
        p.Size=Vector3.new(1,.02,1)
        p.CFrame=CFrame.new(0,-10000,0)
        p.Parent=ctx.Folder;ctx.Track(p)
        return p
    end
    for i=1,MAX do
        pool[i]={snow=part("RM5_SnowRoof",Enum.Material.Snow,
            Color3.fromRGB(220,227,230)),
            wet=part("RM5_WetRoof",Enum.Material.Glass,
            Color3.fromRGB(88,99,106)),
            mass=0,water=0,last=0,used=false}
    end
    local function evict()
        local best,old=nil,math.huge
        for _,c in ipairs(pool) do
            if not c.used then return c end
            if c.last<old then old=c.last;best=c end
        end
        if best then
            cells[best.key]=nil
            best.snow.Transparency=1;best.wet.Transparency=1
        end
        return best
    end
    local function ensure(hit)
        local k=key(hit.Position)
        local c=cells[k]
        if c and math.abs(c.pos.Y-hit.Position.Y)>1.1 then
            c=nil
        end
        if c then return c end
        c=evict();if not c then return end
        c.key=k;c.used=true;c.pos=hit.Position;c.normal=hit.Normal
        c.mass=0;c.water=0;c.last=t
        c.width=rand(1.2,2.8)
        cells[k]=c
        return c
    end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.IgnoreWater=false
    local function collect()
        local camera=W.CurrentCamera
        if not camera then return end
        local loc=camera.CFrame.Position
        rp.FilterDescendantsInstances={ctx.Folder, ctx.Players.LocalPlayer.Character}
        for _=1,3 do
            local x,z=rand(-32,32),rand(-32,32)
            local origin=loc+Vector3.new(x,45,z)
            local hit=W:Raycast(origin,Vector3.new(0,-94,0),rp)
            if hit and hit.Normal.Y>.58 and hit.Material~=Enum.Material.Water then
                local object=hit.Instance
                local valid=(object==W.Terrain)
                    or (object and object:IsA("BasePart") and object.Anchored
                        and object.Transparency<.4 and not object:IsDescendantOf(
                            ctx.Players.LocalPlayer.Character or ctx.Folder))
                if valid then
                    local c=ensure(hit)
                    if c then
                        c.last=t
                        c.pos=hit.Position;c.normal=hit.Normal
                        if ctx.Base.weatherMode=="SNOW" then
                            c.mass=math.min(1.0,c.mass+rand(.006,.019)
                                *ctx.Base.weatherIntensity)
                        elseif ctx.Base.weatherMode=="RAIN" then
                            c.water=math.min(1.0,c.water+rand(.01,.03)
                                *ctx.Base.weatherIntensity)
                        end
                    end
                end
            end
        end
    end
    local function draw(c)
        if not c.used then return end
        -- Normal based alignment: patches follow sloped roofs and stone ledges.
        local axis=c.normal
        local a=math.abs(axis.X)<.9 and Vector3.new(1,0,0) or Vector3.new(0,0,1)
        local right=(a-axis*a:Dot(axis)).Unit
        local front=right:Cross(axis)
        local basis=CFrame.fromMatrix(c.pos,right,axis,front)
        local snowThickness=.014+c.mass*.075
        c.snow.CFrame=basis*CFrame.new(0,snowThickness*.5+.008,0)
        c.snow.Size=Vector3.new(c.width,snowThickness,c.width)
        c.snow.Transparency=c.mass>.015 and math.clamp(.77-c.mass*.56,.16,.95) or 1
        c.wet.CFrame=basis*CFrame.new(0,.014,0)
        c.wet.Size=Vector3.new(c.width,.009,c.width)
        c.wet.Transparency=c.water>.02 and math.clamp(.94-c.water*.14,.71,.99) or 1
    end
    ctx.AddStep(function(dt,visual)
        if not ctx.Base.enabled then
            if visual then
                for _,c in ipairs(pool) do
                    c.snow.Transparency=1;c.wet.Transparency=1
                end
            end
            return
        end
        t+=dt;probeAccum+=dt;renderAccum+=dt;footAccum+=dt
        if footAccum>.52 and ctx.Base.weatherMode=="SNOW" then
            footAccum=0
            local char=ctx.Players.LocalPlayer.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            local sid=ctx.Options.SnowSoundId
            if root and hum and hum.MoveDirection.Magnitude>.15 and sid then
                for _,c in ipairs(pool) do
                    if c.used and c.mass>.14 and math.abs(root.Position.Y-c.pos.Y)<7
                        and (Vector3.new(root.Position.X,0,root.Position.Z)
                            - Vector3.new(c.pos.X,0,c.pos.Z)).Magnitude<2.2 then
                        snowSound.SoundId="rbxassetid://"..sid
                        snowSound.PlaybackSpeed=rand(.94,1.06)
                        snowSound.Volume=math.clamp(c.mass*.3,.06,.20)
                        pcall(function() snowSound:Play() end)
                        break
                    end
                end
            end
        end
        if probeAccum>.16 then
            probeAccum-=.16
            if ctx.Base.weatherMode~="OFF" then collect() end
        end
        -- Stored mass remains after switching weather. Rain melts snow.
        local warm=(ctx.Base.weatherMode=="RAIN") and .063 or .004
        local hour=L.ClockTime
        if hour>9 and hour<17 then warm+=.003 end
        for _,c in ipairs(pool) do
            if c.used then
                if c.mass>0 then
                    local melt=math.min(c.mass,warm*dt)
                    c.mass-=melt;c.water=math.min(1,c.water+melt*.75)
                end
                if c.water>0 then
                    local drain=math.clamp(.012+(.95-c.normal.Y)*.06,.012,.1)
                    c.water=math.max(0,c.water-drain*dt)
                end
                if t-c.last>90 and c.mass<.02 and c.water<.02 then
                    c.used=false;cells[c.key]=nil
                    c.snow.Transparency=1;c.wet.Transparency=1
                end
            end
        end
        if renderAccum>.1 then
            renderAccum=0
            local count=0
            for _,c in ipairs(pool) do
                if c.used then draw(c);count+=1 end
            end
            ctx.Stats.SurfacePatches=count
        end
    end)
    return {Name="Roof accumulation"}
end