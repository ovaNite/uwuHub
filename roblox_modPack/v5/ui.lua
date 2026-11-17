-- roblox_modPack v5.3 | interface.lua
-- Compact, restrained, animated settings panel. No game HUD replacements.
return function(ctx)
    local player=ctx.Players.LocalPlayer
    local playerGui=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
    if not playerGui then return {Name="UI unavailable"} end
    for _,name in ipairs({"RM4_LocalGraphicsDiagnostics","RM5_RealismControl","roblox_modPack_CUSTOM_UI"}) do
        local old=playerGui:FindFirstChild(name)
        if old then old.Enabled=false end
    end
    local U=ctx.UserInputService
    local Tween=game:GetService("TweenService")
    local palette={
        window=Color3.fromRGB(17,19,22),side=Color3.fromRGB(21,24,28),
        field=Color3.fromRGB(33,37,42),edge=Color3.fromRGB(73,80,87),
        text=Color3.fromRGB(233,236,239),sub=Color3.fromRGB(151,160,169),
        accent=Color3.fromRGB(143,166,176)
    }
    local appearance={radius=10,alpha=.025,key=Enum.KeyCode.F10}
    local rounders={}
    local function make(class,props,parent)
        local o=Instance.new(class)
        for k,v in pairs(props or {}) do o[k]=v end
        o.Parent=parent
        return o
    end
    local function rounded(p,r)
        local c=make("UICorner",{CornerRadius=UDim.new(0,r or appearance.radius)},p)
        rounders[#rounders+1]=c
        return c
    end
    local function edge(p,alpha)
        make("UIStroke",{Color=palette.edge,Thickness=1,Transparency=alpha or .78},p)
    end
    local function anim(o,props,time)
        local ok=pcall(function()
            Tween:Create(o,TweenInfo.new(time or .16,Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out),props):Play()
        end)
        return ok
    end
    local function label(parent,text,x,y,w,h,sz,bold,color)
        return make("TextLabel",{
            Name="Label",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            Text=text,Font=bold and Enum.Font.GothamSemibold or Enum.Font.Gotham,
            TextSize=sz or 12,TextColor3=color or palette.text,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Center,
            BackgroundTransparency=1,ZIndex=9
        },parent)
    end
    local function btn(parent,text,x,y,w,h,callback)
        local b=make("TextButton",{
            Name="Action",Position=UDim2.fromOffset(x,y),
            Size=UDim2.fromOffset(w,h),BackgroundColor3=palette.field,
            BorderSizePixel=0,Text=text,
            Font=Enum.Font.GothamMedium,TextSize=12,
            TextColor3=palette.text,ZIndex=9,AutoButtonColor=false
        },parent)
        rounded(b,7)
        ctx.Link(b.MouseEnter,function()
            anim(b,{BackgroundColor3=Color3.fromRGB(49,55,60)},.13)
        end)
        ctx.Link(b.MouseLeave,function()
            anim(b,{BackgroundColor3=palette.field},.17)
        end)
        if callback then
            ctx.Link(b.MouseButton1Click,function()
                local ok,msg=pcall(callback)
                if not ok then warn("[Realism UI] "..tostring(msg)) end
            end)
        end
        return b
    end
    local gui=make("ScreenGui",{
        Name="RM53_Control",IgnoreGuiInset=false,ResetOnSpawn=false,
        DisplayOrder=250,ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    },playerGui)
    ctx.Track(gui)
    local panel=make("Frame",{
        Name="Window",Size=UDim2.fromOffset(568,432),
        Position=UDim2.new(.5,-284,.5,-216),
        BackgroundColor3=palette.window,
        BackgroundTransparency=appearance.alpha,
        BorderSizePixel=0,ClipsDescendants=true,ZIndex=2
    },gui)
    rounded(panel,12);edge(panel,.60)
    local scale=make("UIScale",{Scale=.97},panel)
    anim(scale,{Scale=1},.26)
    local background=make("ImageLabel",{
        Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        Image="",ImageTransparency=.88,ScaleType=Enum.ScaleType.Crop,ZIndex=2
    },panel)
    local bgveil=make("Frame",{
        Size=UDim2.fromScale(1,1),
        BackgroundColor3=palette.window,BackgroundTransparency=.23,
        BorderSizePixel=0,ZIndex=3
    },panel)
    local top=make("Frame",{
        Name="Header",Size=UDim2.new(1,0,0,57),
        BackgroundTransparency=1,ZIndex=4
    },panel)
    label(top,"REALISM",21,9,190,24,16,true)
    label(top,"LOCAL GRAPHICS  /  V5.3",22,32,230,15,10,false,palette.sub)
    local live=label(top,"●  ACTIVE",404,17,97,21,11,true,palette.accent)
    live.TextXAlignment=Enum.TextXAlignment.Right
    local minimize=btn(top,"–",522,12,31,30,nil)
    minimize.TextSize=18
    local hairline=make("Frame",{
        Position=UDim2.fromOffset(0,57),
        Size=UDim2.new(1,0,0,1),BackgroundColor3=palette.edge,
        BackgroundTransparency=.78,BorderSizePixel=0,ZIndex=5
    },panel)
    local side=make("Frame",{
        Name="Navigation",Position=UDim2.fromOffset(0,58),
        Size=UDim2.fromOffset(135,374),
        BackgroundColor3=palette.side,
        BackgroundTransparency=.045,BorderSizePixel=0,ZIndex=4
    },panel)
    local vertical=make("Frame",{
        Position=UDim2.fromOffset(134,58),Size=UDim2.fromOffset(1,374),
        BackgroundColor3=palette.edge,BackgroundTransparency=.80,
        BorderSizePixel=0,ZIndex=5
    },panel)
    local pages={}
    local tabNames={"Weather","Graphics","Sound","Interface"}
    local nav={}
    local activePage="Weather"
    for index,name in ipairs(tabNames) do
        local tab=make("TextButton",{
            Name=name,Text=name,TextSize=12,Font=Enum.Font.GothamMedium,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextColor3=index==1 and palette.text or palette.sub,
            Position=UDim2.fromOffset(11,16+(index-1)*44),
            Size=UDim2.fromOffset(115,36),BorderSizePixel=0,
            BackgroundColor3=index==1 and Color3.fromRGB(43,48,54)
                or palette.side,
            AutoButtonColor=false,ZIndex=7
        },side)
        make("UIPadding",{PaddingLeft=UDim.new(0,12)},tab)
        rounded(tab,6)
        nav[name]=tab
        local page=make("ScrollingFrame",{
            Name=name,
            Position=UDim2.fromOffset(152,73),Size=UDim2.fromOffset(402,341),
            BackgroundTransparency=1,BorderSizePixel=0,
            CanvasSize=UDim2.fromOffset(0,480),
            ScrollBarThickness=3,ScrollBarImageColor3=palette.edge,
            Visible=index==1,ZIndex=7
        },panel)
        pages[name]=page
    end
    local function choose(name)
        activePage=name
        for n,tab in pairs(nav) do
            local selected=n==name
            anim(tab,{
                BackgroundColor3=selected and Color3.fromRGB(43,48,54) or palette.side,
                TextColor3=selected and palette.text or palette.sub
            },.15)
            pages[n].Visible=selected
        end
    end
    for name,tab in pairs(nav) do
        ctx.Link(tab.MouseButton1Click,function() choose(name) end)
    end
    local launcher=btn(gui,"R",0,0,36,36,nil)
    launcher.Position=UDim2.new(1,-52,0,18)
    launcher.Visible=false
    launcher.TextSize=14
    rounded(launcher,10)
    local function show(b)
        if b then
            panel.Visible=true;launcher.Visible=false
            scale.Scale=.95;anim(scale,{Scale=1},.18)
        else
            panel.Visible=false;launcher.Visible=true
        end
    end
    ctx.Link(minimize.MouseButton1Click,function()show(false)end)
    ctx.Link(launcher.MouseButton1Click,function()show(true)end)
    local function section(p,text,y)
        label(p,text,2,y,383,22,12,true,palette.text)
    end
    local function small(p,text,y)
        return label(p,text,3,y,380,22,11,false,palette.sub)
    end
    local function toggle(p,title,x,y,w,state,fn)
        local b=btn(p,"",x,y,w,39,nil)
        local text=label(b,title,12,0,w-68,39,12,false)
        local pill=make("Frame",{
            Size=UDim2.fromOffset(36,20),Position=UDim2.fromOffset(w-48,10),
            BackgroundColor3=state and palette.accent or Color3.fromRGB(72,78,84),
            BorderSizePixel=0,ZIndex=10
        },b)
        rounded(pill,10)
        local dot=make("Frame",{
            Size=UDim2.fromOffset(14,14),
            Position=state and UDim2.fromOffset(19,3) or UDim2.fromOffset(3,3),
            BackgroundColor3=Color3.fromRGB(246,247,249),
            BorderSizePixel=0,ZIndex=11
        },pill)
        rounded(dot,7)
        local value=state
        ctx.Link(b.MouseButton1Click,function()
            value=not value
            anim(pill,{BackgroundColor3=value and palette.accent or Color3.fromRGB(72,78,84)})
            anim(dot,{Position=value and UDim2.fromOffset(19,3) or UDim2.fromOffset(3,3)})
            fn(value)
        end)
        return b
    end
    local function slider(p,titleText,y,initial,fn)
        label(p,titleText,2,y,305,24,12,false)
        local number=label(p,tostring(initial).."%",335,y,52,24,12,true,palette.sub)
        number.TextXAlignment=Enum.TextXAlignment.Right
        local line=make("Frame",{
            Position=UDim2.fromOffset(6,y+35),
            Size=UDim2.fromOffset(376,5),
            BackgroundColor3=Color3.fromRGB(65,73,79),
            BorderSizePixel=0,ZIndex=9
        },p)
        rounded(line,3)
        local fill=make("Frame",{
            Size=UDim2.fromScale(initial/100,1),
            BackgroundColor3=palette.accent,BorderSizePixel=0,ZIndex=10
        },line)
        rounded(fill,3)
        local thumb=make("Frame",{
            Size=UDim2.fromOffset(12,12),AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.new(initial/100,0,.5,0),
            BackgroundColor3=Color3.fromRGB(237,242,245),BorderSizePixel=0,
            ZIndex=11
        },line)
        rounded(thumb,6)
        local dragging=false,last=initial
        local function set(x)
            local f=math.clamp((x-line.AbsolutePosition.X)/
                math.max(line.AbsoluteSize.X,1),0,1)
            last=math.clamp(math.floor(f*100+.5),1,100)
            number.Text=last.."%"
            fill.Size=UDim2.fromScale(last/100,1)
            thumb.Position=UDim2.new(last/100,0,.5,0)
        end
        ctx.Link(line.InputBegan,function(e)
            if e.UserInputType==Enum.UserInputType.MouseButton1
                or e.UserInputType==Enum.UserInputType.Touch then
                dragging=true;set(e.Position.X)
            end
        end)
        ctx.Link(U.InputChanged,function(e)
            if dragging and (e.UserInputType==Enum.UserInputType.MouseMovement
                or e.UserInputType==Enum.UserInputType.Touch) then
                set(e.Position.X)
            end
        end)
        ctx.Link(U.InputEnded,function(e)
            if dragging and (e.UserInputType==Enum.UserInputType.MouseButton1
                or e.UserInputType==Enum.UserInputType.Touch) then
                dragging=false;fn(last)
            end
        end)
    end
    local function input(p,placeholder,y)
        local field=make("TextBox",{
            Position=UDim2.fromOffset(2,y),Size=UDim2.fromOffset(382,36),
            Text="",PlaceholderText=placeholder,
            ClearTextOnFocus=false,Font=Enum.Font.Gotham,
            TextSize=12,TextColor3=palette.text,
            PlaceholderColor3=palette.sub,
            BackgroundColor3=palette.field,BorderSizePixel=0,ZIndex=9
        },p)
        rounded(field,7)
        make("UIPadding",{PaddingLeft=UDim.new(0,12)},field)
        return field
    end
    -- Weather ----------------------------------------------------------
    local w=pages.Weather
    section(w,"WEATHER",0)
    local function setMode(mode)
        ctx.Base.SetWeatherMode(mode)
        if mode=="RAIN" then
            ctx.Base.SetWeatherIntensityFraction((ctx.Options.RainPercent or 65)/100)
        elseif mode=="SNOW" then
            ctx.Base.SetWeatherIntensityFraction((ctx.Options.SnowPercent or 45)/100)
        end
    end
    btn(w,"Rain",2,32,91,35,function()ctx.Options.Storm=false;setMode("RAIN")end)
    btn(w,"Snow",100,32,91,35,function()ctx.Options.Storm=false;setMode("SNOW")end)
    btn(w,"Clear",198,32,91,35,function()ctx.Options.Storm=false;setMode("OFF")end)
    btn(w,"Storm",296,32,91,35,function()ctx.Options.Storm=true;setMode("RAIN")end)
    slider(w,"Rain intensity",88,ctx.Options.RainPercent or 65,function(v)
        ctx.Options.RainPercent=v
        if ctx.Base.weatherMode=="RAIN" then ctx.Base.SetWeatherIntensityFraction(v/100) end
    end)
    slider(w,"Snow intensity",163,ctx.Options.SnowPercent or 45,function(v)
        ctx.Options.SnowPercent=v
        if ctx.Base.weatherMode=="SNOW" then ctx.Base.SetWeatherIntensityFraction(v/100) end
    end)
    toggle(w,"Camera lens droplets",2,248,384,true,function(on)ctx.Options.CameraWet=on end)
    local stat=small(w,"Physics  /  —",304)
    w.CanvasSize=UDim2.fromOffset(0,347)
    -- Graphics ---------------------------------------------------------
    local g=pages.Graphics
    section(g,"VISUAL PROFILE",0)
    local looks=ctx.Styles and ctx.Styles.List() or {"Realism","Anime","Galaxy"}
    for i,name in ipairs(looks) do
        local col=(i-1)%2;local row=math.floor((i-1)/2)
        btn(g,name,2+col*195,35+row*41,186,34,function()
            if ctx.Styles then ctx.Styles.Set(name) end
        end)
    end
    local y=50+math.ceil(#looks/2)*41
    slider(g,"Profile intensity",y,85,function(v)ctx.Options.StylePercent=v end)
    toggle(g,"Camera optics",2,y+79,384,true,function(on)ctx.Options.Optics=on end)
    g.CanvasSize=UDim2.fromOffset(0,y+140)
    -- Audio ------------------------------------------------------------
    local a=pages.Sound
    section(a,"LOCAL AUDIO",0)
    small(a,"Rain ambience and water impacts",28)
    slider(a,"Rain volume",62,55,function(v)
        ctx.Options.RainVolume=v/100
        if ctx.Audio then ctx.Audio.SetRainVolume(v/100) end
    end)
    toggle(a,"Weather sounds",2,145,384,true,function(on)ctx.Options.Sound=on end)
    section(a,"MUSIC",213)
    local song=input(a,"Roblox audio asset ID",242)
    btn(a,"Play",2,290,186,35,function()
        if ctx.Audio then ctx.Audio.PlayMusic(song.Text) end
    end)
    btn(a,"Stop",198,290,186,35,function()
        if ctx.Audio then ctx.Audio.StopMusic() end
    end)
    a.CanvasSize=UDim2.fromOffset(0,351)
    -- Interface --------------------------------------------------------
    local p=pages.Interface
    section(p,"APPEARANCE",0)
    slider(p,"Corner radius",30,40,function(v)
        appearance.radius=math.floor(v*.22)+2
        for _,c in ipairs(rounders) do c.CornerRadius=UDim.new(0,appearance.radius) end
    end)
    slider(p,"Window transparency",105,5,function(v)
        appearance.alpha=math.min(.55,v/180)
        anim(panel,{BackgroundTransparency=appearance.alpha})
    end)
    small(p,"Background image (Roblox asset ID)",190)
    local art=input(p,"rbxassetid://...",215)
    btn(p,"Apply image",2,263,185,34,function()
        local id=art.Text:match("(%d+)")
        background.Image=id and "rbxassetid://"..id or ""
    end)
    btn(p,"Clear",198,263,185,34,function()
        art.Text="";background.Image=""
    end)
    section(p,"SHORTCUTS",326)
    local binds={
        {"Menu","Menu",appearance.key},
        {"Toggle","Realism",ctx.Base.Keybinds.Toggle},
        {"Weather","Weather",ctx.Base.Keybinds.Weather},
        {"Intensity","Intensity",ctx.Base.Keybinds.Intensity},
        {"Details","Diagnostics",ctx.Base.Keybinds.Details}
    }
    local keyBtns={}
    local waiting=nil
    for i,entry in ipairs(binds) do
        local k,titleText,key=entry[1],entry[2],entry[3]
        keyBtns[k]=btn(p,titleText.."   /   "..key.Name,2,360+(i-1)*41,382,34,
            function()
                waiting=k
                keyBtns[k].Text=titleText.."   /   PRESS A KEY"
            end)
    end
    p.CanvasSize=UDim2.fromOffset(0,586)
    ctx.Link(U.InputBegan,function(input,processed)
        if waiting then
            if input.UserInputType~=Enum.UserInputType.Keyboard
                or input.KeyCode==Enum.KeyCode.Unknown then return end
            local choice=waiting;waiting=nil
            if choice=="Menu" then
                appearance.key=input.KeyCode
            else
                ctx.Base.SetKeybind(choice,input.KeyCode)
            end
            for _,entry in ipairs(binds) do
                local key=entry[1]=="Menu" and appearance.key or ctx.Base.Keybinds[entry[1]]
                keyBtns[entry[1]].Text=entry[2].."   /   "..key.Name
            end
            return
        end
        if not processed and input.KeyCode==appearance.key then
            show(not panel.Visible)
        end
    end)
    -- Drag the header; no modal cursor lock and no input capture after release.
    local dragging=false
    local startMouse,startWindow
    ctx.Link(top.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;startMouse=input.Position;startWindow=panel.Position
        end
    end)
    ctx.Link(U.InputChanged,function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local d=input.Position-startMouse
            panel.Position=UDim2.new(startWindow.X.Scale,startWindow.X.Offset+d.X,
                startWindow.Y.Scale,startWindow.Y.Offset+d.Y)
        end
    end)
    ctx.Link(U.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    local elapsed=0
    ctx.AddRender(function(dt)
        elapsed+=dt
        if elapsed<.45 then return end
        elapsed=0
        live.Text=ctx.Base.enabled and "●  ACTIVE" or "○  PAUSED"
        live.TextColor3=ctx.Base.enabled and palette.accent or palette.sub
        stat.Text=string.format("%s  ·  %.0f / 90 Hz  ·  %d lens drops",
            tostring(ctx.Base.weatherMode or "OFF"),
            tonumber(ctx.Base.weatherPhysicsMeasuredHz) or 0,
            tonumber(ctx.Stats.LensDroplets) or 0)
    end)
    return {Name="Minimal custom UI v5.3", Stop=function()
        for _,name in ipairs({"RM4_LocalGraphicsDiagnostics","RM5_RealismControl","roblox_modPack_CUSTOM_UI"}) do
            local old=playerGui:FindFirstChild(name)
            if old then old.Enabled=true end
        end
    end}
end