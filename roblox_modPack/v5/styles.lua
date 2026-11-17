-- roblox_modPack / styles.lua
-- Reversible engine-supported colour profiles; no copyrighted pictures/shaders.
return function(ctx)
    local L,W=ctx.Lighting,ctx.Workspace
    local presets={
        {Name="Realism",tint=Color3.fromRGB(255,252,248),b=.003,c=.027,s=-.025,bloom=.025,rays=.045},
        {Name="Anime",tint=Color3.fromRGB(255,245,244),b=.028,c=.105,s=.22,bloom=.09,rays=.055},
        {Name="Hello Kitty",tint=Color3.fromRGB(255,225,240),b=.052,c=.015,s=.14,bloom=.13,rays=.05},
        {Name="Star Wars",tint=Color3.fromRGB(230,237,255),b=-.045,c=.12,s=-.055,bloom=.07,rays=.01},
        {Name="WW2",tint=Color3.fromRGB(223,211,182),b=-.025,c=.095,s=-.28,bloom=.018,rays=.025},
        {Name="Russia",tint=Color3.fromRGB(224,236,250),b=-.014,c=.057,s=-.15,bloom=.032,rays=.024},
        {Name="Walter White",tint=Color3.fromRGB(243,232,190),b=.006,c=.115,s=.10,bloom=.016,rays=.09},
        {Name="Galaxy",tint=Color3.fromRGB(187,203,255),b=-.083,c=.155,s=.20,bloom=.09,rays=0},
        {Name="CS2",tint=Color3.fromRGB(255,250,232),b=.028,c=.082,s=.038,bloom=.025,rays=.02},
        {Name="Sophy Rain",tint=Color3.fromRGB(206,222,239),b=-.024,c=.04,s=-.13,bloom=.032,rays=.008},
        {Name="Kung Fu Panda",tint=Color3.fromRGB(252,242,209),b=.025,c=.068,s=.19,bloom=.062,rays=.07},
        {Name="Stalin",tint=Color3.fromRGB(229,216,201),b=-.032,c=.118,s=-.31,bloom=.018,rays=.017},
        {Name="Gewitter",tint=Color3.fromRGB(218,231,246),b=-.043,c=.096,s=-.12,bloom=.014,rays=.005},
        {Name="Bright",tint=Color3.fromRGB(255,255,250),b=.082,c=-.005,s=.04,bloom=.10,rays=.075},
    }
    local current=1
    local profile=presets[1]
    local grade=Instance.new("ColorCorrectionEffect")
    grade.Name="RM5_StyleGrade";grade.Enabled=true
    grade.TintColor=Color3.new(1,1,1);grade.Brightness=0
    grade.Contrast=0;grade.Saturation=0
    grade.Parent=L;ctx.Track(grade)
    local bloom=Instance.new("BloomEffect")
    bloom.Name="RM5_StyleBloom";bloom.Intensity=0
    bloom.Size=14;bloom.Threshold=1.95
    bloom.Parent=L;ctx.Track(bloom)
    local sun=Instance.new("SunRaysEffect")
    sun.Name="RM5_StyleSun";sun.Intensity=0;sun.Spread=.67
    sun.Parent=L;ctx.Track(sun)
    local stars={}
    local rng=Random.new(11431)
    local function addStar(i)
        local p=Instance.new("Part")
        p.Name="RM5_GalaxyStar"
        p.Shape=Enum.PartType.Ball
        p.Size=Vector3.new(.12,.12,.12)
        p.Color=i%7==0 and Color3.fromRGB(173,192,255) or Color3.fromRGB(240,248,255)
        p.Material=Enum.Material.Neon
        p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false
        p.Transparency=1;p.CastShadow=false
        p.Parent=ctx.Folder;ctx.Track(p)
        local elev=rng:NextNumber(.06,.92)
        local az=rng:NextNumber(-math.pi,math.pi)
        local rad=rng:NextNumber(175,255)
        stars[i]={p=p,offset=Vector3.new(math.cos(az)*math.cos(elev),math.sin(elev),
            math.sin(az)*math.cos(elev))*rad,phase=rng:NextNumber(0,10)}
    end
    for i=1,82 do addStar(i) end
    local galaxyTick=0
    local function applyPreset(index)
        current=math.clamp(index,1,#presets)
        profile=presets[current]
        ctx.Options.Style=profile.Name
        -- Storm visual theme selects storm weather but does not alter server state.
        ctx.Options.Storm=profile.Name=="Gewitter"
        if profile.Name=="Gewitter" or profile.Name=="Sophy Rain" then
            pcall(function()ctx.Base.SetWeatherMode("RAIN")end)
        end
        ctx.Stats.VisualProfile=profile.Name
        return profile.Name
    end
    local api={}
    function api.List()
        local out={}
        for _,p in ipairs(presets) do out[#out+1]=p.Name end
        return out
    end
    function api.Set(name)
        for i,p in ipairs(presets) do
            if p.Name==name then return applyPreset(i) end
        end
        return nil
    end
    function api.Next()
        return applyPreset((current%#presets)+1)
    end
    function api.Current()return profile.Name end
    ctx.Styles=api
    local function interp(a,b,dt)
        return a+(b-a)*math.clamp(dt*2.1,0,1)
    end
    ctx.AddRender(function(dt)
        local enabled=ctx.Base.enabled and ctx.Options.StyleEnabled~=false
        grade.Enabled=enabled;bloom.Enabled=enabled;sun.Enabled=enabled
        local cam=W.CurrentCamera
        if not enabled then
            for _,star in ipairs(stars) do star.p.Transparency=1 end
            return
        end
        grade.TintColor=grade.TintColor:Lerp(profile.tint,math.clamp(dt*2.2,0,1))
        grade.Brightness=interp(grade.Brightness,profile.b,dt)
        grade.Contrast=interp(grade.Contrast,profile.c,dt)
        grade.Saturation=interp(grade.Saturation,profile.s,dt)
        local day=math.clamp(math.sin((L.ClockTime-6)*math.pi/12),0,1)
        bloom.Intensity=interp(bloom.Intensity,profile.bloom,dt)
        sun.Intensity=interp(sun.Intensity,profile.rays*day,dt)
        galaxyTick+=dt
        if galaxyTick>.13 then
            galaxyTick=0
            local visible=profile.Name=="Galaxy" and cam~=nil
            for _,star in ipairs(stars) do
                star.p.Transparency=visible and .28+.22*math.abs(math.sin(os.clock()*1.8+star.phase)) or 1
                if visible then star.p.CFrame=CFrame.new(cam.CFrame.Position+star.offset) end
            end
        end
    end)
    return {Name="Graphics styles",Stop=function()
        for _,star in ipairs(stars) do star.p.Transparency=1 end
    end}
end