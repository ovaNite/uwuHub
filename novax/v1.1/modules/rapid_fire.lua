-- NovaX v1.1: bounded client gun cooldown adapter (no remote replication).
-- Works only if the local RIVALS Gun class is present and the executor can hook it.
return function(env)
  local Players=game:GetService("Players")
  local RunService=game:GetService("RunService")
  local player=Players.LocalPlayer
  local state=env.NX_RAPID_FIRE_HOOK
  if type(state)~="table" or state.protocol~=1 then
    state={protocol=1,installed=false,active=false,session=false,multiplier=4,
      gun=nil,item=nil,changes=0,last=setmetatable({}, {__mode="k"}),
      reason="Waiting for weapon controller"}
    env.NX_RAPID_FIRE_HOOK=state
  end
  if state.connection then pcall(function() state.connection:Disconnect() end);state.connection=nil end
  state.session=true
  state.active=false
  state.item=nil
  state.last=setmetatable({}, {__mode="k"})
  local function isLocalGun(item)
    if type(item)~="table" then return false end
    local ok,owned=pcall(function()
      local fighter=item.ClientFighter
      return fighter and fighter.IsLocalPlayer==true
    end)
    return ok and owned==true
  end
  local function adjust()
    if not state.session or not state.active or state.multiplier<=1 then return end
    local item=state.item
    if not isLocalGun(item) then return end
    local ok,deadline=pcall(function() return item._shoot_cooldown end)
    if not ok or type(deadline)~="number" or deadline~=deadline then return end
    local now=tick()
    if deadline<=now or deadline-now>15 then
      state.last[item]=deadline
      return
    end
    local previous=state.last[item]
    -- Only shorten newly assigned deadlines. Never repeatedly shrink
    -- the same deadline on every Heartbeat.
    if previous~=nil and deadline<=previous+0.005 then return end
    local shortened=now+(deadline-now)/state.multiplier
    local changed=pcall(function() item._shoot_cooldown=shortened end)
    if changed then
      state.last[item]=shortened
      state.changes+=1
    end
  end
  local function tryHook()
    if state.installed then return end
    if type(hookfunction)~="function" then
      state.reason="Executor has no hookfunction"
      return
    end
    local scripts=player and player:FindFirstChild("PlayerScripts")
    local modules=scripts and scripts:FindFirstChild("Modules")
    local types=modules and modules:FindFirstChild("ItemTypes")
    local gunFile=types and types:FindFirstChild("Gun")
    if not gunFile or not gunFile:IsA("ModuleScript") then
      state.reason="PlayerScripts/Modules/ItemTypes/Gun not found"
      return
    end
    -- Require only a class the game has already loaded, when supported.
    if type(getloadedmodules)=="function" then
      local loaded=false
      local ok,items=pcall(getloadedmodules)
      if ok and type(items)=="table" then
        for _,module in ipairs(items) do
          if module==gunFile then loaded=true;break end
        end
        if not loaded then state.reason="Waiting for loaded Gun module";return end
      end
    end
    local ok,gun=pcall(require,gunFile)
    if not ok or type(gun)~="table" or type(gun.StartShooting)~="function" then
      state.reason="Gun.StartShooting unavailable"
      return
    end
    if state.gun==gun and state.installed then return end
    local original
    local function around(item,...)
      local results=table.pack(original(item,...))
      if state.session and state.active and isLocalGun(item) then
        if state.item~=item then
          state.item=item
          state.last[item]=nil
        end
        adjust()
      end
      return table.unpack(results,1,results.n)
    end
    local hooked,prior=pcall(hookfunction,gun.StartShooting,around)
    if not hooked or type(prior)~="function" then
      state.reason="Cannot hook Gun.StartShooting"
      return
    end
    original=prior
    state.gun=gun
    state.installed=true
    state.reason="Gun.StartShooting hooked; local cooldown only"
  end
  local nextProbe=0
  state.connection=RunService.Heartbeat:Connect(function()
    if not state.session then return end
    if not state.installed and os.clock()>=nextProbe then
      nextProbe=os.clock()+1
      pcall(tryHook)
    end
    if state.installed then adjust() end
  end)
  local api={}
  function api:Ready() return state.installed end
  function api:SetActive(value)
    state.active=value==true
    state.last=setmetatable({}, {__mode="k"})
  end
  function api:SetMultiplier(value)
    state.multiplier=math.floor(math.clamp(tonumber(value) or 4,1,100))
    state.last=setmetatable({}, {__mode="k"})
  end
  function api:Status()
    local name=state.item and tostring(state.item.Name) or "(none)"
    return string.format("%s | weapon: %s | x%d | cooldown edits: %d",
      state.reason,name,state.multiplier,state.changes)
  end
  function api:Stop()
    state.active=false
    state.session=false
    state.item=nil
    if state.connection then state.connection:Disconnect();state.connection=nil end
  end
  env.NX_RAPID_FIRE=api
  pcall(tryHook)
  return api
end
