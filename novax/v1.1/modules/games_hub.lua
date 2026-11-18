-- NovaX Games Hub v1.1
-- Separate header workspace; live GitHub folder discovery; native Luau code editor.
-- Does not include a standalone VM: requires the executor's loadstring runtime.
-- IMPORTANT: repository scripts run with the executor's permissions.
return function(env)
  local HttpService=game:GetService("HttpService")
  local TweenService=game:GetService("TweenService")
  local RunService=game:GetService("RunService")
  local Players=game:GetService("Players")
  local win=assert(env.NX_UI_WINDOW,"NovaX window missing")
  local root=assert(win.Root,"NovaX root missing")
  local header=assert(win.Header,"NovaX header anchor missing")
  local sidebar=assert(win.Sidebar,"NovaX sidebar anchor missing")
  local content=assert(win.Content,"NovaX content anchor missing")
  local state=type(env.NX_STATE)=="table" and env.NX_STATE or {}
  if type(state.NovaXGameSelected)~="string" then state.NovaXGameSelected="" end
  local colors={
    bg=Color3.fromRGB(9,13,20),panel=Color3.fromRGB(17,23,34),
    elevated=Color3.fromRGB(24,33,47),hover=Color3.fromRGB(32,47,63),
    accent=Color3.fromRGB(107,166,220),white=Color3.fromRGB(230,239,247),
    muted=Color3.fromRGB(130,148,168),line=Color3.fromRGB(47,63,82),
    green=Color3.fromRGB(100,212,178),red=Color3.fromRGB(229,112,119)
  }
  local REPO="ovaNite/uwuHub"
  local BRANCH="main"
  local ROOT="novax/scripts"
  local RAW="https://raw.githubusercontent.com/"..REPO.."/"..BRANCH.."/"..ROOT.."/"
  local API="https://api.github.com/repos/"..REPO.."/contents/"..ROOT.."?ref="..BRANCH
  local live=true
  local open=false
  local current=nil
  local selectedKind="repo"
  local games={}
  local cards={}
  local lastRefresh=0
  local updateBusy=false
  local generation=0
  local editorDefault="-- NovaX Luau editor\n-- Type a script or choose a game from the library.\nprint('Hello from NovaX Games')"
  local sourceText=editorDefault
  local codeDirty=false
  local runningSession=nil
  local logs={}
  local connections={}
  local function connect(signal,fn)
    local c=signal:Connect(fn)
    connections[#connections+1]=c
    return c
  end
  local function new(class,properties,parent)
    local obj=Instance.new(class)
    for k,v in pairs(properties or {}) do obj[k]=v end
    if parent then obj.Parent=parent end
    return obj
  end
  local function round(obj,r)
    return new("UICorner",{CornerRadius=UDim.new(0,r)},obj)
  end
  local function border(obj,c,t)
    return new("UIStroke",{Color=c or colors.line,Thickness=t or 1,Transparency=0.37},obj)
  end
  local function tween(obj,props,duration)
    if not live or not obj or not obj.Parent then return end
    TweenService:Create(obj,TweenInfo.new(duration or 0.17,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),props):Play()
  end
  local function label(parent,text,size,position,color,weight)
    return new("TextLabel",{
      Size=size,Position=position,BackgroundTransparency=1,
      Font=weight or Enum.Font.Gotham,
      TextSize=13,TextColor3=color or colors.white,
      TextXAlignment=Enum.TextXAlignment.Left,
      TextYAlignment=Enum.TextYAlignment.Center,
      TextTruncate=Enum.TextTruncate.AtEnd,
      Text=tostring(text or ""),
    },parent)
  end
  local function button(parent,text,size,position,callback,accent)
    local btn=new("TextButton",{
      Size=size,Position=position,
      BackgroundColor3=accent and colors.accent or colors.elevated,
      BorderSizePixel=0,AutoButtonColor=false,
      Font=Enum.Font.GothamMedium,TextSize=12,
      TextColor3=accent and colors.bg or colors.white,
      Text=tostring(text or ""),
    },parent)
    round(btn,10)
    connect(btn.MouseEnter,function()
      tween(btn,{BackgroundColor3=accent and Color3.fromRGB(151,192,231) or colors.hover},0.14)
    end)
    connect(btn.MouseLeave,function()
      tween(btn,{BackgroundColor3=accent and colors.accent or colors.elevated},0.14)
    end)
    connect(btn.MouseButton1Click,function()
      if live then
        local ok,err=pcall(callback)
        if not ok then warn("[NovaX Games] "..tostring(err)) end
      end
    end)
    return btn
  end
  local nav=new("Frame",{
    Name="NovaXTopNavigation",Position=UDim2.new(0,434,0,22),
    Size=UDim2.fromOffset(198,34),
    BackgroundColor3=colors.bg,BorderSizePixel=0,
  },header)
  round(nav,11)
  border(nav)
  local mainBtn=button(nav,"MAIN",UDim2.fromOffset(94,28),UDim2.fromOffset(3,3),function()end)
  local gamesBtn=button(nav,"GAMES",UDim2.fromOffset(95,28),UDim2.fromOffset(100,3),function()end)
  local panel=new("Frame",{
    Name="NovaXGamesWorkspace",Position=UDim2.new(0,12,0,86),
    Size=UDim2.new(1,-24,1,-102),BackgroundColor3=colors.bg,
    BorderSizePixel=0,Visible=false,ClipsDescendants=true,
  },root)
  round(panel,14)
  border(panel,colors.line)
  new("UIGradient",{
    Color=ColorSequence.new({
      ColorSequenceKeypoint.new(0,colors.panel),
      ColorSequenceKeypoint.new(1,colors.bg),
    }),Rotation=30,
  },panel)
  label(panel,"GAMES",UDim2.new(0.5,-18,0,32),UDim2.fromOffset(18,11),colors.white,Enum.Font.GothamBold).TextSize=21
  label(panel,"GitHub library  •  browse  •  edit  •  execute",
    UDim2.new(1,-36,0,21),UDim2.fromOffset(19,42),colors.muted)
  local query=new("TextBox",{
    Size=UDim2.new(0.58,-43,0,34),Position=UDim2.fromOffset(18,75),
    BackgroundColor3=colors.elevated,BorderSizePixel=0,
    Font=Enum.Font.Gotham,TextSize=12,TextColor3=colors.white,
    PlaceholderText="Search games and scripts...",
    PlaceholderColor3=colors.muted,
    Text="",ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left,
  },panel)
  round(query,10)
  new("UIPadding",{PaddingLeft=UDim.new(0,13),PaddingRight=UDim.new(0,8)},query)
  local refreshBtn=button(panel,"REFRESH",UDim2.fromOffset(92,34),
    UDim2.new(0.58,-5,0,75),function()end)
  local syncStatus=label(panel,"Checking GitHub...",UDim2.new(0.33,-15,0,28),
    UDim2.new(0.7,6,0,78),colors.muted)
  syncStatus.TextSize=11
  local gridPanel=new("ScrollingFrame",{
    Name="GameGallery",Size=UDim2.new(0.58,-28,1,-132),
    Position=UDim2.fromOffset(18,118),
    BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=3,ScrollBarImageColor3=colors.muted,
    CanvasSize=UDim2.new(0,0,0,0),
    ScrollingDirection=Enum.ScrollingDirection.Y,
  },panel)
  local layout=new("UIGridLayout",{
    SortOrder=Enum.SortOrder.LayoutOrder,
    CellPadding=UDim2.fromOffset(12,12),
    CellSize=UDim2.new(0.5,-9,0,195),
  },gridPanel)
  connect(layout:GetPropertyChangedSignal("AbsoluteContentSize"),function()
    gridPanel.CanvasSize=UDim2.fromOffset(0,layout.AbsoluteContentSize.Y+12)
  end)
  local inspector=new("Frame",{
    Name="ScriptEngine",Size=UDim2.new(0.42,-28,1,-132),
    Position=UDim2.new(0.58,10,0,118),
    BackgroundColor3=colors.panel,BorderSizePixel=0,
  },panel)
  round(inspector,12)
  border(inspector)
  local inspectorTitle=label(inspector,"LUA SCRIPT ENGINE",
    UDim2.new(1,-22,0,24),UDim2.fromOffset(12,10),colors.white,Enum.Font.GothamBold)
  inspectorTitle.TextSize=13
  local subtitle=label(inspector,"Loadstring runtime • no embedded VM",
    UDim2.new(1,-22,0,18),UDim2.fromOffset(12,34),colors.muted)
  subtitle.TextSize=11
  local currentName=label(inspector,"CUSTOM EDITOR",
    UDim2.new(1,-24,0,24),UDim2.fromOffset(12,58),colors.accent,Enum.Font.GothamBold)
  currentName.TextSize=12
  local statusName=label(inspector,"Ready to edit",UDim2.new(1,-24,0,19),
    UDim2.fromOffset(12,79),colors.muted)
  statusName.TextSize=11
  local codeBox=new("TextBox",{
    Name="NovaXCodeEditor",Size=UDim2.new(1,-24,1,-240),
    Position=UDim2.fromOffset(12,104),
    BackgroundColor3=colors.bg,BorderSizePixel=0,
    ClearTextOnFocus=false,MultiLine=true,
    TextWrapped=false,TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,TextSize=12,
    Font=Enum.Font.Code,TextColor3=colors.white,
    PlaceholderText="-- Select an experience or write Luau code",
    PlaceholderColor3=colors.muted,Text=editorDefault,
  },inspector)
  round(codeBox,10)
  border(codeBox,colors.line)
  new("UIPadding",{
    PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),
    PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),
  },codeBox)
  local controlsY=UDim2.new(0,12,1,-126)
  local sourceBtn=button(inspector,"LOAD SOURCE",UDim2.new(0.48,0,0,34),
    controlsY,function()end)
  local customBtn=button(inspector,"NEW SCRIPT",UDim2.new(0.48,0,0,34),
    UDim2.new(0.52,-12,1,-126),function()end)
  local runBtn=button(inspector,"RUN SCRIPT",UDim2.new(0.48,0,0,34),
    UDim2.new(0,12,1,-85),function()end,true)
  local stopBtn=button(inspector,"STOP",UDim2.new(0.48,0,0,34),
    UDim2.new(0.52,-12,1,-85),function()end)
  local console=label(inspector,"No script executed",
    UDim2.new(1,-24,0,37),UDim2.new(0,12,1,-47),colors.muted)
  console.TextWrapped=true
  console.TextYAlignment=Enum.TextYAlignment.Top
  console.TextSize=10

  local function emit(message,color)
    local line=tostring(message or "")
    logs[#logs+1]=line
    if #logs>16 then table.remove(logs,1) end
    console.Text=line
    console.TextColor3=color or colors.muted
    print("[NovaX Games] "..line)
  end
  local function httpGet(url,maxSize)
    local ok,response=pcall(function() return game:HttpGet(url,true) end)
    if not ok or type(response)~="string" or #response==0 then
      return nil,"HTTP unavailable: "..string.sub(tostring(response),1,100)
    end
    if #response>(maxSize or 180000) then return nil,"Downloaded file too large" end
    return response
  end
  local function fetchJSON(url)
    local data,err=httpGet(url,240000)
    if not data then return nil,err end
    local ok,decoded=pcall(function()return HttpService:JSONDecode(data)end)
    if not ok or type(decoded)~="table" then return nil,"Invalid JSON" end
    return decoded
  end
  local function slugValid(value)
    return type(value)=="string" and #value>0 and #value<=55
      and value:match("^[%w_%-]+$")~=nil
  end
  local function scriptValid(value)
    return type(value)=="string" and #value>0 and #value<=65
      and value:match("^[%w_%-]+%.lua$")~=nil
  end
  local function validate(meta,slug)
    if type(meta)~="table" or not slugValid(slug) then return nil end
    local filename=meta.script or "loader.lua"
    if not scriptValid(filename) then return nil end
    local name=meta.name
    if type(name)~="string" or name=="" or #name>80 then return nil end
    local places={}
    if type(meta.placeIds)=="table" then
      for _,id in ipairs(meta.placeIds) do
        local num=tonumber(id)
        if num and num>0 then places[#places+1]=num end
      end
    end
    local uid=tonumber(meta.universeId)
    local image="rbxassetid://0"
    if uid and uid>0 then
      image="rbxthumb://type=GameIcon&id="..math.floor(uid).."&w=420&h=420"
    end
    if type(meta.thumbnail)=="string" then
      local asset=meta.thumbnail:match("^rbxassetid://(%d+)$")
      if asset then image="rbxassetid://"..asset end
    end
    return {
      id=slug,name=name,description=tostring(meta.description or ""):sub(1,140),
      filename=filename,placeIds=places,universeId=uid,thumbnail=image,
      source=RAW..slug.."/"..filename,
    }
  end
  local function inExperience(item)
    if not item then return false end
    if #item.placeIds==0 and not item.universeId then return false end
    if item.universeId and game.GameId==item.universeId then return true end
    for _,place in ipairs(item.placeIds) do
      if game.PlaceId==place then return true end
    end
    return false
  end
  local function metadata(slug)
    local data=fetchJSON(RAW..slug.."/game.json")
    return data and validate(data,slug) or nil
  end
  local function compare(a,b)
    local first=inExperience(a) and 1 or 0
    local second=inExperience(b) and 1 or 0
    if first~=second then return first>second end
    return a.name:lower()<b.name:lower()
  end
  local function renderGames()
    for _,card in ipairs(cards) do if card.Parent then card:Destroy() end end
    table.clear(cards)
    local term=query.Text:lower()
    local visible=0
    for _,entry in ipairs(games) do
      if term=="" or entry.name:lower():find(term,1,true)
        or entry.id:lower():find(term,1,true)
        or entry.description:lower():find(term,1,true) then
        visible+=1
        local holder=new("TextButton",{
          Size=UDim2.new(1,0,0,195),
          BackgroundColor3=colors.elevated,
          BorderSizePixel=0,AutoButtonColor=false,Text="",
          LayoutOrder=visible,
          ClipsDescendants=true,
        },gridPanel)
        round(holder,12)
        border(holder)
        local thumb=new("ImageLabel",{
          Name="Thumbnail",Size=UDim2.new(1,-14,0,126),
          Position=UDim2.fromOffset(7,7),BackgroundColor3=colors.bg,
          BorderSizePixel=0,ScaleType=Enum.ScaleType.Crop,
          Image=entry.thumbnail,
        },holder)
        round(thumb,9)
        label(holder,entry.name,UDim2.new(1,-18,0,24),
          UDim2.fromOffset(9,137),colors.white,Enum.Font.GothamBold).TextSize=12
        label(holder,inExperience(entry) and "CURRENT EXPERIENCE  •  READY" or "SCRIPT  •  "..entry.id:upper(),
          UDim2.new(1,-18,0,18),UDim2.fromOffset(9,165),
          inExperience(entry) and colors.green or colors.muted).TextSize=10
        connect(holder.MouseEnter,function()tween(holder,{BackgroundColor3=colors.hover},0.18)end)
        connect(holder.MouseLeave,function()tween(holder,{BackgroundColor3=colors.elevated},0.18)end)
        connect(holder.MouseButton1Click,function()
          current=entry
          selectedKind="repo"
          codeDirty=false
          state.NovaXGameSelected=entry.id
          currentName.Text=entry.name
          statusName.Text=entry.description~="" and entry.description or "GitHub: "..entry.id
          codeBox.Text="-- "..entry.name.."\n-- Click LOAD SOURCE to fetch "..entry.filename..".\n-- RUN is available only inside the matching experience."
          sourceText=codeBox.Text
          emit("Selected "..entry.name..". Load source to inspect it.")
        end)
        cards[#cards+1]=holder
      end
    end
    if visible==0 then
      local empty=label(gridPanel,"No games found. Add a folder in novax/scripts and click REFRESH.",
        UDim2.new(1,0,0,50),UDim2.fromOffset(8,20),colors.muted)
      cards[#cards+1]=empty
    end
    syncStatus.Text=#games.." games • "..(updateBusy and "syncing" or "live library")
  end

  local function scanRepo()
    if updateBusy or not live then return end
    updateBusy=true
    syncStatus.Text="SYNCING..."
    local myGeneration=generation+1
    generation=myGeneration
    task.spawn(function()
      local found={}
      local seen={}
      local index,apiError=fetchJSON(API)
      if index and type(index)=="table" then
        for _,entry in ipairs(index) do
          if not live or generation~=myGeneration then return end
          if type(entry)=="table" and entry.type=="dir" and slugValid(entry.name) then
            local meta=metadata(entry.name)
            if meta then
              found[#found+1]=meta
              seen[meta.id]=true
            end
          end
        end
      end
      -- Rate-limit fallback. The index itself can also be used for offline
      -- bootstrap; new folders appear automatically via the GitHub API.
      if #found==0 then
        local fallback=fetchJSON(RAW.."index.json")
        if fallback and type(fallback.games)=="table" then
          for _,entry in ipairs(fallback.games) do
            local id=entry.id
            if slugValid(id) and not seen[id] then
              local meta=validate(entry,id)
              if meta then found[#found+1]=meta;seen[id]=true end
            end
          end
        end
      end
      if not live or generation~=myGeneration then return end
      table.sort(found,compare)
      games=found
      lastRefresh=os.clock()
      updateBusy=false
      renderGames()
      if #found==0 then
        emit("No game metadata found. GitHub API: "..tostring(apiError or "empty"),colors.red)
      elseif index then
        emit("Synced "..#found.." game folders from GitHub",colors.green)
      else
        emit("Loaded fallback index; GitHub API unavailable",colors.muted)
      end
    end)
  end
  local function loadSource()
    if not current then emit("Choose a game card first",colors.red);return end
    local target=current
    local source,err=httpGet(target.source,220000)
    if not source then emit("Source failed: "..tostring(err),colors.red);return end
    if not live or current~=target then return end
    sourceText=source
    codeDirty=false
    codeBox.Text=source
    emit("Loaded "..target.id.."/"..target.filename.." ("..#source.." bytes)",colors.green)
  end
  local function stopSession()
    if not runningSession then
      emit("No active stoppable script")
      return
    end
    local previous=runningSession
    runningSession=nil
    previous.alive=false
    if type(previous.stop)=="function" then
      local ok,err=pcall(previous.stop)
      emit(ok and "Script stop requested" or "Stop error: "..tostring(err),
        ok and colors.green or colors.red)
    else
      emit("Stop signal set; this script did not provide Stop(). Already-started tasks may continue.")
    end
  end
  local function runEditor()
    if type(loadstring)~="function" then
      emit("Executor does not expose loadstring",colors.red)
      return
    end
    if selectedKind=="repo" and current and not inExperience(current) then
      emit("Wrong experience. Open "..current.name.." before running its loader.",colors.red)
      return
    end
    local source=codeBox.Text
    if source=="" then emit("Editor is empty",colors.red);return end
    if #source>220000 then emit("Editor limit: 220KB",colors.red);return end
    if runningSession then stopSession() end
    local chunk,syntax=loadstring(source)
    if not chunk then
      emit("Luau compile error: "..tostring(syntax),colors.red)
      return
    end
    local session={alive=true,stop=nil}
    runningSession=session
    local name=current and current.name or "Custom"
    emit("Executing "..name.."...",colors.accent)
    task.spawn(function()
      local context={
        Name=name,
        IsRunning=function() return session.alive end,
        Log=function(message) if live then emit(tostring(message)) end end,
        PlaceId=game.PlaceId,UniverseId=game.GameId,
      }
      -- loadstring runs in the existing executor context, not a sandbox.
      local ok,result=pcall(chunk,context)
      if not ok then
        if runningSession==session then runningSession=nil end
        emit("Runtime error: "..tostring(result),colors.red)
        return
      end
      if type(result)=="function" then
        local initialized,returned=pcall(result,context)
        if not initialized then
          if runningSession==session then runningSession=nil end
          emit("Loader error: "..tostring(returned),colors.red)
          return
        end
        result=returned
      end
      if type(result)=="table" and type(result.Stop)=="function" then
        session.stop=function() result:Stop() end
        emit(name.." active • Stop() available",colors.green)
      else
        if runningSession==session then runningSession=nil end
        emit(name.." completed (no Stop() contract)",colors.green)
      end
    end)
  end

  connect(query:GetPropertyChangedSignal("Text"),renderGames)
  connect(codeBox:GetPropertyChangedSignal("Text"),function()
    codeDirty=true
  end)
  local function activate(mode)
    if not live then return end
    open=mode=="Games"
    sidebar.Visible=not open
    content.Visible=not open
    panel.Visible=open
    tween(mainBtn,{BackgroundColor3=open and colors.elevated or colors.accent,
      TextColor3=open and colors.white or colors.bg})
    tween(gamesBtn,{BackgroundColor3=open and colors.accent or colors.elevated,
      TextColor3=open and colors.bg or colors.white})
    if open and os.clock()-lastRefresh>20 then scanRepo() end
  end
  mainBtn.MouseButton1Click:Connect(function()activate("Main")end)
  gamesBtn.MouseButton1Click:Connect(function()activate("Games")end)
  refreshBtn.MouseButton1Click:Connect(scanRepo)
  sourceBtn.MouseButton1Click:Connect(loadSource)
  customBtn.MouseButton1Click:Connect(function()
    current=nil
    selectedKind="custom"
    codeBox.Text=editorDefault
    sourceText=editorDefault
    codeDirty=false
    currentName.Text="CUSTOM LUA EDITOR"
    statusName.Text="Your own Luau script • manual execution"
    emit("Custom editor ready. Scripts run with your executor's privileges.")
  end)
  runBtn.MouseButton1Click:Connect(runEditor)
  stopBtn.MouseButton1Click:Connect(stopSession)
  activate("Main")
  task.spawn(function()
    while live do
      task.wait(120)
      if live and open and os.clock()-lastRefresh>100 then scanRepo() end
    end
  end)
  env.NX_GAMES_HUB={
    Refresh=scanRepo,Open=function()activate("Games")end,
    SelectGame=function(slug)
      for _,entry in ipairs(games) do
        if entry.id==slug then
          current=entry
          state.NovaXGameSelected=slug
          currentName.Text=entry.name
          statusName.Text=entry.description
          activate("Games")
          return true
        end
      end
      return false
    end,
  }
  return {Stop=function()
    if not live then return end
    stopSession()
    live=false
    generation+=1
    sidebar.Visible=true
    content.Visible=true
    for _,conn in ipairs(connections) do pcall(function()conn:Disconnect()end) end
    if nav.Parent then nav:Destroy()end
    if panel.Parent then panel:Destroy()end
    if env.NX_GAMES_HUB then env.NX_GAMES_HUB=nil end
  end}
end
