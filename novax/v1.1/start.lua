-- NovaX v1.1 RELEASE LOADER
-- Developers: Klaus (Dev), Nexus (Bug Fixer)
-- Loads original 7466-line template as UI + main core, plus optional
-- 90Hz weather, compatibility checker and integrated Weather/Diagnostics tabs.
local REV="2df577a270a78151c9afa2f7b7b9340e45a38f4d"
local VISUAL_REV="a4993fedeb256f7f1c1919a5a64806b6d05a3bea"
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
  local includeShared=true
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
  tab:CreateToggle({Name="Include shared shot sounds (may mute other effects)",CurrentValue=true,
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
  local http=game:GetService("HttpService")
  local encoded="{}"
  if configState then
    if type(configState.NovaXSkinSelections)~="string" then configState.NovaXSkinSelections="{}" end
    encoded=configState.NovaXSkinSelections
    local ok,data=pcall(function() return http:JSONDecode(encoded) end)
    if ok and type(data)=="table" then chosen=data end
  end
  local catalog,assetsByName,weapons={}, {}, {}
  local selectedWeapon,skinDropdown,weaponDropdown="",nil,nil
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
    if not models or not library or type(getloadedmodules)~="function" then return false end
    local ready=false
    local ok,loaded=pcall(getloadedmodules)
    if ok and type(loaded)=="table" then for _,v in ipairs(loaded) do if v==library then ready=true;break end end end
    if not ready then return false end
    local success,lib=pcall(require,library)
    local all=success and type(lib)=="table" and rawget(lib,"Cosmetics")
    if type(all)~="table" then return false end
    local indexed={}
    for _,folder in ipairs(models:GetChildren()) do
      for _,model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and not indexed[model.Name] then indexed[model.Name]=model end
      end
    end
    local nextCatalog,nextWeapons={},{}
    for name,entry in pairs(all) do
      if type(name)=="string" and type(entry)=="table" and rawget(entry,"Type")=="Skin" then
        local weapon=rawget(entry,"ItemName");local asset=indexed[name]
        if type(weapon)=="string" and asset then
          if not nextCatalog[weapon] then nextCatalog[weapon]={};nextWeapons[#nextWeapons+1]=weapon end
          local rarity=tostring(rawget(entry,"Rarity") or "Unknown")
          nextCatalog[weapon][#nextCatalog[weapon]+1]={name=name,rarity=rarity,model=asset}
        end
      end
    end
    table.sort(nextWeapons)
    for _,entries in pairs(nextCatalog) do table.sort(entries,function(a,b) return a.name<b.name end) end
    catalog,assetsByName,weapons=nextCatalog,indexed,nextWeapons
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
  tab:CreateSection("Local weapon skins")
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
  end})
  selectedWeapon=available[1]
  skinDropdown=tab:CreateDropdown({Name="Skin",Options={"Original"},CurrentOption={"Original"},Callback=function(v)
    local label=type(v)=="table" and tostring(v[1]) or tostring(v)
    chosen[selectedWeapon]=labels[label]
    if configState then
      local ok,data=pcall(function() return http:JSONEncode(chosen) end)
      if ok then encoded=data;configState.NovaXSkinSelections=data end
    end
    clear();retryAt=0
  end})
  refreshSkins()
  tab:CreateButton({Name="Refresh skin catalogue",Callback=function()
    if not loadCatalog() then
      if ui.Notify then ui:Notify({Title="Skin Changer",Content="Catalogue not ready yet.",Duration=4}) end
      return
    end
    local exists=catalog[selectedWeapon]~=nil
    if not exists then selectedWeapon=weapons[1] end
    if weaponDropdown and weaponDropdown.Refresh then weaponDropdown:Refresh(weapons);weaponDropdown:Set(selectedWeapon) end
    refreshSkins()
  end})
  tab:CreateSection("Alignment")
  tab:CreateLabel("Offsets apply locally; matching moving sections follow the weapon.")
  for _,item in ipairs({{"Offset X","x",-2,2,0.05},{"Offset Y","y",-2,2,0.05},
    {"Offset Z","z",-2,2,0.05},{"Rotation X","rx",-180,180,5},
    {"Rotation Y","ry",-180,180,5},{"Rotation Z","rz",-180,180,5}}) do
    local key=item[2]
    tab:CreateSlider({Name=item[1],Range={item[3],item[4]},Increment=item[5],CurrentValue=0,
      Callback=function(value) adjustments[key]=tonumber(value) or 0 end})
  end
  modelControls={Stop=function()
    active=false;for _,c in ipairs(links) do c:Disconnect() end;clear()
  end}
  local configCheckAt=0
  links[#links+1]=run.RenderStepped:Connect(function()
    if not active then return end
    local now=os.clock()
    if configState and now>=configCheckAt then
      configCheckAt=now+0.5
      local incoming=configState.NovaXSkinSelections
      if type(incoming)=="string" and incoming~=encoded then
        local ok,data=pcall(function() return http:JSONDecode(incoming) end)
        if ok and type(data)=="table" then
          chosen=data;encoded=incoming;clear();retryAt=0;refreshSkins()
        end
      end
    end
    local target,weapon=activeRig();local skin=weapon and chosen[weapon]
    if not skin then if shown then clear() end;return end
    if (target~=shownRig or skin~=shownSkin) and os.clock()>=retryAt then
      retryAt=os.clock()+1;show(target,weapon,skin)
      if shown then retryAt=0 end
    end
    if shown then
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

