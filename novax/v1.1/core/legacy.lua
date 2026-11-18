-- NovaX original core from user's uploaded template
local NovaPremiumUI=((getgenv and getgenv()) or _G).NovaPremiumUI
-- =============== NOVAX MAIN SCRIPT ===============

-- XENO EXECUTOR CHECK
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(0.2)

local NX_DEBUG = true
local NX_SHOW_NOTIFICATIONS = true
function nxWarn(...)
  if NX_DEBUG then
    warn(...)
  end
end
local cleanup
local cleanAllESP = function() end
local clearAimTargetHighlight = function() end
local restoreDeviceSpoof = function() end
local applyDeviceSpoof = function() return false end
local restoreSoftSpoof = function() end
local applySoftSpoof = function() return true end
local applyReplicationControlSpoof = function() return false end
local restoreAntiHitPose = function() end
local restoreAntiHitMovement = function() end
local restoreHeadGuardOrbit = function() end
local aimTarget
local aimLockedPlayer
local aimLockLostSince
local autoAimTarget
local autoAimLockedPlayer
local autoAimSmoothedPos
local autoAimLastPart
local autoAimLastRawPos
local autoAimVelocity
local autoAimLostSince
local autoAimReleaseUntil
local autoAimManualBreakUntil
local autoAimBreakScore
local autoAimMixedUseHead
local autoAimMixedNextSwitch
local autoAimMixedBlend
local rageTarget
local rageLockedPlayer
local rageNextShotAt
local rageMixedUseHead
local rageMixedNextSwitch
local rageMixedBlend
local restoreRageWeaponLock = function() end
local lockEquippedToolToPosition = function() return false end
local mouseStepState
local injectedMouseDelta
local injectedMouseAt
local controlSpoofRemote
local lastControlSpoofMode
local lastControlSpoofAt
local antiVoidNextAt
local setFB, setNF, setFPS, setFPSBoost, setupGrabber
local UI_WINDOW = nil

if getgenv then
  local gv = getgenv()
  gv.NX_XENO_LOADING = nil
  gv.NX_XENO = true
  gv.NX_CLEANUP = function()
    if cleanup then cleanup() end
  end
end

math.randomseed(tick() * 1000)

--  SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = nil
pcall(function()
  VirtualInputManager = game:GetService("VirtualInputManager")
end)
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local SUPPORT = {
  MetaHook = typeof(hookmetamethod) == "function" and typeof(newcclosure) == "function" and typeof(getnamecallmethod) == "function" and typeof(checkcaller) == "function",
  HookFunction = (hookfunction ~= nil),
  GetConnections = (getconnections ~= nil),
  Debug = (debug and debug.getupvalue ~= nil),
}

-- Character/HRP werden lazy abgefragt. Die GUI darf dadurch nie blockieren.

local V3, CF = Vector3.new, CFrame.new
local clamp, floor, huge = math.clamp, math.floor, math.huge
local V0, UP = Vector3.zero, V3(0, 1, 0)
local MF = V3(1, 1, 1) * 9e4

--  XENO-SAFE FUNCTIONS

function safeNum(v)
  if v == nil then return 0 end
  return tonumber(v) or 0
end

function notify(title, msg, dur)
  if not NX_SHOW_NOTIFICATIONS then
    return false
  end
  local duration = tonumber(dur)
  if not duration or duration <= 0 then
    duration = 6
  elseif duration < 5 then
    duration = 5
  end
  
  task.spawn(function()
    pcall(function()
      StarterGui:SetCore("SendNotification", {
        Title = tostring(title),
        Text = tostring(msg),
        Duration = duration
      })
    end)
  end)
end

local lastLeftClickAt, lastRightClickAt = 0, 0
local MAX_TRIGGER_CPS = 30 -- guard against 500 Hz input spam
local MIN_SHOT_INTERVAL = 1 / MAX_TRIGGER_CPS
local MIN_RIGHT_CLICK_INTERVAL = 0.25

function activateEquippedTool()
  local char = LocalPlayer and LocalPlayer.Character
  local tool = char and char:FindFirstChildOfClass("Tool")
  if not tool then
    return false
  end
  return pcall(function()
    tool:Activate()
  end)
end

function sendMouseButton(button, interval)
  local now = tick()
  if button == 0 then
    if now - lastLeftClickAt < interval then
      return false
    end
    lastLeftClickAt = now
  else
    if now - lastRightClickAt < interval then
      return false
    end
    lastRightClickAt = now
  end

  if not VirtualInputManager or typeof(VirtualInputManager.SendMouseButtonEvent) ~= "function" then
    return button == 0 and activateEquippedTool() or false
  end

  local x, y = 0, 0
  pcall(function()
    local pos = UserInputService:GetMouseLocation()
    x, y = pos.X, pos.Y
  end)

  local ok = pcall(function()
    VirtualInputManager:SendMouseButtonEvent(x, y, button, true, game, 0)
    task.wait(math.clamp((tonumber(interval) or MIN_SHOT_INTERVAL) * 0.35, 0.001, 0.01))
    VirtualInputManager:SendMouseButtonEvent(x, y, button, false, game, 0)
  end)
  if ok then
    return true
  end
  return button == 0 and activateEquippedTool() or false
end

function click(interval)
  return sendMouseButton(0, interval or MIN_SHOT_INTERVAL)
end

function safeHook(setupFunc, featureName)
  if not setupFunc then return false end
  
  local ok, result = pcall(setupFunc)
  if not ok then
    nxWarn("[NovaX] " .. tostring(featureName) .. " failed -> disabled")
    return false
  end
  
  if result == false then
    nxWarn("[NovaX] " .. tostring(featureName) .. " not supported -> skipped")
    return false
  end
  
  return true
end

--  CONTROL
local RUNNING = true
local CONNECTIONS = {}

function addConnection(name, conn)
  if not conn then return end
  if CONNECTIONS[name] then
    pcall(function() CONNECTIONS[name]:Disconnect() end)
  end
  CONNECTIONS[name] = conn
end

addConnection("camera", workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
  while RUNNING and not workspace.CurrentCamera do
    task.wait()
  end
  Camera = workspace.CurrentCamera
end))

cleanup = function()
  RUNNING = false
  aimTarget = nil
  aimLockedPlayer = nil
  aimLockLostSince = 0
  autoAimTarget = nil
  autoAimLockedPlayer = nil
  autoAimSmoothedPos = nil
  autoAimLastPart = nil
  autoAimLastRawPos = nil
  autoAimVelocity = Vector3.zero
  autoAimLostSince = 0
  autoAimReleaseUntil = 0
  autoAimManualBreakUntil = 0
  autoAimBreakScore = 0
  autoAimMixedUseHead = true
  autoAimMixedNextSwitch = 0
  autoAimMixedBlend = 0
  rageTarget = nil
  rageLockedPlayer = nil
  rageNextShotAt = 0
  restoreRageWeaponLock()
  rageMixedUseHead = true
  rageMixedNextSwitch = 0
  rageMixedBlend = 0
  pcall(function()
    if mouseStepState then
      mouseStepState.auto = Vector2.new(0, 0)
      mouseStepState.lock = Vector2.new(0, 0)
    end
    injectedMouseDelta = Vector2.new(0, 0)
    injectedMouseAt = 0
    controlSpoofRemote = nil
    lastControlSpoofMode = "MouseKeyboard"
    lastControlSpoofAt = 0
    antiVoidNextAt = 0
  end)
  pcall(function()
    local g=(getgenv and getgenv()) or _G
    local hook=g.NX_INTERNAL_RAY_HOOK
    if type(hook)=="table" then hook.enabled=false;hook.target=nil end
  end)
  pcall(cleanAllESP)
  pcall(clearAimTargetHighlight)
  pcall(restoreDeviceSpoof)
  pcall(function()
    if setFB then setFB(false) end
  end)
  pcall(function()
    if setNF then setNF(false) end
  end)
  pcall(function()
    if setFPS then setFPS(false) end
  end)
  pcall(function()
    if setFPSBoost then setFPSBoost(false) end
  end)
  pcall(restoreAntiHitPose)
  pcall(restoreHeadGuardOrbit)
  pcall(restoreAntiHitMovement)
  pcall(function()
    if getgenv then getgenv().NX_UI_WINDOW=nil end
    if UI_WINDOW and UI_WINDOW.Destroy then
      UI_WINDOW:Destroy()
    end
    UI_WINDOW = nil
  end)
  for _, conn in pairs(CONNECTIONS) do
    pcall(function() conn:Disconnect() end)
  end
  CONNECTIONS = {}
  
  pcall(function()
    if getgenv then
      local gv = getgenv()
      if gv.NX_FOV then
        pcall(function() gv.NX_FOV:Remove() end)
        gv.NX_FOV = nil
      end
      if gv.NX_FOV_GUI then
        pcall(function() gv.NX_FOV_GUI:Destroy() end)
        gv.NX_FOV_GUI = nil
      end
      gv.NX_STATE = nil
      gv.NX_HOOKED = nil
      gv.NX_XENO_LOADING = nil
      gv.NX_XENO = nil
      gv.NX_CLEANUP = nil
      gv.NX_AUTOCONFIG = nil
      gv.NX_CONFIG_APPLY = nil
    end
  end)
end

if getgenv then
  getgenv().NX_CLEANUP = cleanup
end

--  STATE
local STATE = {
  AimLock = false,
  AimLockPart = "Head",
  AimLockStrength = 100,
  SilentAim = false,
  SilentAimMode = "Snap",
  SilentVisibleCheck = true,
  SilentTargetPart = "Head",
  SilentHitChance = 100,
  SilentHookTargetPart = "Head",
  SilentHookHitChance = 100,
  NoHookMode = "ULTRA",
  AutoAim = false,
  RageBot = false,
  RageTargetPart = "Head",
  RageVisibilityCheck = false,
  RageLockStrength = 100,
  RageAutoShoot = false,
  RageRequireADS = false,
  RageCPS = 8,
  RageShootFOV = 7,
  AimFOV = 150,
  AimMaxDist = 300,
  AutoAimStrengthADS = 100,
  AutoAimStrengthHip = 100,
  AutoAimTargetPart = "Head",
  AutoAimVisibleCheck = false,
  AimTeamCheck = true,
  AimFOVCircle = true,
  AimFOVHidden = false,
  AimFOVColor = "White",
  AimRequireCenter = false,
  AimMouseAssist = true,
  AimMouseAssistStrength = 100,
  AimLockRequireRMB = false,
  AutoAimRequireRMB = false,
  
  TriggerEnabled = false,
  TriggerDelay = 0,
  TriggerCPS = 8,
  TriggerTarget = "Head",
  TriggerTeamCheck = true,
  TriggerRequireCenter = false,
  TriggerVisibleCheck = true,
  
  HitboxExpander = false,
  HitboxSize = 10,
  
  ESPEnabled = false,
  ESPTeam = false,
  ESPEnemy = true,
  ESPName = true,
  ESPHealth = true,
  ESPDistance = true,
  ESPBox = true,
  ESPSkeleton = false,
  ESPBoxScale = 40,
  ESPMaxDistance = 500,
  
  SpeedEnabled = false,
  SpeedValue = 40,
  FlyEnabled = false,
  FlySpeed = 50,
  FlyToggle = false,
  InfJump = false,
  InfJumpHeight = 36,
  NoClip = false,
  BunnyHop = false,
  
  NoSpread = false,
  Wallbang = false,
  -- Shared config settings for modules loaded AFTER this core.
  NovaXFastFire = false,
  NovaXFastFireMultiplier = 4,
  NovaXNoShootSound = false,
  NovaXSharedShotSounds = true,
  NovaXWeaponEffectSounds = true,
  NovaXShotVolume = 100,
  NovaXAutoHeal = false,
  NovaXAutoAmmo = false,
  NovaXAutoDropRemote = true,
  NovaXAutoDropNavigate = false,
  NovaXWeatherMode = "OFF",
  NovaXWeatherRain = 55,
  NovaXWeatherSnow = 65,
  NovaXWeatherQuality = "BALANCED",
  NovaXWeatherAdaptive = true,
  NovaXWeatherSnowFX = true,
  NovaXWeatherRainFX = true,
  NovaXWeatherWetFloor = true,
  NovaXWeatherCameraWet = true,
  NovaXWeatherSound = true,
  NovaXWeatherStorm = false,
  NovaXWorldEnabled = false,
  NovaXWorldSaturation = 0,
  NovaXWorldContrast = 0,
  NovaXWorldTint = "Neutral",
  NovaXWorldBloom = false,
  NovaXWorldBloomIntensity = 30,
  NovaXWorldRays = false,
  NovaXWorldRaysStrength = 10,
  NovaXWorldDepth = false,
  NovaXWorldDepthFocus = 50,
  NovaXWorldDepthBlur = 15,
  NovaXWorldPerformance = false,
  NovaXWorldBrightnessEnabled = false,
  NovaXWorldBrightness = 2,
  NovaXWorldExposure = 0,
  NovaXWorldFogEnabled = false,
  NovaXWorldFogEnd = 1000,
  NovaXWorldAmbientEnabled = false,
  NovaXWorldAmbient = 128,
  NovaXWorldShadowsEnabled = false,
  NovaXWorldShadows = true,
  NovaXWorldClockEnabled = false,
  NovaXWorldClock = 14,
  NovaXWorldFovEnabled = false,
  NovaXWorldFov = 70,
  
  FullBright = false,
  NoFog = false,
  FPSUnlocker = true,
  FPSBoost = false,
  MobileSpoof = false,
  ConsoleSpoof = false,
  VRSpoof = false,
  SoftMobileSpoof = false,
  SoftConsoleSpoof = false,
  SoftVRSpoof = false,
  
  TPPlayer = "",
  TPDistance = 4,
  AutoBackstab = false,
  AutoBackstabInterval = 180,
  AutoBackstabRandomize = true,
  AutoBackstabRandomMin = 90,
  AutoBackstabRandomMax = 260,
  
  BeggerFarm = false,
  AntiHit = false,
  AntiHitMode = "Adaptive Jitter",
  AntiHitSpeed = 2.2,
  AntiHitExperimental = false,
  AntiHitGuardDodge = true,
  AntiHitOrbitRadius = 2.5,
  AntiVoid = true,
  
  BindToggleGUI = "K",
  BindFly = "X",
  BindAimLock = "None",
  BindAutoAim = "None",
  BindRageBot = "None",
  BindTrigger = "None",
  BindESP = "None",
  BindBeggerFarm = "None",
  BindAutoBackstab = "None",
  BindApplyControlMode = "None",
  
  AimMouseAssistSmooth = 1,
}

if getgenv then
  getgenv().NX_STATE = STATE
end

local BIND_KEYS = {
  "BindToggleGUI",
  "BindFly",
  "BindAimLock",
  "BindAutoAim",
  "BindRageBot",
  "BindTrigger",
  "BindESP",
  "BindBeggerFarm",
  "BindAutoBackstab",
  "BindApplyControlMode",
}

function normalizeSingleLetterBind(value)
  local raw = tostring(value or "None")
  if raw == "" or raw == "None" then
    return "None"
  end
  local first = raw:match("^[A-Za-z]")
  return first and first:upper() or "None"
end

function normalizeAllBinds()
  for _, key in ipairs(BIND_KEYS) do
    STATE[key] = normalizeSingleLetterBind(STATE[key])
  end
end

local CONFIG_FOLDER = "NovaXConfigs"

function ensureConfigFolder()
  if typeof(makefolder) == "function" and typeof(isfolder) == "function" then
    if not isfolder(CONFIG_FOLDER) then
      pcall(function()
        makefolder(CONFIG_FOLDER)
      end)
    end
  end
end

function sanitizeConfigName(name)
  local raw = tostring(name or "default")
  local clean = raw:gsub("[^%w_%-%s]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_")
  if clean == "" then
    clean = "default"
  end
  return clean
end

function getConfigPath(name)
  local clean = sanitizeConfigName(name)
  return string.format("%s/%s.json", CONFIG_FOLDER, clean), clean
end

function snapshotState()
  local data = {}
  for k, v in pairs(STATE) do
    local t = type(v)
    if t == "boolean" or t == "number" or t == "string" then
      data[k] = v
    end
  end
  return data
end

function saveConfig(name)
  ensureConfigFolder()
  if typeof(writefile) ~= "function" then
    return false, "writefile nicht verfuegbar"
  end
  
  local path, clean = getConfigPath(name)
  local payload = snapshotState()
  local ok, err = pcall(function()
    writefile(path, HttpService:JSONEncode(payload))
  end)
  if not ok then
    return false, tostring(err)
  end
  return true, clean
end

function loadConfig(name)
  ensureConfigFolder()
  if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then
    return false, "readfile/isfile nicht verfuegbar"
  end
  
  local path, clean = getConfigPath(name)
  if not isfile(path) then
    return false, "Config nicht gefunden"
  end
  
  local ok, parsed = pcall(function()
    return HttpService:JSONDecode(readfile(path))
  end)
  if not ok or type(parsed) ~= "table" then
    return false, "Config konnte nicht gelesen werden"
  end
  
  for k, v in pairs(parsed) do
    if STATE[k] ~= nil and type(STATE[k]) == type(v) then
      STATE[k] = v
    end
  end
  
  -- Configs sollen keine Features zwangsweise blockieren. Nur No-Hook bleibt auf ULTRA normalisiert.
  STATE.NoHookMode = "ULTRA"
  STATE.AimTeamCheck = true
  STATE.AimRequireCenter = false
  STATE.TriggerTeamCheck = true
  STATE.TriggerRequireCenter = false
  STATE.TriggerVisibleCheck = true
  STATE.RageVisibilityCheck = false
  STATE.FPSUnlocker = true
  STATE.InfJumpHeight = math.clamp(safeNum(STATE.InfJumpHeight), 28, 80)
  STATE.AimLockStrength = math.clamp(safeNum(STATE.AimLockStrength), 1, 100)
  STATE.AimMouseAssistStrength = math.clamp(safeNum(STATE.AimMouseAssistStrength), 5, 100)
  STATE.RageCPS = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(STATE.RageCPS)))
  STATE.TriggerCPS = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(STATE.TriggerCPS)))
  normalizeAllBinds()
  if STATE.VRSpoof then
    STATE.MobileSpoof = false
    STATE.ConsoleSpoof = false
  elseif STATE.ConsoleSpoof then
    STATE.MobileSpoof = false
  end
  if tostring(STATE.AntiHitMode) == "Anti Spin" then
    STATE.AntiHitMode = "Adaptive Jitter"
  end
  
  return true, clean
end

function deleteConfig(name)
  ensureConfigFolder()
  if typeof(delfile) ~= "function" then
    return false, "delfile nicht verfuegbar"
  end
  local path, clean = getConfigPath(name)
  if typeof(isfile) == "function" and not isfile(path) then
    return true, clean
  end
  local ok, err = pcall(function()
    delfile(path)
  end)
  if not ok then
    return false, tostring(err)
  end
  return true, clean
end

function renameConfig(oldName, newName)
  ensureConfigFolder()
  if typeof(readfile) ~= "function" or typeof(writefile) ~= "function" then
    return false, "readfile/writefile nicht verfuegbar"
  end
  local oldPath, oldClean = getConfigPath(oldName)
  local newPath, newClean = getConfigPath(newName)
  if oldClean == newClean then
    return true, newClean
  end
  if typeof(isfile) == "function" and not isfile(oldPath) then
    return false, "Config nicht gefunden"
  end
  if typeof(isfile) == "function" and isfile(newPath) then
    return false, "Config Name existiert schon"
  end
  local okRead, data = pcall(function()
    return readfile(oldPath)
  end)
  if not okRead then
    return false, tostring(data)
  end
  local okWrite, writeErr = pcall(function()
    writefile(newPath, data)
  end)
  if not okWrite then
    return false, tostring(writeErr)
  end
  if typeof(delfile) == "function" then
    pcall(function()
      delfile(oldPath)
    end)
  end
  return true, newClean
end

function listConfigNames()
  ensureConfigFolder()
  local names = {}
  if typeof(listfiles) ~= "function" or typeof(isfolder) ~= "function" or not isfolder(CONFIG_FOLDER) then
    return names
  end
  
  local ok, files = pcall(function()
    return listfiles(CONFIG_FOLDER)
  end)
  if not ok or type(files) ~= "table" then
    return names
  end
  
  for index = 1, #files do
    local f = files[index]
    local s = tostring(f)
    local name = s:match("([^/\\]+)%.json$")
    if name and name ~= "" then
      table.insert(names, name)
    end
  end
  table.sort(names)
  return names
end

ensureConfigFolder()

-- Track the selected config separately from normal *.json config files.
-- Never overwrite a user's saved config during startup.
local AUTO_CONFIG_FILE = CONFIG_FOLDER.."/NovaX_last_profile.txt"
local autoConfigName=nil
local autoConfigStatus="No saved config found"
local function rememberAutoConfig(name)
  local clean=sanitizeConfigName(name)
  autoConfigName=clean
  if type(writefile)=="function" then
    local ok,err=pcall(function()
      ensureConfigFolder()
      writefile(AUTO_CONFIG_FILE,clean)
    end)
    if not ok then
      warn("[NovaX Config] Cannot remember auto-load selection: "..tostring(err))
    end
  end
end
local function clearAutoConfig()
  autoConfigName=nil
  if type(delfile)=="function" and type(isfile)=="function" then
    pcall(function() if isfile(AUTO_CONFIG_FILE) then delfile(AUTO_CONFIG_FILE) end end)
  end
