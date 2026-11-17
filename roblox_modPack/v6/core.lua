--[[
  roblox_modPack | REALISM v6.0 (90 HZ WEATHER, NO LEGACY GUI)
  Originales, neutrales Profil: kein Neon, keine fremden Assets, keine Remote-Requests.

  ECHTE AENDERUNGEN (wenn der Client sie erlaubt):
  * LightingStyle Realistic (Versuch + Readback, moeglicherweise gesperrt)
  * Schatten / Umgebungsreflexion / helligkeitsadaptive Beleuchtung
  * Atmosphaere, Wolken, Sonne/Mond, Film-Colorgrading
  * Terrainfarben, Wasser, Gras
  * Grosse statische Plastikflaechen -> Beton, natuerliche Strukturfarben
  * Vorhandene lokale Lichtquellen erhalten Schatten
  * Lokaler 3D-Regen / 3D-Schnee mit physikalischer Bahn-Integration,
    swept Raycast-Kollisionen, Oberflaechenwasser, Abfluss und Schneeakkumulation
    (begrenztes lokales Modell; keine kompletten Fluidgleichungen oder Serverwetter)

  F8 = AN/AUS  |  F6 = Diagnose  |  F7 = Regen/Schnee/Aus  |  F9 = Intensitaet
  Wiederholtes Ausfuehren stoppt die aeltere Instanz und stellt Werte wieder her.
  Alle Aenderungen sind nur lokal und NICHT echte neue PBR-/Shader-Assets.
  Verwende dieses Skript nur, wo du zur lokalen Modifikation berechtigt bist.
--]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    warn("[RM v4] Kein LocalPlayer. Dieses Skript benoetigt einen Client-Kontext.")
    return
end

local CONFIG = {
    -- Beide Varianten sind neutral und fotografisch, NICHT neonfarbig.
    Atmosphere = true,
    Clouds = true,
    SkyDiscSize = true,
    TerrainColors = true,
    TerrainWater = true,
    StaticWorldMaterials = true,
    NaturalSurfaceColors = true,
    StructuralShadows = true,
    ExistingLightShadows = true,
    DepthOfField = false,             -- unscharfe Distanz stoert viele Spiele
    ReapplyLightingEvery = 14,        -- nicht pro Frame, daher keine Dauer-Last
    MaxWorldPartsChanged = 2300,      -- FPS-/Speicher-Schutz
    MaxLightSourcesChanged = 50,
    ScanBatch = 120,
    Hotkey = Enum.KeyCode.F8,
    DetailHotkey = Enum.KeyCode.F6,
    WeatherHotkey = Enum.KeyCode.F7,
    WeatherIntensityHotkey = Enum.KeyCode.F9,
    RainDrops = 170,          -- 3D, gepoolt, nicht 2D-HUD
    SnowFlakes = 125,
    MaxSplashParts = 44,
    MaxSettledSnow = 80,
    MaxImpactsPerStep = 6,
    SnowAccumulation = true, -- lokale Schnee-Zellen
    PhysicsHz = 90,          -- feste Simulationsschritte pro Realzeitsekunde
    MaxPhysicsSubsteps = 6, -- bis 6 Nachholschritte pro Renderframe
    MaxFrameDelta = 0.10,   -- FPS-Einbrueche begrenzen
}

local environment = _G
pcall(function()
    if type(getgenv) == "function" then
        local candidate = getgenv()
        if type(candidate) == "table" then environment = candidate end
    end
end)

if type(environment.roblox_modPack_Realism_v4) == "table" then
    local old = environment.roblox_modPack_Realism_v4
    if type(old.Stop) == "function" then pcall(old.Stop) end
end
-- V3 safely stop before enabling v4: only one weather simulation may run.
if type(environment.roblox_modPack_Realism_v3) == "table" then
    local previousV3 = environment.roblox_modPack_Realism_v3
    if type(previousV3.Stop) == "function" then pcall(previousV3.Stop) end
end
-- Vorversion v2 stoppen: sonst laufen zwei Render-/Wetterprofile nebeneinander.
if type(environment.roblox_modPack_Realism_v2) == "table" then
    local oldV2 = environment.roblox_modPack_Realism_v2
    if type(oldV2.Stop) == "function" then pcall(oldV2.Stop) end
end
-- Alte v1 ebenfalls stoppen, sonst kaempfen zwei Grafik-Profile gegeneinander.
if type(environment.roblox_modPack_LocalRealism) == "table" then
    local oldV1 = environment.roblox_modPack_LocalRealism
    if type(oldV1.Stop) == "function" then pcall(oldV1.Stop) end
end

local SECTIONS = {"Lighting", "PostFX", "Atmosphere", "SkyClouds", "Terrain", "World", "LocalLights"}
local state = {
    running = true,
    enabled = false,
    generation = 0,
    scanning = false,
    scanComplete = false,
    worldVisited = 0,
    worldChanged = 0,
    lightsChanged = 0,
    currentMode = "NEUTRAL REALISM",
    writes = 0,
    errors = 0,
    sections = {},
    failures = {},
    lightingStyle = "nicht geprueft",
}
for _, section in ipairs(SECTIONS) do
    state.sections[section] = {changed = 0, rejected = 0}
end
environment.roblox_modPack_Realism_v4 = state

-- Originalwerte nur nach erfolgreichem Schreiben merken: kein Fake-Zaehler.
local original = {}
local terrainOriginal = {}
local created = {}
local connections = {}
local blockedProperties = {}
local graphicUi = nil
local statusButton = nil
local detailsPanel = nil
local detailsLabel = nil
local detailsVisible = false

local function formatValue(value)
    if typeof(value) == "Color3" then
        return string.format("RGB(%d,%d,%d)", value.R * 255, value.G * 255, value.B * 255)
    end
    return tostring(value)
end

local function equivalent(a, b)
    if typeof(a) ~= typeof(b) then return false end
    if typeof(a) == "number" then return math.abs(a - b) < 0.0005 end
    if typeof(a) == "Color3" then
        return math.abs(a.R - b.R) < 0.003
            and math.abs(a.G - b.G) < 0.003
            and math.abs(a.B - b.B) < 0.003
    end
    return a == b
end

local function readProperty(object, prop, fallback)
    local ok, value = pcall(function() return object[prop] end)
    if ok then return value end
    return fallback
end

local function baseline(object, prop, fallback)
    local values = original[object]
    if values and values[prop] ~= nil then return values[prop] end
    return readProperty(object, prop, fallback)
end

local function rejected(section, property, message)
    state.errors += 1
    local stats = state.sections[section]
    if stats then stats.rejected += 1 end
    if #state.failures < 12 then
        state.failures[#state.failures + 1] = section .. "." .. property .. ": " .. tostring(message)
    end
end

local function setProperty(object, prop, desired, section)
    if not object then return false end
    local blockKey = section .. ":" .. prop
    if blockedProperties[blockKey] then return false end
    local okRead, old = pcall(function() return object[prop] end)
    if not okRead then
        rejected(section, prop, "Lesen verweigert")
        blockedProperties[blockKey] = true
        return false
    end
    if equivalent(old, desired) then return true end
    local okWrite, err = pcall(function() object[prop] = desired end)
    if not okWrite then
        rejected(section, prop, err)
        blockedProperties[blockKey] = true
        return false
    end
    local okVerify, actual = pcall(function() return object[prop] end)
    if not okVerify or not equivalent(actual, desired) then
        rejected(section, prop, "Readback weicht ab (" .. formatValue(actual) .. ")")
        -- Auch bei Rundung/Clamping muss der vorherige Wert restauriert werden.
        blockedProperties[blockKey] = true
    end
    if not original[object] then original[object] = {} end
    if original[object][prop] == nil then original[object][prop] = old end
    local verified = okVerify and equivalent(actual, desired)
    if verified then
        state.writes += 1
        local bucket = state.sections[section]
        if bucket then bucket.changed += 1 end
    end
    return verified
end

local function ensureOwned(className, name, parent)
    -- Niemals eine vorhandene, spiel-eigene Instanz anhand des Namens uebernehmen.
    local success, object = pcall(function()
        local instance = Instance.new(className)
        instance.Name = name
        instance.Parent = parent
        return instance
    end)
    if success and object then
        created[#created + 1] = object
        return object
    end
    rejected("PostFX", className, object)
    return nil
end

local function safeLerp(a, b, amount)
    return a:Lerp(b, math.clamp(amount, 0, 1))
end

local function getDayWeight()
    local clock = readProperty(Lighting, "ClockTime", 12)
    -- 0 = Nacht; 1 = heller Tag; Dazwischen weicher Morgen/Abend.
    local height = math.sin((clock - 6) * math.pi / 12)
    return math.clamp((height + 0.18) / 1.1, 0, 1)
end

local function naturalLight()
    local daylight = getDayWeight()
    local indoorBase = baseline(Lighting, "Ambient", Color3.fromRGB(76, 78, 80))
    local outdoorBase = baseline(Lighting, "OutdoorAmbient", Color3.fromRGB(128, 132, 136))
    local indoorTarget = safeLerp(Color3.fromRGB(30, 34, 40), Color3.fromRGB(70, 72, 73), daylight)
    local outdoorTarget = safeLerp(Color3.fromRGB(56, 64, 79), Color3.fromRGB(145, 147, 148), daylight)

    -- Bewahrt den Charakter von Spielen; reduziert nur flaches, unphysikalisches Licht.
    setProperty(Lighting, "GlobalShadows", true, "Lighting")
    setProperty(Lighting, "ShadowSoftness", 0.25, "Lighting")
    setProperty(Lighting, "EnvironmentDiffuseScale", 0.83, "Lighting")
    setProperty(Lighting, "EnvironmentSpecularScale", 0.95, "Lighting")
    setProperty(Lighting, "Ambient", safeLerp(indoorBase, indoorTarget, 0.68), "Lighting")
    setProperty(Lighting, "OutdoorAmbient", safeLerp(outdoorBase, outdoorTarget, 0.65), "Lighting")
    setProperty(Lighting, "ExposureCompensation", math.clamp(baseline(Lighting, "ExposureCompensation", 0), -0.55, 0.45), "Lighting")

    -- Diese beiden Eigenschaften sind je nach Engine-/Sicherheitskontext gesperrt.
    -- Ein Fehlschlag steht sichtbar im Report. Kein heimlicher Erfolgsanspruch.
    if Enum.LightingStyle and Enum.LightingStyle.Realistic then
        setProperty(Lighting, "LightingStyle", Enum.LightingStyle.Realistic, "Lighting")
    end
    setProperty(Lighting, "PrioritizeLightingQuality", true, "Lighting")
    state.lightingStyle = formatValue(readProperty(Lighting, "LightingStyle", "nicht zugreifbar"))

    -- Bestehende Sonne und Zeit des Spiels bleiben erhalten.
    return daylight
end

local postEffects = {}
local function installPostFX()
    postEffects.grade = ensureOwned("ColorCorrectionEffect", "RM4_NeutralGrade", Lighting)
    if postEffects.grade then
        setProperty(postEffects.grade, "Enabled", true, "PostFX")
        setProperty(postEffects.grade, "Brightness", 0.0, "PostFX")
        setProperty(postEffects.grade, "Contrast", 0.085, "PostFX")
        setProperty(postEffects.grade, "Saturation", -0.06, "PostFX")
        setProperty(postEffects.grade, "TintColor", Color3.fromRGB(255, 254, 252), "PostFX")
    end
    postEffects.bloom = ensureOwned("BloomEffect", "RM2_OpticBloom", Lighting)
    if postEffects.bloom then
        setProperty(postEffects.bloom, "Enabled", true, "PostFX")
        setProperty(postEffects.bloom, "Intensity", 0.09, "PostFX")
        setProperty(postEffects.bloom, "Threshold", 1.75, "PostFX")
        setProperty(postEffects.bloom, "Size", 12, "PostFX")
    end
    postEffects.rays = ensureOwned("SunRaysEffect", "RM2_SoftRays", Lighting)
    if postEffects.rays then
        setProperty(postEffects.rays, "Enabled", true, "PostFX")
        setProperty(postEffects.rays, "Intensity", 0.045, "PostFX")
        setProperty(postEffects.rays, "Spread", 0.70, "PostFX")
    end
    if CONFIG.DepthOfField then
        postEffects.dof = ensureOwned("DepthOfFieldEffect", "RM2_PhotoDOF", Lighting)
        if postEffects.dof then
            setProperty(postEffects.dof, "Enabled", true, "PostFX")
            setProperty(postEffects.dof, "FarIntensity", 0.025, "PostFX")
            setProperty(postEffects.dof, "NearIntensity", 0, "PostFX")
            setProperty(postEffects.dof, "FocusDistance", 90, "PostFX")
            setProperty(postEffects.dof, "InFocusRadius", 70, "PostFX")
        end
    end
end

local function applyAtmosphere()
    if not CONFIG.Atmosphere then return end
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = ensureOwned("Atmosphere", "RM2_PhotographicAir", Lighting)
    end
    if not atmosphere then return end
    local density = baseline(atmosphere, "Density", 0.25)
    local haze = baseline(atmosphere, "Haze", 0.6)
    local glare = baseline(atmosphere, "Glare", 0.0)
    local daytime = getDayWeight()
    setProperty(atmosphere, "Density", math.clamp(density * 0.65 + 0.085, 0.12, 0.35), "Atmosphere")
    setProperty(atmosphere, "Haze", math.clamp(haze * 0.6 + 0.52, 0.4, 1.5), "Atmosphere")
    setProperty(atmosphere, "Glare", math.clamp(glare * 0.4 + 0.035, 0.025, 0.15), "Atmosphere")
    setProperty(atmosphere, "Offset", 0.03, "Atmosphere")
    local sunAir = safeLerp(Color3.fromRGB(167, 178, 194), Color3.fromRGB(206, 214, 220), daytime)
    setProperty(atmosphere, "Color", safeLerp(baseline(atmosphere, "Color", sunAir), sunAir, 0.45), "Atmosphere")
    -- Keine pinken/violetten Himmel; vorhandene Wettereffekte bleiben erkennbar.
    local decay = safeLerp(Color3.fromRGB(82, 91, 109), Color3.fromRGB(116, 125, 136), daytime)
    setProperty(atmosphere, "Decay", safeLerp(baseline(atmosphere, "Decay", decay), decay, 0.35), "Atmosphere")
end

local function applySkyAndClouds()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky and CONFIG.SkyDiscSize then
        -- Reale Sonne und realer Mond erscheinen klein; keine gigantischen Glows.
        setProperty(sky, "SunAngularSize", 3, "SkyClouds")
        setProperty(sky, "MoonAngularSize", 3.5, "SkyClouds")
    end
    if not CONFIG.Clouds then return end
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    local clouds = terrain:FindFirstChildOfClass("Clouds")
    if not clouds then clouds = ensureOwned("Clouds", "RM4_RealClouds", terrain) end
    if not clouds then return end
    setProperty(clouds, "Enabled", true, "SkyClouds")
    local oldCover = baseline(clouds, "Cover", 0.30)
    setProperty(clouds, "Cover", math.clamp(oldCover * 0.6 + 0.16, 0.22, 0.65), "SkyClouds")
    setProperty(clouds, "Density", math.clamp(baseline(clouds, "Density", 0.4) * 0.6 + 0.20, 0.31, 0.65), "SkyClouds")
    local day = getDayWeight()
    local cloudColor = safeLerp(Color3.fromRGB(167, 175, 188), Color3.fromRGB(235, 236, 237), day)
    setProperty(clouds, "Color", safeLerp(baseline(clouds, "Color", cloudColor), cloudColor, 0.6), "SkyClouds")
end

local TERRAIN_PALETTE = {
    Grass = Color3.fromRGB(89, 111, 74),
    LeafyGrass = Color3.fromRGB(82, 106, 74),
    Ground = Color3.fromRGB(119, 109, 94),
    Sand = Color3.fromRGB(177, 163, 133),
    Mud = Color3.fromRGB(93, 82, 70),
    Rock = Color3.fromRGB(105, 109, 108),
    Slate = Color3.fromRGB(99, 106, 107),
    Basalt = Color3.fromRGB(69, 71, 72),
    Limestone = Color3.fromRGB(174, 168, 148),
    Concrete = Color3.fromRGB(155, 156, 153),
    Pavement = Color3.fromRGB(124, 126, 126),
    Snow = Color3.fromRGB(234, 237, 238),
    Ice = Color3.fromRGB(185, 207, 213),
    WoodPlanks = Color3.fromRGB(141, 113, 83),
}

local function applyTerrain()
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return end
    if CONFIG.TerrainWater then
        local naturalWater = Color3.fromRGB(44, 91, 102)
        setProperty(terrain, "WaterColor", safeLerp(baseline(terrain, "WaterColor", naturalWater), naturalWater, 0.78), "Terrain")
        setProperty(terrain, "WaterReflectance", 0.46, "Terrain")
        setProperty(terrain, "WaterTransparency", 0.38, "Terrain")
        setProperty(terrain, "WaterWaveSize", 0.16, "Terrain")
        setProperty(terrain, "WaterWaveSpeed", 10, "Terrain")
        setProperty(terrain, "GrassLength", 0.55, "Terrain")
    end
    if not CONFIG.TerrainColors then return end
    for name, target in pairs(TERRAIN_PALETTE) do
        local material = Enum.Material[name]
        if material then
            local ok, old = pcall(function() return terrain:GetMaterialColor(material) end)
            if ok then
                local baseColor = terrainOriginal[name] or old
                local newColor = baseColor:Lerp(target, 0.42)
                if not equivalent(newColor, old) then
                    local okWrite, err = pcall(function() terrain:SetMaterialColor(material, newColor) end)
                    if okWrite then
                        local key = name
                        if terrainOriginal[key] == nil then terrainOriginal[key] = old end
                        local okCheck, current = pcall(function() return terrain:GetMaterialColor(material) end)
                        if okCheck and equivalent(current, newColor) then
                            state.sections.Terrain.changed += 1
                            state.writes += 1
                        else
                            rejected("Terrain", "SetMaterialColor(" .. name .. ")", "Readback weicht ab")
                        end
                    else
                        rejected("Terrain", "SetMaterialColor(" .. name .. ")", err)
                    end
                end
            else
                rejected("Terrain", "GetMaterialColor(" .. name .. ")", old)
            end
        end
    end
end

local function isInCharacterOrTool(inst)
    local ancestor = inst.Parent
    local levels = 0
    while ancestor and ancestor ~= Workspace and levels < 8 do
        if ancestor:IsA("Tool") or ancestor:IsA("Accessory") then return true end
        if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then return true end
        ancestor = ancestor.Parent
        levels += 1
    end
    return false
end

local function hasArtwork(part)
    for _, child in ipairs(part:GetChildren()) do
        if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance")
            or child:IsA("SurfaceGui") or child:IsA("SpecialMesh") then
            return true
        end
    end
    return false
end

local function staticGeometry(part)
    if not part:IsA("Part") or not part.Anchored or not part.CanCollide then return false end
    if part.Transparency > 0.08 or isInCharacterOrTool(part) then return false end
    if part.Shape ~= Enum.PartType.Block or hasArtwork(part) then return false end
    if part.Material == Enum.Material.Neon or part.Material == Enum.Material.Glass then return false end
    local s = part.Size
    if s.Magnitude < 9 then return false end
    return true
end

local function photographicSurface(part)
    if not state.running or not state.enabled then return end
    if state.worldChanged >= CONFIG.MaxWorldPartsChanged then return end
    if not staticGeometry(part) then return end

    local changed = false
    local h, saturation, value = part.Color:ToHSV()
    local size = part.Size
    local largest = math.max(size.X, size.Y, size.Z)
    local isStructure = largest >= 9 and (size.Y >= 5 or (size.X >= 9 and size.Z >= 9))
    local neutral = saturation < 0.22 and value > 0.15 and value < 0.98

    -- Grosse glatte, graue Plastik-Waende und Boeden sind ein haeufiges
    -- Roblox-Problem: sie erhalten eine echte Engine-Betonmaterialstruktur.
    -- Keine Neonschilder, Spielmechanik, Terrainvoxel oder Custom-Meshes.
    if CONFIG.StaticWorldMaterials and isStructure and neutral and (
        part.Material == Enum.Material.Plastic or part.Material == Enum.Material.SmoothPlastic
    ) then
        local before = readProperty(part, "Material", nil)
        setProperty(part, "Material", Enum.Material.Concrete, "World")
        if before ~= readProperty(part, "Material", nil) then changed = true end
    end

    -- Statisch gerenderte Geometrie soll Schatten werfen.
    if CONFIG.StructuralShadows and isStructure and not part.CastShadow then
        if setProperty(part, "CastShadow", true, "World") then changed = true end
    end

    -- Stark uebersaettigte GROSSE Wandfarben werden leicht entsaettigt.
    -- Nicht bei interaktiven, bewegten, transparenten oder texturierten Objekten.
    if CONFIG.NaturalSurfaceColors and isStructure and saturation > 0.74 and value > 0.4
        and part.Material ~= Enum.Material.Neon then
        local softer = Color3.fromHSV(h, math.max(0.48, saturation * 0.78), value)
        if setProperty(part, "Color", softer, "World") then changed = true end
    end

    -- Kleine Reflexionswerte nur an bereits vom Spiel als Metall/Ice
    -- markierten soliden Oberflaechen. Keine Fake-Spiegel.
    if part.Material == Enum.Material.Metal or part.Material == Enum.Material.DiamondPlate then
        local originalReflectance = baseline(part, "Reflectance", 0)
        if originalReflectance < 0.055 then
            if setProperty(part, "Reflectance", 0.055, "World") then changed = true end
        end
    end
    if changed then state.worldChanged += 1 end
end

local function improveLight(instance)
    if not CONFIG.ExistingLightShadows or state.lightsChanged >= CONFIG.MaxLightSourcesChanged then return end
    if instance:IsA("PointLight") or instance:IsA("SpotLight") or instance:IsA("SurfaceLight") then
        if instance.Enabled and instance.Brightness > 0.2 and instance.Range > 3 then
            if not instance.Shadows then
                local success = setProperty(instance, "Shadows", true, "LocalLights")
                if success then state.lightsChanged += 1 end
            end
        end
    end
end

local function scanWorldAsync()
    if not state.enabled or not state.running or state.scanning then return end
    state.scanning = true
    state.scanComplete = false
    state.generation += 1
    local scanGeneration = state.generation

    task.spawn(function()
        local ok, descendants = pcall(function() return Workspace:GetDescendants() end)
        if not ok then
            rejected("World", "GetDescendants", descendants)
            state.scanning = false
            return
        end
        for index, instance in ipairs(descendants) do
            if not state.running or not state.enabled or state.generation ~= scanGeneration then break end
            state.worldVisited += 1
            if instance:IsA("BasePart") then photographicSurface(instance) end
            if instance:IsA("Light") then improveLight(instance) end
            if index % CONFIG.ScanBatch == 0 then task.wait() end
            if state.worldChanged >= CONFIG.MaxWorldPartsChanged
                and state.lightsChanged >= CONFIG.MaxLightSourcesChanged then break end
        end
        if state.generation == scanGeneration then
            state.scanComplete = true
            state.scanning = false
            print(string.format(
                "[RM v4] Scan: %d Instanzen, %d Weltoberflaechen, %d Lichtquellen geaendert.",
                state.worldVisited, state.worldChanged, state.lightsChanged
            ))
        end
    end)
end

local function applyAll()
    naturalLight()
    installPostFX()
    applyAtmosphere()
    applySkyAndClouds()
    applyTerrain()
    scanWorldAsync()
end

--[[
  LOCAL WEATHER PHYSICS v4
  Numerically integrated precipitation, swept raycast collisions, splash impulses,
  slope-dependent shallow-water runoff, snowpack deposition and melt. All pooled,
  client only, cosmetic: no real Terrain voxel floods, no server authority.
--]]
local weather = {
    mode = "OFF", folder = nil, droplets = {}, impacts = {}, surfacePool = {}, cells = {},
    cellCount = 0, buildToken = 0, rayParams = nil,
    stepTime = 0, indoorTime = 1, surfaceTime = 0, cloudTime = 0,
    indoor = false, hits = 0, roofs = 0, totalSpawned = 0, impactIndex = 0,
    cellCursor = 0, flowCursor = 0, elapsed = 0, avgFps = 60,
    simStepCount = 0, simWindowStart = 0, simMeasuredHz = 0,
    droppedPhysicsTime = 0, maxSubstepsSeen = 0,
    waterTransferred = 0, snowMelt = 0, failedSpawns = 0, raycasts = 0,
}
state.weatherMode = "RAIN"
state.weatherIntensity = 1.0
state.weatherIndoor = false
state.weatherLiveParticles = 0
state.weatherImpacts = 0
state.weatherWetCells = 0
state.weatherSnowCells = 0
state.weatherRunoff = 0
state.weatherMelt = 0
state.weatherSimulation = "lokale Partikel + Oberflaechenmodell"
state.weatherPhysicsHz = CONFIG.PhysicsHz
state.weatherPhysicsMeasuredHz = 0
state.weatherDroppedPhysicsTime = 0

local rng = Random.new()
local function rand(a, b) return rng:NextNumber(a, b) end
local colorRain = Color3.fromRGB(171, 185, 192)
local colorSnow = Color3.fromRGB(232, 235, 237)
local weatherButton = nil
local CELL_SIZE = 2.7 -- studs; local neighborhood only, no map-wide terrain writes
local MAX_CELLS = 75
local MAX_RAYCASTS_PER_FRAME = 280

local function makeWeatherPart(name, shape, size, material, tint, transparency)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Shape = shape
    p.Material = material
    p.Size = size
    p.Color = tint
    p.Transparency = transparency
    p.CFrame = CFrame.new(0, -10000, 0)
    p.Parent = weather.folder
    return p
end
local function hidePart(p)
    if p then p.Transparency = 1; p.CFrame = CFrame.new(0, -10000, 0) end
end
local function makeRayParams()
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Exclude
    rp.IgnoreWater = false
    rp.RespectCanCollide = true
    local excludes = {weather.folder}
    if LocalPlayer.Character then excludes[#excludes + 1] = LocalPlayer.Character end
    rp.FilterDescendantsInstances = excludes
    weather.rayParams = rp
end
local function ray(origin, direction)
    if weather.raycasts >= MAX_RAYCASTS_PER_FRAME then return nil end
    weather.raycasts += 1
    return Workspace:Raycast(origin, direction, weather.rayParams)
end
local function stormWind(t, snow)
    local w = readProperty(Workspace, "GlobalWind", Vector3.zero)
    if typeof(w) ~= "Vector3" then w = Vector3.zero end
    local horizontal = Vector3.new(w.X, 0, w.Z)
    if horizontal.Magnitude > 25 then horizontal = horizontal.Unit * 25 end
    local gust = Vector3.new(math.sin(t * 0.23) * 3 + math.sin(t * 0.77) * 1.4,
        0, math.cos(t * 0.31) * 2.2)
    return horizontal * (snow and 0.6 or 0.29) + gust
end
local function isStationarySurface(hit)
    if not hit or hit.Material == Enum.Material.Water then return false end
    if hit.Normal.Y < 0.61 then return false end
    if hit.Instance and hit.Instance:IsA("BasePart") then
        if not hit.Instance.Anchored then return false end
        if hit.Instance.Transparency > 0.3 then return false end
    end
    return true
end
local function surfaceKey(pos)
    return math.floor(pos.X / CELL_SIZE + 0.5) .. ":"
        .. math.floor(pos.Z / CELL_SIZE + 0.5) .. ":"
        .. math.floor(pos.Y / 3.5 + 0.5)
end
local function newSurfaceCell(hit)
    local key = surfaceKey(hit.Position)
    local current = weather.cells[key]
    if current and math.abs(current.y - hit.Position.Y) < 1.3 then return current end
    local target = nil
    if weather.cellCount < MAX_CELLS then
        weather.cellCount += 1
        target = weather.surfacePool[weather.cellCount]
    else
        -- LRU eviction. Old trails do not pile up indefinitely across a big map.
        local oldest = math.huge
        for _, cell in ipairs(weather.surfacePool) do
            if cell.used and cell.lastTouched < oldest then
                oldest = cell.lastTouched
                target = cell
            end
        end
        if not target then return nil end
        weather.cells[target.key] = nil
    end
    weather.cells[key] = target
    target.used = true
    target.key = key
    target.pos = hit.Position
    target.y = hit.Position.Y
    target.normal = hit.Normal
    target.water = 0
    target.snow = 0
    target.lastTouched = weather.elapsed
    target.wetPart.Material = Enum.Material.Glass
    target.wetPart.Color = Color3.fromRGB(47, 58, 64)
    target.wetPart.Reflectance = 0.09
    hidePart(target.wetPart)
    hidePart(target.snowPart)
    return target
end
local weatherImpactListeners = {}
function state.AddWeatherImpactListener(callback)
    if type(callback) ~= "function" then return function() end end
    weatherImpactListeners[#weatherImpactListeners+1] = callback
    return function()
        for i=#weatherImpactListeners,1,-1 do
            if weatherImpactListeners[i] == callback then
                table.remove(weatherImpactListeners,i)
                break
            end
        end
    end
end
local function addSurface(hit, isSnow, amount)
    if not isStationarySurface(hit) then return end
    for _,callback in ipairs(weatherImpactListeners) do
        pcall(callback,hit.Position,hit.Normal,isSnow,amount,hit.Instance)
    end
    local cell = newSurfaceCell(hit)
    if not cell then return end
    cell.lastTouched = weather.elapsed
    if isSnow then
        cell.snow = math.clamp(cell.snow + amount, 0, 1.9)
    else
        cell.water = math.clamp(cell.water + amount, 0, 1.75)
    end
end
local function impactAt(pos, normal, isSnow)
    weather.hits += 1
    state.weatherImpacts = weather.hits
    -- Independent ballistic splash fragments (local visual solver).
    local count = isSnow and 1 or 2
    for _ = 1, count do
        weather.impactIndex = (weather.impactIndex % #weather.impacts) + 1
        local imp = weather.impacts[weather.impactIndex]
        if imp then
            local tangent = Vector3.new(rand(-1, 1), 0, rand(-1, 1))
            local shove = tangent * (isSnow and rand(0.25, 1.2) or rand(1.7, 4.7))
            imp.pos = pos + normal * 0.06
            imp.vel = normal * (isSnow and rand(0.5, 2.1) or rand(3.7, 6.5)) + shove
            imp.ttl = isSnow and rand(0.12, 0.29) or rand(0.10, 0.25)
            imp.maxLife = imp.ttl
            imp.part.Color = isSnow and colorSnow or colorRain
            imp.part.Size = Vector3.new(isSnow and 0.1 or 0.065, isSnow and 0.1 or 0.065, isSnow and 0.1 or 0.065)
            imp.part.Transparency = isSnow and 0.2 or 0.35
        end
    end
end
local function weatherSky()
    if not state.enabled or state.weatherMode == "OFF" then return end
    local isRain = state.weatherMode == "RAIN"
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    local clouds = terrain and terrain:FindFirstChildOfClass("Clouds")
    if clouds then
        setProperty(clouds, "Enabled", true, "SkyClouds")
        setProperty(clouds, "Cover", isRain and 0.86 or 0.82, "SkyClouds")
        setProperty(clouds, "Density", isRain and 0.7 or 0.58, "SkyClouds")
        setProperty(clouds, "Color", isRain and Color3.fromRGB(160, 167, 173) or Color3.fromRGB(206, 209, 211), "SkyClouds")
    end
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        setProperty(atmosphere, "Haze", isRain and 2.0 or 1.65, "Atmosphere")
        setProperty(atmosphere, "Density", isRain and 0.31 or 0.25, "Atmosphere")
        setProperty(atmosphere, "Color", isRain and Color3.fromRGB(190, 198, 203) or Color3.fromRGB(211, 221, 229), "Atmosphere")
    end
    setProperty(Lighting, "ExposureCompensation", math.clamp(baseline(Lighting, "ExposureCompensation", 0)
        - (isRain and 0.15 or 0.07), -1, 0.7), "Lighting")
end
local function destroyWeather()
    weather.mode = "OFF"
    weather.buildToken += 1
    if weather.folder then pcall(function() weather.folder:Destroy() end) end
    weather.folder = nil
    weather.droplets = {}
    weather.impacts = {}
    weather.surfacePool = {}
    weather.cells = {}
    weather.cellCount = 0
    weather.rayParams = nil
    state.weatherLiveParticles = 0
    state.weatherWetCells = 0
    state.weatherSnowCells = 0
    state.weatherIndoor = false
end
local updatePuddleOrSnow -- forward declaration, defined before first call at runtime
local function buildWeather()
    -- Keep surface mass across rain/snow transitions: snow melts when rain begins,
    -- water evaporates/drains when snow begins. OFF destroys all local proxies.
    local preserved = {}
    if state.weatherMode ~= "OFF" then
        for _, cell in ipairs(weather.surfacePool) do
            if cell.used and (cell.water > .02 or cell.snow > .02) then
                preserved[#preserved + 1] = {
                    Position = cell.pos, Normal = cell.normal,
                    water = cell.water, snow = cell.snow,
                }
            end
        end
    end
    destroyWeather()
    if not state.running or not state.enabled or state.weatherMode == "OFF" then return end
    weather.mode = state.weatherMode
    weather.folder = Instance.new("Folder")
    weather.folder.Name = "RM4_LOCAL_WEATHER_PHYSICS"
    weather.folder.Parent = Workspace
    local token = weather.buildToken
    makeRayParams()
    weather.hits = 0
    weather.roofs = 0
    weather.failedSpawns = 0
    weather.elapsed = 0
    weather.indoorTime = 1
    weather.surfaceTime = 0
    weather.avgFps = 60
    weather.waterTransferred = 0
    weather.snowMelt = 0
    weather.stepTime = 0
    weather.simStepCount = 0
    weather.simWindowStart = 0
    weather.simMeasuredHz = 0
    weather.droppedPhysicsTime = 0
    weather.maxSubstepsSeen = 0
    state.weatherPhysicsMeasuredHz = 0
    state.weatherDroppedPhysicsTime = 0
    local snow = weather.mode == "SNOW"
    local count = math.clamp(math.floor((snow and CONFIG.SnowFlakes or CONFIG.RainDrops)
        * state.weatherIntensity), 2, 260)
    for i = 1, count do
        local p = makeWeatherPart(snow and "Snow" or "Rain", snow and Enum.PartType.Ball or Enum.PartType.Block,
            snow and Vector3.new(0.13, 0.13, 0.13) or Vector3.new(0.035, 1.05, 0.035),
            Enum.Material.SmoothPlastic, snow and colorSnow or colorRain, 1)
        weather.droplets[#weather.droplets + 1] = {
            part = p, active = false, cooldown = rand(0, 0.7), pos = Vector3.zero,
            vel = Vector3.zero, age = 0, alpha = 0.5, seed = rand(0, 100)
        }
        if i % 40 == 0 then task.wait() end
        if token ~= weather.buildToken or not state.running or not state.enabled then return end
    end
    for i = 1, CONFIG.MaxSplashParts do
        local p = makeWeatherPart("BallisticImpact", Enum.PartType.Ball,
            Vector3.new(.06, .06, .06), Enum.Material.SmoothPlastic, colorRain, 1)
        weather.impacts[#weather.impacts + 1] = {part = p, ttl = 0, maxLife = 1, pos = Vector3.zero, vel = Vector3.zero}
    end
    -- Physical-looking surface layers: clients see real 3D parts and evolving mass,
    -- but these are NOT full Navier-Stokes liquid/ice or changes to server Terrain.
    for i = 1, MAX_CELLS do
        -- Smooth ellipsoids: no more rectangular puddles or snow tiles.
        local wet = makeWeatherPart("LocalPuddle", Enum.PartType.Block, Vector3.one,
            Enum.Material.Glass, Color3.fromRGB(105, 120, 129), 1)
        local wetMesh = Instance.new("SpecialMesh")
        wetMesh.MeshType = Enum.MeshType.Sphere; wetMesh.Scale=Vector3.one
        wetMesh.Parent=wet
        local snowPart = makeWeatherPart("LocalSnowpack", Enum.PartType.Block, Vector3.one,
            Enum.Material.Snow, Color3.fromRGB(248,250,253), 1)
        local snowMesh = Instance.new("SpecialMesh")
        snowMesh.MeshType = Enum.MeshType.Sphere; snowMesh.Scale=Vector3.one
        snowMesh.Parent=snowPart
        weather.surfacePool[i] = {
            wetPart=wet,snowPart=snowPart,wetMesh=wetMesh,snowMesh=snowMesh,
            used=false,lastTouched=-1,seed=rand(0,1000),
        }
    end
    for _, previous in ipairs(preserved) do
        -- The input is a snapshot from our own verified surface collider.
        local restored = newSurfaceCell({
            Position = previous.Position, Normal = previous.Normal,
            Material = Enum.Material.Concrete, Instance = Workspace.Terrain,
        })
        if restored then
            restored.water = previous.water
            restored.snow = previous.snow
            updatePuddleOrSnow(restored)
        end
    end
    weatherSky()
end
local function setWeatherMode(mode)
    if mode ~= "RAIN" and mode ~= "SNOW" and mode ~= "OFF" then return end
    state.weatherMode = mode
    if state.enabled then
        buildWeather()
        if mode == "OFF" then
            naturalLight()
            applyAtmosphere()
            applySkyAndClouds()
        end
    end
    print("[RM v4] " .. mode .. " / " .. tostring(state.weatherIntensity) .. "x")
end
state.SetWeatherMode = setWeatherMode
local function cycleWeather()
    if state.weatherMode == "RAIN" then setWeatherMode("SNOW")
    elseif state.weatherMode == "SNOW" then setWeatherMode("OFF")
    else setWeatherMode("RAIN") end
end
state.CycleWeather = cycleWeather
local function cycleWeatherIntensity()
    if state.weatherIntensity < 0.8 then state.weatherIntensity = 1
    elseif state.weatherIntensity < 1.3 then state.weatherIntensity = 1.5
    else state.weatherIntensity = 0.6 end
    if state.enabled and state.weatherMode ~= "OFF" then buildWeather() end
end
state.CycleWeatherIntensity = cycleWeatherIntensity
state.Keybinds = {
    Toggle=CONFIG.Hotkey,Details=CONFIG.DetailHotkey,
    Weather=CONFIG.WeatherHotkey,Intensity=CONFIG.WeatherIntensityHotkey
}
function state.SetKeybind(action,key)
    if state.Keybinds[action]==nil or typeof(key)~="EnumItem"
        or key.EnumType~=Enum.KeyCode then return false end
    for other,value in pairs(state.Keybinds) do
        if other~=action and value==key then return false end
    end
    state.Keybinds[action]=key
    return true
end
function state.SetWeatherIntensityFraction(value)
    local amount=math.clamp(tonumber(value) or 1,.01,1.0)
    if math.abs(state.weatherIntensity-amount)>.009 then
        state.weatherIntensity=amount
        if state.enabled and state.weatherMode~="OFF" then buildWeather() end
    end
end

local function spawnParticle(d, focus, now)
    d.active = false
    hidePart(d.part)
    local snow = weather.mode == "SNOW"
    local wind = stormWind(now, snow)
    -- Sample from a real volume around the camera, not a HUD plane.
    for _ = 1, 7 do
        local radius = snow and 34 or 38
        local x, z = rand(-radius, radius), rand(-radius, radius)
        if weather.indoor and x * x + z * z < 150 then
            x += (x < 0 and -13 or 13)
        end
        local origin = focus + Vector3.new(x, rand(snow and 9 or 14, snow and 32 or 43), z)
        -- A candidate underneath a roof is invalid; outdoors remains active.
        local roof = ray(origin + Vector3.new(0, .3, 0), Vector3.new(0, 135, 0))
        if not roof then
            d.pos = origin
            d.age = 0
            d.active = true
            d.seed = rand(0, 1000)
            if snow then
                d.vel = Vector3.new(wind.X * 0.3 + rand(-1.1, 1.1), rand(-5.5, -2.0), wind.Z * 0.3 + rand(-1.1, 1.1))
                local size = rand(.10, .19)
                d.part.Shape = Enum.PartType.Ball
                d.part.Size = Vector3.new(size, size, size)
                d.alpha = rand(.17, .4)
            else
                d.vel = Vector3.new(wind.X * .7 + rand(-3, 3), rand(-115, -78), wind.Z * .7 + rand(-3, 3))
                local width = rand(.025, .042)
                d.part.Shape = Enum.PartType.Block
                d.part.Size = Vector3.new(width, rand(.72, 1.55), width)
                d.alpha = rand(.48, .69)
            end
            d.part.Transparency = d.alpha
            return
        end
        weather.roofs += 1
    end
    d.cooldown = rand(.14, .36)
    weather.failedSpawns += 1
end

updatePuddleOrSnow = function(cell)
    -- Single renderer policy: the organic-surface module owns all visible
    -- snow/puddle shapes. Keep original grid/mass physics, hide duplicate proxies.
    hidePart(cell.wetPart)
    hidePart(cell.snowPart)
end
local function surfaceStep(dt)
    if weather.cellCount == 0 then return end
    local wet, snowy = 0, 0
    local sun = getDayWeight()
    local ambientMelt = (weather.mode == "RAIN" and 0.009 or 0.00016 + sun * 0.0012) * dt
    -- Shallow-surface mass balance: input, evaporation, melting, runoff.
    for _, cell in ipairs(weather.surfacePool) do
        if cell.used then
            if cell.snow > 0 then
                local loss = math.min(cell.snow, ambientMelt/(1+cell.snow*3))
                cell.snow -= loss
                if loss > 0 then
                    cell.water = math.min(1.75, cell.water + loss * .70)
                    weather.snowMelt += loss
                end
            end
            if cell.water > 0 then
                cell.water = math.max(0, cell.water - (weather.mode == "RAIN" and .008 or .022) * dt)
            end
            if cell.water > .025 then wet += 1 end
            if cell.snow > .025 then snowy += 1 end
            updatePuddleOrSnow(cell)
        end
    end
    -- A subset of slope cells transfers mass to verified lower neighboring ground.
    -- Does not imply river hydraulics, full fluid pressure, or network replication.
    local allowedTransfers = 7
    for _ = 1, allowedTransfers do
        weather.flowCursor = weather.flowCursor % MAX_CELLS + 1
        local cell = weather.surfacePool[weather.flowCursor]
        if cell and cell.used and cell.water > .09 and cell.normal.Y < .995 then
            local downslope = Vector3.new(cell.normal.X, 0, cell.normal.Z)
            if downslope.Magnitude > .08 then
                local nextSpot = cell.pos + downslope.Unit * CELL_SIZE
                local landing = ray(nextSpot + Vector3.new(0, 3.2, 0), Vector3.new(0, -9, 0))
                if landing and landing.Position.Y <= cell.y + .06 and isStationarySurface(landing) then
                    local receiver = newSurfaceCell(landing)
                    if receiver and receiver ~= cell then
                        local moved = math.min(cell.water * .15, .08)
                        cell.water -= moved
                        receiver.water = math.min(1.75, receiver.water + moved)
                        receiver.lastTouched = weather.elapsed
                        weather.waterTransferred += moved
                    end
                end
            end
        end
    end
    state.weatherWetCells = wet
    state.weatherSnowCells = snowy
    state.weatherRunoff = weather.waterTransferred
    state.weatherMelt = weather.snowMelt
end
local function weatherStep(dt, drawVisuals)
    if not weather.folder or not weather.rayParams or not state.enabled then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local now = os.clock()
    weather.elapsed += dt
    weather.raycasts = 0
    local focus = camera.CFrame.Position + camera.CFrame.LookVector * 7
    weather.indoorTime += dt
    weather.surfaceTime += dt
    weather.cloudTime += dt
    if weather.indoorTime >= .6 then
        weather.indoorTime = 0
        makeRayParams() -- also refreshes character exclusion on respawn
        weather.indoor = ray(camera.CFrame.Position + Vector3.new(0, 1, 0), Vector3.new(0, 180, 0)) ~= nil
        state.weatherIndoor = weather.indoor
    end
    if weather.cloudTime >= 8 then weather.cloudTime = 0; weatherSky() end
    local snow = weather.mode == "SNOW"
    local wind = stormWind(now, snow)
    local gravity = math.clamp(readProperty(Workspace, "Gravity", 196.2), 50, 300)
    local visible = 0
    local impactBudget = CONFIG.MaxImpactsPerStep
    local fpsFactor = math.clamp((weather.avgFps - 18) / 32, .37, 1)
    for i, drop in ipairs(weather.droplets) do
        local keep = i <= math.floor(#weather.droplets * fpsFactor)
        if not keep then
            if drop.active then drop.active = false; hidePart(drop.part) end
        elseif not drop.active then
            drop.cooldown -= dt
            if drop.cooldown <= 0 then spawnParticle(drop, focus, now) end
        else
            drop.age += dt
            local v = drop.vel
            if snow then
                local drift = Vector3.new(math.sin(now * 1.4 + drop.seed) * 2.1, 0,
                    math.cos(now * 1.25 + drop.seed) * 2.2)
                local horizontal = Vector3.new(v.X, 0, v.Z)
                horizontal += (wind + drift - horizontal) * math.min(1, dt * 1.85)
                -- Terminal fall velocity caused by high aerodynamic drag.
                local terminal = 9.0
                local rate = -gravity * .075 * (1 - math.min(1, (v.Y/terminal)^2))
                local falling = math.max(-terminal, v.Y + rate * dt)
                v = Vector3.new(horizontal.X, falling, horizontal.Z)
            else
                local horizontal = Vector3.new(v.X, 0, v.Z)
                horizontal += (wind - horizontal) * math.min(1, dt * 2.1)
                -- Gravity versus quadratic air drag; terminal rain velocity.
                local terminal = 125
                local gDrag = -gravity * (1 - math.min(1, (v.Y / terminal)^2))
                v = Vector3.new(horizontal.X, math.max(-terminal, v.Y + gDrag * dt), horizontal.Z)
            end
            local previous = drop.pos
            local nextPos = previous + v * dt
            drop.vel = v
            drop.pos = nextPos
            -- Swept collision test from previous to next position, so rapid drops
            -- cannot simply tunnel through a floor or a roof between frames.
            local hit = ray(previous, nextPos - previous)
            if hit then
                if impactBudget > 0 and (hit.Position - camera.CFrame.Position).Magnitude < 52 then
                    impactAt(hit.Position, hit.Normal, snow)
                    impactBudget -= 1
                end
                addSurface(hit, snow, snow and rand(.014, .034) or rand(.012, .027))
                drop.active = false
                drop.cooldown = rand(0, .20)
                hidePart(drop.part)
            else
                local delta = nextPos - camera.CFrame.Position
                local expired = drop.age > (snow and 10 or 2.2) or delta.Y < -52
                    or delta.Y > 70 or math.abs(delta.X) > 55 or math.abs(delta.Z) > 55
                if expired then
                    drop.active = false
                    drop.cooldown = rand(.02, .22)
                    hidePart(drop.part)
                else
                    -- Physik mit 90 Hz; das sichtbare Mesh nur einmal pro Renderframe bewegen.
                    if drawVisuals then
                        if snow then
                            drop.part.CFrame = CFrame.new(nextPos)
                        else
                            drop.part.CFrame = CFrame.lookAt(nextPos, nextPos + v)
                                * CFrame.Angles(math.pi/2, 0, 0)
                        end
                        drop.part.Transparency = math.clamp(drop.alpha + (delta.Magnitude < 3 and .15 or 0), 0, 1)
                    end
                    visible += 1
                end
            end
        end
    end
    state.weatherLiveParticles = visible
    for _, imp in ipairs(weather.impacts) do
        if imp.ttl > 0 then
            local previous = imp.pos
            imp.vel += Vector3.new(0, -gravity * dt, 0)
            local newPos = previous + imp.vel * dt
            local collision = ray(previous, newPos - previous)
            if collision then imp.ttl = 0 else imp.pos = newPos; imp.ttl -= dt end
            if imp.ttl <= 0 then
                hidePart(imp.part)
            elseif drawVisuals then
                imp.part.CFrame = CFrame.new(newPos)
                imp.part.Transparency = math.clamp(1 - .70 * (imp.ttl / imp.maxLife), 0, 1)
            end
        end
    end
    if weather.surfaceTime >= .32 then
        local amount = weather.surfaceTime
        weather.surfaceTime = 0
        surfaceStep(amount)
    end
end
-- Die Heartbeat-Frequenz des Hosts bleibt variabel (z.B. 60 FPS).
-- Der Akkumulator fuehrt dafuer im Mittel 90 feste Physikschritte/s aus.
-- Die Darstellung wird zur FPS-Schonung nur beim letzten Schritt aktualisiert.
local FIXED_PHYSICS_DT = 1 / CONFIG.PhysicsHz
connections[#connections + 1] = RunService.Heartbeat:Connect(function(dt)
    if not state.running or not state.enabled or not weather.folder then return end
    local frameDt = math.clamp(dt, 0, CONFIG.MaxFrameDelta)
    weather.avgFps = weather.avgFps * .94 + (1 / math.max(dt, .001)) * .06
    weather.stepTime += frameDt
    local steps = math.min(
        math.floor((weather.stepTime + 1e-9) / FIXED_PHYSICS_DT),
        CONFIG.MaxPhysicsSubsteps
    )
    if steps < 1 then return end

    weather.stepTime -= steps * FIXED_PHYSICS_DT
    if weather.stepTime >= FIXED_PHYSICS_DT then
        -- Bei extremem Lag keinen unendlichen Rueckstau aufbauen.
        local skipped = math.floor(weather.stepTime / FIXED_PHYSICS_DT) * FIXED_PHYSICS_DT
        weather.droppedPhysicsTime += skipped
        weather.stepTime -= skipped
    end
    weather.maxSubstepsSeen = math.max(weather.maxSubstepsSeen, steps)
    for substep = 1, steps do
        weatherStep(FIXED_PHYSICS_DT, substep == steps)
    end
    weather.simStepCount += steps
    local now = os.clock()
    if weather.simWindowStart == 0 then weather.simWindowStart = now end
    local duration = now - weather.simWindowStart
    if duration >= 1 then
        weather.simMeasuredHz = weather.simStepCount / duration
        state.weatherPhysicsMeasuredHz = weather.simMeasuredHz
        state.weatherDroppedPhysicsTime = weather.droppedPhysicsTime
        weather.simStepCount = 0
        weather.simWindowStart = now
    end
end)

local function restore()
    destroyWeather()
    state.generation += 1 -- laufende Scanner abbrechen
    state.scanning = false
    for instance, props in pairs(original) do
        for property, oldValue in pairs(props) do
            pcall(function() instance[property] = oldValue end)
        end
    end
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        for materialName, oldColor in pairs(terrainOriginal) do
            pcall(function() terrain:SetMaterialColor(Enum.Material[materialName], oldColor) end)
        end
    end
    for i = #created, 1, -1 do
        pcall(function() created[i]:Destroy() end)
    end
    original = {}
    terrainOriginal = {}
    created = {}
    postEffects = {}
    state.worldChanged = 0
    state.lightsChanged = 0
    state.worldVisited = 0
    state.scanComplete = false
end

local function report()
    local out = {
        "roblox_modPack REALISM v4 | " .. (state.enabled and "AN" or "AUS"),
        "LightingStyle: " .. state.lightingStyle,
        string.format("Wetter-Physik: Ziel %d Hz | gemessen %.1f Hz | max %d Substeps",
            CONFIG.PhysicsHz, state.weatherPhysicsMeasuredHz, weather.maxSubstepsSeen),
        string.format("Verworfene Nachholzeit: %.3f s (nur bei starkem Lag)",
            state.weatherDroppedPhysicsTime),
        string.format("Wetter: %s | Intensitaet %.1fx | innen: %s", state.weatherMode, state.weatherIntensity, tostring(state.weatherIndoor)),
        string.format("Simulierte 3D-Tropfen/Flocken: %d | Einschlaege: %d | Dachsperren: %d", state.weatherLiveParticles, state.weatherImpacts, weather.roofs),
        string.format("Oberflaechen: %d Pfuetzenzellen | %d Schneezellen", state.weatherWetCells, state.weatherSnowCells),
        string.format("Abfluss %.2f | Schmelze %.2f (lokale Einheiten) | FPS-Schaetzung %.0f", state.weatherRunoff, state.weatherMelt, weather.avgFps),
        string.format("Erfolgreiche Schreiboperationen: %d", state.writes),
        string.format("Scan: %d Objekte | %d Weltflaechen | %d Lichtquellen", state.worldVisited, state.worldChanged, state.lightsChanged),
    }
    for _, section in ipairs(SECTIONS) do
        local stat = state.sections[section]
        out[#out + 1] = string.format("%s: %d geaendert / %d verweigert", section, stat.changed, stat.rejected)
    end
    if #state.failures > 0 then
        out[#out + 1] = "API-Grenzen/Fehler (erste " .. #state.failures .. "):"
        for _, text in ipairs(state.failures) do out[#out + 1] = " - " .. text end
    end
    out[#out + 1] = "Keine echten Server-Fluide oder Terrainvoxel-Aenderungen; nur lokal."
    out[#out + 1] = "Keine neuen Shader, SSR oder PBR-Texturen in fremden Spielen."
    return table.concat(out, "\n")
end
state.GetReport = report
state.PrintReport = function() print("[RM v4]\n" .. report()) end

local function updateUI()
    if statusButton then
        statusButton.Text = state.enabled and "REALISM  AN  | F8" or "REALISM  AUS  | F8"
        statusButton.BackgroundColor3 = state.enabled and Color3.fromRGB(53, 59, 60) or Color3.fromRGB(44, 45, 47)
    end
    if weatherButton then
        weatherButton.Text = string.format("WETTER %s  %.1fx | F7", state.weatherMode, state.weatherIntensity)
        weatherButton.BackgroundColor3 = Color3.fromRGB(47, 51, 54)
    end
    if detailsPanel then detailsPanel.Visible = detailsVisible end
    if detailsLabel then detailsLabel.Text = report() end
end

local function setEnabled(enabled)
    if not state.running or state.enabled == enabled then return end
    if enabled then
        state.enabled = true
        applyAll()
        buildWeather()
    else
        state.enabled = false
        restore()
    end
    updateUI()
end
state.SetEnabled = setEnabled
state.ClientCoreVersion = '6.0'
state.ShowLegacyUI = false

function state.Stop()
    if not state.running then return end
    if state.enabled then setEnabled(false) end
    state.running = false
    for _, connection in ipairs(connections) do
        pcall(function() connection:Disconnect() end)
    end
    connections = {}
    if graphicUi then pcall(function() graphicUi:Destroy() end) end
    if environment.roblox_modPack_Realism_v4 == state then
        environment.roblox_modPack_Realism_v4 = nil
    end
end

-- Unsichtbare Mauskontrolle ist bewusst NICHT enthalten. Dezent und lesbar.
local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 12)
if false and playerGui then
    graphicUi = Instance.new("ScreenGui")
    graphicUi.Name = "RM4_LocalGraphicsDiagnostics"
    graphicUi.ResetOnSpawn = false
    graphicUi.IgnoreGuiInset = false
    graphicUi.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    graphicUi.DisplayOrder = 20
    graphicUi.Parent = playerGui

    statusButton = Instance.new("TextButton")
    statusButton.Name = "Status"
    statusButton.Size = UDim2.fromOffset(174, 32)
    statusButton.Position = UDim2.new(1, -186, 0, 10)
    statusButton.TextColor3 = Color3.fromRGB(235, 237, 238)
    statusButton.TextSize = 12
    statusButton.Font = Enum.Font.GothamSemibold
    statusButton.BorderSizePixel = 0
    statusButton.BackgroundColor3 = Color3.fromRGB(45, 47, 47)
    statusButton.Parent = graphicUi
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = statusButton

    detailsPanel = Instance.new("Frame")
    detailsPanel.Name = "Details"
    detailsPanel.Size = UDim2.fromOffset(340, 403)
    detailsPanel.Position = UDim2.new(1, -352, 0, 87)
    detailsPanel.BackgroundColor3 = Color3.fromRGB(27, 29, 31)
    detailsPanel.BorderSizePixel = 0
    detailsPanel.Visible = false
    detailsPanel.Parent = graphicUi
    local frameCorner = Instance.new("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 7)
    frameCorner.Parent = detailsPanel

    detailsLabel = Instance.new("TextLabel")
    detailsLabel.Name = "ActualChanges"
    detailsLabel.Size = UDim2.new(1, -20, 1, -16)
    detailsLabel.Position = UDim2.fromOffset(10, 8)
    detailsLabel.BackgroundTransparency = 1
    detailsLabel.TextSize = 12
    detailsLabel.TextColor3 = Color3.fromRGB(225, 229, 230)
    detailsLabel.Font = Enum.Font.Code
    detailsLabel.TextXAlignment = Enum.TextXAlignment.Left
    detailsLabel.TextYAlignment = Enum.TextYAlignment.Top
    detailsLabel.TextWrapped = true
    detailsLabel.TextTruncate = Enum.TextTruncate.AtEnd
    detailsLabel.Parent = detailsPanel

    weatherButton = Instance.new("TextButton")
    weatherButton.Name = "Weather"
    weatherButton.Size = UDim2.fromOffset(174, 32)
    weatherButton.Position = UDim2.new(1, -186, 0, 47)
    weatherButton.TextColor3 = Color3.fromRGB(234, 237, 238)
    weatherButton.TextSize = 11
    weatherButton.Font = Enum.Font.GothamSemibold
    weatherButton.BorderSizePixel = 0
    weatherButton.BackgroundColor3 = Color3.fromRGB(47, 51, 54)
    weatherButton.Parent = graphicUi
    local weatherCorner = Instance.new("UICorner")
    weatherCorner.CornerRadius = UDim.new(0, 6)
    weatherCorner.Parent = weatherButton
    connections[#connections + 1] = weatherButton.MouseButton1Click:Connect(function()
        cycleWeather()
        updateUI()
    end)

    connections[#connections + 1] = statusButton.MouseButton1Click:Connect(function()
        detailsVisible = not detailsVisible
        updateUI()
    end)
end

connections[#connections + 1] = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == state.Keybinds.Toggle then
        setEnabled(not state.enabled)
    elseif input.KeyCode == state.Keybinds.Details then
        detailsVisible = not detailsVisible
        updateUI()
    elseif input.KeyCode == state.Keybinds.Weather then
        cycleWeather()
        updateUI()
    elseif input.KeyCode == state.Keybinds.Intensity then
        cycleWeatherIntensity()
        updateUI()
    end
end)

connections[#connections + 1] = Workspace.DescendantAdded:Connect(function(instance)
    if not state.running or not state.enabled then return end
    -- Neu gestreamte Weltinhalte; keine teuren rekursiven Vollscans pro Frame.
    if instance:IsA("BasePart") and state.worldChanged < CONFIG.MaxWorldPartsChanged then
        task.defer(function()
            if state.enabled and instance:IsDescendantOf(Workspace) then photographicSurface(instance) end
        end)
    elseif instance:IsA("Light") and state.lightsChanged < CONFIG.MaxLightSourcesChanged then
        task.defer(function()
            if state.enabled and instance:IsDescendantOf(Workspace) then improveLight(instance) end
        end)
    end
end)

-- Dynamischen Tagesablauf behalten: keine fixe 12-Uhr-Sonne.
-- Bei Spielen, die fremde Lichtwerte sehr oft setzen, kann das Ergebnis variieren.
task.spawn(function()
    local lastSunBucket = -1
    local lastApply = 0
    local lastEnvironmentApply = 0
    while state.running do
        task.wait(2.0)
        if state.running and state.enabled then
            local clock = readProperty(Lighting, "ClockTime", 12)
            local bucket = math.floor(clock * 4)
            local now = os.clock()
            if bucket ~= lastSunBucket or now - lastApply > CONFIG.ReapplyLightingEvery then
                lastSunBucket = bucket
                lastApply = now
                naturalLight()
                weatherSky()
            end
            if now - lastEnvironmentApply > 24 then
                lastEnvironmentApply = now
                applyAtmosphere()
                applySkyAndClouds()
                applyTerrain()
                weatherSky()
            end
        end
        updateUI()
    end
end)

setEnabled(true)
state.PrintReport()
print("[RM v4.1] 90 Hz fixed-step Physik | F8 an/aus | F6 Bericht | F7 Regen/Schnee/Aus | F9 Wetterstaerke. Darstellung folgt Client-FPS; keine Serverfluide.")
