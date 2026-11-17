-- roblox_modPack v5 / body.lua
-- Local character weather contact. Visual simulation only; never changes hitboxes.
return function(ctx)
    local Players, W, R = ctx.Players, ctx.Workspace, ctx.RunService
    local rng = Random.new()
    local pools, attached = {}, {}
    local character, humanoid, root
    local spawnClock, roofClock, gearClock = 0, 0, 0
    local outside, surfaceHits = true, 0
    local limit = 68

    local function rand(a,b) return rng:NextNumber(a,b) end
    local function hide(p)
        p.Transparency = 1
        p.CFrame = CFrame.new(0,-10000,0)
    end
    local function ray(a,d)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {ctx.Folder, character}
        params.IgnoreWater = false
        return W:Raycast(a,d,params)
    end
    local function newDot(i)
        local p=Instance.new("Part")
        p.Name="RM5_BodyDroplet_"..i; p.Anchored=true
        p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Shape=Enum.PartType.Ball;p.Material=Enum.Material.Glass
        p.Color=Color3.fromRGB(183,199,208)
        p.Reflectance=0.06;p.Size=Vector3.new(.065,.065,.065)
        hide(p);p.Parent=ctx.Folder;ctx.Track(p)
        return {p=p,life=0,mode="OFF",part=nil,pos=Vector3.zero,vel=Vector3.zero,alpha=0,scale=.06}
    end
    for i=1,limit do pools[i]=newDot(i) end

    local function limbList(model)
        local list={}
        if not model then return list end
        for _,name in ipairs({"LeftHand","RightHand","LeftLowerArm","RightLowerArm","LeftUpperArm","RightUpperArm","Left Arm","Right Arm","LeftFoot","RightFoot","Head","UpperTorso","Torso"}) do
            local p=model:FindFirstChild(name)
            if p and p:IsA("BasePart") then list[#list+1]=p end
        end
        return list
    end
    local function refresh()
        character=Players.LocalPlayer and Players.LocalPlayer.Character
        humanoid=character and character:FindFirstChildOfClass("Humanoid")
        root=character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
        attached=limbList(character)
        for _,item in ipairs(pools) do item.life=0;hide(item.p) end
    end
    refresh()
    if Players.LocalPlayer then ctx.Link(Players.LocalPlayer.CharacterAdded,function()
        task.defer(refresh)
    end) end

    local function release(d)
        d.part=nil;d.life=0;hide(d.p)
    end
    local function spawn(mode)
        if #attached==0 then return end
        local d
        for _,item in ipairs(pools) do if item.life<=0 then d=item;break end end
        if not d then return end
        local part=attached[rng:NextInteger(1,#attached)]
        if not part or not part.Parent then return end
        local top=part.Size.Y*.42
        local halfX=part.Size.X*.38
        local halfZ=part.Size.Z*.38
        d.pos=Vector3.new(rand(-halfX,halfX), top,rand(-halfZ,halfZ))
        d.part=part;d.mode=mode;d.life=mode=="RAIN" and rand(.25,1.5) or rand(1.8,8.5)
        d.alpha=0
        d.vel=Vector3.zero
        d.scale=mode=="RAIN" and rand(.025,.075) or rand(.06,.14)
        d.p.Material=mode=="RAIN" and Enum.Material.Glass or Enum.Material.Snow
        d.p.Color=mode=="RAIN" and Color3.fromRGB(186,201,207) or Color3.fromRGB(230,235,238)
        d.p.Reflectance=mode=="RAIN" and .10 or 0
        d.p.Size=Vector3.new(d.scale,d.scale,d.scale)
        d.p.Transparency=mode=="RAIN" and .18 or .07
        d.p.CFrame=CFrame.new(part.CFrame:PointToWorldSpace(d.pos))
    end
    local function detach(d)
        if d.mode=="SNOW" then release(d);return end
        local limb=d.part
        d.pos=limb.CFrame:PointToWorldSpace(d.pos)
        d.part=nil
        local motion=limb.AssemblyLinearVelocity
        d.vel=motion*.5 + Vector3.new(rand(-2,2),rand(-4,-1),rand(-2,2))
        d.life=.3
    end

    ctx.AddStep(function(dt,visual)
        local base=ctx.Base
        local mode=(base.enabled and base.weatherMode) or "OFF"
        if mode=="OFF" or not character or not character.Parent then
            for _,d in ipairs(pools) do if d.life>0 then release(d) end end
            return
        end
        gearClock+=dt
        if gearClock>.8 then
            gearClock=0
            attached=limbList(character)
            local tool=character and character:FindFirstChildOfClass("Tool")
            if tool then
                local h=tool:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then attached[#attached+1]=h end
            end
            local camera=W.CurrentCamera
            local vm=camera and (camera:FindFirstChild("Viewmodel") or camera:FindFirstChild("ViewModel"))
            if vm then
                for _,p in ipairs(vm:GetDescendants()) do
                    if p:IsA("BasePart") and (p.Name=="Handle" or p.Name=="Scope"
                        or p.Name=="Barrel" or p.Name=="Muzzle") then
                        attached[#attached+1]=p
                        if #attached>=20 then break end
                    end
                end
            end
        end
        roofClock+=dt
        if roofClock>.45 and root then
            roofClock=0
            outside=ray(root.Position+Vector3.new(0,2.5,0),Vector3.new(0,75,0))==nil
        end
        spawnClock+=dt
        if outside and spawnClock>=.035 then
            local count=math.min(4,math.floor(spawnClock/.035))
            spawnClock-=(count*.035)
            for _=1,count do
                if rand(0,1)<(mode=="RAIN" and .65 or .38)*base.weatherIntensity then spawn(mode) end
            end
        end
        local grav=W.Gravity
        local speed=root and root.AssemblyLinearVelocity.Magnitude or 0
        for _,d in ipairs(pools) do
            if d.life>0 then
                d.life-=dt
                if d.part and d.part.Parent then
                    local limb=d.part
                    if mode=="RAIN" then
                        -- Gravitation in den lokalen Raum des bewegten Arms transformieren.
                        local down=limb.CFrame:VectorToObjectSpace(Vector3.new(0,-1,0))
                        d.vel+=down*grav*.035*dt
                        d.vel=d.vel*(1-math.min(.9,dt*3.8))
                        d.pos+=d.vel*dt
                        local bounds=limb.Size*.52
                        if math.abs(d.pos.X)>bounds.X or math.abs(d.pos.Y)>bounds.Y or math.abs(d.pos.Z)>bounds.Z or speed>43 then
                            detach(d)
                        end
                    else
                        -- Flocken bleiben laenger sitzen; kleine Aggregate statt Schneehuellen.
                        d.scale=math.min(.20,d.scale+dt*.008)
                        if speed>38 or mode~="SNOW" then detach(d) end
                    end
                    if d.part and visual then
                        d.p.Size=Vector3.new(d.scale,d.scale,d.scale)
                        d.p.CFrame=CFrame.new(limb.CFrame:PointToWorldSpace(d.pos))
                    end
                elseif not d.part then
                    local old=d.pos
                    d.vel+=Vector3.new(0,-grav,0)*dt
                    d.pos+=d.vel*dt
                    -- Gesweepter Kontakt: kein Durchtunneln bei schnellen Tropfen.
                    local hit=ray(old,d.pos-old)
                    if hit then
                        surfaceHits+=1
                        if type(ctx.OnBodyWaterHit)=="function" then
                            pcall(ctx.OnBodyWaterHit,hit.Position,hit.Normal)
                        end
                        release(d)
                    elseif visual then d.p.CFrame=CFrame.new(d.pos) end
                else
                    release(d)
                end
                if d.life<=0 then release(d) end
            end
        end
        ctx.Stats.BodyImpacts=surfaceHits
        ctx.Stats.BodyDrops=(function()
            local n=0
            for _,d in ipairs(pools) do if d.life>0 then n+=1 end end
            return n
        end)()
    end)
    return {Name="Body contact",Stop=function()
        for _,d in ipairs(pools) do release(d) end
    end}
end