end
local function bootAutoConfig()
  if type(readfile)~="function" or type(isfile)~="function" then
    autoConfigStatus="Executor has no readfile/isfile; auto-load unavailable"
    return
  end
  local preferred
  local ok,remembered=pcall(function()
    return isfile(AUTO_CONFIG_FILE) and readfile(AUTO_CONFIG_FILE) or nil
  end)
  if ok and type(remembered)=="string" and remembered~="" then
    preferred=sanitizeConfigName(remembered)
  end
  local options={}
  if preferred then options[#options+1]=preferred end
  options[#options+1]="default"
  local names=listConfigNames()
  for _,name in ipairs(names) do options[#options+1]=name end
  local checked={}
  for _,name in ipairs(options) do
    local candidate=sanitizeConfigName(name)
    if not checked[candidate] then
      checked[candidate]=true
      local path=getConfigPath(candidate)
      local exists,hasFile=pcall(isfile,path)
      if exists and hasFile then
        local loaded,message=loadConfig(candidate)
        if loaded then
          autoConfigName=candidate
          autoConfigStatus="Auto-loaded: "..candidate
          print("[NovaX Config] "..autoConfigStatus)
          return
        end
        warn("[NovaX Config] "..candidate..": "..tostring(message))
      end
    end
  end
  autoConfigStatus="No readable saved config found"
end
bootAutoConfig()
local configGlobal=(getgenv and getgenv()) or _G
configGlobal.NX_AUTOCONFIG={
  Status=function() return autoConfigStatus end,
  Selected=function() return autoConfigName end,
  Set=function(name) rememberAutoConfig(name);autoConfigStatus="Selected: "..autoConfigName end,
  Clear=clearAutoConfig,
}

if not SUPPORT.MetaHook and tostring(STATE.SilentAimMode or "No Hook") == "Hook" then
  nxWarn("[NovaX] Meta-Hook fehlt: Silent/Wallbang kann je nach Executor ohne Wirkung bleiben")
end

--  GAME HELPERS (XENO-SAFE!)
function getChar()
  if not LocalPlayer then return nil end
  return LocalPlayer.Character
end

function getRoot()
  local char = getChar()
  if not char then return nil end
  -- WICHTIG: FindFirstChild statt WaitForChild!
  return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

function getHumanoid()
  local char = getChar()
  if not char then return nil end
  return char:FindFirstChildOfClass("Humanoid")
end

function getTool()
  local char = getChar()
  if not char then return nil end
  return char:FindFirstChildOfClass("Tool")
end

local function normalizeWeaponName(value)
  local name = string.lower(tostring(value or ""))
  name = name:gsub("[_%-%[%]%(%)]+", " ")
  name = name:gsub("%s+", " ")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  return name
end

function isAssaultRifleEquipped()
  local tool = getTool()
  if not tool then
    return false
  end

  local name = normalizeWeaponName(tool.Name)
  if name == "ar" or name == "assault" or name == "assault rifle" then
    return true
  end

  if name:find("assault", 1, true) and not name:find("sniper", 1, true) then
    return true
  end

  if name:match("^ar%d+") then
    return true
  end

  return (" " .. name .. " "):find(" ar ", 1, true) ~= nil
end

function getARSightCenterOffset()
  if not Camera or not isAssaultRifleEquipped() then
    return Vector2.new(0, 0), false
  end
  if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
    return Vector2.new(0, 0), false
  end

  local side = 0
  local hum = getHumanoid()
  if hum and hum.MoveDirection and hum.MoveDirection.Magnitude > 0.04 then
    side = hum.MoveDirection:Dot(Camera.CFrame.RightVector)
  end

  if math.abs(side) < 0.05 then
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then side = side - 1 end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then side = side + 1 end
  end

  side = math.clamp(side, -1, 1)
  if math.abs(side) < 0.05 then
    return Vector2.new(0, 0), false
  end

  local root = getRoot()
  local lateralSpeed = 16
  if root and root.AssemblyLinearVelocity then
    local vel = root.AssemblyLinearVelocity
    lateralSpeed = math.abs(vel:Dot(Camera.CFrame.RightVector))
  elseif hum then
    lateralSpeed = safeNum(hum.WalkSpeed)
  end

  local amount = math.clamp(2.25 + lateralSpeed * 0.22, 2.25, 8.75)
  return Vector2.new(-side * amount, 0), true
end

function getAimScreenCenter()
  if not Camera then
    return Vector2.new(0, 0), false
  end

  local center = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
  local offset, active = getARSightCenterOffset()
  return center + offset, active, offset
end

function getCharacterRoot(char)
  if not char then return nil end
  return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

function getPlayerRoot(player)
  if not player or not player.Character then return nil end
  return getCharacterRoot(player.Character)
end

function getPreferredPartFromPlayer(player, mode)
  if not player then return nil end
  local char = player.Character
  if not char then return nil end
  
  local head = char:FindFirstChild("Head")
  local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
  local root = char:FindFirstChild("HumanoidRootPart") or torso
  local selected = tostring(mode or "Head")
  
  if selected == "Torso" or selected == "UpperTorso" then
    return torso or root or head
  end
  
  if selected == "HumanoidRootPart" or selected == "Root" then
    return root or torso or head
  end
  
  return head or torso or root
end

local rageWeaponGrips = setmetatable({}, {__mode = "k"})

restoreRageWeaponLock = function()
  for tool, originalGrip in pairs(rageWeaponGrips) do
    if tool and tool.Parent and originalGrip then
      pcall(function()
        tool.Grip = originalGrip
      end)
    end
  end
  rageWeaponGrips = setmetatable({}, {__mode = "k"})
end

lockEquippedToolToPosition = function(targetPos, strength)
  local tool = getTool()
  if not tool or typeof(targetPos) ~= "Vector3" then
    return false
  end
  
  local root = getRoot()
  local handle = tool:FindFirstChild("Handle")
  local refCF = root and root.CFrame or (handle and handle.CFrame)
  local origin = handle and handle.Position or (root and root.Position)
  if not refCF or not origin then
    return false
  end
  
  local dir = targetPos - origin
  if dir.Magnitude < 0.05 then
    return false
  end
  
  local applied = false
  local ok = pcall(function()
    if rageWeaponGrips[tool] == nil then
      rageWeaponGrips[tool] = tool.Grip
    end
    
    local originalGrip = rageWeaponGrips[tool]
    local localDir = refCF:VectorToObjectSpace(dir.Unit)
    if localDir.Magnitude < 0.05 then
      return
    end
    
    local targetGrip = CFrame.lookAt(originalGrip.Position, originalGrip.Position + localDir.Unit, UP)
    local alpha = math.clamp(0.22 + (math.clamp(safeNum(strength), 0, 1) * 0.78), 0.22, 1)
    tool.Grip = originalGrip:Lerp(targetGrip, alpha)
    applied = true
  end)
  
  return ok and applied
end

local teamResolverCache = {
  checkedAt = 0,
  mode = "none",
  key = nil,
  getter = nil,
  printed = false,
}

local TEAM_KEYWORDS = {"team", "faction", "side", "squad", "alliance", "allegiance", "camp", "clan"}
local STATIC_TEAM_KEYS = {"Team", "TeamId", "TeamID", "TeamIndex", "TeamName", "Faction", "Side", "Squad", "Alliance", "Allegiance", "Camp", "Clan"}

function nameLooksTeamLike(name)
  local lower = string.lower(tostring(name or ""))
  if lower == "" then
    return false
  end
  for _, kw in ipairs(TEAM_KEYWORDS) do
    if string.find(lower, kw, 1, true) then
      return true
    end
  end
  return false
end

function normalizeTeamToken(value)
  if value == nil then
    return nil
  end
  
  local t = typeof(value)
  if t == "string" then
    local s = string.lower(tostring(value)):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" or s == "none" or s == "nil" or s == "neutral" or s == "unknown" then
      return nil
    end
    return s
  end
  
  if t == "number" then
    if value == 0 then
      return nil
    end
    return string.format("%.3f", value)
  end
  
  if t == "boolean" then
    return value and "true" or "false"
  end
  
  if t == "BrickColor" or t == "Color3" then
    return tostring(value)
  end
  
  if t == "Instance" then
    return tostring(value:GetFullName())
  end
  
  return tostring(value)
end

function collectTeamStats(tokenGetter)
  local tokenCounts = {}
  local covered = 0
  local localToken = nil
  
  for _, p in ipairs(Players:GetPlayers()) do
    local token = tokenGetter(p)
    if token then
      covered = covered + 1
      tokenCounts[token] = (tokenCounts[token] or 0) + 1
      if p == LocalPlayer then
        localToken = token
      end
    end
  end
  
  local uniqueCount = 0
  local maxCount = 0
  for _, count in pairs(tokenCounts) do
    uniqueCount = uniqueCount + 1
    if count > maxCount then
      maxCount = count
    end
  end
  
  local localCount = localToken and (tokenCounts[localToken] or 0) or 0
  return {
    covered = covered,
    uniqueCount = uniqueCount,
    maxCount = maxCount,
    localToken = localToken,
    localCount = localCount,
  }
end

function teamStatsScore(stats)
  if not stats.localToken then
    return -huge
  end
  if stats.covered < 2 then
    return -huge
  end
  if stats.uniqueCount < 2 then
    return -huge
  end
  if stats.localCount <= 1 and stats.uniqueCount >= stats.covered then
    return -huge
  end
  
  local score = 0
  score = score + (stats.covered * 9)
  score = score + (stats.localCount * 14)
  score = score + math.min(stats.maxCount, 12)
  score = score - (stats.uniqueCount * 2)
  return score
end

function listTeamLikeNamesFromAttributes(getAttributesFn)
  local out = {}
  local seen = {}
  
  local function addName(name)
    if not name or name == "" or seen[name] then return end
    if not nameLooksTeamLike(name) then return end
    seen[name] = true
    table.insert(out, name)
  end
  
  for _, n in ipairs(STATIC_TEAM_KEYS) do
    addName(n)
  end
  
  for _, p in ipairs(Players:GetPlayers()) do
    local attrs = {}
    pcall(function()
      attrs = getAttributesFn(p) or {}
    end)
    for attrName in pairs(attrs) do
      addName(attrName)
    end
  end
  
  return out
end

function listTeamLikeValueNames(getRootFn)
  local out = {}
  local seen = {}
  
  local function addName(name)
    if not name or name == "" or seen[name] then return end
    if not nameLooksTeamLike(name) then return end
    seen[name] = true
    table.insert(out, name)
  end
  
  for _, n in ipairs(STATIC_TEAM_KEYS) do
    addName(n)
  end
  
  for _, p in ipairs(Players:GetPlayers()) do
    local root = getRootFn(p)
    if root then
      for _, child in ipairs(root:GetDescendants()) do
        if child:IsA("ValueBase") then
          addName(child.Name)
        end
      end
    end
  end
  
  return out
end

function resolveTeamSource()
  local now = tick()
  if now - teamResolverCache.checkedAt < 12 and teamResolverCache.getter ~= nil then
    return teamResolverCache.mode, teamResolverCache.key, teamResolverCache.getter
  end
  
  teamResolverCache.checkedAt = now
  teamResolverCache.mode = "none"
  teamResolverCache.key = nil
  teamResolverCache.getter = nil
  
  local candidates = {}
  local function addCandidate(mode, key, getter)
    local stats = collectTeamStats(getter)
    local score = teamStatsScore(stats)
    if score > -huge then
      table.insert(candidates, {
        mode = mode,
        key = key,
        getter = getter,
        score = score,
      })
    end
  end
  
  addCandidate("player_team", nil, function(p)
    return normalizeTeamToken(p and p.Team)
  end)
  
  addCandidate("player_teamcolor", nil, function(p)
    return normalizeTeamToken(p and p.TeamColor)
  end)
  
  local playerAttrNames = listTeamLikeNamesFromAttributes(function(p)
    return p and p:GetAttributes() or {}
  end)
  for _, attrName in ipairs(playerAttrNames) do
    addCandidate("player_attr", attrName, function(p)
      if not p then return nil end
      return normalizeTeamToken(p:GetAttribute(attrName))
    end)
  end
  
  local charAttrNames = listTeamLikeNamesFromAttributes(function(p)
    local c = p and p.Character
    return c and c:GetAttributes() or {}
  end)
  for _, attrName in ipairs(charAttrNames) do
    addCandidate("char_attr", attrName, function(p)
      local c = p and p.Character
      if not c then return nil end
      return normalizeTeamToken(c:GetAttribute(attrName))
    end)
  end
  
  table.sort(candidates, function(a, b)
    return a.score > b.score
  end)
  
  local best = candidates[1]
  if best then
    teamResolverCache.mode = best.mode
    teamResolverCache.key = best.key
    teamResolverCache.getter = best.getter
  else
    teamResolverCache.mode = "none"
    teamResolverCache.key = nil
    teamResolverCache.getter = nil
  end
  
  return teamResolverCache.mode, teamResolverCache.key, teamResolverCache.getter
end

local teamColorCache = {checkedAt = 0, value = false}
function hasUsefulTeamColors()
  local now = tick()
  if now - teamColorCache.checkedAt < 4 then
    return teamColorCache.value
  end
  local stats = collectTeamStats(function(p)
    return normalizeTeamToken(p and p.TeamColor)
  end)
  teamColorCache.checkedAt = now
  teamColorCache.value = (stats.uniqueCount >= 2 and stats.localToken ~= nil)
  return teamColorCache.value
end

function getTeamToken(player)
  if not player then
    return nil
  end
  
  local mode, key, getter = resolveTeamSource()
  if getter then
    local token = getter(player)
    if token then
      local prefix = tostring(mode or "team")
      if key then
        prefix = prefix .. ":" .. tostring(key)
      end
      return prefix .. ":" .. token
    end
  end
  
  return nil
end

function isSameTeam(playerA, playerB)
  if not playerA or not playerB then
    return false
  end
  
  if playerA == playerB then
    return true
  end
  
  if not playerA.Parent or not playerB.Parent then
    return false
  end
  
  local teamA = playerA.Team
  local teamB = playerB.Team
  if teamA ~= nil and teamB ~= nil then
    return teamA == teamB
  end
  
  local colorA = normalizeTeamToken(playerA.TeamColor)
  local colorB = normalizeTeamToken(playerB.TeamColor)
  if colorA and colorB and hasUsefulTeamColors() then
    return colorA == colorB
  end
  
  local quickAttrKeys = {"TeamID", "TeamId", "Team", "Faction", "Side", "Squad"}
  for _, key in ipairs(quickAttrKeys) do
    local aTok = nil
    local bTok = nil
    pcall(function()
      aTok = normalizeTeamToken(playerA:GetAttribute(key))
      bTok = normalizeTeamToken(playerB:GetAttribute(key))
    end)
    if aTok and bTok then
      return aTok == bTok
    end
    pcall(function()
      local aChar = playerA.Character
      local bChar = playerB.Character
      if aChar and bChar then
        aTok = normalizeTeamToken(aChar:GetAttribute(key))
        bTok = normalizeTeamToken(bChar:GetAttribute(key))
      end
    end)
    if aTok and bTok then
      return aTok == bTok
    end
  end

  local tokenA = getTeamToken(playerA)
  local tokenB = getTeamToken(playerB)
  if tokenA and tokenB then
    return tokenA == tokenB
  end
  
  return false
end

function getPlayerLabel(p)
  local display = tostring(p.DisplayName or p.Name)
  local username = tostring(p.Name)
  if string.lower(display) == string.lower(username) then
    return username
  end
  return string.format("%s  (@%s)", display, username)
end

function getSelectablePlayers()
  local list = {}
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
      table.insert(list, getPlayerLabel(p))
    end
  end
  table.sort(list)
  if #list == 0 then
    table.insert(list, "None")
  end
  return list
end

function findPlayerByName(name)
  if not name or name == "" or name == "None" then return nil end
  local raw = tostring(name)
  local extractedUser = raw:match("@([%w_]+)")
  local n = string.lower(extractedUser or raw)
  
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
      local pn = string.lower(p.Name)
      local pd = string.lower(p.DisplayName or "")
      local label = string.lower(string.format("%s  (@%s)", p.DisplayName or p.Name, p.Name))
      if pn == n or pd == n or label == n or string.sub(pn, 1, #n) == n or string.sub(pd, 1, #n) == n then
        return p
      end
    end
  end
  
  return nil
end

function getNearestEnemyPlayer()
  local myRoot = getRoot()
  if not myRoot then return nil end
  
  local nearest, nearestDist = nil, huge
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
      if not (STATE.AimTeamCheck and teamCheckMeaningful() and isSameTeam(p, LocalPlayer)) then
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
          local root = getPlayerRoot(p)
          if root then
            local d = (root.Position - myRoot.Position).Magnitude
            if d < nearestDist then
              nearestDist = d
              nearest = p
            end
          end
        end
      end
    end
  end
  
  return nearest
end

function rightClick()
  return sendMouseButton(1, MIN_RIGHT_CLICK_INTERVAL)
end

function teleportToTargetRoot(targetRoot, behind)
  local myRoot = getRoot()
  if not myRoot or not targetRoot then return false end
  
  local dist = math.max(1.5, safeNum(STATE.TPDistance))
  local offset
  if behind then
    offset = -(targetRoot.CFrame.LookVector * dist)
  else
    offset = targetRoot.CFrame.RightVector * dist
  end
  
  local dest = targetRoot.Position + offset
  myRoot.CFrame = CFrame.new(dest, targetRoot.Position)
  return true
end

local teamCheckCache = {at = 0, val = true}
function teamCheckMeaningful()
  local now = tick()
  if now - teamCheckCache.at < 1 then return teamCheckCache.val end
  teamCheckCache.at = now
  local seen, differs = nil, false
  for _, p in ipairs(Players:GetPlayers()) do
    local t = p.Team
    if t then
      if seen == nil then seen = t elseif seen ~= t then differs = true break end
    end
  end
  teamCheckCache.val = differs or seen == nil
  return teamCheckCache.val
end

function isEnemy(player, teamCheck)
  if not player or player == LocalPlayer then return false end

  if teamCheck == false or not teamCheckMeaningful() then
    return true
  end
  
  if isSameTeam(player, LocalPlayer) then
    return false
  end
  
  return true
end

function isAlive(player)
  if not player then return false end
  if not player.Character then return false end
  local hum = player.Character:FindFirstChildOfClass("Humanoid")
  if not hum then return false end
  return hum.Health > 0
end

function worldToScreen(pos)
  if not Camera or not Camera.WorldToViewportPoint or not pos then
    return Vector2.new(0, 0), false
  end
  
  local success, sp, os = pcall(function()
    local s, o = Camera:WorldToViewportPoint(pos)
    return s, o
  end)
  
  if not success then return Vector2.new(0, 0), false end
  return Vector2.new(sp.X, sp.Y), os
end

function isMouseNearCenter(threshold)
  if not Camera then return false end
  
  if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
    return true
  end

  local ok, mousePos = pcall(function()
    return UserInputService:GetMouseLocation()
  end)
  
  if not ok or not mousePos then
    return true
  end
  
  local inset = Vector2.new(0, 0)
  pcall(function()
    if GuiService and GuiService.GetGuiInset then
      local tl = GuiService:GetGuiInset()
      if typeof(tl) == "Vector2" then
        inset = tl
      end
    end
  end)
  
  local center = getAimScreenCenter()
  local tol = threshold or 60
  local m = Vector2.new(mousePos.X, mousePos.Y) - inset
  return (m - center).Magnitude <= tol
end

function isAimCenterGateOpen()
  if not STATE.AimRequireCenter then
    return true
  end
  if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
    return true
  end
  return isMouseNearCenter(130)
end

function bindNameToKeyCode(name)
  if not name or name == "" or name == "None" then
    return nil
  end
  
  local keyName = tostring(name):sub(1, 1):upper()
  if #tostring(name) ~= 1 or not keyName:match("^[A-Z]$") then
    return nil
  end
  return Enum.KeyCode[keyName]
end

function inputMatchesBind(input, bindName)
  local bind = bindNameToKeyCode(bindName)
  if not bind then return false end
  
  if typeof(bind) == "EnumItem" and bind.EnumType == Enum.KeyCode then
    return input.KeyCode == bind
  end
  
  if typeof(bind) == "EnumItem" and bind.EnumType == Enum.UserInputType then
    return input.UserInputType == bind
  end
  
  return false
end

local roundStateCache = {
  value = true,
  checkedAt = 0,
}

function isRoundStarted()
  local now = tick()
  if now - roundStateCache.checkedAt < 0.25 then
    return roundStateCache.value
  end
  
  roundStateCache.checkedAt = now
  
  local hum = getHumanoid()
  if not hum or hum.Health <= 0 then
    roundStateCache.value = false
    return false
  end
  
  local boolNames = {"InRound", "RoundStarted", "RoundActive", "MatchStarted", "InMatch", "GameStarted"}
  for _, rootObj in ipairs({workspace, ReplicatedStorage}) do
    if rootObj then
      for _, n in ipairs(boolNames) do
        local ok, obj = pcall(function()
          return rootObj:FindFirstChild(n, true)
        end)
        if ok and obj then
          if obj:IsA("BoolValue") then
            roundStateCache.value = obj.Value == true
            return roundStateCache.value
          elseif obj:IsA("IntValue") or obj:IsA("NumberValue") then
            roundStateCache.value = obj.Value > 0
            return roundStateCache.value
          elseif obj:IsA("StringValue") then
            local s = string.lower(tostring(obj.Value))
            if s:find("lobby") or s:find("intermission") or s:find("waiting") then
              roundStateCache.value = false
              return false
            end
            if s:find("round") or s:find("match") or s:find("playing") or s:find("fight") then
              roundStateCache.value = true
              return true
            end
          end
        end
      end
    end
  end
  
  local tool = getTool()
  local lockLike = (UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.MouseIconEnabled == false)
  if tool and lockLike then
    roundStateCache.value = true
    return true
  end
  
  if lockLike and getRoot() ~= nil then
    roundStateCache.value = true
    return true
  end
  
  roundStateCache.value = false
  return false
end

--  PLAYER CACHE
local cachedPlayers = {}
local lastUpdate = 0

function updateCache()
  local now = tick()
  if now - lastUpdate < 0.3 then return end
  
  local success, result = pcall(function()
    return Players:GetPlayers()
  end)
  
  if success and result then
    cachedPlayers = result
  end
  
  lastUpdate = now
end

--  VISIBILITY
function isVisible(part)
  if not part or not part.Parent or not Camera then return false end
  
  local success, result = pcall(function()
    local origin = Camera.CFrame.Position
    local diff = part.Position - origin
    local dist = diff.Magnitude
    if dist == 0 then return true end
    local dir = diff.Unit
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {}
    if LocalPlayer and LocalPlayer.Character then
      table.insert(exclude, LocalPlayer.Character)
    end
    if Camera then
      table.insert(exclude, Camera)
    end
    params.FilterDescendantsInstances = exclude
    
    local target = part.Parent
    for _ = 1, 8 do
      local rayResult = workspace:Raycast(origin, dir * dist, params)
      if not rayResult then return true end
      local hit = rayResult.Instance
      if hit == part or hit:IsDescendantOf(target) then return true end
      local passThrough = hit.Transparency >= 0.9 or not hit.CanCollide
      if not passThrough then
        local m = hit:FindFirstAncestorOfClass("Model")
        passThrough = m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
      end
      if not passThrough then return false end
      exclude[#exclude + 1] = hit
      params.FilterDescendantsInstances = exclude
      origin = rayResult.Position
      dist = (part.Position - origin).Magnitude
      if dist < 0.05 then return true end
      dir = (part.Position - origin).Unit
    end
    return false
  end)
  
  return success and result or false
end

local visCache = {}
local visCacheTime = 0

function isVisibleCached(part)
  if not part then return false end
  
  local now = tick()
  if now - visCacheTime > 0.1 then
    visCache = {}
    visCacheTime = now
  end
  
  if visCache[part] ~= nil then
    return visCache[part]
  end
  
  local result = isVisible(part)
  visCache[part] = result
  return result
end

local getClosestDbgAt = 0
-- Assigned after spawn-zone definitions are loaded. Fail closed until then.
local safeRageCombatTarget=function() return false end
local rageCombatActive=function() return false end
function getClosest(fov, teamCheck, maxDist, checkVis, forceHead, preferredPart)
  updateCache()
  
  if #cachedPlayers == 0 then return nil end
  
  if not Camera then return nil end
  
  local ok, best = pcall(function()
    local closest, bestDist = nil, huge
    local center = getAimScreenCenter()
    local myRoot = getRoot()
    local activeState = (getgenv and getgenv().NX_STATE) or STATE
    local aimPart = forceHead and "Head" or preferredPart or (activeState.AimLockPart or "Head")
    
    local why = {players = 0, noChar = 0, notEnemy = 0, dead = 0, noPart = 0, tooFar = 0, behind = 0, offscreen = 0, outsideFov = 0, hidden = 0}
    for _, player in ipairs(cachedPlayers) do
      if player and player ~= LocalPlayer then
        why.players = why.players + 1
        local char = player.Character
        if not char then
          why.noChar = why.noChar + 1
        elseif not isEnemy(player, teamCheck)
          or (STATE.RageBot and not safeRageCombatTarget(player)) then
          why.notEnemy = why.notEnemy + 1
        else
          local hum = char:FindFirstChildOfClass("Humanoid")
          if not hum or hum.Health <= 0 then
            why.dead = why.dead + 1
          else
            local head = char:FindFirstChild(aimPart)
              or char:FindFirstChild("Head")
              or char:FindFirstChild("UpperTorso")
              or char:FindFirstChild("HumanoidRootPart")
            if not head then
              why.noPart = why.noPart + 1
            elseif myRoot and maxDist and (head.Position - myRoot.Position).Magnitude > safeNum(maxDist) then
              why.tooFar = why.tooFar + 1
            else
              local lookDir = head.Position - Camera.CFrame.Position
              if STATE.AimFOVCircle and lookDir.Magnitude > 0.001 and Camera.CFrame.LookVector:Dot(lookDir.Unit) < 0 then
                why.behind = why.behind + 1
              else
                local sp, os = worldToScreen(head.Position)
                if STATE.AimFOVCircle and not os then
                  why.offscreen = why.offscreen + 1
                else
                  local dist = STATE.AimFOVCircle and (sp - center).Magnitude
                    or (lookDir.Magnitude > 0.001 and (1 - Camera.CFrame.LookVector:Dot(lookDir.Unit)) or 2)
                  if STATE.AimFOVCircle and dist > safeNum(fov) then
                    why.outsideFov = why.outsideFov + 1
                  elseif checkVis and not isVisibleCached(head) then
                    why.hidden = why.hidden + 1
                  elseif dist < bestDist then
                    bestDist = dist
                    closest = head
                  end
                end
              end
            end
          end
        end
      end
    end

    if NX_DEBUG and not closest and tick() - (getClosestDbgAt or 0) > 2 then
      getClosestDbgAt = tick()
      warn(string.format("[NX] getClosest: keiner. players=%d noChar=%d notEnemy=%d dead=%d noPart=%d tooFar=%d behind=%d offscreen=%d outsideFov=%d hidden=%d (fov=%s maxDist=%s)",
        why.players, why.noChar, why.notEnemy, why.dead, why.noPart, why.tooFar, why.behind, why.offscreen, why.outsideFov, why.hidden, tostring(fov), tostring(maxDist)))
    end

    return closest
  end)
  
  if not ok then
    if NX_DEBUG and tick() - getClosestDbgAt > 2 then
      getClosestDbgAt = tick()
      warn("[NX] getClosest Fehler: " .. tostring(best))
    end
    return nil
  end
  return best
end

--  AIM LOCK
aimTarget = nil
aimLockedPlayer = nil
aimLockLostSince = 0
autoAimTarget = nil
autoAimLockedPlayer = nil
autoAimSmoothedPos = nil
autoAimLastPart = nil
autoAimLastRawPos = nil
autoAimVelocity = Vector3.zero
autoAimLostSince = 0
autoAimReleaseUntil = 0
autoAimManualBreakUntil = 0
autoAimBreakScore = 0
autoAimMixedUseHead = true
autoAimMixedNextSwitch = 0
autoAimMixedBlend = 0
rageTarget = nil
rageLockedPlayer = nil
rageNextShotAt = 0
rageMixedUseHead = true
rageMixedNextSwitch = 0
rageMixedBlend = 0
local updateFOV = function() end
local aimTargetHighlight = nil

clearAimTargetHighlight = function()
  if aimTargetHighlight then
    pcall(function()
      aimTargetHighlight:Destroy()
    end)
    aimTargetHighlight = nil
  end
end

function setAimTargetHighlight(targetPart)
  if not targetPart or not targetPart.Parent then
    clearAimTargetHighlight()
    return
  end
  
  if aimTargetHighlight and aimTargetHighlight.Parent == targetPart then
    return
  end
  
  clearAimTargetHighlight()
  
  local hl = Instance.new("Highlight")
  hl.Name = "NX_AIM_TARGET"
  hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
  hl.FillColor = Color3.fromRGB(255, 0, 0)
  hl.OutlineColor = Color3.fromRGB(255, 255, 0)
  hl.FillTransparency = 0.15
  hl.OutlineTransparency = 0
  hl.Adornee = targetPart
  hl.Parent = targetPart
  aimTargetHighlight = hl
end

mouseStepState = {
  auto = Vector2.new(0, 0),
  lock = Vector2.new(0, 0),
}
injectedMouseDelta = Vector2.new(0, 0)
injectedMouseAt = 0
controlSpoofRemote = nil
lastControlSpoofMode = "MouseKeyboard"
lastControlSpoofAt = 0
antiVoidNextAt = 0

function hasMouseAssistBackend()
  if typeof(mousemoverel) == "function" then
    return true
  end
  if typeof(mousemoveabs) == "function" then
    return true
  end
  if typeof(mousemovedelta) == "function" then
    return true
  end
  if VirtualInputManager and typeof(VirtualInputManager.SendMouseMoveDelta) == "function" then
    return true
  end
  return false
end

function sendMouseDelta(dx, dy)
  local x = tonumber(dx) or 0
  local y = tonumber(dy) or 0
  if math.abs(x) < 0.05 and math.abs(y) < 0.05 then
    return false
  end
  
  if math.abs(x) < 1 and x ~= 0 then
    x = x > 0 and 1 or -1
  end
  if math.abs(y) < 1 and y ~= 0 then
    y = y > 0 and 1 or -1
  end
  
  x = x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
  y = y >= 0 and math.floor(y + 0.5) or math.ceil(y - 0.5)
  
  local function markInjected()
    injectedMouseDelta = Vector2.new(x, y)
    injectedMouseAt = tick()
  end
  
  if typeof(mousemoverel) == "function" then
    local ok = pcall(function()
      mousemoverel(x, y)
    end)
    if ok then
      markInjected()
      return true
    end
  end
  
  if typeof(mousemovedelta) == "function" then
    local ok = pcall(function()
      mousemovedelta(x, y)
    end)
    if ok then
      markInjected()
      return true
    end
  end
  
  if typeof(mousemoveabs) == "function" then
    local ok = pcall(function()
      local mp = UserInputService:GetMouseLocation()
      mousemoveabs(mp.X + x, mp.Y + y)
    end)
    if ok then
      markInjected()
      return true
    end
  end
  
  if VirtualInputManager and typeof(VirtualInputManager.SendMouseMoveDelta) == "function" then
    local ok = pcall(function()
      VirtualInputManager:SendMouseMoveDelta(x, y)
    end)
    if ok then
      markInjected()
      return true
    end
  end
  
  return false
end

function mouseAimStep(targetPos, smooth, mode, speedFactor)
  if not Camera or not targetPos then return false end
  if not hasMouseAssistBackend() then
    return false
  end
  
  local sp, onScreen = worldToScreen(targetPos)
  if not onScreen then
    if STATE.AimFOVCircle then return false end
    local origin=Camera.CFrame.Position
    if (targetPos-origin).Magnitude<0.01 then return false end
    local aim=CFrame.lookAt(origin,targetPos)
    local alpha=math.clamp(1 / math.max(1,tonumber(smooth) or 1),0.02,1)
    Camera.CFrame=Camera.CFrame:Lerp(aim,alpha)
    return true
  end
  
  local center, arSightCompActive = getAimScreenCenter()
  local delta = sp - center
  local hardLock = mode == "hardlock"
  local key = mode == "auto" and "auto" or "lock"
  local isAuto = (key == "auto")
  local autoSpeedFactor = isAuto and math.clamp(tonumber(speedFactor) or 1, 1, 3.4) or 1
  local prev = mouseStepState[key] or Vector2.new(0, 0)
  local deadzone = hardLock and 0 or (isAuto and math.max(0.75, 2.1 / autoSpeedFactor) or 1.25)
  if arSightCompActive and not hardLock then
    deadzone = math.min(deadzone, isAuto and 0.45 or 0.65)
  end
  if delta.Magnitude < deadzone then
    local decay = arSightCompActive and 0.82 or (isAuto and 0.72 or 0.52)
    mouseStepState[key] = prev:Lerp(Vector2.new(0, 0), decay)
    return true
  end
  
  if hardLock then
    mouseStepState[key] = delta
    return sendMouseDelta(delta.X, delta.Y)
  end
  
  local s = math.clamp(safeNum(smooth), 1, 36)
  local userSmooth = math.clamp(safeNum(STATE.AimMouseAssistSmooth), 0.01, 1)
  local assistStrength = math.clamp(safeNum(STATE.AimMouseAssistStrength) / 100, 0.05, 1)
  if isAuto then
    s = s * (0.9 + (1 - userSmooth) * 2.1)
  else
    s = s * (0.68 + (1 - userSmooth) * 1.3)
  end
  if arSightCompActive then
    s = s * (isAuto and 0.78 or 0.72)
  end
  
  local scaleDiv = isAuto and 220 or 150
  local minScale = isAuto and 0.12 or 0.2
  local scale = math.clamp(delta.Magnitude / scaleDiv, minScale, 1)
  local maxStep = (isAuto and (14 * autoSpeedFactor) or 34) * (0.55 + assistStrength * 0.45)
  if arSightCompActive then
    maxStep = maxStep * 1.32
  end
  local desiredRaw = Vector2.new(
    math.clamp((delta.X / s) * scale * assistStrength, -maxStep, maxStep),
    math.clamp((delta.Y / s) * scale * assistStrength, -maxStep, maxStep)
  )
  
  local accelLimit = (isAuto and 4.8 or 8.4) * (isAuto and autoSpeedFactor or 1)
  if arSightCompActive then
    accelLimit = accelLimit * 1.45
  end
  local deltaStep = desiredRaw - prev
  local desired = desiredRaw
  if deltaStep.Magnitude > accelLimit then
    desired = prev + (deltaStep.Unit * accelLimit)
  end
  
  local blend = isAuto and math.clamp(0.22 + ((autoSpeedFactor - 1) * 0.10), 0.22, 0.46) or 0.42
  if arSightCompActive then
    blend = math.min(0.58, blend + 0.12)
  end
  local filtered = prev:Lerp(desired, blend)
  if isAuto and filtered.Magnitude < 0.2 then
    filtered = Vector2.new(0, 0)
  end
  mouseStepState[key] = filtered
  
  return sendMouseDelta(filtered.X, filtered.Y)
end

function getManualMouseDelta()
  local ok, d = pcall(function()
    return UserInputService:GetMouseDelta()
  end)
  if not ok or not d then
    return Vector2.new(0, 0)
  end
  
  local raw = Vector2.new(d.X, d.Y)
  local age = tick() - injectedMouseAt
  if age >= 0 and age <= 0.09 then
    local fade = 1 - (age / 0.09)
    raw = raw - (injectedMouseDelta * fade)
  end
  
  if raw.Magnitude < 0.08 then
    return Vector2.new(0, 0)
  end
  return raw
end

function getAutoAimPartFromTarget(t, noSwitch, deltaTime)
  if not t or not t.Parent then return nil, nil, nil, nil end
  
  local char = t.Parent
  local head = char:FindFirstChild("Head")
  local torso = char:FindFirstChild("UpperTorso")
    or char:FindFirstChild("LowerTorso")
    or char:FindFirstChild("Torso")
    or char:FindFirstChild("HumanoidRootPart")
  local headPart = head or torso or t
  local torsoPart = torso or head or t
  
  local mode = tostring(STATE.AutoAimTargetPart or "Head")
  if mode == "Torso" then
    return torsoPart, torsoPart.Position, headPart, torsoPart
  end
  
  if mode == "Mixed" then
    local useVisibility = STATE.AutoAimVisibleCheck == true
    local now = tick()
    local headVisible = useVisibility and (headPart and isVisibleCached(headPart) or false) or true
    local torsoVisible = useVisibility and (torsoPart and isVisibleCached(torsoPart) or false) or true
    
    if useVisibility and headVisible and not torsoVisible then
      autoAimMixedUseHead = true
      autoAimMixedNextSwitch = now + 0.55
    elseif useVisibility and torsoVisible and not headVisible then
      autoAimMixedUseHead = false
      autoAimMixedNextSwitch = now + 0.55
    elseif (not noSwitch) and now >= autoAimMixedNextSwitch then
      autoAimMixedUseHead = not autoAimMixedUseHead
      autoAimMixedNextSwitch = now + (useVisibility and 0.62 or 0.72)
    end
    
    local targetBlend = autoAimMixedUseHead and 0 or 1
    local dt = math.clamp(deltaTime or (1 / 60), 1 / 240, 1 / 15)
    local blendAlpha = useVisibility
      and math.clamp(dt * 7, 0.04, 0.22)
      or math.clamp(dt * 4.8, 0.03, 0.14)
    autoAimMixedBlend = autoAimMixedBlend + (targetBlend - autoAimMixedBlend) * blendAlpha
    
    local mixedPos = headPart.Position:Lerp(torsoPart.Position, autoAimMixedBlend)
    local chosenPart = (autoAimMixedBlend < 0.5) and headPart or torsoPart
    return chosenPart, mixedPos, headPart, torsoPart
  end
  
  return headPart, headPart.Position, headPart, torsoPart
end

function isAutoAimTargetValid(t)
  if not t or not t.Parent or not Camera then
    return false
  end
  
  local player = Players:GetPlayerFromCharacter(t.Parent)
  if not player or not isAlive(player) or not isEnemy(player, STATE.AimTeamCheck) then
    return false
  end
  
  local part, aimPos, headPart, torsoPart = getAutoAimPartFromTarget(t, true)
  if not part or not aimPos then
    return false
  end
  
  if STATE.AutoAimVisibleCheck then
    local mode = tostring(STATE.AutoAimTargetPart or "Head")
    if mode == "Mixed" then
      local headVisible = headPart and isVisibleCached(headPart) or false
      local torsoVisible = torsoPart and isVisibleCached(torsoPart) or false
      if not headVisible and not torsoVisible then
        return false
      end
    else
      if not isVisibleCached(part) then
        return false
      end
    end
  end
  
  local sp, onScreen = worldToScreen(aimPos)
  if STATE.AimFOVCircle and not onScreen then
    return false
  end
  
  local myRoot = getRoot()
  if myRoot and safeNum(STATE.AimMaxDist) > 0 then
    local dist3d = (aimPos - myRoot.Position).Magnitude
    if dist3d > safeNum(STATE.AimMaxDist) * 1.15 then
      return false
    end
  end
  
  local center = getAimScreenCenter()
  local dist2d = (sp - center).Magnitude
  if STATE.AimFOVCircle and dist2d > safeNum(STATE.AimFOV) * 1.55 then
    return false
  end
  
  return true
end

function isAimLockTargetValid(t)
  if not t or not t.Parent or not Camera then
    return false
  end
  
  local player = Players:GetPlayerFromCharacter(t.Parent)
  if not player or not isAlive(player) or not isEnemy(player, STATE.AimTeamCheck) then
    return false
  end
  
  local lockPart = getPreferredPartFromPlayer(player, STATE.AimLockPart) or t
  if not lockPart or not lockPart.Parent then
    return false
  end
  
  local sp, onScreen = worldToScreen(lockPart.Position)
  if STATE.AimFOVCircle and not onScreen then
    return false
  end
  
  local myRoot = getRoot()
  if myRoot and safeNum(STATE.AimMaxDist) > 0 then
    local dist3d = (lockPart.Position - myRoot.Position).Magnitude
    if dist3d > safeNum(STATE.AimMaxDist) * 1.15 then
      return false
    end
  end
  
  local center = getAimScreenCenter()
  if STATE.AimFOVCircle and (sp - center).Magnitude > safeNum(STATE.AimFOV) * 1.15 then
    return false
  end
  
  return true, lockPart, player
end

function getRagePartFromTarget(t, noSwitch, deltaTime)
  if not t or not t.Parent then return nil, nil, nil, nil end
  
  local char = t.Parent
  local head = char:FindFirstChild("Head")
  local torso = char:FindFirstChild("UpperTorso")
    or char:FindFirstChild("LowerTorso")
    or char:FindFirstChild("Torso")
    or char:FindFirstChild("HumanoidRootPart")
  local headPart = head or torso or t
  local torsoPart = torso or head or t
  
  local mode = tostring(STATE.RageTargetPart or "Head")
  if mode == "Torso" then
    return torsoPart, torsoPart.Position, headPart, torsoPart
  end
  
  if mode == "Mixed" then
    local now = tick()
    if (not noSwitch) and now >= rageMixedNextSwitch then
      rageMixedUseHead = not rageMixedUseHead
      rageMixedNextSwitch = now + 0.42
    end
    
    local targetBlend = rageMixedUseHead and 0 or 1
    local dt = math.clamp(deltaTime or (1 / 60), 1 / 240, 1 / 15)
    local blendAlpha = math.clamp(dt * 9.5, 0.08, 0.34)
    rageMixedBlend = rageMixedBlend + (targetBlend - rageMixedBlend) * blendAlpha
    
    local mixedPos = headPart.Position:Lerp(torsoPart.Position, rageMixedBlend)
    local chosenPart = (rageMixedBlend < 0.5) and headPart or torsoPart
    return chosenPart, mixedPos, headPart, torsoPart
  end
  
  return headPart, headPart.Position, headPart, torsoPart
end

function isRageShotVisible(part)
  if not part or not part.Parent then
    return false
  end
  if not STATE.RageVisibilityCheck then
    return true
  end
  return isVisibleCached(part)
end

function isRageTargetValid(t)
  if not t or not t.Parent or not Camera then
    return false
  end
  
  local player = Players:GetPlayerFromCharacter(t.Parent)
  if not player or not isAlive(player) or not isEnemy(player, STATE.AimTeamCheck)
    or not safeRageCombatTarget(player) then
    return false
  end
  
  local part, aimPos = getRagePartFromTarget(t, true)
  if not part or not aimPos then
    return false
  end
  
  return true
end

function setupCombat()
  addConnection("combat", RunService.RenderStepped:Connect(function(deltaTime)
    STATE.AimTeamCheck = true
    STATE.AimRequireCenter = false
    STATE.TriggerTeamCheck = true
    STATE.TriggerRequireCenter = false
    STATE.TriggerVisibleCheck = true
    STATE.RageVisibilityCheck = false
    local aimModeCount = (STATE.AimLock and 1 or 0) + (STATE.AutoAim and 1 or 0) + (STATE.RageBot and 1 or 0) + (STATE.SilentAim and 1 or 0)
    if aimModeCount > 1 and enforceAimModeExclusivity then
      enforceAimModeExclusivity()
    end

    if not RUNNING or not Camera then
      aimTarget = nil
      aimLockedPlayer = nil
      autoAimTarget = nil
      autoAimLockedPlayer = nil
      autoAimSmoothedPos = nil
      autoAimLastPart = nil
      autoAimLastRawPos = nil
      autoAimVelocity = Vector3.zero
      autoAimLostSince = 0
      autoAimManualBreakUntil = 0
      autoAimBreakScore = 0
      rageTarget = nil
      rageLockedPlayer = nil
      rageNextShotAt = 0
      restoreRageWeaponLock()
      return
    end

    updateFOV()

    local selfHum = getHumanoid()
    if not selfHum or selfHum.Health <= 0 then
      aimTarget = nil
      aimLockedPlayer = nil
      autoAimTarget = nil
      autoAimLockedPlayer = nil
      autoAimSmoothedPos = nil
      autoAimLastPart = nil
      autoAimLastRawPos = nil
      autoAimVelocity = Vector3.zero
      autoAimLostSince = 0
      autoAimReleaseUntil = 0
      autoAimManualBreakUntil = 0
      autoAimBreakScore = 0
      rageTarget = nil
      rageLockedPlayer = nil
      rageNextShotAt = 0
      restoreRageWeaponLock()
      clearAimTargetHighlight()
      if mouseStepState then
        mouseStepState.auto = Vector2.new(0, 0)
        mouseStepState.lock = Vector2.new(0, 0)
      end
      return
    end

    local centerOk = isAimCenterGateOpen()
    local hasActiveTarget =
      (STATE.AimLock and aimTarget and aimTarget.Parent)
      or (STATE.AutoAim and autoAimTarget and autoAimTarget.Parent)
      or (STATE.RageBot and rageTarget and rageTarget.Parent)
    
    if not centerOk and not hasActiveTarget then
      aimTarget = nil
      aimLockedPlayer = nil
      autoAimTarget = nil
      autoAimLockedPlayer = nil
      autoAimSmoothedPos = nil
      autoAimLastPart = nil
      autoAimLastRawPos = nil
      autoAimVelocity = Vector3.zero
      autoAimLostSince = 0
      autoAimReleaseUntil = tick() + 0.06
      autoAimManualBreakUntil = tick() + 0.08
      autoAimBreakScore = 0
      clearAimTargetHighlight()
      if not STATE.RageBot then
        rageTarget = nil
        rageLockedPlayer = nil
        rageNextShotAt = 0
        restoreRageWeaponLock()
      end
      return
    end
    
    pcall(function()
      if STATE.RageBot then
        if not rageCombatActive() then
          rageTarget=nil
          rageLockedPlayer=nil
          rageNextShotAt=0
          restoreRageWeaponLock()
          return
        end
        aimTarget = nil
        autoAimTarget = nil
        autoAimSmoothedPos = nil
        autoAimLastPart = nil
        autoAimLastRawPos = nil
        autoAimVelocity = Vector3.zero
        autoAimLostSince = 0
        autoAimBreakScore = 0
        clearAimTargetHighlight()
        
        local now = tick()
        local rageRmbDown = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        local rageAimAllowed = (not STATE.RageRequireADS) or rageRmbDown
        if not rageAimAllowed then
          rageTarget = nil
          rageLockedPlayer = nil
          rageNextShotAt = 0
          restoreRageWeaponLock()
          return
        end
        
        if rageLockedPlayer and not isAlive(rageLockedPlayer) then
          rageLockedPlayer = nil
          rageTarget = nil
        end
        
        if rageTarget and not isRageTargetValid(rageTarget) then
          rageTarget = nil
        end
        
        if (not rageTarget) and rageLockedPlayer then
          rageTarget = getPreferredPartFromPlayer(rageLockedPlayer, STATE.RageTargetPart)
        end
        
        if not rageTarget then
          if not centerOk then
            rageNextShotAt = 0
            restoreRageWeaponLock()
            return
          end
          local preferredPart = nil
          local rageMode = tostring(STATE.RageTargetPart or "Head")
          if rageMode == "Head" then
            preferredPart = "Head"
          elseif rageMode == "Torso" then
            preferredPart = "UpperTorso"
          elseif rageMode == "Mixed" then
            rageMixedUseHead = true
            rageMixedBlend = 0
            rageMixedNextSwitch = now + 0.32
            preferredPart = "Head"
          end
          
          rageTarget = getClosest(
            STATE.AimFOV,
            STATE.AimTeamCheck,
            STATE.AimMaxDist,
            false,
            false,
            preferredPart
          )
          rageLockedPlayer = rageTarget and Players:GetPlayerFromCharacter(rageTarget.Parent) or nil
        end
        
        if rageTarget then
          local targetPart, targetBasePos = getRagePartFromTarget(rageTarget, false, deltaTime)
          if not targetPart or not targetBasePos then
            rageTarget = nil
            if not rageLockedPlayer or not isAlive(rageLockedPlayer) then
              rageLockedPlayer = nil
            end
            rageNextShotAt = 0
            return
          end
          
          if not rageLockedPlayer then
            rageLockedPlayer = Players:GetPlayerFromCharacter(targetPart.Parent)
          end
          
          if not isRageShotVisible(targetPart) then
            rageTarget = nil
            rageNextShotAt = 0
            restoreRageWeaponLock()
            return
          end
          
          local targetPos = targetBasePos
          
          local lockStrength = math.clamp(safeNum(STATE.RageLockStrength), 1, 100) / 100
          local useMouse = hasMouseAssistBackend()
          local weaponLocked = false
          
          if useMouse then
            local smooth = math.clamp(9.5 - (lockStrength * 8.4), 1.01, 9.5)
            mouseAimStep(targetPos, smooth, "lock")
          else
            rageNextShotAt = 0
            restoreRageWeaponLock()
            return
          end
          
          local shouldShoot = STATE.RageAutoShoot and ((not STATE.RageRequireADS) or rageRmbDown)
          
          if shouldShoot and now >= rageNextShotAt then
            local cps = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(STATE.RageCPS)))
            local interval = 1 / cps
            if weaponLocked then
              click(interval)
            else
              local sp, os = worldToScreen(targetPos)
              if os then
                local center = getAimScreenCenter()
                local shootRadius = math.max(2, safeNum(STATE.RageShootFOV))
                if (sp - center).Magnitude <= shootRadius then
                  click(interval)
                end
              end
            end
            
            rageNextShotAt = now + interval
          end
          
          return
        else
          rageNextShotAt = 0
          restoreRageWeaponLock()
        end
      else
        rageTarget = nil
        rageLockedPlayer = nil
        rageNextShotAt = 0
        restoreRageWeaponLock()
      end
      
      if STATE.AimLock then
        if STATE.AimLockRequireRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
          clearAimTargetHighlight()
          if mouseStepState then
            mouseStepState.lock = mouseStepState.lock:Lerp(Vector2.new(0, 0), 0.65)
          end
          return
        end

        autoAimTarget = nil
        autoAimLockedPlayer = nil
        autoAimSmoothedPos = nil
        autoAimLastPart = nil
        autoAimLastRawPos = nil
        autoAimVelocity = Vector3.zero
        autoAimLostSince = 0
        autoAimBreakScore = 0
        autoAimManualBreakUntil = 0

        if not centerOk then
          aimTarget = nil
          aimLockedPlayer = nil
          clearAimTargetHighlight()
          if mouseStepState then
            mouseStepState.lock = mouseStepState.lock:Lerp(Vector2.new(0, 0), 0.65)
          end
          return
        end

        local preferredPart = nil
        local aimMode = tostring(STATE.AimLockPart or "Head")
        if aimMode == "Head" then
          preferredPart = "Head"
        elseif aimMode == "Torso" or aimMode == "UpperTorso" then
          preferredPart = "UpperTorso"
        elseif aimMode == "HumanoidRootPart" then
          preferredPart = "HumanoidRootPart"
        end
        if aimTarget then
          local valid, lockPart, player = isAimLockTargetValid(aimTarget)
          if valid then
            aimTarget = lockPart
            aimLockedPlayer = player
            aimLockLostSince = 0
          else
            if aimLockLostSince == 0 then
              aimLockLostSince = tick()
            end
            if tick() - aimLockLostSince > 0.18 then
              aimTarget = nil
              aimLockedPlayer = nil
              aimLockLostSince = 0
            end
          end
        end
        
        if not aimTarget then
          aimTarget = getClosest(STATE.AimFOV, STATE.AimTeamCheck, STATE.AimMaxDist, false, false, preferredPart)
          aimLockedPlayer = aimTarget and Players:GetPlayerFromCharacter(aimTarget.Parent) or nil
          aimLockLostSince = 0
        end
        
        if aimTarget then
          local lockPart = getPreferredPartFromPlayer(aimLockedPlayer, STATE.AimLockPart) or aimTarget
          if not lockPart or not lockPart.Parent then
            aimTarget = nil
            aimLockedPlayer = nil
            aimLockLostSince = 0
            clearAimTargetHighlight()
            return
          end
          aimTarget = lockPart
          
          setAimTargetHighlight(lockPart)
          
          local targetPos = lockPart.Position
          pcall(function()
            local lockStrength = math.clamp(safeNum(STATE.AimLockStrength), 1, 100) / 100
            if STATE.AimMouseAssist and hasMouseAssistBackend() then
              local smooth = math.clamp(9.5 - lockStrength * 8.4, 1.01, 9.5)
              mouseAimStep(targetPos, smooth, "lock")
            else
              local cf = Camera.CFrame
              local want = CFrame.new(cf.Position, targetPos)
              Camera.CFrame = lockStrength >= 0.99 and want or cf:Lerp(want, math.clamp(lockStrength * 0.9, 0.05, 0.95))
            end
          end)
        else
          aimTarget = nil
          aimLockedPlayer = nil
          aimLockLostSince = 0
          clearAimTargetHighlight()
        end
      elseif STATE.AutoAim then
        if STATE.AutoAimRequireRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
          if mouseStepState then
            mouseStepState.auto = mouseStepState.auto:Lerp(Vector2.new(0, 0), 0.65)
          end
          return
        end

        clearAimTargetHighlight()
        local now = tick()
        if now < autoAimReleaseUntil then
          mouseStepState.auto = mouseStepState.auto:Lerp(Vector2.new(0, 0), 0.45)
          return
        end
        if now < autoAimManualBreakUntil then
          mouseStepState.auto = mouseStepState.auto:Lerp(Vector2.new(0, 0), 0.55)
          return
        end
        
        if autoAimLockedPlayer and not isAlive(autoAimLockedPlayer) then
          autoAimLockedPlayer = nil
          autoAimTarget = nil
        end
        
        if autoAimTarget and not isAutoAimTargetValid(autoAimTarget) then
          if autoAimLostSince == 0 then
            autoAimLostSince = now
          end
          if now - autoAimLostSince > 0.16 then
            autoAimTarget = nil
            autoAimLockedPlayer = nil
            autoAimSmoothedPos = nil
            autoAimLastPart = nil
            autoAimLastRawPos = nil
            autoAimVelocity = Vector3.zero
            autoAimLostSince = 0
            autoAimReleaseUntil = now + 0.09
            autoAimBreakScore = 0
            mouseStepState.auto = mouseStepState.auto:Lerp(Vector2.new(0, 0), 0.7)
            return
          end
        else
          autoAimLostSince = 0
        end
        
        if not autoAimTarget then
          if autoAimLockedPlayer then
            autoAimTarget = getPreferredPartFromPlayer(autoAimLockedPlayer, STATE.AutoAimTargetPart)
          end
        end
        
        if not autoAimTarget then
          if not centerOk then
            if mouseStepState then
              mouseStepState.auto = mouseStepState.auto:Lerp(Vector2.new(0, 0), 0.65)
            end
            return
          end
          local preferredPart = nil
          local mode = tostring(STATE.AutoAimTargetPart or "Head")
          if mode == "Head" then
            preferredPart = "Head"
          elseif mode == "Torso" then
            preferredPart = "UpperTorso"
          elseif mode == "Mixed" then
            autoAimMixedUseHead = true
            autoAimMixedBlend = 0
            autoAimMixedNextSwitch = tick() + 0.48
            preferredPart = "Head"
          end
          
          autoAimTarget = getClosest(
            STATE.AimFOV,
            STATE.AimTeamCheck,
            STATE.AimMaxDist,
            STATE.AutoAimVisibleCheck,
            false,
            preferredPart
          )
          autoAimLockedPlayer = autoAimTarget and Players:GetPlayerFromCharacter(autoAimTarget.Parent) or nil
          autoAimSmoothedPos = nil
          autoAimLastPart = nil
          autoAimLastRawPos = nil
          autoAimVelocity = Vector3.zero
        end
        
        local autoTarget = autoAimTarget
        if autoTarget then
          local targetPart, targetPos = getAutoAimPartFromTarget(autoTarget, false, deltaTime)
          if not targetPart or not targetPos then
            autoAimTarget = nil
            autoAimLockedPlayer = nil
            autoAimSmoothedPos = nil
            autoAimLastPart = nil
            autoAimLastRawPos = nil
            autoAimVelocity = Vector3.zero
            return
          end
          local _, onScreen = worldToScreen(targetPos)
          if not onScreen then
            autoAimBreakScore = math.max(0, autoAimBreakScore - 0.08)
            return
          end

          if autoAimLastPart ~= targetPart then
            if tostring(STATE.AutoAimTargetPart or "Head") ~= "Mixed" then
              autoAimSmoothedPos = nil
            end
            autoAimLastPart = targetPart
          end

          local dt = math.clamp(deltaTime or (1 / 60), 1 / 240, 1 / 15)
          local rawVelocity = Vector3.zero
          if autoAimLastRawPos then
            rawVelocity = (targetPos - autoAimLastRawPos) / dt
          end
          local partVelocity = targetPart.AssemblyLinearVelocity
          if typeof(partVelocity) == "Vector3" and partVelocity.Magnitude > rawVelocity.Magnitude then
            rawVelocity = partVelocity
          end
          autoAimLastRawPos = targetPos
          local velocityAlpha = math.clamp(dt * 14, 0.18, 0.62)
          autoAimVelocity = (autoAimVelocity or Vector3.zero):Lerp(rawVelocity, velocityAlpha)
          local targetSpeed = autoAimVelocity.Magnitude
          local autoAimSpeedFactor = math.clamp(1 + (targetSpeed / 55), 1, 3.4)

          if autoAimSmoothedPos == nil then
            autoAimSmoothedPos = targetPos
          else
            local posAlpha
            if tostring(STATE.AutoAimTargetPart or "Head") == "Mixed" then
              posAlpha = math.clamp(dt * (7.5 + targetSpeed * 0.08), 0.08, 0.58)
            else
              posAlpha = math.clamp(dt * (12 + targetSpeed * 0.12), 0.14, 0.82)
            end
            autoAimSmoothedPos = autoAimSmoothedPos:Lerp(targetPos, posAlpha)
          end

          local isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
          local modeStrength = isAiming and safeNum(STATE.AutoAimStrengthADS) or safeNum(STATE.AutoAimStrengthHip)
          if modeStrength <= 0 then
            return
          end

          local strength = math.clamp(modeStrength, 1, 100) / 100
          local curve = strength ^ 1.45
          local hum = getHumanoid()
          local moveMag = hum and hum.MoveDirection and hum.MoveDirection.Magnitude or 0
          local movePenalty = math.clamp(moveMag * 0.08, 0, 0.08)
          local adjustedStrength = math.clamp(curve - movePenalty, 0, 1)

          local leadTime = math.clamp(0.012 + (targetSpeed * 0.00055), 0.012, 0.075) * adjustedStrength
          local targetForAim = autoAimSmoothedPos + (autoAimVelocity * leadTime)
          
          local _, targetScreenVisible = worldToScreen(targetForAim)
          if targetScreenVisible then
            local manualDelta = getManualMouseDelta()
            local manualMag = manualDelta.Magnitude

            local manualThreshold
            if modeStrength >= 100 then
              manualThreshold = 8.5
            else
              manualThreshold = 3.0 + math.clamp((100 - modeStrength) * 0.018, 0, 1.8)
            end
            if manualMag > manualThreshold then
              autoAimReleaseUntil = now + math.clamp(0.015 + (manualMag * 0.0024), 0.015, 0.06)
              autoAimManualBreakUntil = now + math.clamp(0.02 + (manualMag * 0.0032), 0.02, 0.09)
              autoAimBreakScore = 0
              mouseStepState.auto = mouseStepState.auto:Lerp(Vector2.new(0, 0), 0.9)
              return
            else
              autoAimBreakScore = math.max(0, autoAimBreakScore - 0.22)
            end
          else
            autoAimBreakScore = math.max(0, autoAimBreakScore - 0.12)
          end

          local useMouse = STATE.AimMouseAssist and hasMouseAssistBackend()
          if useMouse then
            local smooth = math.clamp(13.5 - (adjustedStrength * 9.5) - ((autoAimSpeedFactor - 1) * 2.2), 1.15, 13.5)
            if modeStrength >= 100 then
              smooth = math.max(1.35, 2.0 - ((autoAimSpeedFactor - 1) * 0.35))
            end
            mouseAimStep(targetForAim, smooth, "auto", autoAimSpeedFactor)
          elseif Camera and (targetForAim - Camera.CFrame.Position).Magnitude > 0.01 then
            local cf = Camera.CFrame
            local want = CFrame.lookAt(cf.Position, targetForAim, cf.UpVector)
            local alpha = math.clamp(adjustedStrength * deltaTime * 8, 0, 1)
            Camera.CFrame = cf:Lerp(want, alpha)
          end
          
        else
          autoAimTarget = nil
          autoAimLockedPlayer = nil
          autoAimSmoothedPos = nil
          autoAimLastPart = nil
          autoAimLastRawPos = nil
          autoAimVelocity = Vector3.zero
          autoAimBreakScore = math.max(0, autoAimBreakScore - 0.2)
        end
      else
        aimTarget = nil
        aimLockedPlayer = nil
        autoAimTarget = nil
        autoAimLockedPlayer = nil
        autoAimSmoothedPos = nil
        autoAimLastPart = nil
        autoAimLastRawPos = nil
        autoAimVelocity = Vector3.zero
        autoAimLostSince = 0
        autoAimBreakScore = 0
        autoAimManualBreakUntil = 0
        rageLockedPlayer = nil
        clearAimTargetHighlight()
      end
    end)
  end))
end

--  TRIGGER BOT
local nextTriggerShotAt = 0
local triggerRayParams = RaycastParams.new()
triggerRayParams.FilterType = Enum.RaycastFilterType.Exclude

function updateTriggerParams()
  local exclude = {workspace.Terrain}
  local char = getChar()
  if char then
    table.insert(exclude, char)
  end
  triggerRayParams.FilterDescendantsInstances = exclude
end

function triggerCheckCenter()
  if not Camera then return false end
  local vp = Camera.ViewportSize
  local teamCheck = STATE.TriggerTeamCheck == true
  local center = getAimScreenCenter()
  local mode = tostring(STATE.TriggerTarget or "Head")
  
  local function getPlayerFromHitPart(part)
    if not part then return nil end
    local model = part:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    return Players:GetPlayerFromCharacter(model)
  end

  local function getTriggerPart(char)
    if not char then return nil end
    if mode == "Torso" then
      return char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("Head")
    end
    if mode == "Any Visible Body" then
      return char:FindFirstChild("Head")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChildWhichIsA("BasePart")
    end
    return char:FindFirstChild("Head")
  end

  local function hitPartAllowed(player, hitPart)
    if not player or not hitPart or not player.Character then
      return false
    end
    if not isEnemy(player, teamCheck) or not isAlive(player) then
      return false
    end
    if not hitPart:IsDescendantOf(player.Character) then
      return false
    end
    if STATE.TriggerVisibleCheck ~= false and not isVisibleCached(hitPart) then
      return false
    end
    if mode == "Any Visible Body" then
      return hitPart:IsA("BasePart")
    end
    local wanted = getTriggerPart(player.Character)
    if not wanted then return false end
    if hitPart == wanted then
      return true
    end
    if hitPart:IsDescendantOf(wanted) then
      return true
    end
    return tostring(hitPart.Name) == tostring(wanted.Name)
  end
  
  local function isPartInTriggerAssist(part, pos)
    if not part or not part.Parent or not pos then return false end
    local player = Players:GetPlayerFromCharacter(part.Parent)
    if not player or not isEnemy(player, teamCheck) or not isAlive(player) then
      return false
    end
    
    if not isVisibleCached(part) then
      return false
    end
    
    local vel = part.AssemblyLinearVelocity or part.Velocity or V0
    local leadTime = math.clamp(vel.Magnitude / 2500, 0.0, 0.045)
    local predictedPos = pos + (vel * leadTime)
    local sp, onScreen = worldToScreen(predictedPos)
    if not onScreen then
      return false
    end
    
    local speedBoost = math.clamp(vel.Magnitude / 70, 0, 8)
    local baseRadius = mode == "Head" and 11 or (mode == "Torso" and 16 or 20)
    local assistBoost = (STATE.AutoAim or STATE.AimLock or STATE.RageBot) and 3.5 or 0
    local radius = baseRadius + speedBoost + assistBoost
    return (sp - center).Magnitude <= radius
  end
  
  if STATE.AutoAim and autoAimTarget then
    local part, pos = getAutoAimPartFromTarget(autoAimTarget, true, 1 / 60)
    if mode ~= "Any Visible Body" and part and part.Parent then
      part = getTriggerPart(part.Parent) or part
      pos = part.Position
    end
    if isPartInTriggerAssist(part, pos) then
      return true
    end
  end
  
  if STATE.AimLock and aimTarget and aimTarget.Parent then
    local lockPart = getTriggerPart(aimTarget.Parent) or aimTarget
    if isPartInTriggerAssist(lockPart, lockPart.Position) then
      return true
    end
  end
  
  if STATE.RageBot and rageTarget then
    local part, pos = getRagePartFromTarget(rageTarget, true, 1 / 60)
    if mode ~= "Any Visible Body" and part and part.Parent then
      part = getTriggerPart(part.Parent) or part
      pos = part.Position
    end
    if isPartInTriggerAssist(part, pos) then
      return true
    end
  end
  
  for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer and p.Character then
      local part = getTriggerPart(p.Character)
      if part and part.Parent and isPartInTriggerAssist(part, part.Position) then
        return true
      end
    end
  end

  local spread = mode == "Head" and 3 or (mode == "Torso" and 4 or 5)
  
  for _, offset in ipairs({
    Vector2.new(center.X, center.Y),
    Vector2.new(center.X - spread, center.Y),
    Vector2.new(center.X + spread, center.Y),
    Vector2.new(center.X, center.Y - spread),
    Vector2.new(center.X, center.Y + spread),
    Vector2.new(center.X - spread, center.Y - spread),
    Vector2.new(center.X + spread, center.Y - spread),
    Vector2.new(center.X - spread, center.Y + spread),
    Vector2.new(center.X + spread, center.Y + spread),
  }) do
    local ray = Camera:ViewportPointToRay(offset.X, offset.Y)
    local result = workspace:Raycast(ray.Origin, ray.Direction * 1200, triggerRayParams)
    if result and result.Instance then
      local player = getPlayerFromHitPart(result.Instance)
      if hitPartAllowed(player, result.Instance) then
        return true
      end
    end
  end
  
  return false
end

function setupTrigger()
  updateTriggerParams()
  
  task.spawn(function()
    local nextParamsAt = 0
    while RUNNING do
      STATE.TriggerVisibleCheck = true
      if tick() >= nextParamsAt then
        nextParamsAt = tick() + 0.25
        pcall(updateTriggerParams)
      end
      if STATE.TriggerEnabled then
        pcall(function()
          if STATE.RageBot and STATE.RageAutoShoot then
            return
          end
          
          local hasAimAssistTarget = (STATE.AutoAim and autoAimTarget ~= nil)
            or (STATE.AimLock and aimTarget ~= nil)
            or (STATE.RageBot and rageTarget ~= nil)
          local triggerCenterOpen = (not STATE.TriggerRequireCenter)
            or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
            or isMouseNearCenter(130)
          if (not hasAimAssistTarget) and (not triggerCenterOpen) then
            return
          end
          
          local now = tick()
          if now >= nextTriggerShotAt then
            if triggerCheckCenter() then
              local delayMs = math.max(0, safeNum(STATE.TriggerDelay))
              if delayMs > 0 then
                task.wait(delayMs / 1000)
              end
              
              local cps = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(STATE.TriggerCPS)))
              local interval = 1 / cps
              local fired = click(interval)
              if fired then
                nextTriggerShotAt = tick() + interval
              else
                nextTriggerShotAt = tick() + 0.05
              end
            end
          end
        end)
        
        local cps = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(STATE.TriggerCPS)))
        task.wait(math.clamp((1 / cps) * 0.5, 0.001, 0.01))
      else
        nextTriggerShotAt = 0
        task.wait(0.1)
      end
    end
  end)
