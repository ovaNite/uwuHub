-- NovaX: lokale Grafikoptionen. Klaus (Dev) / Nexus (Bug Fixer)
return function(env)
  local ui=env.NX_UI_WINDOW
  local state=type(env.NX_STATE)=="table" and env.NX_STATE or {}
  local controls={}
  local function record(key,control) controls[key]=control;return control end
  if type(ui)~="table" or type(ui.CreateTab)~="function" then error("GUI not available") end
  local Lighting=game:GetService("Lighting")
  local Workspace=game:GetService("Workspace")
  for _,name in ipairs({"NovaX_Color","NovaX_Bloom","NovaX_SunRays","NovaX_Depth"}) do
    local old=Lighting:FindFirstChild(name)
    if old then old:Destroy() end
  end
  local color=Instance.new("ColorCorrectionEffect")
  color.Name="NovaX_Color"
  color.Enabled=false
  color.Parent=Lighting
  local bloom=Instance.new("BloomEffect")
  bloom.Name="NovaX_Bloom"
  bloom.Enabled=false
  bloom.Intensity=.3
  bloom.Size=24
  bloom.Threshold=1.2
  bloom.Parent=Lighting
  local rays=Instance.new("SunRaysEffect")
  rays.Name="NovaX_SunRays";rays.Enabled=false;rays.Intensity=0.1;rays.Parent=Lighting
  local depth=Instance.new("DepthOfFieldEffect")
  depth.Name="NovaX_Depth";depth.Enabled=false;depth.FarIntensity=0.15;depth.NearIntensity=0;depth.FocusDistance=50;depth.InFocusRadius=30;depth.Parent=Lighting
  local overrides={}
  local function override(key,enabled,value)
    local entry=overrides[key]
    if enabled then
      if not entry then entry={old=Lighting[key]};overrides[key]=entry end
      Lighting[key]=value;entry.assigned=value
    elseif entry then
      if Lighting[key]==entry.assigned then Lighting[key]=entry.old end
      overrides[key]=nil
    end
  end
  local initialClock=Lighting.ClockTime
  local assignedClock=nil
  local lastCamera=nil
  local initialFov=nil
  local assignedFov=nil
  local opts={enabled=false,bloom=false,saturation=0,contrast=0,clock=14,fov=70,clockEnabled=false,fovEnabled=false,
    rays=false,depth=false,brightnessEnabled=false,brightness=2,exposure=0,fogEnabled=false,fogEnd=1000,
    ambientEnabled=false,ambient=128,shadowsEnabled=false,shadows=true,tint="Neutral",performance=false}
  local function readState()
    opts.enabled=state.NovaXWorldEnabled==true
    opts.saturation=math.clamp((tonumber(state.NovaXWorldSaturation) or 0)/100,-1,1)
    opts.contrast=math.clamp((tonumber(state.NovaXWorldContrast) or 0)/100,-1,1)
    opts.tint=tostring(state.NovaXWorldTint or "Neutral")
    opts.bloom=state.NovaXWorldBloom==true
    bloom.Intensity=math.clamp((tonumber(state.NovaXWorldBloomIntensity) or 30)/100,0,1)
    opts.rays=state.NovaXWorldRays==true
    rays.Intensity=math.clamp((tonumber(state.NovaXWorldRaysStrength) or 10)/100,0,1)
    opts.depth=state.NovaXWorldDepth==true
    depth.FocusDistance=math.clamp(tonumber(state.NovaXWorldDepthFocus) or 50,5,300)
    depth.FarIntensity=math.clamp((tonumber(state.NovaXWorldDepthBlur) or 15)/100,0,1)
    opts.performance=state.NovaXWorldPerformance==true
    opts.brightnessEnabled=state.NovaXWorldBrightnessEnabled==true
    opts.brightness=math.clamp(tonumber(state.NovaXWorldBrightness) or 2,0,10)
    opts.exposure=math.clamp(tonumber(state.NovaXWorldExposure) or 0,-3,3)
    opts.fogEnabled=state.NovaXWorldFogEnabled==true
    opts.fogEnd=math.clamp(tonumber(state.NovaXWorldFogEnd) or 1000,50,5000)
    opts.ambientEnabled=state.NovaXWorldAmbientEnabled==true
    opts.ambient=math.clamp(tonumber(state.NovaXWorldAmbient) or 128,0,255)
    opts.shadowsEnabled=state.NovaXWorldShadowsEnabled==true
    opts.shadows=state.NovaXWorldShadows~=false
    opts.clockEnabled=state.NovaXWorldClockEnabled==true
    opts.clock=math.clamp(tonumber(state.NovaXWorldClock) or 14,0,23.75)
    opts.fovEnabled=state.NovaXWorldFovEnabled==true
    opts.fov=math.clamp(tonumber(state.NovaXWorldFov) or 70,40,120)
  end
  local closing=false
  local function saveState()
    if closing then return end
    state.NovaXWorldEnabled=opts.enabled
    state.NovaXWorldSaturation=opts.saturation*100
    state.NovaXWorldContrast=opts.contrast*100
    state.NovaXWorldTint=opts.tint
    state.NovaXWorldBloom=opts.bloom
    state.NovaXWorldBloomIntensity=bloom.Intensity*100
    state.NovaXWorldRays=opts.rays
    state.NovaXWorldRaysStrength=rays.Intensity*100
    state.NovaXWorldDepth=opts.depth
    state.NovaXWorldDepthFocus=depth.FocusDistance
    state.NovaXWorldDepthBlur=depth.FarIntensity*100
    state.NovaXWorldPerformance=opts.performance
    state.NovaXWorldBrightnessEnabled=opts.brightnessEnabled
    state.NovaXWorldBrightness=opts.brightness
    state.NovaXWorldExposure=opts.exposure
    state.NovaXWorldFogEnabled=opts.fogEnabled
    state.NovaXWorldFogEnd=opts.fogEnd
    state.NovaXWorldAmbientEnabled=opts.ambientEnabled
    state.NovaXWorldAmbient=opts.ambient
    state.NovaXWorldShadowsEnabled=opts.shadowsEnabled
    state.NovaXWorldShadows=opts.shadows
    state.NovaXWorldClockEnabled=opts.clockEnabled
    state.NovaXWorldClock=opts.clock
    state.NovaXWorldFovEnabled=opts.fovEnabled
    state.NovaXWorldFov=opts.fov
  end
  readState()
  local tints={Neutral=Color3.fromRGB(255,255,255),Warm=Color3.fromRGB(255,225,195),
    Cool=Color3.fromRGB(200,225,255),Sunset=Color3.fromRGB(255,192,164),Mono=Color3.fromRGB(220,220,220)}
  local function camera()
    local c=Workspace.CurrentCamera
    if c~=lastCamera then
      if lastCamera and assignedFov and math.abs(lastCamera.FieldOfView-assignedFov)<.01 then
        lastCamera.FieldOfView=initialFov
      end
      lastCamera=c
      initialFov=c and c.FieldOfView or nil
      assignedFov=nil
    end
    return c
  end
  local function apply()
    saveState()
    color.Enabled=opts.enabled
    color.Saturation=opts.saturation
    color.Contrast=opts.contrast
    color.TintColor=tints[opts.tint] or tints.Neutral
    bloom.Enabled=opts.bloom and not opts.performance
    rays.Enabled=opts.rays and not opts.performance;depth.Enabled=opts.depth and not opts.performance
    override("Brightness",opts.brightnessEnabled,opts.brightness)
    override("ExposureCompensation",opts.brightnessEnabled,opts.exposure)
    override("FogStart",opts.fogEnabled,0)
    override("FogEnd",opts.fogEnabled,opts.fogEnd)
    local grey=Color3.fromRGB(opts.ambient,opts.ambient,opts.ambient)
    override("Ambient",opts.ambientEnabled,grey)
    override("OutdoorAmbient",opts.ambientEnabled,grey)
    override("GlobalShadows",opts.performance or opts.shadowsEnabled,not opts.performance and opts.shadows)
    if opts.clockEnabled then
      Lighting.ClockTime=opts.clock
      assignedClock=opts.clock
    elseif assignedClock~=nil then
      if math.abs(Lighting.ClockTime-assignedClock)<.01 then Lighting.ClockTime=initialClock end
      assignedClock=nil
    end
    local c=camera()
    if c and opts.fovEnabled then
      c.FieldOfView=opts.fov
      assignedFov=opts.fov
    elseif c and assignedFov~=nil then
      if math.abs(c.FieldOfView-assignedFov)<.01 then c.FieldOfView=initialFov end
      assignedFov=nil
    end
  end
  local tab=ui:CreateTab("World Visuals",4483345998)
  tab:CreateSection("Color and light")
  record("NovaXWorldEnabled",tab:CreateToggle({Name="Color grading",CurrentValue=state.NovaXWorldEnabled,Callback=function(v) opts.enabled=v;apply() end}))
  record("NovaXWorldSaturation",tab:CreateSlider({Name="Saturation",Range={-100,100},Increment=1,CurrentValue=state.NovaXWorldSaturation,Callback=function(v) opts.saturation=math.clamp((tonumber(v) or 0)/100,-1,1);apply() end}))
  record("NovaXWorldContrast",tab:CreateSlider({Name="Contrast",Range={-100,100},Increment=1,CurrentValue=state.NovaXWorldContrast,Callback=function(v) opts.contrast=math.clamp((tonumber(v) or 0)/100,-1,1);apply() end}))
  record("NovaXWorldTint",tab:CreateDropdown({Name="Color tint",Options={"Neutral","Warm","Cool","Sunset","Mono"},CurrentOption={state.NovaXWorldTint or "Neutral"},Callback=function(v) opts.tint=type(v)=="table" and v[1] or v;apply() end}))
  record("NovaXWorldBloom",tab:CreateToggle({Name="Bloom",CurrentValue=state.NovaXWorldBloom,Callback=function(v) opts.bloom=v;apply() end}))
  record("NovaXWorldBloomIntensity",tab:CreateSlider({Name="Bloom intensity",Range={0,100},Increment=1,CurrentValue=state.NovaXWorldBloomIntensity,Callback=function(v) bloom.Intensity=math.clamp((tonumber(v) or 0)/100,0,1);apply() end}))
  record("NovaXWorldRays",tab:CreateToggle({Name="Sun rays",CurrentValue=state.NovaXWorldRays,Callback=function(v) opts.rays=v;apply() end}))
  record("NovaXWorldRaysStrength",tab:CreateSlider({Name="Sun rays strength",Range={0,100},Increment=1,CurrentValue=state.NovaXWorldRaysStrength,Callback=function(v) rays.Intensity=math.clamp((tonumber(v) or 0)/100,0,1);apply() end}))
  record("NovaXWorldDepth",tab:CreateToggle({Name="Depth of field",CurrentValue=state.NovaXWorldDepth,Callback=function(v) opts.depth=v;apply() end}))
  record("NovaXWorldDepthFocus",tab:CreateSlider({Name="Depth focus distance",Range={5,300},Increment=5,CurrentValue=state.NovaXWorldDepthFocus,Callback=function(v) depth.FocusDistance=math.clamp(tonumber(v) or 50,5,300);apply() end}))
  record("NovaXWorldDepthBlur",tab:CreateSlider({Name="Depth blur strength",Range={0,100},Increment=1,CurrentValue=state.NovaXWorldDepthBlur,Callback=function(v) depth.FarIntensity=math.clamp((tonumber(v) or 0)/100,0,1);apply() end}))
  tab:CreateSection("Performance")
  record("NovaXWorldPerformance",tab:CreateToggle({Name="Performance mode (shadows and blur off)",CurrentValue=state.NovaXWorldPerformance,Callback=function(v) opts.performance=v;apply() end}))
  tab:CreateSection("World lighting")
  record("NovaXWorldBrightnessEnabled",tab:CreateToggle({Name="Custom brightness and exposure",CurrentValue=state.NovaXWorldBrightnessEnabled,Callback=function(v) opts.brightnessEnabled=v;apply() end}))
  record("NovaXWorldBrightness",tab:CreateSlider({Name="Brightness",Range={0,10},Increment=0.1,CurrentValue=state.NovaXWorldBrightness,Callback=function(v) opts.brightness=math.clamp(tonumber(v) or 2,0,10);apply() end}))
  record("NovaXWorldExposure",tab:CreateSlider({Name="Exposure",Range={-3,3},Increment=0.1,CurrentValue=state.NovaXWorldExposure,Callback=function(v) opts.exposure=math.clamp(tonumber(v) or 0,-3,3);apply() end}))
  record("NovaXWorldFogEnabled",tab:CreateToggle({Name="Custom fog distance",CurrentValue=state.NovaXWorldFogEnabled,Callback=function(v) opts.fogEnabled=v;apply() end}))
  record("NovaXWorldFogEnd",tab:CreateSlider({Name="Fog end distance",Range={50,5000},Increment=50,CurrentValue=state.NovaXWorldFogEnd,Callback=function(v) opts.fogEnd=math.clamp(tonumber(v) or 1000,50,5000);apply() end}))
  record("NovaXWorldAmbientEnabled",tab:CreateToggle({Name="Custom ambient light",CurrentValue=state.NovaXWorldAmbientEnabled,Callback=function(v) opts.ambientEnabled=v;apply() end}))
  record("NovaXWorldAmbient",tab:CreateSlider({Name="Ambient brightness",Range={0,255},Increment=1,CurrentValue=state.NovaXWorldAmbient,Callback=function(v) opts.ambient=math.floor(math.clamp(tonumber(v) or 128,0,255));apply() end}))
  record("NovaXWorldShadowsEnabled",tab:CreateToggle({Name="Override world shadows",CurrentValue=state.NovaXWorldShadowsEnabled,Callback=function(v) opts.shadowsEnabled=v;apply() end}))
  record("NovaXWorldShadows",tab:CreateToggle({Name="World shadows",CurrentValue=state.NovaXWorldShadows,Callback=function(v) opts.shadows=v;apply() end}))
  tab:CreateSection("Scene and camera")
  record("NovaXWorldClockEnabled",tab:CreateToggle({Name="Custom time",CurrentValue=state.NovaXWorldClockEnabled,Callback=function(v) opts.clockEnabled=v;apply() end}))
  record("NovaXWorldClock",tab:CreateSlider({Name="Time of day",Range={0,23.75},Increment=0.25,CurrentValue=state.NovaXWorldClock,Callback=function(v) opts.clock=math.clamp(tonumber(v) or 14,0,23.75);apply() end}))
  record("NovaXWorldFovEnabled",tab:CreateToggle({Name="Camera FOV override",CurrentValue=state.NovaXWorldFovEnabled,Callback=function(v) opts.fovEnabled=v;apply() end}))
  record("NovaXWorldFov",tab:CreateSlider({Name="Camera FOV",Range={40,120},Increment=1,CurrentValue=state.NovaXWorldFov,Callback=function(v) opts.fov=math.clamp(tonumber(v) or 70,40,120);apply() end}))
  local cameraConnection=Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(apply)
  local alive=true
  local function applyState()
    if not alive then return end
    readState()
    apply()
    for key,control in pairs(controls) do
      local value=state[key]
      if control and control.Set and value~=nil then pcall(function()control:Set(value)end) end
    end
  end
  applyState()
  return {ApplyState=applyState,Stop=function()
    if not alive then return end
    alive=false
    closing=true
    cameraConnection:Disconnect()
    opts.clockEnabled=false
    opts.fovEnabled=false
    opts.brightnessEnabled=false;opts.fogEnabled=false;opts.ambientEnabled=false;opts.shadowsEnabled=false;opts.performance=false
    apply()
    color:Destroy()
    bloom:Destroy();rays:Destroy();depth:Destroy()
  end}
end

