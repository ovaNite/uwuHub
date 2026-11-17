-- roblox_modPack v9 / rain.lua
-- Verified core-collision rain impacts. No circular floor plates, no
-- swimming-pool texture overlay: ballistic narrow splash strands + mist.
return function(ctx)
    local W=ctx.Workspace
    local Lighting=ctx.Lighting
    local RNG=Random.new(90511)
    local function rnd(a,b)return RNG:NextNumber(a,b) end
    local splashParts={}
    local MAX=96
    local impactNodes={}
    local activeCount=0
    local hits=0
    local lastImpactSound=0
    local lastRainMode="OFF"
    local function makePart(name,size)
        local p=Instance.new("Part")
        p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false
        p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.Glass
        p.Color=Color3.fromRGB(197,216,231)
        p.Transparency=1;p.Size=size
        p.CFrame=CFrame.new(0,-10000,0)
        p.Parent=ctx.Folder;ctx.Track(p)
        return p
    end
    for i=1,MAX do
        splashParts[i]={p=makePart("RainSplashThread",Vector3.new(.010,.07,.010)),
            life=0,ttl=.3,pos=Vector3.zero,velocity=Vector3.zero,opacity=.42}
    end
    local function makeMist()
        local p=makePart("SplashMistOrigin",Vector3.new(.12,.08,.12))
        local emitter=Instance.new("ParticleEmitter")
        emitter.Name="WaterMist"
        emitter.Enabled=false;emitter.Rate=0
        emitter.Texture="rbxasset://textures/particles/smoke_main.dds"
        emitter.Lifetime=NumberRange.new(.12,.29)
        emitter.Speed=NumberRange.new(.3,1.5)
        emitter.Drag=6
        emitter.SpreadAngle=Vector2.new(160,160)
        emitter.EmissionDirection=Enum.NormalId.Top
        emitter.VelocityInheritance=0
        emitter.LightEmission=.05
        emitter.LightInfluence=.8
        emitter.Color=ColorSequence.new(
            Color3.fromRGB(226,237,245),Color3.fromRGB(192,209,218))
        emitter.Size=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.03),
            NumberSequenceKeypoint.new(.35,.13),
            NumberSequenceKeypoint.new(1,.18)})
        emitter.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.48),
            NumberSequenceKeypoint.new(.45,.70),
            NumberSequenceKeypoint.new(1,1)})
        emitter.Parent=p
        return {part=p,emitter=emitter}
    end
    for i=1,16 do impactNodes[i]=makeMist() end
    local mistCursor=0
    local SoundService=game:GetService("SoundService")
    local function sound(id,vol,loop)
        local s=Instance.new("Sound")
        s.SoundId="rbxassetid://"..id;s.Volume=vol
        s.Looped=loop;s.Parent=SoundService;ctx.Track(s)
        return s
    end
    -- These assets may be unavailable depending on game-level audio permissions.
    local ambience=sound("1516791621",.22,true)
    local splashSound=sound("9126179648",.11,false)
    local thunderSound=sound("125355642447331",.3,false)
    local thunderFlash=Instance.new("ColorCorrectionEffect")
    thunderFlash.Name="RM9_Lightning";thunderFlash.Enabled=false
    thunderFlash.Brightness=0;thunderFlash.Contrast=.015
    thunderFlash.Parent=Lighting;ctx.Track(thunderFlash)
    local windClock=0
    local skyBoom=0
    local flashT=0
    local thunderDelay=-1
    ctx.Audio={}
    local music=sound("",.28,false)
    function ctx.Audio.PlayMusic(asset)
        local id=tostring(asset or ""):match("(%d+)")
        if not id then return false end
        music.SoundId="rbxassetid://"..id
        return pcall(function()music:Play()end)
    end
    function ctx.Audio.StopMusic() pcall(function()music:Stop()end)end
    function ctx.Audio.SetRainVolume(value)
        ctx.Options.RainVolume=math.clamp(tonumber(value) or .5,0,1)
    end
    function ctx.Audio.MusicVolume(value)
        music.Volume=math.clamp(tonumber(value) or .28,0,1)
    end
    local function tangentFrom(normal)
        local trial=Vector3.new(rnd(-1,1),0,rnd(-1,1))
        local proj=trial-normal*trial:Dot(normal)
        if proj.Magnitude<.001 then proj=normal:Cross(Vector3.xAxis) end
        return proj.Unit
    end
    local lastHit=0
    local function impact(position,normal,isSnow,amount,hitInstance)
        if isSnow or not ctx.Base.enabled or ctx.Options.RainParticles==false then
            return
        end
        if ctx.Base.weatherMode~="RAIN" then return end
        local camera=W.CurrentCamera
        if not camera or (camera.CFrame.Position-position).Magnitude>72 then
            return
        end
        if os.clock()-lastHit<.032 then return end
        lastHit=os.clock()
        hits+=1
        local strength=math.clamp(tonumber(ctx.Base.weatherIntensity) or .55,.01,1)
        local num=math.clamp(math.floor(2+strength*6+rnd(0,2)),2,11)
        for _=1,num do
            local d
            for _,p in ipairs(splashParts) do if p.life<=0 then d=p;break end end
            if not d then break end
            local surfaceTangent=tangentFrom(normal)
            d.pos=position+normal*.028
            d.velocity=normal*rnd(.85,3.5)+surfaceTangent*rnd(.55,3.8)
            d.life=rnd(.12,.32);d.ttl=d.life
            d.opacity=rnd(.38,.63)
            d.p.Transparency=d.opacity
            d.p.Size=Vector3.new(rnd(.008,.017),rnd(.035,.09),rnd(.008,.017))
        end
        mistCursor=mistCursor%#impactNodes+1
        local mist=impactNodes[mistCursor]
        mist.part.CFrame=CFrame.lookAt(position+normal*.02,position+normal)
        pcall(function()mist.emitter:Emit(math.clamp(num,3,11))end)
        local now=os.clock()
        if ctx.Options.Sound~=false and now-lastImpactSound>.22 then
            lastImpactSound=now
            splashSound.PlaybackSpeed=rnd(.88,1.13)
            splashSound.Volume=(ctx.Options.RainVolume or .5)*.22
            pcall(function()splashSound:Play()end)
        end
    end
    if type(ctx.Base.AddWeatherImpactListener)=="function" then
        ctx.AddStop(ctx.Base.AddWeatherImpactListener(impact))
    end
    ctx.OnBodyWaterHit=function(position,normal)
        impact(position,normal,false,.015)
    end
    local elapsed=0
    ctx.AddStep(function(dt,visual)
        local wet=ctx.Base.enabled and ctx.Base.weatherMode=="RAIN"
        elapsed+=dt
        activeCount=0
        for _,s in ipairs(splashParts) do
            if s.life>0 then
                s.life-=dt
                s.velocity+=Vector3.new(0,-W.Gravity*.38,0)*dt
                s.velocity*=1-math.min(.65,dt*.9)
                s.pos+=s.velocity*dt
                if s.life<=0 then
                    s.p.Transparency=1
                elseif visual then
                    local velocity=s.velocity
                    if velocity.Magnitude>.03 then
                        s.p.CFrame=CFrame.lookAt(s.pos,s.pos+velocity)
                            *CFrame.Angles(math.pi/2,0,0)
                    else
                        s.p.CFrame=CFrame.new(s.pos)
                    end
                    s.p.Transparency=math.clamp(s.opacity+
                        (1-s.life/s.ttl)*.52,0,1)
                    activeCount+=1
                end
            end
        end
        if wet and ctx.Options.Sound~=false then
            ambience.Volume=(ctx.Options.RainVolume or .5)*.46
            if not ambience.IsPlaying then pcall(function()ambience:Play()end)end
        elseif ambience.IsPlaying then pcall(function()ambience:Stop()end)end
        skyBoom+=dt
        if wet and ctx.Options.Storm then
            if skyBoom>rnd(14,28) then
                skyBoom=0;flashT=.24
                thunderFlash.Enabled=true
                thunderFlash.Brightness=.14
                thunderDelay=rnd(.6,2.4)
            end
        else
            skyBoom=0;thunderDelay=-1
            flashT=0;thunderFlash.Enabled=false
        end
        if flashT>0 then
            flashT-=dt
            thunderFlash.Brightness=.14*math.clamp(flashT/.24,0,1)
            if flashT<=0 then thunderFlash.Enabled=false end
        end
        if thunderDelay>0 then
            thunderDelay-=dt
            if thunderDelay<=0 and ctx.Options.Sound~=false then
                pcall(function()thunderSound:Play()end)
            end
        end
        ctx.Stats.Rain3DImpactHits=hits
        ctx.Stats.RainSplashStrands=activeCount
    end)
    ctx.AddStop(function()
        pcall(function()ambience:Stop()end)
        pcall(function()music:Stop()end)
        pcall(function()thunderSound:Stop()end)
    end)
    return {Name="90Hz rain impact threads and mist, no puddle discs"}
end