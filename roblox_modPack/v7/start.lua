-- roblox_modPack v7 / START
-- Brand-new entrypoint; no previous /v5/load.lua or mutable module branches.
-- v6 loads the 90Hz local-weather renderer. v7 adds budget-limited geometric
-- TWO-RAY reflections on rain-wet floors (not native GPU RTX).
local ROOT="https://raw.githubusercontent.com/ovaNite/uwuHub/"
local REV_BASE="3ddf0f9b60e125f977ce1544ce331dae90d74006"
local REV_TRACE="5b5d678f95cef10b32f18cd0e1fcf69cf7c45760"
local function download(path)
    local ok,source=pcall(function()return game:HttpGet(path,true)end)
    if not ok or type(source)~="string" or #source<100 then
        error("[RM7] Cannot fetch pinned source: "..tostring(source))
    end
    return source
end
local function run(path)
    if type(loadstring)~="function" then
        error("[RM7] Executor requires loadstring")
    end
    local source=download(path)
    local compiled,problem=loadstring(source)
    if not compiled then error("[RM7] Module compile error: "..tostring(problem))end
    return compiled()
end
local env=_G
pcall(function()
    if type(getgenv)=="function" then
        local v=getgenv()
        if type(v)=="table" then env=v end
    end
end)
if type(env.roblox_modPack_v7)=="table" and
    type(env.roblox_modPack_v7.Stop)=="function" then
    pcall(env.roblox_modPack_v7.Stop)
end
-- Intentionally launch the immutable v6 base WITHOUT loading any v5 menu.
local baseUrl=ROOT..REV_BASE.."/roblox_modPack/v6/start.lua"
local ok,err=pcall(function()run(baseUrl)end)
if not ok then
    warn("[RM7] Existing 90Hz weather foundation failed: "..tostring(err))
    return
end
local ctx=env.roblox_modPack_v6
if type(ctx)~="table" or type(ctx.AddRender)~="function" then
    warn("[RM7] v6 graphics state missing")
    return
end
ctx.Options.RayReflections=true
ctx.Options.ReflectionPower=.72
ctx.Options.ReflectionRoughness=.014
ctx.Stats.ReflectionRaysPerSec=0
ctx.Stats.ReflectionHitsPerSec=0
ctx.Stats.ReflectionErrors=0
local traceUrl=ROOT..REV_TRACE.."/roblox_modPack/v7/reflections.lua"
local loaded,module=pcall(function()
    local factory=run(traceUrl)
    if type(factory)~="function" then error("Bad reflection factory")end
    return factory(ctx)
end)
if not loaded then
    warn("[RM7] Reflection module failed: "..tostring(module))
    pcall(ctx.Stop)
    return
end
if type(module)=="table" and type(module.Stop)=="function" then
    ctx.AddStop(module.Stop)
end
ctx.ReflectionsVersion="7.0"
ctx.ReflectionsPin=REV_TRACE
env.roblox_modPack_v7=ctx
print("[RM7] Geometric 2-ray reflections loaded. RAIN mode only.")
print("[RM7] F11 reflection toggle | F12 sampling quality | F10 existing settings.")
print("[RM7] Workspace raycasts, not GPU RTX or texture-perfect SSR.")
