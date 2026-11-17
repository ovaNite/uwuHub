-- roblox_modPack v5 - VERIFIED REVISION LOADER
-- Paste this one file into an executor that supports loadstring & game:HttpGet.
-- Modules are pinned to a specific immutable Git commit, not a mutable branch.
-- No hidden payloads, account collection, remote telemetry or anti-debugging.
local REV="cd8d4f5b1e01aa79f4e6b241e3d1a7b957f5b375"
local ROOT="https://raw.githubusercontent.com/ovaNite/uwuHub/"..REV.."/roblox_modPack/v5/"
local function envTable()
    local e=_G
    if type(getgenv)=="function" then
        local ok,val=pcall(getgenv)
        if ok and type(val)=="table" then e=val end
    end
    return e
end
local env=envTable()
if type(env.roblox_modPack_v5)=="table" and type(env.roblox_modPack_v5.Stop)=="function" then
    pcall(env.roblox_modPack_v5.Stop)
end
if type(loadstring)~="function" then
    warn("[RM5] Executor needs loadstring (not standard Roblox Luau).")
    return
end
local function import(name)
    local url=ROOT..name
    local success,source=pcall(function() return game:HttpGet(url,true) end)
    if not success or type(source)~="string" or #source<25 then
        error("[RM5] Cannot retrieve "..name..": "..tostring(source))
    end
    local fn,err=loadstring(source)
    if not fn then error("[RM5] Compilation error in "..name..": "..tostring(err)) end
    return fn
end
local ok,err=pcall(function() import("dist/core.lua")() end)
if not ok then
    warn("[RM5] Core load failed: "..tostring(err));return
end
local base=env.roblox_modPack_Realism_v4
if type(base)~="table" or type(base.Stop)~="function" then
    warn("[RM5] Core state not found; addons were not started.")
    return
end
local R=game:GetService("RunService")
local ctx={
    Active=true,
    Base=base, Players=game:GetService("Players"),
    Workspace=game:GetService("Workspace"),
    Lighting=game:GetService("Lighting"),
    RunService=R, UserInputService=game:GetService("UserInputService"),
    Stats={},Options={Fire=true,Foliage=true,Scope=true,Optics=true},
    PhysicsHz=90,PhysicsActual=0,PhysicsSkipped=0,
    Revision=REV,
}
local owned,connections,stepHooks,renderHooks,stopHooks={}, {}, {}, {}, {}
function ctx.Track(o)
    owned[#owned+1]=o
    return o
end
function ctx.Link(signal,callback)
    local c=signal:Connect(callback)
    connections[#connections+1]=c
    return c
end
function ctx.AddStep(callback) stepHooks[#stepHooks+1]=callback end
function ctx.AddRender(callback) renderHooks[#renderHooks+1]=callback end
function ctx.AddStop(callback) stopHooks[#stopHooks+1]=callback end

local folder=Instance.new("Folder")
folder.Name="RM5_LOCAL_VISUALS"
folder.Parent=ctx.Workspace
ctx.Folder=ctx.Track(folder)
function ctx.Stop()
    if not ctx.Active then return end
    ctx.Active=false
    for i=#connections,1,-1 do
        pcall(function() connections[i]:Disconnect() end)
    end
    for i=#stopHooks,1,-1 do
        pcall(stopHooks[i])
    end
    for i=#owned,1,-1 do
        pcall(function() owned[i]:Destroy() end)
    end
    pcall(base.Stop)
    if env.roblox_modPack_v5==ctx then
        env.roblox_modPack_v5=nil
    end
end
env.roblox_modPack_v5=ctx

local loaded,errors={},{}
for _,name in ipairs({"dist/body.lua","dist/surface.lua","dist/worldfx.lua","dist/optics.lua","dist/ui.lua"}) do
    local successful,why=pcall(function()
        local factory=import(name)()
        if type(factory)~="function" then
            error("module must return function(ctx)")
        end
        local module=factory(ctx)
        if type(module)=="table" and type(module.Stop)=="function" then
            ctx.AddStop(module.Stop)
        end
    end)
    if successful then
        loaded[#loaded+1]=name
    else
        errors[#errors+1]=name..": "..tostring(why)
        warn("[RM5] "..errors[#errors])
    end
end

local fixed=1/90
local accumulator,count,measureSince=0,0,os.clock()
ctx.Link(R.Heartbeat,function(dt)
    if not ctx.Active then return end
    local d=math.clamp(dt,0,.10)
    accumulator+=d
    local number=math.min(6,math.floor((accumulator+1e-9)/fixed))
    accumulator-=number*fixed
    if accumulator>=fixed then
        local skipped=math.floor(accumulator/fixed)*fixed
        accumulator-=skipped
        ctx.PhysicsSkipped+=skipped
    end
    for i=1,number do
        for _,f in ipairs(stepHooks) do
            local okStep,why=pcall(f,fixed,i==number)
            if not okStep then
                ctx.Stats.StepErrors=(ctx.Stats.StepErrors or 0)+1
                if ctx.Stats.StepErrors<4 then warn("[RM5] Step: "..tostring(why)) end
            end
        end
    end
    count+=number
    local now=os.clock()
    if now-measureSince>=1 then
        ctx.PhysicsActual=count/(now-measureSince)
        measureSince=now
        count=0
    end
    for _,f in ipairs(renderHooks) do
        local okRender,why=pcall(f,dt)
        if not okRender then
            ctx.Stats.RenderErrors=(ctx.Stats.RenderErrors or 0)+1
            if ctx.Stats.RenderErrors<4 then warn("[RM5] Render: "..tostring(why)) end
        end
    end
end)

ctx.Report=function()
    print(string.format("[RM5] %d modules | core %.1fHz | addons %.1fHz | body %d | surfaces %d | errors %d",
        #loaded,tonumber(base.weatherPhysicsMeasuredHz) or 0,ctx.PhysicsActual,
        ctx.Stats.BodyDrops or 0,ctx.Stats.SurfacePatches or 0,
        (ctx.Stats.StepErrors or 0)+(ctx.Stats.RenderErrors or 0)))
    for _,e in ipairs(errors) do warn(e) end
end
ctx.Report()
print("[RM5] F10 UI | F7 rain/snow/off | F9 intensity | F8 power | F6 diagnostics")