end

-- Fail-closed combat teleport gate. RIVALS DuelLibrary and ClientDueler
-- are class definitions, not reliable live team assignments by themselves.
-- Never infer an enemy from a missing TeamID, neutral lobby state or cursor lock.
local LOBBY_SPAWN_DESCRIPTORS={
  {{"WaitingRoom","Important","Spawn"},Vector3.new(120,-635.75,1964.75),Vector3.new(25,1,25)},
  {{"ShootingRange","Important","Spawn"},Vector3.new(1406.67,-713.675,1044.35),Vector3.new(13.25,5.25,39.5)},
  {{"Hub","Important","Center","Spawn"},Vector3.new(109,-680,1183.95),Vector3.new(20,2,20)},
  {{"Hub","Important","Duels","Spawn"},Vector3.new(186,-677.5,1183.95),Vector3.new(2,2,2)},
}
local function combatTeamToken(p)
  if not p then return nil end
  local value
  -- TeamID from Player/Character is only used when BOTH sides have it.
  local character=p.Character
  for _,key in ipairs({"TeamID","TeamId"}) do
    local ok,v=pcall(function()return p:GetAttribute(key)end)
    if ok then value=normalizeTeamToken(v) end
    if not value and character then
      ok,v=pcall(function()return character:GetAttribute(key)end)
      if ok then value=normalizeTeamToken(v) end
    end
    if value then return "duel:"..value end
  end
  if p.Team and not p.Neutral then return "roblox:"..tostring(p.Team) end
  return nil
