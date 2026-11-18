-- NovaX v1.1 RELEASE LOADER
-- Developers: Klaus (Dev), Nexus (Bug Fixer)
-- Loads original 7466-line template as UI + main core, plus optional
-- 90Hz weather, compatibility checker and integrated Weather/Diagnostics tabs.
local REV="2df577a270a78151c9afa2f7b7b9340e45a38f4d"
local VISUAL_REV="c290c9998ce798a2720f111b19f7885e10b0d695"
local DIAG_REV="403437264c2067d8f1fbd4c64fb53fadb1b78d65"
local FIRE_REV="30b4f0d542cc71fafeb34910751f3c81a9828553"
local DROPS_REV="f7cc67f6488dbf580f8a30329264ef16924a5bac"
local CORE_REV="5f3ee8e7e9d05c8ece707dd0bda3ce27de3c093f"
local EQUIPMENT_REV="e8f386a5c780531c13eb51c2a04971be53216b8f"
local GUI_REV="663d8a59cbf8d87023685cf8f3a77d8a0f66bcf4"
local SPREAD_REV="8bfaaaa7fac652ecc486baf20b983f22cd7b98d3"
local BASE="https://raw.githubusercontent.com/ovaNite/uwuHub/"..REV.."/novax/v1/"
local env=(getgenv and getgenv()) or _G
if type(loadstring)~="function" then
  error("[NovaX] This executor does not provide loadstring")
end
local function load(relative)
  local url = relative=="core/legacy.lua" and ("https://raw.githubusercontent.com/ovaNite/uwuHub/"..CORE_REV.."/novax/v1.1/core/legacy.lua") or relative=="modules/visual_studio.lua" and ("https://raw.githubusercontent.com/ovaNite/uwuHub/"..VISUAL_REV.."/novax/v1.1/modules/visual_studio.lua") or (BASE..relative)
  if relative=="modules/weapon_diagnostics.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..DIAG_REV.."/novax/v1.1/modules/weapon_diagnostics.lua"
  elseif relative=="modules/rapid_fire.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..FIRE_REV.."/novax/v1.1/modules/rapid_fire.lua"
  elseif relative=="modules/auto_drops.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..DROPS_REV.."/novax/v1.1/modules/auto_drops.lua"
  elseif relative=="modules/no_spread.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..SPREAD_REV.."/novax/v1.1/modules/no_spread.lua"
  elseif relative=="modules/gui_extensions.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..GUI_REV.."/novax/v1.1/modules/gui_extensions.lua"
  elseif relative=="modules/official_cosmetics.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..EQUIPMENT_REV.."/novax/v1.1/modules/official_cosmetics.lua"
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
-- Workspace pickup controller: local discovery and optional remote-touch attempts.
local dropsFactory=execute("modules/auto_drops.lua",false)
local dropsModule=nil
if type(dropsFactory)=="function" then
  local ok,result=pcall(dropsFactory,env)
  if ok and type(result)=="table" then dropsModule=result
  else
    local message="Auto Drops: "..tostring(result)
    table.insert(env.NovaXRelease.Errors,message)
    warn("[NovaX] "..message)
  end
end
-- Reversible No Spread via the six numeric/boolean ItemLibrary spread fields.
local noSpreadFactory=execute("modules/no_spread.lua",false)
local noSpreadModule=nil
if type(noSpreadFactory)=="function" then
  local ok,result=pcall(noSpreadFactory,env)
  if ok and type(result)=="table" then noSpreadModule=result
  else
    local message="No Spread: "..tostring(result)
    table.insert(env.NovaXRelease.Errors,message)
    warn("[NovaX] "..message)
  end
end
-- Use the real client Gun controller when present; never confuse viewmodels
-- or activation spam with confirmed shots.
local rapidFactory=execute("modules/rapid_fire.lua",false)
local rapidModule=nil
if type(rapidFactory)=="function" then
  local ok,result=pcall(rapidFactory,env)
  if ok and type(result)=="table" then rapidModule=result
  else
    local message="Fast Fire: "..tostring(result)
    table.insert(env.NovaXRelease.Errors,message)
    warn("[NovaX] "..message)
  end
