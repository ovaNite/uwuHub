-- roblox_modPack v7 / reflection_trace.lua
-- TRUE SCENE RAYS, NOT RTX: view ray -> wet floor -> reflected scene ray.
-- This local, sparse software reflection uses Workspace:Raycast. The display
-- uses blended low-resolution ground samples, NOT a GPU ray-traced render.
return function(ctx)
    local Workspace=ctx.Workspace
    local UserInput=ctx.UserInputService
    local Players=ctx.Players
    local LocalPlayer=Players.LocalPlayer
    local Randomizer=Random.new(70121)

    local CONFIG={
        maxDistance=85,
        bounceDistance=105,
        maxFloorSlope=0.84,
        maxSurfaceDistance=65,
        minimumFloorSize=7,
        rayBudgetPerFrame=12,
        sampleRefreshSeconds=.38,
        mediumWidth=16,
        mediumHeight=8,
    }
    local levels={
        {label="ECO",columns=10,rows=5,budget=7},
        {label="BALANCED",columns=16,rows=8,budget=12},
        {label="DETAIL",columns=22,rows=10,budget=19},
    }
    local setting=2
    local enabled=true
    local samples={}
    local maxSamples=levels[#levels].columns*levels[#levels].rows
    local index=0
    local frameCount=0
    local rayTotal=0
    local reflectedTotal=0
    local duration=.0
    local raysWindow=0
    local rayRate=0
    local hitsWindow=0
    local bouncedRate=0
    local sampleTime=0
    local lastCameraPosition=nil
    local floorMaterials={}
    for _,material in ipairs({Enum.Material.SmoothPlastic,Enum.Material.Plastic,
        Enum.Material.Concrete,Enum.Material.Asphalt,Enum.Material.Marble,
        Enum.Material.Slate,Enum.Material.Metal,Enum.Material.Glass,
        Enum.Material.Granite,Enum.Material.Brick,Enum.Material.Sandstone}) do
        floorMaterials[material]=true
    end
    local function safe(value,fallback)
        if typeof(value)=="number" then return value end
        return fallback
    end
    local function makeSample(i)
        local p=Instance.new("Part")
        p.Name="RM7_TraceSample_"..i
        p.Anchored=true;p.CanCollide=false;p.CanTouch=false
        p.CanQuery=false;p.CastShadow=false;p.Locked=true
        p.Size=Vector3.new(1,1,1)
        p.Material=Enum.Material.SmoothPlastic
        p.Color=Color3.fromRGB(170,185,195)
        p.Reflectance=.03
        p.Transparency=1
        p.CFrame=CFrame.new(0,-1e5,0)
        p.Parent=ctx.Folder
        ctx.Track(p)
        local mesh=Instance.new("SpecialMesh")
        mesh.MeshType=Enum.MeshType.Sphere
        mesh.Scale=Vector3.new(.5,.009,.5)
        mesh.Parent=p
        return {part=p,mesh=mesh,last=0,valid=false}
    end
    for i=1,maxSamples do samples[i]=makeSample(i) end

    local param=RaycastParams.new()
    param.FilterType=Enum.RaycastFilterType.Exclude
    param.IgnoreWater=false
    param.RespectCanCollide=false

    local function hide(sample)
        sample.valid=false
        sample.part.Transparency=1
    end
    local function reset()
        for _,sample in ipairs(samples) do hide(sample) end
    end

    local function isFloor(hit)
        if not hit or hit.Normal.Y<CONFIG.maxFloorSlope then return false end
        local part=hit.Instance
        if not part then return false end
        if part==Workspace.Terrain then return true end
        if not part:IsA("BasePart") or not part.Anchored then return false end
        if part.Transparency>.68 then return false end
        if part.Size.X+part.Size.Z<CONFIG.minimumFloorSize then return false end
        if part.Material==Enum.Material.Neon or part.Material==Enum.Material.ForceField then return false end
        return true
    end
    local function sourceColor(hit)
        if not hit or not hit.Instance then return nil,nil end
        local part=hit.Instance
        if part:IsA("BasePart") then
            if part.Transparency>.65 then return nil,nil end
            return part.Color,part.Material
        end
        if part==Workspace.Terrain then
            local ok,c=pcall(function()return part:GetMaterialColor(hit.Material)end)
            return (ok and c) or Color3.fromRGB(100,108,116),hit.Material
        end
        return nil,nil
    end
    local function opticsPlane(hit, incomingDirection)
        local normal=hit.Normal
        local reflected=incomingDirection-normal*(2*incomingDirection:Dot(normal))
        return reflected.Unit
    end
    local function basis(position,normal)
        local axis=math.abs(normal.X)<.90 and Vector3.xAxis or Vector3.zAxis
        local x=(axis-normal*axis:Dot(normal)).Unit
        local z=x:Cross(normal)
        return CFrame.fromMatrix(position,x,normal,z)
    end

    local function castSample(sample,cell,cam,quality,character)
        local cols=quality.columns
        local rows=quality.rows
        local cx=(cell-1)%cols
        local cy=math.floor((cell-1)/cols)
        -- Focus on the lower portion of the screen; these are samples of ground
        -- visible to the current camera, never a fake mirrored viewport image.
        local vx=(cx+.5)/cols
        local vy=.42+(.56*(cy+.5)/rows)
        local jitterX=Randomizer:NextNumber(-.25,.25)/cols
        local jitterY=Randomizer:NextNumber(-.18,.18)/rows
        local viewport=cam.ViewportSize
        local pixelX=(vx+jitterX)*viewport.X
        local pixelY=(vy+jitterY)*viewport.Y
        local ray=cam:ViewportPointToRay(pixelX,pixelY)
        local rayDir=ray.Direction.Unit
        local first=Workspace:Raycast(ray.Origin,rayDir*CONFIG.maxDistance,param)
        rayTotal+=1
        raysWindow+=1
        if not isFloor(first) or first.Distance>CONFIG.maxSurfaceDistance then
            hide(sample)
            return
        end
        -- Only render on rain-wet surfaces by default; do not hallucinate SSR
        -- on dry floors or on walls the camera cannot see.
        local p=first.Position
        local n=first.Normal
        local reflectedDir=opticsPlane(first,rayDir)
        -- A tiny deterministic roughness perturbation resembles wet concrete,
        -- while the reflection law still determines the main ray direction.
        local roughness=math.clamp(ctx.Options.ReflectionRoughness or .014,0,.055)
        local drift=Vector3.new(
            Randomizer:NextNumber(-roughness,roughness),
            0,
            Randomizer:NextNumber(-roughness,roughness))
        local bounceDir=(reflectedDir+drift).Unit
        local second=Workspace:Raycast(p+n*.04,bounceDir*CONFIG.bounceDistance,param)
        rayTotal+=1
        raysWindow+=1
        if not second then
            hide(sample)
            return
        end
        local color,material=sourceColor(second)
        if not color then hide(sample);return end
        reflectedTotal+=1
        hitsWindow+=1
        -- Fade with distance, Fresnel, and display only genuine second-ray hits.
        local cosV=math.clamp(math.abs(n:Dot(-rayDir)),0,1)
        local fresnel=.08+.92*(1-cosV)^5
        local distanceFade=math.clamp(1-first.Distance/CONFIG.maxSurfaceDistance,.05,1)
        local nearFade=math.clamp(1-second.Distance/CONFIG.bounceDistance,.1,1)
        local wetPower=math.clamp(ctx.Options.ReflectionPower or .72,.05,1)
        local strength=math.clamp((fresnel*.90+.27)*wetPower*
            (nearFade*.65+.35)*(distanceFade*.5+.5),.03,.70)
        -- A thin ellipse directly on the actual surface for proper 3D occlusion;
        -- its colour comes from the second hit, not a preselected blue shader.
        local sourceBoost=(material==Enum.Material.Neon and 1.25) or 1
        local floorTint=first.Instance:IsA("BasePart") and first.Instance.Color
            or Color3.fromRGB(45,49,54)
        local sampled=floorTint:Lerp(color,math.clamp(strength*sourceBoost*2.1,0,1))
        local footprint=math.clamp(first.Distance/cols*.38,.16,.82)
        local aspect=1.65
        sample.mesh.Scale=Vector3.new(footprint*aspect,.012,footprint*.8)
        sample.part.Color=sampled
        sample.part.CFrame=basis(p+n*.025,n)
        sample.part.Transparency=math.clamp(.80-strength*.72,.35,.87)
        sample.last=os.clock()
        sample.valid=true
    end

    ctx.Options.ReflectionsRaycast=true
    ctx.Options.ReflectionPower=.72
    ctx.Options.ReflectionRoughness=.014
    ctx.Stats.ReflectionQuality="BALANCED"
    local toast=nil
    local toastTime=0
    local function message(t)
        print("[RM7] "..t)
        if toast and toast.Parent then
            toast.Text=t
            toast.Visible=true
            toastTime=os.clock()
        end
    end
    local function newHud()
        local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        local screen=Instance.new("ScreenGui")
        screen.Name="RM7_ReflectionInfo"
        screen.ResetOnSpawn=false;screen.DisplayOrder=205
        screen.IgnoreGuiInset=false
        screen.Parent=pg;ctx.Track(screen)
        local label=Instance.new("TextLabel")
        label.Size=UDim2.fromOffset(260,24)
        label.Position=UDim2.new(.5,-130,1,-42)
        label.BackgroundColor3=Color3.fromRGB(18,22,25)
        label.BackgroundTransparency=.38
        label.TextColor3=Color3.fromRGB(214,223,231)
        label.Font=Enum.Font.GothamMedium
        label.TextSize=11
        label.Visible=false
        label.Text="REFLECTIONS"
        label.Parent=screen
        Instance.new("UICorner",label).CornerRadius=UDim.new(0,7)
        toast=label
    end
    pcall(newHud)
    ctx.Link(UserInput.InputBegan,function(input,processed)
        if processed then return end
        if input.KeyCode==Enum.KeyCode.F11 then
            enabled=not enabled
            ctx.Options.ReflectionsRaycast=enabled
            if not enabled then reset()end
            message("Geometric reflections: "..(enabled and "ON" or "OFF"))
        elseif input.KeyCode==Enum.KeyCode.F12 then
            setting=setting%#levels+1
            local q=levels[setting]
            ctx.Stats.ReflectionQuality=q.label
            index=0
            reset()
            message("Reflection quality: "..q.label)
        end
    end)

    local clock=0
    ctx.AddRender(function(dt)
        if not ctx.Active then return end
        local enabledNow=enabled and ctx.Base.enabled
            and ctx.Options.WorldFinish~=false
            and ctx.Options.ReflectionsRaycast~=false
            and ctx.Base.weatherMode=="RAIN"
        local cam=Workspace.CurrentCamera
        if toast and toast.Visible and os.clock()-toastTime>2.2 then toast.Visible=false end
        if not enabledNow or not cam then
            if clock>-.1 then
                reset()
                clock=-1
            end
            return
        end
        if clock<0 then clock=0 end
        local viewport=cam.ViewportSize
        if viewport.X<200 or viewport.Y<150 then return end
        local character=LocalPlayer.Character
        param.FilterDescendantsInstances={ctx.Folder,character,cam}
        local quality=levels[setting]
        local cells=quality.columns*quality.rows
        -- Sample at most this many rays per render frame. This is not 90Hz
        -- pixel shading: the existing WEATHER solver keeps its own 90Hz loop.
        local budget=quality.budget
        for _=1,budget do
            index=index%cells+1
            local sample=samples[index]
            local ok,err=pcall(castSample,sample,index,cam,quality,character)
            if not ok then
                hide(sample)
                ctx.Stats.ReflectionErrors=(ctx.Stats.ReflectionErrors or 0)+1
                if ctx.Stats.ReflectionErrors<=2 then
                    warn("[RM7] Ray sample error: "..tostring(err))
                end
            end
        end
        for i=cells+1,maxSamples do
            if samples[i].valid then hide(samples[i]) end
        end
        clock+=dt
        if clock>=1 then
            rayRate=raysWindow/clock
            bouncedRate=hitsWindow/clock
            raysWindow=0
            hitsWindow=0
            clock=0
            ctx.Stats.ReflectionRaysPerSec=rayRate
            ctx.Stats.ReflectionHitsPerSec=bouncedRate
            ctx.Stats.ReflectionQuality=quality.label
        end
    end)
    ctx.AddStop(function()
        reset()
        if toast and toast.Parent then toast:Destroy() end
    end)
    message("Reflections ready | F11 toggle | F12 quality | works with RAIN")
    return {Name="Geometrically raycast local reflections"}
end