end
local function inLobbySpawnZone(position)
  if typeof(position)~="Vector3" then return true end
  local lobby=workspace:FindFirstChild("Lobby")
  for _,descriptor in ipairs(LOBBY_SPAWN_DESCRIPTORS) do
    local path,fallbackCenter,fallbackSize=descriptor[1],descriptor[2],descriptor[3]
    local node=lobby
    for _,segment in ipairs(path) do
      node=node and node:FindFirstChild(segment) or nil
    end
    local part=node and node:IsA("BasePart") and node or nil
    local relative=part and part.CFrame:PointToObjectSpace(position) or (position-fallbackCenter)
    local size=part and part.Size or fallbackSize
    if math.abs(relative.X)<=size.X/2+13 and
       math.abs(relative.Z)<=size.Z/2+13 and
       math.abs(relative.Y)<=size.Y/2+24 then
      return true
    end
  end
  return false
end
local function safeCombatTeleportTarget(player)
  if not RUNNING or not player or player==LocalPlayer or not isAlive(player) then return false,"invalid target" end
  if not isRoundStarted() then return false,"round not active" end
  local myRoot,targetRoot=getRoot(),getPlayerRoot(player)
  if not myRoot or not targetRoot then return false,"missing root" end
  if inLobbySpawnZone(myRoot.Position) or inLobbySpawnZone(targetRoot.Position) then
    return false,"lobby/spawn zone"
  end
  local mine,theirs=combatTeamToken(LocalPlayer),combatTeamToken(player)
  if not mine or not theirs then return false,"unconfirmed duel TeamID" end
  if mine==theirs then return false,"teammate" end
  if hasSpawnProtection and hasSpawnProtection(player) then return false,"spawn protection" end
  return true,"confirmed combat"
end
rageCombatActive=function()
  local root=getRoot()
  return root~=nil and isRoundStarted() and not inLobbySpawnZone(root.Position)
end
safeRageCombatTarget=function(player)
  local allowed=safeCombatTeleportTarget(player)
  return allowed==true
end
--  TELEPORT + AUTO BACKSTAB
local tpDropdownRef = nil
local backstabBusy = false
local nextBackstabAt = 0

function setTPPlayer(value)
  if type(value) == "table" then
    value = value[1]
  end
  if not value or value == "None" then
    STATE.TPPlayer = ""
    return
  end
  local matched = findPlayerByName(value)
  if matched then
    STATE.TPPlayer = matched.Name
  else
    STATE.TPPlayer = tostring(value)
  end
end

function getBackstabTargetPlayer()
  local selected=findPlayerByName(STATE.TPPlayer)
  if selected and safeCombatTeleportTarget(selected) then return selected end
  local best,bestDistance=nil,math.huge
  local root=getRoot()
  if not root then return nil end
  for _,candidate in ipairs(Players:GetPlayers()) do
    if candidate~=LocalPlayer and safeCombatTeleportTarget(candidate) then
      local part=getPlayerRoot(candidate)
      local d=part and (part.Position-root.Position).Magnitude or math.huge
      if d<bestDistance then best,bestDistance=candidate,d end
    end
  end
  return best
end

function refreshTPDropdown()
  if not tpDropdownRef then return end
  
  local options = getSelectablePlayers()
  pcall(function()
    if tpDropdownRef.Refresh then
      tpDropdownRef:Refresh(options)
    elseif tpDropdownRef.SetOptions then
      tpDropdownRef:SetOptions(options)
    end
    
    local selected = findPlayerByName(STATE.TPPlayer)
    local selectedLabel = selected and getPlayerLabel(selected) or "None"
    if tpDropdownRef.Set then
      tpDropdownRef:Set(selectedLabel)
    end
  end)
  
  if not findPlayerByName(STATE.TPPlayer) then
    if options[1] ~= "None" then
      setTPPlayer(options[1])
    else
      STATE.TPPlayer = ""
    end
  end
end

function teleportNearSelected(behind)
  local targetPlayer = findPlayerByName(STATE.TPPlayer)
  if not targetPlayer then
    notify("TP", "Waehle zuerst einen Spieler", 2)
    return false
  end
  
  local targetRoot=getPlayerRoot(targetPlayer)
  if not targetRoot then
    notify("TP","Target hat keinen Root",2)
    return false
  end
  local eligible,reason=safeCombatTeleportTarget(targetPlayer)
  if not eligible then
    notify("TP blocked","Spawn/Team check: "..tostring(reason),3)
    return false
  end

  rightClick()
  task.wait(0.02)
  local allowed=safeCombatTeleportTarget(targetPlayer)
  local ok=allowed and teleportToTargetRoot(targetRoot,behind==true) or false
  if ok then
    notify("TP", string.format("Zu %s (@%s) teleportiert", tostring(targetPlayer.DisplayName or targetPlayer.Name), tostring(targetPlayer.Name)), 1.5)
  end
  return ok
end

function followBehindTargetBriefly(targetRoot, durationSec)
  if not targetRoot or not targetRoot.Parent then return end
  local myRoot = getRoot()
  if not myRoot then return end
  
  local duration = math.clamp(safeNum(durationSec), 0.1, 2)
  local endAt = tick() + duration
  while RUNNING and tick() < endAt do
    if not myRoot.Parent or not targetRoot.Parent then
      break
    end
    local behindDist = math.max(2, safeNum(STATE.TPDistance))
    local behindPos = targetRoot.Position - targetRoot.CFrame.LookVector * behindDist
    myRoot.CFrame = CFrame.new(behindPos, targetRoot.Position)
    task.wait(0.03)
  end
end

function getPlayerHumanoid(player)
  local char = player and player.Character
  return char and char:FindFirstChildOfClass("Humanoid") or nil
end

function hasSpawnProtection(player)
  local char = player and player.Character
  if not char then return false end
  if char:FindFirstChildOfClass("ForceField") then
    return true
  end
  for _, obj in ipairs(char:GetDescendants()) do
    if obj:IsA("ForceField") then
      return true
    end
    local name = string.lower(tostring(obj.Name or ""))
    local protectedName = name:find("spawn", 1, true)
      or name:find("bubble", 1, true)
      or name:find("shield", 1, true)
      or name:find("protect", 1, true)
    if protectedName and (obj:IsA("BasePart") or obj:IsA("Highlight") or obj:IsA("SelectionBox") or obj:IsA("BillboardGui")) then
      return true
    end
  end
  return false
end

function waitForSpawnProtectionGone(player, maxWait, requireAuto)
  local deadline = tick() + math.clamp(safeNum(maxWait), 0.5, 10)
  while RUNNING and (requireAuto ~= true or STATE.AutoBackstab) and isAlive(player) and hasSpawnProtection(player) do
    if tick() >= deadline then
      return false
    end
    task.wait(0.08)
  end
  return (requireAuto ~= true or STATE.AutoBackstab) and isAlive(player) and not hasSpawnProtection(player)
end

function getBackAimPosition(targetRoot)
  if not targetRoot then return nil end
  return targetRoot.Position - (targetRoot.CFrame.LookVector * 0.9) + Vector3.new(0, 0.75, 0)
end

function aimAtTargetBack(targetRoot)
  local myRoot = getRoot()
  local aimPos = getBackAimPosition(targetRoot)
  if not myRoot or not targetRoot or not aimPos then return false end
  local behindDist = math.max(2, safeNum(STATE.TPDistance))
  local behindPos = targetRoot.Position - targetRoot.CFrame.LookVector * behindDist
  myRoot.CFrame = CFrame.new(behindPos, aimPos)
  if Camera then
    pcall(function()
      Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, aimPos)
    end)
  end
  return true
end

function fireBegAction()
  local remotes = ReplicatedStorage:FindFirstChild("Remotes")
  local misc = remotes and remotes:FindFirstChild("Misc")
  local dialogAction = misc and misc:FindFirstChild("DialogAction")
  if dialogAction and dialogAction:IsA("RemoteEvent") then
    pcall(function()
      dialogAction:FireServer("beg")
    end)
    return true
  end
  return false
end

function setupBeggerFarm()
  task.spawn(function()
    while RUNNING do
      if STATE.BeggerFarm then
        fireBegAction()
        task.wait(0.15)
      else
        task.wait(0.35)
      end
    end
  end)
end

function normalizeControlModeName(mode)
  local m = tostring(mode or "MouseKeyboard")
  if m == "Touch" or m == "Gamepad" or m == "MouseKeyboard" or m == "VR" then return m end
  m = string.lower(m)
  if m == "mobile" then return "Touch" end
  if m == "console" or m == "controller" then return "Gamepad" end
  if m == "vr" then return "VR" end
  return "MouseKeyboard"
end
function getSelectedControlMode()
  if STATE.VRSpoof then return "VR" end
  if STATE.ConsoleSpoof then return "Gamepad" end
  if STATE.MobileSpoof then return "Touch" end
  return "MouseKeyboard"
