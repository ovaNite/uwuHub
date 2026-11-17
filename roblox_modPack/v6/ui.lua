-- roblox_modPack v6 / panel.lua
-- Neutral compact settings window. No giant debug overlay.
return function(ctx)
    local player=ctx.Players.LocalPlayer
    local guiRoot=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
    if not guiRoot then error("No PlayerGui") end
    local UserInput=ctx.UserInputService
    local Tween=game:GetService("TweenService")
    local function new(kind,parent,props)
        local x=Instance.new(kind)
        for prop,value in pairs(props or {}) do x[prop]=value end
        x.Parent=parent
        return x
    end
    local function corner(p,r)
        return new("UICorner",p,{CornerRadius=UDim.new(0,r)})
    end
    local function fade(p,props)
        pcall(function()
            Tween:Create(p,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),props):Play()
        end)
    end
    local colors={
        bg=Color3.fromRGB(17,19,21),sidebar=Color3.fromRGB(21,24,27),
        select=Color3.fromRGB(38,44,49),border=Color3.fromRGB(62,69,75),
        text=Color3.fromRGB(238,239,240),secondary=Color3.fromRGB(160,168,174),
        accent=Color3.fromRGB(167,188,199)
    }
    local screen=new("ScreenGui",guiRoot,{
        Name="RM6_Control",ResetOnSpawn=false,DisplayOrder=280,
        IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
    ctx.Track(screen)
    local window=new("Frame",screen,{
        Size=UDim2.fromOffset(492,360),Position=UDim2.new(.5,-246,.5,-180),
        BackgroundColor3=colors.bg,BackgroundTransparency=.02,
        BorderSizePixel=0,ClipsDescendants=true,ZIndex=2
    })
    corner(window,11)
    new("UIStroke",window,{Color=colors.border,Transparency=.38,Thickness=1})
    local scale=new("UIScale",window,{Scale=.94})
    fade(scale,{Scale=1})
    local function label(parent,text,x,y,w,h,size,bold,color)
        return new("TextLabel",parent,{
            Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            Text=text,Font=bold and Enum.Font.GothamSemibold or Enum.Font.Gotham,
            TextSize=size or 12,TextColor3=color or colors.text,
            TextXAlignment=Enum.TextXAlignment.Left,
            BackgroundTransparency=1,BorderSizePixel=0,
            TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6
        })
    end
    local function button(parent,text,x,y,w,h,action)
        local p=new("TextButton",parent,{
            Text=text,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),
            TextColor3=colors.text,BackgroundColor3=colors.select,
            BorderSizePixel=0,AutoButtonColor=false,
            Font=Enum.Font.GothamMedium,TextSize=12,ZIndex=6
        })
        corner(p,7)
        ctx.Link(p.MouseEnter,function()fade(p,{BackgroundColor3=Color3.fromRGB(57,64,69)})end)
        ctx.Link(p.MouseLeave,function()fade(p,{BackgroundColor3=colors.select})end)
        if action then ctx.Link(p.MouseButton1Click,action) end
        return p
    end
    local header=new("Frame",window,{
        Size=UDim2.new(1,0,0,48),BackgroundTransparency=1,ZIndex=5
    })
    label(header,"REALISM",18,12,180,27,16,true)
    label(header,"V6  /  CLIENT GRAPHICS",285,13,155,27,10,false,colors.secondary)
    local hide=button(header,"—",448,9,30,30,nil)
    hide.TextSize=17
    local nav=new("Frame",window,{
        Position=UDim2.fromOffset(0,49),Size=UDim2.fromOffset(117,311),
        BackgroundColor3=colors.sidebar,BorderSizePixel=0,ZIndex=4
    })
    new("Frame",window,{
        Position=UDim2.fromOffset(117,49),Size=UDim2.fromOffset(1,311),
        BackgroundColor3=colors.border,BackgroundTransparency=.65,
        BorderSizePixel=0,ZIndex=5
    })
    local tabs={"Weather","Materials","Graphics"}
    local pages={}
    local navigation={}
    local function page(name,visible)
        return new("Frame",window,{
            Name=name,Position=UDim2.fromOffset(134,62),
            Size=UDim2.fromOffset(342,283),BackgroundTransparency=1,
            Visible=visible,ZIndex=5
        })
    end
    for i,name in ipairs(tabs) do
        pages[name]=page(name,i==1)
        local b=button(nav,name,9,12+(i-1)*43,99,34,nil)
        navigation[name]=b
        ctx.Link(b.MouseButton1Click,function()
            for n,p in pairs(pages) do p.Visible=n==name end
            for n,x in pairs(navigation) do
                fade(x,{BackgroundColor3=n==name and
                    Color3.fromRGB(58,64,68) or colors.select})
            end
        end)
    end
    local launcher=button(screen,"R",0,0,35,35,nil)
    launcher.Position=UDim2.new(1,-52,0,18)
    launcher.Visible=false
    local function show(value)
        window.Visible=value
        launcher.Visible=not value
        if value then scale.Scale=.93;fade(scale,{Scale=1}) end
    end
    ctx.Link(hide.MouseButton1Click,function()show(false)end)
    ctx.Link(launcher.MouseButton1Click,function()show(true)end)
    local drag=false
    local dragStart,frameStart
    ctx.Link(header.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true;dragStart=input.Position;frameStart=window.Position
        end
    end)
    ctx.Link(UserInput.InputChanged,function(input)
        if drag and input.UserInputType==Enum.UserInputType.MouseMovement then
            local d=input.Position-dragStart
            window.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,
                frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
        end
    end)
    ctx.Link(UserInput.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
    end)
    ctx.Link(UserInput.InputBegan,function(input,used)
        if not used and input.KeyCode==Enum.KeyCode.F10 then
            show(not window.Visible)
        end
    end)
    local function toggle(parent,title,y,key)
        local b=button(parent,title,0,y,335,36,nil)
        local stateLabel=label(b,"ON",285,1,44,34,11,true,colors.accent)
        stateLabel.TextXAlignment=Enum.TextXAlignment.Right
        local function sync()
            local enabled=ctx.Options[key]~=false
            stateLabel.Text=enabled and "ON" or "OFF"
            stateLabel.TextColor3=enabled and colors.accent or colors.secondary
        end
        ctx.Link(b.MouseButton1Click,function()
            ctx.Options[key]=not (ctx.Options[key]~=false)
            sync()
        end)
        sync()
        return b
    end
    local function slider(parent,title,y,initial,onChange)
        label(parent,title,1,y,250,20,12,false)
        local number=label(parent,tostring(initial).."%",277,y,57,20,12,true,colors.secondary)
        number.TextXAlignment=Enum.TextXAlignment.Right
        local line=new("Frame",parent,{
            Position=UDim2.fromOffset(1,y+29),Size=UDim2.fromOffset(331,5),
            BackgroundColor3=Color3.fromRGB(57,62,68),BorderSizePixel=0,ZIndex=7
        })
        corner(line,3)
        local fill=new("Frame",line,{
            Size=UDim2.fromScale(initial/100,1),
            BackgroundColor3=colors.accent,BorderSizePixel=0,ZIndex=8
        })
        corner(fill,3)
        local active=false
        local function set(mouseX,commit)
            local ratio=math.clamp((mouseX-line.AbsolutePosition.X)/
                math.max(1,line.AbsoluteSize.X),.01,1)
            local pct=math.clamp(math.floor(ratio*100+.5),1,100)
            fill.Size=UDim2.fromScale(pct/100,1)
            number.Text=pct.."%"
            if commit then onChange(pct) end
        end
        ctx.Link(line.InputBegan,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 then
                active=true;set(input.Position.X,true)
            end
        end)
        ctx.Link(UserInput.InputChanged,function(input)
            if active and input.UserInputType==Enum.UserInputType.MouseMovement then
                set(input.Position.X,true)
            end
        end)
        ctx.Link(UserInput.InputEnded,function(input)
            if input.UserInputType==Enum.UserInputType.MouseButton1 then active=false end
        end)
    end
    local w=pages.Weather
    label(w,"Weather",0,0,290,25,15,true)
    local function weather(mode)
        ctx.Base.SetWeatherMode(mode)
        if mode=="RAIN" then
            ctx.Base.SetWeatherIntensityFraction(ctx.Options.RainStrength/100)
        elseif mode=="SNOW" then
            ctx.Base.SetWeatherIntensityFraction(ctx.Options.SnowStrength/100)
        end
    end
    button(w,"RAIN",0,38,103,34,function()weather("RAIN")end)
    button(w,"SNOW",115,38,103,34,function()weather("SNOW")end)
    button(w,"CLEAR",230,38,103,34,function()weather("OFF")end)
    slider(w,"Rain",99,ctx.Options.RainStrength,function(x)
        ctx.Options.RainStrength=x
        if ctx.Base.weatherMode=="RAIN" then ctx.Base.SetWeatherIntensityFraction(x/100) end
    end)
    slider(w,"Snow",165,ctx.Options.SnowStrength,function(x)
        ctx.Options.SnowStrength=x
        if ctx.Base.weatherMode=="SNOW" then ctx.Base.SetWeatherIntensityFraction(x/100) end
    end)
    local summary=label(w,"Physics: –",0,244,333,22,11,false,colors.secondary)
    local m=pages.Materials
    label(m,"Surface finish",0,0,300,25,15,true)
    toggle(m,"Wet floor / surface highlights",43,"WorldFinish")
    toggle(m,"Weapon metal / optic finish",87,"WeaponFinish")
    toggle(m,"Camera water droplets",131,"CameraWet")
    label(m,"Respects existing image textures",0,194,330,24,11,false,colors.secondary)
    local counts=label(m,"–",0,224,330,36,11,false,colors.secondary)
    local g=pages.Graphics
    label(g,"Color and lighting",0,0,325,25,15,true)
    local profile=label(g,"Profile: Realism",0,45,330,24,12,false)
    button(g,"NEXT PROFILE",0,80,333,36,function()
        if ctx.Styles then profile.Text="Profile: "..ctx.Styles.Next() end
    end)
    toggle(g,"Subtle optical effects",130,"Optics")
    toggle(g,"Environmental lighting",173,"Fire")
    local bottom=label(g,"F10 menu  /  F8 on-off  /  F6 diagnostics",
        0,241,330,24,10,false,colors.secondary)
    local tick=0
    ctx.AddRender(function(dt)
        tick+=dt
        if tick<.38 then return end
        tick=0
        summary.Text=string.format("Weather: %s   |   Physics %.1f / 90 Hz",
            tostring(ctx.Base.weatherMode),tonumber(ctx.Base.weatherPhysicsMeasuredHz) or 0)
        counts.Text=string.format("Floor: %d   Walls: %d   Weapon: %d   Puddles: %d",
            ctx.Stats.WetFloors or 0,ctx.Stats.WallCandidates or 0,
            ctx.Stats.WeaponFinishes or 0,ctx.Stats.WetPuddles or 0)
    end)
    return {Name="Realism v6 menu"}
end