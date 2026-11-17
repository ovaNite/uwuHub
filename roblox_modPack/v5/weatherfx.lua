-- roblox_modPack / weatherfx.lua
-- Rounded ballistic splashes and local weather audio. Every hit is verified by
-- the core Raycast. Asset playback still depends on Roblox audio permissions.
return function(ctx)
    local W=ctx.Workspace
    local SoundService=game:GetService("SoundService")
    local rng=Random.new()
    local function rand(a,b) return rng:NextNumber(a,b) end
    local function makeSphere(name,material,color)
        local p=Instance.new("Part")
        p.Name=name;p.Shape=Enum.PartType.Ball
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
        p.CastShadow=false;p.Material=material;p.Color=color
        p.Transparency=1;p.Size=Vector3.new(.05,.05,.05)
        p.CFrame=CFrame.new(0,-10000,0)
        p.Parent=ctx.Folder;ctx.Track(p)
        return p
    end
    local fragmentPool={}
    for i=1,60 do
        fragmentPool[i]={
            p=makeSphere("RM5_SplashDroplet",Enum.Material.Glass,Color3.fromRGB(192,211,224)),
            ttl=0,pos=Vector3.zero,vel=Vector3.zero,
        }
    end
    local rings={}
    for i=1,22 do
        local p=makeSphere("RM5_RoundedRipple",Enum.Material.Glass,Color3.fromRGB(180,198,211))
        p.Reflectance=.04
        local mesh=Instance.new("SpecialMesh")
        mesh.MeshType=Enum.MeshType.Sphere;mesh.Scale=Vector3.one
        mesh.Parent=p
        rings[i]={p=p,mesh=mesh,ttl=0,life=1,pos=Vector3.zero,normal=Vector3.yAxis,radius=1}
    end
    local function sound(name,id,volume,loop)
        local s=Instance.new("Sound")
        s.Name=name;s.SoundId="rbxassetid://"..tostring(id)
        s.Volume=volume;s.Looped=loop
        s.Parent=SoundService;ctx.Track(s)
        return s
    end
    -- Public Creator Store asset IDs, not guaranteed playable in every experience.
    local rainSound=sound("RM5_RainSound",1516791621,.23,true)
    local impactSounds={
        sound("RM5_DropImpact1",9126179648,.13,false),
        sound("RM5_DropImpact2",9126179648,.12,false),
        sound("RM5_DropImpact3",9126179648,.11,false)
    }
    local thunder=sound("RM5_Thunder",125355642447331,.38,false)
    local music=Instance.new("Sound")
    music.Name="RM5_LocalMusic";music.Volume=.32;music.Looped=false
    music.Parent=SoundService;ctx.Track(music)
    ctx.Audio={}
    function ctx.Audio.PlayMusic(asset)
        local id=tostring(asset or ""):match("(%d+)")
        if not id then return false end
        music.SoundId="rbxassetid://"..id
        pcall(function() music:Play() end)
        return true
    end
    function ctx.Audio.StopMusic() pcall(function() music:Stop() end) end
    function ctx.Audio.MusicVolume(x) music.Volume=math.clamp(tonumber(x) or .32,0,1) end
    function ctx.Audio.SetRainVolume(x)
        ctx.Options.RainVolume=math.clamp(tonumber(x) or .5,0,1)
    end
    local stamp,impactCounter,thunderClock,lightningT=0,0,0,0
    local flash=Instance.new("ColorCorrectionEffect")
    flash.Name="RM5_LightningFlash";flash.Enabled=false
    flash.Brightness=0;flash.Contrast=.02
    flash.Parent=ctx.Lighting;ctx.Track(flash)
    local function hit(position,normal,isSnow,amount)
        if isSnow or not ctx.Base.enabled then return end
        if ctx.Base.weatherMode~="RAIN" then return end
        local camera=W.CurrentCamera
        if not camera or (camera.CFrame.Position-position).Magnitude>55 then return end
        local now=os.clock()
        if now-stamp<.045 then return end
        stamp=now
        impactCounter+=1
        local count=math.floor(rand(3,6))
        for _=1,count do
            local f
            for _,d in ipairs(fragmentPool) do if d.ttl<=0 then f=d;break end end
            if not f then break end
            local horizontal=Vector3.new(rand(-1,1),0,rand(-1,1))
            if horizontal.Magnitude<.05 then horizontal=Vector3.xAxis end
            local tangent=(horizontal-normal*horizontal:Dot(normal))
            if tangent.Magnitude<.02 then tangent=normal:Cross(Vector3.xAxis) end
            tangent=tangent.Unit
            f.pos=position+normal*.035
            f.vel=tangent*rand(1.0,4.2)+normal*rand(1.1,4.0)
            f.ttl=rand(.12,.32)
            local radius=rand(.028,.075)
            f.p.Size=Vector3.new(radius,radius,radius)
            f.p.Transparency=rand(.12,.38)
        end
        local ring
        for _,r in ipairs(rings) do if r.ttl<=0 then ring=r;break end end
        if ring then
            ring.pos=position;ring.normal=normal
            ring.ttl=rand(.12,.21);ring.life=ring.ttl
            ring.radius=rand(.18,.35)
            ring.p.Transparency=.50
        end
        if now-(ctx._LastImpactSound or 0)>.18 and rand(0,1)<.62
            and ctx.Options.Sound~=false then
            ctx._LastImpactSound=now
            local snd=impactSounds[(impactCounter%#impactSounds)+1]
            snd.PlaybackSpeed=rand(.9,1.15)
            snd.Volume=math.clamp((ctx.Options.RainVolume or .5)*.24,.03,.30)
            pcall(function() snd:Play() end)
        end
    end
    ctx.OnBodyWaterHit=function(position,normal)
        hit(position,normal,false,.015)
    end
    if type(ctx.Base.AddWeatherImpactListener)=="function" then
        local off=ctx.Base.AddWeatherImpactListener(hit)
        ctx.AddStop(off)
    end
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances={ctx.Folder}
    rayParams.IgnoreWater=false
    local thunderDelayed=-1
    ctx.AddStep(function(dt,draw)
        local mode=(ctx.Base.enabled and ctx.Base.weatherMode) or "OFF"
        local rainy=mode=="RAIN" and ctx.Options.Sound~=false
        if rainy then
            rainSound.Volume=math.clamp((ctx.Options.RainVolume or .5)*.58,.02,.7)
            if not rainSound.IsPlaying then pcall(function()rainSound:Play()end)end
        elseif rainSound.IsPlaying then
            pcall(function()rainSound:Stop()end)
        end
        -- Raycast sweep for dynamic splash droplets; stop on second impact.
        for _,f in ipairs(fragmentPool) do
            if f.ttl>0 then
                f.ttl-=dt
                local previous=f.pos
                f.vel+=Vector3.new(0,-W.Gravity,0)*dt
                f.vel*=1-math.min(.65,dt*.6)
                local nextPos=previous+f.vel*dt
                local impact=W:Raycast(previous,nextPos-previous,rayParams)
                if impact then f.ttl=0 else f.pos=nextPos end
                if f.ttl<=0 then f.p.Transparency=1
                elseif draw then
                    f.p.CFrame=CFrame.new(f.pos)
                    f.p.Transparency=math.clamp(f.p.Transparency+dt*.6,.12,.95)
                end
            end
        end
        for _,r in ipairs(rings) do
            if r.ttl>0 then
                r.ttl-=dt
                if r.ttl<=0 then r.p.Transparency=1
                elseif draw then
                    local u=1-r.ttl/r.life
                    local radius=r.radius+u*.33
                    local normal=r.normal
                    local x=(math.abs(normal.X)<.85 and Vector3.xAxis or Vector3.zAxis)
                    x=(x-normal*x:Dot(normal)).Unit
                    local z=x:Cross(normal)
                    r.p.CFrame=CFrame.fromMatrix(r.pos+normal*.023,x,normal,z)
                    r.mesh.Scale=Vector3.new(radius*2,.015*(1-u)+.002,radius*2)
                    r.p.Transparency=.53+.46*u
                end
            end
        end
        -- Actual lighting impulse, thunder follows a delayed lightning strike.
        local storm=ctx.Options.Storm and mode=="RAIN"
        if storm then
            thunderClock+=dt
            if thunderClock>=math.clamp(ctx.Options.ThunderEvery or 17,6,55) then
                thunderClock=0
                flash.Enabled=true;flash.Brightness=.19;lightningT=.22
                thunderDelayed=rand(.45,2.6)
                ctx.Stats.LightningCount=(ctx.Stats.LightningCount or 0)+1
            end
        else thunderClock=0;thunderDelayed=-1;lightningT=0;flash.Enabled=false end
        if lightningT>0 then
            lightningT-=dt
            flash.Brightness=.19*math.clamp(lightningT/.22,0,1)
            if lightningT<=0 then flash.Enabled=false end
        end
        if thunderDelayed>0 then
            thunderDelayed-=dt
            if thunderDelayed<=0 and ctx.Options.Sound~=false then
                thunder.PlaybackSpeed=rand(.90,1.12)
                pcall(function()thunder:Play()end)
            end
        end
        ctx.Stats.SplashImpacts=impactCounter
    end)
    ctx.AddStop(function()
        pcall(function()rainSound:Stop()end)
        pcall(function()thunder:Stop()end)
        pcall(function()music:Stop()end)
    end)
    return {Name="Rain splashes and audio"}
end