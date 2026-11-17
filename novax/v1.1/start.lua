-- NovaX v1.1 RELEASE LOADER
-- Developers: Klaus (Dev), Nexus (Bug Fixer)
-- Loads original 7466-line template as UI + main core, plus optional
-- 90Hz weather, compatibility checker and integrated Weather/Diagnostics tabs.
local REV="2df577a270a78151c9afa2f7b7b9340e45a38f4d"
local VISUAL_REV="47a44eee561bdc9d9cb52f04712d914d91bab74b"
local DIAG_REV="650f186a50d8b44420c946ca9d8ff39e008bd6f3"
local CORE_REV="7d1f117e9d25d7cbb47f17ebdd59f007ecc34605"
local BASE="https://raw.githubusercontent.com/ovaNite/uwuHub/"..REV.."/novax/v1/"
local env=(getgenv and getgenv()) or _G
if type(loadstring)~="function" then
  error("[NovaX] This executor does not provide loadstring")
end
local function load(relative)
  local url = relative=="core/legacy.lua" and ("https://raw.githubusercontent.com/ovaNite/uwuHub/"..CORE_REV.."/novax/v1.1/core/legacy.lua") or relative=="modules/visual_studio.lua" and ("https://raw.githubusercontent.com/ovaNite/uwuHub/"..VISUAL_REV.."/novax/v1.1/modules/visual_studio.lua") or (BASE..relative)
  if relative=="modules/weapon_diagnostics.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..DIAG_REV.."/novax/v1.1/modules/weapon_diagnostics.lua"
  end
  local ok,result=pcall(function()return game:HttpGet(url,true)end)
  if not ok or type(result)~="string" or #result<100 then
    error("[NovaX] Cannot download "..relative..": "..tostring(result))
  end
  local chunk,syntax=loadstring(result)
  if not chunk then error("[NovaX] Syntax error in "..relative..": "..tostring(syntax))end
  return chunk
end
local function cleanKnown()
  if type(env.NovaXWeather)=="table" and type(env.NovaXWeather.Stop)=="function" then
    pcall(env.NovaXWeather.Stop)
  end
  if type(env.NX_CLEANUP)=="function" then pcall(env.NX_CLEANUP)end
  for _,key in ipairs({
    "roblox_modPack_v9","roblox_modPack_v8","roblox_modPack_v7",
    "roblox_modPack_v6","roblox_modPack_v5","roblox_modPack_Realism_v4"
  }) do
    local old=env[key]
    if type(old)=="table" and type(old.Stop)=="function" then
      pcall(old.Stop)
    end
  end
  if type(env.NX_INTERNAL_RAY_HOOK)=="table" then
    env.NX_INTERNAL_RAY_HOOK.enabled=false
    env.NX_INTERNAL_RAY_HOOK.target=nil
  end
  env.NX_XENO=nil
  env.NX_XENO_LOADING=nil
  local lp=game:GetService("Players").LocalPlayer
  local pg=lp and lp:FindFirstChildOfClass("PlayerGui")
  if pg then
    for _,name in ipairs({
      "RM4_LocalGraphicsDiagnostics","RM5_RealismControl",
      "RM53_Control","RM6_Control","RM9_Control","NovaX_WeatherOverlay"
    }) do
      local instance=pg:FindFirstChild(name)
      if instance then pcall(function()instance:Destroy()end)end
    end
  end
end
cleanKnown()
env.NX_XENO_LOADING=true
env.NovaXRelease={Version="1.1",Credits={"Klaus (Dev)","Nexus (Bug Fixer)"},
  Pinned=REV,Ready=false,Errors={}}