end
function getSetControlsRemote()
  if controlSpoofRemote and controlSpoofRemote.Parent then return controlSpoofRemote end
  local remotes = ReplicatedStorage:FindFirstChild("Remotes")
  local replication = remotes and remotes:FindFirstChild("Replication")
  local fighter = replication and replication:FindFirstChild("Fighter")
  local remote = fighter and fighter:FindFirstChild("SetControls")
  if remote and remote:IsA("RemoteEvent") then controlSpoofRemote = remote; return remote end
  controlSpoofRemote = nil; return nil
end
applyReplicationControlSpoof = function(modeOverride, forceSend)
  local mode = normalizeControlModeName(modeOverride or getSelectedControlMode())
  local remote = getSetControlsRemote(); if not remote then return false end
  if not forceSend and lastControlSpoofMode == mode and (tick() - (lastControlSpoofAt or 0)) < 0.35 then return true end
  local ok = pcall(function() remote:FireServer(mode) end)
  if ok then lastControlSpoofMode = mode; lastControlSpoofAt = tick() end
  return ok
end
restoreSoftSpoof = function()
  STATE.SoftMobileSpoof, STATE.SoftConsoleSpoof, STATE.SoftVRSpoof = false, false, false
  if getgenv then local gv = getgenv(); gv.NX_DEVICE_MOBILE=nil; gv.NX_DEVICE_CONSOLE=nil; gv.NX_DEVICE_VR=nil end
  applyReplicationControlSpoof("MouseKeyboard", true)
end
applySoftSpoof = function()
  if not STATE.MobileSpoof and not STATE.ConsoleSpoof and not STATE.VRSpoof then restoreSoftSpoof(); return true end
  if getgenv then local gv = getgenv(); gv.NX_DEVICE_MOBILE=STATE.MobileSpoof; gv.NX_DEVICE_CONSOLE=STATE.ConsoleSpoof; gv.NX_DEVICE_VR=STATE.VRSpoof end
  return applyReplicationControlSpoof(nil, true)
end
restoreDeviceSpoof = function() restoreSoftSpoof() end
applyDeviceSpoof = function() return applySoftSpoof() end
function setupControlModeSpoof()
  task.spawn(function() while RUNNING do if STATE.MobileSpoof or STATE.ConsoleSpoof or STATE.VRSpoof then applyDeviceSpoof() end; task.wait(1) end end)
end

local FOV_COLOR_PRESETS = {
  White = Color3.fromRGB(235, 245, 255),
  Blue = Color3.fromRGB(84, 146, 255),
  Cyan = Color3.fromRGB(70, 225, 255),
  Green = Color3.fromRGB(80, 255, 145),
  Yellow = Color3.fromRGB(255, 220, 80),
  Red = Color3.fromRGB(255, 70, 70),
  Pink = Color3.fromRGB(255, 95, 190),
}

function getFOVColor()
  return FOV_COLOR_PRESETS[tostring(STATE.AimFOVColor or "White")] or FOV_COLOR_PRESETS.White
end

local fovGui, fovFrame, fovStroke = nil, nil, nil
local function getFOVGuiParent()
  if type(gethui) == "function" then
    local ok, hui = pcall(gethui)
    if ok and hui then
      return hui
    end
  end
  local okCore, coreGui = pcall(function()
    return game:GetService("CoreGui")
  end)
  if okCore and coreGui then
    return coreGui
  end
  local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
  return playerGui
end
local function ensureFOVGui()
  if fovFrame and fovFrame.Parent and fovStroke then
    return true
  end
  local parent = getFOVGuiParent()
  if not parent then
    return false
  end
  
  fovGui = Instance.new("ScreenGui")
  fovGui.Name = "NX_FOV_UI"
  fovGui.ResetOnSpawn = false
  fovGui.IgnoreGuiInset = true
  fovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  fovGui.DisplayOrder = 5
  local okParent = pcall(function()
    fovGui.Parent = parent
  end)
  if (not okParent or not fovGui.Parent) and LocalPlayer then
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if playerGui then
      pcall(function()
        fovGui.Parent = playerGui
      end)
    end
  end
  if not fovGui.Parent then
    return false
  end
  
  fovFrame = Instance.new("Frame")
  fovFrame.Name = "Circle"
  fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
  fovFrame.BackgroundTransparency = 1
  fovFrame.BorderSizePixel = 0
  fovFrame.ZIndex = 1
  fovFrame.Visible = false
  fovFrame.Parent = fovGui
  
  local corner = Instance.new("UICorner")
  corner.CornerRadius = UDim.new(1, 0)
  corner.Parent = fovFrame
  
  fovStroke = Instance.new("UIStroke")
  fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  fovStroke.Thickness = 2
  fovStroke.Transparency = 0
  fovStroke.Parent = fovFrame
  
  if getgenv then
    getgenv().NX_FOV_GUI = fovGui
  end
  return true
end
updateFOV = function()
  if not Camera then return end
  pcall(function()
    local visible = STATE.AimFOVCircle == true and STATE.AimFOVHidden ~= true
    local radius = safeNum(STATE.AimFOV)
    local center = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y * 0.5)
    local color = getFOVColor()
    
    if ensureFOVGui() then
      fovFrame.Visible = visible
      if visible then
        fovFrame.Size = UDim2.new(0, radius * 2, 0, radius * 2)
        fovFrame.Position = UDim2.new(0, center.X, 0, center.Y)
        fovStroke.Color = color
      end
    end
  end)
end

local lightingDefaults = {
  Brightness = Lighting.Brightness,
  Ambient = Lighting.Ambient,
  OutdoorAmbient = Lighting.OutdoorAmbient,
  FogEnd = Lighting.FogEnd,
  GlobalShadows = Lighting.GlobalShadows,
}
local terrainDefaults = nil

setFB = function(enabled)
  pcall(function()
    if enabled then
      Lighting.Brightness = 2.5
      Lighting.Ambient = Color3.new(1, 1, 1)
      Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    else
      Lighting.Brightness = lightingDefaults.Brightness
      Lighting.Ambient = lightingDefaults.Ambient
      Lighting.OutdoorAmbient = lightingDefaults.OutdoorAmbient
    end
  end)
end

setNF = function(enabled)
  pcall(function()
    Lighting.FogEnd = enabled and 1e9 or lightingDefaults.FogEnd
  end)
end

setFPS = function(enabled)
  if typeof(setfpscap) == "function" then
    pcall(setfpscap, enabled and 240 or 60)
  end
end

setFPSBoost = function(enabled)
  pcall(function()
    Lighting.GlobalShadows = not enabled and lightingDefaults.GlobalShadows or false
    if settings and settings().Rendering then
      settings().Rendering.QualityLevel = enabled and Enum.QualityLevel.Level01 or Enum.QualityLevel.Automatic
    end
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
      if not terrainDefaults then
        terrainDefaults = {
          WaterWaveSize = terrain.WaterWaveSize,
          WaterWaveSpeed = terrain.WaterWaveSpeed,
          WaterReflectance = terrain.WaterReflectance,
          WaterTransparency = terrain.WaterTransparency,
        }
      end
      terrain.WaterWaveSize = enabled and 0 or terrainDefaults.WaterWaveSize
      terrain.WaterWaveSpeed = enabled and 0 or terrainDefaults.WaterWaveSpeed
      terrain.WaterReflectance = enabled and 0 or terrainDefaults.WaterReflectance
      terrain.WaterTransparency = enabled and 1 or terrainDefaults.WaterTransparency
    end
  end)
end

-- NovaX v1.1 Snap aim assist.
-- Standard Roblox client APIs only: no metatable hooks, no remote firing.
-- Hold Mouse1 to keep the camera aligned; release immediately stops assistance.
local silentAimRng=Random.new()
local silentHoldDown=false
local silentHoldAccepted=false
local silentHoldPartMode="Head"
local silentTargetPart=nil
local silentTargetRefresh=0

