-- NovaX: lokale Grafikoptionen. Klaus (Dev) / Nexus (Bug Fixer)
return function(env)
  local ui=env.NX_UI_WINDOW
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
    ambientEnabled=false,ambient=128,shadowsEnabled=false,shadows=true,tint="Neutral"}
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
    color.Enabled=opts.enabled
    color.Saturation=opts.saturation
    color.Contrast=opts.contrast
    color.TintColor=tints[opts.tint] or tints.Neutral
    bloom.Enabled=opts.bloom
    rays.Enabled=opts.rays;depth.Enabled=opts.depth
    override("Brightness",opts.brightnessEnabled,opts.brightness)
    override("ExposureCompensation",opts.brightnessEnabled,opts.exposure)
    override("FogStart",opts.fogEnabled,0)
    override("FogEnd",opts.fogEnabled,opts.fogEnd)
    local grey=Color3.fromRGB(opts.ambient,opts.ambient,opts.ambient)
    override("Ambient",opts.ambientEnabled,grey)
    override("OutdoorAmbient",opts.ambientEnabled,grey)
    override("GlobalShadows",opts.shadowsEnabled,opts.shadows)
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
  tab:CreateToggle({Name="Color grading",CurrentValue=false,Callback=function(v) opts.enabled=v;apply() end})
  tab:CreateSlider({Name="Saturation",Range={-100,100},Increment=1,CurrentValue=0,Callback=function(v) opts.saturation=math.clamp((tonumber(v) or 0)/100,-1,1);apply() end})
  tab:CreateSlider({Name="Contrast",Range={-100,100},Increment=1,CurrentValue=0,Callback=function(v) opts.contrast=math.clamp((tonumber(v) or 0)/100,-1,1);apply() end})
  tab:CreateDropdown({Name="Color tint",Options={"Neutral","Warm","Cool","Sunset","Mono"},CurrentOption={"Neutral"},Callback=function(v) opts.tint=type(v)=="table" and v[1] or v;apply() end})
  tab:CreateToggle({Name="Bloom",CurrentValue=false,Callback=function(v) opts.bloom=v;apply() end})
  tab:CreateSlider({Name="Bloom intensity",Range={0,100},Increment=1,CurrentValue=30,Callback=function(v) bloom.Intensity=math.clamp((tonumber(v) or 0)/100,0,1) end})
  tab:CreateToggle({Name="Sun rays",CurrentValue=false,Callback=function(v) opts.rays=v;apply() end})
  tab:CreateSlider({Name="Sun rays strength",Range={0,100},Increment=1,CurrentValue=10,Callback=function(v) rays.Intensity=math.clamp((tonumber(v) or 0)/100,0,1) end})
  tab:CreateToggle({Name="Depth of field",CurrentValue=false,Callback=function(v) opts.depth=v;apply() end})
  tab:CreateSlider({Name="Depth focus distance",Range={5,300},Increment=5,CurrentValue=50,Callback=function(v) depth.FocusDistance=math.clamp(tonumber(v) or 50,5,300) end})
  tab:CreateSlider({Name="Depth blur strength",Range={0,100},Increment=1,CurrentValue=15,Callback=function(v) depth.FarIntensity=math.clamp((tonumber(v) or 0)/100,0,1) end})
  tab:CreateSection("World lighting")
  tab:CreateToggle({Name="Custom brightness and exposure",CurrentValue=false,Callback=function(v) opts.brightnessEnabled=v;apply() end})
  tab:CreateSlider({Name="Brightness",Range={0,10},Increment=0.1,CurrentValue=2,Callback=function(v) opts.brightness=math.clamp(tonumber(v) or 2,0,10);apply() end})
  tab:CreateSlider({Name="Exposure",Range={-3,3},Increment=0.1,CurrentValue=0,Callback=function(v) opts.exposure=math.clamp(tonumber(v) or 0,-3,3);apply() end})
  tab:CreateToggle({Name="Custom fog distance",CurrentValue=false,Callback=function(v) opts.fogEnabled=v;apply() end})
  tab:CreateSlider({Name="Fog end distance",Range={50,5000},Increment=50,CurrentValue=1000,Callback=function(v) opts.fogEnd=math.clamp(tonumber(v) or 1000,50,5000);apply() end})
  tab:CreateToggle({Name="Custom ambient light",CurrentValue=false,Callback=function(v) opts.ambientEnabled=v;apply() end})
  tab:CreateSlider({Name="Ambient brightness",Range={0,255},Increment=1,CurrentValue=128,Callback=function(v) opts.ambient=math.floor(math.clamp(tonumber(v) or 128,0,255));apply() end})
  tab:CreateToggle({Name="Override world shadows",CurrentValue=false,Callback=function(v) opts.shadowsEnabled=v;apply() end})
  tab:CreateToggle({Name="World shadows",CurrentValue=true,Callback=function(v) opts.shadows=v;apply() end})
  tab:CreateSection("Scene and camera")
  tab:CreateToggle({Name="Custom time",CurrentValue=false,Callback=function(v) opts.clockEnabled=v;apply() end})
  tab:CreateSlider({Name="Time of day",Range={0,23.75},Increment=0.25,CurrentValue=14,Callback=function(v) opts.clock=math.clamp(tonumber(v) or 14,0,23.75);apply() end})
  tab:CreateToggle({Name="Camera FOV override",CurrentValue=false,Callback=function(v) opts.fovEnabled=v;apply() end})
  tab:CreateSlider({Name="Camera FOV",Range={40,120},Increment=1,CurrentValue=70,Callback=function(v) opts.fov=math.clamp(tonumber(v) or 70,40,120);apply() end})
  local cameraConnection=Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(apply)
  local alive=true
  return {Stop=function()
    if not alive then return end
    alive=false
    cameraConnection:Disconnect()
    opts.clockEnabled=false
    opts.fovEnabled=false
    opts.brightnessEnabled=false;opts.fogEnabled=false;opts.ambientEnabled=false;opts.shadowsEnabled=false
    apply()
    color:Destroy()
    bloom:Destroy();rays:Destroy();depth:Destroy()
  end}
end

