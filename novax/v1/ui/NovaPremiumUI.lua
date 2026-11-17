-- =============== NOVA PREMIUM UI LIBRARY ===============
local NovaPremiumUI = (function()
-- NovaPremiumUI.lua
-- Single-file modern Roblox GUI library (premium app-style).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

if not game:IsLoaded() then
  game.Loaded:Wait()
end

local UI = {}
UI.__index = UI
UI.Debug = false

function UI.SetDebug(self, maybeVal)
  local v = maybeVal
  if type(self) == "boolean" and maybeVal == nil then
    v = self
  end
  UI.Debug = v and true or false
  if UI.Debug then warn("[NovaPremiumUI][debug] Debug enabled") end
end

UI.DefaultTheme = {
  Font = Enum.Font.Gotham,
  Radius = 14,
  WindowSize = Vector2.new(860, 560),
  LogoImage = nil,
  LogoRectOffset = Vector2.new(160, 330),
  LogoRectSize = Vector2.new(310, 270),
  Colors = {
    BgA = Color3.fromRGB(5, 12, 24),
    BgB = Color3.fromRGB(8, 22, 42),
    Surface = Color3.fromRGB(12, 25, 45),
    Surface2 = Color3.fromRGB(17, 35, 62),
    Surface3 = Color3.fromRGB(21, 48, 83),
    Sidebar = Color3.fromRGB(8, 18, 34),
    Sidebar2 = Color3.fromRGB(10, 26, 48),
    Stroke = Color3.fromRGB(46, 103, 174),
    StrokeSoft = Color3.fromRGB(22, 54, 94),
    Text = Color3.fromRGB(237, 246, 255),
    TextDim = Color3.fromRGB(149, 176, 209),
    Accent = Color3.fromRGB(48, 145, 255),
    Accent2 = Color3.fromRGB(34, 221, 217),
    AccentSoft = Color3.fromRGB(11, 74, 128),
    Input = Color3.fromRGB(7, 19, 36),
    Shadow = Color3.fromRGB(0, 0, 0),
  },
  Anim = {
    Fast = 0.14,
    Normal = 0.24,
    Slow = 0.46,
    Splash = 3.05,
  },
  Spacing = {
    XS = 4,
    SM = 8,
    MD = 12,
    LG = 16,
  },
}

local function copy(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    out[k] = type(v) == "table" and copy(v) or v
  end
  return out
end

local function merge(base, override)
  local out = copy(base)
  if type(override) ~= "table" then
    return out
  end
  for k, v in pairs(override) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

local function make(class, props)
  local inst = Instance.new(class)
  for k, v in pairs(props or {}) do
    inst[k] = v
  end
  if UI.Debug and not inst then
    warn("[NovaPremiumUI][debug] Instance.new returned nil for class:", tostring(class))
  end
  return inst
end

local function corner(parent, radius)
  return make("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
end

local function stroke(parent, color, thickness, transparency)
  return make("UIStroke", {
    Color = color,
    Thickness = thickness or 1,
    Transparency = transparency or 0,
    Parent = parent,
  })
end

local function gradient(parent, c0, c1, rotation)
  return make("UIGradient", {
    Rotation = rotation or 0,
    Color = ColorSequence.new({
      ColorSequenceKeypoint.new(0, c0),
      ColorSequenceKeypoint.new(1, c1),
    }),
    Parent = parent,
  })
end

local function tween(obj, t, props, style, dir)
  local tw = TweenService:Create(
    obj,
    TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
    props
  )
  tw:Play()
  return tw
end

local function safeCallback(callback, ...)
  if type(callback) ~= "function" then
    return
  end
  local ok, err = pcall(callback, ...)
  if not ok and UI.Debug then
    warn("[NovaPremiumUI][debug] Callback failed:", tostring(err))
  end
end

local function resolveAssetSource(source)
  local function resolveOne(value)
    if type(value) ~= "string" or value == "" then
      return nil
    end
    
    if value:match("^rbxasset") or value:match("^http") then
      return value
    end
    
    if typeof(getcustomasset) == "function" then
      local ok, asset = pcall(getcustomasset, value)
      if ok and type(asset) == "string" and asset ~= "" then
        return asset
      end
    end
    
    if typeof(getsynasset) == "function" then
      local ok, asset = pcall(getsynasset, value)
      if ok and type(asset) == "string" and asset ~= "" then
        return asset
      end
    end
    
    return nil
  end
  
  if type(source) == "table" then
    for _, value in ipairs(source) do
      local asset = resolveOne(value)
      if asset then
        return asset
      end
    end
    return nil
  end
  
  return resolveOne(source)
end

local function createNovaMark(parent, theme, size, imageSource, rectOffset, rectSize)
  local badge = make("Frame", {
    Size = UDim2.new(0, size, 0, size),
    BackgroundColor3 = theme.Colors.Input,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = parent,
  })
  corner(badge, math.max(10, math.floor(size * 0.28)))
  stroke(badge, theme.Colors.Stroke, 1, 0.22)
  gradient(badge, theme.Colors.AccentSoft, theme.Colors.Input, 38)
  
  if imageSource then
    local img = make("ImageLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 10, 1, 10),
      Position = UDim2.new(0, -5, 0, -5),
      Image = imageSource,
      ImageTransparency = 0,
      ScaleType = Enum.ScaleType.Fit,
      Parent = badge,
    })
    if typeof(rectOffset) == "Vector2" and typeof(rectSize) == "Vector2" then
      img.ImageRectOffset = rectOffset
      img.ImageRectSize = rectSize
    end
  else
    make("TextLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 1, 0),
      Font = Enum.Font.GothamBlack,
      Text = "NX",
      TextSize = math.floor(size * 0.38),
      TextColor3 = theme.Colors.Text,
      TextTransparency = 0.02,
      Parent = badge,
    })
    
  end
  
  return badge
end

local function getLocalPlayerSafe(maxWait)
  local lp = LocalPlayer or Players.LocalPlayer
  if lp then
    LocalPlayer = lp
    return lp
  end
  local deadline = tick() + (tonumber(maxWait) or 6)
  while tick() < deadline do
    task.wait(0.05)
    lp = Players.LocalPlayer
    if lp then
      LocalPlayer = lp
      return lp
    end
  end
  return nil
end

local function getPlayerGuiSafe(lp, maxWait)
  if not lp then return nil end
  local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui")
  if pg then return pg end
  local deadline = tick() + (tonumber(maxWait) or 6)
  while tick() < deadline do
    task.wait(0.05)
    pg = lp:FindFirstChildOfClass("PlayerGui") or lp:FindFirstChild("PlayerGui")
    if pg then
      return pg
    end
  end
  return nil
end

local function waitForGameReady(maxWait)
  if not game:IsLoaded() then
    game.Loaded:Wait()
  end
  local lp = getLocalPlayerSafe(maxWait or 8)
  if lp then
    getPlayerGuiSafe(lp, maxWait or 8)
  end
  return lp
end

local function buildGuiParents()
  local list = {}
  local seen = {}
  local function addParent(inst)
    if typeof(inst) ~= "Instance" then return end
    if seen[inst] then return end
    seen[inst] = true
    table.insert(list, inst)
  end
  
  -- Prefer executor UI container when available.
  if typeof(gethui) == "function" then
    local okHui, hui = pcall(gethui)
    if okHui then
      addParent(hui)
    end
  end
  
  addParent(CoreGui)
  
  local lp = getLocalPlayerSafe(4)
  addParent(getPlayerGuiSafe(lp, 4))
  
  return list
end

local function safeParent(gui, retrySeconds)
  local tries = math.max(1, math.floor(((tonumber(retrySeconds) or 2) / 0.1) + 0.5))
  for _ = 1, tries do
    for _, parentInst in ipairs(buildGuiParents()) do
      local ok = pcall(function()
        gui.Parent = parentInst
      end)
      if ok and gui.Parent == parentInst then
        if UI.Debug then
          warn("[NovaPremiumUI][debug] Parented to", parentInst:GetFullName())
        end
        return true
      end
    end
    task.wait(0.1)
  end
  return false
end

local function makeDraggable(handle, target, trackConnection, onMoved, onEnded)
  local dragging = false
  local dragStart, startPos

  local inputBeganConn = handle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      dragStart = input.Position
      startPos = target.Position
      local changedConn
      changedConn = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
          dragging = false
          if type(onEnded) == "function" then
            pcall(onEnded, target.Position)
          end
          if changedConn then
            changedConn:Disconnect()
            changedConn = nil
          end
        end
      end)
    end
  end)
  if trackConnection then
    trackConnection(inputBeganConn)
  end

  local inputChangedConn = UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
      local d = input.Position - dragStart
      target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
      if type(onMoved) == "function" then
        pcall(onMoved, target.Position)
      end
    end
  end)
  if trackConnection then
    trackConnection(inputChangedConn)
  end
end