local function resolveSilentPartMode(requested)
  local mode=tostring(requested or STATE.SilentTargetPart or "Head")
  if mode~="Random" then return mode end
  local choices={"Head","UpperTorso","LowerTorso","HumanoidRootPart"}
  return choices[silentAimRng:NextInteger(1,#choices)]
end

local function getSilentPartForPlayer(player,mode)
  local character=player and player.Character
  if not character then return nil end
  local head=character:FindFirstChild("Head")
  local upper=character:FindFirstChild("UpperTorso")
  local lower=character:FindFirstChild("LowerTorso")
  local torso=character:FindFirstChild("Torso")
  local root=character:FindFirstChild("HumanoidRootPart")
  if mode=="Head" then return head or upper or torso or root end
  if mode=="UpperTorso" then return upper or torso or lower or root or head end
  if mode=="LowerTorso" then return lower or torso or upper or root or head end
  if mode=="HumanoidRootPart" then return root or torso or upper or lower or head end
  return head or upper or torso or root
end

local function getSilentAimTarget(partMode)
  local cam=workspace.CurrentCamera
  if not cam then return nil end
  local center=cam.ViewportSize*.5
  local best=nil
  local bestMetric=math.huge
  local maxFOV=math.clamp(tonumber(STATE.AimFOV) or 150,20,500)
  local maxRange=math.clamp(tonumber(STATE.AimMaxDist) or 300,20,1000)
  for _,candidate in ipairs(Players:GetPlayers()) do
    if candidate~=LocalPlayer and isAlive(candidate) and isEnemy(candidate,STATE.AimTeamCheck) then
      local part=getSilentPartForPlayer(candidate,partMode)
      if part and part:IsA("BasePart") and part.Parent then
        local delta=part.Position-cam.CFrame.Position
        local distance=delta.Magnitude
        if distance>0 and distance<=maxRange then
          local screen,onScreen=cam:WorldToViewportPoint(part.Position)
          if not STATE.AimFOVCircle or (onScreen and screen.Z>0) then
            local pixel=(Vector2.new(screen.X,screen.Y)-Vector2.new(center.X,center.Y)).Magnitude
            if (not STATE.AimFOVCircle or pixel<=maxFOV) and (not STATE.SilentVisibleCheck or isVisible(part)) then
              local metric=STATE.AimFOVCircle and (pixel+distance*.003)
                or (1-cam.CFrame.LookVector:Dot(delta.Unit))+distance*.000001
              if metric<bestMetric then best,bestMetric=part,metric end
            end
          end
        end
      end
    end
  end
  return best
end

local function releaseSilentAimHold()
  silentHoldDown=false
  silentHoldAccepted=false
  silentTargetPart=nil
  silentTargetRefresh=0
end

local function beginSilentAimHold()
  if not RUNNING or not STATE.SilentAim or STATE.SilentAimMode~="Snap" then return end
  if silentHoldDown then return end
  silentHoldDown=true
  silentHoldPartMode=resolveSilentPartMode()
  local chance=math.clamp(math.floor(tonumber(STATE.SilentHitChance) or 100),0,100)
  -- One roll per physical press. Holding does not spam or reroll every frame.
  silentHoldAccepted=chance>0 and (chance>=100 or silentAimRng:NextInteger(1,100)<=chance)
  silentTargetRefresh=.05
  if silentHoldAccepted then
    silentTargetPart=getSilentAimTarget(silentHoldPartMode)
  end
end

local function updateSilentAimHold(dt)
  if not silentHoldDown then return end
  if not RUNNING or not STATE.SilentAim or STATE.SilentAimMode~="Snap" then
    releaseSilentAimHold()
    return
  end
  if not silentHoldAccepted then return end
  silentTargetRefresh+=dt
  if silentTargetRefresh>=.05 or not silentTargetPart or not silentTargetPart.Parent then
    silentTargetRefresh=0
    silentTargetPart=getSilentAimTarget(silentHoldPartMode)
  end
  local cam=workspace.CurrentCamera
  local target=silentTargetPart
  if not cam or not target or not target.Parent then return end
  local origin=cam.CFrame.Position
  local direction=target.Position-origin
  if direction.Magnitude>.01 then
    cam.CFrame=CFrame.lookAt(origin,target.Position,cam.CFrame.UpVector)
  end
end

local silentAimGate
local function hasSilentHookSupport()
  return SUPPORT.MetaHook and typeof(hookmetamethod)=="function"
end
local function installInternalRayHook()
  if not hasSilentHookSupport() then return false end
  local env=(getgenv and getgenv()) or _G
  if type(env.NX_INTERNAL_RAY_HOOK)=="table" and env.NX_INTERNAL_RAY_HOOK.installed then
    silentAimGate=env.NX_INTERNAL_RAY_HOOK
    return true
  end
  local gate={installed=false,enabled=false,untilTime=0,target=nil}
  local original
  local hookOK,hookError=pcall(function()
    original=hookmetamethod(game,"__namecall",newcclosure(function(self,...)
      local method=getnamecallmethod()
      if method~="Raycast" or self~=workspace or not gate.enabled then
        return original(self,...)
      end
      if type(checkcaller)=="function" then
        local okCheck,localCall=pcall(checkcaller)
        if okCheck and localCall then return original(self,...) end
      end
      local args={...}
      local origin,direction=args[1],args[2]
      local target=gate.target
      if typeof(origin)~="Vector3" or typeof(direction)~="Vector3"
        or not target or not target.Parent or direction.Magnitude<12 then
        return original(self,...)
      end
      local cam=workspace.CurrentCamera
      if not cam or (origin-cam.CFrame.Position).Magnitude>12 then
        return original(self,...)
      end
      local toward=target.Position-origin
      if toward.Magnitude<.5 then return original(self,...) end
      args[2]=toward.Unit*direction.Magnitude
      return original(self,table.unpack(args))
    end))
  end)
  if not hookOK then
    nxWarn("[NovaX] Internal hook could not be installed: "..tostring(hookError))
    return false
  end
  gate.installed=true
  env.NX_INTERNAL_RAY_HOOK=gate
  silentAimGate=gate
  return true
end
local hookHold=false
local hookRollAccepted=false
local hookPartMode="Head"
local hookClock=0
local function clearHookHold()
  hookHold=false
  hookRollAccepted=false
  if silentAimGate then silentAimGate.enabled=false; silentAimGate.target=nil end
end
local function silentEnd()
  releaseSilentAimHold()
  clearHookHold()
end
setupGrabber=function()
  if hasSilentHookSupport() then installInternalRayHook() end
  addConnection("silent_aim_begin",UserInputService.InputBegan:Connect(function(input,processed)
    if processed or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    if STATE.SilentAimMode=="Snap" then
      beginSilentAimHold()
    elseif STATE.SilentAimMode=="Hook (Internal)" and RUNNING and STATE.SilentAim then
      if not silentAimGate and not installInternalRayHook() then
        nxWarn("[NovaX] Internal Hook unavailable")
        return
      end
      hookHold=true
      hookPartMode=resolveSilentPartMode(STATE.SilentHookTargetPart)
      local chance=math.clamp(math.floor(tonumber(STATE.SilentHookHitChance) or 100),0,100)
      hookRollAccepted=chance>0 and (chance>=100 or silentAimRng:NextInteger(1,100)<=chance)
      local target=hookRollAccepted and getSilentAimTarget(hookPartMode) or nil
      silentAimGate.target=target
      silentAimGate.enabled=target~=nil
    end
  end))
  addConnection("silent_aim_end",UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then silentEnd() end
  end))
  addConnection("silent_aim_focus_release",UserInputService.WindowFocusReleased:Connect(silentEnd))
  addConnection("silent_aim_render",RunService.RenderStepped:Connect(updateSilentAimHold))
  addConnection("silent_aim_hook_update",RunService.Heartbeat:Connect(function(dt)
    if not RUNNING or not STATE.SilentAim or STATE.SilentAimMode~="Hook (Internal)"
       or not hookHold or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
      clearHookHold()
      return
    end
    hookClock+=dt
    if hookClock>=.05 then
      hookClock=0
      local target=hookRollAccepted and getSilentAimTarget(hookPartMode) or nil
      if silentAimGate then silentAimGate.target=target; silentAimGate.enabled=target~=nil end
    end
  end))
  return true
end

do
local espObjs, espHighlights, espState, espPlayerConnections = {}, {}, {}, {}
local drawingReady = typeof(Drawing) == "table" and typeof(Drawing.new) == "function"
local ESP_SKELETON_KEYS = {"S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11", "S12", "S13", "S14"}
local ESP_DRAW_KEYS = {"Name", "Health", "Distance", "L1", "L2", "L3", "L4", "HPBG", "HP"}
for _, key in ipairs(ESP_SKELETON_KEYS) do
  table.insert(ESP_DRAW_KEYS, key)
end
local ESP_TEXT_KEYS = {"Name", "Health", "Distance"}
local ESP_BOX_KEYS = {"L1", "L2", "L3", "L4"}
local ESP_ENEMY_COLOR = Color3.fromRGB(255, 50, 50)
local ESP_TEAM_COLOR = Color3.fromRGB(0, 145, 255)
local ESP_TEXT_COLOR = Color3.fromRGB(215, 220, 230)
local ESP_HP_BG_COLOR = Color3.fromRGB(20, 20, 20)
local ESP_OUTLINE_COLOR = Color3.new(1, 1, 1)
local ESP_HEALTH_COLORS = {}
function getHealthColor(ratio)
  local percent = math.clamp(math.floor(((tonumber(ratio) or 0) * 100) + 0.5), 0, 100)
  local color = ESP_HEALTH_COLORS[percent]
  if not color then
    local normalized = percent / 100
    color = Color3.fromRGB(math.floor(255 * (1 - normalized)), math.floor(255 * normalized), 45)
    ESP_HEALTH_COLORS[percent] = color
  end
  return color, percent
end
function hideESP(esp, player)
  if not esp then
    return
  end
  local meta = player and espState[player]
  if meta and meta.hidden then
    return
  end
  for _, key in ipairs(ESP_DRAW_KEYS) do
    local obj = esp[key]
    if obj then
      pcall(function()
        if obj.Visible then
          obj.Visible = false
        end
      end)
    end
  end
  if meta then
    meta.hidden = true
    meta.boxVisible = false
    meta.nameVisible = false
    meta.healthVisible = false
    meta.distanceVisible = false
    meta.healthBarVisible = false
    meta.skeletonVisible = false
  end
end
function setHighlightEnabled(player, enabled)
  local hl = espHighlights[player]
  if not hl then
    return
  end
  if not hl.Parent then
    espHighlights[player] = nil
    return
  end
  local shouldEnable = enabled == true
  local meta = player and espState[player]
  pcall(function()
    if hl.Enabled ~= shouldEnable then
      hl.Enabled = shouldEnable
    end
  end)
  if meta then
    meta.hlEnabled = shouldEnable
  end
end
function cleanESP(player)
  if espPlayerConnections[player] then
    for _, conn in pairs(espPlayerConnections[player]) do
      pcall(function() conn:Disconnect() end)
    end
    espPlayerConnections[player] = nil
  end
  if espObjs[player] then for _, key in ipairs(ESP_DRAW_KEYS) do local obj = espObjs[player][key]; if obj then pcall(function() obj:Remove() end) end end; espObjs[player]=nil end
  if espHighlights[player] then pcall(function() espHighlights[player]:Destroy() end); espHighlights[player]=nil end
  espState[player] = nil
end
cleanAllESP = function()
  local seen = {}
  for p in pairs(espObjs) do seen[p] = true end
  for p in pairs(espHighlights) do seen[p] = true end
  for p in pairs(espPlayerConnections) do seen[p] = true end
  for p in pairs(seen) do cleanESP(p) end
  espObjs, espHighlights, espState, espPlayerConnections = {}, {}, {}, {}
end
function createESPHighlight(player, char)
  if not player or player == LocalPlayer or not char then
    return nil
  end
  local hl = espHighlights[player]
  if hl and hl.Parent == char then
    return hl
  end
  if hl then
    pcall(function() hl:Destroy() end)
    espHighlights[player] = nil
  end
  
  local ok, newHl = pcall(function()
    local created = Instance.new("Highlight")
    created.Name = "NX_ESP_HL"
    created.Archivable = false
    created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    created.OutlineTransparency = 0
    created.FillTransparency = 0.72
    created.FillColor = ESP_ENEMY_COLOR
    created.OutlineColor = ESP_OUTLINE_COLOR
    created.Adornee = char
    created.Enabled = false
    created.Parent = char
    return created
  end)
  
  if ok and newHl then
    espHighlights[player] = newHl
    return newHl
  end
  return nil
end
function trackESPPlayer(player)
  if not player or player == LocalPlayer or espPlayerConnections[player] then
    return
  end
  espPlayerConnections[player] = {
    character = player.CharacterAdded:Connect(function(char)
      hideESP(espObjs[player], player)
      if not drawingReady then
        createESPHighlight(player, char)
      end
    end)
  }
  if player.Character and not drawingReady then
    createESPHighlight(player, player.Character)
  end
end
addConnection("esp_add", Players.PlayerAdded:Connect(trackESPPlayer))
addConnection("esp_remove", Players.PlayerRemoving:Connect(cleanESP))
for _, player in ipairs(Players:GetPlayers()) do
  trackESPPlayer(player)
end
function ensureHL(player, char, enemy, enabled)
  if not player or not char then
    return nil
  end
  if enabled ~= true and drawingReady then
    if espHighlights[player] then
      pcall(function() espHighlights[player]:Destroy() end)
      espHighlights[player] = nil
    end
    local meta = espState[player]
    if meta then
      meta.hlEnabled = false
      meta.hlChar = nil
    end
    return nil
  end
  local hl = espHighlights[player]
  if not hl or not hl.Parent or hl.Parent ~= char then
    hl = createESPHighlight(player, char)
  end
  if not hl then
    return nil
  end
  local fillColor = enemy and ESP_ENEMY_COLOR or ESP_TEAM_COLOR
  local shouldEnable = enabled == true
  local meta = espState[player] or {}
  espState[player] = meta
  if meta.hlChar == char and meta.hlEnemy == enemy and meta.hlEnabled == shouldEnable then
    return hl
  end
  pcall(function()
    if hl.Adornee ~= char then hl.Adornee = char end
    if hl.FillColor ~= fillColor then hl.FillColor = fillColor end
    if hl.OutlineColor ~= ESP_OUTLINE_COLOR then hl.OutlineColor = ESP_OUTLINE_COLOR end
    if hl.Enabled ~= shouldEnable then hl.Enabled = shouldEnable end
  end)
  meta.hlChar = char
  meta.hlEnemy = enemy
  meta.hlEnabled = shouldEnable
  return hl
end
function createESP(player)
  if not drawingReady then return nil end
  if espObjs[player] then return espObjs[player] end
  local ok, esp = pcall(function()
    local created = {Name=Drawing.new("Text"),Health=Drawing.new("Text"),Distance=Drawing.new("Text"),L1=Drawing.new("Line"),L2=Drawing.new("Line"),L3=Drawing.new("Line"),L4=Drawing.new("Line"),HPBG=Drawing.new("Line"),HP=Drawing.new("Line")}
    for _, key in ipairs(ESP_SKELETON_KEYS) do
      created[key] = Drawing.new("Line")
    end
    return created
  end)
  if not ok or type(esp) ~= "table" then
    drawingReady = false
    return nil
  end
  for _, key in ipairs(ESP_DRAW_KEYS) do
    if not esp[key] then
      for _, removeKey in ipairs(ESP_DRAW_KEYS) do
        local obj = esp[removeKey]
        if obj then
          pcall(function() obj:Remove() end)
        end
      end
      drawingReady = false
      return nil
    end
  end
  for _, key in ipairs(ESP_DRAW_KEYS) do
    local obj = esp[key]
    pcall(function()
      obj.Visible = false
      if obj.Thickness ~= nil then
        obj.Thickness = (key == "HPBG" or key == "HP") and 3 or (string.sub(key, 1, 1) == "S" and 1 or 2)
      end
      if key == "HPBG" and obj.Color ~= nil then
        obj.Color = ESP_HP_BG_COLOR
      end
    end)
  end
  for _, k in ipairs(ESP_TEXT_KEYS) do pcall(function() esp[k].Center=true; esp[k].Outline=true; esp[k].Font=2; esp[k].Size=(k=="Name") and 14 or 12 end) end
  espObjs[player]=esp
  espState[player] = espState[player] or {hidden = true}
  return esp
end
function screenBounds(char, root, widthFactor)
  if not char or not root or not Camera then
    return nil
  end
  local head = char:FindFirstChild("Head") or root
  local ok, headPos, headOn, rootPos, rootOn = pcall(function()
    local hp, ho = Camera:WorldToViewportPoint(head.Position + V3(0, 0.55, 0))
    local rp, ro = Camera:WorldToViewportPoint(root.Position - V3(0, 2.6, 0))
    return hp, ho, rp, ro
  end)
  if not ok or not headOn or not rootOn then
    return nil
  end
  
  local height = math.abs(rootPos.Y - headPos.Y)
  if height < 10 then
    return nil
  end
  
  widthFactor = math.clamp(tonumber(widthFactor) or 0.45, 0.3, 0.7)
  local halfW = math.max(6, height * widthFactor)
  local centerX = headPos.X
  local topY = math.min(headPos.Y, rootPos.Y)
  local bottomY = topY + height
  
  return centerX - halfW, topY, centerX + halfW, bottomY
end
function setBox(esp,x1,y1,x2,y2,color)
  esp.L1.From,esp.L1.To=Vector2.new(x1,y1),Vector2.new(x2,y1); esp.L2.From,esp.L2.To=Vector2.new(x2,y1),Vector2.new(x2,y2); esp.L3.From,esp.L3.To=Vector2.new(x2,y2),Vector2.new(x1,y2); esp.L4.From,esp.L4.To=Vector2.new(x1,y2),Vector2.new(x1,y1)
  for _, k in ipairs(ESP_BOX_KEYS) do
    local line = esp[k]
    if line.Color ~= color then line.Color = color end
    if not line.Visible then line.Visible = true end
  end
end
function hideBox(esp)
  for _, k in ipairs(ESP_BOX_KEYS) do
    local line = esp[k]
    if line and line.Visible then
      line.Visible = false
    end
  end
end
function hideSkeleton(esp)
  if not esp then return end
  for _, key in ipairs(ESP_SKELETON_KEYS) do
    local line = esp[key]
    if line and line.Visible then
      line.Visible = false
    end
  end
end

local ESP_SKELETON_BONES = {
  {{"Head"}, {"UpperTorso", "Torso", "HumanoidRootPart"}},
  {{"UpperTorso", "Torso"}, {"LowerTorso", "HumanoidRootPart"}},
  {{"UpperTorso", "Torso"}, {"LeftUpperArm", "Left Arm"}},
  {{"LeftUpperArm", "Left Arm"}, {"LeftLowerArm", "LeftHand", "Left Arm"}},
  {{"LeftLowerArm", "Left Arm"}, {"LeftHand", "Left Arm"}},
  {{"UpperTorso", "Torso"}, {"RightUpperArm", "Right Arm"}},
  {{"RightUpperArm", "Right Arm"}, {"RightLowerArm", "RightHand", "Right Arm"}},
  {{"RightLowerArm", "Right Arm"}, {"RightHand", "Right Arm"}},
  {{"LowerTorso", "Torso", "HumanoidRootPart"}, {"LeftUpperLeg", "Left Leg"}},
  {{"LeftUpperLeg", "Left Leg"}, {"LeftLowerLeg", "LeftFoot", "Left Leg"}},
  {{"LeftLowerLeg", "Left Leg"}, {"LeftFoot", "Left Leg"}},
  {{"LowerTorso", "Torso", "HumanoidRootPart"}, {"RightUpperLeg", "Right Leg"}},
  {{"RightUpperLeg", "Right Leg"}, {"RightLowerLeg", "RightFoot", "Right Leg"}},
  {{"RightLowerLeg", "Right Leg"}, {"RightFoot", "Right Leg"}},
}

local function findCharacterPart(char, names)
  if not char then return nil end
  for _, name in ipairs(names) do
    local part = char:FindFirstChild(name)
    if part and part:IsA("BasePart") then
      return part
    end
  end
  return nil
end

local espEnemyCache = setmetatable({}, {__mode = "k"})
local skelPartCache = setmetatable({}, {__mode = "k"})

function setSkeleton(esp, char, color)
  local used = 0
  local cache = skelPartCache[char]
  if not cache then
    cache = {}
    skelPartCache[char] = cache
  end
  for index, bone in ipairs(ESP_SKELETON_BONES) do
    local line = esp[ESP_SKELETON_KEYS[index]]
    local c = cache[index]
    if not c or not c[1] or not c[1].Parent or not c[2] or not c[2].Parent then
      c = {findCharacterPart(char, bone[1]), findCharacterPart(char, bone[2])}
      cache[index] = c
    end
    local partA, partB = c[1], c[2]
    if line and partA and partB and partA ~= partB then
      local a, aOn = worldToScreen(partA.Position)
      local b, bOn = worldToScreen(partB.Position)
      if aOn and bOn then
        line.From = a
        line.To = b
        if line.Color ~= color then line.Color = color end
        if not line.Visible then line.Visible = true end
        used = index
      elseif line.Visible then
        line.Visible = false
      end
    elseif line and line.Visible then
      line.Visible = false
    end
  end
  for index = used + 1, #ESP_SKELETON_KEYS do
    local line = esp[ESP_SKELETON_KEYS[index]]
    if line and line.Visible then
      line.Visible = false
    end
  end
end

function updateESPPlayer(p, cameraPos, maxDist, boxWidthFactor, showEnemy, showTeam, showName, showHealth, showDistance, showBox, showSkeleton)
  if not p or p == LocalPlayer then
    return
  end
  local char = p.Character
  local enemy = espEnemyCache[p]
  if enemy == nil then
    enemy = isEnemy(p, true)
    espEnemyCache[p] = enemy
  end
  local show = char and ((enemy and showEnemy) or ((not enemy) and showTeam))
  if not show then
    hideESP(espObjs[p], p)
    setHighlightEnabled(p, false)
    return
  end
  
  local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
  local hum = char and char:FindFirstChildOfClass("Humanoid")
  if not root or not hum or hum.Health <= 0 then
    hideESP(espObjs[p], p)
    setHighlightEnabled(p, false)
    return
  end
  
  local dist = (cameraPos - root.Position).Magnitude
  if dist > maxDist then
    hideESP(espObjs[p], p)
    setHighlightEnabled(p, false)
    return
  end
  
  local wantsDrawing = showName or showHealth or showDistance or showBox or showSkeleton
  local x1, y1, x2, y2 = nil, nil, nil, nil
  if drawingReady and wantsDrawing then
    x1, y1, x2, y2 = screenBounds(char, root, boxWidthFactor)
    if not x1 then
      hideESP(espObjs[p], p)
      setHighlightEnabled(p, false)
      return
    end
  elseif not wantsDrawing then
    hideESP(espObjs[p], p)
  end
  
  ensureHL(p, char, enemy, (not drawingReady) and true or false)
  if not drawingReady or not wantsDrawing then
    return
  end
  
  local esp = createESP(p)
  if not esp then
    return
  end
  
  local meta = espState[p] or {}
  espState[p] = meta
  meta.hidden = false
  local color = enemy and ESP_ENEMY_COLOR or ESP_TEAM_COLOR
  
  if showBox then
    setBox(esp, x1, y1, x2, y2, color)
    meta.boxVisible = true
  elseif meta.boxVisible ~= false then
    hideBox(esp)
    meta.boxVisible = false
  end
  
  if showSkeleton then
    setSkeleton(esp, char, color)
    meta.skeletonVisible = true
  elseif meta.skeletonVisible ~= false then
    hideSkeleton(esp)
    meta.skeletonVisible = false
  end
  
  if showName then
    local nameText = tostring(p.DisplayName or p.Name)
    if meta.nameText ~= nameText then
      esp.Name.Text = nameText
      meta.nameText = nameText
    end
    esp.Name.Position = Vector2.new((x1 + x2) * 0.5, y1 - 16)
    if meta.nameColor ~= color then
      esp.Name.Color = color
      meta.nameColor = color
    end
    if meta.nameVisible ~= true then
      esp.Name.Visible = true
      meta.nameVisible = true
    end
  elseif meta.nameVisible ~= false then
    esp.Name.Visible = false
    meta.nameVisible = false
  end
  
  local ratio = 0
  local hpColor = ESP_TEXT_COLOR
  if showHealth then
    ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
    local healthPercent
    hpColor, healthPercent = getHealthColor(ratio)
    local healthText = tostring(healthPercent) .. "%"
    if meta.healthText ~= healthText then
      esp.Health.Text = healthText
      meta.healthText = healthText
    end
    esp.Health.Position = Vector2.new((x1 + x2) * 0.5, y1 - 4)
    if meta.healthColor ~= hpColor then
      esp.Health.Color = hpColor
      esp.HP.Color = hpColor
      meta.healthColor = hpColor
    end
    if meta.healthVisible ~= true then
      esp.Health.Visible = true
      meta.healthVisible = true
    end
    
    esp.HPBG.From = Vector2.new(x1 - 6, y1)
    esp.HPBG.To = Vector2.new(x1 - 6, y2)
    esp.HP.From = Vector2.new(x1 - 6, y2)
    esp.HP.To = Vector2.new(x1 - 6, y2 - ((y2 - y1) * ratio))
    if meta.healthBarVisible ~= true then
      esp.HPBG.Visible = true
      esp.HP.Visible = true
      meta.healthBarVisible = true
    end
  else
    if meta.healthVisible ~= false then
      esp.Health.Visible = false
      meta.healthVisible = false
    end
    if meta.healthBarVisible ~= false then
      esp.HPBG.Visible = false
      esp.HP.Visible = false
      meta.healthBarVisible = false
    end
  end
  
  if showDistance then
    local distanceText = tostring(math.floor(dist + 0.5)) .. "m"
    if meta.distanceText ~= distanceText then
      esp.Distance.Text = distanceText
      meta.distanceText = distanceText
    end
    esp.Distance.Position = Vector2.new((x1 + x2) * 0.5, y2 + 3)
    if meta.distanceColor ~= ESP_TEXT_COLOR then
      esp.Distance.Color = ESP_TEXT_COLOR
      meta.distanceColor = ESP_TEXT_COLOR
    end
    if meta.distanceVisible ~= true then
      esp.Distance.Visible = true
      meta.distanceVisible = true
    end
  elseif meta.distanceVisible ~= false then
    esp.Distance.Visible = false
    meta.distanceVisible = false
  end
end
function setupESP()
  local last=0
  local wasEnabled=false
  local cursor=1
  local activeESPPlayers={}
  local activeESPSet={}
  local lastActiveScan=0
  local noTargetsHidden=false
  local espSignal = RunService.RenderStepped or RunService.Heartbeat
  addConnection("esp", espSignal:Connect(function()
    if not RUNNING or not Camera then return end
    if not STATE.ESPEnabled then
      if wasEnabled then
        for p, esp in pairs(espObjs) do
          hideESP(esp, p)
        end
        for p in pairs(espHighlights) do
          setHighlightEnabled(p, false)
        end
        wasEnabled = false
        noTargetsHidden = false
        activeESPPlayers = {}
        activeESPSet = {}
        lastActiveScan = 0
      end
      return
    end
    
    local now = tick()
    updateCache()
    local showEnemy = STATE.ESPEnemy == true
    local showTeam = STATE.ESPTeam == true
    local showName = STATE.ESPName == true
    local showHealth = STATE.ESPHealth == true
    local showDistance = STATE.ESPDistance == true
    local showBox = STATE.ESPBox == true
    local showSkeleton = STATE.ESPSkeleton == true

    if not showEnemy and not showTeam then
      if not noTargetsHidden then
        for p, esp in pairs(espObjs) do
          hideESP(esp, p)
        end
        noTargetsHidden = true
      end
      last = now
      return
    end

    if now - lastActiveScan > 0.25 then
      lastActiveScan = now
      activeESPPlayers = {}
      activeESPSet = {}
      for _, p in ipairs(cachedPlayers) do
        if p and p ~= LocalPlayer then
          local char = p.Character
          local hum = char and char:FindFirstChildOfClass("Humanoid")
          if hum and hum.Health > 0 then
            local enemy = isEnemy(p, true)
            espEnemyCache[p] = enemy
            if (enemy and showEnemy) or ((not enemy) and showTeam) then
              activeESPPlayers[#activeESPPlayers + 1] = p
              activeESPSet[p] = true
            end
          end
        end
      end
      for p, esp in pairs(espObjs) do
        if not activeESPSet[p] then
          hideESP(esp, p)
        end
      end
    end

    local playerCount = #activeESPPlayers
    if playerCount <= 0 then
      if not noTargetsHidden then
        for p, esp in pairs(espObjs) do
          hideESP(esp, p)
        end
        noTargetsHidden = true
      end
      last = now
      return
    end
    noTargetsHidden = false

    last = now
    wasEnabled = true

    local budget = playerCount
    
    local cameraPos = Camera.CFrame.Position
    local maxDist = math.max(0, safeNum(STATE.ESPMaxDistance))
    local boxWidthFactor = math.clamp(safeNum(STATE.ESPBoxScale) / 100, 0.3, 0.7)
    
    for _ = 1, budget do
      if cursor > playerCount then
        cursor = 1
      end
      local p = activeESPPlayers[cursor]
      cursor = cursor + 1
      local ok = pcall(updateESPPlayer, p, cameraPos, maxDist, boxWidthFactor, showEnemy, showTeam, showName, showHealth, showDistance, showBox, showSkeleton)
      if not ok and p then
        hideESP(espObjs[p], p)
        setHighlightEnabled(p, false)
      end
    end
  end))
end
end
local speedBV, flyBV, flyBG, flyActive = nil,nil,nil,false
local noClipOriginal = {}
local antiHitPose = {char=nil, neck=nil, waist=nil}
local antiHitOriginalHumanoid, antiHitOriginalAutoRotate = nil, nil
local headGuard = {char=nil, nextScan=0, nextDodge=0, dodgeUntil=0, lateral=nil, threat=0}
local lastInfJumpAt = 0
function clearSpeed() if speedBV then pcall(function() speedBV:Destroy() end) end; speedBV=nil end
function stopFly() if flyBV then pcall(function() flyBV:Destroy() end) end; if flyBG then pcall(function() flyBG:Destroy() end) end; flyBV,flyBG,flyActive=nil,nil,false; local hum=getHumanoid(); if hum then pcall(function() hum.PlatformStand=false end); pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end) end end
function restoreNoClip() for part,old in pairs(noClipOriginal) do if part and part.Parent then pcall(function() part.CanCollide=old end) end end; noClipOriginal={} end
restoreAntiHitPose = function()
  pcall(function()
    if antiHitPose.neck and antiHitPose.neck.Parent then antiHitPose.neck.Transform=CFrame.new() end
    if antiHitPose.waist and antiHitPose.waist.Parent then antiHitPose.waist.Transform=CFrame.new() end
  end)
  antiHitPose={char=nil,neck=nil,waist=nil}
  headGuard.dodgeUntil=0
  headGuard.lateral=nil
end
restoreAntiHitMovement = function()
  if antiHitOriginalHumanoid and antiHitOriginalHumanoid.Parent and antiHitOriginalAutoRotate~=nil then
    pcall(function() antiHitOriginalHumanoid.AutoRotate=antiHitOriginalAutoRotate end)
  end
  antiHitOriginalHumanoid=nil
  antiHitOriginalAutoRotate=nil
end
local function setAntiHitAutoRotate(hum,value)
  if antiHitOriginalHumanoid~=hum then
    restoreAntiHitMovement()
    antiHitOriginalHumanoid=hum
    antiHitOriginalAutoRotate=hum.AutoRotate
  end
  hum.AutoRotate=value
end
function getAntiHitJoints()
  local char=getChar()
  if not char then return nil end
  if antiHitPose.char==char then return antiHitPose end
  restoreAntiHitPose()
  local torso=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
  local head=char:FindFirstChild("Head")
  antiHitPose={char=char,neck=nil,waist=nil}
  if head then antiHitPose.neck=head:FindFirstChild("Neck") end
  if not antiHitPose.neck and torso then antiHitPose.neck=torso:FindFirstChild("Neck") end
  if torso then antiHitPose.waist=torso:FindFirstChild("Waist") end
  return antiHitPose
end
-- Client-visible threat estimation: use the actual R15 head/hitbox locations as
-- sensing points, but NEVER resize/move the game's hitboxes or fake immunity.
local function sampleHeadThreat(char,root)
  local head=char:FindFirstChild("Head")
  if not head or not head:IsA("BasePart") then return nil,0 end
  local points={head.Position}
  for _,name in ipairs({"HitboxHead","PhysicalHitboxHead","HitboxHeadSmall"}) do
    local part=char:FindFirstChild(name)
    if part and part:IsA("BasePart") then points[#points+1]=part.Position end
  end
  local best,score=nil,0
  for _,opponent in ipairs(Players:GetPlayers()) do
    if opponent~=LocalPlayer and (not LocalPlayer.Team or opponent.Team~=LocalPlayer.Team) then
      local enemy=opponent.Character
      local ehrp=enemy and enemy:FindFirstChild("HumanoidRootPart")
      local ehead=enemy and enemy:FindFirstChild("Head")
      local ehuman=enemy and enemy:FindFirstChildOfClass("Humanoid")
      if ehrp and ehead and ehuman and ehuman.Health>0 then
        local origin=ehead.Position
        local dist=(head.Position-origin).Magnitude
        if dist>2 and dist<105 then
          local facing=ehrp.CFrame.LookVector
          local aim=ehead.CFrame.LookVector
          for _,point in ipairs(points) do
            local v=point-origin
            if v.Magnitude>1 then
              local direction=v.Unit
              local alignment=math.max(facing:Dot(direction),aim:Dot(direction))
              if alignment>0.9 then
                local candidate=alignment+(105-dist)*0.001
                if candidate>score then
                  local los=RaycastParams.new()
                  los.FilterType=Enum.RaycastFilterType.Exclude
                  los.FilterDescendantsInstances={enemy,char}
                  los.IgnoreWater=true
                  local obstruction=workspace:Raycast(origin,v,los)
                  if not obstruction then
                    local horizontal=Vector3.new(direction.X,0,direction.Z)
                    if horizontal.Magnitude>0.05 then
                      local unit=horizontal.Unit
                      best=Vector3.new(-unit.Z,0,unit.X)
                      score=candidate
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return best,score
end
local function applyHeadGuard(t,root,hum)
  local char=getChar()
  if not char or not char:FindFirstChild("UpperTorso") then return end
  if headGuard.char~=char then
    headGuard={char=char,nextScan=0,nextDodge=0,dodgeUntil=0,lateral=nil,threat=0}
  end
  -- Head remains at its normal position; orbital visuals are updated
  -- independently on RenderStepped. Real hitboxes are not changed.
  local now=os.clock()
  if now>=headGuard.nextScan then
    headGuard.nextScan=now+0.13
    local lateral,risk=sampleHeadThreat(char,root)
    headGuard.threat=risk
    if lateral and STATE.AntiHitGuardDodge and now>=headGuard.nextDodge then
      local side=(math.floor(now*2.7)%2==0) and 1 or -1
      headGuard.lateral=lateral*side
      headGuard.nextDodge=now+0.46
      headGuard.dodgeUntil=now+0.17
    end
  end
  -- Dodge with normal Humanoid movement, preserving the player's current
  -- motion rather than teleporting or editing client/server hitbox sizes.
  if STATE.AntiHitGuardDodge and now<headGuard.dodgeUntil and headGuard.lateral
    and hum.Health>0 and not hum.Sit and hum.FloorMaterial~=Enum.Material.Air
    and not UserInputService:GetFocusedTextBox() then
    local current=hum.MoveDirection
    local proposed=current*0.6+headGuard.lateral*0.9
    if proposed.Magnitude>0.01 then hum:Move(proposed.Unit,false) end
  end
end

-- Head Guard R15 local pose. Unlike the previous version this moves the
-- character's real client-side R15 limb joints, NOT duplicate black body clones.
-- Local Motor6D.Transform is not an invulnerability hook and does not guarantee
-- hitbox/animation replication to the server. The Head itself remains intact.
local HEAD_GUARD_JOINTS={
  {"LeftUpperArm","LeftShoulder"},
  {"LeftLowerArm","LeftElbow"},
  {"LeftHand","LeftWrist"},
  {"RightUpperArm","RightShoulder"},
  {"RightLowerArm","RightElbow"},
  {"RightHand","RightWrist"},
  {"LeftUpperLeg","LeftHip"},
  {"LeftLowerLeg","LeftKnee"},
  {"LeftFoot","LeftAnkle"},
  {"RightUpperLeg","RightHip"},
  {"RightLowerLeg","RightKnee"},
  {"RightFoot","RightAnkle"},
}
local headGuardOrbit={char=nil,motors={},angle=0,active=false}
restoreHeadGuardOrbit=function()
  for _,entry in ipairs(headGuardOrbit.motors) do
    local motor=entry.motor
    if motor and motor.Parent then
      pcall(function()motor.Transform=CFrame.new()end)
    end
  end
  headGuardOrbit={char=nil,motors={},angle=0,active=false}
end
local function setHeadGuardRig(char)
  restoreHeadGuardOrbit()
  local head=char and char:FindFirstChild("Head")
  if not head or not head:IsA("BasePart") then return false end
  for i,info in ipairs(HEAD_GUARD_JOINTS) do
    local part=char:FindFirstChild(info[1])
    local motor=part and part:FindFirstChild(info[2])
    if part and part:IsA("BasePart") and motor and motor:IsA("Motor6D")
      and motor.Part0 and motor.Part1==part then
      local layer=((i-1)%4)+1
      headGuardOrbit.motors[#headGuardOrbit.motors+1]={
        motor=motor,
        part=part,
        slot=(i-1)*(math.pi*2/#HEAD_GUARD_JOINTS),
        layer=layer,
        index=i,
      }
    end
  end
  headGuardOrbit.char=char
  return #headGuardOrbit.motors>0
end
local function stepHeadGuardOrbit(dt)
  local active=RUNNING and STATE.AntiHit and STATE.AntiHitMode=="Head Guard (R15)"
    and not (STATE.FlyEnabled and STATE.FlyToggle)
  local char=LocalPlayer.Character
  local hum=char and char:FindFirstChildOfClass("Humanoid")
  local head=char and char:FindFirstChild("Head")
  if not active or not char or not hum or hum.Health<=0 or
    not head or not head:IsA("BasePart") then
    if headGuardOrbit.char then restoreHeadGuardOrbit() end
    return
  end
  local camera=workspace.CurrentCamera
  -- First person uses the game's original arm/weapon pose.
  local firstPerson=camera and ((camera.CFrame.Position-head.Position).Magnitude<2.5
    or LocalPlayer.CameraMode==Enum.CameraMode.LockFirstPerson)
  if firstPerson then
    if headGuardOrbit.char then restoreHeadGuardOrbit() end
    return
  end
  if headGuardOrbit.char~=char then
    if not setHeadGuardRig(char) then return end
  end
  local speed=math.clamp(safeNum(STATE.AntiHitSpeed),0.4,12)
  headGuardOrbit.angle+=math.clamp(tonumber(dt) or 0,0,0.06)*speed*1.8
  local phase=headGuardOrbit.angle
  local radius=math.clamp(safeNum(STATE.AntiHitOrbitRadius),1.5,6)
  local heights={3.25,1.3,-1.3,-3.25}
  local pivot=head.Position
  -- The head and both torso joints remain in the normal physical R15 chain.
  -- Only arms/legs are repositioned; no damaging hitbox is removed/rewired.
  for _,entry in ipairs(headGuardOrbit.motors) do
    local motor,part=entry.motor,entry.part
    if motor.Parent and motor.Part0 and motor.Part1==part and part.Parent then
      local angle=phase+entry.slot
      local desired=CFrame.new(
        pivot+Vector3.new(math.cos(angle)*radius,
          heights[entry.layer]+math.sin(phase*1.25+entry.index)*0.2,
          math.sin(angle)*radius)
      )*CFrame.Angles(
        math.sin(phase+entry.index)*0.3,
        -angle,
        math.cos(phase*1.4+entry.index)*0.35)
      local ok=pcall(function()
        motor.Transform=(motor.Part0.CFrame*motor.C0):Inverse()*desired*motor.C1
      end)
      if not ok then
        pcall(function()motor.Transform=CFrame.new()end)
      end
    end
  end
end

function applyLobbyAntiHit(t,mode)
  local j=getAntiHitJoints(); if not j then return end; local yaw=math.sin(t*3.1)*1.4; local pitch=math.cos(t*2.7)*0.8; local roll=math.sin(t*3.5)*0.9
  if mode=="Head Orbit" or STATE.AntiHitExperimental then yaw=yaw+t*1.6; roll=roll+math.cos(t*5)*0.55 elseif mode=="Vector Chaos" then yaw=yaw+math.sin(t*6.2)*1.2; pitch=pitch+math.cos(t*4.9)*0.8 end
  if j.neck and j.neck:IsA("Motor6D") then j.neck.Transform=CFrame.Angles(pitch,yaw,roll) end; if j.waist and j.waist:IsA("Motor6D") then j.waist.Transform=CFrame.Angles(pitch*0.2,-yaw*0.25,0) end
end
function setupMovement()
  -- R15 Animator normally sets Motor6D.Transform before PreSimulation.
  -- Apply this local pose afterwards for stable in-game third-person visuals.
  local orbitSignal=RunService.PreSimulation or RunService.Stepped
  addConnection("headGuardOrbit",orbitSignal:Connect(function(a,b)
    local dt=(typeof(b)=="number" and b) or a
    local ok=pcall(stepHeadGuardOrbit,dt)
    if not ok and headGuardOrbit.char then restoreHeadGuardOrbit() end
  end))
  addConnection("move", RunService.Heartbeat:Connect(function()
    if not RUNNING then return end
    pcall(function()
      local root,hum=getRoot(),getHumanoid()
      if STATE.SpeedEnabled and root and hum and hum.MoveDirection.Magnitude>0.1 then if not speedBV or not speedBV.Parent then speedBV=Instance.new("BodyVelocity"); speedBV.MaxForce=V3(1e5,0,1e5); speedBV.Parent=root end; speedBV.Velocity=hum.MoveDirection*safeNum(STATE.SpeedValue) else clearSpeed() end
      if STATE.FlyEnabled and STATE.FlyToggle and root and hum and Camera then
        if not flyActive then flyActive=true; pcall(function() hum.PlatformStand=true end); pcall(function() hum:ChangeState(Enum.HumanoidStateType.Physics) end); flyBV=Instance.new("BodyVelocity"); flyBV.MaxForce=MF; flyBV.Parent=root; flyBG=Instance.new("BodyGyro"); flyBG.MaxTorque=MF; flyBG.Parent=root end
        local dir=V0; if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir=dir+Camera.CFrame.LookVector end; if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir=dir-Camera.CFrame.LookVector end; if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir=dir-Camera.CFrame.RightVector end; if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir=dir+Camera.CFrame.RightVector end; if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir=dir+UP end; if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir=dir-UP end
        flyBV.Velocity=(dir.Magnitude>0 and dir.Unit or V0)*safeNum(STATE.FlySpeed); flyBG.CFrame=CF(root.Position,root.Position+Camera.CFrame.LookVector)
      else if flyActive or flyBV or flyBG then stopFly() end end
      if STATE.NoClip then local char=getChar(); if char then for _,part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then if noClipOriginal[part]==nil then noClipOriginal[part]=part.CanCollide end; part.CanCollide=false end end end else restoreNoClip() end
      if STATE.AntiVoid and root then local killY=workspace.FallenPartsDestroyHeight; if typeof(killY)=="number" and root.Position.Y<=killY+35 and tick()>=(antiVoidNextAt or 0) then antiVoidNextAt=tick()+0.35; root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z); root.CFrame=CFrame.new(root.Position.X,math.max(killY+145,45),root.Position.Z) end end
      if STATE.AntiHit and root and hum and not (STATE.FlyEnabled and STATE.FlyToggle) then
        local t=tick()*math.clamp(safeNum(STATE.AntiHitSpeed),0.4,12)
        local mode=tostring(STATE.AntiHitMode or "Adaptive Jitter")
        if mode=="Head Guard (R15)" then
          -- Keep head and HumanoidRootPart orientation controlled by the game.
          -- Body orbit is a separate local visual layer, never a root spin.
          if antiHitPose.char then restoreAntiHitPose() end
          restoreAntiHitMovement()
          applyHeadGuard(t,root,hum)
        else
          restoreAntiHitPose()
          setAntiHitAutoRotate(hum,false)
          local yaw=t*(mode=="Orbital Drift" and 5.4 or 7.2)
          local pitch=math.sin(t*3.4)*(STATE.AntiHitExperimental and 1.4 or 0.85)
          local roll=math.cos(t*4.1)*(mode=="Vector Chaos" and 1.4 or 0.85)
          if mode=="Head Orbit" then pitch=pitch+math.pi end
          root.CFrame=CFrame.new(root.Position)*CFrame.Angles(pitch,yaw,roll)
        end
      else
        if antiHitPose.char then restoreAntiHitPose() end
        restoreAntiHitMovement()
      end
      if STATE.BunnyHop and hum and hum.MoveDirection.Magnitude>0 and hum.FloorMaterial~=Enum.Material.Air then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
  end))
end
function getInfJumpVelocity(hum)
  local configured = math.clamp(safeNum(STATE.InfJumpHeight), 28, 80)
  if hum and hum.UseJumpPower == false then
    return math.max(28, configured)
  end
  return configured
end
function performInfJump()
  if not RUNNING or not STATE.InfJump then return end
  local now = tick()
  if now - lastInfJumpAt < 0.12 then return end
  lastInfJumpAt = now
  pcall(function()
    local hum, root = getHumanoid(), getRoot()
    if not hum or hum.Health <= 0 then return end
    local jumpVelocity = getInfJumpVelocity(hum)
    hum.Jump = true
    hum:ChangeState(Enum.HumanoidStateType.Jumping)
    if root then
      local v = root.AssemblyLinearVelocity
      root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, jumpVelocity), v.Z)
    end
  end)
end
function setupInfJump()
  addConnection("jump_request", UserInputService.JumpRequest:Connect(function()
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
    performInfJump()
  end))
  addConnection("jump_space", UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Space then
      performInfJump()
    end
  end))
