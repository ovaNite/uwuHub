-- roblox_modPack v8 start.lua / NEW ENTRYPOINT
-- Dedicated entrypoint; NEVER redirects to the old v5 loader.
local ROOT="https://raw.githubusercontent.com/ovaNite/uwuHub/"
local V8="768f8149344cd74cc201842ed79df354de1648ef"
local V6="fb50663a8221e04ebc3abc6d8cb6f410a9adba76"
local V7="8ac16aa34c2442d5363994b8b136c6bba1d043df"
local V5="82dae812868850132778582ef1902ae51394faa8"
local function fetch(folder,commit,file)
    local url=ROOT..commit.."/roblox_modPack/"..folder.."/"..file
    local ok,response=pcall(function()return game:HttpGet(url,true)end)
    if not ok or type(response)~="string" or #response<64 then
        error("[RM8] Download failed "..file..": "..tostring(response))
    end
    return response
end
if type(loadstring)~="function" then error("[RM8] Requires loadstring") end
local function import(folder,commit,file)
    local text=fetch(folder,commit,file)
    local run,err=loadstring(text)
    if not run then error("[RM8] Compile "..file.." failed: "..tostring(err)) end
    return run
end
local env=_G
pcall(function()
    if type(getgenv)=="function" then
        local v=getgenv()
        if type(v)=="table" then env=v end
    end
end)
for _,name in ipairs({"roblox_modPack_v8","roblox_modPack_v7","roblox_modPack_v6","roblox_modPack_v5","roblox_modPack_Realism_v4"}) do
    local old=env[name]
    if type(old)=="table" and type(old.Stop)=="function" then
        pcall(old.Stop)
    end
end
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local gui=player and (player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10))
if gui then
    -- Only known ModPack windows are touched. Never delete game UI.
    for _,name in ipairs({
        "RM4_LocalGraphicsDiagnostics","RM5_RealismControl",
        "RM53_Control","roblox_modPack_CUSTOM_UI","RM6_Control","RM7_ReflectionInfo"
    }) do
        local old=gui:FindFirstChild(name)
        if old then pcall(function()old:Destroy()end)end
    end
end
local okCore,coreError=pcall(function()import("v8",V8,"core.lua")()end)
if not okCore then error("[RM8] Core failed: "..tostring(coreError)) end
local base=env.roblox_modPack_Realism_v4
if type(base)~="table" or type(base.Stop)~="function" then
    error("[RM8] Core did not publish expected state")
