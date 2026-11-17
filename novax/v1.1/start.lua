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
  local held,active,nextShot=false,true,0
  local saved=setmetatable({}, {__mode="k"})
  local connections,rootConnections={},{}
  local function connect(signal,callback,list)
    local c=signal:Connect(callback)
    table.insert(list or connections,c)
    return c
  end
  local function isShot(sound)
    if not sound:IsA("Sound") then return false end
    local name=string.lower(sound.Name)
    for _,word in ipairs({"shoot","shot","fire","gunshot","gunfire"}) do
      if string.find(name,word,1,true) then return true end
    end
    return false
  end
  local function updateSound(sound)
    if not active then return end
    if not isShot(sound) or (not muted and volume==100) then return end
    if saved[sound]==nil then saved[sound]=sound.Volume end
    pcall(function() sound.Volume=muted and 0 or saved[sound]*volume/100 end)
  end
  local function scan(root)
    if not root then return end
    for _,obj in ipairs(root:GetDescendants()) do updateSound(obj) end
  end
  local function roots()
    if not active then return end
    for _,connection in ipairs(rootConnections) do connection:Disconnect() end
    rootConnections={}
    for _,root in pairs({character=player.Character,camera=workspace.CurrentCamera,
                         backpack=player:FindFirstChildOfClass("Backpack")}) do
      scan(root)
      connect(root.DescendantAdded,updateSound,rootConnections)
    end
  end
  local function applySounds()
    for sound,original in pairs(saved) do
      pcall(function() sound.Volume=muted and 0 or original*volume/100 end)
      if not muted and volume==100 then saved[sound]=nil end
    end
    roots()
  end
  controlsModule={Stop=function()
    active=false
    for _,connection in ipairs(connections) do connection:Disconnect() end
    for _,connection in ipairs(rootConnections) do connection:Disconnect() end
    for sound,original in pairs(saved) do pcall(function() sound.Volume=original end) end
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
  tab:CreateLabel("Matches common shot sound names on your character, backpack and camera.")
  tab:CreateToggle({Name="No Shoot Sound",CurrentValue=false,Callback=function(v) muted=v;applySounds() end})
  tab:CreateSlider({Name="Shot volume (%)",Range={0,100},Increment=5,CurrentValue=100,
    Callback=function(v) volume=math.clamp(tonumber(v) or 100,0,100);applySounds() end})
  roots()
end)
if not okControls then
  if controlsModule then pcall(controlsModule.Stop);controlsModule=nil end
  table.insert(env.NovaXRelease.Errors,"Weapon Controls: "..tostring(controlsError))
  warn("[NovaX] Weapon Controls: "..tostring(controlsError))
end
env.NX_CLEANUP=function()
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

