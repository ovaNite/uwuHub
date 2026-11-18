-- NovaX v1.1 Auto Drops (Health/Ammo/AmmoBalanced).
-- Searches the entire Workspace, not just a radius. Server pickup validation
-- still applies: remote touch attempts are NOT a promise of infinite pickup range.
return function(env)
  local Players=game:GetService("Players")
  local Workspace=game:GetService("Workspace")
  local RunService=game:GetService("RunService")
  local PathfindingService=game:GetService("PathfindingService")
  local UserInputService=game:GetService("UserInputService")
  local player=Players.LocalPlayer
  local ui=assert(env.NX_UI_WINDOW,"NovaX GUI not available")
  local settings=type(env.NX_STATE)=="table" and env.NX_STATE or {}
  local defaults={
    NovaXAutoHeal=false,
    NovaXAutoAmmo=false,
    NovaXAutoDropRemote=true,
    NovaXAutoDropNavigate=false
  }
  for key,value in pairs(defaults) do
    if type(settings[key])~="boolean" then settings[key]=value end
  end
  local enabled=true
  local connections={}
  local watched={}
  local entries={}
  local attempts,disappeared=0,0
  local nextAttempt=0
  local navigationToken=0
  local navigationTarget=nil
  local statusNote="Waiting for drops"
  local kinds={Health=true,Ammo=true,AmmoBalanced=true}

  local function connect(signal,fn,destination)
    local connection=signal:Connect(fn)
    table.insert(destination or connections,connection)
    return connection
  end
  local function classify(instance)
    if not instance or not instance.Parent or instance.Name~="_drop" or not instance:IsA("BasePart") then return nil end
    for _,child in ipairs(instance:GetChildren()) do
      if child:IsA("Model") and kinds[child.Name] then return child.Name end
    end
    return nil
  end
  local function forget(instance)
    local record=watched[instance]
    if not record then return end
    watched[instance]=nil
    entries[instance]=nil
    for _,conn in ipairs(record) do pcall(function()conn:Disconnect()end) end
    if navigationTarget==instance then
      navigationToken+=1
      navigationTarget=nil
    end
  end
  local function watch(instance)
    if not enabled or watched[instance] or not instance:IsA("BasePart") or instance.Name~="_drop" then return end
    if instance.Parent~=Workspace then return end
    local links={}
    watched[instance]=links
    local function update()
      if not enabled or instance.Parent~=Workspace then forget(instance);return end
      local kind=classify(instance)
      if kind then
        if not entries[instance] then
          entries[instance]={kind=kind,lastAttempt=0,firstSeen=os.clock()}
        else entries[instance].kind=kind end
      else entries[instance]=nil end
    end
    connect(instance.ChildAdded,update,links)
    connect(instance.ChildRemoved,update,links)
    connect(instance.AncestryChanged,function()
      if instance.Parent~=Workspace then forget(instance) end
    end,links)
    connect(instance.Destroying,function() forget(instance) end,links)
    update()
  end
  for _,obj in ipairs(Workspace:GetChildren()) do watch(obj) end
  connect(Workspace.ChildAdded,watch)
  local function healthData()
    local char=player.Character
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health<=0 then return char,hum,false end
    local value=hum.Health
    local max=hum.MaxHealth
    local node=char:FindFirstChild("Health")
    if node and (node:IsA("NumberValue") or node:IsA("IntValue")) then
      local customMax=node:GetAttribute("MaxHealth")
      if type(customMax)=="number" and customMax>0 then
        value,max=node.Value,customMax
      elseif node.Value>=0 and node.Value<=max and math.abs(node.Value-hum.Health)>0.1 then
        value=node.Value
      end
    end
    return char,hum,max>0 and value<max-0.001
  end
  local function selectDrop(root,needHeal)
    local chosen,bestDist,priority=nil,math.huge,math.huge
    for instance,entry in pairs(entries) do
      if instance.Parent==Workspace and entry.kind then
        local heal=entry.kind=="Health"
        local wanted=(heal and settings.NovaXAutoHeal and needHeal)
          or (not heal and settings.NovaXAutoAmmo)
        if wanted then
          local rank=(heal and needHeal) and 0 or 1
          local distance=(instance.Position-root.Position).Magnitude
          -- Never reject a drop solely due to distance.
          if rank<priority or (rank==priority and distance<bestDist) then
            chosen,bestDist,priority=instance,distance,rank
          end
        end
      end
    end
    return chosen,bestDist
  end
  local function remoteTouch(root,drop,entry)
    if type(firetouchinterest)~="function" then
      statusNote="Remote Touch unsupported by executor"
      return false
    end
    local ok,err=pcall(function()
      firetouchinterest(root,drop,0)
      firetouchinterest(root,drop,1)
    end)
    attempts+=1
    entry.lastAttempt=os.clock()
    statusNote=ok and ("Remote touch attempted: "..entry.kind)
      or ("Remote touch error: "..string.sub(tostring(err),1,95))
    return ok
  end
  local function userMoving()
    if UserInputService:GetFocusedTextBox() then return true end
    for _,key in ipairs({Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,
      Enum.KeyCode.Space,Enum.KeyCode.Up,Enum.KeyCode.Down,Enum.KeyCode.Left,Enum.KeyCode.Right}) do
      if UserInputService:IsKeyDown(key) then return true end
    end
    return false
  end
  local function startNavigation(drop,root,hum)
    if not settings.NovaXAutoDropNavigate then return end
    if navigationTarget==drop or not drop.Parent or userMoving() then return end
    if hum.Health<=0 or hum.Sit then return end
    navigationToken+=1
    local token=navigationToken
    navigationTarget=drop
    task.spawn(function()
      local good,err=pcall(function()
        local path=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=5,
          AgentCanJump=true,WaypointSpacing=5})
        path:ComputeAsync(root.Position,drop.Position)
        if path.Status~=Enum.PathStatus.Success then
          statusNote="No navigable path to "..(classify(drop) or "drop")
          return
        end
        for _,waypoint in ipairs(path:GetWaypoints()) do
          if not enabled or navigationToken~=token or not settings.NovaXAutoDropNavigate
            or not drop.Parent or not hum.Parent or hum.Health<=0 or userMoving() then return end
          if waypoint.Action==Enum.PathWaypointAction.Jump then hum.Jump=true end
          hum:MoveTo(waypoint.Position)
          local arrived=hum.MoveToFinished:Wait()
          if not arrived then return end
          if (root.Position-drop.Position).Magnitude<4.5 then break end
        end
        if enabled and navigationToken==token and drop.Parent and
          (root.Position-drop.Position).Magnitude<7 then
          hum:MoveTo(drop.Position)
        end
      end)
      if not good then statusNote="Navigation error: "..string.sub(tostring(err),1,90) end
      if navigationToken==token then navigationTarget=nil end
    end)
  end
  local accumulator=0
  connect(RunService.Heartbeat,function(dt)
    if not enabled then return end
    accumulator+=dt
    if accumulator<0.15 then return end
    accumulator=0
    if not settings.NovaXAutoHeal and not settings.NovaXAutoAmmo then return end
    local char,hum,needHeal=healthData()
    local root=char and char:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") or not hum or hum.Health<=0 then return end
    local drop,distance=selectDrop(root,needHeal)
    if not drop then
      if navigationTarget then navigationToken+=1;navigationTarget=nil end
      return
    end
    local entry=entries[drop]
    if not entry then return end
    local now=os.clock()
    if now>=nextAttempt and (now-entry.lastAttempt)>1.6 then
      nextAttempt=now+0.65
      if settings.NovaXAutoDropRemote then
        remoteTouch(root,drop,entry)
      end
    end
    -- Optional, actual across-map movement; OFF by default so manual
    -- movement and combat are never unexpectedly overridden.
    if settings.NovaXAutoDropNavigate and distance>4.5
      and (now-entry.firstSeen)>1.5 and (now-entry.lastAttempt)>0.5 then
      startNavigation(drop,root,hum)
    end
  end)
  local tab=ui:CreateTab("Auto Drops",4483345998)
  tab:CreateSection("Automatic pickups")
  tab:CreateLabel("Finds all _drop objects in Workspace; no scan-distance cap.")
  tab:CreateToggle({Name="Auto Heal (whenever health is missing)",
    CurrentValue=settings.NovaXAutoHeal,Callback=function(v)settings.NovaXAutoHeal=v end})
  tab:CreateToggle({Name="Auto Ammo (Ammo + AmmoBalanced)",
    CurrentValue=settings.NovaXAutoAmmo,Callback=function(v)settings.NovaXAutoAmmo=v end})
  tab:CreateSection("Pickup methods")
  tab:CreateToggle({Name="Remote Touch (experimental)",
    CurrentValue=settings.NovaXAutoDropRemote,
    Callback=function(v)settings.NovaXAutoDropRemote=v end})
  tab:CreateToggle({Name="Navigate to drop if needed (moves character)",
    CurrentValue=settings.NovaXAutoDropNavigate,Callback=function(v)
      settings.NovaXAutoDropNavigate=v
      if not v then navigationToken+=1;navigationTarget=nil end
    end})
  tab:CreateLabel("Remote collection can fail if the server checks distance.")
  tab:CreateButton({Name="Check Auto Drops status",Callback=function()
    local count=0
    local byKind={Health=0,Ammo=0,AmmoBalanced=0}
    for drop,entry in pairs(entries) do
      if drop.Parent==Workspace then
        count+=1
        byKind[entry.kind]=(byKind[entry.kind] or 0)+1
      end
    end
    local message=string.format("Visible: %d (H:%d A:%d AB:%d) | remote tries: %d | %s",
      count,byKind.Health,byKind.Ammo,byKind.AmmoBalanced,attempts,statusNote)
    print("[NovaX Auto Drops] "..message)
    if ui.Notify then ui:Notify({Title="Auto Drops",Content=message,Duration=8}) end
  end})
  return {Stop=function()
    enabled=false
    navigationToken+=1
    navigationTarget=nil
    for drop in pairs(watched) do forget(drop) end
    for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end) end
    table.clear(connections)
    table.clear(entries)
  end}
end
