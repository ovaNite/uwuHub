-- NovaX v1.1 | SINGLE UNLOCK TAB
-- Shows everything present in RIVALS CosmeticLibrary in one place and exposes
-- the native Equipment UI. Never fabricates inventory or grants server ownership.
return function(env)
  local Players=game:GetService("Players")
  local ReplicatedStorage=game:GetService("ReplicatedStorage")
  local LocalPlayer=Players.LocalPlayer
  local ui=assert(env.NX_UI_WINDOW,"NovaX window unavailable")
  local state=assert(env.NX_STATE,"NovaX state unavailable")
  local active=true
  local categories={"All","Skins","Wraps","Charms","Finishers","Emotes","Other"}
  local perPage=40
  local catalog={}
  local selectedEntries={}
  local selected=nil
  local status="Catalogue not scanned yet"
  local controls={}
  local busy=false
  if type(state.NovaXUnlockCategory)~="string" then state.NovaXUnlockCategory="All" end
  if type(state.NovaXUnlockPage)~="number" then state.NovaXUnlockPage=1 end
  if type(state.NovaXUnlockSelection)~="string" then state.NovaXUnlockSelection="" end

  local function notify(title,message)
    print("[NovaX Unlock] "..tostring(message))
    if ui.Notify then pcall(function()
      ui:Notify({Title=title,Content=tostring(message),Duration=7})
    end) end
  end
  local function choice(value)
    return type(value)=="table" and tostring(value[1]) or tostring(value)
  end
  local function equipment()
    local pg=LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local main=pg and pg:FindFirstChild("MainGui")
    local frame=main and main:FindFirstChild("MainFrame")
    local equip=frame and frame:FindFirstChild("Equipment")
    return main,frame,equip
  end
  local function showEquipment()
    local main,frame,equip=equipment()
    if not equip or not equip:IsA("GuiObject") then
      notify("Unlock","RIVALS Equipment UI is currently unavailable")
      return false
    end
    local ok,err=pcall(function()
      if main:IsA("ScreenGui") then main.Enabled=true end
      if frame:IsA("GuiObject") then frame.Visible=true end
      equip.Visible=true
    end)
    if not ok then
      notify("Unlock","Unable to open RIVALS inventory: "..tostring(err))
    end
    return ok
  end
  local kindMap={
    skin="Skins",weaponskin="Skins",
    wrap="Wraps",wrapping="Wraps",weaponwrap="Wraps",weaponwrapping="Wraps",
    charm="Charms",weaponcharm="Charms",
    finisher="Finishers",finishingmove="Finishers",
    emote="Emotes",animation="Emotes",
  }
  local function scan()
    local modules=ReplicatedStorage:FindFirstChild("Modules")
    local source=modules and modules:FindFirstChild("CosmeticLibrary")
    if not source or not source:IsA("ModuleScript") then
      status="ReplicatedStorage.Modules.CosmeticLibrary is unavailable"
      return false
    end
    local ok,lib=pcall(require,source)
    local cosmetics=ok and type(lib)=="table" and rawget(lib,"Cosmetics") or nil
    if type(cosmetics)~="table" then
      status="CosmeticLibrary.Cosmetics could not be read"
      return false
    end
    local found={}
    for name,item in pairs(cosmetics) do
      if type(name)=="string" and type(item)=="table" then
        local rawKind=tostring(rawget(item,"Type") or "Other")
        local normalized=rawKind:lower():gsub("[^%a]","")
        found[#found+1]={
          name=name,
          category=kindMap[normalized] or "Other",
          rarity=tostring(rawget(item,"Rarity") or "Unknown"),
          weapon=tostring(rawget(item,"ItemName") or ""),
        }
      end
    end
    table.sort(found,function(a,b)
      if a.category~=b.category then return a.category<b.category end
      return a.name:lower()<b.name:lower()
    end)
    catalog=found
    status="Client catalogue: "..#catalog.." entries. Ownership is not verified."
    return true
  end
  local function filtered()
    local list={}
    local category=state.NovaXUnlockCategory
    for _,entry in ipairs(catalog) do
      if category=="All" or entry.category==category then
        list[#list+1]=entry
      end
    end
    return list
  end
  local function refreshPage()
    if busy then return end
    busy=true
    local list=filtered()
    local pageCount=math.max(1,math.ceil(#list/perPage))
    local page=math.floor(tonumber(state.NovaXUnlockPage) or 1)
    page=math.clamp(page,1,pageCount)
    state.NovaXUnlockPage=page
    selectedEntries={}
    local options={}
    for i=(page-1)*perPage+1,math.min(page*perPage,#list) do
      local item=list[i]
      local label=item.name.." ["..item.rarity.."]"
      if state.NovaXUnlockCategory=="All" then label=item.category.." | "..label end
      options[#options+1]=label
      selectedEntries[label]=item
    end
    if #options==0 then options={"No entries on this page"} end
    if controls.selector and controls.selector.Refresh then
      pcall(function()controls.selector:Refresh(options)end)
    end
    local description=string.format("%s: %d items, page %d/%d",state.NovaXUnlockCategory,#list,page,pageCount)
    if controls.pageInfo and controls.pageInfo.Set then
      pcall(function()controls.pageInfo:Set(description)end)
    end
    status=description.." | Listing does not mean unlocked"
    busy=false
  end
  local tab=ui:CreateTab("Unlock",4483345998)
  tab:CreateSection("All RIVALS cosmetics")
  tab:CreateLabel("All client-listed cosmetics in ONE tab. Locked items remain locked.")
  tab:CreateLabel("Skins, wraps, charms, finishers, emotes and more.")
  controls.category=tab:CreateDropdown({
    Name="Cosmetic category",
    Options=categories,
    CurrentOption={table.find(categories,state.NovaXUnlockCategory) and state.NovaXUnlockCategory or "All"},
    Callback=function(value)
      if busy then return end
      local chosen=choice(value)
      if not table.find(categories,chosen) then return end
      state.NovaXUnlockCategory=chosen
      state.NovaXUnlockPage=1
      refreshPage()
    end,
  })
  controls.pageInfo=tab:CreateParagraph({Title="Catalogue page",Content="Loading..."})
  tab:CreateButton({Name="Previous page",Callback=function()
    state.NovaXUnlockPage=math.max(1,(tonumber(state.NovaXUnlockPage) or 1)-1)
    refreshPage()
  end})
  tab:CreateButton({Name="Next page",Callback=function()
    state.NovaXUnlockPage=(tonumber(state.NovaXUnlockPage) or 1)+1
    refreshPage()
  end})
  controls.selector=tab:CreateDropdown({
    Name="Cosmetic",
    Options={"Load catalogue"},
    CurrentOption={"Load catalogue"},
    Callback=function(value)
      local entry=selectedEntries[choice(value)]
      if not entry then return end
      selected=entry
      state.NovaXUnlockSelection=entry.name
      status=entry.category.." / "..entry.name.." ["..entry.rarity.."]"
      if entry.weapon~="" then status=status.." | weapon: "..entry.weapon end
    end,
  })
  tab:CreateButton({Name="Rescan complete catalogue",Callback=function()
    if scan() then refreshPage() end
    notify("Unlock",status)
  end})
  tab:CreateButton({Name="Show selected cosmetic details",Callback=function()
    notify("Unlock",selected and status or "Choose a cosmetic from the list first")
  end})
  tab:CreateSection("Real equipment")
  tab:CreateButton({Name="Open RIVALS equipment",Callback=function()
    if showEquipment() then
      notify("Unlock","RIVALS inventory opened. Only items owned by your account can be equipped.")
    end
  end})
  tab:CreateButton({Name="Ownership / equip status",Callback=function()
    local _,_,equip=equipment()
    notify("Unlock",string.format("%d cosmetics in client catalogue; ownership is NOT proven. Native equipment: %s",
      #catalog,equip and "available" or "not loaded"))
  end})
  if scan() then refreshPage() end
  return {
    ApplyState=function()
      if not active then return end
      if not table.find(categories,state.NovaXUnlockCategory) then state.NovaXUnlockCategory="All" end
      if controls.category and controls.category.Set then
        pcall(function()controls.category:Set(state.NovaXUnlockCategory)end)
      end
      refreshPage()
    end,
    Stop=function() active=false end,
  }
end
