-- roblox_modPack v5 / worldfx.lua
-- Reversible local postprocessing, existing fire light, limited foliage motion.
-- No projectile manipulation, no custom shader injection, no hitbox changes.
return function(ctx)
    local W,L=ctx.Workspace,ctx.Lighting
    local fireSources,foliage,originals={}, {}, {}
    local fireMax,foliageMax=18,55
    local timer,scanCount,clock=0,0,0
    local scope=Instance.new("DepthOfFieldEffect")
    scope.Name="RM5_OpticalFocus"
    scope.Enabled=false;scope.FocusDistance=95;scope.InFocusRadius=80
    scope.FarIntensity=.055;scope.NearIntensity=.035;scope.Parent=L
    ctx.Track(scope)
    local function put(p,property,value)
        if not originals[p] then originals[p]={} end
        if originals[p][property] == nil then
            local ok,v=pcall(function() return p[property] end)
            if ok then originals[p][property]=v end
        end
        pcall(function() p[property]=value end)
    end
    local function isFireLike(o)
        if not o:IsA("ParticleEmitter") and not o:IsA("Fire") then return false end
        local n=string.lower(o.Name.." "..(o.Parent and o.Parent.Name or ""))
        return n:find("fire",1,true) or n:find("flame",1,true)
            or n:find("molotov",1,true) or n:find("burn",1,true)
            or n:find("muzzle",1,true) or n:find("exo",1,true)
    end
    local function discover(o)
        if #fireSources<fireMax and isFireLike(o) then
            local host=o.Parent
            if host and host:IsA("Attachment") then host=host.Parent end
            if host and host:IsA("BasePart") and not host:IsDescendantOf(ctx.Folder) then
                local point=Instance.new("PointLight")
                point.Name="RM5_TemperatureLight"
                point.Color=Color3.fromRGB(255,174,98)
                point.Shadows=true;point.Range=math.clamp(host.Size.Magnitude*2.5,8,20)
                point.Brightness=0
                point.Parent=host
                ctx.Track(point)
                fireSources[#fireSources+1]={emitter=o,light=point,phase=math.random()*7}
                if o:IsA("ParticleEmitter") then
                    -- Preserve original emitters: tune environmental response only.
                    put(o,"LightInfluence",.25)
                    put(o,"LightEmission",.32)
                end
            end
        end
        if #foliage<foliageMax and o:IsA("BasePart")
            and o.Anchored and not o.CanCollide and o.Size.Magnitude<24 then
            local n=string.lower(o.Name)
            if n:find("leaf",1,true) or n:find("foliage",1,true)
                or n:find("leaves",1,true) then
                foliage[#foliage+1]={part=o,at=o.CFrame,offset=math.random()*6.283}
            end
        end
    end
    task.spawn(function()
        local ok,desc=pcall(function() return W:GetDescendants() end)
        if not ok then return end
        for i,o in ipairs(desc) do
            if not ctx.Active then break end
            discover(o)
            if i%260==0 then task.wait() end
            if #fireSources>=fireMax and #foliage>=foliageMax then break end
        end
        ctx.Stats.FireSources=#fireSources
        ctx.Stats.FoliageParts=#foliage
    end)
    ctx.Link(W.DescendantAdded,function(o)
        if ctx.Active and (#fireSources<fireMax or #foliage<foliageMax) then
            task.defer(function() if ctx.Active then discover(o) end end)
        end
    end)
    ctx.AddRender(function(dt)
        if not ctx.Base.enabled then
            scope.Enabled=false
            for _,f in ipairs(fireSources) do if f.light then f.light.Brightness=0 end end
            return
        end
        clock+=dt; timer+=dt
        if timer>.075 then
            timer=0
            if ctx.Options.Fire then
                for _,f in ipairs(fireSources) do
                    if f.light.Parent and f.emitter.Parent then
                        -- Flackernde Lichtquelle auf Grundlage zweier Bandfrequenzen.
                        local variation=math.sin(clock*9+f.phase)*.12
                            +math.sin(clock*18.4+f.phase*2)*.07
                        f.light.Brightness=math.max(0,1.15+variation)
                    end
                end
            else
                for _,f in ipairs(fireSources) do
                    if f.light.Parent then f.light.Brightness=0 end
                end
            end
        end
        if ctx.Options.Foliage then
            local camera=W.CurrentCamera
            local cameraPos=camera and camera.CFrame.Position
            local wind=Vector3.zero
            pcall(function() wind=W.GlobalWind end)
            local force=math.clamp(wind.Magnitude/25,.1,.95)
            for _,leaf in ipairs(foliage) do
                local p=leaf.part
                if p.Parent and cameraPos and (p.Position-cameraPos).Magnitude<115 then
                    -- Animate foliage very gently; no collision or structural physics.
                    local v=math.sin(clock*(1.1+force)+leaf.offset)
                    local theta=v*(.006+force*.013)
                    p.CFrame=leaf.at*CFrame.Angles(theta,0,theta*.42)
                end
            end
        end
        local camera=W.CurrentCamera
        if camera and ctx.Options.Scope and camera.FieldOfView<52 then
            local char=ctx.Players.LocalPlayer and ctx.Players.LocalPlayer.Character
            local tool=char and char:FindFirstChildOfClass("Tool")
            local n=tool and string.lower(tool.Name) or ""
            local scopeTool=n:find("snip",1,true) or n:find("rifle",1,true)
                or n:find("scope",1,true) or n:find("marks",1,true)
            scope.Enabled=(scopeTool and true or false)
        else
            scope.Enabled=false
        end
        ctx.Stats.ScopeOptics=scope.Enabled and 1 or 0
    end)
    ctx.AddStop(function()
        scope.Enabled=false
        for _,leaf in ipairs(foliage) do
            if leaf.part and leaf.part.Parent then
                pcall(function() leaf.part.CFrame=leaf.at end)
            end
        end
        for inst,props in pairs(originals) do
            for prop,value in pairs(props) do
                pcall(function() inst[prop]=value end)
            end
        end
    end)
    return {Name="Environmental illumination"}
end