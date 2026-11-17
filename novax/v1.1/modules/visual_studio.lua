-- NovaX: lokale Grafikoptionen. Klaus (Dev) / Nexus (Bug Fixer)
return function(env)
  local ui=env.NX_UI_WINDOW
  if type(ui)~="table" or type(ui.CreateTab)~="function" then error("GUI not available") end
  local Lighting=game:GetService("Lighting")
  local Workspace=game:GetService("Workspace")
  for _,name in ipairs({"NovaX_Color","NovaX_Bloom"}) do
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
  local initialClock=Lighting.ClockTime
  local assignedClock=nil
  local lastCamera=nil
  local initialFov=nil
  local assignedFov=nil
  local opts={enabled=false,bloom=false,saturation=0,contrast=0,clock=14,fov=70,clockEnabled=false,fovEnabled=false}
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
    bloom.Enabled=opts.bloom
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
  local tab=ui:CreateTab("Visual Studio",4483345998)
  tab:CreateSection("Color and light")
  tab:CreateToggle({Name="Color grading",CurrentValue=false,Callback=function(v) opts.enabled=v;apply() end})
  tab:CreateSlider({Name="Saturation",Range={-100,100},Increment=1,CurrentValue=0,Callback=function(v) opts.saturation=math.clamp((tonumber(v) or 0)/100,-1,1);apply() end})
  tab:CreateSlider({Name="Contrast",Range={-100,100},Increment=1,CurrentValue=0,Callback=function(v) opts.contrast=math.clamp((tonumber(v) or 0)/100,-1,1);apply() end})
  tab:CreateToggle({Name="Bloom",CurrentValue=false,Callback=function(v) opts.bloom=v;apply() end})
  tab:CreateSlider({Name="Bloom intensity",Range={0,100},Increment=1,CurrentValue=30,Callback=function(v) bloom.Intensity=math.clamp((tonumber(v) or 0)/100,0,1) end})
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
    apply()
    color:Destroy()
    bloom:Destroy()
  end}
end
