-- NovaX weapon diagnostics. Local metadata only; run explicitly from the GUI.
return function(env)
  local Players=game:GetService("Players")
  local HttpService=game:GetService("HttpService")
  local LocalPlayer=Players.LocalPlayer
  local ui=env.NX_UI_WINDOW
  assert(type(ui)=="table" and type(ui.CreateTab)=="function","NovaX GUI not available")
  local patterns={"spread","bloom","accuracy","recoil","rate","rpm","cooldown","delay","speed",
    "velocity","projectile","bullet","fire","range","damage","ammo","magazine","reload","shot","burst"}
  local function interesting(name)
    local low=string.lower(tostring(name))
    for _,p in ipairs(patterns) do if string.find(low,p,1,true) then return true end end
    return false
  end
  local function reportStatus(message)
    print("[NovaX Diagnostics] "..message)
    pcall(function() if ui.Notify then ui:Notify({Title="Weapon Diagnostics",Content=message,Duration=7}) end end)
  end
  local function scan()
    local report={schema="novax.weapon-diagnostics.v1",notes={
      "Local, client-visible metadata only. Values do not prove server behavior.",
      "No scripts, player identities, network payloads, credentials, or arbitrary strings are collected."
    },weapons={},warnings={}}
    local containers={LocalPlayer and LocalPlayer.Character, LocalPlayer and LocalPlayer:FindFirstChildOfClass("Backpack")}
    local seen={}
    for _,container in pairs(containers) do
      if container then
        for _,tool in ipairs(container:GetChildren()) do
          if tool:IsA("Tool") and not seen[tool] and #report.weapons<16 then
            seen[tool]=true
            local item={name=string.sub(tool.Name,1,80),location=container==LocalPlayer.Character and "equipped" or "backpack",entries={}}
            local all={tool}
            for _,v in ipairs(tool:GetDescendants()) do
              if #all>=251 then item.truncated=true;break end
              all[#all+1]=v
            end
            for _,obj in ipairs(all) do
              local entry={name=string.sub(obj.Name,1,80),class=obj.ClassName,attributes={}}
              local matched=interesting(obj.Name)
              local ok,attrs=pcall(function() return obj:GetAttributes() end)
              if ok then
                for name,value in pairs(attrs) do
                  if interesting(name) and (type(value)=="boolean" or (type(value)=="number" and value==value and value~=math.huge and value~=-math.huge)) then
                    entry.attributes[string.sub(name,1,80)]=value
                    matched=true
                  end
                end
              end
              if matched and (obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("BoolValue")) then
                local value=obj.Value
                if type(value)=="boolean" or (type(value)=="number" and value==value and value~=math.huge and value~=-math.huge) then entry.value=value end
              end
              if matched and #item.entries<150 then item.entries[#item.entries+1]=entry end
            end
            report.weapons[#report.weapons+1]=item
          end
        end
      end
    end
    if #report.weapons==0 then report.warnings[#report.warnings+1]="No local Tool objects found; game may store weapons elsewhere." end
    local ok,json=pcall(function()return HttpService:JSONEncode(report)end)
    if not ok then reportStatus("JSON export failed: "..tostring(json));return end
    local filename="NovaX_weapon_diagnostics.json"
    local saved=false
    if type(writefile)=="function" then
      local good=pcall(writefile,filename,json)
      saved=good
    end
    local copied=false
    if type(setclipboard)=="function" then copied=pcall(setclipboard,json) end
    if saved or copied then
      reportStatus(string.format("Found %d weapons. %s%s",#report.weapons,saved and "Saved "..filename..". " or "",copied and "Copied to clipboard." or ""))
    else
      warn("[NovaX Diagnostics] Executor has no writefile or setclipboard. Output follows:")
      print(json)
      reportStatus("No file/clipboard support; diagnostic printed to console.")
    end
  end
  local tab=ui:CreateTab("Weapon Diagnostics",4483345998)
  tab:CreateSection("Local diagnostics")
  tab:CreateLabel("Exports local weapon metadata only; no automatic upload.")
  tab:CreateButton({Name="Scan and export weapon data",Callback=scan})
  return {Stop=function() end}
end
