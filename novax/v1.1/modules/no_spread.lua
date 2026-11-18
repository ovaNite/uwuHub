-- NovaX v1.1 / Weapon Controls / No Spread (client ItemLibrary adapter)
-- Uses only the six user-specified stats, preserving exact originals.
-- Client-side edits are not a guarantee of server-authoritative accuracy.
return function(env)
  local storage=game:GetService("ReplicatedStorage")
  local RunService=game:GetService("RunService")
  local state=assert(env.NX_STATE,"NX_STATE unavailable")
  local fields={
    "ShootSpread",
    "ShootAccuracy",
    "ShootSpreadConsistent",
    "ShootSpreadPerVelocityUnit",
    "ShootSpreadPerVelocityLimit",
    "AimSpreadMultiplier",
  }
  local originals=setmetatable({}, {__mode="k"})
  local applied=setmetatable({}, {__mode="k"})
  local connected=true
  local library=nil
  local items=nil
  local modifiedWeapons=0
  local modifiedFields=0
  local lastError="Not enabled"
  local nextCheck=0

  local function locate()
    if type(items)=="table" then return true end
    local modules=storage:FindFirstChild("Modules")
    local source=modules and modules:FindFirstChild("ItemLibrary")
    if not source or not source:IsA("ModuleScript") then
      lastError="ReplicatedStorage.Modules.ItemLibrary not found"
      return false
    end
    local ok,result=pcall(require,source)
    if not ok or type(result)~="table" or type(result.Items)~="table" then
      lastError="ItemLibrary.Items is not available"
      return false
    end
    library=result
    items=result.Items
    lastError="Ready"
    return true
  end

  local function desired(field,current)
    if type(current)=="boolean" then
      return false
    elseif type(current)=="number" then
      -- In this ItemLibrary, ShootAccuracy is a numeric spread term too.
      -- Do not change any stat that is non-numeric or unsupported.
      return 0
    end
    return nil
  end

  local function modify()
    if not locate() then return end
    local weaponCount,fieldCount=0,0
    for _,entry in pairs(items) do
      if type(entry)=="table" then
        local captured=originals[entry]
        local changed=applied[entry]
        local weaponTouched=false
        for _,key in ipairs(fields) do
          local value=rawget(entry,key)
          if value~=nil then
            local wanted=desired(key,value)
            if wanted~=nil then
              if not captured then captured={};originals[entry]=captured end
              if not changed then changed={};applied[entry]=changed end
              if captured[key]==nil then captured[key]=value end
              if value~=wanted then
                local ok=pcall(function() entry[key]=wanted end)
                if ok then changed[key]=wanted end
              else
                if changed[key]==nil then changed[key]=wanted end
              end
              if changed[key]~=nil then
                weaponTouched=true
                fieldCount+=1
              end
            end
          end
        end
        if weaponTouched then weaponCount+=1 end
      end
    end
    modifiedWeapons=weaponCount
    modifiedFields=fieldCount
    lastError="Client ItemLibrary patched"
  end

  local function restore()
    for entry,captured in pairs(originals) do
      local changed=applied[entry]
      for key,initial in pairs(captured) do
        if changed and rawget(entry,key)==changed[key] then
          pcall(function() entry[key]=initial end)
        end
      end
    end
    originals=setmetatable({}, {__mode="k"})
    applied=setmetatable({}, {__mode="k"})
    modifiedWeapons=0
    modifiedFields=0
    lastError="Disabled; originals restored where unchanged"
  end

  local function tick()
    if not connected then return end
    local now=os.clock()
    if now<nextCheck then return end
    nextCheck=now+0.5
    if state.NoSpread then
      modify()
    elseif next(originals)~=nil then
      restore()
    end
  end
  local connection=RunService.Heartbeat:Connect(tick)
  local api={}
  function api:SetActive(v)
    state.NoSpread=v==true
    nextCheck=0
    if not state.NoSpread then restore() else tick() end
  end
  function api:Status()
    return string.format("%s | weapons: %d | spread stats: %d | local only",
      lastError,modifiedWeapons,modifiedFields)
  end
  function api:Stop()
    connected=false
    if connection then connection:Disconnect();connection=nil end
    restore()
    items=nil
    library=nil
  end
  tick()
  return api
end
