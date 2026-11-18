-- The Strongest Battlegrounds / NovaX TSB Combo Studio
-- Manual character profiles + input recorder. Not a verified combat AI.
-- Runs only in TSB. Returns Stop() so NovaX Games can cleanly unload it.
return function(ctx)
  local Players=game:GetService("Players")
  local UIS=game:GetService("UserInputService")
  local TweenService=game:GetService("TweenService")
  local HttpService=game:GetService("HttpService")
  local player=Players.LocalPlayer
  if game.PlaceId~=10449761463 and game.GameId~=3808081382 then
    error("TSB Combo Studio can only run in The Strongest Battlegrounds")
  end
  local environment=(getgenv and getgenv()) or _G
  if type(environment.NX_TSB_COMBO)=="table" and
    type(environment.NX_TSB_COMBO.Stop)=="function" then
    pcall(function() environment.NX_TSB_COMBO:Stop() end)
  end
  local live=true
  local recording=false
  local playing=false
  local recordStart=0
  local current={}
  local profiles={}
  local connections={}
  local held={}
  local profile="Default"
  local FILE="NovaX/TSB/combo_profiles.json"
  local acceptable={
    Q=true,F=true,E=true,R=true,G=true,Space=true,
    One=true,Two=true,Three=true,Four=true,
    W=true,A=true,S=true,D=true,LeftShift=true,
    MouseButton1=true,MouseButton2=true,
  }
  local vm=nil
  pcall(function() vm=game:GetService("VirtualInputManager") end)
  local function tween(obj,props)
    TweenService:Create(obj,TweenInfo.new(0.15,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props):Play()
  end
  local function make(class,props,parent)
    local obj=Instance.new(class)
    for k,v in pairs(props or {}) do obj[k]=v end
    if parent then obj.Parent=parent end
    return obj
  end
  local function rounded(obj,r) make("UICorner",{CornerRadius=UDim.new(0,r)},obj) end
  local function bind(sig,fn)
    local c=sig:Connect(fn)
    connections[#connections+1]=c
  end
  local colors={bg=Color3.fromRGB(11,16,23),surface=Color3.fromRGB(24,32,44),
    accent=Color3.fromRGB(112,170,231),white=Color3.fromRGB(235,241,249),
    muted=Color3.fromRGB(135,151,170),green=Color3.fromRGB(107,219,175)}
  local gui=make("ScreenGui",{
    Name="NovaX_TSB_Combo_Studio",IgnoreGuiInset=false,
    ResetOnSpawn=false,DisplayOrder=56,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
  },player:WaitForChild("PlayerGui"))
  local panel=make("Frame",{
    Size=UDim2.fromOffset(470,362),Position=UDim2.new(0.5,-235,0.5,-181),
    BackgroundColor3=colors.bg,BorderSizePixel=0,
  },gui)
  rounded(panel,15)
  make("UIStroke",{Color=Color3.fromRGB(50,69,91),Transparency=0.35,Thickness=1},panel)
  local header=make("Frame",{
    Size=UDim2.new(1,0,0,59),BackgroundColor3=colors.surface,BorderSizePixel=0,
  },panel)
  rounded(header,15)
  make("TextLabel",{
    Size=UDim2.new(1,-90,0,28),Position=UDim2.fromOffset(18,10),
    BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=17,
    Text="TSB  /  COMBO STUDIO",TextColor3=colors.white,
    TextXAlignment=Enum.TextXAlignment.Left,
  },header)
  make("TextLabel",{
    Size=UDim2.new(1,-100,0,17),Position=UDim2.fromOffset(19,35),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=11,
    Text="Record • save • replay • separate character profiles",
    TextColor3=colors.muted,TextXAlignment=Enum.TextXAlignment.Left,
  },header)
  local toggle=make("TextButton",{
    Size=UDim2.fromOffset(62,29),Position=UDim2.new(1,-77,0,15),
    BackgroundColor3=colors.bg,Font=Enum.Font.GothamBold,TextSize=11,
    TextColor3=colors.white,Text="HIDE",BorderSizePixel=0,
    AutoButtonColor=false,
  },header)
  rounded(toggle,9)
  local body=make("Frame",{
    Position=UDim2.fromOffset(0,59),Size=UDim2.new(1,0,1,-59),
    BackgroundTransparency=1,
  },panel)
  make("TextLabel",{
    Size=UDim2.fromOffset(165,20),Position=UDim2.fromOffset(18,18),
    BackgroundTransparency=1,Font=Enum.Font.GothamMedium,TextSize=12,
    TextColor3=colors.white,Text="CHARACTER / PROFILE",
    TextXAlignment=Enum.TextXAlignment.Left,
  },body)
  local input=make("TextBox",{
    Position=UDim2.fromOffset(18,41),Size=UDim2.new(1,-36,0,38),
    BackgroundColor3=colors.surface,BorderSizePixel=0,
    Text=profile,PlaceholderText="e.g. Hero Hunter / Default",
    Font=Enum.Font.Gotham,TextSize=13,TextColor3=colors.white,
    TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=false,
  },body)
  rounded(input,9)
  make("UIPadding",{PaddingLeft=UDim.new(0,12)},input)
  local status=make("TextLabel",{
    Position=UDim2.fromOffset(18,87),Size=UDim2.new(1,-36,0,29),
    BackgroundTransparency=1,Font=Enum.Font.Gotham,TextSize=12,
    TextColor3=colors.muted,
    Text="Ready. Record a combo with keyboard and mouse.",
    TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,
  },body)
  local function message(value)
    status.Text=tostring(value)
    if ctx and type(ctx.Log)=="function" then
      pcall(ctx.Log,"TSB: "..tostring(value))
    end
  end
  local function btn(text,x,y,width,handler,primary)
    local b=make("TextButton",{
      Size=UDim2.fromOffset(width,38),Position=UDim2.fromOffset(x,y),
      BackgroundColor3=primary and colors.accent or colors.surface,
      BorderSizePixel=0,AutoButtonColor=false,
      Font=Enum.Font.GothamMedium,TextSize=12,Text=text,
      TextColor3=primary and colors.bg or colors.white,
    },body)
    rounded(b,9)
    bind(b.MouseButton1Click,handler)
    bind(b.MouseEnter,function()tween(b,{BackgroundColor3=primary and Color3.fromRGB(164,199,233) or Color3.fromRGB(39,52,68)})end)
    bind(b.MouseLeave,function()tween(b,{BackgroundColor3=primary and colors.accent or colors.surface})end)
    return b
  end
  local function sanitize(value)
    local v=tostring(value or ""):gsub("^%s+",""):gsub("%s+$","")
    if v=="" then return "Default" end
    return v:sub(1,48)
  end
  local function switchProfile()
    profile=sanitize(input.Text)
    input.Text=profile
    current=profiles[profile] or {}
    message(profile..": "..#current.." recorded events")
  end
  local function readProfiles()
    if type(readfile)~="function" or type(isfile)~="function" then return end
    local ok,text=pcall(function()return isfile(FILE) and readfile(FILE) or nil end)
    if not ok or type(text)~="string" then return end
    local good,result=pcall(function()return HttpService:JSONDecode(text)end)
    if good and type(result)=="table" and type(result.profiles)=="table" then
      for name,steps in pairs(result.profiles) do
        if type(name)=="string" and type(steps)=="table" then
          local valid={}
          for _,event in ipairs(steps) do
            if type(event)=="table" and type(event.t)=="number"
              and type(event.key)=="string" and type(event.down)=="boolean"
              and acceptable[event.key] and event.t>=0 and event.t<=60 then
              valid[#valid+1]={t=event.t,key=event.key,down=event.down}
            end
          end
          profiles[name]=valid
        end
      end
    end
  end
  local function readRepositoryProfiles()
    if type(loadstring)~="function" then return end
    local url="https://raw.githubusercontent.com/ovaNite/uwuHub/main/novax/scripts/tsb/combos.lua"
    local ok,result=pcall(function()
      local source=game:HttpGet(url,true)
      local fn,err=loadstring(source)
      if not fn then error(err) end
      return fn()
    end)
    if not ok or type(result)~="table" then return end
    for name,steps in pairs(result) do
      if type(name)=="string" and #name<=48 and type(steps)=="table" then
        local valid={}
        for _,event in ipairs(steps) do
          if type(event)=="table" and type(event.t)=="number"
            and type(event.key)=="string" and type(event.down)=="boolean"
            and acceptable[event.key] and event.t>=0 and event.t<=60 then
            valid[#valid+1]={t=event.t,key=event.key,down=event.down}
          end
        end
        profiles[name]=valid
      end
    end
  end
  local function writeProfiles()
    profiles[profile]=current
    if type(writefile)~="function" then
      message("Saved in this session; executor has no writefile()")
      return
    end
    local ok,err=pcall(function()
      if type(makefolder)=="function" and type(isfolder)=="function" then
        if not isfolder("NovaX") then makefolder("NovaX") end
        if not isfolder("NovaX/TSB") then makefolder("NovaX/TSB") end
      end
      writefile(FILE,HttpService:JSONEncode({profiles=profiles,version=1}))
    end)
    message(ok and ("Saved "..profile.." locally") or ("Save failed: "..tostring(err)))
  end
  local function recordInput(key,down)
    if not recording or not acceptable[key] then return end
    if #current>=300 then
      recording=false
      message("Recording stopped: maximum 300 events")
      return
    end
    local at=os.clock()-recordStart
    if at>40 then
      recording=false
      message("Recording stopped: maximum 40 seconds")
      return
    end
    current[#current+1]={t=math.floor(at*1000+0.5)/1000,key=key,down=down}
  end
  local function sendInput(key,down)
    local isMouse=key=="MouseButton1" or key=="MouseButton2"
    local success=false
    if vm then
      if isMouse then
        local m=UIS:GetMouseLocation()
        success=pcall(function()
          vm:SendMouseButtonEvent(m.X,m.Y,key=="MouseButton1" and 0 or 1,down,game,0)
        end)
      else
        local code=Enum.KeyCode[key]
        if code then success=pcall(function()vm:SendKeyEvent(down,code,false,game)end)end
      end
    end
    if not success then
      local fn
      if isMouse then
        if key=="MouseButton1" then fn=down and mouse1press or mouse1release
        else fn=down and mouse2press or mouse2release end
      else
        fn=down and keypress or keyrelease
      end
      if type(fn)=="function" then
        success=pcall(function()
          if isMouse then fn()
          else fn(Enum.KeyCode[key].Value) end
        end)
      end
    end
    return success
  end
  local function releaseHeld()
    for key in pairs(held) do pcall(sendInput,key,false);held[key]=nil end
  end
  local function startRecord()
    if playing then message("Stop playback before recording");return end
    switchProfile()
    current={}
    recordStart=os.clock()
    recording=true
    message("RECORDING "..profile.."  •  press combo keys now")
  end
  local function stopRecord()
    if recording then
      recording=false
      profiles[profile]=current
      writeProfiles()
    else
      playing=false
      releaseHeld()
      message("Playback stop requested")
    end
  end
  local function playback()
    if recording or playing then return end
    switchProfile()
    if #current==0 then message("No events. Record a combo first.");return end
    playing=true
    local selection=current
    task.spawn(function()
      local prior=0
      local sent=0
      for _,event in ipairs(selection) do
        if not live or not playing or (ctx and not ctx.IsRunning()) then break end
        local waitSeconds=math.max(0,event.t-prior)
        if waitSeconds>0 then task.wait(waitSeconds) end
        if not live or not playing then break end
        if sendInput(event.key,event.down) then
          sent+=1
          if event.down then held[event.key]=true else held[event.key]=nil end
        end
        prior=event.t
      end
      releaseHeld()
      playing=false
      message(sent>0 and ("Playback finished: "..sent.."/"..#selection.." events") or
        "No input injection support: use a compatible executor")
    end)
  end
  btn("RECORD",18,130,105,startRecord,true)
  btn("STOP",133,130,105,stopRecord)
  btn("PLAY",248,130,94,playback)
  btn("SAVE",352,130,100,writeProfiles)
  btn("LOAD PROFILE",18,177,210,switchProfile)
  btn("CLEAR PROFILE",239,177,213,function()
    if playing or recording then message("Stop playback / recording first");return end
    switchProfile()
    current={}
    profiles[profile]={}
    writeProfiles()
    message("Cleared "..profile)
  end)
  make("TextLabel",{
    Position=UDim2.fromOffset(18,231),Size=UDim2.new(1,-36,0,53),
    BackgroundTransparency=1,TextWrapped=true,
    Font=Enum.Font.Gotham,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,TextColor3=colors.muted,
    Text="Recorder captures movement, M1/M2, Q/F, Space and moves 1–4. Use a different profile for each character. Replay timing follows the client scheduler and is not guaranteed frame-perfect.",
  },body)
  bind(UIS.InputBegan,function(event,processed)
    if not live or not recording or processed or UIS:GetFocusedTextBox() then return end
    local key=event.UserInputType==Enum.UserInputType.Keyboard
      and event.KeyCode.Name or event.UserInputType.Name
    recordInput(key,true)
  end)
  bind(UIS.InputEnded,function(event)
    if not live or not recording then return end
    local key=event.UserInputType==Enum.UserInputType.Keyboard
      and event.KeyCode.Name or event.UserInputType.Name
    recordInput(key,false)
  end)
  bind(input.FocusLost,switchProfile)
  bind(toggle.MouseButton1Click,function()
    body.Visible=not body.Visible
    toggle.Text=body.Visible and "HIDE" or "SHOW"
    tween(panel,{Size=body.Visible and UDim2.fromOffset(470,362) or UDim2.fromOffset(470,59)})
  end)
  local dragging=false
  local dragStart=nil
  local startPos=nil
  bind(header.InputBegan,function(inputEvent)
    if inputEvent.UserInputType==Enum.UserInputType.MouseButton1 then
      dragging=true
      dragStart=inputEvent.Position
      startPos=panel.Position
    end
  end)
  bind(UIS.InputChanged,function(inputEvent)
    if not dragging or inputEvent.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=inputEvent.Position-dragStart
    panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,
      startPos.Y.Scale,startPos.Y.Offset+delta.Y)
  end)
  bind(UIS.InputEnded,function(inputEvent)
    if inputEvent.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
  end)
  readRepositoryProfiles()
  readProfiles()
  switchProfile()
  local api={}
  function api:Stop()
    if not live then return end
    live=false;playing=false;recording=false
    releaseHeld()
    for _,connection in ipairs(connections) do pcall(function()connection:Disconnect()end)end
    if gui and gui.Parent then gui:Destroy()end
    if environment.NX_TSB_COMBO==api then environment.NX_TSB_COMBO=nil end
  end
  environment.NX_TSB_COMBO=api
  return api
end