end
backstabBusy,nextBackstabAt=false,0
function getBackstabInterval()
  local interval = math.max(0.08, safeNum(STATE.AutoBackstabInterval) / 1000)
  if STATE.AutoBackstabRandomize then
    local mn = math.max(50, math.min(safeNum(STATE.AutoBackstabRandomMin), safeNum(STATE.AutoBackstabRandomMax)))
    local mx = math.max(mn, safeNum(STATE.AutoBackstabRandomMax))
    interval = math.random(math.floor(mn), math.floor(mx)) / 1000
  end
  return interval
end
function restoreBackstabOrigin(originCF, originCameraCF)
  local myRoot = getRoot()
  if myRoot and originCF then
    pcall(function()
      myRoot.CFrame = originCF
    end)
  end
  if Camera and originCameraCF then
    pcall(function()
      Camera.CFrame = originCameraCF
    end)
  end
end
function doBackstab(targetPlayer)
  local eligible,reason=safeCombatTeleportTarget(targetPlayer)
  if not eligible then return false,0,reason end
  local targetRoot=getPlayerRoot(targetPlayer)
  local myRoot=getRoot()
  if not targetRoot or not myRoot then return false,0,"missing root" end
  if hasSpawnProtection(targetPlayer) then return false,0,"protected" end
  local originCF = myRoot.CFrame
  local originCameraCF = Camera and Camera.CFrame or nil
  local hum = getPlayerHumanoid(targetPlayer)
  local startHealth = hum and hum.Health or 0
  local hit, damage = false, 0
  local ok = false
  pcall(function()
    if safeCombatTeleportTarget(targetPlayer) then
      ok=aimAtTargetBack(targetRoot)
    end
  end)
  if ok then
    task.wait(0.025)
    rightClick()
    local deadline = tick() + 1.15
    while RUNNING and targetRoot.Parent and tick() < deadline do
      if not safeCombatTeleportTarget(targetPlayer) then break end
      aimAtTargetBack(targetRoot)
      hum = getPlayerHumanoid(targetPlayer)
      if not hum or hum.Health <= 0 then
        hit = true
        damage = math.max(damage, startHealth)
        break
      end
      damage = math.max(damage, startHealth - hum.Health)
      if damage >= 50 then
        hit = true
        break
      end
      task.wait(0.03)
    end
  end
  restoreBackstabOrigin(originCF, originCameraCF)
  return hit, damage
end
function setupAutoBackstab()
  task.spawn(function()
    while RUNNING do
      if STATE.AutoBackstab and isRoundStarted() and not inLobbySpawnZone((getRoot() and getRoot().Position) or Vector3.zero)
        and not backstabBusy and tick() >= nextBackstabAt then
        local target = getBackstabTargetPlayer()
        if target then
          if hasSpawnProtection(target) then
            waitForSpawnProtectionGone(target, 6, true)
          else
            backstabBusy = true
            doBackstab(target)
            nextBackstabAt = tick() + getBackstabInterval()
            backstabBusy = false
          end
        end
      end
      task.wait(0.04)
    end
  end)
end
function backstabOnce()
  if not isRoundStarted() then notify("Backstab","Warte bis die Runde gestartet ist",2);return end
  local target=getBackstabTargetPlayer()
  if not target then notify("Backstab","Kein bestaetigtes Duellziel ausserhalb des Spawns",3);return end
  task.spawn(function()
    if safeCombatTeleportTarget(target) then doBackstab(target) end
  end)
end
GUI_READY=false
stateControlRefs={}
aimLockToggleRef,autoAimToggleRef,rageToggleRef,silentToggleRef=nil,nil,nil,nil
combatModeSyncing=false
featureNoticeAt = {}
featureUnavailable = function(name, reason)
  local key = tostring(name or "Feature") .. ":" .. tostring(reason or "")
  local now = tick()
  if featureNoticeAt[key] and now - featureNoticeAt[key] < 7 then
    return
  end
  featureNoticeAt[key] = now
  nxWarn("[NovaX] " .. tostring(name or "Feature") .. ": " .. tostring(reason or "nicht verfuegbar"))
end
function setControlFromState(control,value) if control then pcall(function() if control.Set then control:Set(value) elseif control.SetValue then control:SetValue(value) end end) end end
function bindStateControl(key,control,sync) if not key or not control then return control end; stateControlRefs[key]=stateControlRefs[key] or {}; table.insert(stateControlRefs[key],{control=control,sync=sync}); return control end
function syncStateControlsFromState() for key,refs in pairs(stateControlRefs) do for _,entry in ipairs(refs) do if entry.sync then pcall(entry.sync,STATE[key],entry.control) else setControlFromState(entry.control,STATE[key]) end end end end
function setToggleValue(ref,value) if ref and ref.Set then pcall(function() ref:Set(value) end) end end
function resetAimLockRuntime() aimTarget,aimLockedPlayer=nil,nil; aimLockLostSince=0; clearAimTargetHighlight(); if mouseStepState then mouseStepState.lock=Vector2.new(0,0) end end
function resetAutoAimRuntime() autoAimTarget,autoAimLockedPlayer,autoAimSmoothedPos,autoAimLastPart=nil,nil,nil,nil; autoAimLastRawPos=nil; autoAimVelocity=Vector3.zero; autoAimLostSince,autoAimReleaseUntil,autoAimManualBreakUntil,autoAimBreakScore=0,0,0,0; autoAimMixedUseHead,autoAimMixedNextSwitch,autoAimMixedBlend=true,tick()+0.2,0; if mouseStepState then mouseStepState.auto=Vector2.new(0,0) end end
function resetRageRuntime() rageTarget,rageLockedPlayer,rageNextShotAt=nil,nil,0; rageMixedUseHead,rageMixedNextSwitch,rageMixedBlend=true,0,0; restoreRageWeaponLock() end
function enforceNoHookMode()
  STATE.NoHookMode = "ULTRA"
end
function enforceAlwaysOnChecks()
  STATE.AimTeamCheck = true
  STATE.AimRequireCenter = false
  STATE.TriggerTeamCheck = true
  STATE.TriggerRequireCenter = false
  STATE.TriggerVisibleCheck = true
  STATE.RageVisibilityCheck = false
  STATE.FPSUnlocker = true
  STATE.InfJumpHeight = math.clamp(safeNum(STATE.InfJumpHeight), 28, 80)
end
function enforceAimModeExclusivity(preferredMode)
  local active = preferredMode
  if not active then
    if STATE.RageBot then
      active = "RageBot"
    elseif STATE.AimLock then
      active = "AimLock"
    elseif STATE.AutoAim then
      active = "AutoAim"
    elseif STATE.SilentAim then
      active = "SilentAim"
    end
  end
  STATE.AimLock = active == "AimLock"
  STATE.AutoAim = active == "AutoAim"
  STATE.RageBot = active == "RageBot"
  STATE.SilentAim = active == "SilentAim"
  if active ~= "AimLock" then resetAimLockRuntime() end
  if active ~= "AutoAim" then resetAutoAimRuntime() end
  if active ~= "RageBot" then resetRageRuntime() end
end
function applyExclusiveMode(modeName,enabled)
  if combatModeSyncing then return end; combatModeSyncing=true
  if enabled then
    enforceAimModeExclusivity(modeName)
  else
    if modeName=="AimLock" then
      STATE.AimLock=false
      resetAimLockRuntime()
    elseif modeName=="AutoAim" then
      STATE.AutoAim=false
      resetAutoAimRuntime()
    elseif modeName=="RageBot" then
      STATE.RageBot=false
      resetRageRuntime()
    elseif modeName=="SilentAim" then
      STATE.SilentAim=false
    end
  end
  setToggleValue(aimLockToggleRef,STATE.AimLock); setToggleValue(autoAimToggleRef,STATE.AutoAim); setToggleValue(rageToggleRef,STATE.RageBot); setToggleValue(silentToggleRef,STATE.SilentAim); combatModeSyncing=false
end
-- NovaX nutzt bewusst nur die echte NovaPremiumUI-Library.
-- Die alte Mini-Fallback-GUI wurde entfernt, weil sie die moderne Lib-API nicht exakt abbildet.
function loadNovaUI()
  if getgenv and type(getgenv().NovaPremiumUI) == "table" and type(getgenv().NovaPremiumUI.CreateWindow) == "function" then
    return getgenv().NovaPremiumUI
  end

  local loadErrors = {}

  if typeof(readfile) == "function" and typeof(loadstring) == "function" then
    local candidates = {
      "NovaPremiumUI.lua",
      "./NovaPremiumUI.lua",
      "novax/NovaPremiumUI.lua",
      "side_project_blueui/NovaPremiumUI.lua",
      "C:/Users/User/OneDrive/Neuer Ordner 1/NovaPremiumUI.lua",
      "C:\\Users\\User\\OneDrive\\Neuer Ordner 1\\NovaPremiumUI.lua",
    }
    
    for _, path in ipairs(candidates) do
      local okRead, src = pcall(function()
        return readfile(path)
      end)
      if okRead and type(src) == "string" and src ~= "" then
        src = src:gsub("^\239\187\191", "")
        local okLoad, chunk = pcall(loadstring, src)
        if okLoad and type(chunk) == "function" then
          local okRun, lib = pcall(chunk)
          if okRun and type(lib) == "table" and type(lib.CreateWindow) == "function" then
            if getgenv then
              getgenv().NovaPremiumUI = lib
            end
            return lib
          else
            table.insert(loadErrors, path .. " run: " .. tostring(lib))
          end
        else
          table.insert(loadErrors, path .. " load: " .. tostring(chunk))
        end
      elseif okRead then
        table.insert(loadErrors, path .. " leer")
      end
    end
  else
    table.insert(loadErrors, "readfile/loadstring nicht verfuegbar")
  end

  return nil, table.concat(loadErrors, " | ")
end

function NX_BootGUI()
  Rayfield, uiLoadError = loadNovaUI()
  Win = nil
  winError = nil
  GUI_READY = false
  
  if Rayfield and type(Rayfield.CreateWindow) == "function" then
    GUI_READY, winError = pcall(function()
      Win = Rayfield:CreateWindow({
        Name = "NovaX",
        Title = "NovaX",
        LoadingTitle = "NovaX",
        LoadingSubtitle = "Klaus (Dev)  |  Nexus (Bug Fixer)",
        Subtitle = "Klaus (Dev)  |  Nexus (Bug Fixer)",
        LogoImage = {
          "NovaX_Logo.png",
          "C:/Users/User/Downloads/NovaX Logo.png",
          "C:\\Users\\User\\Downloads\\NovaX Logo.png",
        },
        LogoRectOffset = Vector2.new(160, 330),
        LogoRectSize = Vector2.new(310, 270),
        ShowWelcome = false,
        ConfigurationSaving = {Enabled = false},
        KeySystem = false,
      })
    end)
  else
    winError = uiLoadError or "NovaPremiumUI missing"
  end
  
  GUI_READY = GUI_READY and Win ~= nil
  if GUI_READY then
    UI_WINDOW = Win
    if getgenv then getgenv().NX_UI_WINDOW = Win end
  end
end

NX_BootGUI()
NX_BootGUI = nil

featureUnavailable = function(name, reason)
  local title = tostring(name or "Feature") .. " nicht verfuegbar"
  local content = tostring(reason or "Diese Funktion wird von diesem Executor nicht unterstuetzt.")
  local key = title .. ":" .. content
  local now = tick()
  if featureNoticeAt[key] and now - featureNoticeAt[key] < 7 then
    return
  end
  featureNoticeAt[key] = now
  nxWarn("[NovaX] " .. title .. ": " .. content)
end

if not GUI_READY then
  warn("[NovaX] NovaPremiumUI konnte die GUI nicht erstellen: " .. tostring(winError))
  notify("NovaX", "GUI konnte nicht geladen werden. NovaPremiumUI.lua pruefen.", 6)
end

function NX_BuildGUI()
if not GUI_READY then
  return
