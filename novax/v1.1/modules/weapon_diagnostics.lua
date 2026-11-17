-- NovaX weapon diagnostics v2: bounded, opt-in, client-visible metadata.
return function(env)
  local Players=game:GetService("Players")
  local HttpService=game:GetService("HttpService")
  local Workspace=game:GetService("Workspace")
  local ReplicatedStorage=game:GetService("ReplicatedStorage")
  local player=Players.LocalPlayer
  local ui=env.NX_UI_WINDOW
  assert(type(ui)=="table" and type(ui.CreateTab)=="function","NovaX GUI not available")
  local words={"weapon","gun","rifle","pistol","shotgun","sniper","revolver","minigun",
    "projectile","bullet","spread","accuracy","recoil","firerate","fire_rate","cooldown",
    "reload","ammo","magazine","muzzle","barrel","crossbow","bow","launcher","grenade"}
  local blocked={"password","cookie","token","secret","credential","auth","session"}
  local function hasAny(name,list)
    local n=string.lower(tostring(name))
    for _,v in ipairs(list) do
      if v=="bow" then
        if string.find(n,"%f[%a]bow%f[%A]") then return true end
      elseif string.find(n,v,1,true) then return true end
    end
    return false
  end
  local function cleanName(name)
    local s=tostring(name)
    if hasAny(s,blocked) then return "[redacted]" end
    for _,p in ipairs(Players:GetPlayers()) do
      for _,identity in ipairs({p.Name,p.DisplayName,tostring(p.UserId)}) do
        if #identity>0 and string.find(string.lower(s),string.lower(identity),1,true) then return "[player]" end
      end
    end
    return string.sub(s,1,80)
  end
  local function finite(value)
    return type(value)=="boolean" or (type(value)=="number" and value==value and value~=math.huge and value~=-math.huge)
  end
  local function status(message)
    print("[NovaX Diagnostics] "..message)
    pcall(function() if ui.Notify then ui:Notify({Title="Weapon Diagnostics",Content=message,Duration=7}) end end)
  end
  local scanning=false
  local function scan()
    if scanning then status("A scan is already running.");return end
    scanning=true
    task.spawn(function()
      local ok,err=pcall(function()
        local report={schema="novax.weapon-diagnostics.v2",summary={},matches={},warnings={
          "Only client-visible object metadata and matching finite numeric/boolean values are included.",
          "Script contents, network messages, credentials, and player character models are excluded."
        }}
        local roots={{instance=Workspace,label="Workspace"},{instance=ReplicatedStorage,label="ReplicatedStorage"}}
        local backpack=player and player:FindFirstChildOfClass("Backpack")
        if backpack then roots[#roots+1]={instance=backpack,label="LocalBackpack"} end
        local character=player and player.Character
        if character then roots[#roots+1]={instance=character,label="LocalCharacter"} end
        local blockedChars={}
        for _,p in ipairs(Players:GetPlayers()) do if p.Character and p~=player then blockedChars[p.Character]=true end end
        local total=0
        for _,root in ipairs(roots) do
          local queue={{obj=root.instance,path=root.label}}
          local index,visited=1,0
          while index<=#queue and total<30000 do
            local item=queue[index]
            queue[index]=false
            index+=1
            local obj=item.obj
            if obj and obj.Name~="NovaX_Weather_LocalVisuals" and not blockedChars[obj] and not (root.label=="Workspace" and obj==character) and not hasAny(obj.Name,blocked) then
              visited+=1;total+=1
              local isScript=obj:IsA("LuaSourceContainer")
              local isRemote=obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
              if not isScript and not isRemote then
                local match=hasAny(obj.Name,words)
                local entry={path=item.path,class=obj.ClassName,attributes={}}
                local success,attrs=pcall(function()return obj:GetAttributes()end)
                if success then
                  local attrCount=0
                  for k,v in pairs(attrs) do
                    if attrCount>=24 then break end
                    if hasAny(k,words) and not hasAny(k,blocked) and finite(v) then
                      entry.attributes[cleanName(k)]=v;match=true;attrCount+=1
                    end
                  end
                end
                if match and (obj:IsA("NumberValue") or obj:IsA("IntValue") or obj:IsA("BoolValue")) and finite(obj.Value) then entry.value=obj.Value end
                if match and #report.matches<600 then report.matches[#report.matches+1]=entry end
                local okChildren,children=pcall(function()return obj:GetChildren()end)
                if okChildren then
                  for _,child in ipairs(children) do
                    if #queue<30001 then queue[#queue+1]={obj=child,path=string.sub(item.path.."/"..cleanName(child.Name),1,512)} end
                  end
                end
              end
            end
            if total%150==0 then task.wait() end
          end
          report.summary[root.label]=visited
        end
        if total>=30000 then report.warnings[#report.warnings+1]="Scan stopped at 30000 objects; results may be incomplete." end
        if #report.matches>=600 then report.warnings[#report.warnings+1]="Match limit reached; results may be incomplete." end
        local json=HttpService:JSONEncode(report)
        local saved=type(writefile)=="function" and pcall(writefile,"NovaX_weapon_diagnostics.json",json)
        local copied=type(setclipboard)=="function" and pcall(setclipboard,json)
        if not saved and not copied then print(json) end
        status(string.format("%d matches / %d objects. %s%s",#report.matches,total,saved and "Saved. " or "",copied and "Copied." or ""))
      end)
      scanning=false
      if not ok then status("Scan error: "..tostring(err)) end
    end)
  end
  local tab=ui:CreateTab("Weapon Diagnostics",4483345998)
  tab:CreateSection("Client-visible diagnostics")
  tab:CreateLabel("Workspace and ReplicatedStorage; capped, local export; no upload.")
  tab:CreateButton({Name="Scan and export weapon data",Callback=scan})
  return {Stop=function() end}
end