end
-- Weapon controls and local shot sounds. Tool mode is fallback only.
local controlsModule
local okControls,controlsError=pcall(function()
  local ui=assert(env.NX_UI_WINDOW,"NovaX GUI not available")
  local player=game:GetService("Players").LocalPlayer
  local input=game:GetService("UserInputService")
  local run=game:GetService("RunService")
  local workspace=game:GetService("Workspace")
  local settings=assert(env.NX_STATE,"NovaX state unavailable")
  local fast=settings.NovaXFastFire==true
  local muted=settings.NovaXNoShootSound==true
  local rate=math.floor(math.clamp(tonumber(settings.NovaXFastFireMultiplier) or 4,1,20))
  local volume=math.clamp(tonumber(settings.NovaXShotVolume) or 100,0,100)
  local includeShared=settings.NovaXSharedShotSounds~=false
  local includeItemSounds=settings.NovaXWeaponEffectSounds~=false
  local held,active,nextShot=false,true,0
  local saved=setmetatable({}, {__mode="k"})
  local watched=setmetatable({}, {__mode="k"})
  local shotIds,shotIdsAll,shotIdsOther,itemSoundIds={},{},{},{}
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
                or lower:find("_shoot_",1,true) or lower:find("_fire_",1,true)
                or lower:find("_quickshot_",1,true)
              local target=shooting and shotIdsAll or shotIdsOther
              for _,id in pairs(ids) do
                if type(id)=="string" then
                  local numeric=id:match("%d+")
                  if numeric then target[numeric]=true end
                end
              end
            end
          end
          local itemSource=library:FindFirstChild("ItemSounds")
          if itemSource and itemSource:IsA("ModuleScript") then
            local itemOk,itemData=pcall(require,itemSource)
            if itemOk and type(itemData)=="table" then
              for _,weapon in ipairs({"Bow","Crossbow","Slingshot","Minigun","Exogun","Grenade Launcher","Paintball Gun","Flamethrower"}) do
                local values=itemData[weapon]
                if type(values)=="table" then for _,id in pairs(values) do
                  if type(id)=="string" then local numeric=id:match("%d+");if numeric then itemSoundIds[numeric]=true end end
                end end
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
    if includeItemSounds then for id in pairs(itemSoundIds) do shotIds[id]=true end end
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
  local applySound
  local function watchVolume(sound)
    local soundLinks=watched[sound]
    if not soundLinks or soundLinks.volumeWatched then return end
    soundLinks.volumeWatched=true
    connect(sound:GetPropertyChangedSignal("Volume"),function()
      if not active or saved[sound]==nil then return end
      local expected=muted and 0 or saved[sound]*volume/100
      if math.abs(sound.Volume-expected)>0.0001 then saved[sound]=sound.Volume;applySound(sound) end
    end,soundLinks)
  end
  applySound=function(sound)
    if not active then return end
    if not isShot(sound) then
      local original=saved[sound]
      if original~=nil then saved[sound]=nil;pcall(function() sound.Volume=original end) end
      return
    end
    watchVolume(sound)
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
  connect(player.ChildAdded,function(child)
    if not child:IsA("Backpack") then return end
    task.defer(function()
      if not active or (not muted and volume==100) or child.Parent~=player then return end
      for _,obj in ipairs(child:GetDescendants()) do if obj:IsA("Sound") then trackSound(obj) end end
      connect(child.DescendantAdded,trackSound,rootConnections)
    end)
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
    -- When the RIVALS Gun hook is installed it handles the real client
    -- cooldown. Do not simultaneously spam legacy Tool activations.
    if rapidModule and rapidModule:Ready() then return end
    local now=os.clock()
    if now<nextShot then return end
    nextShot=now+1/math.max(1,rate*4)
    local character=player.Character
    local tool=character and character:FindFirstChildOfClass("Tool")
    if tool and tool.Enabled then pcall(function() tool:Activate() end) end
  end)
  local tab=ui:CreateTab("Weapon Controls",4483345998)
  tab:CreateSection("Fast Fire")
  tab:CreateLabel("Targets local Gun._shoot_cooldown (x1-x20). Server firing limits may still apply.")
  local controlRefs={}
  local function record(key,control) controlRefs[key]=control;return control end
  record("NovaXFastFire",tab:CreateToggle({Name="Fast Fire",CurrentValue=fast,Callback=function(v)
    fast=v==true;settings.NovaXFastFire=fast;nextShot=0
    if rapidModule then rapidModule:SetActive(fast) end
  end}))
  record("NovaXFastFireMultiplier",tab:CreateSlider({Name="Fire speed multiplier (x)",Range={1,20},Increment=1,CurrentValue=rate,
    Callback=function(v)
      rate=math.floor(math.clamp(tonumber(v) or 4,1,20))
      settings.NovaXFastFireMultiplier=rate
      if rapidModule then rapidModule:SetMultiplier(rate) end
    end}))
  tab:CreateButton({Name="Check Fast Fire status",Callback=function()
    local message=rapidModule and rapidModule:Status() or "Gun hook unavailable; Tool fallback only"
    print("[NovaX Fast Fire] "..message)
    if ui.Notify then ui:Notify({Title="Fast Fire",Content=message,Duration=7}) end
  end})
  tab:CreateSection("Spread")
  tab:CreateLabel("Uses 6 ItemLibrary spread fields for all weapons; local changes only.")
  record("NoSpread",tab:CreateToggle({Name="No Spread",CurrentValue=settings.NoSpread==true,
    Callback=function(v)
      settings.NoSpread=v==true
      if noSpreadModule then noSpreadModule:SetActive(v) end
    end}))
  tab:CreateButton({Name="Check No Spread status",Callback=function()
    local message=noSpreadModule and noSpreadModule:Status() or "ItemLibrary module unavailable"
    print("[NovaX No Spread] "..message)
    if ui.Notify then ui:Notify({Title="No Spread",Content=message,Duration=7}) end
  end})
  tab:CreateSection("Local shot sounds")
  tab:CreateLabel("Uses shooting sound IDs when available and common local sound names.")
  record("NovaXNoShootSound",tab:CreateToggle({Name="No Shoot Sound",CurrentValue=muted,
    Callback=function(v) muted=v==true;settings.NovaXNoShootSound=muted;applySounds() end}))
  record("NovaXSharedShotSounds",tab:CreateToggle({Name="Include shared shot sounds (may mute other effects)",CurrentValue=includeShared,
    Callback=function(v) includeShared=v==true;settings.NovaXSharedShotSounds=includeShared;applySounds() end}))
  record("NovaXWeaponEffectSounds",tab:CreateToggle({Name="Include weapon effect sounds (may mute extra effects)",CurrentValue=includeItemSounds,
    Callback=function(v) includeItemSounds=v==true;settings.NovaXWeaponEffectSounds=includeItemSounds;applySounds() end}))
  record("NovaXShotVolume",tab:CreateSlider({Name="Shot volume (%)",Range={0,100},Increment=5,CurrentValue=volume,
    Callback=function(v) volume=math.clamp(tonumber(v) or 100,0,100);settings.NovaXShotVolume=volume;applySounds() end}))
  controlsModule.ApplyState=function()
    if not active then return end
    fast=settings.NovaXFastFire==true
    muted=settings.NovaXNoShootSound==true
    rate=math.floor(math.clamp(tonumber(settings.NovaXFastFireMultiplier) or 4,1,20))
    volume=math.clamp(tonumber(settings.NovaXShotVolume) or 100,0,100)
    includeShared=settings.NovaXSharedShotSounds~=false
    includeItemSounds=settings.NovaXWeaponEffectSounds~=false
    nextShot=0
    if rapidModule then
      rapidModule:SetMultiplier(rate)
      rapidModule:SetActive(fast)
    end
    if noSpreadModule then noSpreadModule:SetActive(settings.NoSpread==true) end
    local updates={
      NovaXFastFire=fast,NovaXFastFireMultiplier=rate,NoSpread=settings.NoSpread==true,
      NovaXNoShootSound=muted,NovaXSharedShotSounds=includeShared,
      NovaXWeaponEffectSounds=includeItemSounds,NovaXShotVolume=volume
    }
    for key,value in pairs(updates) do
      local control=controlRefs[key]
      if control and control.Set then pcall(function()control:Set(value)end) end
    end
    applySounds()
  end
  controlsModule.ApplyState()
  roots()
end)
if not okControls then
  if controlsModule then pcall(controlsModule.Stop);controlsModule=nil end
  table.insert(env.NovaXRelease.Errors,"Weapon Controls: "..tostring(controlsError))
  warn("[NovaX] Weapon Controls: "..tostring(controlsError))