local function execute(path,required)
  local ok,result=pcall(function()return load(path)()end)
  if not ok then
    local msg=path..": "..tostring(result)
    env.NovaXRelease.Errors[#env.NovaXRelease.Errors+1]=msg
    warn("[NovaX] "..msg)
    if required then error("[NovaX] Required module failed: "..msg)end
    return nil
  end
  print("[NovaX] Loaded "..path)
  return result
end
-- Preserve the supplied original UI library; never download random branches.
local premium=execute("ui/NovaPremiumUI.lua",true)
if type(premium)~="table" or type(premium.CreateWindow)~="function" then
  error("[NovaX] Premium UI library returned an invalid API")
end
env.NovaPremiumUI=premium
local probe=execute("modules/capabilities.lua",true)
if type(probe)=="function" then
  local ok,r=pcall(probe)
  if ok then env.NovaXAudit=r else warn("[NovaX] Capability audit: "..tostring(r))end
end
-- The original 5000+ lines of aim, ESP, movement, trigger, config and GUI.
execute("core/legacy.lua",true)
local baseCleanup=env.NX_CLEANUP
-- Weather is modular and starts in OFF mode, so nothing expensive begins
-- until the user activates Rain or Snow in the premium GUI.
local weatherFactory=execute("modules/weather.lua",false)
if type(weatherFactory)=="function" then
  local ok,r=pcall(weatherFactory,env)
  if ok then env.NovaXWeather=r
  else
    warn("[NovaX] Weather unavailable: "..tostring(r))
    env.NovaXRelease.Errors[#env.NovaXRelease.Errors+1]=tostring(r)
  end
end
local guiFactory=execute("modules/gui_extensions.lua",false)
if type(guiFactory)=="function" then
  local ok,r=pcall(guiFactory,env)
  if not ok then
    warn("[NovaX] Extra GUI tabs failed: "..tostring(r))
    env.NovaXRelease.Errors[#env.NovaXRelease.Errors+1]=tostring(r)
  end
end
local visualFactory=execute("modules/visual_studio.lua",false)
local visualModule=nil
if type(visualFactory)=="function" then
  local ok,result=pcall(visualFactory,env)
  if ok then visualModule=result
  else
    table.insert(env.NovaXRelease.Errors,"Visual Studio: "..tostring(result))
    warn("[NovaX] Visual Studio: "..tostring(result))
  end
end
local diagnosticsFactory=execute("modules/weapon_diagnostics.lua",false)
if type(diagnosticsFactory)=="function" then
  local ok,err=pcall(diagnosticsFactory,env)
  if not ok then
    table.insert(env.NovaXRelease.Errors,"Weapon Diagnostics: "..tostring(err))
    warn("[NovaX] Weapon Diagnostics: "..tostring(err))
  end
end
-- Local weapon controls: regular Tool activation and local sound volume only.
local controlsModule
local okControls,controlsError=pcall(function()
  local ui=assert(env.NX_UI_WINDOW,"NovaX GUI not available")
  local player=game:GetService("Players").LocalPlayer
  local input=game:GetService("UserInputService")
  local run=game:GetService("RunService")
  local workspace=game:GetService("Workspace")
  local fast,muted,rate,volume=false,false,10,100
  local includeShared=false
  local held,active,nextShot=false,true,0
  local saved=setmetatable({}, {__mode="k"})
  local watched=setmetatable({}, {__mode="k"})
  local shotIds,shotIdsAll,shotIdsOther={},{},{}
  local registryReady=false
  local connections,rootConnections={},{}
  local soundService=game:GetService("SoundService")
  local function connect(signal,callback,list)
    local c=signal:Connect(callback)
    table.insert(list or connections,c)
    return c
  end
  -- Some games publish audio metadata as a table. Only use explicitly named
  -- shooting animations, and exclude IDs also used by other animation types.
  local function buildShotIds()
    if not registryReady then
      local storage=game:GetService("ReplicatedStorage")
      local modules=storage:FindFirstChild("Modules")
      local library=modules and modules:FindFirstChild("SoundLibrary")
      local source=library and library:FindFirstChild("ScrapedAnimationSounds")
      if source and source:IsA("ModuleScript") then
        local ok,data=pcall(require,source)
        if ok and type(data)=="table" then
          for name,ids in pairs(data) do
            if type(name)=="string" and type(ids)=="table" then
              local lower=string.lower(name)
              local action=lower:match("_([^_]+)$") or lower
              local shooting=action:match("^shoot%d*$") or action:match("^fire%d*$")
                or action:match("^shot%d*$") or action=="quickshot"
              local target=shooting and shotIdsAll or shotIdsOther
              for _,id in pairs(ids) do
                if type(id)=="string" then
                  local numeric=id:match("%d+")
                  if numeric then target[numeric]=true end
                end
              end
            end
          end
          registryReady=true
        end
      end
    end
    shotIds={}
    for id in pairs(shotIdsAll) do
      if includeShared or not shotIdsOther[id] then shotIds[id]=true end
    end
  end
  local function isShot(sound)
    if not sound:IsA("Sound") then return false end
    local id=tostring(sound.SoundId):match("%d+")
    if id and shotIds[id] then return true end
    local localRoot=(player.Character and sound:IsDescendantOf(player.Character))
      or (workspace.CurrentCamera and sound:IsDescendantOf(workspace.CurrentCamera))
      or (player:FindFirstChildOfClass("Backpack") and sound:IsDescendantOf(player:FindFirstChildOfClass("Backpack")))
    if not localRoot then return false end
    local name=string.lower(sound.Name)
    for _,word in ipairs({"shoot","shot","gunfire","gunshot"}) do
      if string.find(name,word,1,true) then return true end
    end
    return false
  end
  local function applySound(sound)
    if not active then return end
    if not isShot(sound) then
      local original=saved[sound]
      if original~=nil then saved[sound]=nil;pcall(function() sound.Volume=original end) end
      return
    end
    if saved[sound]==nil then saved[sound]=sound.Volume end
    local target=muted and 0 or saved[sound]*volume/100
    if math.abs(sound.Volume-target)>0.0001 then pcall(function() sound.Volume=target end) end
  end
  local function trackSound(sound)
    if not active or not sound:IsA("Sound") then return end
    if watched[sound] then applySound(sound);return end
    local soundLinks={}
    watched[sound]=soundLinks
    connect(sound:GetPropertyChangedSignal("SoundId"),function() applySound(sound) end,soundLinks)
    connect(sound:GetPropertyChangedSignal("Name"),function() applySound(sound) end,soundLinks)
    connect(sound:GetPropertyChangedSignal("Volume"),function()
      if not active or saved[sound]==nil then return end
      local expected=muted and 0 or saved[sound]*volume/100
      if math.abs(sound.Volume-expected)>0.0001 then saved[sound]=sound.Volume;applySound(sound) end
    end,soundLinks)
    connect(sound.Destroying,function()
      for _,connection in ipairs(soundLinks) do connection:Disconnect() end
      watched[sound]=nil;saved[sound]=nil
    end,soundLinks)
    applySound(sound)
  end
  local function stopSounds()
    for _,connection in ipairs(rootConnections) do connection:Disconnect() end
    for _,links in pairs(watched) do
      for _,connection in ipairs(links) do connection:Disconnect() end
    end
    rootConnections={}
    watched=setmetatable({}, {__mode="k"})
    for sound,original in pairs(saved) do pcall(function() sound.Volume=original end) end
    saved=setmetatable({}, {__mode="k"})
  end
  local function roots()
    if not active or (not muted and volume==100) then return end
    for _,connection in ipairs(rootConnections) do connection:Disconnect() end
    rootConnections={}
    for _,root in pairs({world=workspace,sounds=soundService,
                         backpack=player:FindFirstChildOfClass("Backpack")}) do
      for _,obj in ipairs(root:GetDescendants()) do if obj:IsA("Sound") then trackSound(obj) end end
      connect(root.DescendantAdded,trackSound,rootConnections)
    end
  end
  local function applySounds()
    if not muted and volume==100 then stopSounds();return end
    buildShotIds()
    for sound in pairs(watched) do applySound(sound) end
    if #rootConnections==0 then roots() end
  end
  controlsModule={Stop=function()
    active=false
    for _,connection in ipairs(connections) do connection:Disconnect() end
    stopSounds()
  end}
  connect(player.CharacterAdded,function() task.defer(roots) end)
  connect(workspace:GetPropertyChangedSignal("CurrentCamera"),roots)
  connect(player.ChildAdded,function(child)
    if child:IsA("Backpack") then task.defer(roots) end
  end)
  connect(input.InputBegan,function(event,processed)
    if event.UserInputType==Enum.UserInputType.MouseButton1 and not processed then held=true end
  end)
  connect(input.InputEnded,function(event)
    if event.UserInputType==Enum.UserInputType.MouseButton1 then held=false end
  end)
  connect(input.WindowFocusReleased,function() held=false end)
  connect(run.Heartbeat,function()
    if not active or not fast or not held or input:GetFocusedTextBox() then return end
    local now=os.clock()
    if now<nextShot then return end
    nextShot=now+1/rate
    local character=player.Character
    local tool=character and character:FindFirstChildOfClass("Tool")
    if tool and tool.Enabled then pcall(function() tool:Activate() end) end
  end)
  local tab=ui:CreateTab("Weapon Controls",4483345998)
  tab:CreateSection("Fast Fire")
  tab:CreateLabel("Repeats Tool activation while holding left mouse; game cooldowns still apply.")
  tab:CreateToggle({Name="Fast Fire",CurrentValue=false,Callback=function(v) fast=v;nextShot=0 end})
  tab:CreateSlider({Name="Activations per second",Range={1,20},Increment=1,CurrentValue=10,
    Callback=function(v) rate=math.clamp(tonumber(v) or 10,1,20) end})
  tab:CreateSection("Local shot sounds")
  tab:CreateLabel("Uses shooting sound IDs when available and common local sound names.")
  tab:CreateToggle({Name="No Shoot Sound",CurrentValue=false,Callback=function(v) muted=v;applySounds() end})
  tab:CreateToggle({Name="Include shared shot sounds (may mute other effects)",CurrentValue=false,
    Callback=function(v) includeShared=v;applySounds() end})
  tab:CreateSlider({Name="Shot volume (%)",Range={0,100},Increment=5,CurrentValue=100,
    Callback=function(v) volume=math.clamp(tonumber(v) or 100,0,100);applySounds() end})
  roots()
end)
if not okControls then
  if controlsModule then pcall(controlsModule.Stop);controlsModule=nil end
  table.insert(env.NovaXRelease.Errors,"Weapon Controls: "..tostring(controlsError))
  warn("[NovaX] Weapon Controls: "..tostring(controlsError))
end
-- Local view-model appearance selector; does not alter weapon behaviour.
local modelControls
local okModels,modelError=pcall(function()
  local ui=assert(env.NX_UI_WINDOW,"NovaX GUI not available")
  local player=game:GetService("Players").LocalPlayer
  local run=game:GetService("RunService")
  local store=game:GetService("ReplicatedStorage")
  local world=game:GetService("Workspace")
  local cache,originals,links={},{},{}
  local active,selected,shown,shownRig=true,"Original",nil,nil
  local options,dropdown={"Original"},nil
  local function clear()
    if shown then shown:Destroy();shown=nil end
    for part,old in pairs(originals) do pcall(function() part.LocalTransparencyModifier=old end) end
    originals={};shownRig=nil
  end
  local function root()
    local view=world:FindFirstChild("ViewModels")
    return view and view:FindFirstChild("FirstPerson")
  end
  local function rig()
    local r=root();if not r then return nil end
    local prefix=player.Name.." - "
    for _,v in ipairs(r:GetChildren()) do
      if v:IsA("Model") and v.Name:sub(1,#prefix)==prefix and v:FindFirstChild("ItemVisual") then return v end
    end
    return nil
  end
  local function add(model)
    if not model:IsA("Model") then return end
    local prefix=player.Name.." - "
    if model.Name:sub(1,#prefix)~=prefix then return end
    local name=model.Name:sub(#prefix+1)
    if cache[name] or #options>=129 then return end
    local visual=model:FindFirstChild("ItemVisual")
    local grip=model:FindFirstChild("RightItem")
    if not visual or not visual:IsA("Model") or not grip or not grip:IsA("BasePart") then return end
    if not visual:FindFirstChildWhichIsA("BasePart",true) then return end
    local ok,copy,offset=pcall(function() return visual:Clone(),grip.CFrame:ToObjectSpace(visual:GetPivot()) end)
    if not ok or not copy then return end
    for _,v in ipairs(copy:GetDescendants()) do
      if v:IsA("LuaSourceContainer") or v:IsA("Sound") or v:IsA("JointInstance") or v:IsA("Constraint") then
        v:Destroy()
      elseif v:IsA("BasePart") then
        v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
      end
    end
    cache[name]={visual=copy,offset=offset}
    options[#options+1]=name
    if dropdown and dropdown.Refresh then dropdown:Refresh(options) end
  end
  local function scan()
    local activeRoot=root()
    local assets=store:FindFirstChild("Assets")
    local temp=assets and assets:FindFirstChild("Temp")
    local parked=temp and temp:FindFirstChild("ViewModels")
    for _,container in pairs({activeRoot,parked}) do
      if container then for _,model in ipairs(container:GetChildren()) do add(model) end end
    end
  end
  local function show(target)
    clear()
    local source=cache[selected]
    if not source or not target then return end
    local visual=target:FindFirstChild("ItemVisual")
    local grip=target:FindFirstChild("RightItem")
    if not visual or not grip or not grip:IsA("BasePart") then return end
    local clone=source.visual:Clone()
    if not clone then return end
    clone.Name="NovaX_LocalModel"
    clone.Parent=world.CurrentCamera or world
    for _,part in ipairs(visual:GetDescendants()) do
      if part:IsA("BasePart") then originals[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1 end
    end
    shown=clone;shownRig=target
  end
  local tab=ui:CreateTab("Weapon Models",4483345998)
  tab:CreateSection("Local appearance")
  tab:CreateLabel("Equip variants to add them. Appearance is visible only to you.")
  dropdown=tab:CreateDropdown({Name="Model",Options=options,CurrentOption={"Original"},Callback=function(v)
    selected=type(v)=="table" and tostring(v[1]) or tostring(v)
    clear()
  end})
  tab:CreateButton({Name="Refresh loaded models",Callback=scan})
  modelControls={Stop=function()
    active=false
    for _,c in ipairs(links) do c:Disconnect() end
    clear()
    for _,entry in pairs(cache) do entry.visual:Destroy() end
    cache={}
  end}
  local lastScan=0
  links[#links+1]=run.RenderStepped:Connect(function()
    if not active then return end
    local now=os.clock()
    if now-lastScan>=1 then lastScan=now;scan() end
    local target=rig()
    if selected=="Original" then if shown then clear() end;return end
    if target~=shownRig then show(target) end
    if shown and target then
      local grip=target:FindFirstChild("RightItem")
      local source=cache[selected]
      if grip and source then pcall(function() shown:PivotTo(grip.CFrame*source.offset) end) else clear() end
    end
  end)
  scan()
end)
if not okModels then
  if modelControls then pcall(modelControls.Stop);modelControls=nil end
  table.insert(env.NovaXRelease.Errors,"Weapon Models: "..tostring(modelError))
  warn("[NovaX] Weapon Models: "..tostring(modelError))
end
env.NX_CLEANUP=function()
  if modelControls then pcall(modelControls.Stop) end
  if controlsModule then pcall(controlsModule.Stop) end
  if type(visualModule)=="table" and type(visualModule.Stop)=="function" then
    pcall(visualModule.Stop)
  end
  if type(env.NovaXWeather)=="table" and type(env.NovaXWeather.Stop)=="function" then
    pcall(env.NovaXWeather.Stop)
  end
  if type(baseCleanup)=="function" then pcall(baseCleanup)end
  if env.NovaXRelease then env.NovaXRelease.Ready=false end
end
env.NovaXRelease.Ready=true
env.NX_XENO_LOADING=nil
print(string.format("[NovaX v%s] Klaus (Dev) | Nexus (Bug Fixer) | Errors: %d",
  env.NovaXRelease.Version,#env.NovaXRelease.Errors))
print("[NovaX] K GUI | Aim modes: Snap / Hook (Internal) | Weather optional")
return env.NovaXRelease

