-- roblox_modPack v5.3 / body.lua
-- First-person arms and equipped weapon ONLY. No torso/head/legs/world avatars.
-- Small cosmetic beads obey local gravity; none are physics colliders.
return function(ctx)
    local Players,W=ctx.Players,ctx.Workspace
    local player=Players.LocalPlayer
    local rng=Random.new()
    local function rnd(a,b)return rng:NextNumber(a,b)end
    local contacts, pool = {}, {}
    local tScan,tEmit=0,0
    local impacts=0
    local limit=40
    local function lower(p) return string.lower(p.Name or "") end
    local function allowedArm(p)
        if not p:IsA("BasePart") then return false end
        local n=lower(p):gsub("[ _%-]","")
        return n=="lefthand" or n=="righthand"
            or n=="leftarm" or n=="rightarm"
            or n=="leftlowerarm" or n=="rightlowerarm"
            or n=="leftupperarm" or n=="rightupperarm"
            or n=="leftforearm" or n=="rightforearm"
    end
    local function isWeaponName(p)
        local n=lower(p):gsub("[ _%-]","")
        return n=="handle" or n=="barrel" or n=="scope" or n=="receiver"
            or n=="magazine" or n=="weapon" or n=="gun" or n=="muzzle"
            or n=="gunbody"
    end
    local function make()
        local p=Instance.new("Part")
        p.Name="RM53_WeaponWater"
        p.Shape=Enum.PartType.Ball;p.Anchored=true
        p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
        p.Material=Enum.Material.Glass
        p.Color=Color3.fromRGB(190,205,215)
        p.Reflectance=.06;p.Transparency=1
        p.Size=Vector3.new(.02,.02,.02)
        p.Parent=ctx.Folder;ctx.Track(p)
        return {part=p,life=0,host=nil,localPos=Vector3.zero,
            worldPos=Vector3.zero,vel=Vector3.zero,mode="OFF",size=.03,ttl=0}
    end
    for i=1,limit do pool[i]=make()end
    local function retire(d)
        d.life=0;d.host=nil;d.part.Transparency=1
    end
    local function visibleArmAndWeapon()
        local cam=W.CurrentCamera
        local char=player and player.Character
        if not cam or not char then return {} end
        local result,seen={},{}
        local function add(p)
            if not p or seen[p] or not p:IsA("BasePart")
                or p.Transparency>.92 or p.LocalTransparencyModifier>.85 then return end
            if (p.Position-cam.CFrame.Position).Magnitude>10 then return end
            local v,onScreen=cam:WorldToViewportPoint(p.Position)
            if not onScreen or v.Z<=0 then return end
            seen[p]=true;result[#result+1]=p
        end
        -- True first-person viewmodel models parented to CurrentCamera.
        for _,node in ipairs(cam:GetChildren()) do
            local name=lower(node)
            if node:IsA("Model") and
                (name:find("view",1,true) or name:find("arm",1,true)
                or name:find("weapon",1,true) or name:find("gun",1,true)) then
                local count=0
                for _,p in ipairs(node:GetDescendants()) do
                    if allowedArm(p) or isWeaponName(p) then add(p) end
                    count+=1
                    if count>250 or #result>=14 then break end
                end
            elseif node:IsA("BasePart") and (allowedArm(node) or isWeaponName(node)) then
                add(node)
            end
        end
        -- Equipped tool only, never a weapon or character belonging to another player.
        local tool=char:FindFirstChildOfClass("Tool")
        if tool then
            for _,p in ipairs(tool:GetDescendants()) do
                if isWeaponName(p) then add(p) end
                if #result>=16 then break end
            end
        end
        -- Fallback: first-person arms. Never torso, face, hat, legs, other players.
        local head=char:FindFirstChild("Head")
        local firstPerson=head and (cam.CFrame.Position-head.Position).Magnitude<2.25
        if firstPerson then
            for _,p in ipairs(char:GetChildren()) do
                if allowedArm(p) then add(p) end
            end
        end
        return result
    end
    local function emit(mode)
        if #contacts==0 then return end
        local d
        for _,x in ipairs(pool) do
            if x.life<=0 then d=x;break end
        end
        if not d then return end
        local host=contacts[rng:NextInteger(1,#contacts)]
        if not host or not host.Parent then return end
        local s=host.Size
        d.host=host
        d.localPos=Vector3.new(rnd(-.36,.36)*s.X,.44*s.Y,rnd(-.36,.36)*s.Z)
        d.vel=Vector3.zero
        d.mode=mode
        d.life=(mode=="RAIN") and rnd(.18,.60) or rnd(.55,1.5)
        d.size=(mode=="RAIN") and rnd(.015,.034) or rnd(.026,.049)
        d.part.Size=Vector3.new(d.size,d.size,d.size)
        d.part.Material=(mode=="RAIN") and Enum.Material.Glass or Enum.Material.SmoothPlastic
        d.part.Color=(mode=="RAIN") and Color3.fromRGB(185,201,213)
            or Color3.fromRGB(242,245,248)
        d.part.Transparency=(mode=="RAIN") and .48 or .32
        d.part.CFrame=CFrame.new(host.CFrame:PointToWorldSpace(d.localPos))
    end
    local rayParams=RaycastParams.new()
    rayParams.FilterType=Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater=false
    ctx.AddStep(function(dt,visual)
        local mode=(ctx.Base.enabled and ctx.Base.weatherMode) or "OFF"
        if mode=="OFF" then
            for _,d in ipairs(pool) do
                if d.life>0 then retire(d) end
            end
            ctx.Stats.BodyDrops=0
            return
        end
        tScan+=dt;tEmit+=dt
        if tScan>.40 then
            tScan=0;contacts=visibleArmAndWeapon()
            local char=player.Character
            rayParams.FilterDescendantsInstances={ctx.Folder,char}
        end
        local rate=mode=="RAIN" and 12 or 7
        local strength=math.clamp(tonumber(ctx.Base.weatherIntensity) or .65,.01,1)
        if tEmit>1/rate then
            tEmit-=1/rate
            if rng:NextNumber()<strength and #contacts>0 then emit(mode) end
        end
        local active=0
        for _,d in ipairs(pool) do
            if d.life>0 then
                d.life-=dt
                if d.host and d.host.Parent then
                    local host=d.host
                    local localG=host.CFrame:VectorToObjectSpace(Vector3.new(0,-1,0))
                    d.vel=(d.vel+localG*(mode=="RAIN" and 24 or 1.8)*dt)
                        *(1-math.min(.7,dt*2.8))
                    d.localPos+=d.vel*dt
                    local half=host.Size*.51
                    local over=math.abs(d.localPos.X)>half.X
                        or math.abs(d.localPos.Y)>half.Y
                        or math.abs(d.localPos.Z)>half.Z
                    local fast=host.AssemblyLinearVelocity.Magnitude>45
                    if over or fast or d.life<=0 then
                        d.worldPos=host.CFrame:PointToWorldSpace(d.localPos)
                        d.vel=host.AssemblyLinearVelocity*.35
                            +Vector3.new(rnd(-1,1),-rnd(1,3),rnd(-1,1))
                        d.host=nil;d.life=math.max(.10,d.life)
                    elseif visual then
                        d.part.CFrame=CFrame.new(host.CFrame:PointToWorldSpace(d.localPos))
                    end
                else
                    local previous=d.worldPos
                    d.vel+=Vector3.new(0,-W.Gravity,0)*dt
                    d.worldPos+=d.vel*dt
                    local hit=W:Raycast(previous,d.worldPos-previous,rayParams)
                    if hit then
                        impacts+=1
                        if type(ctx.OnBodyWaterHit)=="function" then
                            pcall(ctx.OnBodyWaterHit,hit.Position,hit.Normal)
                        end
                        retire(d)
                    elseif visual then
                        d.part.CFrame=CFrame.new(d.worldPos)
                        d.part.Transparency=math.min(.95,d.part.Transparency+dt*1.6)
                    end
                end
                if d.life<=0 then retire(d) else active+=1 end
            end
        end
        ctx.Stats.BodyDrops=active
        ctx.Stats.BodyImpacts=impacts
        ctx.Stats.WetSurfaces=#contacts
    end)
    return {Name="First-person arms and weapon only", Stop=function()
        for _,d in ipairs(pool) do retire(d) end
    end}
end