end
-- New baseline: the game's own Equipment GUI is the only supported equip
-- entry point. No cloned skins, "unlocked" icons, lock hiding or fake overlays.
local equipmentFactory=execute("modules/official_cosmetics.lua",false)
local equipmentModule=nil
if type(equipmentFactory)=="function" then
  local ok,result=pcall(equipmentFactory,env)
  if ok and type(result)=="table" then
    equipmentModule=result
  else
    local message="RIVALS Equipment: "..tostring(result)
    table.insert(env.NovaXRelease.Errors,message)
    warn("[NovaX] "..message)
  end
end
-- Called after the original Config Manager loads a profile. All extension
-- modules then synchronize their runtime and visible controls from NX_STATE.
env.NX_CONFIG_APPLY=function()
  if controlsModule and controlsModule.ApplyState then pcall(controlsModule.ApplyState) end
  if dropsModule and dropsModule.ApplyState then pcall(dropsModule.ApplyState) end
  if type(visualModule)=="table" and visualModule.ApplyState then pcall(visualModule.ApplyState) end
  if type(env.NovaXWeatherControls)=="table" and env.NovaXWeatherControls.ApplyState then
    pcall(env.NovaXWeatherControls.ApplyState)
  end
end
env.NX_CLEANUP=function()
  if equipmentModule and equipmentModule.Stop then pcall(equipmentModule.Stop) end
  env.NovaXChooseSkin=nil
  if controlsModule then pcall(controlsModule.Stop) end
  if dropsModule and type(dropsModule.Stop)=="function" then pcall(dropsModule.Stop,dropsModule) end
  if noSpreadModule and type(noSpreadModule.Stop)=="function" then pcall(noSpreadModule.Stop,noSpreadModule) end
  if rapidModule and type(rapidModule.Stop)=="function" then pcall(rapidModule.Stop,rapidModule) end
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