local function addRipple(btn, theme)
  local m = UserInputService:GetMouseLocation()
  local lx = m.X - btn.AbsolutePosition.X
  local ly = m.Y - btn.AbsolutePosition.Y

  local clip = btn:FindFirstChild("RippleClip")
  if not clip then
    clip = make("Frame", {
      Name = "RippleClip",
      BackgroundTransparency = 1,
      ClipsDescendants = true,
      Size = UDim2.new(1, 0, 1, 0),
      Parent = btn,
    })
    corner(clip, theme.Radius - 2)
  end

  local r = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0, lx, 0, ly),
    Size = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.7,
    BorderSizePixel = 0,
    Parent = clip,
  })
  corner(r, 999)

  local maxS = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 1.6
  tween(r, theme.Anim.Normal, {Size = UDim2.new(0, maxS, 0, maxS), BackgroundTransparency = 1})
  task.delay(theme.Anim.Normal + 0.05, function()
    if r and r.Parent then r:Destroy() end
  end)
end

local NotifGui, NotifHolder

local function ensureNotifLayer(theme)
  if NotifGui and NotifGui.Parent and NotifHolder then
    return
  end
  NotifGui = make("ScreenGui", {
    Name = "NovaPremiumUI_Notifications",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  })
  local notifParentOk = safeParent(NotifGui)
  if UI.Debug then
    if notifParentOk and NotifGui.Parent then
      warn("[NovaPremiumUI][debug] Notification ScreenGui parent set to", NotifGui.Parent:GetFullName())
    else
      warn("[NovaPremiumUI][debug] Notification ScreenGui not parented; Parent is:", NotifGui.Parent)
    end
  end

  NotifHolder = make("Frame", {
    BackgroundTransparency = 1,
    AnchorPoint = Vector2.new(1, 1),
    Size = UDim2.new(0, 340, 0, 320),
    Position = UDim2.new(1, -18, 1, -18),
    Parent = NotifGui,
  })
  make("UIListLayout", {
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Right,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = NotifHolder,
  })
end

local function makeControlBase(page, theme, h)
  local f = make("Frame", {
    Size = UDim2.new(1, 0, 0, h or 42),
    BackgroundColor3 = theme.Colors.Surface,
    BorderSizePixel = 0,
    Parent = page,
  })
  corner(f, theme.Radius - 4)
  stroke(f, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.18)
  gradient(f, theme.Colors.Surface, theme.Colors.Surface2, 12)

  local glow = make("Frame", {
    Size = UDim2.new(1, 2, 1, 2),
    Position = UDim2.new(0, -1, 0, -1),
    BackgroundColor3 = theme.Colors.Accent2 or theme.Colors.Accent,
    BackgroundTransparency = 0.965,
    ZIndex = f.ZIndex - 1,
    Parent = f,
  })
  corner(glow, theme.Radius)
  return f, glow
end

local function normalizeRange(minValue, maxValue)
  local min = tonumber(minValue) or 0
  local max = tonumber(maxValue) or 100
  if max < min then
    min, max = max, min
  end
  return min, max
end

function UI:Notify(opts)
  opts = opts or {}
  local theme = self._theme or UI.DefaultTheme
  ensureNotifLayer(theme)

  local toast = make("Frame", {
    BackgroundColor3 = theme.Colors.Surface2,
    Size = UDim2.new(1, 0, 0, 80),
    BackgroundTransparency = 0.05,
    Parent = NotifHolder,
  })
  corner(toast, theme.Radius)
  stroke(toast, theme.Colors.Stroke, 1, 0.16)
  gradient(toast, theme.Colors.Surface2, theme.Colors.Input, 18)
  local strip = make("Frame", {
    Size = UDim2.new(0, 3, 1, -18),
    Position = UDim2.new(0, 8, 0, 9),
    BackgroundColor3 = theme.Colors.Accent2 or theme.Colors.Accent,
    BorderSizePixel = 0,
    Parent = toast,
  })
  corner(strip, 999)

  make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -28, 0, 24),
    Position = UDim2.new(0, 18, 0, 8),
    Font = theme.Font,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = theme.Colors.Text,
    Text = tostring(opts.Title or "Notification"),
    Parent = toast,
  })

  make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -28, 0, 40),
    Position = UDim2.new(0, 18, 0, 30),
    Font = Enum.Font.Gotham,
    TextSize = 13,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextColor3 = theme.Colors.TextDim,
    Text = tostring(opts.Content or ""),
    Parent = toast,
  })

  toast.AnchorPoint = Vector2.new(1, 0)
  toast.Position = UDim2.new(1, 30, 0, 0)
  tween(toast, theme.Anim.Normal, {Position = UDim2.new(1, 0, 0, 0)})
  task.delay(tonumber(opts.Duration) or 6, function()
    if toast and toast.Parent then
      tween(toast, theme.Anim.Normal, {Position = UDim2.new(1, 36, 0, 0), BackgroundTransparency = 1})
      task.delay(theme.Anim.Normal + 0.05, function()
        if toast and toast.Parent then toast:Destroy() end
      end)
    end
  end)
end

