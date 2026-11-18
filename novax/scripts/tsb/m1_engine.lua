-- NovaX TSB / M1 input engine and animation telemetry
-- BaseM1 consists of animation identifiers, not reach or combo damage values.
-- Unlimited duration = repeat input while active, NOT infinite server hit range.
return function(options)
  options=type(options)=="table" and options or {}
  local Players=game:GetService("Players")
  local UIS=game:GetService("UserInputService")
  local ReplicatedStorage=game:GetService("ReplicatedStorage")
  local LocalPlayer=Players.LocalPlayer
  local send=assert(options.SendInput,"SendInput callback is required")
  local stopped=false
  local running=false
  local delaySeconds=0.32
  local sentCount=0
  local acceptedCount=0
  local lastAnim="None"
  local lastError=nil
  local animationLookup={}
  local tableCounts={}
  local totalAnimations=0
  local totalGroups=0
  local connections={}
  local animatorConnection=nil
  local function connect(signal,callback)
    local c=signal:Connect(callback)
    connections[#connections+1]=c
    return c
  end
  local function normalizeId(value)
    if type(value)=="number" then return tostring(math.floor(value)) end
    if type(value)=="string" then
      return value:match("(%d+)%D*$")
    end
    return nil
  end
  local function refreshAnimations()
    local module=ReplicatedStorage:FindFirstChild("Info")
    if not module or not module:IsA("ModuleScript") then
      lastError="ReplicatedStorage.Info unavailable"
      return false
    end
    local ok,info=pcall(require,module)
    if not ok or type(info)~="table" or type(info.BaseM1)~="table" then
      lastError="Info.BaseM1 unavailable"
      return false
    end
    animationLookup={}
    tableCounts={}
    totalAnimations=0
    totalGroups=0
    for style,entries in pairs(info.BaseM1) do
      if type(style)=="string" and type(entries)=="table" then
        local count=0
        totalGroups+=1
        for index,value in pairs(entries) do
          local id=normalizeId(value)
          if id then
            animationLookup[id]={style=style,index=index}
            count+=1
            totalAnimations+=1
          end
        end
        tableCounts[style]=count
      end
    end
    lastError=nil
    return true
  end
  local function trackCharacter(char)
    if animatorConnection then
      pcall(function()animatorConnection:Disconnect()end)
      animatorConnection=nil
    end
    local humanoid=char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator=humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator",5)
    if not animator or stopped then return end
    animatorConnection=connect(animator.AnimationPlayed,function(track)
      local anim=track and track.Animation
      local id=anim and normalizeId(anim.AnimationId)
      local match=id and animationLookup[id]
      if match then lastAnim=match.style.." #"..tostring(match.index) end
    end)
  end
  local function aliveCharacter()
    local character=LocalPlayer.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    return character and hum and hum.Health>0
  end
  local function playerCanStrike()
    if stopped or not running or not aliveCharacter() then return false end
    if UIS:GetFocusedTextBox() then return false end
    if options.CanRun and not options.CanRun() then return false end
    return true
  end
  function Status()
    return string.format(
      "M1 input: %s | attempts: %d | dispatched: %d | BaseM1: %d styles / %d IDs | last animation: %s%s",
      running and "ON" or "OFF",sentCount,acceptedCount,
      totalGroups,totalAnimations,lastAnim,
      lastError and (" | "..lastError) or ""
    )
  end
  local api={}
  function api:Start()
    if stopped then return false,"Engine was unloaded" end
    if running then return true end
    running=true
    task.spawn(function()
      while running and not stopped do
        if playerCanStrike() then
          sentCount+=1
          local ok=send("MouseButton1",true)
          task.wait(0.055)
          local released=send("MouseButton1",false)
          if ok and released then acceptedCount+=1 end
        end
        task.wait(delaySeconds)
      end
      pcall(function()send("MouseButton1",false)end)
    end)
    return true
  end
  function api:Stop()
    running=false
    pcall(function()send("MouseButton1",false)end)
  end
  function api:SetInterval(value)
    delaySeconds=math.clamp(tonumber(value) or 0.32,0.12,0.8)
    return delaySeconds
  end
  function api:Status() return Status() end
  function api:Stats()
    return {running=running,attempted=sentCount,dispatched=acceptedCount,
      styles=totalGroups,animations=totalAnimations,lastAnimation=lastAnim,
      interval=delaySeconds,error=lastError}
  end
  function api:RefreshAnimations() return refreshAnimations() end
  function api:Unload()
    self:Stop()
    stopped=true
    for _,c in ipairs(connections) do pcall(function()c:Disconnect()end)end
    table.clear(connections)
    animatorConnection=nil
  end
  refreshAnimations()
  if LocalPlayer.Character then task.spawn(trackCharacter,LocalPlayer.Character) end
  connect(LocalPlayer.CharacterAdded,function(char)
    task.defer(trackCharacter,char)
  end)
  return api
end
