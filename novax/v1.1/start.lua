-- NovaX v1.1 RELEASE LOADER
-- Developers: Klaus (Dev), Nexus (Bug Fixer)
-- Loads original 7466-line template as UI + main core, plus optional
-- 90Hz weather, compatibility checker and integrated Weather/Diagnostics tabs.
local REV="2df577a270a78151c9afa2f7b7b9340e45a38f4d"
local VISUAL_REV="c290c9998ce798a2720f111b19f7885e10b0d695"
local DIAG_REV="403437264c2067d8f1fbd4c64fb53fadb1b78d65"
local FIRE_REV="30b4f0d542cc71fafeb34910751f3c81a9828553"
local DROPS_REV="f7cc67f6488dbf580f8a30329264ef16924a5bac"
local CORE_REV="8f224350b8bcf07fdf06829367476be235f7c3a8"
local COSMETIC_REV="bdd537628bfdf237f64cdffcff9641c72a90685c"
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
  elseif relative=="modules/cosmetic_preview.lua" then
    url="https://raw.githubusercontent.com/ovaNite/uwuHub/"..COSMETIC_REV.."/novax/v1.1/modules/cosmetic_preview.lua"
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
-- Local weapon skins: read the client's cosmetic catalogue and model assets.
local modelControls
local okModels,modelError=pcall(function()
  local ui=assert(env.NX_UI_WINDOW,"NovaX GUI not available")
  local players=game:GetService("Players")
  local player=players.LocalPlayer
  local run=game:GetService("RunService")
  local world=game:GetService("Workspace")
  local storage=game:GetService("ReplicatedStorage")
  local links,originals,motion={}, {}, {}
  local active,shown,shownRig,shownSkin=true,nil,nil,nil
  local retryAt=0
  local chosen,adjustments={}, {x=0,y=0,z=0,rx=0,ry=0,rz=0}
  local configState=type(env.NX_STATE)=="table" and env.NX_STATE or nil
  local adjustmentKeys={
    x="NovaXSkinOffsetX",y="NovaXSkinOffsetY",z="NovaXSkinOffsetZ",
    rx="NovaXSkinRotationX",ry="NovaXSkinRotationY",rz="NovaXSkinRotationZ"
  }
  local adjustmentControls={}
  if configState then
    for key,setting in pairs(adjustmentKeys) do
      adjustments[key]=tonumber(configState[setting]) or 0
    end
  end
  local http=game:GetService("HttpService")
  local encoded,filterEncoded="{}","{}"
  local excluded={}
  if configState then
    if type(configState.NovaXSkinSelections)~="string" then configState.NovaXSkinSelections="{}" end
    encoded=configState.NovaXSkinSelections
    local ok,data=pcall(function() return http:JSONDecode(encoded) end)
    if ok and type(data)=="table" then chosen=data end
    if type(configState.NovaXSkinConfigFilter)~="string" then configState.NovaXSkinConfigFilter="{}" end
    filterEncoded=configState.NovaXSkinConfigFilter
    local filterOk,filterData=pcall(function() return http:JSONDecode(filterEncoded) end)
    if filterOk and type(filterData)=="table" then excluded=filterData end
  end
  local catalog,assetsByName,weapons={}, {}, {}
  local skinWeapons,skinIcons={},{}
  local iconOriginals=setmetatable({}, {__mode="k"})
  local selectedWeapon,skinDropdown,weaponDropdown,configToggle="",nil,nil,nil
  local shopEnabled=false
  local shopToggle=nil
  if configState then
    if type(configState.NovaXShopPreview)~="boolean" then configState.NovaXShopPreview=false end
    shopEnabled=configState.NovaXShopPreview
  end
  local shopEntries={}
  local labels={}
  local function clear()
    if shown then shown:Destroy();shown=nil end
    for part,value in pairs(originals) do pcall(function() part.LocalTransparencyModifier=value end) end
    originals={};motion={};shownRig=nil;shownSkin=nil
  end
  local function loadCatalog()
    local scripts=player:FindFirstChild("PlayerScripts")
    local assets=scripts and scripts:FindFirstChild("Assets")
    local models=assets and assets:FindFirstChild("ViewModels")
    local modules=storage:FindFirstChild("Modules")
    local library=modules and modules:FindFirstChild("CosmeticLibrary")
    if not models or not library then return false end
    -- CosmeticLibrary is a local catalogue module; do not refuse discovery
    -- just because the executor has no getloadedmodules() function.
    local success,lib=pcall(require,library)
    local all=success and type(lib)=="table" and rawget(lib,"Cosmetics")
    if type(all)~="table" then return false end
    local indexed={}
    for _,model in ipairs(models:GetDescendants()) do
      if model:IsA("Model") and not indexed[model.Name] then indexed[model.Name]=model end
    end
    local nextCatalog,nextWeapons,nextSkinWeapons,nextSkinIcons={},{},{},{}
    for name,entry in pairs(all) do
      if type(name)=="string" and type(entry)=="table" and rawget(entry,"Type")=="Skin" then
        local weapon=rawget(entry,"ItemName");local asset=indexed[name]
        if type(weapon)=="string" and asset then
          if not nextCatalog[weapon] then nextCatalog[weapon]={};nextWeapons[#nextWeapons+1]=weapon end
          local rarity=tostring(rawget(entry,"Rarity") or "Unknown")
          nextCatalog[weapon][#nextCatalog[weapon]+1]={name=name,rarity=rarity,model=asset}
          nextSkinWeapons[name]=weapon
          local image=rawget(entry,"Image")
          if type(image)=="string" and image~="" then nextSkinIcons[name]=image end
        end
      end
    end
    table.sort(nextWeapons)
    for _,entries in pairs(nextCatalog) do table.sort(entries,function(a,b) return a.name<b.name end) end
    catalog,assetsByName,weapons,skinWeapons,skinIcons=nextCatalog,indexed,nextWeapons,nextSkinWeapons,nextSkinIcons
    return #weapons>0
  end
  local function activeRig()
    local view=world:FindFirstChild("ViewModels")
    local first=view and view:FindFirstChild("FirstPerson")
    if not first then return nil end
    local prefix=player.Name.." - "
    for _,v in ipairs(first:GetChildren()) do
      if v:IsA("Model") and v.Name:sub(1,#prefix)==prefix and v:FindFirstChild("ItemVisual") then
        local suffix=v.Name:sub(#prefix+1)
        return v,suffix:match("^(.-) %- ") or suffix
      end
    end
    return nil
  end
  local function anchor(model,group)
    local candidate=group and model:FindFirstChild(group)
    local primary=candidate and (candidate:FindFirstChild(tostring(group).."Primary",true) or candidate:FindFirstChild("Primary",true))
    if primary and primary:IsA("BasePart") then return primary end
    local body=model:FindFirstChild("Body")
    primary=body and (body:FindFirstChild("BodyPrimary",true) or body:FindFirstChild("Primary",true))
    if primary and primary:IsA("BasePart") then return primary end
    return model:FindFirstChildWhichIsA("BasePart",true)
  end
  local function adjustment()
    return CFrame.new(adjustments.x,adjustments.y,adjustments.z)
      *CFrame.Angles(math.rad(adjustments.rx),math.rad(adjustments.ry),math.rad(adjustments.rz))
  end
  local function show(rig,weapon,skin)
    clear()
    local asset=assetsByName[skin]
    local visual=rig and rig:FindFirstChild("ItemVisual")
    if not asset or not visual then return end
    local ok,clone=pcall(function() return asset:Clone() end)
    if not ok or not clone then return end
    clone.Name="NovaX_LocalSkin"
    for _,obj in ipairs(clone:GetDescendants()) do
      if obj:IsA("LuaSourceContainer") or obj:IsA("Sound") or obj:IsA("JointInstance") or obj:IsA("Constraint") then
        obj:Destroy()
      elseif obj:IsA("BasePart") then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false end
    end
    for _,part in ipairs(clone:GetDescendants()) do
      if part:IsA("BasePart") then
        local group=part
        while group.Parent and group.Parent~=clone do group=group.Parent end
        local name=group.Parent==clone and group.Name or nil
        local from=anchor(clone,name);local to=anchor(visual,name)
        if from and to then motion[#motion+1]={part=part,target=to,offset=from.CFrame:ToObjectSpace(part.CFrame)} end
      end
    end
    if #motion==0 then clone:Destroy();return end
    clone.Parent=world.CurrentCamera or world
    for _,part in ipairs(visual:GetDescendants()) do
      if part:IsA("BasePart") then originals[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1 end
    end
    shown=clone;shownRig=rig;shownSkin=skin
  end
  local tab=ui:CreateTab("Skin Changer",4483345998)
  tab:CreateSection("Weapon skins")
  tab:CreateLabel("Choose a weapon and a skin. Only your view changes; ownership is unchanged.")
  loadCatalog()
  local available={};for _,name in ipairs(weapons) do available[#available+1]=name end
  if #available==0 then available={"Catalogue unavailable"} end
  local function refreshSkins()
    labels={};local opts={"Original"};local current="Original"
    for _,entry in ipairs(catalog[selectedWeapon] or {}) do
      local label="["..entry.rarity.."] "..entry.name
      labels[label]=entry.name;opts[#opts+1]=label
      if chosen[selectedWeapon]==entry.name then current=label end
    end
    if skinDropdown then skinDropdown:Refresh(opts);skinDropdown:Set(current) end
  end
  weaponDropdown=tab:CreateDropdown({Name="Weapon",Options=available,CurrentOption={available[1]},Callback=function(v)
    selectedWeapon=type(v)=="table" and tostring(v[1]) or tostring(v);refreshSkins()
    if configToggle and configToggle.Set then configToggle:Set(excluded[selectedWeapon]~=true) end
  end})
  selectedWeapon=available[1]
  local function syncConfig()
    if not configState then return end
    local filtered={}
    for weapon,skin in pairs(chosen) do
      if excluded[weapon]~=true and type(weapon)=="string" and type(skin)=="string" then filtered[weapon]=skin end
    end
    local ok,data=pcall(function() return http:JSONEncode(filtered) end)
    if ok then encoded=data;configState.NovaXSkinSelections=data end
    local filterOk,filterData=pcall(function() return http:JSONEncode(excluded) end)
    if filterOk then filterEncoded=filterData;configState.NovaXSkinConfigFilter=filterData end
  end
  local function chooseSkin(weapon,skin)
    if not weapon or not catalog[weapon] then return end
    if skin and skinWeapons[skin]~=weapon then return end
    chosen[weapon]=skin;syncConfig()
    clear();retryAt=0
    if selectedWeapon==weapon then refreshSkins() end
  end
  env.NovaXChooseSkin=chooseSkin
  skinDropdown=tab:CreateDropdown({Name="Skin",Options={"Original"},CurrentOption={"Original"},Callback=function(v)
    local label=type(v)=="table" and tostring(v[1]) or tostring(v)
    chooseSkin(selectedWeapon,labels[label])
  end})
  refreshSkins()
  configToggle=tab:CreateToggle({Name="Save this weapon in configs",CurrentValue=excluded[selectedWeapon]~=true,Callback=function(value)
    if not catalog[selectedWeapon] then return end
    if value then excluded[selectedWeapon]=nil else excluded[selectedWeapon]=true end
    syncConfig()
  end})
  tab:CreateButton({Name="Refresh skin catalogue",Callback=function()
    if not loadCatalog() then
      if ui.Notify then ui:Notify({Title="Skin Changer",Content="Catalogue not ready yet.",Duration=4}) end
      return
    end
    local exists=catalog[selectedWeapon]~=nil
    if not exists then selectedWeapon=weapons[1] end
    if weaponDropdown and weaponDropdown.Refresh then weaponDropdown:Refresh(weapons);weaponDropdown:Set(selectedWeapon) end
    refreshSkins()
    if configToggle and configToggle.Set then configToggle:Set(excluded[selectedWeapon]~=true) end
  end})
  -- The LOCAL overlay is a separate sibling button. It only updates NovaX's
  -- in-memory/config selection and never calls the game's equip button.
  local function restoreIcons()
    for icon,entry in pairs(iconOriginals) do
      pcall(function() if icon.Parent and icon.Image==entry.assigned then icon.Image=entry.original end end)
      iconOriginals[icon]=nil
    end
  end
  local function updateIcons()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local main=pg and pg:FindFirstChild("MainGui")
    local frame=main and main:FindFirstChild("MainFrame")
    local equipment=frame and frame:FindFirstChild("Equipment")
    if not equipment then restoreIcons();return end
    local desired={}
    local left=equipment:FindFirstChild("Left")
    if left then
      for _,slot in ipairs(left:GetDescendants()) do
        if slot.Name=="EquipmentButtonSlot" then
          local button=slot:FindFirstChild("Button")
          local title=button and button:FindFirstChild("Title")
          local icon=button and button:FindFirstChild("Icon")
          local skin=title and chosen[title.Text]
          if icon and icon:IsA("ImageLabel") and skin and skinIcons[skin] then desired[icon]=skinIcons[skin] end
        end
      end
    end
    local right=equipment:FindFirstChild("Right")
    local details=right and right:FindFirstChild("Details",true)
    local box=details and details:FindFirstChild("Container")
    local title=box and box:FindFirstChild("Title")
    local icon=box and box:FindFirstChild("Icon")
    local skin=title and chosen[title.Text]
    if icon and icon:IsA("ImageLabel") and skin and skinIcons[skin] then desired[icon]=skinIcons[skin] end
    local fighterRoot=frame:FindFirstChild("FighterInterfaces")
    local fighter=fighterRoot and fighterRoot:FindFirstChild(player.Name)
    local bottom=fighter and fighter:FindFirstChild("BottomRight")
    local fighterBox=bottom and bottom:FindFirstChild("Container")
    local hotbar=fighterBox and fighterBox:FindFirstChild("Hotbar")
    local slots=hotbar and hotbar:FindFirstChild("Container")
    if slots then
      for weapon,selected in pairs(chosen) do
        local slot=slots:FindFirstChild(weapon)
        local weaponIcon=slot and slot:FindFirstChild("Icon")
        if weaponIcon and weaponIcon:IsA("ImageLabel") and skinIcons[selected] then desired[weaponIcon]=skinIcons[selected] end
      end
    end
    local equipped=fighterBox and fighterBox:FindFirstChild("EquippedDisplay")
    local equippedBox=equipped and equipped:FindFirstChild("Container")
    local weaponBox=equippedBox and equippedBox:FindFirstChild("Weapon")
    local equippedIcon=weaponBox and weaponBox:FindFirstChild("Icon")
    local _,currentWeapon=activeRig()
    local equippedSkin=currentWeapon and chosen[currentWeapon]
    if equippedIcon and equippedIcon:IsA("ImageLabel") and equippedSkin and skinIcons[equippedSkin] then desired[equippedIcon]=skinIcons[equippedSkin] end
    for old,entry in pairs(iconOriginals) do
      if not desired[old] then
        pcall(function() if old.Parent and old.Image==entry.assigned then old.Image=entry.original end end)
        iconOriginals[old]=nil
      end
    end
    for object,image in pairs(desired) do
      pcall(function()
        local entry=iconOriginals[object]
        if not entry then entry={original=object.Image};iconOriginals[object]=entry
        elseif object.Image~=entry.assigned then entry.original=object.Image end
        object.Image=image;entry.assigned=image
      end)
    end
  end
  local function clearShop()
    for slot,entry in pairs(shopEntries) do
      if entry.overlay then entry.overlay:Destroy() end
      pcall(function()
        if entry.lock and entry.lock.Parent and entry.lock.Visible==false then entry.lock.Visible=entry.lockWas end
        if entry.button and entry.button.Parent and entry.button.Interactable==false then entry.button.Interactable=entry.interactableWas end
        if entry.equipped and entry.equipped.Parent and entry.equipped.Visible==entry.assigned then
          entry.equipped.Visible=entry.equippedWas
        end
      end)
      shopEntries[slot]=nil
    end
  end
  local function shopContainer()
    local pg=player:FindFirstChildOfClass("PlayerGui")
    local main=pg and pg:FindFirstChild("MainGui")
    local frame=main and main:FindFirstChild("MainFrame")
    local equipment=frame and frame:FindFirstChild("Equipment")
    local customize=equipment and equipment:FindFirstChild("Customize")
    local bottom=customize and customize:FindFirstChild("Bottom")
    local box=bottom and bottom:FindFirstChild("Container")
    local list=box and box:FindFirstChild("List")
    return list and list:FindFirstChild("Container")
  end
  local function refreshShop()
    if not shopEnabled then return end
    local container=shopContainer()
    if not container then return end
    local slots=container:GetChildren()
    local currentWeapon
    for _,slot in ipairs(slots) do
      local button=slot:FindFirstChild("Button")
      local title=button and button:FindFirstChild("Title")
      if title and title:IsA("TextLabel") and skinWeapons[title.Text] then currentWeapon=skinWeapons[title.Text];break end
    end
    for _,slot in ipairs(slots) do
      if slot.Name=="CosmeticSlot" and slot:IsA("GuiObject") then
        local button=slot:FindFirstChild("Button")
        local title=button and button:FindFirstChild("Title")
        local name=title and title:IsA("TextLabel") and title.Text or nil
        local weapon=name and (skinWeapons[name] or (name=="None" and currentWeapon))
        local entry=shopEntries[slot]
        if entry and (entry.name~=name or entry.weapon~=weapon or not entry.overlay.Parent) then
          entry.overlay:Destroy()
          if entry.lock and entry.lock.Parent and not entry.lock.Visible then entry.lock.Visible=entry.lockWas end
          if entry.button and entry.button.Parent and entry.button.Interactable==false then entry.button.Interactable=entry.interactableWas end
          if entry.equipped and entry.equipped.Parent and entry.equipped.Visible==entry.assigned then entry.equipped.Visible=entry.equippedWas end
          shopEntries[slot]=nil;entry=nil
        end
        local supported,wasInteractable=pcall(function() return button.Interactable end)
        if weapon and not entry and supported and type(wasInteractable)=="boolean" then
          local overlay=Instance.new("TextButton")
          overlay.Name="NovaX_LocalSkinChoice";overlay.BackgroundTransparency=1;overlay.Text=""
          overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=30;overlay.Active=true;overlay.Parent=slot
          local lock=button:FindFirstChild("Locked");local equipped=button:FindFirstChild("Equipped")
          entry={overlay=overlay,name=name,weapon=weapon,lock=lock,equipped=equipped,button=button,
            interactableWas=wasInteractable,lockWas=lock and lock.Visible or false,equippedWas=equipped and equipped.Visible or false}
          shopEntries[slot]=entry
          overlay.Activated:Connect(function()
            if not shopEnabled or not active then return end
            if name=="None" then chooseSkin(weapon,nil) else chooseSkin(weapon,name) end
          end)
        end
        if entry then
          if entry.button and entry.button.Parent then entry.button.Interactable=false end
          if entry.lock and entry.lock.Parent then entry.lock.Visible=false end
          if entry.equipped and entry.equipped.Parent then
            local isSelected=name=="None" and chosen[weapon]==nil or chosen[weapon]==name
            entry.assigned=isSelected;entry.equipped.Visible=isSelected
          end
        end
      end
    end
    for slot,entry in pairs(shopEntries) do
      if not slot.Parent then if entry.overlay then entry.overlay:Destroy() end;shopEntries[slot]=nil end
    end
  end
  local function setShopEnabled(value,save)
    shopEnabled=value==true
    if save and configState then configState.NovaXShopPreview=shopEnabled end
    if shopEnabled then refreshShop() else clearShop() end
  end
  shopToggle=tab:CreateToggle({Name="Local cosmetic choices (no real unlock)",CurrentValue=shopEnabled,Callback=function(v)
    setShopEnabled(v,true)
  end})
  if shopEnabled then refreshShop() end
  tab:CreateSection("Alignment")
  tab:CreateLabel("Adjust position and rotation; matching sections follow the weapon.")
  for _,item in ipairs({{"Offset X","x",-2,2,0.05},{"Offset Y","y",-2,2,0.05},
    {"Offset Z","z",-2,2,0.05},{"Rotation X","rx",-180,180,5},
    {"Rotation Y","ry",-180,180,5},{"Rotation Z","rz",-180,180,5}}) do
    local key=item[2]
    adjustmentControls[key]=tab:CreateSlider({Name=item[1],Range={item[3],item[4]},Increment=item[5],CurrentValue=adjustments[key],
      Callback=function(value)
        adjustments[key]=tonumber(value) or 0
        if configState then configState[adjustmentKeys[key]]=adjustments[key] end
      end})
  end
  modelControls={ApplyState=function()
    if not configState then return end
    for key,setting in pairs(adjustmentKeys) do
      adjustments[key]=tonumber(configState[setting]) or 0
      local control=adjustmentControls[key]
      if control and control.Set then pcall(function()control:Set(adjustments[key])end) end
    end
  end,Stop=function()
    active=false;for _,c in ipairs(links) do c:Disconnect() end;clearShop();restoreIcons();clear()
  end}
  local configCheckAt,shopCheckAt,iconCheckAt=0,0,0
  links[#links+1]=run.RenderStepped:Connect(function()
    if not active then return end
    local now=os.clock()
    if configState and now>=configCheckAt then
      configCheckAt=now+0.5
      local incoming=configState.NovaXSkinSelections
      local filterIncoming=configState.NovaXSkinConfigFilter
      local desiredShop=configState.NovaXShopPreview
      if type(desiredShop)=="boolean" and desiredShop~=shopEnabled then
        setShopEnabled(desiredShop,false)
        if shopToggle and shopToggle.Set then shopToggle:Set(desiredShop) end
      end
      local changed=false
      if type(incoming)=="string" and incoming~=encoded then
        local ok,data=pcall(function() return http:JSONDecode(incoming) end)
        if ok and type(data)=="table" then chosen=data;encoded=incoming;changed=true end
      end
      if type(filterIncoming)=="string" and filterIncoming~=filterEncoded then
        local ok,data=pcall(function() return http:JSONDecode(filterIncoming) end)
        if ok and type(data)=="table" then excluded=data;filterEncoded=filterIncoming;changed=true end
      end
      if changed then
        clear();retryAt=0;refreshSkins()
        if configToggle and configToggle.Set then configToggle:Set(excluded[selectedWeapon]~=true) end
      end
    end
    if shopEnabled and now>=shopCheckAt then
      shopCheckAt=now+1;pcall(refreshShop)
    end
    if now>=iconCheckAt then iconCheckAt=now+2;pcall(updateIcons) end
    local target,weapon=activeRig();local skin=weapon and chosen[weapon]
    if not skin then if shown then clear() end;return end
    if (target~=shownRig or skin~=shownSkin) and os.clock()>=retryAt then
      retryAt=os.clock()+1;show(target,weapon,skin)
      if shown then retryAt=0 end
    end
    if shown then
      -- The game can rewrite local visibility each frame, including on reload.
      for part in pairs(originals) do
        pcall(function()
          if part.Parent and part.LocalTransparencyModifier<0.999 then
            originals[part]=part.LocalTransparencyModifier
            part.LocalTransparencyModifier=1
          end
        end)
      end
      local offset=adjustment()
      pcall(function() for _,link in ipairs(motion) do
        if link.part.Parent and link.target.Parent then link.part.CFrame=link.target.CFrame*offset*link.offset end
      end end)
    end
  end)
end)
if not okModels then
  if modelControls then pcall(modelControls.Stop);modelControls=nil end
  table.insert(env.NovaXRelease.Errors,"Skin Changer: "..tostring(modelError))
  warn("[NovaX] Skin Changer: "..tostring(modelError))
end
-- Local catalogue previews of all known cosmetic entries (including
-- wraps/charms unavailable to the game's normal owned-only UI).
local cosmeticFactory=execute("modules/cosmetic_preview.lua",false)
local cosmeticModule=nil
if type(cosmeticFactory)=="function" then
  local ok,result=pcall(cosmeticFactory,env)
  if ok and type(result)=="table" then cosmeticModule=result
  else
    local message="Cosmetic Preview: "..tostring(result)
    table.insert(env.NovaXRelease.Errors,message)
    warn("[NovaX] "..message)
  end
end
-- Called after the original Config Manager loads a profile. All extension
-- modules then synchronize their runtime and visible controls from NX_STATE.
env.NX_CONFIG_APPLY=function()
  if controlsModule and controlsModule.ApplyState then pcall(controlsModule.ApplyState) end
  if dropsModule and dropsModule.ApplyState then pcall(dropsModule.ApplyState) end
  if modelControls and modelControls.ApplyState then pcall(modelControls.ApplyState) end
  if cosmeticModule and cosmeticModule.ApplyState then pcall(cosmeticModule.ApplyState) end
  if type(visualModule)=="table" and visualModule.ApplyState then pcall(visualModule.ApplyState) end
  if type(env.NovaXWeatherControls)=="table" and env.NovaXWeatherControls.ApplyState then
    pcall(env.NovaXWeatherControls.ApplyState)
  end
end
env.NX_CLEANUP=function()
  if modelControls then pcall(modelControls.Stop) end
  if cosmeticModule and cosmeticModule.Stop then pcall(cosmeticModule.Stop) end
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

