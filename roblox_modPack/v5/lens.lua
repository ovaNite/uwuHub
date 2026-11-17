-- roblox_modPack v5.3 / lens.lua
-- Subtle water on a first-person camera lens. Purely local 2D optics.
-- No solid-white blobs, no blocking the crosshair and no viewmodel clipping.
return function(ctx)
    local player=ctx.Players.LocalPlayer
    local gui=player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui",10)
    if not gui then return {Name="Camera lens disabled"} end
    local lens=Instance.new("ScreenGui")
    lens.Name="RM53_CameraLens"
    lens.ResetOnSpawn=false;lens.IgnoreGuiInset=true
    lens.DisplayOrder=100
    lens.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    lens.Parent=gui;ctx.Track(lens)
    pcall(function() lens.ScreenInsets=Enum.ScreenInsets.None end)
    local rng=Random.new()
    local function rnd(a,b)return rng:NextNumber(a,b)end
    local drops={}
    local count=20
    local function create(index)
        local group=Instance.new("Frame")
        group.Name="LensDroplet_"..index
        group.BackgroundTransparency=1
        group.Size=UDim2.fromOffset(7,11)
        group.AnchorPoint=Vector2.new(.5,.5)
        group.Visible=false
        group.ZIndex=10
        group.Parent=lens
        local base=Instance.new("Frame")
        base.Name="Water"
        base.Size=UDim2.fromScale(1,1)
        base.BackgroundColor3=Color3.fromRGB(208,223,235)
        base.BackgroundTransparency=.79
        base.BorderSizePixel=0;base.ZIndex=11
        base.Parent=group
        Instance.new("UICorner",base).CornerRadius=UDim.new(1,0)
        local grad=Instance.new("UIGradient")
        grad.Transparency=NumberSequence.new({
            NumberSequenceKeypoint.new(0,.97),
            NumberSequenceKeypoint.new(.28,.91),
            NumberSequenceKeypoint.new(.69,.75),
            NumberSequenceKeypoint.new(1,.96)
        })
        grad.Rotation=27
        pcall(function()grad.Type=Enum.GradientType.Radial end)
        grad.Parent=base
        local outline=Instance.new("UIStroke")
        outline.Color=Color3.fromRGB(233,241,246)
        outline.Thickness=.65;outline.Transparency=.83
        outline.Parent=base
        local gloss=Instance.new("Frame")
        gloss.Name="Glint";gloss.BackgroundColor3=Color3.fromRGB(247,250,252)
        gloss.BackgroundTransparency=.60;gloss.BorderSizePixel=0
        gloss.Size=UDim2.fromScale(.16,.17)
        gloss.Position=UDim2.fromScale(.24,.14)
        gloss.ZIndex=12;gloss.Parent=group
        Instance.new("UICorner",gloss).CornerRadius=UDim.new(1,0)
        return {root=group,base=base,gloss=gloss,life=0,
            x=0,y=0,dy=0,drift=0,width=6,height=9,maxLife=1}
    end
    for i=1,count do drops[i]=create(i) end
    local canRain=true
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater=true
    local roofTimer=0
    local emitTimer=0
    local function emit()
        local slot
        for _,d in ipairs(drops) do if d.life<=0 then slot=d;break end end
        if not slot then return end
        -- HUD center exclusion: do not obscure crosshair or weapon sight.
        local x,y
        for _=1,8 do
            x=rnd(.055,.945);y=rnd(.08,.87)
            if (x-.5)^2/(.19^2)+(y-.49)^2/(.18^2)>1 then break end
        end
        if not x then return end
        slot.x=x;slot.y=y
        slot.width=rnd(3.3,7.5)
        slot.height=slot.width*rnd(1.2,1.85)
        slot.life=rnd(.55,1.45)
        slot.maxLife=slot.life
        slot.dy=rnd(.024,.055)
        slot.drift=rnd(-.008,.008)
        slot.root.Size=UDim2.fromOffset(slot.width,slot.height)
        slot.root.Visible=true
        slot.base.BackgroundTransparency=.80
        slot.gloss.BackgroundTransparency=.67
    end
    ctx.Options.CameraWet=true
    local renderAccum=0
    ctx.AddRender(function(dt)
        local mode=(ctx.Base.enabled and ctx.Base.weatherMode) or "OFF"
        local active=mode=="RAIN" and ctx.Options.CameraWet~=false
        if not active then
            for _,d in ipairs(drops) do d.life=0;d.root.Visible=false end
            return
        end
        local camera=ctx.Workspace.CurrentCamera
        if not camera then return end
        roofTimer+=dt
        if roofTimer>.65 then
            roofTimer=0
            rayParams.FilterDescendantsInstances={ctx.Folder,player.Character}
            canRain=ctx.Workspace:Raycast(camera.CFrame.Position+Vector3.yAxis*.4,
                Vector3.new(0,80,0),rayParams)==nil
        end
        renderAccum+=dt
        if canRain then
            emitTimer+=dt
            local strength=math.clamp(tonumber(ctx.Base.weatherIntensity) or .65,.01,1)
            local interval=math.max(.19,.95-.54*strength)
            while emitTimer>=interval do
                emitTimer-=interval
                if rng:NextNumber()<strength then emit() end
            end
        end
        if renderAccum<1/60 then return end
        local dtime=math.min(renderAccum,.08)
        renderAccum=0
        local activeCount=0
        for _,d in ipairs(drops) do
            if d.life>0 then
                d.life-=dtime
                d.dy=math.min(.19,d.dy+dtime*.078)
                d.y+=d.dy*dtime
                d.x+=d.drift*dtime
                if d.life<=0 or d.y>.96 then
                    d.root.Visible=false;d.life=0
                else
                    activeCount+=1
                    d.root.Position=UDim2.fromScale(d.x,d.y)
                    local fade=math.clamp(d.life/.36,0,1)
                    d.base.BackgroundTransparency=.93-.14*fade
                    d.gloss.BackgroundTransparency=.97-.35*fade
                    d.root.Rotation=math.clamp(d.drift*380,-9,9)
                end
            end
        end
        ctx.Stats.LensDroplets=activeCount
    end)
    return {Name="Subtle camera rain"}
end