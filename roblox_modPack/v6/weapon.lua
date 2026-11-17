-- roblox_modPack v6 / weapon_finish.lua
-- First-person weapon graphics, never weapon accuracy/recoil/damage or server objects.
return function(ctx)
    local player=ctx.Players.LocalPlayer
    local W,L=ctx.Workspace,ctx.Lighting
    local originals,monitored={},{}
    local elapsed=0
    local total=0
    local function lower(v)return string.lower(tostring(v or ""))end
    local function set(part,property,value)
        local saved=originals[part]
        if not saved then saved={};originals[part]=saved end
        if saved[property]==nil then
            local ok,old=pcall(function()return part[property]end)
            if not ok then return end
            saved[property]=old
        end
        pcall(function()part[property]=value end)
    end
    local function restore()
        for part,values in pairs(originals) do
            for prop,value in pairs(values) do
                pcall(function()part[prop]=value end)
            end
        end
        table.clear(originals);table.clear(monitored)
    end
    local function looksLikeGunPart(part)
        if not part or not part:IsA("BasePart") or part.Transparency>.65 then
            return false
        end
        local n=lower(part.Name)
        return n:find("barrel",1,true) or n:find("scope",1,true)
            or n:find("receiver",1,true) or n:find("mag",1,true)
            or n:find("sight",1,true) or n:find("muzzle",1,true)
            or n:find("weapon",1,true) or n:find("handle",1,true)
            or n:find("bolt",1,true) or n:find("rail",1,true)
    end
    local function process(part)
        if monitored[part] or total>=58 or not looksLikeGunPart(part) then return end
        if part:FindFirstChildOfClass("SurfaceAppearance") then
            -- Preserve custom PBR and its roughness maps if developer supplied them.
            return
        end
        local camera=W.CurrentCamera
        if camera and (camera.CFrame.Position-part.Position).Magnitude>13 then return end
        monitored[part]=true;total+=1
        local n=lower(part.Name)
        local lens=n:find("lens",1,true) or n:find("optic",1,true)
        local metal=n:find("barrel",1,true) or n:find("scope",1,true)
            or n:find("bolt",1,true) or n:find("muzzle",1,true)
            or n:find("rail",1,true)
        if lens then
            set(part,"Material",Enum.Material.Glass)
            set(part,"Reflectance",.10)
        elseif metal then
            set(part,"Material",Enum.Material.Metal)
            set(part,"Reflectance",.12)
        else
            -- Handle/receiver may be colored polymer, not metal.
            set(part,"Reflectance",ctx.Base.weatherMode=="RAIN" and .105 or .052)
        end
    end
    local function scan()
        if not ctx.Base.enabled or not ctx.Options.WeaponFinish then
            if next(originals) then restore() end
            return
        end
        local camera=W.CurrentCamera
        local char=player.Character
        if not camera or not char then return end
        local tool=char:FindFirstChildOfClass("Tool")
        if tool then
            for _,desc in ipairs(tool:GetDescendants()) do
                if looksLikeGunPart(desc) then process(desc) end
            end
        end
        for _,node in ipairs(camera:GetChildren()) do
            if node:IsA("Model") then
                local n=lower(node.Name)
                if n:find("view",1,true) or n:find("weapon",1,true)
                    or n:find("gun",1,true) or n:find("arms",1,true) then
                    for _,p in ipairs(node:GetDescendants()) do
                        if looksLikeGunPart(p) then process(p) end
                    end
                end
            end
        end
        ctx.Stats.WeaponFinishes=total
    end
    ctx.AddStep(function(dt)
        elapsed+=dt
        if elapsed>.85 then
            elapsed=0
            scan()
        end
    end)
    ctx.AddStop(restore)
    return {Name="Subtle reflective weapon finishes"}
end