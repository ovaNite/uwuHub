-- NovaX: dynamic, LOCAL ONLY cosmetic catalogue and first-person preview.
-- Does NOT grant inventory, purchases, network entitlements or server ownership.
-- Reads live CosmeticLibrary rather than copying a possibly incomplete list.
return function(env)
  local Players=game:GetService("Players")
  local ReplicatedStorage=game:GetService("ReplicatedStorage")
  local Workspace=game:GetService("Workspace")
  local RunService=game:GetService("RunService")
  local player=Players.LocalPlayer
  local ui=assert(env.NX_UI_WINDOW,"NovaX UI unavailable")
  local state=assert(env.NX_STATE,"NX_STATE unavailable")
  local defaults={NovaXCosmeticPreview=false,NovaXCosmeticCategory="Skins",
    NovaXCosmeticPage=1,NovaXCosmeticSelection="",NovaXCosmeticWrapName="",
    NovaXCosmeticCharmName=""}
  for k,v in pairs(defaults) do if type(state[k])~=type(v) then state[k]=v end end
  local alive=true
  local categories={"Skins","Wraps","Charms","Finishers","Emotes","Other"}
  local categoryNames={skin="Skins",wrap="Wraps",charm="Charms",
    finisher="Finishers",emote="Emotes"}
  local catalog,byName,assetFolders={}, {}, {}
  local selectedLabels={}
  local pageSize=36
  local applied=setmetatable({}, {__mode="k"})
  local added={}
  local visibleCharm=nil
  local visualsRig=nil
  local nextScan=0
  local status="Awaiting CosmeticLibrary"
  local ref={}
  local function choose(v) return type(v)=="table" and tostring(v[1]) or tostring(v) end
  local function resolveAssets()
    local scripts=player:FindFirstChild("PlayerScripts")
    local base=scripts and scripts:FindFirstChild("Assets")
    if not base then return end
    assetFolders={
      Wraps=base:FindFirstChild("WrapTextures"),
      Charms=base:FindFirstChild("Charms"),
      Skins=base:FindFirstChild("ViewModels"),
    }
  end
  local function loadCatalog()
    resolveAssets()
    local modules=ReplicatedStorage:FindFirstChild("Modules")
    local source=modules and modules:FindFirstChild("CosmeticLibrary")
    if not source or not source:IsA("ModuleScript") then
      status="CosmeticLibrary missing";return false
    end
    local ok,library=pcall(require,source)
    local all=ok and type(library)=="table" and library.Cosmetics or nil
    if type(all)~="table" then status="CosmeticLibrary.Cosmetics unavailable";return false end
    local lists={},{}
    for _,category in ipairs(categories) do lists[category]={} end
    local lookup={}
    for name,entry in pairs(all) do
      if type(name)=="string" and type(entry)=="table" then
        local kind=tostring(rawget(entry,"Type") or "")
        local category=categoryNames[string.lower(kind)] or "Other"
        local obj={name=name,type=kind,category=category,
          weapon=tostring(rawget(entry,"ItemName") or ""),
          rarity=tostring(rawget(entry,"Rarity") or "Unknown"),
          image=rawget(entry,"Image")}
        table.insert(lists[category],obj)
        lookup[category..":"..name]=obj
      end
    end
    for _,list in pairs(lists) do
      table.sort(list,function(a,b)return a.name:lower()<b.name:lower()end)
    end
    catalog,byName=lists,lookup
    local total=0
    for _,list in pairs(lists) do total+=#list end
    status="Catalogue: "..total.." cosmetics loaded"
    return true
  end
  local function sourceTexture(asset)
    if not asset then return nil end
    local function read(node)
      if node:IsA("Decal") or node:IsA("Texture") then
        return node.Texture
      elseif node:IsA("ImageLabel") or node:IsA("ImageButton") then
        return node.Image
      elseif node:IsA("StringValue") then
        local v=node.Value
        if v:find("rbxasset",1,true) or v:match("^%d+$") then return v end
      end
      return nil
    end
    local direct=read(asset)
    if direct and direct~="" then return direct end
    for _,node in ipairs(asset:GetDescendants()) do
      local texture=read(node)
      if texture and texture~="" then return texture end
    end
    return nil
  end
  local function findAsset(category,name)
    local folder=assetFolders[category]
    if not folder or not name or name=="" then return nil end
    local direct=folder:FindFirstChild(name,true)
    if direct then return direct end
    local query=string.lower(name)
    for _,obj in ipairs(folder:GetDescendants()) do
      if string.lower(obj.Name)==query then return obj end
    end
    return nil
  end
  local function rigVisual()
    local container=Workspace:FindFirstChild("ViewModels")
    local first=container and container:FindFirstChild("FirstPerson")
    if not first then return nil end
    local prefix=player.Name.." - "
    for _,obj in ipairs(first:GetChildren()) do
      if obj:IsA("Model") and obj.Name:sub(1,#prefix)==prefix then
        local visual=obj:FindFirstChild("ItemVisual")
        if visual then return visual end
      end
    end
    return nil
  end
  local function restore()
    for part,original in pairs(applied) do
      if part and part.Parent and part:IsA("MeshPart") then
        pcall(function()
          if part.TextureID==original.assigned then
            part.TextureID=original.before
          end
        end)
      end
      applied[part]=nil
    end
    for _,dec in ipairs(added) do pcall(function()dec:Destroy()end) end
    table.clear(added)
    if visibleCharm then pcall(function()visibleCharm:Destroy()end);visibleCharm=nil end
    visualsRig=nil
  end
  local function applyWrapToRig(visual)
    local name=tostring(state.NovaXCosmeticWrapName or "")
    local entry=byName["Wraps:"..name]
    if not entry then status="Choose a wrap from catalogue";return end
    local asset=findAsset("Wraps",name)
    local texture=sourceTexture(asset)
    if not texture or texture=="" then
      status="Wrap found, but no compatible image texture: "..name;return
    end
    local count=0
    for _,part in ipairs(visual:GetDescendants()) do
      if part:IsA("MeshPart") then
        local ok,before=pcall(function() return part.TextureID end)
        if ok then
          applied[part]={before=before,assigned=texture}
          pcall(function() part.TextureID=texture end)
          count+=1
        end
      elseif part:IsA("Part") then
        local decal=Instance.new("Texture")
        decal.Name="NovaX_Local_WrapPreview"
        decal.Texture=texture
        decal.StudsPerTileU=3
        decal.StudsPerTileV=3
        decal.Face=Enum.NormalId.Front
        decal.Parent=part
        added[#added+1]=decal
        count+=1
      end
    end
    status=string.format("Local wrap preview: %s on %d parts",name,count)
  end
  local function applyCharmToRig(visual)
    local name=tostring(state.NovaXCosmeticCharmName or "")
    if not byName["Charms:"..name] then return end
    local asset=findAsset("Charms",name)
    if not asset then status="Charm model not available locally: "..name;return end
    local ok,clone=pcall(function()return asset:Clone()end)
    if not ok or not clone then return end
    for _,obj in ipairs(clone:GetDescendants()) do
      if obj:IsA("LuaSourceContainer") or obj:IsA("JointInstance") or obj:IsA("Constraint") then
        obj:Destroy()
      elseif obj:IsA("BasePart") then
        obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false
      end
    end
    clone.Name="NovaX_LocalCharmPreview"
    clone.Parent=Workspace.CurrentCamera or Workspace
    visibleCharm=clone
  end
  local function positionCharm()
    if not visibleCharm or not visualsRig or not visualsRig.Parent then return end
    local anchor=visualsRig:FindFirstChildWhichIsA("BasePart",true)
    if not anchor then return end
    local at=anchor.CFrame*CFrame.new(0.2,-0.32,0.12)
    if visibleCharm:IsA("Model") then
      pcall(function()visibleCharm:PivotTo(at)end)
    elseif visibleCharm:IsA("BasePart") then
      visibleCharm.CFrame=at
    end
  end
  local function refresh()
    local category=state.NovaXCosmeticCategory
    if not catalog[category] then category="Skins";state.NovaXCosmeticCategory=category end
    local list=catalog[category] or {}
    local pages=math.max(1,math.ceil(#list/pageSize))
    local page=math.clamp(math.floor(tonumber(state.NovaXCosmeticPage) or 1),1,pages)
    state.NovaXCosmeticPage=page
    selectedLabels={}
    local options={}
    for i=(page-1)*pageSize+1,math.min(#list,page*pageSize) do
      local obj=list[i]
      local label=string.format("%s | %s",obj.name,obj.rarity)
      selectedLabels[label]=obj
      options[#options+1]=label
    end
    if #options==0 then options={"No matching cosmetics"} end
    if ref.selector and ref.selector.Refresh then
      ref.selector:Refresh(options)
    end
    if ref.page and ref.page.Set then
      pcall(function()ref.page:Set(page)end)
    end
    status=string.format("%s: %d entries, page %d/%d (local preview)",
      category,#list,page,pages)
  end
  local function chooseCosmetic(entry)
    if not entry then return end
    state.NovaXCosmeticSelection=entry.name
    if entry.category=="Wraps" then
      state.NovaXCosmeticWrapName=entry.name
    elseif entry.category=="Charms" then
      state.NovaXCosmeticCharmName=entry.name
    elseif entry.category=="Skins" then
      if type(env.NovaXChooseSkin)=="function" and entry.weapon~="" then
        pcall(env.NovaXChooseSkin,entry.weapon,entry.name)
      end
    end
    if entry.category=="Wraps" or entry.category=="Charms" then
      restore()
      nextScan=0
    end
    if entry.category=="Finishers" or entry.category=="Emotes" or entry.category=="Other" then
      status=entry.name.." (catalogue preview only; not owned or equipped)"
    else
      status=entry.name.." selected for local preview"
    end
  end
  local tab=ui:CreateTab("All Cosmetics (Local)",4483345998)
  tab:CreateSection("Entire client catalogue")
  tab:CreateLabel("Local previews only. Game inventory and server ownership unchanged.")
  tab:CreateToggle({Name="Enable local cosmetic previews",
    CurrentValue=state.NovaXCosmeticPreview,
    Callback=function(v)
      state.NovaXCosmeticPreview=v==true
      restore();nextScan=0
    end})
  tab:CreateDropdown({Name="Category",Options=categories,
    CurrentOption={state.NovaXCosmeticCategory},
    Callback=function(value)
      state.NovaXCosmeticCategory=choose(value)
      state.NovaXCosmeticPage=1
      refresh()
    end})
  ref.page=tab:CreateSlider({Name="Catalogue page",Range={1,30},Increment=1,
    CurrentValue=state.NovaXCosmeticPage,
    Callback=function(value)state.NovaXCosmeticPage=value;refresh()end})
  ref.selector=tab:CreateDropdown({Name="Preview cosmetic",Options={"Load catalogue"},
    CurrentOption={"Load catalogue"},
    Callback=function(value)chooseCosmetic(selectedLabels[choose(value)])end})
  tab:CreateButton({Name="Rescan all cosmetics",Callback=function()
    if loadCatalog() then refresh() end
    print("[NovaX Cosmetic Preview] "..status)
  end})
  tab:CreateButton({Name="Catalogue status",Callback=function()
    print("[NovaX Cosmetic Preview] "..status)
    if ui.Notify then ui:Notify({Title="Cosmetic Preview",Content=status,Duration=6})end
  end})
  loadCatalog()
  refresh()
  local accumulator=0
  local connection=RunService.RenderStepped:Connect(function(dt)
    if not alive then return end
    accumulator+=dt
    if state.NovaXCosmeticPreview then positionCharm() end
    if accumulator<0.4 then return end
    accumulator=0
    if not state.NovaXCosmeticPreview then
      if visualsRig then restore() end
      return
    end
    local visual=rigVisual()
    if visual~=visualsRig or os.clock()>=nextScan then
      nextScan=os.clock()+6
      if visual~=visualsRig then
        restore();visualsRig=visual
        if visual then
          if state.NovaXCosmeticWrapName~="" then applyWrapToRig(visual) end
          if state.NovaXCosmeticCharmName~="" then applyCharmToRig(visual) end
        end
      end
      if not visual and not catalog.Skins then
        loadCatalog();refresh()
      end
    end
  end)
  return {
    ApplyState=function()
      if not alive then return end
      restore()
      state.NovaXCosmeticPage=math.clamp(tonumber(state.NovaXCosmeticPage) or 1,1,30)
      refresh()
      nextScan=0
    end,
    Stop=function()
      alive=false
      if connection then connection:Disconnect()end
      restore()
    end,
  }
end
