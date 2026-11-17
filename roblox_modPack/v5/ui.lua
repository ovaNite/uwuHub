-- roblox_modPack / modern_ui.lua
-- Black custom window, movable, animated, 1..100% rain/snow, theme gallery,
-- local music player and remappable keys. No Roblox default widgets.
return function(ctx)
    local player=ctx.Players.LocalPlayer
    local playerGui=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",12)
    if not playerGui then return {Name="UI unavailable"} end
    local legacy=playerGui:FindFirstChild("RM4_LocalGraphicsDiagnostics")
    if legacy then legacy.Enabled=false end
    local U=ctx.UserInputService
    local TweenService=game:GetService("TweenService")
    local Run=ctx.RunService
    local screen=Instance.new("ScreenGui")
    screen.Name="roblox_modPack_CUSTOM_UI"
    screen.ResetOnSpawn=false;screen.IgnoreGuiInset=false
    screen.DisplayOrder=300;screen.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screen.Parent=playerGui
    ctx.Track(screen)
    local accent=Color3.fromRGB(196,208,216)
    local theme={radius=14,windowOpacity=.06,accent=accent,key=Enum.KeyCode.F10}
    local rounds={}
    local function new(class,props,parent)
        local o=Instance.new(class)
        for key,value in pairs(props or {}) do o[key]=value end
        o.Parent=parent
        return o
    end
    local function corner(obj,rad)
        local c=new("UICorner",{CornerRadius=UDim.new(0,rad or theme.radius)},obj)
        table.insert(rounds,c)
        return c
    end
    local function stroke(obj,width,trans)
        return new("UIStroke",{
            Color=Color3.fromRGB(94,105,116),Thickness=width or 1,
            Transparency=trans or .76
        },obj)
    end
    local function animate(obj,dest,time)
        pcall(function()
            TweenService:Create(obj,TweenInfo.new(time or .19,Enum.EasingStyle.Quint,
                Enum.EasingDirection.Out),dest):Play()
        end)
    end
    local gui=new("Frame",{
        Name="Main",Size=UDim2.fromOffset(654,503),Position=UDim2.new(.5,-327,.5,-251),
        BackgroundColor3=Color3.fromRGB(13,15,17),
        BackgroundTransparency=theme.windowOpacity,BorderSizePixel=0,
        ClipsDescendants=true,Visible=true
    },screen)
    corner(gui);stroke(gui,1,.61)
    local scaler=new("UIScale",{Scale=.92},gui)
    animate(scaler,{Scale=1},.30)
    local background=new("ImageLabel",{
        Name="CustomBackground",BackgroundTransparency=1,
        Size=UDim2.fromScale(1,1),Image="",
        ScaleType=Enum.ScaleType.Crop,ImageTransparency=.75,ZIndex=1
    },gui)
    local overlay=new("Frame",{
        Size=UDim2.fromScale(1,1),
        BackgroundColor3=Color3.fromRGB(10,12,14),
        BackgroundTransparency=.18,BorderSizePixel=0,ZIndex=2
    },gui)
    local top=new("Frame",{
        Size=UDim2.new(1,0,0,59),BackgroundTransparency=1,ZIndex=3
    },gui)
    local title=new("TextLabel",{
        Text="REALISM",Font=Enum.Font.GothamBold,TextSize=19,
        TextColor3=Color3.fromRGB(235,237,239),BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(23,6),
        Size=UDim2.fromOffset(240,45),ZIndex=4
    },top)
    local sub=new("TextLabel",{
        Text="LOCAL ENVIRONMENT  /  V5.2",Font=Enum.Font.GothamMedium,TextSize=10,
        TextColor3=Color3.fromRGB(121,137,148),BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Right,Position=UDim2.new(1,-295,0,13),
        Size=UDim2.fromOffset(218,30),ZIndex=4
    },top)
    local function textLabel(parent,label,pos,size,sz,color,font)
        return new("TextLabel",{
            Text=label or "",Position=pos or UDim2.fromOffset(0,0),
            Size=size or UDim2.fromOffset(100,30),BackgroundTransparency=1,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
            TextWrapped=false,Font=font or Enum.Font.Gotham,
            TextSize=sz or 13,TextColor3=color or Color3.fromRGB(210,216,220),ZIndex=6
        },parent)
    end
    local function button(parent,titleText,pos,size,click,selected)
        local b=new("TextButton",{
            Text=titleText,Position=pos,Size=size,
            BackgroundColor3=selected and Color3.fromRGB(48,58,64) or Color3.fromRGB(31,35,39),
            TextColor3=Color3.fromRGB(220,227,232),Font=Enum.Font.GothamMedium,
            TextSize=12,AutoButtonColor=false,BorderSizePixel=0,ZIndex=6
        },parent)
        corner(b,8);stroke(b,1,.89)
        ctx.Link(b.MouseEnter,function()
            animate(b,{BackgroundColor3=Color3.fromRGB(55,62,68)},.12)
        end)
        ctx.Link(b.MouseLeave,function()
            animate(b,{BackgroundColor3=selected and Color3.fromRGB(48,58,64)
                or Color3.fromRGB(31,35,39)},.16)
        end)
        if click then ctx.Link(b.MouseButton1Click,click) end
        return b
    end
    local close=button(top,"—",UDim2.new(1,-51,0,10),UDim2.fromOffset(36,35),nil)
    close.TextSize=20
    local bubble=button(screen,"◈",UDim2.new(1,-54,0,17),UDim2.fromOffset(39,39),nil)
    bubble.Visible=false;corner(bubble,11)
    local function visible(state)
        if state then
            gui.Visible=true;bubble.Visible=false
            scaler.Scale=.9;animate(scaler,{Scale=1},.22)
        else
            gui.Visible=false;bubble.Visible=true
        end
    end
    ctx.Link(close.MouseButton1Click,function()visible(false)end)
    ctx.Link(bubble.MouseButton1Click,function()visible(true)end)
    local sidebar=new("Frame",{
        Position=UDim2.fromOffset(12,63),Size=UDim2.fromOffset(146,424),
        BackgroundColor3=Color3.fromRGB(19,23,26),BorderSizePixel=0,
        BackgroundTransparency=.06,ZIndex=3
    },gui)
    corner(sidebar,10)
    local pageNames={"WETTER","LOOKS","AUDIO","CUSTOM"}
    local pages={}
    local menuButtons={}
    local active="WETTER"
    for i,name in ipairs(pageNames) do
        local b=button(sidebar,name,UDim2.fromOffset(9,14+(i-1)*55),
            UDim2.fromOffset(128,43),nil,i==1)
        menuButtons[name]=b
    end
    local status=textLabel(sidebar,"90 HZ  ·  LOCAL",UDim2.fromOffset(12,380),
        UDim2.fromOffset(128,20),10,Color3.fromRGB(132,151,161),Enum.Font.GothamSemibold)
    local function page(name)
        local p=new("ScrollingFrame",{
            Name=name,Position=UDim2.fromOffset(172,70),Size=UDim2.fromOffset(467,400),
            BackgroundTransparency=1,BorderSizePixel=0,
            ScrollBarThickness=3,ScrollBarImageColor3=Color3.fromRGB(93,105,111),
            CanvasSize=UDim2.fromOffset(0,690),
            ScrollingDirection=Enum.ScrollingDirection.Y,
            Visible=name==active,ZIndex=4
        },gui)
        pages[name]=p
        return p
    end
    for _,name in ipairs(pageNames) do page(name) end
    local function switch(name)
        active=name
        for n,p in pairs(pages) do p.Visible=n==name end
        for n,b in pairs(menuButtons) do
            animate(b,{BackgroundColor3=n==name and Color3.fromRGB(50,59,65)
                or Color3.fromRGB(31,35,39)},.20)
        end
    end
    for name,b in pairs(menuButtons) do
        ctx.Link(b.MouseButton1Click,function()switch(name)end)
    end
    local function caption(p,label,y)
        return textLabel(p,label,UDim2.fromOffset(6,y),
            UDim2.fromOffset(445,23),14,Color3.fromRGB(229,234,237),
            Enum.Font.GothamSemibold)
    end
    local function field(p,placeholder,pos,size)
        local box=new("TextBox",{
            Text="",PlaceholderText=placeholder,ClearTextOnFocus=false,
            Position=pos,Size=size,BackgroundColor3=Color3.fromRGB(31,35,38),
            BorderSizePixel=0,Font=Enum.Font.Gotham,
            TextColor3=Color3.fromRGB(229,233,235),
            PlaceholderColor3=Color3.fromRGB(134,147,157),
            TextSize=12,ZIndex=6
        },p);corner(box,8);stroke(box,1,.87)
        return box
    end
    local function slider(p,titleText,y,default,action)
        local label=caption(p,titleText,y)
        local out=textLabel(p,tostring(default).."%",UDim2.fromOffset(399,y),
            UDim2.fromOffset(55,23),12,Color3.fromRGB(211,221,226),
            Enum.Font.GothamSemibold)
        out.TextXAlignment=Enum.TextXAlignment.Right
        local track=new("Frame",{
            Position=UDim2.fromOffset(7,y+37),Size=UDim2.fromOffset(435,7),
            BackgroundColor3=Color3.fromRGB(58,64,69),BorderSizePixel=0,ZIndex=6
        },p);corner(track,5)
        local fill=new("Frame",{
            Size=UDim2.fromScale(default/100,1),BackgroundColor3=accent,
            BorderSizePixel=0,ZIndex=7
        },track);corner(fill,5)
        local knob=new("Frame",{
            Size=UDim2.fromOffset(16,16),
            AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.new(default/100,0,.5,0),
            BackgroundColor3=Color3.fromRGB(241,247,250),
            BorderSizePixel=0,ZIndex=8
        },track);corner(knob,8)
        local sliding=false
        local pct=default
        local function update(px,committed)
            local target=(px-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1)
            pct=math.clamp(math.floor(target*99+.5)+1,1,100)
            out.Text=tostring(pct).."%"
            fill.Size=UDim2.fromScale(pct/100,1)
            knob.Position=UDim2.new(pct/100,0,.5,0)
            if committed then action(pct) end
        end
        ctx.Link(track.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 or
                input.UserInputType==Enum.UserInputType.Touch then
                sliding=true;update(input.Position.X,false)
            end
        end)
        ctx.Link(U.InputChanged,function(input)
            if sliding and (input.UserInputType==Enum.UserInputType.MouseMovement or
                input.UserInputType==Enum.UserInputType.Touch) then
                update(input.Position.X,false)
            end
        end)
        ctx.Link(U.InputEnded,function(input)
            if sliding and (input.UserInputType==Enum.UserInputType.MouseButton1 or
                input.UserInputType==Enum.UserInputType.Touch) then
                sliding=false;update(input.Position.X,true)
            end
        end)
        return function(value)
            pct=math.clamp(tonumber(value) or pct,1,100)
            out.Text=tostring(pct).."%"
            fill.Size=UDim2.fromScale(pct/100,1)
            knob.Position=UDim2.new(pct/100,0,.5,0)
        end
    end
    local weather=pages.WETTER
    weather.CanvasSize=UDim2.fromOffset(0,570)
    caption(weather,"NIEDERSCHLAG",0)
    local function setMode(mode)
        pcall(function()ctx.Base.SetWeatherMode(mode)end)
        if mode=="RAIN" then
            ctx.Base.SetWeatherIntensityFraction((ctx.Options.RainPercent or 65)/100)
        elseif mode=="SNOW" then
            ctx.Base.SetWeatherIntensityFraction((ctx.Options.SnowPercent or 50)/100)
        end
    end
    button(weather,"REGEN",UDim2.fromOffset(6,35),UDim2.fromOffset(104,38),
        function()ctx.Options.Storm=false;setMode("RAIN")end)
    button(weather,"SCHNEE",UDim2.fromOffset(121,35),UDim2.fromOffset(104,38),
        function()ctx.Options.Storm=false;setMode("SNOW")end)
    button(weather,"KLAR",UDim2.fromOffset(236,35),UDim2.fromOffset(104,38),
        function()ctx.Options.Storm=false;setMode("OFF")end)
    button(weather,"STURM",UDim2.fromOffset(351,35),UDim2.fromOffset(104,38),
        function()ctx.Options.Storm=true;setMode("RAIN")end)
    slider(weather,"Regenstaerke",94,ctx.Options.RainPercent or 65,function(v)
        ctx.Options.RainPercent=v
        if ctx.Base.weatherMode=="RAIN" then ctx.Base.SetWeatherIntensityFraction(v/100)end
    end)
    slider(weather,"Schneestaerke",175,ctx.Options.SnowPercent or 50,function(v)
        ctx.Options.SnowPercent=v
        if ctx.Base.weatherMode=="SNOW" then ctx.Base.SetWeatherIntensityFraction(v/100)end
    end)
    slider(weather,"Niederschlag / Audio",257,ctx.Options.RainVolumePercent or 55,function(v)
        ctx.Options.RainVolumePercent=v
        if ctx.Audio then ctx.Audio.SetRainVolume(v/100)end
    end)
    caption(weather,"WETTER-STATUS",355)
    local report=textLabel(weather,"Wetterphysik wird geladen ...",
        UDim2.fromOffset(6,390),UDim2.fromOffset(445,100),
        12,Color3.fromRGB(182,194,201))
    report.TextWrapped=true;report.TextYAlignment=Enum.TextYAlignment.Top
    local looks=pages.LOOKS
    looks.CanvasSize=UDim2.fromOffset(0,670)
    caption(looks,"GRAFIKPROFILE",2)
    local profiles=ctx.Styles and ctx.Styles.List() or {"Realism","Anime"}
    for i,name in ipairs(profiles) do
        local col=(i-1)%2
        local row=math.floor((i-1)/2)
        button(looks,name,UDim2.fromOffset(6+col*224,38+row*51),
            UDim2.fromOffset(212,41),function()
                if ctx.Styles then ctx.Styles.Set(name)end
            end)
    end
    local looksBase=38+math.ceil(#profiles/2)*51+12
    slider(looks,"Stil-Intensitaet",looksBase,ctx.Options.StylePercent or 85,function(v)
        ctx.Options.StylePercent=v
    end)
    local audio=pages.AUDIO
    audio.CanvasSize=UDim2.fromOffset(0,470)
    caption(audio,"MUSIK  /  NUR LOKAL",0)
    local song=field(audio,"Roblox Audio Asset-ID",UDim2.fromOffset(6,36),UDim2.fromOffset(440,39))
    button(audio,"PLAY",UDim2.fromOffset(6,91),UDim2.fromOffset(212,39),function()
        if ctx.Audio then ctx.Audio.PlayMusic(song.Text) end
    end)
    button(audio,"STOP",UDim2.fromOffset(230,91),UDim2.fromOffset(216,39),function()
        if ctx.Audio then ctx.Audio.StopMusic() end
    end)
    slider(audio,"Musiklautstaerke",155,35,function(v)
        if ctx.Audio then ctx.Audio.MusicVolume(v/100) end
    end)
    textLabel(audio,"Sound bleibt auf deinem Client. Ein Lua-Skript kann\n"
        .."Musik nicht als Mikrofon an andere Spieler senden.",
        UDim2.fromOffset(6,252),UDim2.fromOffset(445,50),12,
        Color3.fromRGB(168,185,194)).TextWrapped=true
    caption(audio,"Roblox-Audioassets muessen nutzbar sein",322)
    local custom=pages.CUSTOM
    custom.CanvasSize=UDim2.fromOffset(0,760)
    caption(custom,"FENSTER-DESIGN",0)
    slider(custom,"Eckenradius",37,55,function(v)
        theme.radius=math.floor(v*.25)+1
        for _,c in ipairs(rounds) do c.CornerRadius=UDim.new(0,theme.radius)end
    end)
    slider(custom,"Transparenz",118,6,function(v)
        theme.windowOpacity=math.min(.65,v/140)
        animate(gui,{BackgroundTransparency=theme.windowOpacity},.12)
    end)
    caption(custom,"UI-Hintergrund  /  Roblox Image Asset-ID",207)
    local art=field(custom,"rbxassetid://...",UDim2.fromOffset(6,241),UDim2.fromOffset(440,37))
    button(custom,"BILD ANWENDEN",UDim2.fromOffset(6,293),
        UDim2.fromOffset(212,36),function()
            local id=art.Text:match("(%d+)")
            background.Image=id and "rbxassetid://"..id or ""
        end)
    button(custom,"ENTFERNEN",UDim2.fromOffset(230,293),
        UDim2.fromOffset(216,36),function()
            art.Text="";background.Image=""
        end)
    caption(custom,"KEYBINDS",352)
    local binds={
        {"Menu","MENUE",theme.key},
        {"Toggle","REALISMUS",ctx.Base.Keybinds.Toggle},
        {"Weather","WETTER",ctx.Base.Keybinds.Weather},
        {"Intensity","INTENSITAET",ctx.Base.Keybinds.Intensity},
        {"Details","STATUS",ctx.Base.Keybinds.Details}
    }
    local awaiting=nil
    local keyButtons={}
    for i,v in ipairs(binds) do
        keyButtons[v[1]]=button(custom,v[2].."   ["..v[3].Name.."]",
            UDim2.fromOffset(6,388+(i-1)*48),UDim2.fromOffset(440,38),
            function()
                awaiting=v[1]
                keyButtons[v[1]].Text=v[2].."   [TASTE DRUECKEN]"
            end)
    end
    -- Remapping works through the original core, not a fake additional hotkey.
    ctx.Link(U.InputBegan,function(input,processed)
        if awaiting then
            if input.UserInputType~=Enum.UserInputType.Keyboard then return end
            local name=awaiting;awaiting=nil
            if input.KeyCode~=Enum.KeyCode.Unknown then
                if name=="Menu" then
                    theme.key=input.KeyCode
                else
                    ctx.Base.SetKeybind(name,input.KeyCode)
                end
            end
            for _,v in ipairs(binds) do
                local key=v[1]=="Menu" and theme.key or ctx.Base.Keybinds[v[1]]
                keyButtons[v[1]].Text=v[2].."   ["..key.Name.."]"
            end
            return
        end
        if not processed and input.KeyCode==theme.key then
            visible(not gui.Visible)
        end
    end)
    -- Smooth panel dragging; never forcibly changes mouse cursor state.
    local dragging=false
    local begin=nil
    local saved=nil
    ctx.Link(top.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;begin=input.Position;saved=gui.Position
        end
    end)
    ctx.Link(U.InputChanged,function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=input.Position-begin
            gui.Position=UDim2.new(saved.X.Scale,saved.X.Offset+delta.X,
                saved.Y.Scale,saved.Y.Offset+delta.Y)
        end
    end)
    ctx.Link(U.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    local refresh=0
    ctx.AddRender(function(dt)
        refresh+=dt
        if refresh<.38 then return end
        refresh=0
        local base=ctx.Base
        report.Text=string.format(
            "Wetter: %s  /  %d%%\nPhysik: %.1f Hz (Ziel 90)\n"
            .."Schneehuegel: %d  ·  Pfuetzen: %d\n"
            .."Aufprall: %d  ·  3D-Spritzer: %d",
            tostring(base.weatherMode or "OFF"),
            math.floor((base.weatherIntensity or 1)*100+.5),
            tonumber(base.weatherPhysicsMeasuredHz) or 0,
            tonumber(ctx.Stats.OrganicSnowMounds) or 0,
            tonumber(ctx.Stats.OrganicPuddles) or 0,
            tonumber(ctx.Stats.WeatherImpacts) or 0,
            tonumber(ctx.Stats.SplashImpacts) or 0)
        status.Text=string.format("%.0f HZ / LOCAL",tonumber(ctx.PhysicsActual) or 0)
    end)
    return {Name="Custom UI v5.2",Stop=function()
        if legacy and legacy.Parent then legacy.Enabled=true end
    end}
end