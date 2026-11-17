-- NovaX v1 Weather Engine | Klaus (Dev) · Nexus (Bug Fixer)
-- Integrates the version-pinned modPack v9 physics without loading its old GUI.
return function(env)
  local Players=game:GetService("Players")
  local RunService=game:GetService("RunService")
  local Workspace=game:GetService("Workspace")
  local V9="11394e8f05814c2fc0210e1fd187a0aa88aada85"
  local V6="fb50663a8221e04ebc3abc6d8cb6f410a9adba76"
  local V5="82dae812868850132778582ef1902ae51394faa8"
  local ROOT="https://raw.githubusercontent.com/ovaNite/uwuHub/"
  local context={Active=true,Errors={},Stats={},PhysicsHz=90,PhysicsActual=0,FramesPerSec=0,
    Options={WorldFinish=true,WeaponFinish=true,CameraWet=true,
      Sound=true,Fire=true,Foliage=false,Scope=true,Optics=true,
      RainParticles=true,SnowParticles=true,
      RainVolume=.45,RainStrength=55,SnowStrength=65,StylePercent=68,
      StyleEnabled=true,Style="Realism",Storm=false,
      AutoPerformance=true,DesiredQuality=2,RunningQuality=2
    },
    Workspace=Workspace,Players=Players,Lighting=game:GetService("Lighting"),
    RunService=RunService,UserInputService=game:GetService("UserInputService")
  }
  local tracked,links,physics,render,stops={},{},{},{},{}
  function context.Track(v)tracked[#tracked+1]=v;return v end
  function context.Link(signal,cb)
    local conn=signal:Connect(cb)
    links[#links+1]=conn
    return conn
  end
  function context.AddStep(cb)physics[#physics+1]=cb end
  function context.AddRender(cb)render[#render+1]=cb end
  function context.AddStop(cb)stops[#stops+1]=cb end
  local folder=Instance.new("Folder")
  folder.Name="NovaX_Weather_LocalVisuals"
  folder.Parent=Workspace
  context.Folder=context.Track(folder)
  local function fetch(path,rev)
    local uri=ROOT..rev.."/roblox_modPack/"..path
    local ok,data=pcall(function()return game:HttpGet(uri,true)end)
    if not ok or type(data)~="string" or #data<100 then
      error("Cannot retrieve "..path.." : "..tostring(data))
    end
    local compiled,err=loadstring(data)
    if not compiled then error("Compile failed "..path.." : "..tostring(err)) end
    return compiled
  end
  local okCore,errCore=pcall(function()fetch("v9/core.lua",V9)()end)
  if not okCore then
    context.Folder:Destroy()
    error("Weather base unavailable: "..tostring(errCore))
  end
  local globals=(getgenv and getgenv()) or _G
  local base=globals.roblox_modPack_Realism_v4
  if type(base)~="table" or type(base.Stop)~="function" then
    context.Folder:Destroy()
    error("Weather core was not registered")
  end
  context.Base=base
  function context.Stop()
    if not context.Active then return end
    context.Active=false
    for i=#links,1,-1 do pcall(function()links[i]:Disconnect()end)end
    for i=#stops,1,-1 do pcall(stops[i])end
    for i=#tracked,1,-1 do pcall(function()tracked[i]:Destroy()end)end
    pcall(base.Stop)
    if globals.NovaXWeather==context then globals.NovaXWeather=nil end
  end
  local modules={}
  local function addon(path,rev)
    local ok,err=pcall(function()
      local factory=fetch(path,rev)()
      if type(factory)~="function" then error("Not a module factory: "..path)end
      local instance=factory(context)
      if type(instance)=="table" and type(instance.Stop)=="function" then
        context.AddStop(instance.Stop)
      end
      modules[#modules+1]=path
    end)
    if not ok then
      context.Errors[#context.Errors+1]=path.." : "..tostring(err)
      warn("[NovaX Weather] "..context.Errors[#context.Errors])
    end
  end
  -- No duplicate snow emitter, no old circular surface module, no v9 UI.
  for _,item in ipairs({
    {"v5/dist/body.lua",V5},
    {"v5/dist/lens.lua",V5},
    {"v5/dist/worldfx.lua",V5},
    {"v5/dist/optics.lua",V5},
    {"v5/dist/styles.lua",V5},
    {"v6/weapon.lua",V6},
    {"v9/surfaces.lua",V9},
    {"v9/snow.lua",V9},
    {"v9/rain.lua",V9}
  }) do addon(item[1],item[2])end
  function context.SetWeather(mode)
    mode=tostring(mode):upper()
    if mode~="RAIN" and mode~="SNOW" and mode~="OFF" then return false end
    context.Base.SetWeatherMode(mode)
    if mode=="RAIN" then
      context.Base.SetWeatherIntensityFraction(context.Options.RainStrength/100)
    elseif mode=="SNOW" then
      context.Base.SetWeatherIntensityFraction(context.Options.SnowStrength/100)
    end
    return true
  end
  function context.SetStrength(mode,n)
    mode=tostring(mode):upper()
    local value=math.clamp(math.floor((tonumber(n)or 50)+.5),1,100)
    if mode=="RAIN" then context.Options.RainStrength=value
    elseif mode=="SNOW" then context.Options.SnowStrength=value
    else return false end
    if context.Base.weatherMode==mode then
      context.Base.SetWeatherIntensityFraction(value/100)
    end
    return true
  end
  function context.SetQuality(level)
    local q=math.clamp(math.floor(tonumber(level)or 2),1,3)
    context.Options.DesiredQuality=q
    if not context.Options.AutoPerformance and context.Snow then
      context.Snow.SetQuality(q)
    end
  end
  -- Start OFF; user must choose weather from the NovaX tab.
  pcall(function()base.SetWeatherMode("OFF")end)
  local fixed=1/90
  local accumulator,stepCount,windowStart,fpsFrames,slowSecs=0,0,os.clock(),0,0
  context.Link(RunService.Heartbeat,function(dt)
    if not context.Active then return end
    local frame=math.clamp(dt,0,.09)
    accumulator+=frame
    local count=math.min(5,math.floor((accumulator+1e-8)/fixed))
    accumulator-=count*fixed
    if accumulator>=fixed then
      local missed=math.floor(accumulator/fixed)*fixed
      accumulator-=missed
      context.Stats.SkippedPhysicsSeconds=(context.Stats.SkippedPhysicsSeconds or 0)+missed
    end
    for i=1,count do
      for _,fn in ipairs(physics) do
        local ok,err=pcall(fn,fixed,i==count)
        if not ok then
          context.Stats.StepErrors=(context.Stats.StepErrors or 0)+1
          if context.Stats.StepErrors<=4 then warn("[NovaX] Weather step: "..tostring(err))end
        end
      end
    end
    for _,fn in ipairs(render) do
      local ok,err=pcall(fn,dt)
      if not ok then
        context.Stats.RenderErrors=(context.Stats.RenderErrors or 0)+1
        if context.Stats.RenderErrors<=4 then warn("[NovaX] Weather render: "..tostring(err))end
      end
    end
    stepCount+=count;fpsFrames+=1
    local elapsed=os.clock()-windowStart
    if elapsed>=1 then
      context.PhysicsActual=stepCount/elapsed
      context.FramesPerSec=fpsFrames/elapsed
      stepCount=0;fpsFrames=0;windowStart=os.clock()
      local desired=context.Options.DesiredQuality
      if context.Options.AutoPerformance then
        if context.FramesPerSec<52 then desired=1
        elseif context.FramesPerSec<78 then desired=math.min(desired,2)end
      end
      if context.Snow and desired~=context.Options.RunningQuality then
        context.Snow.SetQuality(desired)
      end
      context.Options.RunningQuality=desired
    end
  end)
  globals.NovaXWeather=context
  function context.Report()
    local r=context.Stats
    print(string.format(
      "[NovaX] Weather modules %d/9 | %.1f FPS | solver %.1f/90 Hz | snow %d (distant %d) | rain hits %d | errors %d",
      #modules,context.FramesPerSec,context.PhysicsActual,
      r.SnowImpacts or 0,r.SnowFarLandings or 0,
      r.Rain3DImpactHits or 0,#context.Errors+(r.StepErrors or 0)+(r.RenderErrors or 0)))
    for _,err in ipairs(context.Errors) do warn(err)end
  end
  context.Report()
  return context
end