end
local RunService=game:GetService("RunService")
local ctx={
    Active=true,Base=base,
    Workspace=game:GetService("Workspace"),Players=Players,
    Lighting=game:GetService("Lighting"),
    RunService=RunService,UserInputService=game:GetService("UserInputService"),
    Options={
        WorldFinish=true,WeaponFinish=true,CameraWet=true,
        Sound=true,Fire=true,Foliage=false,Scope=true,Optics=true,
        RainVolume=.46,RainStrength=65,SnowStrength=45,
        StylePercent=72,StyleEnabled=true,Style="Realism",
        Storm=false
    },
    Stats={},Errors={},PhysicsHz=90,PhysicsActual=0,
    FrameDrop=0,Revision=V8
}
local tracked,connections,steps,renderers,stopHooks={},{},{},{},{}
function ctx.Track(obj)
    tracked[#tracked+1]=obj
    return obj
end
function ctx.Link(event,callback)
    local c=event:Connect(callback)
    connections[#connections+1]=c
    return c
end
function ctx.AddStep(cb)steps[#steps+1]=cb end
function ctx.AddRender(cb)renderers[#renderers+1]=cb end
function ctx.AddStop(cb)stopHooks[#stopHooks+1]=cb end
local folder=Instance.new("Folder")
folder.Name="RM8_Visuals";folder.Parent=ctx.Workspace
ctx.Folder=ctx.Track(folder)
function ctx.Stop()
    if not ctx.Active then return end
    ctx.Active=false
    for i=#connections,1,-1 do
        pcall(function()connections[i]:Disconnect()end)
    end
    for i=#stopHooks,1,-1 do pcall(stopHooks[i]) end
    for i=#tracked,1,-1 do
        pcall(function()tracked[i]:Destroy()end)
    end
    pcall(base.Stop)
    if env.roblox_modPack_v8==ctx then env.roblox_modPack_v8=nil end
end
env.roblox_modPack_v8=ctx
local loaded={}
local function addon(folder,revision,name)
    local ok,err=pcall(function()
        local factory=import(folder,revision,name)()
        if type(factory)~="function" then error("Expected module factory") end
        local module=factory(ctx)
        if type(module)=="table" and type(module.Stop)=="function" then
            ctx.AddStop(module.Stop)
        end
    end)
    if ok then
        loaded[#loaded+1]=name
    else
        ctx.Errors[#ctx.Errors+1]=name..": "..tostring(err)
        warn("[RM8] "..ctx.Errors[#ctx.Errors])
    end
end
-- Existing physics/particles from pinned v5.3, no old GUI.
for _,name in ipairs({
    "dist/body.lua","dist/weatherfx.lua",
    "dist/lens.lua","dist/worldfx.lua","dist/optics.lua","dist/styles.lua"
}) do addon("v5",V5,name) end
-- The new local floor, wall, weapon finish and exclusive v6 UI.
for _,name in ipairs({"surfaces.lua","weapon.lua","ui.lua"}) do
    addon("v6",V6,name)
end
-- v8: physical snow landings across visible world; replacement for v5 surface.
addon("v8",V8,"surface.lua")
-- Preserve the v7 camera->floor->object reflection research module.
addon("v7",V7,"reflections.lua")
-- Set default rain level once, core handles its own 90Hz physics.
pcall(function()
    if base.weatherMode=="RAIN" then
        base.SetWeatherIntensityFraction(ctx.Options.RainStrength/100)
    end
end)
local accumulator,stepsLast,windowStart=0,0,os.clock()
local fixed=1/90
ctx.Link(RunService.Heartbeat,function(delta)
    if not ctx.Active then return end
    accumulator+=math.clamp(delta,0,.10)
    local n=math.min(6,math.floor((accumulator+1e-9)/fixed))
    accumulator-=n*fixed
    if accumulator>=fixed then
        local skipped=math.floor(accumulator/fixed)*fixed
        ctx.FrameDrop+=skipped
        accumulator-=skipped
    end
    for i=1,n do
        for _,step in ipairs(steps) do
            local success,err=pcall(step,fixed,i==n)
            if not success then
                ctx.Stats.StepErrors=(ctx.Stats.StepErrors or 0)+1
                if ctx.Stats.StepErrors<=3 then warn("[RM8] physics: "..tostring(err))end
            end
        end
    end
    stepsLast+=n
    local now=os.clock()
    local elapsed=now-windowStart
    if elapsed>=1 then
        ctx.PhysicsActual=stepsLast/elapsed
        stepsLast=0;windowStart=now
    end
    for _,render in ipairs(renderers) do
        local success,err=pcall(render,delta)
        if not success then
            ctx.Stats.RenderErrors=(ctx.Stats.RenderErrors or 0)+1
            if ctx.Stats.RenderErrors<=3 then warn("[RM8] render: "..tostring(err))end
        end
    end
end)
ctx.Report=function()
    print(string.format("[RM8] v8 loaded: %d/11 modules | core %.1f Hz | addons %.1f Hz | "
        .."wet floors %d | walls %d | weapon %d | puddles %d | errors %d",
        #loaded,tonumber(base.weatherPhysicsMeasuredHz) or 0,ctx.PhysicsActual,
        ctx.Stats.WetFloors or 0,ctx.Stats.WallCandidates or 0,
        ctx.Stats.WeaponFinishes or 0,ctx.Stats.WetPuddles or 0,#ctx.Errors))
    for _,errorText in ipairs(ctx.Errors) do warn("[RM8] "..errorText)end
end
ctx.Report()
print("[RM8] NEW v8/start.lua | F7 rain/snow | F10 menu | F11 reflections | F6 diagnostics")
