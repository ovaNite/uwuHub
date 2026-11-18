-- NovaX v1 extra tabs: Weather + Compatibility.
-- Uses the complete original NovaPremiumUI rather than a second window.
return function(env)
  local ui=env.NX_UI_WINDOW
  local weather=env.NovaXWeather
  local audit=env.NovaXAudit
  local state=type(env.NX_STATE)=="table" and env.NX_STATE or {}
  local controls={}
  local function record(key,control) controls[key]=control;return control end
  if type(ui)~="table" or type(ui.CreateTab)~="function" then
    warn("[NovaX] Original premium GUI not ready for extension")
    return false
  end
  local function selected(v)
    return type(v)=="table" and tostring(v[1]) or tostring(v)
  end
  local tab=ui:CreateTab("Weather",4483345998)
  tab:CreateSection("Weather Mode")
  tab:CreateButton({Name="RAIN / Regen",Callback=function()
    state.NovaXWeatherMode="RAIN"
    if weather then weather.SetWeather("RAIN")end
  end})
  tab:CreateButton({Name="SNOW / Schnee",Callback=function()
    state.NovaXWeatherMode="SNOW"
    if weather then weather.SetWeather("SNOW")end
  end})
  tab:CreateButton({Name="CLEAR / Aus",Callback=function()
    state.NovaXWeatherMode="OFF"
    if weather then weather.SetWeather("OFF")end
  end})
  record("NovaXWeatherRain",tab:CreateSlider({Name="Rain Intensity",Range={1,100},Increment=1,
    CurrentValue=state.NovaXWeatherRain or 55,Callback=function(value)
      state.NovaXWeatherRain=math.clamp(tonumber(value) or 55,1,100)
      if weather then weather.SetStrength("RAIN",state.NovaXWeatherRain)end
    end}))
  record("NovaXWeatherSnow",tab:CreateSlider({Name="Snow Intensity",Range={1,100},Increment=1,
    CurrentValue=state.NovaXWeatherSnow or 65,Callback=function(value)
      state.NovaXWeatherSnow=math.clamp(tonumber(value) or 65,1,100)
      if weather then weather.SetStrength("SNOW",state.NovaXWeatherSnow)end
    end}))
  tab:CreateSection("Simulation / Performance")
  record("NovaXWeatherQuality",tab:CreateDropdown({Name="Snow Quality",Options={"ECO","BALANCED","ULTRA"},
    CurrentOption={state.NovaXWeatherQuality or "BALANCED"},Callback=function(value)
      local v=selected(value)
      state.NovaXWeatherQuality=v
      if weather then weather.SetQuality(v=="ULTRA" and 3 or v=="ECO" and 1 or 2) end
    end}))
  record("NovaXWeatherAdaptive",tab:CreateToggle({Name="Adaptive Performance",CurrentValue=state.NovaXWeatherAdaptive==true,
    Callback=function(value)
      state.NovaXWeatherAdaptive=value==true
      if weather then weather.Options.AutoPerformance=state.NovaXWeatherAdaptive end
    end}))
  record("NovaXWeatherSnowFX",tab:CreateToggle({Name="Snow Wind & Impacts",CurrentValue=state.NovaXWeatherSnowFX==true,
    Callback=function(value)
      state.NovaXWeatherSnowFX=value==true
      if weather then weather.Options.SnowParticles=state.NovaXWeatherSnowFX end
    end}))
  record("NovaXWeatherRainFX",tab:CreateToggle({Name="Rain Splash / Mist",CurrentValue=state.NovaXWeatherRainFX==true,
    Callback=function(value)
      state.NovaXWeatherRainFX=value==true
      if weather then weather.Options.RainParticles=state.NovaXWeatherRainFX end
    end}))
  record("NovaXWeatherWetFloor",tab:CreateToggle({Name="Wet Floor Materials",CurrentValue=state.NovaXWeatherWetFloor==true,
    Callback=function(value)
      state.NovaXWeatherWetFloor=value==true
      if weather then weather.Options.WorldFinish=state.NovaXWeatherWetFloor end
    end}))
  record("NovaXWeatherCameraWet",tab:CreateToggle({Name="Camera Lens Rain",CurrentValue=state.NovaXWeatherCameraWet==true,
    Callback=function(value)
      state.NovaXWeatherCameraWet=value==true
      if weather then weather.Options.CameraWet=state.NovaXWeatherCameraWet end
    end}))
  record("NovaXWeatherSound",tab:CreateToggle({Name="Weather Sounds",CurrentValue=state.NovaXWeatherSound==true,
    Callback=function(value)
      state.NovaXWeatherSound=value==true
      if weather then weather.Options.Sound=state.NovaXWeatherSound end
    end}))
  record("NovaXWeatherStorm",tab:CreateToggle({Name="Thunderstorm",CurrentValue=state.NovaXWeatherStorm==false,
    Callback=function(value)
      state.NovaXWeatherStorm=value==true
      if weather then weather.Options.Storm=state.NovaXWeatherStorm end
    end}))
  local status=tab:CreateParagraph({
    Title="Live Weather Telemetry",
    Content="Physics measurements will appear here."
  })
  tab:CreateButton({Name="Print Weather Report",Callback=function()
    if weather then weather.Report()end
  end})
  local diag=ui:CreateTab("Compatibility",4483345998)
  diag:CreateSection("NovaX / Client Check")
  diag:CreateLabel("Klaus (Dev)")
  diag:CreateLabel("Nexus (Bug Fixer)")
  if audit then
    diag:CreateParagraph({Title="Runtime capabilities",Content=audit.Summary()})
    local list={
      {"Hook metamethod","hookmetamethod"},
      {"New C closure","newcclosure"},
      {"Namecall method","getnamecallmethod"},
      {"Mouse movement","mousemoverel"},
      {"Drawing overlay","Drawing"},
      {"FPS cap control","setfpscap"},
      {"File configs","readfile"}
    }
    for _,item in ipairs(list) do
      diag:CreateLabel(item[1]..": "..(audit.Available[item[2]] and "available" or "unavailable"))
    end
    diag:CreateParagraph({Title="Not runtime-verified",
      Content="Server-side hits, game-specific weapons, anti-cheat and protected engine capabilities need live testing."})
  end
  diag:CreateButton({Name="Print Diagnostics",Callback=function()
    if audit then print("[NovaX] "..audit.Summary())end
    if weather then weather.Report()end
    local state=env.NX_STATE
    if state then
      print("[NovaX] SilentAim="..tostring(state.SilentAim)
        ..", mode="..tostring(state.SilentAimMode))
    end
  end})
  local accum=0
  if weather then
    weather.Link(game:GetService("RunService").Heartbeat,function(dt)
      accum+=dt
      if accum<1 then return end
      accum=0
      local x=weather.Stats
      if status and status.Set then
        status:Set(string.format(
          "FPS %.0f | Solver %.1f/90 Hz | Snow %d | Far %d | Rain hits %d | Errors %d",
          weather.FramesPerSec or 0,weather.PhysicsActual or 0,
          x.SnowImpacts or 0,x.SnowFarLandings or 0,
          x.Rain3DImpactHits or 0,
          #weather.Errors+(x.StepErrors or 0)+(x.RenderErrors or 0)))
      end
    end)
  end
  local function applyState()
    if not weather then return end
    weather.SetStrength("RAIN",state.NovaXWeatherRain or 55)
    weather.SetStrength("SNOW",state.NovaXWeatherSnow or 65)
    local quality=state.NovaXWeatherQuality or "BALANCED"
    weather.SetQuality(quality=="ULTRA" and 3 or quality=="ECO" and 1 or 2)
    for _,pair in ipairs({
      {"AutoPerformance","NovaXWeatherAdaptive"},{"SnowParticles","NovaXWeatherSnowFX"},
      {"RainParticles","NovaXWeatherRainFX"},{"WorldFinish","NovaXWeatherWetFloor"},
      {"CameraWet","NovaXWeatherCameraWet"},{"Sound","NovaXWeatherSound"},
      {"Storm","NovaXWeatherStorm"},
    }) do weather.Options[pair[1]]=state[pair[2]]==true end
    local mode=tostring(state.NovaXWeatherMode or "OFF")
    if mode~="RAIN" and mode~="SNOW" then mode="OFF" end
    weather.SetWeather(mode)
    for key,control in pairs(controls) do
      local value=state[key]
      if control and control.Set and value~=nil then
        pcall(function()control:Set(value)end)
      end
    end
  end
  env.NovaXWeatherControls={ApplyState=applyState}
  applyState()
  return env.NovaXWeatherControls
end