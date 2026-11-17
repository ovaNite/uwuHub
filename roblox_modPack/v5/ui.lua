-- roblox_modPack v5 / ui.lua
-- User-customizable dark Roblox UI. Roblox asset IDs only (no arbitrary local GIF).
return function(ctx)
    local player=ctx.Players.LocalPlayer
    local playerGui=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
    if not playerGui then return end
    local legacy=playerGui:FindFirstChild("RM4_LocalGraphicsDiagnostics")
    if legacy then legacy.Enabled=false end
    local U=ctx.UserInputService
    local gui=Instance.new("ScreenGui")
    gui.Name="RM5_RealismControl"
    gui.ResetOnSpawn=false;gui.DisplayOrder=40;gui.IgnoreGuiInset=false
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    gui.Parent=playerGui;ctx.Track(gui)
    local theme={radius=11,opacity=.07,accent=Color3.fromRGB(189,198,207)}
    local corners,accents={},{}
    local function obj(class,props,parent)
        local o=Instance.new(class)
        for k,v in pairs(props or {}) do o[k]=v end
        o.Parent=parent
        return o
    end
    local function round(target)
        local c=obj("UICorner",{CornerRadius=UDim.new(0,theme.radius)},target)
        corners[#corners+1]=c
        return c
    end
    local panel=obj("Frame",{
        Name="Panel",Size=UDim2.fromOffset(430,420),
        Position=UDim2.new(.5,-215,.5,-210),
        BackgroundColor3=Color3.fromRGB(15,17,19),
        BackgroundTransparency=theme.opacity,BorderSizePixel=0,
        ClipsDescendants=true
    },gui)
    round(panel)
    local bg=obj("ImageLabel",{
        Name="Background",Size=UDim2.fromScale(1,1),
        BackgroundTransparency=1,ImageTransparency=.70,
        ScaleType=Enum.ScaleType.Crop,Image="",ZIndex=1
    },panel)
    local shade=obj("Frame",{
        Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(11,13,15),
        BackgroundTransparency=.25,BorderSizePixel=0,ZIndex=2
    },panel)
    local heading=obj("TextButton",{
        Name="Drag",Text="  REALISM  /  ENVIRONMENT",Size=UDim2.new(1,-45,0,48),
        Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(239,241,242),
        TextXAlignment=Enum.TextXAlignment.Left,BackgroundTransparency=1,
        ZIndex=3
    },panel)
    local close=obj("TextButton",{
        Text="–",Size=UDim2.fromOffset(37,37),Position=UDim2.new(1,-44,0,5),
        BackgroundColor3=Color3.fromRGB(35,38,40),
        TextColor3=Color3.fromRGB(236,237,238),Font=Enum.Font.GothamBold,
        TextSize=22,ZIndex=4,BorderSizePixel=0
    },panel);round(close)
    local open=obj("TextButton",{
        Name="Open",Text="◈",Size=UDim2.fromOffset(40,40),
        Position=UDim2.new(1,-52,0,16),
        BackgroundColor3=Color3.fromRGB(21,23,25),BorderSizePixel=0,
        TextColor3=theme.accent,Font=Enum.Font.GothamBold,TextSize=19,Visible=false
    },gui);round(open);accents[#accents+1]=open

    local pages={}
    local tabs=obj("Frame",{
        Size=UDim2.new(1,-24,0,39),Position=UDim2.fromOffset(12,53),
        BackgroundTransparency=1,ZIndex=3
    },panel)
    local tabNames={"WEATHER","VISUALS","STYLE"}
    local activePage="WEATHER"
    local function activate(name)
        activePage=name
        for page,p in pairs(pages) do p.Visible=page==name end
    end
    for i,name in ipairs(tabNames) do
        local b=obj("TextButton",{
            Name=name,Size=UDim2.new(1/3,-6,1,0),Position=UDim2.new((i-1)/3,3,0,0),
            Text=name,Font=Enum.Font.GothamSemibold,TextSize=12,
            TextColor3=Color3.fromRGB(223,226,229),
            BackgroundColor3=Color3.fromRGB(34,36,38),BorderSizePixel=0,ZIndex=3
        },tabs);round(b)
        ctx.Link(b.MouseButton1Click,function() activate(name) end)
        pages[name]=obj("Frame",{
            Size=UDim2.new(1,-24,1,-147),Position=UDim2.fromOffset(12,102),
            BackgroundTransparency=1,Visible=i==1,ZIndex=3
        },panel)
    end
    local function label(where,text,y,size)
        return obj("TextLabel",{
            Size=UDim2.new(1,0,0,size or 26),Position=UDim2.fromOffset(0,y),
            BackgroundTransparency=1,Text=text,TextWrapped=true,
            TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,
            Font=Enum.Font.Gotham,TextColor3=Color3.fromRGB(195,201,204),
            TextSize=12,ZIndex=3
        },where)
    end
    local function button(where,name,text,x,y,w,h,fn)
        local b=obj("TextButton",{
            Name=name,Text=text,Position=UDim2.fromOffset(x,y),
            Size=UDim2.fromOffset(w,h),BorderSizePixel=0,ZIndex=3,
            BackgroundColor3=Color3.fromRGB(39,42,45),
            TextColor3=Color3.fromRGB(238,239,240),Font=Enum.Font.GothamSemibold,
            TextSize=12
        },where);round(b)
        ctx.Link(b.MouseButton1Click,function()
            local ok,err=pcall(fn)
            if not ok then warn("[RM5 UI] "..tostring(err)) end
        end)
        return b
    end
    local weather=pages.WEATHER
    label(weather,"NEEDLE-THIN RAIN / WIND-DRIVEN SNOW",0,28)
    button(weather,"Rain","RAIN",0,36,126,40,function() ctx.Base.SetWeatherMode("RAIN") end)
    button(weather,"Snow","SNOW",140,36,126,40,function() ctx.Base.SetWeatherMode("SNOW") end)
    button(weather,"Clear","CLEAR",280,36,126,40,function() ctx.Base.SetWeatherMode("OFF") end)
    button(weather,"Intensity","INTENSITY  ↻",0,92,198,36,function() ctx.Base.CycleWeatherIntensity() end)
    button(weather,"Power","SIMULATION  ON/OFF",209,92,197,36,function()
        ctx.Base.SetEnabled(not ctx.Base.enabled)
    end)
    label(weather,"Physics target: 90 fixed steps / second",143)
    local telemetry=label(weather,"Waiting for client physics...",175,95)
    telemetry.TextYAlignment=Enum.TextYAlignment.Top
    local visual=pages.VISUALS
    label(visual,"LOCAL EFFECTS / REVERSIBLE",0)
    local flagButtons={}
    for i,data in ipairs({
        {"Fire","Fire lighting and particles"},
        {"Foliage","Foliage movement"},
        {"Scope","Scope depth-of-field"}
    }) do
        local key,caption=data[1],data[2]
        flagButtons[key]=button(visual,key,caption,0,35+(i-1)*52,406,42,function()
            ctx.Options[key]=not ctx.Options[key]
        end)
    end
    label(visual,"Scope optics modify ONLY depth-of-field at zoom.\nNo new GPU shaders, ray-tracing or gameplay physics.",205,52)
    local style=pages.STYLE
    label(style,"PANEL APPEARANCE / OWN ASSET ID",0)
    local asset=obj("TextBox",{
        Name="BackgroundAssetId",Text="",PlaceholderText="rbxassetid://12345678",
        ClearTextOnFocus=false,Size=UDim2.fromOffset(406,36),
        Position=UDim2.fromOffset(0,34),ZIndex=3,
        BackgroundColor3=Color3.fromRGB(40,42,44),BorderSizePixel=0,
        Font=Enum.Font.Code,TextColor3=Color3.fromRGB(237,237,237),
        PlaceholderColor3=Color3.fromRGB(124,129,132),TextSize=13
    },style);round(asset)
    local function setAsset()
        local id=asset.Text:match("(%d+)")
        bg.Image=id and ("rbxassetid://"..id) or ""
    end
    ctx.Link(asset.FocusLost,function(enter)
        if enter then setAsset() end
    end)
    button(style,"Load","APPLY IMAGE",0,80,196,36,setAsset)
    button(style,"ResetImage","REMOVE IMAGE",210,80,196,36,function()asset.Text="";bg.Image="" end)
    button(style,"Corners","CORNER RADIUS  ↻",0,132,196,36,function()
        theme.radius=({7,11,18,25})[({[7]=2,[11]=3,[18]=4,[25]=1})[theme.radius] or 2]
        for _,corner in ipairs(corners) do corner.CornerRadius=UDim.new(0,theme.radius) end
    end)
    button(style,"Opacity","PANEL OPACITY  ↻",210,132,196,36,function()
        theme.opacity=theme.opacity>.13 and .02 or theme.opacity+.06
        panel.BackgroundTransparency=theme.opacity
    end)
    button(style,"Accent","NEUTRAL ACCENT  ↻",0,184,406,36,function()
        local colors={
            Color3.fromRGB(189,198,207),
            Color3.fromRGB(231,224,211),
            Color3.fromRGB(160,182,193)}
        local index=1
        for i,c in ipairs(colors) do if c==theme.accent then index=i end end
        theme.accent=colors[index%#colors+1]
        for _,b in ipairs(accents) do b.TextColor3=theme.accent end
    end)
    label(style,"Backgrounds require Roblox-approved image asset IDs.\nArbitrary disk PNG and animated GIF are not supported.",236,45)

    local footer=label(panel,"F6 status  ·  F7 weather  ·  F8 power  ·  F9 strength",385,24)
    footer.Position=UDim2.fromOffset(14,387)
    footer.Size=UDim2.new(1,-28,0,24)
    footer.TextColor3=theme.accent;accents[#accents+1]=footer
    local dragging,lastPos,startPos=false,nil,nil
    ctx.Link(heading.InputBegan,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;lastPos=input.Position;startPos=panel.Position
        end
    end)
    ctx.Link(U.InputEnded,function(input)
        if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
    end)
    ctx.Link(U.InputChanged,function(input)
        if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
            local delta=input.Position-lastPos
            panel.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,
                startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
    ctx.Link(close.MouseButton1Click,function()
        panel.Visible=false;open.Visible=true
    end)
    ctx.Link(open.MouseButton1Click,function()
        panel.Visible=true;open.Visible=false
    end)
    ctx.Link(U.InputBegan,function(input,processed)
        if not processed and input.KeyCode==Enum.KeyCode.F10 then
            panel.Visible=not panel.Visible;open.Visible=not panel.Visible
        end
    end)
    local last=0
    ctx.AddRender(function(dt)
        last+=dt
        if last<.45 then return end
        last=0
        if activePage=="WEATHER" then
            local base=ctx.Base
            telemetry.Text=string.format(
                "Mode: %s  |  intensity %.1fx\n"
                .."Core physics: %.1f / 90 Hz  |  missed %.3fs\n"
                .."World puddles: %d  |  snow cells: %d\n"
                .."Body droplets: %d  |  body impacts: %d",
                tostring(base.weatherMode),tonumber(base.weatherIntensity) or 1,
                tonumber(base.weatherPhysicsMeasuredHz) or 0,
                tonumber(base.weatherDroppedPhysicsTime) or 0,
                tonumber(base.weatherWetCells) or 0,tonumber(base.weatherSnowCells) or 0,
                tonumber(ctx.Stats.BodyDrops) or 0,tonumber(ctx.Stats.BodyImpacts) or 0)
        elseif activePage=="VISUALS" then
            for key,b in pairs(flagButtons) do
                b.Text=key.."  /  "..(ctx.Options[key] and "ON" or "OFF")
            end
        end
    end)
    return {Name="Custom black UI",Stop=function()
        if legacy and legacy.Parent then legacy.Enabled=true end
    end}
end