function UI:CreateWindow(opts)
  opts = opts or {}
  waitForGameReady(10)
  local theme = merge(UI.DefaultTheme, opts.Theme)
  local logoSource = resolveAssetSource(opts.LogoImage or theme.LogoImage)
  local logoRectOffset = opts.LogoRectOffset or theme.LogoRectOffset
  local logoRectSize = opts.LogoRectSize or theme.LogoRectSize

  local window = setmetatable({_theme = theme, _tabs = {}, _activeTab = nil}, UI)
  window._connections = {}
  local function bindConnection(conn)
    if conn then
      table.insert(window._connections, conn)
    end
    return conn
  end

  local sz = opts.Size or theme.WindowSize
  local gui = make("ScreenGui", {
    Name = tostring(opts.Name or "NovaPremiumUI"),
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 15,
    Enabled = true,
  })
  local parented = safeParent(gui, 2.5)
  if not parented or not gui.Parent then
    if UI.Debug then
      warn("[NovaPremiumUI][debug] Failed to parent ScreenGui")
      warn("[NovaPremiumUI][debug] gui.Parent is:", gui.Parent, "; LocalPlayer:", LocalPlayer)
    end
    task.spawn(function()
      local okRetry = safeParent(gui, 10)
      if not okRetry then
        if UI.Debug then warn("[NovaPremiumUI][debug] ScreenGui retry parent failed") end
      elseif UI.Debug and gui.Parent then
        warn("[NovaPremiumUI][debug] ScreenGui retry parent success:", gui.Parent:GetFullName())
      end
    end)
  else
    if UI.Debug then warn("[NovaPremiumUI][debug] ScreenGui parent set to", gui.Parent:GetFullName()) end
  end
  
  local islandGui = nil

  local shell = make("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(0, sz.X, 0, sz.Y),
    Position = UDim2.new(0.5, -sz.X / 2, 0.5, -sz.Y / 2),
    Parent = gui,
  })

  local shadow = make("Frame", {
    Size = UDim2.new(1, 18, 1, 18),
    Position = UDim2.new(0, -9, 0, 10),
    BackgroundColor3 = theme.Colors.Shadow,
    BackgroundTransparency = 0.78,
    BorderSizePixel = 0,
    Parent = shell,
  })
  corner(shadow, theme.Radius + 6)

  local root = make("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = theme.Colors.BgA,
    BorderSizePixel = 0,
    Parent = shell,
  })
  local rootScale = make("UIScale", {Scale = 0.965, Parent = root})
  corner(root, theme.Radius + 2)
  stroke(root, theme.Colors.Stroke, 1, 0.12)
  gradient(root, theme.Colors.BgA, theme.Colors.BgB, 24)

  local top = make("Frame", {
    Size = UDim2.new(1, 0, 0, 74),
    BackgroundColor3 = theme.Colors.Sidebar,
    BorderSizePixel = 0,
    Parent = root,
  })
  corner(top, theme.Radius + 2)
  gradient(top, theme.Colors.Sidebar, theme.Colors.Sidebar2 or theme.Colors.BgB, 0)
  make("Frame", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = theme.Colors.Sidebar2 or theme.Colors.Sidebar, BorderSizePixel = 0, Parent = top})
  make("Frame", {Size = UDim2.new(1, -30, 0, 1), Position = UDim2.new(0, 15, 1, -1), BackgroundColor3 = theme.Colors.StrokeSoft or theme.Colors.Stroke, BackgroundTransparency = 0.32, BorderSizePixel = 0, Parent = top})

  local logoBadge = createNovaMark(top, theme, 46, logoSource, logoRectOffset, logoRectSize)
  logoBadge.Position = UDim2.new(0, 16, 0, 14)

  make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -160, 0, 28),
    Position = UDim2.new(0, 74, 0, 13),
    Font = Enum.Font.GothamBold,
    TextSize = 24,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = theme.Colors.Text,
    Text = tostring(opts.Title or opts.Name or "Nova Premium UI"),
    Parent = top,
  })
  
  make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -220, 0, 18),
    Position = UDim2.new(0, 76, 0, 42),
    Font = theme.Font,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = theme.Colors.TextDim,
    Text = tostring(opts.Subtitle or opts.LoadingSubtitle or "Modern control surface"),
    Parent = top,
  })
  
  local statusPill = make("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Size = UDim2.new(0, 118, 0, 28),
    Position = UDim2.new(1, -52, 0.5, 0),
    BackgroundColor3 = theme.Colors.Input,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Parent = top,
  })
  corner(statusPill, 999)
  stroke(statusPill, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.18)
  local statusDot = make("Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    Position = UDim2.new(0, 12, 0.5, -3),
    BackgroundColor3 = theme.Colors.Accent2 or theme.Colors.Accent,
    BorderSizePixel = 0,
    Parent = statusPill,
  })
  corner(statusDot, 999)
  make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, -28, 1, 0),
    Position = UDim2.new(0, 25, 0, 0),
    Font = theme.Font,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = theme.Colors.TextDim,
    Text = "Ready",
    Parent = statusPill,
  })
  
  local closeBtn = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.new(0, 30, 0, 30),
    BackgroundColor3 = theme.Colors.Surface3 or theme.Colors.Surface2,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    Text = "X",
    TextColor3 = theme.Colors.Accent2 or theme.Colors.Text,
    AutoButtonColor = false,
    Parent = top,
  })
  corner(closeBtn, theme.Radius - 3)
  stroke(closeBtn, theme.Colors.Stroke, 1, 0.18)
  closeBtn.MouseEnter:Connect(function() tween(closeBtn, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.AccentSoft or theme.Colors.Surface2}) end)
  closeBtn.MouseLeave:Connect(function() tween(closeBtn, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Surface3 or theme.Colors.Surface2}) end)
  
  local island = make("Frame", {
    Name = "DragIsland",
    AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.new(0, 320, 0, 8),
    Position = UDim2.new(0.5, 0, 1, 9),
    BackgroundColor3 = theme.Colors.AccentSoft or theme.Colors.Surface3,
    BorderSizePixel = 0,
    Parent = root,
  })
  corner(island, theme.Radius)
  stroke(island, theme.Colors.Accent2 or theme.Colors.Accent, 1, 0.36)
  gradient(island, theme.Colors.Accent, theme.Colors.Accent2 or theme.Colors.Accent, 0)
  local sidebar = make("Frame", {
    Size = UDim2.new(0, 198, 1, -102),
    Position = UDim2.new(0, 12, 0, 86),
    BackgroundColor3 = theme.Colors.Sidebar,
    BorderSizePixel = 0,
    Parent = root,
  })
  corner(sidebar, theme.Radius)
  stroke(sidebar, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.16)
  gradient(sidebar, theme.Colors.Sidebar, theme.Colors.Sidebar2 or theme.Colors.BgB, 90)

  local tabList = make("ScrollingFrame", {
    Size = UDim2.new(1, -8, 1, -8),
    Position = UDim2.new(0, 4, 0, 4),
    BackgroundTransparency = 1,
    ScrollBarThickness = 0,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = sidebar,
  })
  local tabLayout = make("UIListLayout", {Padding = UDim.new(0, theme.Spacing.SM), Parent = tabList})
  bindConnection(tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    tabList.CanvasSize = UDim2.new(0, 0, 0, tabLayout.AbsoluteContentSize.Y + 10)
  end))

  local content = make("Frame", {
    Size = UDim2.new(1, -226, 1, -102),
    Position = UDim2.new(0, 214, 0, 86),
    BackgroundColor3 = theme.Colors.Surface,
    BorderSizePixel = 0,
    Parent = root,
  })
  corner(content, theme.Radius)
  stroke(content, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.14)
  gradient(content, theme.Colors.Surface, theme.Colors.Input, 16)

  local search = make("TextBox", {
    Size = UDim2.new(1, -22, 0, 38),
    Position = UDim2.new(0, 11, 0, 11),
    BackgroundColor3 = theme.Colors.Input,
    BorderSizePixel = 0,
    Font = theme.Font,
    TextSize = 13,
    TextColor3 = theme.Colors.Text,
    PlaceholderColor3 = theme.Colors.TextDim,
    PlaceholderText = "Search features...",
    Text = "",
    ClearTextOnFocus = false,
    Parent = content,
  })
  corner(search, theme.Radius - 2)
  local searchStroke = stroke(search, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.22)
  search.Focused:Connect(function()
    tween(searchStroke, theme.Anim.Fast, {Transparency = 0.02, Color = theme.Colors.Accent2 or theme.Colors.Accent})
  end)
  search.FocusLost:Connect(function()
    tween(searchStroke, theme.Anim.Fast, {Transparency = 0.22, Color = theme.Colors.StrokeSoft or theme.Colors.Stroke})
  end)

  local pages = make("Frame", {
    Size = UDim2.new(1, -22, 1, -62),
    Position = UDim2.new(0, 11, 0, 55),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Parent = content,
  })

  function window:_Switch(tab)
    if self._activeTab == tab then return end
    local prev = self._activeTab
    self._activeTab = tab
    if prev and prev.Page and prev.Page.Visible then
      tween(prev.Page, theme.Anim.Normal, {Position = UDim2.new(0, -24, 0, 0)})
      task.delay(theme.Anim.Normal, function() if prev.Page then prev.Page.Visible = false end end)
    end
    tab.Page.Position = UDim2.new(0, 24, 0, 0)
    tab.Page.Visible = true
    tween(tab.Page, theme.Anim.Normal, {Position = UDim2.new(0, 0, 0, 0)})
    for _, t in ipairs(self._tabs) do
      local active = t == tab
      tween(t.Button, theme.Anim.Fast, {
        BackgroundColor3 = active and (theme.Colors.Surface3 or theme.Colors.Surface2) or theme.Colors.Surface,
      })
      if t.Label then
        tween(t.Label, theme.Anim.Fast, {
          TextColor3 = active and theme.Colors.Text or theme.Colors.TextDim,
        })
      end
      if t.Accent then
        tween(t.Accent, theme.Anim.Fast, {
          BackgroundTransparency = active and 0.05 or 0.82,
          Size = active and UDim2.new(0, 3, 0, 24) or UDim2.new(0, 2, 0, 14),
        })
      end
    end
  end

  function window:_ApplySearch(q)
    q = string.lower(tostring(q or ""))
    local firstVisible
    for _, tab in ipairs(self._tabs) do
      local tabMatch = (q == "") or string.find(string.lower(tab.Name), q, 1, true) ~= nil
      local anyControl = false
      for _, c in ipairs(tab.Controls) do
        local token = tostring(c._token or "")
        local m = (q == "") or (string.find(token, q, 1, true) ~= nil)
        c:SetVisible(m)
        if m then anyControl = true end
      end
      local showTab = tabMatch or anyControl
      tab.Button.Visible = showTab
      if showTab and not firstVisible then firstVisible = tab end
    end
    if self._activeTab and not self._activeTab.Button.Visible and firstVisible then
      self:_Switch(firstVisible)
    end
  end

  bindConnection(search:GetPropertyChangedSignal("Text"):Connect(function()
    window:_ApplySearch(search.Text)
  end))

  function window:Confirm(opts)
    opts = opts or {}
    local title = tostring(opts.Title or "Confirm")
    local contentText = tostring(opts.Content or opts.Text or "Are you sure?")
    local confirmText = tostring(opts.ConfirmText or "Confirm")
    local cancelText = tostring(opts.CancelText or "Cancel")
    local done = false
    
    local overlay = make("Frame", {
      Name = "NovaConfirm",
      Size = UDim2.new(1, 0, 1, 0),
      BackgroundColor3 = Color3.new(0, 0, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      ZIndex = 900,
      Parent = gui,
    })
    
    local card = make("Frame", {
      AnchorPoint = Vector2.new(0.5, 0.5),
      Size = UDim2.new(0, 390, 0, 170),
      Position = UDim2.new(0.5, 0, 0.5, 10),
      BackgroundColor3 = theme.Colors.Surface2,
      BackgroundTransparency = 0.04,
      BorderSizePixel = 0,
      ZIndex = 901,
      Parent = overlay,
    })
    corner(card, theme.Radius)
    stroke(card, theme.Colors.Stroke, 1, 0.12)
    
    make("TextLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, -32, 0, 28),
      Position = UDim2.new(0, 16, 0, 14),
      Font = Enum.Font.GothamBold,
      TextSize = 18,
      TextColor3 = theme.Colors.Text,
      TextXAlignment = Enum.TextXAlignment.Left,
      Text = title,
      ZIndex = 902,
      Parent = card,
    })
    
    make("TextLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, -32, 0, 58),
      Position = UDim2.new(0, 16, 0, 48),
      Font = theme.Font,
      TextSize = 13,
      TextColor3 = theme.Colors.TextDim,
      TextXAlignment = Enum.TextXAlignment.Left,
      TextYAlignment = Enum.TextYAlignment.Top,
      TextWrapped = true,
      Text = contentText,
      ZIndex = 902,
      Parent = card,
    })
    
    local cancelBtn = make("TextButton", {
      Size = UDim2.new(0.5, -22, 0, 36),
      Position = UDim2.new(0, 16, 1, -52),
      BackgroundColor3 = theme.Colors.Input,
      BorderSizePixel = 0,
      AutoButtonColor = false,
      Font = theme.Font,
      TextSize = 13,
      TextColor3 = theme.Colors.Text,
      Text = cancelText,
      ZIndex = 902,
      Parent = card,
    })
    corner(cancelBtn, theme.Radius - 4)
    stroke(cancelBtn, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.28)
    
    local confirmBtn = make("TextButton", {
      Size = UDim2.new(0.5, -22, 0, 36),
      Position = UDim2.new(0.5, 6, 1, -52),
      BackgroundColor3 = theme.Colors.Accent,
      BorderSizePixel = 0,
      AutoButtonColor = false,
      Font = Enum.Font.GothamBold,
      TextSize = 13,
      TextColor3 = Color3.new(1, 1, 1),
      Text = confirmText,
      ZIndex = 902,
      Parent = card,
    })
    corner(confirmBtn, theme.Radius - 4)
    
    local function close(result)
      if done then return end
      done = true
      tween(overlay, theme.Anim.Fast, {BackgroundTransparency = 1})
      tween(card, theme.Anim.Fast, {Position = UDim2.new(0.5, 0, 0.5, 10), BackgroundTransparency = 1})
      task.delay(theme.Anim.Fast + 0.04, function()
        if overlay and overlay.Parent then
          overlay:Destroy()
        end
      end)
      if result then
        safeCallback(opts.ConfirmCallback)
      else
        safeCallback(opts.CancelCallback)
      end
      safeCallback(opts.Callback, result)
    end
    
    cancelBtn.MouseEnter:Connect(function() tween(cancelBtn, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Surface}) end)
    cancelBtn.MouseLeave:Connect(function() tween(cancelBtn, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Input}) end)
    confirmBtn.MouseEnter:Connect(function() tween(confirmBtn, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Accent2 or theme.Colors.Accent}) end)
    confirmBtn.MouseLeave:Connect(function() tween(confirmBtn, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Accent}) end)
    cancelBtn.MouseButton1Click:Connect(function() close(false) end)
    confirmBtn.MouseButton1Click:Connect(function() close(true) end)
    
    tween(overlay, theme.Anim.Fast, {BackgroundTransparency = 0.45})
    tween(card, theme.Anim.Normal, {Position = UDim2.new(0.5, 0, 0.5, 0)}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    
    return {
      Frame = overlay,
      Close = function(_, result)
        close(result == true)
      end,
    }
  end

  function window:CreateTab(name)
    local tab = {Name = tostring(name or ("Tab " .. tostring(#self._tabs + 1))), Controls = {}}
    local b = make("TextButton", {
      Size = UDim2.new(1, 0, 0, 36),
      BackgroundColor3 = theme.Colors.Surface,
      BorderSizePixel = 0,
      Text = "",
      TextXAlignment = Enum.TextXAlignment.Left,
      Font = theme.Font,
      TextSize = 13,
      TextColor3 = theme.Colors.TextDim,
      AutoButtonColor = false,
      Parent = tabList,
    })
    corner(b, theme.Radius - 2)
    stroke(b, theme.Colors.StrokeSoft or theme.Colors.Stroke, 1, 0.36)
    local accent = make("Frame", {
      AnchorPoint = Vector2.new(0, 0.5),
      Size = UDim2.new(0, 2, 0, 14),
      Position = UDim2.new(0, 12, 0.5, 0),
      BackgroundColor3 = theme.Colors.Accent2 or theme.Colors.Accent,
      BackgroundTransparency = 0.72,
      BorderSizePixel = 0,
      Parent = b,
    })
    corner(accent, 999)
    local tabLabel = make("TextLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, -46, 1, 0),
      Position = UDim2.new(0, 34, 0, 0),
      Font = theme.Font,
      TextSize = 13,
      Text = tab.Name,
      TextColor3 = theme.Colors.TextDim,
      TextXAlignment = Enum.TextXAlignment.Left,
      Parent = b,
    })
    b.MouseEnter:Connect(function()
      if window._activeTab ~= tab then
        tween(b, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Surface2})
      end
    end)
    b.MouseLeave:Connect(function()
      if window._activeTab ~= tab then
        tween(b, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Surface})
      end
    end)
    b.MouseButton1Down:Connect(function() addRipple(b, theme) end)
    b.MouseButton1Click:Connect(function() self:_Switch(tab) end)

    local p = make("ScrollingFrame", {
      Size = UDim2.new(1, 0, 1, 0),
      BackgroundTransparency = 1,
      BorderSizePixel = 0,
      ScrollBarThickness = 4,
      CanvasSize = UDim2.new(0, 0, 0, 0),
      Visible = false,
      Parent = pages,
    })
    make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = p})
      local layout = make("UIListLayout", {Padding = UDim.new(0, 8), Parent = p})
      bindConnection(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 82)
      end))

      tab.Button = b
      tab.Page = p
      tab.Accent = accent
      tab.Label = tabLabel

    local function reg(ctrl)
      table.insert(tab.Controls, ctrl)
      return ctrl
    end

    function tab:CreateSection(s)
      local f = make("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = p})
      local rail = make("Frame", {
        Size = UDim2.new(0, 4, 0, 16),
        Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = theme.Colors.Accent2 or theme.Colors.Accent,
        BorderSizePixel = 0,
        Parent = f,
      })
      corner(rail, 999)
      make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 12, 0, 0), Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = theme.Colors.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Text = string.upper(tostring(s or "Section")), Parent = f})
      return reg({Frame = f, _token = string.lower(tostring(s or "")), SetVisible = function(_, v) f.Visible = v end})
    end
    
    function tab:CreateLabel(textOrCfg)
      local text = type(textOrCfg) == "table" and textOrCfg.Text or textOrCfg
      local f = make("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = p})
      local lbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Font = theme.Font,
        TextSize = 13,
        TextColor3 = theme.Colors.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = tostring(text or ""),
        Parent = f,
      })
      return reg({
        Frame = f,
        _token = string.lower(tostring(text or "")),
        SetVisible = function(_, v) f.Visible = v end,
        Set = function(_, v) lbl.Text = tostring(v or "") end,
        SetValue = function(_, v) lbl.Text = tostring(v or "") end,
      })
    end
    
    function tab:CreateParagraph(cfg)
      cfg = cfg or {}
      local title = tostring(cfg.Title or cfg.Name or "Paragraph")
      local contentText = tostring(cfg.Content or cfg.Text or "")
      local f = makeControlBase(p, theme, 58)
      local titleLbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -14, 0, 20),
        Position = UDim2.new(0, 8, 0, 4),
        Font = theme.Font,
        TextSize = 13,
        TextColor3 = theme.Colors.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = title,
        Parent = f,
      })
      local contentLbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -14, 0, 30),
        Position = UDim2.new(0, 8, 0, 24),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = theme.Colors.TextDim,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Text = contentText,
        Parent = f,
      })
      return reg({
        Frame = f,
        _token = string.lower(title .. " " .. contentText),
        SetVisible = function(_, v) f.Visible = v end,
        Set = function(_, v)
          contentLbl.Text = tostring(v or "")
        end,
        SetValue = function(_, v)
          contentLbl.Text = tostring(v or "")
        end,
        SetTitle = function(_, v)
          titleLbl.Text = tostring(v or "")
        end,
      })
    end

    function tab:CreateButton(cfg)
      cfg = cfg or {}
      local f, glow = makeControlBase(p, theme, 40)
      local btn = make("TextButton", {BackgroundTransparency = 1, Size = UDim2.new(1, -14, 1, 0), Position = UDim2.new(0, 7, 0, 0), AutoButtonColor = false, Text = tostring(cfg.Name or "Button"), Font = theme.Font, TextSize = 13, TextColor3 = theme.Colors.Text, Parent = f})
      local scale = make("UIScale", {Scale = 1, Parent = btn})
      btn.MouseEnter:Connect(function() tween(glow, theme.Anim.Fast, {BackgroundTransparency = 0.85}) end)
      btn.MouseEnter:Connect(function() tween(scale, theme.Anim.Fast, {Scale = 1.02}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end)
      btn.MouseLeave:Connect(function()
        tween(glow, theme.Anim.Fast, {BackgroundTransparency = 0.93})
        tween(scale, theme.Anim.Fast, {Scale = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
      end)
      btn.MouseButton1Down:Connect(function() addRipple(btn, theme) end)
      btn.MouseButton1Click:Connect(function()
        if type(cfg.Callback) == "function" then
          task.spawn(function()
            safeCallback(cfg.Callback)
          end)
        end
      end)
      return reg({Frame = f, _token = string.lower(tostring(cfg.Name or "")), SetVisible = function(_, v) f.Visible = v end})
    end

    function tab:CreateToggle(cfg)
      cfg = cfg or {}
      local state = cfg.CurrentValue == true
      local f = makeControlBase(p, theme, 42)
      local row = f
      make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -72, 1, 0), Position = UDim2.new(0, 10, 0, 0), Font = theme.Font, TextSize = 13, TextColor3 = theme.Colors.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(cfg.Name or "Toggle"), Parent = row})
      local sw = make("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 50, 0, 26), BackgroundColor3 = theme.Colors.Input, BorderSizePixel = 0, Text = "", AutoButtonColor = false, Parent = row})
      corner(sw, 999); stroke(sw, theme.Colors.Stroke, 1, 0.4)
      local k = make("Frame", {Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 3, 0.5, -10), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Parent = sw}); corner(k, 999)
      local function render(anim)
        local bg = state and theme.Colors.Accent or theme.Colors.Input
        local pos = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        if anim then tween(sw, theme.Anim.Fast, {BackgroundColor3 = bg}); tween(k, theme.Anim.Fast, {Position = pos}, Enum.EasingStyle.Back, Enum.EasingDirection.Out) else sw.BackgroundColor3 = bg; k.Position = pos end
      end
      sw.MouseButton1Click:Connect(function()
        state = not state
        render(true)
        safeCallback(cfg.Callback, state)
      end)
      render(false)
      return reg({
        Frame = row,
        _token = string.lower(tostring(cfg.Name or "")),
        SetVisible = function(_, v) row.Visible = v end,
        Set = function(_, v) state = v == true; render(true) end,
        SetValue = function(_, v) state = v == true; render(true) end,
        Get = function() return state end,
      })
    end
    
    function tab:CreateExpandableToggle(cfg)
      cfg = cfg or {}
      local name = tostring(cfg.Name or "Expandable")
      local enabled = cfg.CurrentValue == true
      local expanded = cfg.Expanded == true
      local children = {}
      local childHeights = {}
      local childTokens = {}
      
      local f = makeControlBase(p, theme, 42)
      local titleBtn = make("TextButton", {
        Size = UDim2.new(1, -90, 1, -8),
        Position = UDim2.new(0, 7, 0, 4),
        BackgroundColor3 = theme.Colors.Input,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        TextColor3 = theme.Colors.Text,
        Font = theme.Font,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = f,
      })
      corner(titleBtn, theme.Radius - 4)
      stroke(titleBtn, theme.Colors.Stroke, 1, 0.4)
      
      local toggleBtn = make("TextButton", {
        Size = UDim2.new(0, 48, 1, -8),
        Position = UDim2.new(1, -55, 0, 4),
        BackgroundColor3 = theme.Colors.Surface2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        TextColor3 = theme.Colors.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        Parent = f,
      })
      corner(toggleBtn, theme.Radius - 4)
      stroke(toggleBtn, theme.Colors.Stroke, 1, 0.35)
      
      local function getChildHeight(child)
        if childHeights[child] then
          return childHeights[child]
        end
        
        local frame = child and child.Frame
        local h = frame and frame.Size.Y.Offset or 42
        if h <= 1 then
          h = 42
        end
        childHeights[child] = h
        return h
      end
      
      local function setChildExpanded(child, visible, instant)
        local frame = child and child.Frame
        if not frame then
          pcall(function()
            if child and child.SetVisible then
              child:SetVisible(visible)
            end
          end)
          return
        end
        
        local currentHeight = frame.Size.Y.Offset
        if currentHeight > 1 then
          childHeights[child] = currentHeight
        end
        
        local targetHeight = getChildHeight(child)
        childTokens[child] = (childTokens[child] or 0) + 1
        local token = childTokens[child]
        frame.ClipsDescendants = true
        
        if visible then
          frame.Visible = true
          if instant then
            frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, targetHeight)
          else
            if frame.Size.Y.Offset <= 1 then
              frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 0)
            end
            tween(frame, theme.Anim.Normal, {
              Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, targetHeight),
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
          end
        else
          if instant then
            frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 0)
            frame.Visible = false
          else
            tween(frame, theme.Anim.Normal, {
              Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, 0, 0),
            }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
            task.delay(theme.Anim.Normal + 0.03, function()
              if childTokens[child] == token and frame and frame.Parent then
                frame.Visible = false
              end
            end)
          end
        end
      end
      
      local function applyChildrenVisible(instant)
        local v = expanded
        for _, child in ipairs(children) do
          setChildExpanded(child, v, instant == true)
        end
      end
      
      local function render()
        titleBtn.Text = string.format("  %s  %s", expanded and "v" or ">", name)
        toggleBtn.Text = enabled and "ON" or "OFF"
        toggleBtn.BackgroundColor3 = enabled and theme.Colors.Accent or theme.Colors.Surface2
      end
      
      titleBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        render()
        applyChildrenVisible(false)
      end)
      toggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        render()
        safeCallback(cfg.Callback, enabled)
      end)
      
      local function prefixed(source)
        local out = {}
        for k, v in pairs(source or {}) do out[k] = v end
        out.Name = "   " .. tostring(out.Name or "Item")
        return out
      end
      
      local function addChild(ctrl)
        table.insert(children, ctrl)
        if ctrl and ctrl.Frame then
          pcall(function()
            ctrl.Frame.BackgroundColor3 = theme.Colors.Input
            ctrl.Frame.Size = UDim2.new(1, -18, 0, ctrl.Frame.Size.Y.Offset)
            childHeights[ctrl] = math.max(1, ctrl.Frame.Size.Y.Offset)
          end)
        end
        setChildExpanded(ctrl, expanded, true)
        return ctrl
      end
      
      render()
      local ctrl = reg({
        Frame = f,
        _token = string.lower(name),
        SetVisible = function(_, v)
          f.Visible = v
          if not v then
            for _, child in ipairs(children) do
              pcall(function() if child and child.SetVisible then child:SetVisible(false) end end)
            end
          else
            applyChildrenVisible(true)
          end
        end,
        Set = function(_, v)
          enabled = v == true
          render()
        end,
        SetValue = function(_, v)
          enabled = v == true
          render()
        end,
        Get = function() return enabled end,
        SetExpanded = function(_, v)
          expanded = v == true
          render()
          applyChildrenVisible(false)
        end,
        GetExpanded = function() return expanded end,
      })
      
      function ctrl:CreateToggle(subCfg) return addChild(tab:CreateToggle(prefixed(subCfg))) end
      function ctrl:CreateSlider(subCfg) return addChild(tab:CreateSlider(prefixed(subCfg))) end
      function ctrl:CreateDropdown(subCfg) return addChild(tab:CreateDropdown(prefixed(subCfg))) end
      function ctrl:CreateInput(subCfg) return addChild(tab:CreateInput(prefixed(subCfg))) end
      function ctrl:CreateButton(subCfg) return addChild(tab:CreateButton(prefixed(subCfg))) end
      function ctrl:CreateKeybind(subCfg) return addChild(tab:CreateKeybind(prefixed(subCfg))) end
      function ctrl:CreateLabel(subCfg) return addChild(tab:CreateLabel(subCfg)) end
      function ctrl:CreateParagraph(subCfg) return addChild(tab:CreateParagraph(subCfg)) end
      
      applyChildrenVisible(true)
      return ctrl
    end

    function tab:CreateSlider(cfg)
      cfg = cfg or {}
      local rawMin = tonumber(cfg.Min) or (cfg.Range and cfg.Range[1]) or 0
      local rawMax = tonumber(cfg.Max) or (cfg.Range and cfg.Range[2]) or 100
      local min, max = normalizeRange(rawMin, rawMax)
      local inc = tonumber(cfg.Increment) or 1
      local val = math.clamp(tonumber(cfg.CurrentValue) or min, min, max)
      local f = makeControlBase(p, theme, 56)
      local row = f
      local name = tostring(cfg.Name or "Slider")
      local suffix = cfg.Suffix and (" " .. tostring(cfg.Suffix)) or ""
      local l = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(1, -110, 0, 20), Position = UDim2.new(0, 10, 0, 4), Font = theme.Font, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = theme.Colors.Text, Text = name, Parent = row})
      local vl = make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(0, 100, 0, 20), Position = UDim2.new(1, -108, 0, 4), Font = theme.Font, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = theme.Colors.TextDim, Text = tostring(val), Parent = row})
      local bar = make("Frame", {Size = UDim2.new(1, -20, 0, 16), Position = UDim2.new(0, 10, 0, 30), BackgroundColor3 = theme.Colors.Input, BorderSizePixel = 0, Parent = row}); corner(bar, 999); stroke(bar, theme.Colors.Stroke, 1, 0.45)
      local fill = make("Frame", {Size = UDim2.new(0,0,1,0), BackgroundColor3 = theme.Colors.Accent, BorderSizePixel = 0, Parent = bar}); corner(fill, 999)
      local knob = make("Frame", {AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.new(0,14,0,14), Position = UDim2.new(0,0,0.5,0), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Parent = bar}); corner(knob, 999)
      local dragging = false
      local function snap(v) return inc <= 0 and v or math.floor(v / inc + 0.5) * inc end
      local function render(fromDrag)
        local pct = (max == min) and 0 or ((val - min) / (max - min))
        tween(fill, fromDrag and 0.06 or theme.Anim.Fast, {Size = UDim2.new(pct,0,1,0)})
        tween(knob, fromDrag and 0.06 or theme.Anim.Fast, {Position = UDim2.new(pct,0,0.5,0)})
        vl.Text = tostring(val) .. suffix
      end
      local function setByAlpha(a, drag)
        local nv = min + (max - min) * math.clamp(a,0,1)
        val = math.clamp(snap(nv), min, max)
        render(drag)
        safeCallback(cfg.Callback, val)
      end
      local function updateMouse()
        local px = UserInputService:GetMouseLocation().X
        setByAlpha((px - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), true)
      end
      bindConnection(bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; updateMouse() end end))
      bindConnection(UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then updateMouse() end end))
      bindConnection(UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end))
      setByAlpha((val - min) / math.max(1e-6, max - min), false)
      return reg({
        Frame = row,
        _token = string.lower(name),
        SetVisible = function(_, v) row.Visible = v end,
        Set = function(_, v) val = math.clamp(tonumber(v) or min, min, max); render(false) end,
        SetValue = function(_, v) val = math.clamp(tonumber(v) or min, min, max); render(false) end,
        Get = function() return val end,
      })
    end

    function tab:CreateDropdown(cfg)
      cfg = cfg or {}
      local opts = cfg.Options or {"None"}
      local current = cfg.CurrentOption
      if type(current) == "table" then current = current[1] end
      current = current or opts[1]

      local holder = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        Parent = p,
      })

      local row, glow = makeControlBase(p, theme, 42)
      row.Parent = holder

      local btn = make("TextButton", {
        Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.new(0, 7, 0, 0),
        BackgroundTransparency = 1,
        AutoButtonColor = false,
        Text = "",
        Parent = row,
      })

      local lbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.new(0, 2, 0, 0),
        Font = theme.Font,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = theme.Colors.Text,
        Parent = btn,
      })

      local arrow = make("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 18, 0, 18),
        Font = theme.Font,
        TextSize = 14,
        TextColor3 = theme.Colors.TextDim,
        Text = ">",
        Parent = btn,
      })

      local listFrame = make("Frame", {
        Size = UDim2.new(1, -8, 0, 0),
        Position = UDim2.new(0, 4, 0, 46),
        BackgroundColor3 = theme.Colors.Input,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = holder,
      })
      corner(listFrame, theme.Radius - 2)
      stroke(listFrame, theme.Colors.Stroke, 1, 0.45)
      local listLayout = make("UIListLayout", {Padding = UDim.new(0, 4), Parent = listFrame})
      make("UIPadding", {
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
        Parent = listFrame,
      })

      local opened = false
      local itemButtons = {}
      local function updateLabel()
        lbl.Text = string.format("%s: %s", tostring(cfg.Name or "Dropdown"), tostring(current))
      end

      local function setOpened(v)
        opened = v == true
        arrow.Text = opened and "v" or ">"
        local h = opened and (listLayout.AbsoluteContentSize.Y + 12) or 0
        tween(listFrame, theme.Anim.Normal, {Size = UDim2.new(1, -8, 0, h)})
        tween(holder, theme.Anim.Normal, {Size = UDim2.new(1, 0, 0, 42 + (opened and h + 6 or 0))})
        tween(glow, theme.Anim.Fast, {BackgroundTransparency = opened and 0.84 or 0.93})
      end

      local function setValue(v, fireCallback)
        if type(v) == "table" then
          v = v[1]
        end
        current = v
        updateLabel()
        if fireCallback then
          safeCallback(cfg.Callback, v)
        end
      end
      
      local function clearItems()
        for _, btn in ipairs(itemButtons) do
          if btn and btn.Parent then
            btn:Destroy()
          end
        end
        itemButtons = {}
      end
      
      local function normalizeOptions(newOpts)
        local out = {}
        if type(newOpts) ~= "table" then
          out[1] = "None"
          return out
        end
        
        for _, opt in ipairs(newOpts) do
          out[#out + 1] = tostring(opt)
        end
        
        if #out == 0 then
          out[1] = "None"
        end
        return out
      end
      
      local function containsOption(val)
        local target = tostring(val)
        for _, opt in ipairs(opts) do
          if tostring(opt) == target then
            return true
          end
        end
        return false
      end
      
      local function rebuildItems()
        clearItems()
        for _, opt in ipairs(opts) do
          local val = tostring(opt)
          local item = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = theme.Colors.Surface,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = theme.Font,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = theme.Colors.Text,
            Text = "  " .. val,
            Parent = listFrame,
          })
          corner(item, theme.Radius - 4)
          item.MouseEnter:Connect(function() tween(item, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Surface2}) end)
          item.MouseLeave:Connect(function() tween(item, theme.Anim.Fast, {BackgroundColor3 = theme.Colors.Surface}) end)
          item.MouseButton1Click:Connect(function()
            setValue(val, true)
            setOpened(false)
          end)
          table.insert(itemButtons, item)
        end
      end
      
      local function refreshOptions(newOpts, keepCurrent)
        opts = normalizeOptions(newOpts)
        rebuildItems()
        
        local keep = keepCurrent == true and current ~= nil and containsOption(current)
        if keep then
          setValue(current, false)
        else
          setValue(opts[1], false)
        end
        
        if opened then
          setOpened(true)
        else
          setOpened(false)
        end
      end

      btn.MouseButton1Down:Connect(function() addRipple(btn, theme) end)
      btn.MouseButton1Click:Connect(function() setOpened(not opened) end)

      refreshOptions(opts, true)
      setOpened(false)

      local ctrl = {
        Frame = holder,
        _token = string.lower(string.format("%s %s", tostring(cfg.Name or ""), tostring(current))),
        SetVisible = function(_, v) holder.Visible = v end,
        Set = function(self, v)
          setValue(v, false)
          self._token = string.lower(string.format("%s %s", tostring(cfg.Name or ""), tostring(current)))
        end,
        SetValue = function(self, v)
          setValue(v, false)
          self._token = string.lower(string.format("%s %s", tostring(cfg.Name or ""), tostring(current)))
        end,
        Refresh = function(self, newOpts)
          refreshOptions(newOpts, true)
          self._token = string.lower(string.format("%s %s", tostring(cfg.Name or ""), tostring(current)))
        end,
        SetOptions = function(self, newOpts)
          refreshOptions(newOpts, true)
          self._token = string.lower(string.format("%s %s", tostring(cfg.Name or ""), tostring(current)))
        end,
        Get = function() return current end,
      }
      return reg(ctrl)
    end

    function tab:CreateInput(cfg)
      cfg = cfg or {}
      local f = makeControlBase(p, theme, 46)
      local row = f
      local name = tostring(cfg.Name or "Input")
      local removeAfterFocusLost = cfg.RemoveTextAfterFocusLost == true
      make("TextLabel", {BackgroundTransparency = 1, Size = UDim2.new(0,120,1,0), Position = UDim2.new(0,10,0,0), Font = theme.Font, TextSize = 13, TextColor3 = theme.Colors.Text, TextXAlignment = Enum.TextXAlignment.Left, Text = name, Parent = row})
      local tb = make("TextBox", {Size = UDim2.new(1,-140,0,30), Position = UDim2.new(0,130,0.5,-15), BackgroundColor3 = theme.Colors.Input, BorderSizePixel = 0, Font = theme.Font, TextSize = 13, TextColor3 = theme.Colors.Text, PlaceholderColor3 = theme.Colors.TextDim, PlaceholderText = tostring(cfg.PlaceholderText or "Type..."), Text = tostring(cfg.CurrentValue or ""), ClearTextOnFocus = false, Parent = row})
      corner(tb, theme.Radius - 4); stroke(tb, theme.Colors.Stroke, 1, 0.45)
      tb.FocusLost:Connect(function()
        safeCallback(cfg.Callback, tb.Text)
        if removeAfterFocusLost then
          tb.Text = ""
        end
      end)
      return reg({
        Frame = row,
        _token = string.lower(name),
        SetVisible = function(_, v) row.Visible = v end,
        Set = function(_, v) tb.Text = tostring(v or "") end,
        SetValue = function(_, v) tb.Text = tostring(v or "") end,
        Get = function() return tb.Text end,
      })
    end
    
    function tab:CreateKeybind(cfg)
      cfg = cfg or {}
      local name = tostring(cfg.Name or "Keybind")
      local current = tostring(cfg.CurrentKeybind or "None")
      local pending = current
      
      local f, glow = makeControlBase(p, theme, 66)
      local lbl = make("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -18, 0, 20),
        Position = UDim2.new(0, 9, 0, 4),
        Font = theme.Font,
        TextSize = 13,
        TextColor3 = theme.Colors.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = f,
      })
      local inputBox = make("TextBox", {
        Size = UDim2.new(1, -166, 0, 28),
        Position = UDim2.new(0, 9, 0, 30),
        BackgroundColor3 = theme.Colors.Input,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = theme.Font,
        TextSize = 13,
        TextColor3 = theme.Colors.Text,
        PlaceholderColor3 = theme.Colors.TextDim,
        Text = current,
        PlaceholderText = "1 Buchstabe",
        Parent = f,
      })
      corner(inputBox, theme.Radius - 4)
      stroke(inputBox, theme.Colors.Stroke, 1, 0.45)
      local applyBtn = make("TextButton", {
        Size = UDim2.new(0, 68, 0, 28),
        Position = UDim2.new(1, -150, 0, 30),
        BackgroundColor3 = theme.Colors.Accent,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = theme.Font,
        TextSize = 12,
        TextColor3 = theme.Colors.Text,
        Text = "Apply",
        Parent = f,
      })
      corner(applyBtn, theme.Radius - 4)
      local clearBtn = make("TextButton", {
        Size = UDim2.new(0, 72, 0, 28),
        Position = UDim2.new(1, -76, 0, 30),
        BackgroundColor3 = theme.Colors.Input,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = theme.Font,
        TextSize = 12,
        TextColor3 = theme.Colors.Text,
        Text = "Clear",
        Parent = f,
      })
      corner(clearBtn, theme.Radius - 4)
      
      local function renderLabel()
        lbl.Text = string.format("%s: %s", name, tostring(current))
      end
      
      local suppressTextSync = false
      local applyValue
      
      local function normalizeKeyName(value)
        local raw = tostring(value or "None")
        raw = raw:gsub("Enum.KeyCode.", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if raw == "" then return "None" end
        raw = raw:match("^[^%s,;]+") or raw
        if raw == "None" then return raw end
        local first = raw:match("^[A-Za-z]") or ""
        first = first:upper()
        if first ~= "" and Enum.KeyCode[first] then return first end
        return "None"
      end
      
      local function setPending(value)
        pending = normalizeKeyName(value)
        suppressTextSync = true
        inputBox.Text = pending
        task.defer(function()
          if inputBox and inputBox.Parent then
            inputBox.Text = pending
          end
          suppressTextSync = false
        end)
      end
      
      inputBox.Focused:Connect(function()
        pending = normalizeKeyName(inputBox.Text)
        inputBox.Text = pending
        tween(glow, theme.Anim.Fast, {BackgroundTransparency = 0.85})
      end)
      inputBox.FocusLost:Connect(function(enterPressed)
        pending = normalizeKeyName(inputBox.Text)
        inputBox.Text = pending
        tween(glow, theme.Anim.Fast, {BackgroundTransparency = 0.93})
        if enterPressed then
          applyValue(pending)
        end
      end)
      applyValue = function(value)
        current = normalizeKeyName(value)
        pending = current
        inputBox.Text = current
        renderLabel()
        safeCallback(cfg.Callback, current)
      end
      applyBtn.MouseButton1Click:Connect(function()
        addRipple(applyBtn, theme)
        applyValue(inputBox.Text)
      end)
      clearBtn.MouseButton1Click:Connect(function()
        addRipple(clearBtn, theme)
        applyValue("None")
      end)
      
      bindConnection(UserInputService.InputBegan:Connect(function(input, gp)
        if not inputBox:IsFocused() then return end
        local newName = nil
        if input.UserInputType == Enum.UserInputType.Keyboard then
          if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
            applyValue(pending)
            inputBox:ReleaseFocus()
            return
          elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
            newName = "None"
          else
            local keyName = tostring(input.KeyCode.Name)
            if #keyName == 1 and keyName:match("^[A-Za-z]$") then
              newName = keyName
            end
          end
        end
        if newName then
          setPending(newName)
        end
      end))
      bindConnection(inputBox:GetPropertyChangedSignal("Text"):Connect(function()
        if suppressTextSync or not inputBox:IsFocused() then return end
        local clean = normalizeKeyName(inputBox.Text)
        if inputBox.Text ~= clean then
          setPending(clean)
        else
          pending = clean
        end
      end))
      
      renderLabel()
      return reg({
        Frame = f,
        _token = string.lower(name),
        SetVisible = function(_, v) f.Visible = v end,
        Set = function(_, v) current = normalizeKeyName(v); pending = current; inputBox.Text = current; renderLabel() end,
        SetValue = function(_, v) current = normalizeKeyName(v); pending = current; inputBox.Text = current; renderLabel() end,
        Get = function() return current end,
        Apply = function() applyValue(pending) end,
        Clear = function() applyValue("None") end,
      })
    end

    table.insert(self._tabs, tab)
    if #self._tabs == 1 then self:_Switch(tab) end
    return tab
  end

  window.Gui = gui
  window.Root = root
  window.Shell = shell
  local openPos = UDim2.new(0.5, -sz.X / 2, 0.5, -sz.Y / 2)
  local hiddenPos = UDim2.new(0.5, -sz.X / 2, 1, sz.Y + 80)
  local slidDown = false
  local animatingToggle = false
  local function setOpenPosition(pos)
    if slidDown or animatingToggle then return end
    openPos = pos
    hiddenPos = UDim2.new(openPos.X.Scale, openPos.X.Offset, 1, sz.Y + 80)
  end
  function window:Destroy()
    for _, conn in ipairs(self._connections or {}) do
      pcall(function() conn:Disconnect() end)
    end
    self._connections = {}
    if gui and gui.Parent then gui:Destroy() end
    if islandGui and islandGui.Parent then islandGui:Destroy() end
  end
  function window:Toggle()
    slidDown = not slidDown
    self._slidDown = slidDown
    animatingToggle = true
    tween(shell, theme.Anim.Slow, {Position = slidDown and hiddenPos or openPos}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    task.delay(theme.Anim.Slow + 0.03, function()
      animatingToggle = false
    end)
  end
  function window:IsOpen()
    return slidDown ~= true
  end
  function window:Notify(n) UI.Notify(self, n) end
  
  closeBtn.MouseButton1Click:Connect(function()
    window:Toggle()
  end)

  makeDraggable(top, shell, bindConnection, setOpenPosition, setOpenPosition)
  makeDraggable(island, shell, bindConnection, setOpenPosition, setOpenPosition)

  shell.Position = UDim2.new(0.5, -sz.X / 2, 0.5, -sz.Y / 2 + 38)
  root.BackgroundTransparency = 1
  rootScale.Scale = 0.94
  root.Visible = false
  
  task.spawn(function()
    local okSplash = pcall(function()
    local splash = make("Frame", {
      Size = UDim2.new(1, 0, 1, 0),
      BackgroundColor3 = theme.Colors.BgA,
      BackgroundTransparency = 0.02,
      BorderSizePixel = 0,
      Parent = gui,
    })
    local sgrad = make("UIGradient", {
      Rotation = 24,
      Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, theme.Colors.BgB),
        ColorSequenceKeypoint.new(0.55, theme.Colors.Input),
        ColorSequenceKeypoint.new(1, theme.Colors.BgA),
      }),
      Parent = splash,
    })
    local _ = sgrad
    local splashLogo = createNovaMark(splash, theme, 86, logoSource, logoRectOffset, logoRectSize)
    splashLogo.AnchorPoint = Vector2.new(0.5, 0.5)
    splashLogo.Position = UDim2.new(0.5, 0, 0.5, -62)
    local stext = make("TextLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, 50),
      Position = UDim2.new(0, 0, 0.5, 6),
      Font = Enum.Font.GothamBold,
      TextSize = 30,
      Text = tostring(opts.LoadingTitle or opts.Title or opts.Name or "NovaX"),
      TextColor3 = theme.Colors.Text,
      Parent = splash,
    })
    local subText = make("TextLabel", {
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, 24),
      Position = UDim2.new(0, 0, 0.5, 48),
      Font = theme.Font,
      TextSize = 13,
      Text = tostring(opts.LoadingSubtitle or opts.Subtitle or "Loading interface"),
      TextColor3 = theme.Colors.TextDim,
      Parent = splash,
    })
    local splashScale = make("UIScale", {Scale = 0.92, Parent = splashLogo})
    tween(splashScale, theme.Anim.Splash * 0.58, {Scale = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    tween(stext, theme.Anim.Splash * 0.22, {TextTransparency = 0}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    task.wait(theme.Anim.Splash * 0.52)
    root.Visible = true
    tween(shell, theme.Anim.Slow, {Position = openPos}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    tween(root, theme.Anim.Slow, {BackgroundTransparency = 0})
    tween(rootScale, theme.Anim.Slow, {Scale = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    task.wait(theme.Anim.Splash * 0.06)
    tween(splash, theme.Anim.Splash * 0.45, {BackgroundTransparency = 1})
    tween(stext, theme.Anim.Splash * 0.45, {TextTransparency = 1})
    tween(subText, theme.Anim.Splash * 0.45, {TextTransparency = 1})
    tween(splashLogo, theme.Anim.Splash * 0.45, {BackgroundTransparency = 1})
    task.wait(theme.Anim.Splash * 0.45)
    if splash and splash.Parent then splash:Destroy() end
    end)
    if not okSplash then
      root.Visible = true
      tween(shell, theme.Anim.Slow, {Position = openPos}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
      tween(root, theme.Anim.Slow, {BackgroundTransparency = 0})
      tween(rootScale, theme.Anim.Slow, {Scale = 1}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    end
  end)

  if opts.ShowWelcome == true then
    window:Notify({Title = tostring(opts.Title or "Nova Premium UI"), Content = "Initialized", Duration = 5})
  end

  if UI.Debug then
    warn("[NovaPremiumUI][debug] CreateWindow completed for:", tostring(opts.Name or "NovaPremiumUI"))
  end
  return window
end

function UI:CreateConfigManager(window, stateTable, opts)
  opts = opts or {}
  local folder = tostring(opts.Folder or "NovaConfigs")
  local defaultName = tostring(opts.DefaultName or "default")
  local sync = opts.Sync
  local tabName = tostring(opts.TabName or "Configs")
  local activeName = defaultName
  local selectedName = defaultName
  local configDropdown
  local configInput
  local busy = false
  local refresh
  local hiddenDeleted = {}

  local function cleanName(name)
    local raw = tostring(name or defaultName)
    local clean = raw:gsub("[^%w_%-%s]", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_")
    return clean ~= "" and clean or defaultName
  end

  local function ensureFolder()
    if typeof(makefolder) == "function" and typeof(isfolder) == "function" and not isfolder(folder) then
      pcall(function() makefolder(folder) end)
    end
  end

  local function pathFor(name)
    return folder .. "/" .. cleanName(name) .. ".json"
  end

  local manager = {}
  
  local function notifyConfig(title, content)
    if window and window.Notify then
      window:Notify({Title = tostring(title or "Config"), Content = tostring(content or ""), Duration = 5})
    end
  end
  
  local function fileExists(name)
    return typeof(isfile) == "function" and isfile(pathFor(name))
  end
  
  local function uniqueName(base)
    local root = cleanName(base or "config")
    local used = {}
    for _, item in ipairs(manager:List()) do
      used[tostring(item)] = true
    end
    if not used[root] and not fileExists(root) then
      return root
    end
    for index = 1, 999 do
      local candidate = cleanName(root .. "_" .. tostring(index))
      if not used[candidate] and not fileExists(candidate) then
        return candidate
      end
    end
    return cleanName(root .. "_" .. tostring(math.floor(tick())))
  end

  function manager:List()
    ensureFolder()
    local out = {}
    if typeof(listfiles) == "function" and typeof(isfolder) == "function" and isfolder(folder) then
      local ok, files = pcall(function() return listfiles(folder) end)
      if ok and type(files) == "table" then
        for index = 1, #files do
          local f = files[index]
          local n = tostring(f):match("([^/\\]+)%.json$")
          if n and not hiddenDeleted[n] then table.insert(out, n) end
        end
      end
    end
    table.sort(out)
    if #out == 0 then table.insert(out, defaultName) end
    return out
  end

  function manager:Save(name)
    ensureFolder()
    if typeof(writefile) ~= "function" then return false, "writefile unavailable" end
    local targetName = cleanName(name or activeName)
    local payload = {}
    for k, v in pairs(stateTable or {}) do
      local tv = type(v)
      if tv == "boolean" or tv == "number" or tv == "string" then
        payload[k] = v
      end
    end
    local ok, err = pcall(function()
      writefile(pathFor(targetName), HttpService:JSONEncode(payload))
    end)
    if ok then
      activeName = targetName
      selectedName = targetName
      hiddenDeleted[targetName] = nil
    end
    return ok, ok and targetName or tostring(err)
  end

  function manager:Load(name)
    ensureFolder()
    if typeof(readfile) ~= "function" or typeof(isfile) ~= "function" then return false, "readfile/isfile unavailable" end
    local targetName = cleanName(name or activeName)
    local path = pathFor(targetName)
    if not isfile(path) then return false, "config missing" end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
    if not ok or type(data) ~= "table" then return false, "invalid config" end
    for k, v in pairs(data) do
      if stateTable and stateTable[k] ~= nil and type(stateTable[k]) == type(v) then
        stateTable[k] = v
      end
    end
    if type(sync) == "function" then pcall(sync, stateTable) end
    activeName = targetName
    selectedName = targetName
    return true, targetName
  end

  function manager:Delete(name)
    if typeof(delfile) ~= "function" then return false, "delfile unavailable" end
    local targetName = cleanName(name or activeName)
    local path = pathFor(targetName)
    if typeof(isfile) == "function" and not isfile(path) then
      hiddenDeleted[targetName] = true
      return true, targetName
    end
    local ok, err = pcall(function() delfile(path) end)
    if ok then
      hiddenDeleted[targetName] = true
    end
    if ok and activeName == targetName then
      activeName = defaultName
      selectedName = defaultName
    end
    return ok, ok and targetName or tostring(err)
  end
  
  function manager:Rename(oldName, newName)
    ensureFolder()
    if typeof(readfile) ~= "function" or typeof(writefile) ~= "function" then
      return false, "readfile/writefile unavailable"
    end
    local sourceName = cleanName(oldName or selectedName or activeName)
    local targetName = cleanName(newName or sourceName)
    if sourceName == targetName then
      activeName = targetName
      selectedName = targetName
      return true, targetName
    end
    local sourcePath = pathFor(sourceName)
    local targetPath = pathFor(targetName)
    if typeof(isfile) == "function" and not isfile(sourcePath) then
      return false, "source config missing"
    end
    if typeof(isfile) == "function" and isfile(targetPath) then
      return false, "target config exists"
    end
    local okRead, data = pcall(function() return readfile(sourcePath) end)
    if not okRead then
      return false, tostring(data)
    end
    local okWrite, writeErr = pcall(function() writefile(targetPath, data) end)
    if not okWrite then
      return false, tostring(writeErr)
    end
    if typeof(delfile) == "function" then
      pcall(function() delfile(sourcePath) end)
    end
    hiddenDeleted[sourceName] = true
    hiddenDeleted[targetName] = nil
    activeName = targetName
    selectedName = targetName
    return true, targetName
  end

  if window and window.CreateTab then
    local tab = window:CreateTab(tabName)
    configInput = tab:CreateInput({
      Name = "Config Name",
      CurrentValue = activeName,
      PlaceholderText = defaultName,
      Callback = function() end,
    })
    configDropdown = tab:CreateDropdown({
      Name = "Saved Configs",
      Options = manager:List(),
      CurrentOption = {activeName},
      Callback = function(v)
        selectedName = cleanName(type(v) == "table" and v[1] or v)
        activeName = selectedName
        if configInput and configInput.Set then
          configInput:Set(selectedName)
        end
        if not busy then
          busy = true
          local ok, loaded = manager:Load(selectedName)
          refresh(ok and loaded or selectedName)
          busy = false
        end
      end,
    })
    local function currentInputName()
      if configInput and configInput.Get then
        local raw = tostring(configInput:Get() or "")
        if raw ~= "" then
          return cleanName(raw)
        end
      end
      return cleanName(activeName)
    end
    local function currentSelectedName()
      return cleanName(selectedName or activeName or currentInputName())
    end
    local function runConfigAction(action)
      if busy then return false end
      busy = true
      local ok, err = pcall(action)
      if not ok then
        warn("[NovaPremiumUI] Config action failed: " .. tostring(err))
        notifyConfig("Config Fehler", tostring(err))
      end
      busy = false
      return ok
    end
    refresh = function(selectName)
      if configDropdown and configDropdown.Refresh then
        local names = manager:List()
        local selected = cleanName(selectName or activeName)
        local exists = false
        for _, item in ipairs(names) do
          if tostring(item) == selected then
            exists = true
            break
          end
        end
        if not exists then
          selected = names[1] or defaultName
        end
        activeName = selected
        selectedName = selected
        configDropdown:Refresh(names)
        if configDropdown.Set then
          configDropdown:Set(selected)
        end
        if configInput and configInput.Set then
          configInput:Set(selected)
        end
      end
    end
    tab:CreateButton({Name = "Save Config", Callback = function()
      runConfigAction(function()
        local ok, saved = manager:Save(currentInputName())
        notifyConfig(ok and "Config gespeichert" or "Config Fehler", ok and ("Gespeichert: " .. tostring(saved)) or tostring(saved))
        refresh(ok and saved or activeName)
      end)
    end})
    tab:CreateButton({Name = "New Config", Callback = function()
      runConfigAction(function()
        local name = uniqueName("config")
        local ok, saved = manager:Save(name)
        notifyConfig(ok and "Config erstellt" or "Config Fehler", ok and ("Erstellt: " .. tostring(saved)) or tostring(saved))
        refresh(ok and saved or activeName)
      end)
    end})
    tab:CreateButton({Name = "Rename Config", Callback = function()
      runConfigAction(function()
        local oldName = currentSelectedName()
        local newName = currentInputName()
        local ok, renamed = manager:Rename(oldName, newName)
        notifyConfig(ok and "Config umbenannt" or "Config Fehler", ok and ("Umbenannt: " .. tostring(renamed)) or tostring(renamed))
        refresh(ok and renamed or activeName)
      end)
    end})
    tab:CreateButton({Name = "Load Config", Callback = function()
      runConfigAction(function()
        local ok, loaded = manager:Load(currentInputName())
        notifyConfig(ok and "Config geladen" or "Config Fehler", ok and ("Geladen: " .. tostring(loaded)) or tostring(loaded))
        refresh(ok and loaded or activeName)
      end)
    end})
    tab:CreateButton({Name = "Delete Config", Callback = function()
      local targetName = currentSelectedName()
      local function deleteSelected()
        runConfigAction(function()
          local ok, deleted = manager:Delete(targetName)
          notifyConfig(ok and "Config geloescht" or "Config Fehler", ok and ("Geloescht: " .. tostring(deleted)) or tostring(deleted))
          refresh()
        end)
      end
      if window and window.Confirm then
        window:Confirm({
          Title = "Config loeschen",
          Content = "Moechtest du wirklich Config \"" .. tostring(targetName) .. "\" loeschen?",
          ConfirmText = "Loeschen",
          CancelText = "Abbrechen",
          ConfirmCallback = deleteSelected,
        })
      else
        deleteSelected()
      end
    end})
    tab:CreateButton({Name = "Refresh Configs", Callback = refresh})
  end

  return manager
end

local exported = setmetatable({}, UI)

if getgenv then
  getgenv().NovaPremiumUI = exported
end

return exported
end)()

if getgenv then
  getgenv().NovaPremiumUI = NovaPremiumUI
end

return NovaPremiumUI