end

  local CT = Win:CreateTab("Combat", 4483345998)
  local creditsTab=Win:CreateTab("Credits",4483345998)
  creditsTab:CreateSection("NovaX Development")
  creditsTab:CreateLabel("Klaus (Dev)")
  creditsTab:CreateLabel("Nexus (Bug Fixer)")
  creditsTab:CreateLabel("Hook availability is executor-dependent.")
  CT:CreateSection("AimLock")
  
  do
    local c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "AimLock",
        CurrentValue = STATE.AimLock,
        Expanded = false,
        Callback = function(v)
          applyExclusiveMode("AimLock", v)
        end,
      })
      or CT:CreateToggle({
        Name = "AimLock",
        CurrentValue = STATE.AimLock,
        Callback = function(v)
          applyExclusiveMode("AimLock", v)
        end,
      })
    aimLockToggleRef = bindStateControl("AimLock", c)
    bindStateControl("AimLockRequireRMB", c:CreateToggle({
      Name = "Nur Bei RMB",
      CurrentValue = STATE.AimLockRequireRMB,
      Callback = function(v)
        STATE.AimLockRequireRMB = v
      end,
    }))
    bindStateControl(
      "AimLockPart",
      c:CreateDropdown({
        Name = "Target Part",
        Options = {"Head", "UpperTorso", "HumanoidRootPart"},
        CurrentOption = {STATE.AimLockPart},
        Callback = function(v)
          STATE.AimLockPart = type(v) == "table" and v[1] or tostring(v)
          resetAimLockRuntime()
        end,
      }),
      function(v, o)
        setControlFromState(o, tostring(v or "Head"))
      end
    )
    bindStateControl("AimMaxDist", c:CreateSlider({
      Name = "Max Distance",
      Range = {50, 2000},
      Increment = 25,
      CurrentValue = STATE.AimMaxDist,
      Callback = function(v)
        STATE.AimMaxDist = v
        resetAimLockRuntime()
        resetAutoAimRuntime()
        resetRageRuntime()
      end,
    }))
  end
  
  do
    local c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "Auto Aim",
        CurrentValue = STATE.AutoAim,
        Expanded = false,
        Callback = function(v)
          applyExclusiveMode("AutoAim", v)
        end,
      })
      or CT:CreateToggle({
        Name = "Auto Aim",
        CurrentValue = STATE.AutoAim,
        Callback = function(v)
          applyExclusiveMode("AutoAim", v)
        end,
      })
    autoAimToggleRef = bindStateControl("AutoAim", c)
    bindStateControl(
      "AutoAimTargetPart",
      c:CreateDropdown({
        Name = "Target Part",
        Options = {"Head", "Torso", "Mixed"},
        CurrentOption = {STATE.AutoAimTargetPart},
        Callback = function(v)
          STATE.AutoAimTargetPart = type(v) == "table" and v[1] or tostring(v)
          resetAutoAimRuntime()
        end,
      }),
      function(v, o)
        setControlFromState(o, tostring(v or "Head"))
      end
    )
    bindStateControl("AutoAimVisibleCheck", c:CreateToggle({
      Name = "Visibility Check",
      CurrentValue = STATE.AutoAimVisibleCheck,
      Callback = function(v)
        STATE.AutoAimVisibleCheck = v
        resetAutoAimRuntime()
      end,
    }))
    bindStateControl("AutoAimRequireRMB", c:CreateToggle({
      Name = "Nur Bei RMB",
      CurrentValue = STATE.AutoAimRequireRMB,
      Callback = function(v)
        STATE.AutoAimRequireRMB = v
      end,
    }))
    bindStateControl("AutoAimStrengthADS", c:CreateSlider({
      Name = "ADS Strength",
      Range = {0, 100},
      Increment = 1,
      CurrentValue = STATE.AutoAimStrengthADS,
      Callback = function(v)
        STATE.AutoAimStrengthADS = v
      end,
    }))
    bindStateControl("AutoAimStrengthHip", c:CreateSlider({
      Name = "Hipfire Strength",
      Range = {0, 100},
      Increment = 1,
      CurrentValue = STATE.AutoAimStrengthHip,
      Callback = function(v)
        STATE.AutoAimStrengthHip = v
      end,
    }))
  end
    do
    local c
    c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "Mouse Aim Assist",
        CurrentValue = STATE.AimMouseAssist,
        Expanded = false,
        Callback = function(v)
          STATE.AimMouseAssist = v == true
        end,
      })
      or CT:CreateToggle({
        Name = "Mouse Aim Assist",
        CurrentValue = STATE.AimMouseAssist,
        Callback = function(v)
          STATE.AimMouseAssist = v == true
        end,
      })
    bindStateControl("AimMouseAssist", c)
    c:CreateLabel("Maussteuerung fuer AimLock und Auto Aim; Zielmodus separat aktivieren.")
    bindStateControl(
      "AimMouseAssistSmooth",
      c:CreateSlider({
        Name = "Smoothness",
        Range = {1, 100},
        Increment = 1,
        CurrentValue = math.floor(STATE.AimMouseAssistSmooth * 100 + 0.5),
        Callback = function(v)
          STATE.AimMouseAssistSmooth = math.clamp(safeNum(v) / 100, 0.01, 1)
        end,
      }),
      function(v, o)
        setControlFromState(o, math.floor(math.clamp(safeNum(v), 0.01, 1) * 100 + 0.5))
      end
    )
    bindStateControl("AimMouseAssistStrength", c:CreateSlider({
      Name = "Strength",
      Range = {5, 100},
      Increment = 1,
      CurrentValue = STATE.AimMouseAssistStrength,
      Callback = function(v)
        STATE.AimMouseAssistStrength = v
      end,
    }))
  end
  
  CT:CreateSection("Other")
  do
    local c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "Rage Bot",
        CurrentValue = STATE.RageBot,
        Expanded = false,
        Callback = function(v)
          applyExclusiveMode("RageBot", v)
        end,
      })
      or CT:CreateToggle({
        Name = "Rage Bot",
        CurrentValue = STATE.RageBot,
        Callback = function(v)
          applyExclusiveMode("RageBot", v)
        end,
      })
    rageToggleRef = bindStateControl("RageBot", c)
    bindStateControl(
      "RageTargetPart",
      c:CreateDropdown({
        Name = "Target Part",
        Options = {"Head", "Torso", "Mixed"},
        CurrentOption = {STATE.RageTargetPart},
        Callback = function(v)
          STATE.RageTargetPart = type(v) == "table" and v[1] or tostring(v)
          resetRageRuntime()
        end,
      }),
      function(v, o)
        setControlFromState(o, tostring(v or "Head"))
      end
    )
    bindStateControl("RageLockStrength", c:CreateSlider({
      Name = "Lock Strength",
      Range = {1, 100},
      Increment = 1,
      CurrentValue = STATE.RageLockStrength,
      Callback = function(v)
        STATE.RageLockStrength = v
      end,
    }))
    bindStateControl("RageAutoShoot", c:CreateToggle({
      Name = "Auto Shoot",
      CurrentValue = STATE.RageAutoShoot,
      Callback = function(v)
        STATE.RageAutoShoot = v
      end,
    }))
    bindStateControl("RageRequireADS", c:CreateToggle({
      Name = "Aim RMB",
      CurrentValue = STATE.RageRequireADS,
      Callback = function(v)
        STATE.RageRequireADS = v
      end,
    }))
    bindStateControl("RageCPS", c:CreateSlider({
      Name = "Shoot CPS",
      Range = {1, MAX_TRIGGER_CPS},
      Increment = 1,
      CurrentValue = math.min(MAX_TRIGGER_CPS, math.max(1, STATE.RageCPS)),
      Callback = function(v)
        STATE.RageCPS = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(v)))
      end,
    }))
    bindStateControl("RageShootFOV", c:CreateSlider({
      Name = "Shoot Radius",
      Range = {2, 30},
      Increment = 1,
      CurrentValue = STATE.RageShootFOV,
      Callback = function(v)
        STATE.RageShootFOV = v
      end,
    }))
  end
  
  CT:CreateSection("Trigger")
  do
    local c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "Trigger Bot",
        CurrentValue = STATE.TriggerEnabled,
        Expanded = false,
        Callback = function(v)
          STATE.TriggerEnabled = v
        end,
      })
      or CT:CreateToggle({
        Name = "Trigger Bot",
        CurrentValue = STATE.TriggerEnabled,
        Callback = function(v)
          STATE.TriggerEnabled = v
        end,
      })
    bindStateControl("TriggerEnabled", c)
    bindStateControl(
      "TriggerTarget",
      c:CreateDropdown({
        Name = "Target",
        Options = {"Head", "Torso", "Any Visible Body"},
        CurrentOption = {STATE.TriggerTarget},
        Callback = function(v)
          STATE.TriggerTarget = type(v) == "table" and v[1] or tostring(v)
        end,
      }),
      function(v, o)
        setControlFromState(o, tostring(v or "Head"))
      end
    )
    bindStateControl("TriggerDelay", c:CreateSlider({
      Name = "Delay ms",
      Range = {0, 250},
      Increment = 5,
      CurrentValue = STATE.TriggerDelay,
      Callback = function(v)
        STATE.TriggerDelay = v
      end,
    }))
    bindStateControl("TriggerCPS", c:CreateSlider({
      Name = "CPS",
      Range = {1, MAX_TRIGGER_CPS},
      Increment = 1,
      CurrentValue = math.min(MAX_TRIGGER_CPS, math.max(1, STATE.TriggerCPS)),
      Callback = function(v)
        STATE.TriggerCPS = math.min(MAX_TRIGGER_CPS, math.max(1, safeNum(v)))
      end,
    }))
  end
  

  do
    local c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "FOV",
        CurrentValue = STATE.AimFOVCircle,
        Expanded = false,
        Callback = function(v)
          STATE.AimFOVCircle = v
        end,
      })
      or CT:CreateToggle({
        Name = "FOV",
        CurrentValue = STATE.AimFOVCircle,
        Callback = function(v)
          STATE.AimFOVCircle = v
        end,
      })
    bindStateControl("AimFOVCircle", c)
    bindStateControl("AimFOV", c:CreateSlider({
      Name = "Radius",
      Range = {20, 500},
      Increment = 10,
      CurrentValue = STATE.AimFOV,
      Callback = function(v)
        STATE.AimFOV = v
      end,
    }))
    bindStateControl("AimFOVHidden", c:CreateToggle({
      Name = "Hide FOV",
      CurrentValue = STATE.AimFOVHidden,
      Callback = function(v)
        STATE.AimFOVHidden = v
        updateFOV()
      end,
    }))
    bindStateControl(
      "AimFOVColor",
      c:CreateDropdown({
        Name = "Color",
        Options = {"White", "Blue", "Cyan", "Green", "Yellow", "Red", "Pink"},
        CurrentOption = {STATE.AimFOVColor},
        Callback = function(v)
          STATE.AimFOVColor = type(v) == "table" and v[1] or tostring(v)
          updateFOV()
        end,
      }),
      function(v, o)
        setControlFromState(o, tostring(v or "White"))
      end
    )
  end
  
  do
    local c = CT.CreateExpandableToggle
      and CT:CreateExpandableToggle({
        Name = "Silent Aim",
        CurrentValue = STATE.SilentAim,
        Expanded = false,
        Callback = function(v)
          applyExclusiveMode("SilentAim", v)
        end,
      })
      or CT:CreateToggle({
        Name = "Silent Aim",
        CurrentValue = STATE.SilentAim,
        Callback = function(v)
          applyExclusiveMode("SilentAim", v)
        end,
      })
    silentToggleRef = bindStateControl("SilentAim", c)
    bindStateControl(
      "SilentAimMode",
      c:CreateDropdown({
        Name = "Mode",
        Options = {"Snap","Hook (Internal)"},
        CurrentOption = {STATE.SilentAimMode},
        Callback = function(value)
          local selected=type(value)=="table" and value[1] or tostring(value)
          if selected=="Hook (Internal)" and not hasSilentHookSupport() then
            nxWarn("[NovaX] Internal hook unavailable")
            selected="Snap"
          end
          STATE.SilentAimMode=selected
          syncStateControlsFromState()
        end
      }),
      function(value,o)
        setControlFromState(o,tostring(value or "Snap"))
      end
    )
    c:CreateLabel("Snap: camera. Hook: client raycasts, if supported.")
    bindStateControl(
      "SilentTargetPart",
      c:CreateDropdown({
        Name = "Hit Part",
        Options = {"Head","UpperTorso","LowerTorso","HumanoidRootPart","Random"},
        CurrentOption = {STATE.SilentTargetPart},
        Callback = function(v)
          STATE.SilentTargetPart=type(v)=="table" and v[1] or tostring(v)
        end
      }),
      function(v,o)
        setControlFromState(o,tostring(v or "Head"))
      end
    )
    bindStateControl(
      "SilentHitChance",
      c:CreateSlider({
        Name = "Hitchance / Hold",
        Range = {0,100},
        Increment = 1,
        CurrentValue = STATE.SilentHitChance,
        Callback = function(v)
          STATE.SilentHitChance=math.clamp(math.floor(tonumber(v) or 100),0,100)
        end
      })
    )
    c:CreateLabel("Snap: one chance roll per Mouse1 press.")
    c:CreateLabel("Hook (Internal): separate hit part and chance.")
    bindStateControl("SilentHookTargetPart", c:CreateDropdown({
      Name = "Hook Hit Part",
      Options = {"Head","UpperTorso","LowerTorso","HumanoidRootPart","Random"},
      CurrentOption = {STATE.SilentHookTargetPart},
      Callback = function(v)
        STATE.SilentHookTargetPart=type(v)=="table" and v[1] or tostring(v)
      end,
    }), function(v,o) setControlFromState(o,tostring(v or "Head")) end)
    bindStateControl("SilentHookHitChance", c:CreateSlider({
      Name = "Hook Hitchance / Hold",
      Range = {0,100}, Increment = 1,
      CurrentValue = STATE.SilentHookHitChance,
      Callback = function(v)
        STATE.SilentHookHitChance=math.clamp(math.floor(tonumber(v) or 100),0,100)
      end,
    }))
    c:CreateLabel("Hook chance is rolled once per Mouse1 press.")
  end
  
  local ET = Win:CreateTab("ESP", 4483345998)
  for _, item in ipairs({
    {"ESPEnabled", "ESP"},
    {"ESPEnemy", "Enemy"},
    {"ESPTeam", "Team"},
    {"ESPName", "Names"},
    {"ESPHealth", "Health"},
    {"ESPDistance", "Distance"},
    {"ESPBox", "Boxes"},
    {"ESPSkeleton", "Skeleton"},
  }) do
    bindStateControl(item[1], ET:CreateToggle({
      Name = item[2],
      CurrentValue = STATE[item[1]],
      Callback = function(v)
        STATE[item[1]] = v
      end,
    }))
  end
  bindStateControl("ESPBoxScale", ET:CreateSlider({
    Name = "Box Scale",
    Range = {30, 70},
    Increment = 1,
    CurrentValue = STATE.ESPBoxScale,
    Callback = function(v)
      STATE.ESPBoxScale = v
    end,
  }))
  bindStateControl("ESPMaxDistance", ET:CreateSlider({
    Name = "Max Distance",
    Range = {50, 2000},
    Increment = 25,
    CurrentValue = STATE.ESPMaxDistance,
    Callback = function(v)
      STATE.ESPMaxDistance = v
    end,
  }))
  
  local MT = Win:CreateTab("Movement", 4483345998)
  do
    local c = MT.CreateExpandableToggle
      and MT:CreateExpandableToggle({
        Name = "Speed",
        CurrentValue = STATE.SpeedEnabled,
        Expanded = false,
        Callback = function(v)
          STATE.SpeedEnabled = v
        end,
      })
      or MT:CreateToggle({
        Name = "Speed",
        CurrentValue = STATE.SpeedEnabled,
        Callback = function(v)
          STATE.SpeedEnabled = v
        end,
      })
    bindStateControl("SpeedEnabled", c)
    local speedSlider = c.CreateSlider and c:CreateSlider({
      Name = "Speed Value",
      Range = {16, 200},
      Increment = 1,
      CurrentValue = STATE.SpeedValue,
      Callback = function(v)
        STATE.SpeedValue = v
      end,
    }) or MT:CreateSlider({
      Name = "Speed Value",
      Range = {16, 200},
      Increment = 1,
      CurrentValue = STATE.SpeedValue,
      Callback = function(v)
        STATE.SpeedValue = v
      end,
    })
    bindStateControl("SpeedValue", speedSlider)
  end
  
  do
    local c = MT.CreateExpandableToggle
      and MT:CreateExpandableToggle({
        Name = "Fly",
        CurrentValue = STATE.FlyEnabled,
        Expanded = false,
        Callback = function(v)
          STATE.FlyEnabled = v
          STATE.FlyToggle = v
          if not v then
            stopFly()
          end
        end,
      })
      or MT:CreateToggle({
        Name = "Fly",
        CurrentValue = STATE.FlyEnabled,
        Callback = function(v)
          STATE.FlyEnabled = v
          STATE.FlyToggle = v
          if not v then
            stopFly()
          end
        end,
      })
    bindStateControl("FlyEnabled", c)
    local flySpeedSlider = c.CreateSlider and c:CreateSlider({
      Name = "Fly Speed",
      Range = {16, 200},
      Increment = 1,
      CurrentValue = STATE.FlySpeed,
      Callback = function(v)
        STATE.FlySpeed = v
      end,
    }) or MT:CreateSlider({
      Name = "Fly Speed",
      Range = {16, 200},
      Increment = 1,
      CurrentValue = STATE.FlySpeed,
      Callback = function(v)
        STATE.FlySpeed = v
      end,
    })
    bindStateControl("FlySpeed", flySpeedSlider)
  end
  
  do
    local c = MT.CreateExpandableToggle
      and MT:CreateExpandableToggle({
        Name = "Anti Hit",
        CurrentValue = STATE.AntiHit,
        Expanded = false,
        Callback = function(v)
          STATE.AntiHit = v
        end,
      })
      or MT:CreateToggle({
        Name = "Anti Hit",
        CurrentValue = STATE.AntiHit,
        Callback = function(v)
          STATE.AntiHit = v
        end,
      })
    bindStateControl("AntiHit", c)
    bindStateControl(
      "AntiHitMode",
      c:CreateDropdown({
        Name = "Mode",
        Options = {"Adaptive Jitter", "Orbital Drift", "Head Orbit", "Vector Chaos", "Head Guard (R15)"},
        CurrentOption = {STATE.AntiHitMode},
        Callback = function(v)
          STATE.AntiHitMode = type(v) == "table" and v[1] or tostring(v)
        end,
      }),
      function(v, o)
        setControlFromState(o, tostring(v or "Adaptive Jitter"))
      end
    )
    bindStateControl(
      "AntiHitSpeed",
      c:CreateSlider({
        Name = "Speed",
        Range = {4, 120},
        Increment = 1,
        CurrentValue = math.floor(STATE.AntiHitSpeed * 10 + 0.5),
        Callback = function(v)
          STATE.AntiHitSpeed = math.clamp(safeNum(v) / 10, 0.4, 12)
        end,
      }),
      function(v, o)
        setControlFromState(o, math.floor(math.clamp(safeNum(v), 0.4, 12) * 10 + 0.5))
      end
    )
    bindStateControl("AntiHitExperimental", c:CreateToggle({
      Name = "Experimental Pose Layer",
      CurrentValue = STATE.AntiHitExperimental,
      Callback = function(v)
        STATE.AntiHitExperimental = v
      end,
    }))
    bindStateControl("AntiHitGuardDodge", c:CreateToggle({
      Name = "Head Guard: Auto Dodge",
      CurrentValue = STATE.AntiHitGuardDodge,
      Callback = function(v)
        STATE.AntiHitGuardDodge = v
      end,
    }))
    MT:CreateLabel("Head Guard R15 pose: real local limb joints, no fake cloned body. Server hits remain authoritative.")
    bindStateControl("AntiHitOrbitRadius", c:CreateSlider({
      Name = "Head Guard: Orbit Radius",
      Range = {1.5,6},
      Increment = 0.25,
      CurrentValue = STATE.AntiHitOrbitRadius,
      Callback = function(v)
        STATE.AntiHitOrbitRadius=math.clamp(safeNum(v),1.5,6)
      end,
    }))
    bindStateControl("AntiVoid", c:CreateToggle({
      Name = "Anti Void",
      CurrentValue = STATE.AntiVoid,
      Callback = function(v)
        STATE.AntiVoid = v
      end,
    }))
  end
  
  bindStateControl("BunnyHop", MT:CreateToggle({
    Name = "Bunny Hop",
    CurrentValue = STATE.BunnyHop,
    Callback = function(v)
      STATE.BunnyHop = v
    end,
  }))
  do
    local c = MT.CreateExpandableToggle
      and MT:CreateExpandableToggle({
        Name = "Inf Jump",
        CurrentValue = STATE.InfJump,
        Expanded = false,
        Callback = function(v)
          STATE.InfJump = v
        end,
      })
      or MT:CreateToggle({
        Name = "Inf Jump",
        CurrentValue = STATE.InfJump,
        Callback = function(v)
          STATE.InfJump = v
        end,
      })
    bindStateControl("InfJump", c)
    local jumpControls = (c and c.CreateSlider) and c or MT
    bindStateControl("InfJumpHeight", jumpControls:CreateSlider({
      Name = "Jump Height",
      Range = {28, 80},
      Increment = 1,
      CurrentValue = STATE.InfJumpHeight,
      Callback = function(v)
        STATE.InfJumpHeight = math.clamp(safeNum(v), 28, 80)
      end,
    }))
  end
  bindStateControl("NoClip", MT:CreateToggle({
    Name = "NoClip",
    CurrentValue = STATE.NoClip,
    Callback = function(v)
      STATE.NoClip = v
    end,
  }))
  
  local TT = Win:CreateTab("TP/Backstab", 4483345998)
  do
    local c = TT.CreateExpandableToggle
      and TT:CreateExpandableToggle({
        Name = "Auto Backstab",
        CurrentValue = STATE.AutoBackstab,
        Expanded = false,
        Callback = function(v)
          STATE.AutoBackstab = v
        end,
      })
      or TT:CreateToggle({
        Name = "Auto Backstab",
        CurrentValue = STATE.AutoBackstab,
        Callback = function(v)
          STATE.AutoBackstab = v
        end,
      })
    bindStateControl("AutoBackstab", c)
    bindStateControl("AutoBackstabInterval", c:CreateSlider({
      Name = "Interval ms",
      Range = {80, 1000},
      Increment = 10,
      CurrentValue = STATE.AutoBackstabInterval,
      Callback = function(v)
        STATE.AutoBackstabInterval = v
      end,
    }))
    bindStateControl("AutoBackstabRandomize", c:CreateToggle({
      Name = "Randomize",
      CurrentValue = STATE.AutoBackstabRandomize,
      Callback = function(v)
        STATE.AutoBackstabRandomize = v
      end,
    }))
    bindStateControl("AutoBackstabRandomMin", c:CreateSlider({
      Name = "Random Min",
      Range = {50, 1000},
      Increment = 10,
      CurrentValue = STATE.AutoBackstabRandomMin,
      Callback = function(v)
        STATE.AutoBackstabRandomMin = v
      end,
    }))
    bindStateControl("AutoBackstabRandomMax", c:CreateSlider({
      Name = "Random Max",
      Range = {50, 1500},
      Increment = 10,
      CurrentValue = STATE.AutoBackstabRandomMax,
      Callback = function(v)
        STATE.AutoBackstabRandomMax = v
      end,
    }))
  end
  
  tpDropdownRef = bindStateControl(
    "TPPlayer",
    TT:CreateDropdown({
      Name = "Target Player",
      Options = getSelectablePlayers(),
      CurrentOption = {"None"},
      Callback = setTPPlayer,
    }),
    function(v, o)
      setControlFromState(o, v and v ~= "" and v or "None")
    end
  )
  TT:CreateButton({Name = "Refresh Player List", Callback = refreshTPDropdown})
  bindStateControl("TPDistance", TT:CreateSlider({
    Name = "TP Distance",
    Range = {2, 20},
    Increment = 1,
    CurrentValue = STATE.TPDistance,
    Callback = function(v)
      STATE.TPDistance = v
    end,
  }))
  TT:CreateButton({
    Name = "TP Near Selected",
    Callback = function()
      teleportNearSelected(false)
    end,
  })
  TT:CreateButton({
    Name = "TP Behind Selected",
    Callback = function()
      teleportNearSelected(true)
    end,
  })
  TT:CreateButton({Name = "Backstab Once", Callback = backstabOnce})
  
  local VT = Win:CreateTab("Visual", 4483345998)
  bindStateControl("FullBright", VT:CreateToggle({
    Name = "FullBright",
    CurrentValue = STATE.FullBright,
    Callback = function(v)
      STATE.FullBright = v
      setFB(v)
    end,
  }))
  bindStateControl("NoFog", VT:CreateToggle({
    Name = "No Fog",
    CurrentValue = STATE.NoFog,
    Callback = function(v)
      STATE.NoFog = v
      setNF(v)
    end,
  }))
  bindStateControl("FPSBoost", VT:CreateToggle({
    Name = "FPS Boost",
    CurrentValue = STATE.FPSBoost,
    Callback = function(v)
      STATE.FPSBoost = v
      setFPSBoost(v)
    end,
  }))
  
  local MST = Win:CreateTab("Misc", 4483345998)
  bindStateControl("BeggerFarm", MST:CreateToggle({
    Name = "Begger Farm",
    CurrentValue = STATE.BeggerFarm,
    Callback = function(v)
      STATE.BeggerFarm = v
    end,
  }))
  
  local spoofRefs = {}
  local function syncSpoofs()
    if spoofRefs.MobileSpoof then spoofRefs.MobileSpoof:Set(STATE.MobileSpoof) end
    if spoofRefs.ConsoleSpoof then spoofRefs.ConsoleSpoof:Set(STATE.ConsoleSpoof) end
    if spoofRefs.VRSpoof then spoofRefs.VRSpoof:Set(STATE.VRSpoof) end
  end
  local function setSpoof(key, value)
    STATE.MobileSpoof = false
    STATE.ConsoleSpoof = false
    STATE.VRSpoof = false
    if value then
      STATE[key] = true
    end
    syncSpoofs()
    applyDeviceSpoof()
  end
  
  spoofRefs.MobileSpoof = bindStateControl("MobileSpoof", MST:CreateToggle({
    Name = "Mobile Spoof",
    CurrentValue = STATE.MobileSpoof,
    Callback = function(v)
      setSpoof("MobileSpoof", v)
    end,
  }))
  spoofRefs.ConsoleSpoof = bindStateControl("ConsoleSpoof", MST:CreateToggle({
    Name = "Console Spoof",
    CurrentValue = STATE.ConsoleSpoof,
    Callback = function(v)
      setSpoof("ConsoleSpoof", v)
    end,
  }))
  spoofRefs.VRSpoof = bindStateControl("VRSpoof", MST:CreateToggle({
    Name = "VR Spoof",
    CurrentValue = STATE.VRSpoof,
    Callback = function(v)
      setSpoof("VRSpoof", v)
    end,
  }))
  
  MST:CreateButton({
    Name = "Reset Device Spoof",
    Callback = function()
      STATE.MobileSpoof = false
      STATE.ConsoleSpoof = false
      STATE.VRSpoof = false
      restoreDeviceSpoof()
      syncSpoofs()
    end,
  })
  
  local BT = Win:CreateTab("Binds", 4483345998)
  local function makeBind(label, key)
    if BT.CreateKeybind then
      bindStateControl(key, BT:CreateKeybind({
        Name = label,
        CurrentKeybind = STATE[key],
        Callback = function(v)
          STATE[key] = normalizeSingleLetterBind(v)
        end,
      }))
    else
      BT:CreateButton({
        Name = label .. " Set",
        Callback = function()
          notify("Bind", "NovaPremiumUI fuer Keybinds nutzen", 2)
        end,
      })
    end
  end
  for _, b in ipairs({
    {"Toggle GUI", "BindToggleGUI"},
    {"Fly Toggle", "BindFly"},
    {"Toggle AimLock", "BindAimLock"},
    {"Toggle AutoAim", "BindAutoAim"},
    {"Toggle RageBot", "BindRageBot"},
    {"Toggle Trigger", "BindTrigger"},
    {"Toggle ESP", "BindESP"},
    {"Toggle Begger Farm", "BindBeggerFarm"},
    {"Toggle Auto Backstab", "BindAutoBackstab"},
    {"Apply Control Mode", "BindApplyControlMode"},
  }) do
    makeBind(b[1], b[2])
  end
  
  local function syncAfterConfigLoad()
    enforceNoHookMode()
    enforceAlwaysOnChecks()
    normalizeAllBinds()
    enforceAimModeExclusivity()
    setFB(STATE.FullBright)
    setNF(STATE.NoFog)
    STATE.FPSUnlocker = true
    setFPS(true)
    setFPSBoost(STATE.FPSBoost)
    applyDeviceSpoof()
    syncStateControlsFromState()
    refreshTPDropdown()
    local globals=(getgenv and getgenv()) or _G
    if type(globals.NX_CONFIG_APPLY)=="function" then
      local ok,err=pcall(globals.NX_CONFIG_APPLY)
      if not ok then warn("[NovaX Config] External sync: "..tostring(err)) end
    end
  end

  if Rayfield.CreateConfigManager then
    local manager=Rayfield:CreateConfigManager(Win, STATE, {
      Folder = CONFIG_FOLDER,
      DefaultName = autoConfigName or "default",
      TabName = "Configs",
      Sync = syncAfterConfigLoad,
    })
    if type(manager)=="table" then
      -- Wrapping existing manager methods also tracks manual Save, Load,
      -- Rename and Delete actions without altering NovaPremiumUI itself.
      local save,load,rename,delete=manager.Save,manager.Load,manager.Rename,manager.Delete
      function manager:Save(name)
        local ok,result=save(self,name)
        if ok then rememberAutoConfig(result);autoConfigStatus="Saved and selected: "..tostring(result) end
        return ok,result
      end
      function manager:Load(name)
        local ok,result=load(self,name)
        if ok then rememberAutoConfig(result);autoConfigStatus="Loaded: "..tostring(result) end
        return ok,result
      end
      function manager:Rename(oldName,newName)
        local ok,result=rename(self,oldName,newName)
        if ok then rememberAutoConfig(result);autoConfigStatus="Renamed and selected: "..tostring(result) end
        return ok,result
      end
      function manager:Delete(name)
        local ok,result=delete(self,name)
        if ok and autoConfigName==sanitizeConfigName(result) then
          clearAutoConfig()
          autoConfigStatus="Deleted selection; next start uses default/first config"
        end
        return ok,result
      end
    end
  end
  MST:CreateButton({
    Name="Auto Config Status",
    Callback=function()
      local selected=autoConfigName or "(none)"
      local message=autoConfigStatus.." | selected: "..selected
      print("[NovaX Config] "..message)
      notify("Auto Config",message,6)
    end,
  })
  
  addConnection("input", UserInputService.InputBegan:Connect(function(i, gp)
    if gp then
      return
    end
    if inputMatchesBind(i, STATE.BindToggleGUI) and Win.Toggle then
      Win:Toggle()
    end
    if inputMatchesBind(i, STATE.BindFly) and STATE.FlyEnabled then
      STATE.FlyToggle = not STATE.FlyToggle
      if not STATE.FlyToggle then
        stopFly()
      end
    end
    if inputMatchesBind(i, STATE.BindAimLock) then
      applyExclusiveMode("AimLock", not STATE.AimLock)
    end
    if inputMatchesBind(i, STATE.BindAutoAim) then
      applyExclusiveMode("AutoAim", not STATE.AutoAim)
    end
    if inputMatchesBind(i, STATE.BindRageBot) then
      applyExclusiveMode("RageBot", not STATE.RageBot)
    end
    if inputMatchesBind(i, STATE.BindTrigger) then
      STATE.TriggerEnabled = not STATE.TriggerEnabled
      syncStateControlsFromState()
    end
    if inputMatchesBind(i, STATE.BindESP) then
      STATE.ESPEnabled = not STATE.ESPEnabled
      syncStateControlsFromState()
    end
    if inputMatchesBind(i, STATE.BindBeggerFarm) then
      STATE.BeggerFarm = not STATE.BeggerFarm
      syncStateControlsFromState()
    end
    if inputMatchesBind(i, STATE.BindAutoBackstab) then
      STATE.AutoBackstab = not STATE.AutoBackstab
      syncStateControlsFromState()
    end
    if inputMatchesBind(i, STATE.BindApplyControlMode) then
      applyDeviceSpoof()
    end
  end))
  
  syncStateControlsFromState()
  refreshTPDropdown()
end

NX_BuildGUI()
NX_BuildGUI = nil
function scheduleLoad(label, delay, fn)
  task.defer(function()
    if delay and delay > 0 then
      task.wait(delay)
    end
    local ok, err = pcall(fn)
    if not ok then
      nxWarn("[NovaX] load step failed: " .. tostring(label) .. " -> " .. tostring(err))
    end
  end)
end

task.wait(0.18)

scheduleLoad("core.device", 0.02, function()
  applyDeviceSpoof()
  STATE.FPSUnlocker = true
  setFPS(true)
  setFPSBoost(STATE.FPSBoost)
end)
scheduleLoad("combat.scheduler", 0.08, setupCombat)
scheduleLoad("combat.trigger", 0.12, setupTrigger)
scheduleLoad("utility.begger", 0.20, setupBeggerFarm)
scheduleLoad("utility.controlmode", 0.24, setupControlModeSpoof)
scheduleLoad("utility.backstab", 0.28, setupAutoBackstab)
scheduleLoad("visual.esp", 0.34, setupESP)
scheduleLoad("movement", 0.40, setupMovement)
scheduleLoad("movement.infjump", 0.44, setupInfJump)
scheduleLoad("aim.silent",0.46,function()
  safeHook(setupGrabber,"Silent Aim Snap/Internal Hook")
end)

notify("NovaX", "Loaded Successfully!", 3)
if GUI_READY then
  notify("GUI Bind", "Toggle: " .. tostring(STATE.BindToggleGUI or "K"), 2)
else
  notify("NovaX", "Features laufen, GUI-Lib fehlt/fehlerhaft", 3)
end
