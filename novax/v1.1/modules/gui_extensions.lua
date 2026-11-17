-- NovaX v1 extra tabs: Weather + Compatibility.
-- Uses the complete original NovaPremiumUI rather than a second window.
return function(env)
  local ui=env.NX_UI_WINDOW
  local weather=env.NovaXWeather
  local audit=env.NovaXAudit
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
    if weather then weather.SetWeather("RAIN")end
  end})
  tab:CreateButton({Name="SNOW / Schnee",Callback=function()
    if weather then weather.SetWeather("SNOW")end
  end})
  tab:CreateButton({Name="CLEAR / Aus",Callback=function()
    if weather then weather.SetWeather("OFF")end
  end})
  tab:CreateSlider({Name="Rain Intensity",Range={1,100},Increment=1,
    CurrentValue=55,Callback=function(value)
      if weather then weather.SetStrength("RAIN",value)end
    end})
  tab:CreateSlider({Name="Snow Intensity",Range={1,100},Increment=1,
    CurrentValue=65,Callback=function(value)
      if weather then weather.SetStrength("SNOW",value)end
    end})
  tab:CreateSection("Simulation / Performance")
  tab:CreateDropdown({Name="Snow Quality",Options={"ECO","BALANCED","ULTRA"},
    CurrentOption={"BALANCED"},Callback=function(value)
      if not weather then return end
      local v=selected(value)
      weather.SetQuality(v=="ULTRA" and 3 or v=="ECO" and 1 or 2)
    end})
  tab:CreateToggle({Name="Adaptive Performance",CurrentValue=true,
    Callback=function(value)
      if weather then weather.Options.AutoPerformance=value end
    end})
  tab:CreateToggle({Name="Snow Wind & Impacts",CurrentValue=true,
    Callback=function(value)
      if weather then weather.Options.SnowParticles=value end
    end})
  tab:CreateToggle({Name="Rain Splash / Mist",CurrentValue=true,
    Callback=function(value)
      if weather then weather.Options.RainParticles=value end
    end})
  tab:CreateToggle({Name="Wet Floor Materials",CurrentValue=true,
    Callback=function(value)
      if weather then weather.Options.WorldFinish=value end
    end})
  tab:CreateToggle({Name="Camera Lens Rain",CurrentValue=true,
    Callback=function(value)
      if weather then weather.Options.CameraWet=value end
    end})
  tab:CreateToggle({Name="Weather Sounds",CurrentValue=true,
    Callback=function(value)
      if weather then weather.Options.Sound=value end
    end})
  tab:CreateToggle({Name="Thunderstorm",CurrentValue=false,
    Callback=function(value)
      if weather then weather.Options.Storm=value end
    end})
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
  return true
end