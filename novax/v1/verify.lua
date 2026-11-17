-- NovaX v1 compile-only verification. No gameplay functions are executed.
local REV="8d1955224c38146b07bda7d8fad0e16e050caab1"
local root="https://raw.githubusercontent.com/ovaNite/uwuHub/"..REV.."/novax/v1/"
local paths={
  "ui/NovaPremiumUI.lua",
  "core/legacy.lua",
  "modules/capabilities.lua",
  "modules/weather.lua",
  "modules/gui_extensions.lua",
}
if type(loadstring)~="function" then
  warn("[NovaX VERIFY] ERROR: loadstring unavailable")
  return false
end
local good=0
local bad=0
for _,path in ipairs(paths) do
  local ok,source=pcall(function()return game:HttpGet(root..path,true)end)
  if not ok or type(source)~="string" or #source<100 then
    warn("[NovaX VERIFY] FAIL download "..path.." : "..tostring(source))
    bad+=1
  else
    local fn,err=loadstring(source)
    if type(fn)=="function" then
      good+=1
      print("[NovaX VERIFY] PASS compile "..path.." | "..#source.." bytes")
    else
      bad+=1
      warn("[NovaX VERIFY] FAIL syntax "..path.." : "..tostring(err))
    end
  end
end
print(string.format("[NovaX VERIFY] Syntax checks %d/%d | failures %d",
  good,#paths,bad))
print("[NovaX VERIFY] This does not verify in-game permissions, hook behavior or hits.")
return bad==0
