-- NovaX v1 capabilities.lua | read-only checks, never calls privileged APIs just to test.
return function()
  local svc={}
  local Players=game:GetService("Players")
  local Camera=workspace.CurrentCamera
  local function callable(name)
    local value
    local ok=pcall(function()
      value=({getgenv=getgenv,loadstring=loadstring,hookmetamethod=hookmetamethod,
        getnamecallmethod=getnamecallmethod,newcclosure=newcclosure,
        checkcaller=checkcaller,setfpscap=setfpscap,
        mousemoverel=mousemoverel,mouse1click=mouse1click,
        firetouchinterest=firetouchinterest,getconnections=getconnections,
        readfile=readfile,writefile=writefile,makefolder=makefolder,
        listfiles=listfiles,gethui=gethui,Drawing=Drawing})[name]
    end)
    return ok and type(value)=="function"
  end
  local report={
    Mode="NovaX",
    Available={},
    Notes={},
    Engine={},
    Unverified={},
  }
  for _,name in ipairs({
    "getgenv","loadstring","hookmetamethod","getnamecallmethod",
    "newcclosure","checkcaller","setfpscap","mousemoverel","mouse1click",
    "firetouchinterest","getconnections","readfile","writefile",
    "makefolder","listfiles","gethui"
  }) do
    report.Available[name]=callable(name)
  end
  report.Available.Drawing=type(Drawing)=="table"
  report.Engine.LocalPlayer=Players.LocalPlayer~=nil
  report.Engine.Camera=Camera~=nil
  report.Engine.Raycast=pcall(function()return workspace.Raycast~=nil end)
  report.Engine.ViewportPointToRay=Camera and
    pcall(function()return Camera.ViewportPointToRay~=nil end) or false
  report.Engine.ParticleEmitter=pcall(function()
    local o=Instance.new("ParticleEmitter");o:Destroy()
  end)
  report.Engine.RunServiceHeartbeat=pcall(function()
    return game:GetService("RunService").Heartbeat~=nil
  end)
  report.Notes.InternalHook="Executor-only. Supported API presence does not guarantee weapon interception."
  report.Notes.Snap="Camera orientation can be changed locally; server hit registration is game-dependent."
  report.Notes.RayTracing="Local geometric rays do not turn on hardware GPU ray tracing."
  report.Unverified={"Actual server-side damage/hits","Anticheat/allowance",
    "Injected hooks in a particular game","Protected Roblox APIs",
    "FPS and effects across all Roblox experiences"}
  function report.Summary()
    local total,yes=0,0
    for _,present in pairs(report.Available) do
      total+=1
      if present then yes+=1 end
    end
    return string.format("Executor APIs %d/%d | camera %s | raycasts %s | particle emitter %s",
      yes,total,tostring(report.Engine.Camera),tostring(report.Engine.Raycast),
      tostring(report.Engine.ParticleEmitter))
  end
  print("[NovaX capability audit] "..report.Summary())
  return report
end