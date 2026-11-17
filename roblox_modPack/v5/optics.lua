-- roblox_modPack v5 / optics.lua
-- Engine-supported photographic effects per weather; no external GPU shaders.
return function(ctx)
    local L=ctx.Lighting
    local grade=Instance.new("ColorCorrectionEffect")
    grade.Name="RM5_WeatherGrade"
    grade.Brightness=0;grade.Contrast=0;grade.Saturation=0
    grade.TintColor=Color3.new(1,1,1)
    grade.Parent=L;ctx.Track(grade)
    local bloom=Instance.new("BloomEffect")
    bloom.Name="RM5_HighlightBloom"
    bloom.Intensity=0;bloom.Threshold=1.9;bloom.Size=12
    bloom.Parent=L;ctx.Track(bloom)
    local rays=Instance.new("SunRaysEffect")
    rays.Name="RM5_NaturalSunRays"
    rays.Intensity=0;rays.Spread=.65
    rays.Parent=L;ctx.Track(rays)
    local accum=0
    local tint=Color3.new(1,1,1)
    local function interp(current,target,dt)
        return current+(target-current)*math.clamp(dt*1.7,0,1)
    end
    ctx.AddRender(function(dt)
        accum+=dt
        if accum<.10 then return end
        dt=accum;accum=0
        local enabled=ctx.Base.enabled and ctx.Options.Optics
        grade.Enabled=enabled;bloom.Enabled=enabled;rays.Enabled=enabled
        if not enabled then return end
        local mode=ctx.Base.weatherMode
        local clock=L.ClockTime
        local daylight=math.clamp(math.sin((clock-6)*math.pi/12),0,1)
        local dawn=math.clamp(1-math.abs(clock-7)/2,0,1)
        local dusk=math.clamp(1-math.abs(clock-18)/2,0,1)
        local warm=math.max(dawn,dusk)
        local target,brightness,contrast,saturation,bloomLevel,sunLevel
        if mode=="RAIN" then
            target=Color3.fromRGB(241,245,248)
            brightness=-.012;contrast=.027;saturation=-.045
            bloomLevel=.022;sunLevel=.007
        elseif mode=="SNOW" then
            target=Color3.fromRGB(251,253,255)
            brightness=.006;contrast=.018;saturation=-.022
            bloomLevel=.035;sunLevel=.016*daylight
        else
            target=Color3.fromRGB(255,252,245):Lerp(Color3.fromRGB(255,240,223),warm*.42)
            brightness=.002;contrast=.018;saturation=-.012
            bloomLevel=.052*daylight;sunLevel=.055*daylight
        end
        tint=tint:Lerp(target,math.clamp(dt*1.9,0,1))
        grade.TintColor=tint
        grade.Brightness=interp(grade.Brightness,brightness,dt)
        grade.Contrast=interp(grade.Contrast,contrast,dt)
        grade.Saturation=interp(grade.Saturation,saturation,dt)
        bloom.Intensity=interp(bloom.Intensity,bloomLevel,dt)
        rays.Intensity=interp(rays.Intensity,sunLevel,dt)
        ctx.Stats.OpticalMode=mode
    end)
    return {Name="Dynamic optical weather"}
end