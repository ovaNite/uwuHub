-- NovaX v1.1 - honest RIVALS equipment integration.
-- The previous "Unlock All"/local cosmetics tabs only spoofed appearances.
-- This tab never claims server ownership or intercepts purchases/equip remotes.
return function(env)
  local Players=game:GetService("Players")
  local ReplicatedStorage=game:GetService("ReplicatedStorage")
  local player=Players.LocalPlayer
  local ui=assert(env.NX_UI_WINDOW,"NovaX window unavailable")
  local active=true
  local count=0
  local dataReady=false
  local status="No ownership data confirmed"
  local function notify(title,message)
    print("[NovaX Equipment] "..tostring(message))
    if ui.Notify then
      pcall(function()ui:Notify({Title=title,Content=tostring(message),Duration=7})end)
    end
  end
  local function equipment()
    local playerGui=player:FindFirstChildOfClass("PlayerGui")
    local mainGui=playerGui and playerGui:FindFirstChild("MainGui")
    local frame=mainGui and mainGui:FindFirstChild("MainFrame")
    local equip=frame and frame:FindFirstChild("Equipment")
    return mainGui,frame,equip
  end
  local function catalogueInfo()
    local modules=ReplicatedStorage:FindFirstChild("Modules")
    local module=modules and modules:FindFirstChild("CosmeticLibrary")
    if not module or not module:IsA("ModuleScript") then
      return nil,"CosmeticLibrary not available"
    end
    local ok,lib=pcall(require,module)
    if not ok or type(lib)~="table" or type(lib.Cosmetics)~="table" then
      return nil,"Cannot read CosmeticLibrary.Cosmetics"
    end
    local totals={}
    local total=0
    for name,entry in pairs(lib.Cosmetics) do
      if type(name)=="string" and type(entry)=="table" then
        local kind=tostring(rawget(entry,"Type") or "Other")
        total+=1
        totals[kind]=(totals[kind] or 0)+1
      end
    end
    count=total
    dataReady=true
    return totals,"Catalogue contains "..total.." cosmetics (NOT an owned-item count)"
  end
  local tab=ui:CreateTab("RIVALS Equipment",4483345998)
  tab:CreateSection("Native inventory and equip")
  tab:CreateLabel("Real equip requires game-accepted ownership. Client previews cannot unlock items.")
  tab:CreateButton({Name="Open official RIVALS equipment",Callback=function()
    if not active then return end
    local gui,frame,equip=equipment()
    if not equip or not equip:IsA("GuiObject") then
      notify("Equipment","RIVALS Equipment UI not currently loaded.")
      return
    end
    local ok,err=pcall(function()
      if gui and gui:IsA("ScreenGui") then gui.Enabled=true end
      if frame and frame:IsA("GuiObject") then frame.Visible=true end
      equip.Visible=true
    end)
    if ok then
      status="Official equipment view opened. Equip items through RIVALS's own controls."
    else
      status="Failed to open RIVALS equipment: "..tostring(err)
    end
    notify("Equipment",status)
  end})
  tab:CreateButton({Name="Check catalogue / native equipment",Callback=function()
    if not active then return end
    local _,_,equip=equipment()
    local _,message=catalogueInfo()
    local available=equip and equip:IsA("GuiObject")
    status=message.." | Native UI: "..(available and "present" or "not loaded")
    notify("Equipment",status)
  end})
  tab:CreateButton({Name="Check unlock capability",Callback=function()
    if not active then return end
    notify("Ownership","No server-authorized unlock/equip API has been verified. Locked items remain locked.")
  end})
  return {Stop=function()active=false end}
end
