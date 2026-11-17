-- NovaX v1.1 compile-only verification. Does not start gameplay modules.
local REV="e34e7f8387eda9cf580e8dc7e485a16706c4f628"
local root="https://raw.githubusercontent.com/ovaNite/uwuHub/"..REV.."/novax/v1.1/"
local paths={"ui/NovaPremiumUI.lua","core/legacy.lua","modules/capabilities.lua",
  "modules/weather.lua","modules/gui_extensions.lua"}
if type(loadstring)~="function" then
  warn("[NovaX VERIFY] loadstring unavailable")
  return false
end
local good,bad=0,0
for _,path in ipairs(paths) do
  local ok,source=pcall(function()return game:HttpGet(root..path,true)end)
  if not ok or type(source)~="string" or #source<100 then
    bad+=1
    warn("[NovaX VERIFY] FAIL download "..path.." : "..tostring(source))
  else
    local fn,err=loadstring(source)
    if type(fn)=="function" then
      good+=1
      print("[NovaX VERIFY] PASS "..path.." | "..#source.." bytes")
    else
      bad+=1
      warn("[NovaX VERIFY] FAIL syntax "..path.." : "..tostring(err))
    end
  end
end
print(string.format("[NovaX VERIFY] Syntax checks %d/%d | failures %d",good,#paths,bad))
print("[NovaX VERIFY] No modules were executed; no live weapon behavior is tested.")
return bad==0
