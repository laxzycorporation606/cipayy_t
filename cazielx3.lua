local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

if _G.__CAZX_CLEANUP then pcall(_G.__CAZX_CLEANUP) end

local APP_NAME = "CAZIELX"
local EDITION = "ARCHX"
local VERSION = "1.0.7"
local BUILD = "20261110"
local CONFIG_FILE = "CAZIELX_ARCHX_config.json"
local IS_TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled
local HAS_FILES = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
local HAS_CLIPBOARD = typeof(setclipboard) == "function"
local HAS_FPSCAP = typeof(setfpscap) == "function"
local HTTP_REQUEST = (typeof(request) == "function" and request) or (typeof(http_request) == "function" and http_request) or nil
local FONT, BOLD, MONO = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.Code

local alive = true
local S = { _tab = "Home" }
local notify, markDirty, updateActive, applyScale, switchTab, applyTheme, placeAll
-- Single source of truth for window / floating-icon positions: fractions (0..1) of the ScreenGui size.
-- Never derived from AbsolutePosition, so Tween / scale / inset changes cannot accumulate offsets.
local POS = { win = { x = .5, y = .5 }, float = { x = -1, y = .5 } } -- float.x < 0 = default edge position

local function newBag()
    local items, bag = {}, {}
    function bag.add(x) items[#items + 1] = x return x end
    function bag.clear()
        for i = #items, 1, -1 do
            local x = items[i]
            items[i] = nil
            pcall(function()
                local t = typeof(x)
                if t == "RBXScriptConnection" then x:Disconnect()
                elseif t == "Instance" then x:Destroy()
                elseif t == "function" then x() end
            end)
        end
    end
    return bag
end
local Root = newBag()

local function getHum()
    local c = Player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function hookCharacter(bag, fn)
    local cb = newBag()
    bag.add(cb.clear)
    local function go(c) cb.clear() fn(c, cb) end
    if Player.Character then task.spawn(go, Player.Character) end
    bag.add(Player.CharacterAdded:Connect(function(c) task.spawn(go, c) end))
end

local PRESET_ORDER = { "Obsidian Dark", "Midnight Blue", "Crimson Core", "Cyber Violet", "Emerald Matrix", "Arctic Light", "Pure Black" }
local PRESETS = {
    ["Obsidian Dark"] = { Bg = Color3.fromRGB(10, 10, 13), Panel = Color3.fromRGB(18, 18, 22), Border = Color3.fromRGB(46, 48, 58), Accent = Color3.fromRGB(64, 196, 255), Text = Color3.fromRGB(236, 240, 248), Sub = Color3.fromRGB(132, 140, 158) },
    ["Midnight Blue"] = { Bg = Color3.fromRGB(8, 12, 26), Panel = Color3.fromRGB(13, 20, 40), Border = Color3.fromRGB(32, 48, 88), Accent = Color3.fromRGB(62, 136, 255), Text = Color3.fromRGB(230, 238, 255), Sub = Color3.fromRGB(122, 140, 180) },
    ["Crimson Core"] = { Bg = Color3.fromRGB(12, 8, 9), Panel = Color3.fromRGB(21, 12, 14), Border = Color3.fromRGB(62, 30, 34), Accent = Color3.fromRGB(238, 66, 84), Text = Color3.fromRGB(246, 232, 234), Sub = Color3.fromRGB(160, 130, 136) },
    ["Cyber Violet"] = { Bg = Color3.fromRGB(10, 8, 18), Panel = Color3.fromRGB(18, 13, 32), Border = Color3.fromRGB(50, 36, 90), Accent = Color3.fromRGB(158, 94, 255), Text = Color3.fromRGB(240, 234, 255), Sub = Color3.fromRGB(144, 130, 178) },
    ["Emerald Matrix"] = { Bg = Color3.fromRGB(6, 13, 11), Panel = Color3.fromRGB(10, 22, 18), Border = Color3.fromRGB(26, 62, 50), Accent = Color3.fromRGB(40, 214, 142), Text = Color3.fromRGB(228, 248, 240), Sub = Color3.fromRGB(116, 156, 140) },
    ["Arctic Light"] = { Bg = Color3.fromRGB(234, 240, 248), Panel = Color3.fromRGB(255, 255, 255), Border = Color3.fromRGB(204, 214, 228), Accent = Color3.fromRGB(0, 120, 255), Text = Color3.fromRGB(20, 28, 44), Sub = Color3.fromRGB(94, 106, 128) },
    ["Pure Black"] = { Bg = Color3.fromRGB(0, 0, 0), Panel = Color3.fromRGB(7, 7, 9), Border = Color3.fromRGB(32, 32, 38), Accent = Color3.fromRGB(122, 172, 255), Text = Color3.fromRGB(238, 238, 244), Sub = Color3.fromRGB(128, 128, 140) },
}
local ACCENT_SWATCHES = { "#40c4ff", "#3e88ff", "#9e5eff", "#ee4254", "#28d68e", "#ffb84d", "#ff6ec7", "#ffffff" }

local T = {}

local function hexColor(h)
    if type(h) == "string" and h:match("^#%x%x%x%x%x%x$") then
        local ok, c = pcall(Color3.fromHex, h)
        if ok then return c end
    end
    return nil
end

local function lum(c) return .2126 * c.R + .7152 * c.G + .0722 * c.B end

local function computeTheme()
    local p = PRESETS[S.theme_preset] or PRESETS["Obsidian Dark"]
    local bg = hexColor(S.theme_bg) or p.Bg
    local panel = hexColor(S.theme_panel) or p.Panel
    local border = hexColor(S.theme_border) or p.Border
    local accent = hexColor(S.theme_accent) or p.Accent
    local tx = hexColor(S.theme_text) or p.Text
    local sub = hexColor(S.theme_sub) or p.Sub
    local light = lum(bg) > .6
    T.Bg, T.Panel, T.Border, T.Accent, T.Text, T.Sub = bg, panel, border, accent, tx, sub
    T.Card = panel:Lerp(tx, light and .04 or .05)
    T.CardHover = panel:Lerp(tx, light and .09 or .1)
    T.Off = panel:Lerp(tx, .22)
    T.AccentDim = accent:Lerp(bg, light and .72 or .62)
    T.OnAccent = lum(accent) > .55 and Color3.fromRGB(10, 12, 18) or Color3.fromRGB(250, 252, 255)
    T.Good = light and Color3.fromRGB(14, 156, 92) or Color3.fromRGB(60, 220, 140)
    T.Warn = light and Color3.fromRGB(196, 120, 0) or Color3.fromRGB(255, 184, 77)
    T.Bad = light and Color3.fromRGB(205, 38, 56) or Color3.fromRGB(255, 84, 98)
    T.Tr = math.clamp(S.theme_tr or 0, 0, .6)
    T.Light = light
end
computeTheme()

local bindings = {}
local COLOR_PROPS = { BackgroundColor3 = true, TextColor3 = true, ImageColor3 = true, Color = true, ScrollBarImageColor3 = true, PlaceholderColor3 = true }

local function bind(o, prop, key)
    bindings[#bindings + 1] = { o, prop, key }
    o[prop] = T[key]
end

local function pruneBindings()
    local j = 0
    for i = 1, #bindings do
        local b = bindings[i]
        if b[1].Parent then j += 1 bindings[j] = b end
    end
    for i = #bindings, j + 1, -1 do bindings[i] = nil end
end

local activeTween = setmetatable({}, { __mode = "k" })
local function tween(obj, t, props, style, dir)
    local k = S.anim_level
    if k == nil then k = 1 end
    local reg = activeTween[obj]
    if not reg then reg = {} activeTween[obj] = reg end
    for prop, val in pairs(props) do
        local old = reg[prop]
        if old then old:Cancel() reg[prop] = nil end
        if k <= 0 then
            obj[prop] = val
        else
            local tw = TweenService:Create(obj, TweenInfo.new(math.max(t * k, .03), style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), { [prop] = val })
            reg[prop] = tw
            tw:Play()
        end
    end
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if type(v) == "string" and (COLOR_PROPS[k] or k == "BackgroundTransparency") then bind(o, k, v)
        else o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end
local function round(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function stroke(o, key, th, tr)
    return new("UIStroke", { Color = key or "Border", Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function text(parent, t, size, key, bold, extra)
    local p = { BackgroundTransparency = 1, Text = t, TextSize = size, TextColor3 = key or "Text",
        Font = bold and BOLD or FONT, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, BorderSizePixel = 0 }
    if extra then for k, v in pairs(extra) do p[k] = v end end
    return new("TextLabel", p, parent)
end

local ICON_DEFS = {
    home = { { "l", 3, 12, 12, 4 }, { "l", 12, 4, 21, 12 }, { "l", 6, 11, 6, 20 }, { "l", 18, 11, 18, 20 }, { "l", 6, 20, 18, 20 } },
    farm = { { "l", 12, 21, 12, 10 }, { "l", 12, 14, 6, 9 }, { "l", 12, 11, 18, 6 }, { "l", 7, 21, 17, 21 } },
    automation = { { "l", 13, 3, 6, 13 }, { "l", 6, 13, 12, 13 }, { "l", 12, 13, 10, 21 }, { "l", 10, 21, 18, 10 }, { "l", 18, 10, 12, 10 }, { "l", 12, 10, 13, 3 } },
    movement = { { "l", 5, 19, 19, 5 }, { "l", 10, 5, 19, 5 }, { "l", 19, 5, 19, 14 } },
    visuals = { { "o", 3, 7, 18, 10, 5 }, { "d", 12, 12, 2.6 } },
    player = { { "c", 12, 8, 4 }, { "o", 5, 14, 14, 8, 5 } },
    statistics = { { "f", 5, 12, 3, 8, 1 }, { "f", 10.5, 7, 3, 13, 1 }, { "f", 16, 4, 3, 16, 1 } },
    server = { { "o", 4, 4, 16, 6, 2 }, { "o", 4, 14, 16, 6, 2 }, { "d", 8, 7, 1 }, { "d", 8, 17, 1 } },
    settings = { { "l", 4, 8, 20, 8 }, { "l", 4, 16, 20, 16 }, { "d", 9, 8, 2.8 }, { "d", 15, 16, 2.8 } },
    diagnostics = { { "l", 3, 12, 8, 12 }, { "l", 8, 12, 10, 6 }, { "l", 10, 6, 14, 18 }, { "l", 14, 18, 16, 12 }, { "l", 16, 12, 21, 12 } },
    about = { { "c", 12, 12, 9 }, { "l", 12, 11, 12, 17 }, { "d", 12, 7.6, 1.1 } },
    theme = { { "c", 12, 12, 9 }, { "d", 8, 10, 1.4 }, { "d", 12, 7, 1.4 }, { "d", 16, 10, 1.4 } },
    search = { { "c", 10.5, 10.5, 6.5 }, { "l", 15.5, 15.5, 20, 20 } },
    notification = { { "o", 6, 5, 12, 11, 6 }, { "l", 4, 17, 20, 17 }, { "d", 12, 20, 1.6 } },
    minimize = { { "l", 6, 17, 18, 17 } },
    close = { { "l", 6, 6, 18, 18 }, { "l", 18, 6, 6, 18 } },
    expand = { { "o", 4, 4, 16, 16, 3 } },
    collapse = { { "o", 4, 8, 12, 12, 2 }, { "l", 8, 4, 20, 4 }, { "l", 20, 4, 20, 16 } },
    save = { { "o", 4, 4, 16, 16, 2 }, { "l", 8, 4, 8, 9 }, { "l", 8, 9, 16, 9 }, { "o", 8, 14, 8, 6, 1 } },
    reset = { { "c", 12, 13, 7 }, { "l", 6, 3, 6, 9 }, { "l", 6, 9, 12, 9 } },
    refresh = { { "c", 12, 12, 7 }, { "l", 18, 3, 18, 9 }, { "l", 18, 9, 12, 9 } },
    import = { { "l", 12, 4, 12, 15 }, { "l", 8, 11, 12, 15 }, { "l", 16, 11, 12, 15 }, { "l", 5, 20, 19, 20 } },
    export = { { "l", 12, 16, 12, 5 }, { "l", 8, 9, 12, 5 }, { "l", 16, 9, 12, 5 }, { "l", 5, 20, 19, 20 } },
    play = { { "l", 8, 5, 19, 12 }, { "l", 19, 12, 8, 19 }, { "l", 8, 19, 8, 5 } },
    pause = { { "f", 7, 5, 3, 14, 1 }, { "f", 14, 5, 3, 14, 1 } },
    stop = { { "f", 6, 6, 12, 12, 2 } },
    chevron = { { "l", 6, 9, 12, 15 }, { "l", 12, 15, 18, 9 } },
    check = { { "l", 5, 12, 10, 17 }, { "l", 10, 17, 19, 7 } },
    warning = { { "l", 12, 4, 21, 19 }, { "l", 21, 19, 3, 19 }, { "l", 3, 19, 12, 4 }, { "l", 12, 10, 12, 14 }, { "d", 12, 16.8, 1 } },
    error = { { "c", 12, 12, 9 }, { "l", 8.5, 8.5, 15.5, 15.5 }, { "l", 15.5, 8.5, 8.5, 15.5 } },
    menu = { { "l", 4, 7, 20, 7 }, { "l", 4, 12, 20, 12 }, { "l", 4, 17, 20, 17 } },
    logo = { { "c", 12, 12, 10 }, { "o", 7.5, 7.5, 9, 9, 1, 45 }, { "d", 12, 12, 1.8 } },
}

local Icons = {}
local function iconColor(ic)
    if ic.override then return ic.override end
    if ic.state == "hover" then return T.Text end
    if ic.state == "active" then return T.Accent end
    if ic.state == "disabled" then return T.Off end
    return T.Sub
end
local function paintIcon(ic, animate)
    local col = iconColor(ic)
    for _, pt in ipairs(ic.parts) do
        local prop = pt[2] == "stroke" and "Color" or "BackgroundColor3"
        if animate then tween(pt[1], .16, { [prop] = col }) else pt[1][prop] = col end
    end
end
local function CreateIcon(name, size, parent, props)
    local def = ICON_DEFS[name] or ICON_DEFS.about
    local k = size / 24
    local th = math.max(1.5, 1.9 * k)
    local root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), BorderSizePixel = 0 }, parent)
    if props then for a, b in pairs(props) do root[a] = b end end
    local ic = { root = root, parts = {}, state = "normal", name = name, size = size }
    local function add(inst, mode) ic.parts[#ic.parts + 1] = { inst, mode } end
    for _, d in ipairs(def) do
        local kind = d[1]
        if kind == "l" then
            local dx, dy = (d[4] - d[2]) * k, (d[5] - d[3]) * k
            local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset((d[2] + d[4]) / 2 * k, (d[3] + d[5]) / 2 * k),
                Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th * .5, th), Rotation = math.deg(math.atan2(dy, dx)), BorderSizePixel = 0 }, root)
            new("UICorner", { CornerRadius = UDim.new(.5, 0) }, f)
            add(f, "bg")
        elseif kind == "d" then
            local r = d[4] * k
            local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(d[2] * k, d[3] * k), Size = UDim2.fromOffset(r * 2, r * 2), BorderSizePixel = 0 }, root)
            new("UICorner", { CornerRadius = UDim.new(.5, 0) }, f)
            add(f, "bg")
        elseif kind == "c" then
            local r = d[4] * k
            local f = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(d[2] * k, d[3] * k), Size = UDim2.fromOffset(r * 2 - th, r * 2 - th), BackgroundTransparency = 1, BorderSizePixel = 0 }, root)
            new("UICorner", { CornerRadius = UDim.new(.5, 0) }, f)
            add(new("UIStroke", { Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f), "stroke")
        elseif kind == "o" then
            local f = new("Frame", { Position = UDim2.fromOffset(d[2] * k + th / 2, d[3] * k + th / 2), Size = UDim2.fromOffset(d[4] * k - th, d[5] * k - th),
                BackgroundTransparency = 1, BorderSizePixel = 0, Rotation = d[7] or 0 }, root)
            new("UICorner", { CornerRadius = UDim.new(0, d[6] * k) }, f)
            add(new("UIStroke", { Thickness = th, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f), "stroke")
        elseif kind == "f" then
            local f = new("Frame", { Position = UDim2.fromOffset(d[2] * k, d[3] * k), Size = UDim2.fromOffset(d[4] * k, d[5] * k), BorderSizePixel = 0 }, root)
            new("UICorner", { CornerRadius = UDim.new(0, d[6] * k) }, f)
            add(f, "bg")
        end
    end
    Icons[#Icons + 1] = ic
    paintIcon(ic, false)
    return ic
end
local function SetIconColor(ic, color)
    if not ic or not ic.root.Parent then return end
    ic.override = color
    paintIcon(ic, true)
end
local function SetIconState(ic, state)
    if not ic or not ic.root.Parent or ic.state == state then return end
    ic.state = state
    ic.override = nil
    paintIcon(ic, true)
end
local function DestroyIcon(ic)
    if not ic then return end
    local i = table.find(Icons, ic)
    if i then table.remove(Icons, i) end
    if ic.root then ic.root:Destroy() end
end
local function refreshIcons(animate)
    local j = 0
    for i = 1, #Icons do
        local ic = Icons[i]
        if ic.root.Parent then j += 1 Icons[j] = ic paintIcon(ic, animate) end
    end
    for i = #Icons, j + 1, -1 do Icons[i] = nil end
end
local function iconHover(btn, ic, isActive)
    if IS_TOUCH then return end
    btn.MouseEnter:Connect(function() if not isActive or not isActive() then SetIconState(ic, "hover") end end)
    btn.MouseLeave:Connect(function() SetIconState(ic, (isActive and isActive()) and "active" or "normal") end)
end

local Tabs, TabByName, Feat, FeatList = {}, {}, {}, {}

local function addTab(name, icon)
    local t = { name = name, icon = icon, items = {} }
    Tabs[#Tabs + 1] = t
    TabByName[name] = t
    return t
end

local function def(tabName, id, f)
    assert(not Feat[id], "duplicate feature id " .. id)
    f.id, f.tab, f.views = id, tabName, {}
    Feat[id] = f
    FeatList[#FeatList + 1] = f
    table.insert(TabByName[tabName].items, f)
    if f.kind == "toggle" then S[id] = false
    elseif f.kind == "slider" or f.kind == "dropdown" then S[id] = f.default
    elseif f.kind == "color" then S[id] = "" end
    return f
end

local NEEDS = "Needs this game's own remotes/objects. They are not verified, so nothing is faked."
local function na(tabName, id, name, desc, reason, badge)
    def(tabName, id, { kind = "toggle", name = name, desc = desc, unavailable = reason or NEEDS, badge = badge or "NEEDS INTEGRATION" })
end

local function refreshViews(f)
    for _, u in pairs(f.views) do pcall(u) end
end

local function valid(f, v)
    if f.kind == "slider" then return type(v) == "number" end
    if f.kind == "dropdown" then return type(v) == "string" and table.find(f.options, v) ~= nil end
    if f.kind == "color" then return type(v) == "string" and (v == "" or hexColor(v) ~= nil) end
    if f.kind == "toggle" then return type(v) == "boolean" end
    return false
end

local function setValue(id, v, silent)
    local f = Feat[id]
    if not f then return false end
    if f.kind == "toggle" then
        v = (v == true)
        if v and f.unavailable then
            if not silent then notify(f.name .. ": " .. f.unavailable, "warn", 4) end
            refreshViews(f)
            return false
        end
        if S[id] == v then refreshViews(f) return true end
        if v then
            local ok, r1, r2 = pcall(f.fn, true)
            if not ok then
                warn("[CAZX] " .. f.name .. ": " .. tostring(r1))
                pcall(f.fn, false)
                S[id] = false
                notify(f.name .. " failed to start", "bad")
                refreshViews(f) updateActive()
                return false
            end
            if r1 == false then
                pcall(f.fn, false)
                S[id] = false
                notify(r2 or (f.name .. " is not available"), "warn", 4)
                refreshViews(f) updateActive()
                return false
            end
            S[id] = true
            if not silent then notify(f.name .. " enabled", "good", 1.6) end
        else
            local ok, err = pcall(f.fn, false)
            if not ok then warn("[CAZX] " .. f.name .. " cleanup: " .. tostring(err)) end
            S[id] = false
            if not silent then notify(f.name .. " disabled", "info", 1.4) end
        end
        updateActive()
    elseif f.kind == "slider" then
        if type(v) ~= "number" or f.unavailable then return false end
        local step = f.step or 1
        v = math.clamp(math.floor(v / step + .5) * step, f.min, f.max)
        v = tonumber(string.format("%.4f", v))
        if S[id] == v then return true end
        S[id] = v
        if f.fn then
            local ok, err = pcall(f.fn, v)
            if not ok then warn("[CAZX] " .. f.name .. ": " .. tostring(err)) end
        end
    elseif f.kind == "dropdown" then
        if f.unavailable or not table.find(f.options, v) then return false end
        if S[id] == v then refreshViews(f) return true end
        S[id] = v
        if f.fn then pcall(f.fn, v) end
    elseif f.kind == "color" then
        if not valid(f, v) then return false end
        v = v:lower()
        if S[id] == v then refreshViews(f) return true end
        S[id] = v
        if f.fn then pcall(f.fn, v) end
    end
    refreshViews(f)
    markDirty()
    return true
end

local memoryConfig
local dirty = false
local THEME_IDS = { "theme_preset", "theme_accent", "theme_bg", "theme_panel", "theme_border", "theme_text", "theme_sub", "theme_tr", "anim_level", "ui_scale" }

local function encodeConfig()
    local out = { v = 2, tab = S._tab, state = {}, pos = { wx = POS.win.x, wy = POS.win.y, fx = POS.float.x, fy = POS.float.y } }
    for _, f in ipairs(FeatList) do
        if f.kind == "toggle" or f.kind == "slider" or f.kind == "dropdown" or f.kind == "color" then out.state[f.id] = S[f.id] end
    end
    return HttpService:JSONEncode(out)
end

local function applyConfig(data)
    if type(data) ~= "table" or type(data.state) ~= "table" then return false, "Invalid config structure" end
    local applied, skipped = 0, 0
    for pass = 1, 2 do
        for _, f in ipairs(FeatList) do
            local isToggle = f.kind == "toggle"
            if (pass == 1 and not isToggle) or (pass == 2 and isToggle) then
                local v = data.state[f.id]
                if v ~= nil then
                    if valid(f, v) and not (isToggle and v and f.unavailable) and not (f.unavailable and not isToggle) then
                        setValue(f.id, v, true)
                        applied += 1
                    else
                        skipped += 1
                    end
                end
            end
        end
    end
    for k in pairs(data.state) do if not Feat[k] then skipped += 1 end end
    if type(data.pos) == "table" then
        local function n(v, d) return (type(v) == "number" and v == v and v >= -1 and v <= 1) and v or d end
        POS.win.x, POS.win.y = math.clamp(n(data.pos.wx, .5), 0, 1), math.clamp(n(data.pos.wy, .5), 0, 1)
        local fx = n(data.pos.fx, -1)
        POS.float.x, POS.float.y = fx < 0 and -1 or math.clamp(fx, 0, 1), math.clamp(n(data.pos.fy, .5), 0, 1)
        if placeAll then placeAll() end
    end
    if type(data.tab) == "string" and TabByName[data.tab] and TabByName[data.tab].page then switchTab(data.tab, true) end
    return true, ("Applied %d, skipped %d"):format(applied, skipped)
end

local function importJSON(str)
    if type(str) ~= "string" or str:match("^%s*$") then return false, "Config is empty" end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, str)
    if not ok then return false, "Invalid JSON" end
    return applyConfig(data)
end

local function readStoredConfig()
    local json
    if HAS_FILES then
        local ok, exists = pcall(isfile, CONFIG_FILE)
        if ok and exists then
            local ok2, c = pcall(readfile, CONFIG_FILE)
            if ok2 then json = c end
        end
    end
    return json or memoryConfig
end

local function saveConfig(silent)
    local json = encodeConfig()
    memoryConfig = json
    if HAS_FILES then
        local ok = pcall(writefile, CONFIG_FILE, json)
        if not silent then notify(ok and "Configuration saved to file" or "File write failed (kept in session)", ok and "good" or "warn") end
    elseif not silent then
        notify("No file access: saved for this session only", "warn")
    end
end

local function loadConfig(silent)
    local json = readStoredConfig()
    if not json then
        if not silent then notify("No saved configuration found", "warn") end
        return
    end
    local ok, msg = importJSON(json)
    if not silent then notify(ok and ("Loaded. " .. msg) or msg, ok and "good" or "bad") end
end

local function resetConfig()
    for _, f in ipairs(FeatList) do
        if f.kind == "toggle" then setValue(f.id, false, true)
        elseif f.kind == "slider" or f.kind == "dropdown" then setValue(f.id, f.default, true)
        elseif f.kind == "color" then setValue(f.id, "", true) end
    end
    notify("Configuration reset to defaults", "good")
end

markDirty = function()
    if dirty then return end
    dirty = true
    task.delay(1.5, function()
        dirty = false
        if alive then pcall(saveConfig, true) end
    end)
end

local gui = Root.add(new("ScreenGui", { Name = "CazielxArchx", ResetOnSpawn = false, DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true }, PlayerGui))

local WIN_W, WIN_H, TITLE_H = 700, 440, 44
local SB_OPEN, SB_MIN = 158, 52
local ROW_H = IS_TOUCH and 52 or 46
local TAB_H = IS_TOUCH and 44 or 38
local state = { open = false, min = false, max = false, sb = not IS_TOUCH, unloadArmed = false }
local uiRefs = {}

local function baseScale()
    local vp = gui.AbsoluteSize
    if vp.X < 10 or vp.Y < 10 then return 1 end
    local fit = math.max(math.min((vp.X - 12) / WIN_W, (vp.Y - 12) / WIN_H), .4)
    local s = math.min(fit, 1.15) * (S.ui_scale or 1)
    return math.min(s, fit)
end

local notifHolder = new("Frame", { Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(280, 400), ZIndex = 50 }, gui)
local notifScale = new("UIScale", { Scale = 1 }, notifHolder)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, notifHolder)
local liveNotifs = {}
local NOTIF_ICON = { good = "check", warn = "warning", bad = "error", info = "about" }
local NOTIF_KEY = { good = "Good", warn = "Warn", bad = "Bad", info = "Accent" }

local function dropNotif(wrap)
    local i = table.find(liveNotifs, wrap)
    if i then table.remove(liveNotifs, i) end
    if wrap.icon then DestroyIcon(wrap.icon) end
    if wrap.frame and wrap.frame.Parent then wrap.frame:Destroy() end
end

notify = function(msg, kind, dur)
    if not alive then return end
    kind = NOTIF_ICON[kind] and kind or "info"
    local lvl = S.notif_level or "All"
    if lvl == "Off" or (lvl == "Important" and (kind == "info" or kind == "good")) then return end
    while #liveNotifs >= 4 do dropNotif(table.remove(liveNotifs, 1)) end
    local frame = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50) }, notifHolder)
    local card = new("Frame", { BackgroundColor3 = "Panel", Size = UDim2.fromScale(1, 1), Position = UDim2.new(1.3, 0, 0, 0), BorderSizePixel = 0 }, frame)
    round(card, 8) stroke(card, NOTIF_KEY[kind], 1, .45)
    new("Frame", { BackgroundColor3 = NOTIF_KEY[kind], Size = UDim2.new(0, 3, 1, -16), Position = UDim2.fromOffset(7, 8), BorderSizePixel = 0 }, card)
    local ic = CreateIcon(NOTIF_ICON[kind], 16, card, { Position = UDim2.new(0, 18, .5, -8) })
    SetIconColor(ic, T[NOTIF_KEY[kind]])
    text(card, tostring(msg), 12, "Text", false, { Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), TextWrapped = true, TextTruncate = Enum.TextTruncate.None })
    local entry = { frame = frame, icon = ic }
    liveNotifs[#liveNotifs + 1] = entry
    tween(card, .28, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
    task.delay(dur or 3, function()
        if not frame.Parent then return end
        tween(card, .2, { Position = UDim2.new(1.3, 0, 0, 0) })
        task.delay(.24, function() dropNotif(entry) end)
    end)
end

local tip = new("TextLabel", { Visible = false, AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = "Bg",
    TextColor3 = "Text", Font = FONT, TextSize = 12, TextWrapped = true, Text = "", ZIndex = 200,
    BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, gui)
round(tip, 6) stroke(tip, "Accent", 1, .4)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, tip)
new("UISizeConstraint", { MaxSize = Vector2.new(260, 220) }, tip)

local function bindTooltip(obj, msg)
    if IS_TOUCH or not msg or msg == "" then return end
    local function place()
        local m = UIS:GetMouseLocation()
        tip.Position = UDim2.fromOffset(math.min(m.X + 14, gui.AbsoluteSize.X - 280), m.Y + 16)
    end
    obj.MouseEnter:Connect(function() tip.Text = msg place() tip.Visible = true end)
    obj.MouseMoved:Connect(place)
    obj.MouseLeave:Connect(function() tip.Visible = false end)
end

local drag
local function beginDrag(input, update, finish)
    drag = { input = input, update = update, finish = finish }
end
Root.add(UIS.InputChanged:Connect(function(input)
    if not drag then return end
    local t = input.UserInputType
    if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and input == drag.input) then
        drag.update(input.Position)
    end
end))
Root.add(UIS.InputEnded:Connect(function(input)
    if not drag then return end
    if input == drag.input or (drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
        local d = drag
        drag = nil
        if d.finish then pcall(d.finish) end
    end
end))
local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

addTab("Home", "home") addTab("Farm", "farm") addTab("Automation", "automation") addTab("Movement", "movement")
addTab("Visuals", "visuals") addTab("Player", "player") addTab("Statistics", "statistics") addTab("Server", "server")
addTab("Settings", "settings") addTab("Theme", "theme") addTab("Diagnostics", "diagnostics") addTab("About", "about")

local function rejoin()
    if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, Player)
    else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end
end
Root.add(TeleportService.TeleportInitFailed:Connect(function(_, _, msg) notify("Teleport failed: " .. tostring(msg), "bad", 5) end))

local function loop(interval, step)
    local h = { alive = true }
    task.spawn(function()
        while h.alive and alive do
            local ok, err = pcall(step, h)
            if not ok then warn("[CAZX] " .. tostring(err)) end
            local t = 0
            while h.alive and alive and t < interval do t += task.wait(math.min(.25, interval)) end
        end
    end)
    return h
end

local function getRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then return r end
    return nil
end
local function fireRemote(name, ...)
    local r = getRemote(name)
    if not r then return false end
    return (pcall(r.FireServer, r, ...))
end
local function numAttr(name)
    local v = Player:GetAttribute(name)
    return type(v) == "number" and v or nil
end
local function findStat(names)
    local ls = Player:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _, n in ipairs(names) do
        local v = ls:FindFirstChild(n)
        if v and (v:IsA("NumberValue") or v:IsA("IntValue")) then return v.Value end
    end
    return nil
end
local function getCash()
    return numAttr("Cash") or findStat({ "Cash", "Coins", "Money", "Gold" })
end

local function humanoidOverride(prop, valueFn, aux)
    local self, bag, origs, auxOrigs = {}, nil, nil, nil
    local function enforce(h) local v = valueFn() if h[prop] ~= v then h[prop] = v end end
    function self.enable()
        self.disable()
        bag, origs, auxOrigs = newBag(), setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
        hookCharacter(bag, function(char, cb)
            local h = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
            if not h or not origs then return end
            if origs[h] == nil then origs[h] = h[prop] if aux then auxOrigs[h] = h[aux.prop] end end
            if aux then h[aux.prop] = aux.value end
            enforce(h)
            cb.add(h:GetPropertyChangedSignal(prop):Connect(function() enforce(h) end))
        end)
    end
    function self.refresh() if bag then local h = getHum() if h then enforce(h) end end end
    function self.disable()
        if not bag then return end
        bag.clear() bag = nil
        for h, v in pairs(origs) do
            if h.Parent then pcall(function() h[prop] = v if aux then h[aux.prop] = auxOrigs[h] end end) end
        end
        origs, auxOrigs = nil, nil
    end
    return self
end

local function hasAnimalTool()
    for _, c in ipairs({ Player:FindFirstChild("Backpack"), Player.Character }) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t.Name ~= "Pickaxe" and t.Name ~= "Bat" then return true end
            end
        end
    end
    return false
end

local bestLoop
def("Farm", "auto_best", { kind = "toggle", name = "Place Best Pets", desc = "Equips your best pets whenever you hold an animal (PetsInventoryRemote).", fn = function(on)
    if bestLoop then bestLoop.alive = false bestLoop = nil end
    if not on then return end
    if not getRemote("PetsInventoryRemote") then return false, "PetsInventoryRemote was not found in ReplicatedStorage" end
    bestLoop = loop(3, function() if hasAnimalTool() then fireRemote("PetsInventoryRemote", "EquipBest") end end)
end })
def("Farm", "auto_bestnow", { kind = "button", name = "Place Best Now", desc = "Sends one EquipBest request now.", run = function()
    if not getRemote("PetsInventoryRemote") then return false, "PetsInventoryRemote was not found in ReplicatedStorage" end
    if not fireRemote("PetsInventoryRemote", "EquipBest") then return false, "EquipBest request failed" end
    notify("EquipBest sent", "good", 1.8)
end })

local function buyLoop(remoteName, argsFn, progressFn, confirmed)
    local gate = { wait = 5, nextAt = 0 }
    return loop(1, function()
        if os.clock() < gate.nextAt then return end
        local args = argsFn()
        if not args then return end
        local before = progressFn()
        if not fireRemote(remoteName, table.unpack(args)) then return end
        task.wait(1.2)
        if confirmed(before, progressFn()) then
            gate.wait = 5
            gate.nextAt = os.clock() + 1
        else
            gate.wait = math.min(gate.wait * 1.5, 40)
            gate.nextAt = os.clock() + gate.wait
        end
    end)
end

local pickLoop
def("Farm", "inv_pick", { kind = "toggle", name = "Buy Pickaxes", desc = "Buys the next pickaxe tier (PickaxeShopRequest) and backs off when it fails.", fn = function(on)
    if pickLoop then pickLoop.alive = false pickLoop = nil end
    if not on then return end
    if not getRemote("PickaxeShopRequest") then return false, "PickaxeShopRequest was not found in ReplicatedStorage" end
    if not numAttr("PickaxeTier") then return false, "PickaxeTier attribute was not found on your player" end
    pickLoop = buyLoop("PickaxeShopRequest", function()
        local tier = numAttr("PickaxeTier")
        return tier and { "Buy", tier + 1 } or nil
    end, function() return numAttr("PickaxeTier") end, function(a, b) return a ~= b end)
end })

local plotLoop
def("Farm", "up_plot", { kind = "toggle", name = "Upgrade Plot", desc = "Requests plot upgrades (UpgradePlotRequest); success is confirmed by a cash drop.", fn = function(on)
    if plotLoop then plotLoop.alive = false plotLoop = nil end
    if not on then return end
    if not getRemote("UpgradePlotRequest") then return false, "UpgradePlotRequest was not found in ReplicatedStorage" end
    if not numAttr("Cash") then return false, "Cash attribute was not found on your player" end
    plotLoop = buyLoop("UpgradePlotRequest", function() return numAttr("Cash") and {} or nil end,
        function() return numAttr("Cash") end, function(a, b) return a and b and b < a end)
end })

-- ===== Farm status / base / egg detection (heuristic, read-only scans; nothing runs in the background unless a toggle is ON) =====
local FarmInfo = { base = nil, baseWhy = "not scanned", eggs = 0, eggState = "TESTING", interact = "not checked", breakState = "OFF", errors = {} }
local function farmErr(msg)
    FarmInfo.errors[#FarmInfo.errors + 1] = os.date("%H:%M:%S") .. " " .. tostring(msg)
    while #FarmInfo.errors > 15 do table.remove(FarmInfo.errors, 1) end
end
local OWNER_KEYS = { "Owner", "OwnerId", "OwnerUserId", "UserId", "Player", "PlayerName", "Username" }
local function isMine(v)
    if v == Player or v == Player.UserId or v == Player.Name or v == Player.DisplayName then return true end
    return type(v) == "string" and tonumber(v) == Player.UserId
end
local function ownedByMe(inst)
    for _, k in ipairs(OWNER_KEYS) do
        local ok, a = pcall(inst.GetAttribute, inst, k)
        if ok and a ~= nil and isMine(a) then return true, "attribute " .. k end
    end
    for _, c in ipairs(inst:GetChildren()) do
        if c:IsA("ValueBase") and table.find(OWNER_KEYS, c.Name) then
            local ok, v = pcall(function() return c.Value end)
            if ok and isMine(v) then return true, "value " .. c.Name end
        end
    end
    return false
end
local function instPos(inst)
    if inst:IsA("Model") then return inst:GetPivot().Position end
    if inst:IsA("BasePart") then return inst.Position end
    local p = inst:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position or nil
end
local function scanBase()
    -- bounded breadth-first scan (depth <= 3, <= 2500 instances), only runs on demand
    local queue, head, seen = { { workspace, 0 } }, 1, 0
    while queue[head] do
        local cur, depth = queue[head][1], queue[head][2]
        head += 1
        for _, c in ipairs(cur:GetChildren()) do
            seen += 1
            if seen > 2500 then break end
            if c:IsA("Model") or c:IsA("Folder") or c:IsA("BasePart") then
                local ok, why = ownedByMe(c)
                if ok then return c, why end
                if depth < 2 and not c:IsA("BasePart") and c ~= Player.Character then queue[#queue + 1] = { c, depth + 1 } end
            end
        end
    end
    local rl = Player.RespawnLocation
    if rl and rl.Parent then return rl, "Player.RespawnLocation" end
    return nil, "no object tagged with your UserId/Name (Owner attributes/values) and no RespawnLocation"
end
local function getBase(force)
    local b = FarmInfo.base
    if force or not b or not b.Parent then
        FarmInfo.base, FarmInfo.baseWhy = scanBase()
        b = FarmInfo.base
    end
    return b
end
Root.add(Player:GetPropertyChangedSignal("RespawnLocation"):Connect(function() FarmInfo.base = nil end)) -- base location changed
hookCharacter(Root, function(char) FarmInfo.base = nil FarmInfo.interact = "not checked" end) -- respawn: force re-detection

local function findEggs(base)
    local out = {}
    local build = workspace:FindFirstChild("Build")
    local zones = build and build:FindFirstChild("ZoneBuilds")
    if not zones then return out, "Workspace.Build.ZoneBuilds not found" end
    for _, o in ipairs(zones:GetDescendants()) do
        if o.Name == "Egg" and o:IsA("BasePart") and o.Parent and o.Parent.Parent and o.Parent.Parent.Name == "Eggs" then
            if not base or o:IsDescendantOf(base) then out[#out + 1] = o end
        end
    end
    return out
end
local function eggInteraction(egg)
    local scope = { egg, egg.Parent }
    for _, s in ipairs(scope) do
        local pp = s and (s:IsA("ProximityPrompt") and s or s:FindFirstChildWhichIsA("ProximityPrompt", true))
        if pp then return "prompt", pp end
        local cd = s and s:FindFirstChildWhichIsA("ClickDetector", true)
        if cd then return "click", cd end
    end
    return nil
end

local breakLoop
def("Farm", "farm_break", { kind = "toggle", name = "Auto Break [TESTING]", desc = "Breaks eggs inside YOUR OWN base via their ProximityPrompt/ClickDetector when in range. Needs fireproximityprompt/fireclickdetector; does not walk or touch other players' eggs.", fn = function(on)
    if breakLoop then breakLoop.alive = false breakLoop = nil end
    FarmInfo.breakState = "OFF"
    if not on then return end
    if typeof(fireproximityprompt) ~= "function" and typeof(fireclickdetector) ~= "function" then
        FarmInfo.breakState = "REQUIRES INTEGRATION"
        return false, "REQUIRES INTEGRATION: this environment has no way to trigger egg prompts (fireproximityprompt/fireclickdetector missing)"
    end
    local base = getBase(true)
    if not base then FarmInfo.breakState = "ERROR" return false, "Base not detected: " .. tostring(FarmInfo.baseWhy) end
    FarmInfo.breakState = "TESTING"
    breakLoop = loop(.6, function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local b = getBase(false)
        if not hrp or not b then FarmInfo.eggState = "no character/base" return end
        local eggs, why = findEggs(b)
        FarmInfo.eggs = #eggs
        if why then FarmInfo.eggState = "ERROR: " .. why farmErr(why) return end
        if #eggs == 0 then FarmInfo.eggState = "NO EGGS IN BASE" return end
        local best, bd, kind, obj
        for _, e in ipairs(eggs) do
            local k, o = eggInteraction(e)
            if k then
                local d = (e.Position - hrp.Position).Magnitude
                local reach = k == "prompt" and (o.MaxActivationDistance or 10) or (o.MaxActivationDistance or 32)
                if d <= reach and (not bd or d < bd) then best, bd, kind, obj = e, d, k, o end
            end
        end
        if not best then FarmInfo.interact = "none in range" FarmInfo.eggState = #eggs .. " egg(s), none in range" return end
        FarmInfo.interact = kind
        local ok, err
        if kind == "prompt" and typeof(fireproximityprompt) == "function" then ok, err = pcall(fireproximityprompt, obj)
        elseif kind == "click" and typeof(fireclickdetector) == "function" then ok, err = pcall(fireclickdetector, obj)
        else FarmInfo.eggState = "REQUIRES INTEGRATION" return end
        if ok then FarmInfo.eggState = "TESTING (sent " .. kind .. ", server result unverified)" else farmErr(err) FarmInfo.eggState = "ERROR" end
    end)
end })
na("Farm", "farm_onehit", "Egg Breaker One-Hit", "Break an egg with a single hit.", "Cannot be verified: whether one hit is possible is decided by the game's server, and no documented mechanism exists to force it. Not faked.", "NOT SUPPORTED")
def("Farm", "farm_scan", { kind = "button", name = "Scan Farm Status", desc = "Re-detects your base, eggs and interaction type and reports the result.", run = function()
    local base = getBase(true)
    if not base then notify("Base: " .. tostring(FarmInfo.baseWhy), "warn", 5) return false, "Base not detected" end
    local eggs, why = findEggs(base)
    FarmInfo.eggs = #eggs
    local kind = #eggs > 0 and eggInteraction(eggs[1]) or nil
    FarmInfo.interact = kind or (#eggs > 0 and "none found" or "no eggs")
    FarmInfo.eggState = why and ("ERROR: " .. why) or (#eggs > 0 and (#eggs .. " egg(s) detected") or "NO EGGS IN BASE")
    notify(("Base OK (%s) | %s | interaction: %s"):format(FarmInfo.baseWhy, FarmInfo.eggState, FarmInfo.interact), "info", 5)
end })

local UNVERIFIED_FARM = "Needs walking and animal-collect logic that cannot be verified without running in the game."
na("Farm", "farm_auto", "Auto Farm", "Automatic egg farming.", UNVERIFIED_FARM)
for _, e in ipairs({ { "egg_rarity", "Egg Rarity Filter" }, { "pet_rarity", "Pet Rarity Filter" }, { "min_gen", "Minimum Generation Filter" },
    { "titanic", "Titanic Eggs" }, { "keep_gd", "Keep Gold And Diamond" }, { "sell_weak", "Sell Weakest When Full" } }) do
    na("Farm", e[1], e[2], "Needs game integration.")
end
for _, e in ipairs({ { "inv_trail", "Buy Trails" }, { "inv_gear", "Use Best Gear" }, { "up_tread", "Upgrade Treadmill" },
    { "claim_rewards", "Claim Rewards" }, { "claim_now", "Claim Now" }, { "sell_now", "Sell Now" } }) do
    na("Farm", e[1], e[2], "Needs game integration.")
end

local NOSTEAL = "Not provided: taking items from other players is out of scope for this hub."
for _, e in ipairs({ { "steal_auto", "Auto Steal" }, { "steal_instant", "Instant Steal" }, { "steal_hold", "Hold After Teleport" },
    { "steal_first", "Steal First" }, { "steal_skip", "Skip Slow Eggs" }, { "steal_guard", "Guard Safety" } }) do
    na("Automation", e[1], e[2], "Not available.", NOSTEAL, "NOT PROVIDED")
end
for _, e in ipairs({ { "auto_train", "Train When Idle" }, { "auto_place", "Auto Place Eggs" }, { "auto_open", "Open Ready Eggs" },
    { "auto_merge", "Merge Pets" }, { "auto_fuse", "Fuse Pets" }, { "auto_sell", "Auto Sell" },
    { "auto_potions", "Keep Potions Running" } }) do
    na("Automation", e[1], e[2], "Needs game integration.")
end
for _, e in ipairs({ { "ev_halloween", "Halloween Events" }, { "ev_shield", "Pumpkin King Shield" }, { "ev_candy", "Buy Eggs With Candy" },
    { "ev_predict", "Event Predictor" }, { "ev_alert", "Event Alerts" } }) do
    na("Automation", e[1], e[2], "Needs game integration.")
end

local noclip = {}
def("Movement", "noclip", { kind = "toggle", name = "NoClip", desc = "Walk through walls (local). Collisions restored when off.", fn = function(on)
    if noclip.bag then noclip.bag.clear() noclip.bag = nil end
    if noclip.orig then for p in pairs(noclip.orig) do if p.Parent then p.CanCollide = true end end noclip.orig = nil end
    if not on then return end
    local bag = newBag()
    local parts, orig = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
    noclip.bag, noclip.orig = bag, orig
    hookCharacter(bag, function(char, cb)
        table.clear(parts)
        for _, d in ipairs(char:GetDescendants()) do if d:IsA("BasePart") then parts[d] = true end end
        cb.add(char.DescendantAdded:Connect(function(d) if d:IsA("BasePart") then parts[d] = true end end))
    end)
    bag.add(RunService.Stepped:Connect(function()
        for p in pairs(parts) do if p.Parent and p.CanCollide then orig[p] = true p.CanCollide = false end end
    end))
end })

local ij
def("Movement", "infjump", { kind = "toggle", name = "Infinite Jump", desc = "Jump again while in the air.", fn = function(on)
    if ij then ij.clear() ij = nil end
    if on then
        ij = newBag()
        ij.add(UIS.JumpRequest:Connect(function()
            local h = getHum()
            if h and h.Health > 0 then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end))
    end
end })

local speed = humanoidOverride("WalkSpeed", function() return S.speed_value end)
def("Movement", "speed", { kind = "toggle", name = "Speed Boost", desc = "Sets WalkSpeed to the slider value; restored when off.", fn = function(on)
    if on then speed.enable() else speed.disable() end
end })
def("Movement", "speed_value", { kind = "slider", name = "Walk Speed", desc = "Value used by Speed Boost.", min = 16, max = 150, step = 1, default = 32, fn = function() speed.refresh() end })

local jump = humanoidOverride("JumpPower", function() return S.jump_value end, { prop = "UseJumpPower", value = true })
def("Movement", "jump", { kind = "toggle", name = "Jump Boost", desc = "Sets JumpPower to the slider value; restored when off.", fn = function(on)
    if on then jump.enable() else jump.disable() end
end })
def("Movement", "jump_value", { kind = "slider", name = "Jump Power", desc = "Value used by Jump Boost.", min = 50, max = 250, step = 5, default = 90, fn = function() jump.refresh() end })

def("Movement", "tp_base", { kind = "button", name = "Teleport To Base [TESTING]", desc = "Moves your own character to your detected base (no hardcoded coordinates). Servers with anti-teleport may reject it.", run = function()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = getHum()
    if not hrp or not hum or hum.Health <= 0 then return false, "Character is not ready (respawning?)" end
    local base = getBase(true)
    if not base then return false, "Base not detected: " .. tostring(FarmInfo.baseWhy) end
    local p = instPos(base)
    if not p then return false, "Base has no position to teleport to" end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local hit = workspace:Raycast(p + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
    local dest = (hit and hit.Position or p) + Vector3.new(0, 4, 0)
    if dest ~= dest or dest.Magnitude > 1e5 or math.abs(dest.Y) > 5000 then return false, "Destination failed validation" end
    local ok, err = pcall(function() char:PivotTo(CFrame.new(dest) * (hrp.CFrame - hrp.CFrame.Position)) end)
    if not ok then farmErr(err) return false, "Teleport failed: " .. tostring(err) end
    notify("Teleported to base (" .. tostring(FarmInfo.baseWhy) .. ")", "good", 2)
end })
na("Movement", "walk_zone", "Walk To Zone", "Walk to a zone.", "Needs the game's zone objects (names unknown/unverified).")
na("Movement", "walk_tread", "Walk To Treadmill", "Walk to the treadmill.", "Needs the game's treadmill point (found at runtime by KryvenHub; not verified here).")
na("Movement", "walk_plot", "Walk To Plot", "Walk to your plot.", "Needs the game's plot objects (names unknown/unverified).")
na("Movement", "walk_safe", "Walk To Safe Zone", "Walk to the safe zone.", "Needs the game's safe-zone objects (names unknown/unverified).")

local FB_PROPS = { Brightness = 2, Ambient = Color3.new(1, 1, 1), OutdoorAmbient = Color3.new(1, 1, 1), GlobalShadows = false, FogEnd = 1e6 }
local fbState
def("Visuals", "fullbright", { kind = "toggle", name = "Fullbright", desc = "Removes darkness and fog; original lighting restored when off.", fn = function(on)
    if fbState then
        fbState.bag.clear()
        for k, v in pairs(fbState.orig) do pcall(function() Lighting[k] = v end) end
        fbState = nil
    end
    if not on then return end
    local bag, orig = newBag(), {}
    fbState = { bag = bag, orig = orig }
    for k, v in pairs(FB_PROPS) do
        orig[k] = Lighting[k]
        Lighting[k] = v
        bag.add(Lighting:GetPropertyChangedSignal(k):Connect(function() if Lighting[k] ~= v then Lighting[k] = v end end))
    end
end })

local lowState
local function isEffect(o)
    return o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") or o:IsA("PostEffect")
end
def("Visuals", "lowgfx", { kind = "toggle", name = "Low Graphics", desc = "Disables particles, trails, beams and post effects (also new ones).", fn = function(on)
    if lowState then
        lowState.bag.clear()
        for o, v in pairs(lowState.orig) do if o.Parent then pcall(function() o.Enabled = v end) end end
        lowState = nil
    end
    if not on then return end
    local bag, orig = newBag(), setmetatable({}, { __mode = "k" })
    lowState = { bag = bag, orig = orig }
    local function cut(o)
        if isEffect(o) then
            if orig[o] == nil then orig[o] = o.Enabled end
            o.Enabled = false
        end
    end
    for _, o in ipairs(workspace:GetDescendants()) do cut(o) end
    for _, o in ipairs(Lighting:GetDescendants()) do cut(o) end
    bag.add(workspace.DescendantAdded:Connect(cut))
    bag.add(Lighting.DescendantAdded:Connect(cut))
end })

local fpsState
def("Visuals", "fpsboost", { kind = "toggle", name = "FPS Boost", desc = "Lowest render quality + no terrain decoration; restored when off.", fn = function(on)
    if not on then
        if fpsState then
            pcall(function() settings().Rendering.QualityLevel = fpsState.q end)
            if fpsState.deco ~= nil then pcall(function() workspace.Terrain.Decoration = fpsState.deco end) end
            fpsState = nil
        end
        return
    end
    local ok, q = pcall(function()
        local r = settings().Rendering
        local old = r.QualityLevel
        r.QualityLevel = Enum.QualityLevel.Level01
        return old
    end)
    if not ok then return false, "Render quality can't be changed from this context" end
    fpsState = { q = q }
    local ok2, d = pcall(function() local t = workspace.Terrain local old = t.Decoration t.Decoration = false return old end)
    if ok2 then fpsState.deco = d end
end })

local ESP_COLORS = { Blue = Color3.fromRGB(0, 136, 255), Red = Color3.fromRGB(255, 70, 80), Green = Color3.fromRGB(60, 220, 140),
    Purple = Color3.fromRGB(170, 100, 255), White = Color3.fromRGB(240, 245, 255) }
local esp = { hl = {} }
local function addHL(plr, char)
    if plr == Player or not char then return end
    local old = esp.hl[plr]
    if old then old:Destroy() end
    esp.hl[plr] = new("Highlight", { Name = "CAZX_ESP", Adornee = char, FillColor = ESP_COLORS[S.esp_color] or ESP_COLORS.Blue,
        OutlineColor = Color3.new(1, 1, 1), FillTransparency = .75, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, char)
end
local function watchPlayer(plr)
    if plr == Player or not esp.bag then return end
    esp.bag.add(plr.CharacterAdded:Connect(function(c) addHL(plr, c) end))
    if plr.Character then addHL(plr, plr.Character) end
end
def("Visuals", "esp_players", { kind = "toggle", name = "Player ESP", desc = "Highlights other players through walls (event-driven, no scanning).", fn = function(on)
    if esp.bag then esp.bag.clear() esp.bag = nil end
    for p, h in pairs(esp.hl) do h:Destroy() esp.hl[p] = nil end
    if not on then return end
    esp.bag = newBag()
    for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
    esp.bag.add(Players.PlayerAdded:Connect(watchPlayer))
    esp.bag.add(Players.PlayerRemoving:Connect(function(p)
        local h = esp.hl[p]
        if h then h:Destroy() esp.hl[p] = nil end
    end))
end })
def("Visuals", "esp_color", { kind = "dropdown", name = "ESP Color", desc = "Fill color for Player ESP.", options = { "Blue", "Red", "Green", "Purple", "White" }, default = "Blue", fn = function(v)
    for _, h in pairs(esp.hl) do if h.Parent then h.FillColor = ESP_COLORS[v] or ESP_COLORS.Blue end end
end })

local eggEsp
def("Visuals", "esp_egg", { kind = "toggle", name = "Egg ESP", desc = "Highlights eggs under Workspace.Build.ZoneBuilds (event-driven).", fn = function(on)
    if eggEsp then
        eggEsp.bag.clear()
        for _, h in pairs(eggEsp.hl) do h:Destroy() end
        eggEsp = nil
    end
    if not on then return end
    local build = workspace:FindFirstChild("Build")
    local zones = build and build:FindFirstChild("ZoneBuilds")
    if not zones then return false, "Workspace.Build.ZoneBuilds was not found in this server" end
    local st = { bag = newBag(), hl = {} }
    eggEsp = st
    local function tag(o)
        if o.Name == "Egg" and o:IsA("BasePart") and not st.hl[o] then
            local holder = o.Parent
            local folder = holder and holder.Parent
            if folder and folder.Name == "Eggs" then
                st.hl[o] = new("Highlight", { Name = "CAZX_EGG", Adornee = o, FillColor = T.Accent, OutlineColor = Color3.new(1, 1, 1),
                    FillTransparency = .55, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop }, o)
            end
        end
    end
    for _, d in ipairs(zones:GetDescendants()) do tag(d) end
    st.bag.add(zones.DescendantAdded:Connect(tag))
    st.bag.add(zones.DescendantRemoving:Connect(function(o)
        local h = st.hl[o]
        if h then h:Destroy() st.hl[o] = nil end
    end))
end })
na("Visuals", "esp_lucky", "Lucky Egg ESP", "Marks lucky eggs.")
na("Visuals", "esp_pet", "Pet ESP", "Marks pets.")
na("Visuals", "esp_rarity", "Rarity Indicator", "Shows rarity labels.")

local inv = {}
def("Player", "invisible", { kind = "toggle", name = "Invisible (Local)", desc = "Hides your character on your screen only.", fn = function(on)
    if inv.bag then inv.bag.clear() inv.bag = nil end
    if inv.orig then for o, v in pairs(inv.orig) do if o.Parent then o.Transparency = v end end inv.orig = nil end
    if not on then return end
    local bag, orig = newBag(), setmetatable({}, { __mode = "k" })
    inv.bag, inv.orig = bag, orig
    local function hide(o)
        if o:IsA("BasePart") or o:IsA("Decal") then
            if orig[o] == nil then orig[o] = o.Transparency end
            o.Transparency = 1
        end
    end
    hookCharacter(bag, function(char, cb)
        for _, d in ipairs(char:GetDescendants()) do hide(d) end
        cb.add(char.DescendantAdded:Connect(hide))
    end)
end })
def("Player", "reset", { kind = "button", name = "Reset Character", desc = "Respawns your character.", run = function()
    local h = getHum()
    if not h then return false, "No character to reset" end
    h.Health = 0
end })

local dcAlert
def("Player", "dc_alert", { kind = "toggle", name = "Disconnect Alert", desc = "Notifies when Roblox shows a disconnect/error message.", fn = function(on)
    if dcAlert then dcAlert.clear() dcAlert = nil end
    if on then
        dcAlert = newBag()
        dcAlert.add(GuiService.ErrorMessageChanged:Connect(function(msg)
            if msg and msg ~= "" then notify("Disconnected: " .. msg, "bad", 10) end
        end))
    end
end })

local afk
def("Player", "antiafk", { kind = "toggle", name = "Anti AFK", desc = "Prevents the idle kick by simulating input.", fn = function(on)
    if afk then afk.clear() afk = nil end
    if on then
        afk = newBag()
        afk.add(Player.Idled:Connect(function()
            pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
        end))
    end
end })

local reco
def("Player", "autoreconnect", { kind = "toggle", name = "Auto Reconnect", desc = "Best effort: teleports back to this place after a disconnect message.", fn = function(on)
    if reco then reco.clear() reco = nil end
    if on then
        reco = newBag()
        local busy = false
        reco.add(GuiService.ErrorMessageChanged:Connect(function(msg)
            if busy or not msg or msg == "" then return end
            busy = true
            notify("Connection lost. Reconnecting in 3s...", "warn", 4)
            task.delay(3, function()
                pcall(function() TeleportService:Teleport(game.PlaceId, Player) end)
                busy = false
            end)
        end))
    end
end })

local pingW
def("Player", "pingfreeze", { kind = "toggle", name = "Rejoin If Ping Freezes", desc = "Rejoins when ping stays above the limit for ~9 seconds.", fn = function(on)
    if pingW then pingW.alive = false pingW = nil end
    if not on then return end
    local w = { alive = true }
    pingW = w
    task.spawn(function()
        local strikes = 0
        while w.alive and alive do
            task.wait(3)
            if not w.alive then break end
            local ok, p = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if ok and p and p > S.ping_limit then strikes += 1 else strikes = 0 end
            if strikes >= 3 then
                w.alive = false
                notify("Ping frozen. Rejoining...", "warn", 4)
                pcall(rejoin)
            end
        end
    end)
end })
def("Player", "ping_limit", { kind = "slider", name = "Ping Limit (ms)", desc = "Threshold for Rejoin If Ping Freezes.", min = 300, max = 5000, step = 100, default = 1500 })
na("Player", "rejoin_each", "Rejoin Every Join", "Auto rejoin on each join.", "Needs a persistent loader across teleports; not available in a plain LocalScript.", "UNAVAILABLE")
na("Player", "nopause", "No Gameplay Paused", "Disable the gameplay-paused screen.", "Pause state is controlled by the engine/server; the client can't override it.", "UNAVAILABLE")

local rep
def("Statistics", "reports", { kind = "toggle", name = "Progress Reports", desc = "Periodic session report: uptime, FPS, ping, players.", fn = function(on)
    if rep then rep.alive = false rep.bag.clear() rep = nil end
    if not on then return end
    local r = { alive = true, bag = newBag(), frames = 0 }
    rep = r
    r.bag.add(RunService.Heartbeat:Connect(function() r.frames += 1 end))
    local startTime, last = os.time(), time()
    task.spawn(function()
        while r.alive and alive do
            task.wait(math.max(S.report_minutes, 1) * 60)
            if not r.alive then break end
            local now = time()
            local fps = r.frames / math.max(now - last, 1)
            r.frames, last = 0, now
            local ping = 0
            pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            notify(("Session %d min | %d FPS | %d ms | %d players"):format(math.floor((os.time() - startTime) / 60),
                math.floor(fps), math.floor(ping), #Players:GetPlayers()), "info", 6)
        end
    end)
end })
def("Statistics", "report_minutes", { kind = "slider", name = "Report Interval (min)", desc = "Time between reports.", min = 1, max = 30, step = 1, default = 5 })
na("Statistics", "pet_alert", "New Pet Alerts", "Alert on new pets.")

local blackGui
def("Settings", "blackscreen", { kind = "toggle", name = "Black Screen", desc = "Covers the 3D view with black. This hub stays on top.", fn = function(on)
    if blackGui then blackGui:Destroy() blackGui = nil end
    if on then
        blackGui = new("ScreenGui", { Name = "CazxBlack", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50 }, PlayerGui)
        new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, blackGui)
    end
end })
def("Settings", "no3d", { kind = "toggle", name = "Disable 3D Rendering", desc = "Stops 3D rendering to save GPU. UI keeps working.", fn = function(on)
    local ok = pcall(function() RunService:Set3dRenderingEnabled(not on) end)
    if not ok then return false, "3D rendering can't be toggled from this context" end
end })
def("Settings", "fps_limit", { kind = "toggle", name = "Limit FPS", desc = "Caps frame rate (needs setfpscap). Restores 60 when off.",
    check = function() return HAS_FPSCAP, "Requires an environment that provides setfpscap" end,
    fn = function(on)
        local ok = pcall(setfpscap, on and S.fps_cap or 60)
        if not ok then return false, "setfpscap failed" end
    end })
def("Settings", "fps_cap", { kind = "slider", name = "FPS Cap", desc = "Value used by Limit FPS.", min = 15, max = 240, step = 5, default = 60,
    check = function() return HAS_FPSCAP, "Requires setfpscap" end,
    fn = function(v) if S.fps_limit and HAS_FPSCAP then pcall(setfpscap, v) end end })
na("Settings", "backpack_lag", "Fix Backpack Lag", "Reduce backpack lag.", "Needs the game's backpack UI/objects (unverified).")
def("Settings", "notif_level", { kind = "dropdown", name = "Notifications", desc = "All, only warnings/errors, or none.", options = { "All", "Important", "Off" }, default = "All" })
def("Settings", "toggle_key", { kind = "dropdown", name = "Toggle Key (PC)", desc = "Keyboard shortcut to show/hide. Mobile uses the floating button.", options = { "RightShift", "RightControl", "Insert", "Home", "K" }, default = "RightShift" })
def("Settings", "config_box", { kind = "textbox", name = "Config JSON", desc = "Export fills this box. Paste JSON here to import." })
def("Settings", "cfg_save", { kind = "button", name = "Save Configuration", desc = "Saves to file (if available) and session.", run = function() saveConfig(false) end })
def("Settings", "cfg_load", { kind = "button", name = "Load Configuration", desc = "Loads the last saved configuration.", run = function() loadConfig(false) end })
def("Settings", "cfg_export", { kind = "button", name = "Export Configuration", desc = "Writes JSON into the box (and clipboard if possible).", run = function()
    local json = encodeConfig()
    if uiRefs.configBox then uiRefs.configBox.Text = json end
    if HAS_CLIPBOARD and pcall(setclipboard, json) then notify("Config exported and copied", "good")
    else notify("Config exported. Copy it from the box.", "good") end
end })
def("Settings", "cfg_import", { kind = "button", name = "Import Configuration", desc = "Validates and applies the JSON in the box.", run = function()
    local ok, msg = importJSON(uiRefs.configBox and uiRefs.configBox.Text or "")
    notify(ok and msg or ("Import failed: " .. msg), ok and "good" or "bad", 4)
end })
def("Settings", "cfg_reset", { kind = "button", name = "Reset Configuration", desc = "Turns everything off and restores defaults.", run = resetConfig })
def("Settings", "cfg_unload", { kind = "button", name = "Unload Hub", desc = "Disables all features, closes connections and removes the UI.", run = function()
    task.defer(function() if _G.__CAZX_CLEANUP then _G.__CAZX_CLEANUP() end end)
end })

def("Server", "rejoin", { kind = "button", name = "Rejoin Server", desc = "Rejoins this server (or a fresh one if you're alone).", run = function()
    notify("Rejoining...", "info", 2)
    local ok = pcall(rejoin)
    if not ok then return false, "Rejoin failed (teleport not allowed here)" end
end })
def("Server", "copyjob", { kind = "button", name = "Copy JobId", desc = "Copies this server's JobId.", run = function()
    local id = game.JobId ~= "" and game.JobId or "(empty - Studio)"
    if HAS_CLIPBOARD and pcall(setclipboard, id) then notify("JobId copied", "good")
    else notify("Clipboard unavailable. JobId: " .. id, "warn", 8) end
end })
def("Server", "showjob", { kind = "button", name = "Show JobId", desc = "Shows this server's JobId.", run = function()
    notify("JobId: " .. (game.JobId ~= "" and game.JobId or "(empty - Studio)"), "info", 8)
end })
def("Server", "hop", { kind = "button", name = "Server Hop", desc = "Joins another public server (needs an HTTP request function).",
    check = function() return HTTP_REQUEST ~= nil, "Requires an environment that provides an HTTP request function" end,
    run = function()
        notify("Searching for a server...", "info", 2)
        task.spawn(function()
            local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
            local ok, res = pcall(HTTP_REQUEST, { Url = url, Method = "GET" })
            if not ok or type(res) ~= "table" or res.StatusCode ~= 200 then notify("Server list request failed", "bad") return end
            local okj, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
            if not okj or type(data) ~= "table" or type(data.data) ~= "table" then notify("Unexpected server list format", "bad") return end
            for _, s in ipairs(data.data) do
                if s.id ~= game.JobId and type(s.playing) == "number" and type(s.maxPlayers) == "number" and s.playing < s.maxPlayers - 1 then
                    notify("Hopping...", "good", 2)
                    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, Player) end)
                    return
                end
            end
            notify("No suitable server found", "warn")
        end)
    end })

def("Theme", "theme_preset", { kind = "dropdown", name = "Theme Preset", desc = "Switches the whole interface. Clears custom colors.", options = PRESET_ORDER, default = "Obsidian Dark", fn = function()
    for _, id in ipairs({ "theme_accent", "theme_bg", "theme_panel", "theme_border", "theme_text", "theme_sub" }) do
        S[id] = ""
        refreshViews(Feat[id])
    end
    applyTheme(true)
end })
local function colorFeat(id, name, desc, key, palette)
    def("Theme", id, { kind = "color", name = name, desc = desc, key = key, palette = palette, fn = function() applyTheme(true) end })
end
colorFeat("theme_accent", "Accent Color", "Hex like #40c4ff. Empty follows the preset.", "Accent", true)
colorFeat("theme_bg", "Background Color", "Window background.", "Bg")
colorFeat("theme_panel", "Panel Color", "Sidebar, title bar and cards.", "Panel")
colorFeat("theme_border", "Border Color", "Outlines and dividers.", "Border")
colorFeat("theme_text", "Text Color", "Primary text.", "Text")
colorFeat("theme_sub", "Secondary Text Color", "Descriptions and hints.", "Sub")
def("Theme", "theme_tr", { kind = "slider", name = "UI Transparency", desc = "Window and card transparency.", min = 0, max = .5, step = .05, default = 0, fn = function() applyTheme(false) end })
def("Theme", "ui_scale", { kind = "slider", name = "UI Scale", desc = "Scales the whole hub.", min = .7, max = 1.3, step = .05, default = 1, fn = function() applyScale() end })
def("Theme", "anim_level", { kind = "slider", name = "Animation Intensity", desc = "0 disables animation, 1 is normal, 2 is slower and softer.", min = 0, max = 2, step = .25, default = 1 })
def("Theme", "theme_reset", { kind = "button", name = "Reset Theme", desc = "Restores Obsidian Dark and default theme settings.", run = function()
    for _, id in ipairs({ "theme_accent", "theme_bg", "theme_panel", "theme_border", "theme_text", "theme_sub" }) do
        S[id] = ""
        refreshViews(Feat[id])
    end
    S.theme_preset = "Obsidian Dark" refreshViews(Feat.theme_preset)
    setValue("theme_tr", 0, true) setValue("ui_scale", 1, true) setValue("anim_level", 1, true)
    applyTheme(true)
    markDirty()
    notify("Theme reset", "good")
end })
def("Theme", "theme_save", { kind = "button", name = "Save Theme", desc = "Saves the theme with the configuration.", run = function() saveConfig(false) end })

local UI = {}
local bootWarnings = 0
local sessionStart = os.clock()

local function refreshAllViews()
    for _, f in ipairs(FeatList) do refreshViews(f) end
end

applyTheme = function(animate)
    computeTheme()
    local j = 0
    for i = 1, #bindings do
        local b = bindings[i]
        local o = b[1]
        if o.Parent then
            j += 1
            bindings[j] = b
            local v = T[b[3]]
            if v ~= nil then
                if animate then tween(o, .3, { [b[2]] = v }) else o[b[2]] = v end
            end
        end
    end
    for i = #bindings, j + 1, -1 do bindings[i] = nil end
    refreshIcons(animate)
    refreshAllViews()
    for _, t in ipairs(Tabs) do if t.setActive then t.setActive(t.isActive == true, animate) end end
    if UI.onTheme then pcall(UI.onTheme) end
end

local function preloadTheme(data)
    if type(data) ~= "table" or type(data.state) ~= "table" then return end
    for _, id in ipairs(THEME_IDS) do
        local f, v = Feat[id], data.state[id]
        if f and valid(f, v) then
            if f.kind == "slider" then v = math.clamp(v, f.min, f.max) end
            if f.kind == "color" then v = v:lower() end
            S[id] = v
        end
    end
    applyTheme(true)
end

local function formatNumber(n)
    if type(n) ~= "number" then return "N/A" end
    local a = math.abs(n)
    local units = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, u in ipairs(units) do
        if a >= u[1] then return ("%.2f%s"):format(n / u[1], u[2]) end
    end
    return tostring(math.floor(n * 100 + .5) / 100)
end
local function formatTime(sec)
    sec = math.floor(sec)
    return ("%d:%02d:%02d"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end

local cashSamples, cashBase = {}, nil
local fpsValue, frameCount, lastFpsAt = 0, 0, os.clock()
local function sampleStats()
    local now = os.clock()
    local cash = getCash()
    if cash then
        if not cashBase then cashBase = cash end
        cashSamples[#cashSamples + 1] = { now, cash }
        while #cashSamples > 60 do table.remove(cashSamples, 1) end
    end
end
local function cashPerSecond()
    local attr = numAttr("CashPerSecond")
    if attr then return attr end
    local n = #cashSamples
    if n < 2 then return nil end
    local first, last = cashSamples[math.max(1, n - 30)], cashSamples[n]
    local dt = last[1] - first[1]
    if dt < 1 then return nil end
    return (last[2] - first[2]) / dt
end
local function activeCount()
    local n = 0
    for _, f in ipairs(FeatList) do if f.kind == "toggle" and S[f.id] then n += 1 end end
    return n
end

local diagItems = {}
diagItems[#diagItems + 1] = { label = "Farm / Base", fn = function() return FarmInfo.base and (FarmInfo.base:GetFullName() .. " (" .. tostring(FarmInfo.baseWhy) .. ")") or ("not detected: " .. tostring(FarmInfo.baseWhy)) end }
diagItems[#diagItems + 1] = { label = "Farm / Eggs", fn = function() return tostring(FarmInfo.eggs) .. " | " .. tostring(FarmInfo.eggState) end }
diagItems[#diagItems + 1] = { label = "Farm / Interaction", fn = function() return tostring(FarmInfo.interact) end }
diagItems[#diagItems + 1] = { label = "Farm / Auto Break", fn = function() return tostring(FarmInfo.breakState) end }
diagItems[#diagItems + 1] = { label = "Farm / Last Error", fn = function() return FarmInfo.errors[#FarmInfo.errors] or "none" end }
local function diagReport()
    local lines = { APP_NAME .. " " .. EDITION .. " v" .. VERSION .. " build " .. BUILD }
    for _, it in ipairs(diagItems) do
        local ok, val = pcall(it.fn)
        lines[#lines + 1] = it.label .. ": " .. (ok and tostring(val) or "error")
    end
    return table.concat(lines, "\n")
end
def("Diagnostics", "diag_refresh", { kind = "button", name = "Refresh Diagnostics", desc = "Re-runs every check on this page.", run = function()
    if UI.runLive then UI.runLive(true) end
    notify("Diagnostics refreshed", "good", 1.6)
end })
def("Diagnostics", "diag_copy", { kind = "button", name = "Copy Report", desc = "Copies the diagnostics report (or shows it if clipboard is unavailable).", run = function()
    local rep = diagReport()
    if HAS_CLIPBOARD and pcall(setclipboard, rep) then notify("Report copied", "good")
    else notify("Clipboard unavailable. See Diagnostics page.", "warn", 5) end
end })

local function buildInterface()
    local win = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
        Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = "Bg", BackgroundTransparency = "Tr", BorderSizePixel = 0,
        Visible = false, ClipsDescendants = true, Active = true }, gui)
    round(win, 12) stroke(win, "Border", 1.2, 0)
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 226, 232)) }, win)
    local winScale = new("UIScale", { Scale = 1 }, win)
    UI.win, UI.winScale = win, winScale

    local titleBar = new("Frame", { Size = UDim2.new(1, 0, 0, TITLE_H), BackgroundColor3 = "Panel", BackgroundTransparency = "Tr", BorderSizePixel = 0, Active = true }, win)
    new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = "Border", BorderSizePixel = 0 }, titleBar)
    new("Frame", { Size = UDim2.new(0, 120, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = "Accent", BorderSizePixel = 0 }, titleBar)

    local bw = IS_TOUCH and 38 or 34
    local function ctrl(iconName, x, hoverKey)
        local b = new("TextButton", { Text = "", Size = UDim2.fromOffset(bw, 30), Position = UDim2.new(1, x, .5, -15),
            BackgroundColor3 = "Card", AutoButtonColor = false, BorderSizePixel = 0 }, titleBar)
        round(b, 7)
        local ic = CreateIcon(iconName, 16, b, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5) })
        b.MouseEnter:Connect(function() tween(b, .12, { BackgroundColor3 = T[hoverKey or "CardHover"] }) SetIconState(ic, "hover") end)
        b.MouseLeave:Connect(function() tween(b, .15, { BackgroundColor3 = T.Card }) SetIconState(ic, "normal") end)
        b.MouseButton1Down:Connect(function() tween(b, .06, { BackgroundColor3 = T.AccentDim }) end)
        return b, ic
    end
    local btnClose = ctrl("close", -(bw + 8), "Bad")
    local btnMax, icMax = ctrl("expand", -(2 * bw + 12))
    local icMaxAlt = CreateIcon("collapse", 16, btnMax, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Visible = false })
    local btnMin = ctrl("minimize", -(3 * bw + 16))
    local btnUnload, icUnload = ctrl("stop", -(4 * bw + 20), "Bad")
    local btnMenu = new("TextButton", { Text = "", Size = UDim2.fromOffset(bw, 30), Position = UDim2.new(0, 8, .5, -15),
        BackgroundColor3 = "Card", AutoButtonColor = false, BorderSizePixel = 0 }, titleBar)
    round(btnMenu, 7)
    local icMenu = CreateIcon("menu", 16, btnMenu, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5) })
    iconHover(btnMenu, icMenu)
    bindTooltip(btnMenu, "Toggle sidebar")
    bindTooltip(btnClose, "Close: hides the interface; features keep running")
    bindTooltip(btnMax, "Expand or restore the window")
    bindTooltip(btnMin, "Minimize: hides the window; features keep running")
    bindTooltip(btnUnload, "Unload Hub: stops every feature and removes all UI")

    CreateIcon("logo", 22, titleBar, { Position = UDim2.new(0, 14 + bw, .5, -11) })
    text(titleBar, APP_NAME, 15, "Text", true, { Position = UDim2.fromOffset(46 + bw, 0), Size = UDim2.fromOffset(80, TITLE_H) })
    text(titleBar, EDITION .. "  v" .. VERSION, 10, "Accent", true, { Position = UDim2.fromOffset(122 + bw, 0), Size = UDim2.fromOffset(110, TITLE_H) })
    local activeLbl = text(titleBar, "0 active", 11, "Sub", false, { Position = UDim2.fromOffset(232 + bw, 0), Size = UDim2.fromOffset(90, TITLE_H) })
    updateActive = function() activeLbl.Text = activeCount() .. " active" end

    local body = new("Frame", { Position = UDim2.fromOffset(0, TITLE_H), Size = UDim2.new(1, 0, 1, -TITLE_H), BackgroundTransparency = 1, ClipsDescendants = true }, win)
    local sbW = state.sb and SB_OPEN or SB_MIN
    local sidebar = new("Frame", { Size = UDim2.new(0, sbW, 1, 0), BackgroundColor3 = "Panel", BackgroundTransparency = "Tr", BorderSizePixel = 0, ClipsDescendants = true }, body)
    new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = "Border", BorderSizePixel = 0 }, sidebar)
    local sideList = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, sidebar)
    new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, sideList)
    new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 5), PaddingBottom = UDim.new(0, 8) }, sideList)
    local content = new("Frame", { Position = UDim2.fromOffset(sbW, 0), Size = UDim2.new(1, -sbW, 1, 0), BackgroundTransparency = 1 }, body)

    local searchCard = new("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -22, 0, 34), BackgroundColor3 = "Card", BackgroundTransparency = "Tr", BorderSizePixel = 0 }, content)
    round(searchCard, 9)
    local searchStroke = stroke(searchCard, "Border", 1, .2)
    local icSearch = CreateIcon("search", 16, searchCard, { Position = UDim2.fromOffset(10, 9) })
    local searchBox = new("TextBox", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -70, 1, 0), BackgroundTransparency = 1,
        Text = "", PlaceholderText = "Search features...", PlaceholderColor3 = "Sub", TextColor3 = "Text", Font = FONT,
        TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0 }, searchCard)
    local clearBtn = new("TextButton", { Text = "", Size = UDim2.fromOffset(30, 34), Position = UDim2.new(1, -32, 0, 0), BackgroundTransparency = 1, Visible = false }, searchCard)
    local icClear = CreateIcon("close", 12, clearBtn, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5) })
    iconHover(clearBtn, icClear)
    searchBox.Focused:Connect(function() tween(searchStroke, .15, { Color = T.Accent }) SetIconState(icSearch, "active") end)
    searchBox.FocusLost:Connect(function() tween(searchStroke, .15, { Color = T.Border }) SetIconState(icSearch, "normal") end)
    clearBtn.Activated:Connect(function() searchBox.Text = "" end)

    local host = new("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, ClipsDescendants = true }, content)

    local function dims()
        if state.max then
            local vp, s = gui.AbsoluteSize, baseScale()
            return math.floor((vp.X - 12) / s), math.floor((vp.Y - 12) / s)
        end
        return WIN_W, WIN_H
    end
    local FLOAT_SZ = 46
    local function vpSize()
        local v = gui.AbsoluteSize
        if v.X < 10 or v.Y < 10 then return Vector2.new(1280, 720) end
        return v
    end
    local function axis(f, half, vp)
        local lo, hi = half / vp, 1 - half / vp
        if lo >= hi then return .5 end
        return math.clamp(f, lo, hi)
    end
    local function placeWin(animate)
        local fx, fy = .5, .5
        if not state.max then
            local vp, s = vpSize(), baseScale()
            local w, h = dims()
            POS.win.x = axis(POS.win.x, w * s / 2, vp.X)
            POS.win.y = axis(POS.win.y, h * s / 2, vp.Y)
            fx, fy = POS.win.x, POS.win.y
        end
        local target = UDim2.fromScale(fx, fy)
        if animate then tween(win, .26, { Position = target }, Enum.EasingStyle.Quint) else win.Position = target end
    end
    local function applySize(animate)
        local w, h = dims()
        local goal = UDim2.fromOffset(w, h)
        if animate then tween(win, .26, { Size = goal }, Enum.EasingStyle.Quint) else win.Size = goal end
        placeWin(animate)
    end

    local float = new("TextButton", { Text = "", Size = UDim2.fromOffset(FLOAT_SZ, FLOAT_SZ), AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.fromScale(.5, .5), BackgroundColor3 = "Bg", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 60 }, gui)
    round(float, 23) stroke(float, "Accent", 1.5, .15)
    local icFloat = CreateIcon("logo", 26, float, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5) })
    SetIconState(icFloat, "active")
    local function placeFloat()
        local vp, half = vpSize(), FLOAT_SZ / 2
        local fx = POS.float.x < 0 and (38 / vp.X) or POS.float.x -- default: 38px from the left edge
        fx = axis(fx, half, vp.X)
        if POS.float.x >= 0 then POS.float.x = fx end
        POS.float.y = axis(POS.float.y, half, vp.Y) -- default y = .5 (vertical center)
        float.Position = UDim2.fromScale(fx, POS.float.y)
    end
    placeAll = function() placeWin(false) placeFloat() end
    UI.place = placeAll

    applyScale = function()
        local s = baseScale()
        if state.open then winScale.Scale = s end
        notifScale.Scale = math.clamp(s, .7, 1)
        applySize(false)
        placeFloat()
    end
    UI.float = float

    local function openWindow()
        state.open = true
        win.Visible = true
        local s = baseScale()
        winScale.Scale = s * .88
        tween(winScale, .3, { Scale = s }, Enum.EasingStyle.Back)
        float.Visible = false
        placeWin(false)
        if UI.runLive then task.defer(UI.runLive, true) end
    end
    local function hideWindow(mode)
        state.open = false
        tip.Visible = false
        tween(winScale, .18, { Scale = baseScale() * .88 })
        task.delay(.2, function() if not state.open and win.Parent then win.Visible = false end end)
        if mode == "min" or IS_TOUCH then
            placeFloat()
            float.Visible = true
            float.BackgroundTransparency = mode == "min" and 0 or .55
            float.Size = UDim2.fromOffset(0, 0)
            tween(float, .3, { Size = UDim2.fromOffset(46, 46) }, Enum.EasingStyle.Back)
        end
        if mode == "close" then
            notify(IS_TOUCH and "Interface closed. Tap the faded button to reopen." or ("Interface closed. Press " .. tostring(S.toggle_key or "RightShift") .. " to reopen."), "info", 3)
        end
    end
    local function toggleWindow() if state.open then hideWindow("min") else openWindow() end end
    UI.openWindow, UI.toggleWindow = openWindow, toggleWindow

    btnClose.Activated:Connect(function() hideWindow("close") end)
    btnMin.Activated:Connect(function() hideWindow("min") end)
    btnMax.Activated:Connect(function()
        state.max = not state.max
        icMax.root.Visible = not state.max
        icMaxAlt.root.Visible = state.max
        applySize(true)
        task.delay(.28, function() if alive then placeWin(false) end end)
    end)
    local unloadToken = 0
    btnUnload.Activated:Connect(function()
        if state.unloadArmed then
            task.defer(function() if _G.__CAZX_CLEANUP then _G.__CAZX_CLEANUP() end end)
            return
        end
        state.unloadArmed = true
        unloadToken += 1
        local mine = unloadToken
        SetIconColor(icUnload, T.Bad)
        notify("Tap Unload again within 4 seconds to remove the hub", "warn", 4)
        task.delay(4, function()
            if mine == unloadToken and alive then
                state.unloadArmed = false
                SetIconColor(icUnload, nil)
            end
        end)
    end)

    local function applySidebar(animate)
        local w = state.sb and SB_OPEN or SB_MIN
        local p1, p2 = { Size = UDim2.new(0, w, 1, 0) }, { Position = UDim2.fromOffset(w, 0), Size = UDim2.new(1, -w, 1, 0) }
        if animate then
            tween(sidebar, .22, p1, Enum.EasingStyle.Quint)
            tween(content, .22, p2, Enum.EasingStyle.Quint)
        else
            for k, v in pairs(p1) do sidebar[k] = v end
            for k, v in pairs(p2) do content[k] = v end
        end
    end
    UI.applySidebar = applySidebar
    btnMenu.Activated:Connect(function() state.sb = not state.sb applySidebar(true) end)

    local function savePos() if markDirty then markDirty() end end
    titleBar.InputBegan:Connect(function(input)
        if not isPress(input) or state.max then return end
        local startIn, sx, sy = input.Position, POS.win.x, POS.win.y
        beginDrag(input, function(pos)
            local d, vp = pos - startIn, vpSize()
            POS.win.x, POS.win.y = sx + d.X / vp.X, sy + d.Y / vp.Y
            placeWin(false)
        end, savePos)
    end)
    float.InputBegan:Connect(function(input)
        if not isPress(input) then return end
        local startIn, moved = input.Position, false
        local vp0 = vpSize()
        local sx = POS.float.x < 0 and (38 / vp0.X) or POS.float.x
        local sy = POS.float.y
        beginDrag(input, function(pos)
            local d, vp = pos - startIn, vpSize()
            if d.Magnitude > 6 then moved = true end
            if moved then
                POS.float.x, POS.float.y = sx + d.X / vp.X, sy + d.Y / vp.Y
                placeFloat()
            end
        end, function() if moved then savePos() else openWindow() end end)
    end)

    Root.add(UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        local ok, key = pcall(function() return Enum.KeyCode[S.toggle_key or "RightShift"] end)
        if ok and input.KeyCode == key then
            if state.open then hideWindow("min") else openWindow() end
        end
    end))
    Root.add(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() applyScale() end))
    Root.add(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function() task.defer(function() if alive then applyScale() end end) end))

    local function makeCard(parent, h)
        local c = new("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = "Card", BackgroundTransparency = "Tr",
            BorderSizePixel = 0, LayoutOrder = #parent:GetChildren() }, parent)
        round(c, 9)
        return c, stroke(c, "Border", 1, .2)
    end
    local function attachFx(card, st, hit)
        if hit:IsA("GuiButton") then
            hit.MouseButton1Down:Connect(function() tween(card, .08, { BackgroundColor3 = T.AccentDim }) end)
            hit.MouseButton1Up:Connect(function() tween(card, .12, { BackgroundColor3 = IS_TOUCH and T.Card or T.CardHover }) end)
        end
        if not IS_TOUCH then
            hit.MouseEnter:Connect(function() tween(card, .12, { BackgroundColor3 = T.CardHover }) tween(st, .12, { Color = T.Accent }) end)
        end
        hit.MouseLeave:Connect(function() tween(card, .15, { BackgroundColor3 = T.Card }) tween(st, .15, { Color = T.Border }) end)
    end
    local function nameDesc(card, f, rightPad)
        local py = math.floor((ROW_H - 36) / 2)
        local dim = f.unavailable ~= nil
        text(card, f.name, 13, dim and "Sub" or "Text", true, { Position = UDim2.fromOffset(12, py), Size = UDim2.new(1, -rightPad, 0, 18) })
        text(card, f.desc or "", 11, "Sub", false, { Position = UDim2.fromOffset(12, py + 19), Size = UDim2.new(1, -rightPad, 0, 16), TextTransparency = dim and .35 or 0 })
    end
    local function tipFor(f)
        return (f.desc or "") .. (f.unavailable and ("\n[!] " .. f.unavailable) or "")
    end

    local function buildToggle(f, parent)
        local card, st = makeCard(parent, ROW_H)
        nameDesc(card, f, 176)
        local status = text(card, "OFF", 10, T.Sub, true, { Position = UDim2.new(1, -166, 0, 0), Size = UDim2.new(0, 106, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
        local track = new("Frame", { Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -50, .5, -10), BackgroundColor3 = T.Off, BorderSizePixel = 0 }, card)
        round(track, 10)
        local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 3, .5, -7), BackgroundColor3 = "OnAccent", BorderSizePixel = 0 }, track)
        round(knob, 7)
        local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
        attachFx(card, st, hit)
        bindTooltip(hit, tipFor(f))
        hit.Activated:Connect(function()
            if f.unavailable then notify(f.name .. ": " .. f.unavailable, "warn", 4) return end
            setValue(f.id, not S[f.id])
        end)
        local function update(instant)
            local on = S[f.id] == true
            local nav = f.unavailable ~= nil
            local col = (not nav and on) and T.Accent or T.Off
            local kp = on and UDim2.new(1, -17, .5, -7) or UDim2.new(0, 3, .5, -7)
            if instant then track.BackgroundColor3 = col knob.Position = kp
            else tween(track, .16, { BackgroundColor3 = col }) tween(knob, .16, { Position = kp }, Enum.EasingStyle.Back) end
            status.Text = nav and (f.badge or "UNAVAILABLE") or (on and "ON" or "OFF")
            status.TextColor3 = nav and T.Warn or (on and T.Good or T.Sub)
        end
        return card, update
    end

    local function fmt(f, v) if (f.step or 1) < 1 then return ("%.2f"):format(v) end return tostring(v) end

    local function buildSlider(f, parent)
        local card, st = makeCard(parent, ROW_H + 22)
        nameDesc(card, f, 110)
        local py = math.floor((ROW_H - 36) / 2)
        local valLbl = text(card, "", 12, "Accent", true, { Position = UDim2.new(1, -92, 0, py), Size = UDim2.new(0, 80, 0, 18), TextXAlignment = Enum.TextXAlignment.Right })
        local track = new("Frame", { Position = UDim2.new(0, 12, 0, ROW_H + 4), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = "Off", BorderSizePixel = 0 }, card)
        round(track, 3)
        local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0 }, track)
        round(fill, 3)
        local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(0, 0, .5, 0), BackgroundColor3 = "Text", BorderSizePixel = 0 }, track)
        round(knob, 7)
        local hit = new("TextButton", { Position = UDim2.new(0, 0, 0, ROW_H - 8), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
        attachFx(card, st, card)
        bindTooltip(hit, tipFor(f))
        local function setFromX(x)
            local r = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            setValue(f.id, f.min + (f.max - f.min) * r)
        end
        hit.InputBegan:Connect(function(input)
            if not isPress(input) then return end
            if f.unavailable then notify(f.name .. ": " .. f.unavailable, "warn", 4) return end
            parent.ScrollingEnabled = false
            setFromX(input.Position.X)
            beginDrag(input, function(pos) setFromX(pos.X) end, function() parent.ScrollingEnabled = true end)
        end)
        local function update()
            local r = (S[f.id] - f.min) / (f.max - f.min)
            fill.Size = UDim2.fromScale(r, 1)
            knob.Position = UDim2.new(r, 0, .5, 0)
            valLbl.Text = f.unavailable and "N/A" or fmt(f, S[f.id])
            fill.BackgroundColor3 = f.unavailable and T.Off or T.Accent
        end
        return card, update
    end

    local function buildDropdown(f, parent)
        local n = #f.options
        local isOpen = false
        local card, st = makeCard(parent, ROW_H)
        card.ClipsDescendants = true
        nameDesc(card, f, 160)
        attachFx(card, st, card)
        local btn = new("TextButton", { Position = UDim2.new(1, -138, 0, (ROW_H - 30) / 2), Size = UDim2.fromOffset(126, 30), BackgroundColor3 = "Bg",
            Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, card)
        round(btn, 7) stroke(btn, "Border", 1, .1)
        local valLbl = text(btn, "", 12, "Text", true, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -28, 1, 0) })
        local chev = CreateIcon("chevron", 14, btn, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.new(1, -14, .5, 0) })
        SetIconState(chev, "active")
        bindTooltip(btn, tipFor(f))
        local optBtns = {}
        local function setOpen(o)
            isOpen = o
            tween(chev.root, .18, { Rotation = o and 180 or 0 })
            tween(card, .2, { Size = UDim2.new(1, 0, 0, o and (ROW_H + n * 32 + 6) or ROW_H) }, Enum.EasingStyle.Quint)
        end
        for i, opt in ipairs(f.options) do
            local ob = new("TextButton", { Position = UDim2.new(0, 10, 0, ROW_H + (i - 1) * 32), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = T.Bg,
                Text = opt, TextColor3 = T.Sub, Font = FONT, TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0 }, card)
            round(ob, 7)
            ob.Activated:Connect(function() setValue(f.id, opt) setOpen(false) end)
            optBtns[opt] = ob
        end
        btn.Activated:Connect(function()
            if f.unavailable then notify(f.name .. ": " .. f.unavailable, "warn", 4) return end
            setOpen(not isOpen)
        end)
        local function update()
            valLbl.Text = f.unavailable and "N/A" or tostring(S[f.id])
            for opt, ob in pairs(optBtns) do
                local sel = S[f.id] == opt
                ob.TextColor3 = sel and T.Text or T.Sub
                tween(ob, .12, { BackgroundColor3 = sel and T.AccentDim or T.Bg })
            end
        end
        return card, update
    end

    local function buildButton(f, parent)
        local card, st = makeCard(parent, ROW_H)
        nameDesc(card, f, 100)
        local nav = f.unavailable ~= nil
        local pill = new("Frame", { Size = UDim2.fromOffset(62, 26), Position = UDim2.new(1, -74, .5, -13), BackgroundColor3 = nav and T.Off or T.AccentDim, BorderSizePixel = 0 }, card)
        round(pill, 7)
        local lbl = text(pill, nav and "N/A" or "RUN", 11, T.Text, true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
        local hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, card)
        attachFx(card, st, hit)
        bindTooltip(hit, tipFor(f))
        hit.Activated:Connect(function()
            if f.unavailable then notify(f.name .. ": " .. f.unavailable, "warn", 4) return end
            local ok, r1, r2 = pcall(f.run)
            if not ok then notify("Error: " .. tostring(r1), "bad", 4)
            elseif r1 == false then notify(r2 or "Action failed", "warn", 4) end
        end)
        return card, function() pill.BackgroundColor3 = nav and T.Off or T.AccentDim lbl.TextColor3 = T.Text end
    end

    local function buildTextbox(f, parent)
        local card = makeCard(parent, 120)
        text(card, f.name, 13, "Text", true, { Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 18) })
        text(card, f.desc or "", 11, "Sub", false, { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 16) })
        local box = new("TextBox", { Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 66), BackgroundColor3 = "Bg", TextColor3 = "Text",
            PlaceholderText = "Press Export, or paste config JSON here and press Import", PlaceholderColor3 = "Sub", Text = "", Font = MONO,
            TextSize = 11, MultiLine = true, TextWrapped = true, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, BorderSizePixel = 0 }, card)
        round(box, 7)
        new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4) }, box)
        uiRefs.configBox = box
        return card, function() end
    end

    local function buildColor(f, parent)
        local sw = IS_TOUCH and 30 or 26
        local card, st = makeCard(parent, ROW_H + (f.palette and 38 or 0))
        nameDesc(card, f, 210)
        attachFx(card, st, card)
        local swatch = new("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -132, 0, (ROW_H - 24) / 2), BackgroundColor3 = T[f.key], BorderSizePixel = 0 }, card)
        round(swatch, 7) stroke(swatch, "Border", 1, 0)
        local box = new("TextBox", { Position = UDim2.new(1, -100, 0, (ROW_H - 28) / 2), Size = UDim2.fromOffset(88, 28), BackgroundColor3 = "Bg", Text = "",
            PlaceholderText = "Auto", PlaceholderColor3 = "Sub", TextColor3 = "Text", Font = MONO, TextSize = 12, ClearTextOnFocus = false, BorderSizePixel = 0 }, card)
        round(box, 7) stroke(box, "Border", 1, .1)
        box.FocusLost:Connect(function()
            local v = box.Text:match("^%s*(.-)%s*$")
            if v ~= "" and v:sub(1, 1) ~= "#" then v = "#" .. v end
            if v ~= "" and not hexColor(v) then
                notify("Invalid color. Use #RRGGBB", "warn", 3)
                box.Text = S[f.id]
                return
            end
            setValue(f.id, v)
        end)
        if f.palette then
            for i, hex in ipairs(ACCENT_SWATCHES) do
                local b = new("TextButton", { Text = "", Size = UDim2.fromOffset(sw, sw), Position = UDim2.new(0, 12 + (i - 1) * (sw + 6), 0, ROW_H + 3),
                    BackgroundColor3 = Color3.fromHex(hex), AutoButtonColor = false, BorderSizePixel = 0 }, card)
                round(b, sw / 2) stroke(b, "Border", 1, 0)
                b.Activated:Connect(function() setValue(f.id, hex) end)
            end
        end
        return card, function() swatch.BackgroundColor3 = T[f.key] box.Text = S[f.id] end
    end

    local builders = { toggle = buildToggle, slider = buildSlider, dropdown = buildDropdown, button = buildButton, textbox = buildTextbox, color = buildColor }
    local function buildRow(f, parent)
        local row, update = builders[f.kind](f, parent)
        f.views[row] = update
        row.Destroying:Connect(function() f.views[row] = nil end)
        update(true)
        return row
    end

    local function newPage()
        local p = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = IS_TOUCH and 5 or 3, ScrollBarImageColor3 = "Accent", AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable }, host)
        new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, p)
        new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }, p)
        return p
    end

    local currentPage, searchPage
    local function showPage(p, animate)
        tip.Visible = false
        if currentPage and currentPage ~= p then currentPage.Visible = false end
        currentPage = p
        p.Visible = true
        if animate then
            p.Position = UDim2.fromOffset(0, 16)
            tween(p, .22, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
        else
            p.Position = UDim2.fromOffset(0, 0)
        end
        if UI.runLive then task.defer(UI.runLive) end
    end
    UI.currentPage = function() return currentPage end

    switchTab = function(name, instant)
        local t = TabByName[name]
        if not t or not t.page then return end
        S._tab = name
        for _, tt in ipairs(Tabs) do
            tt.isActive = tt == t
            if tt.setActive then tt.setActive(tt.isActive, not instant) end
        end
        if currentPage ~= searchPage then showPage(t.page, not instant) end
        markDirty()
    end

    local function buildTab(t)
        local btn = new("TextButton", { Size = UDim2.new(1, -10, 0, TAB_H), BackgroundColor3 = "Card", BackgroundTransparency = 1,
            Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = #sideList:GetChildren() }, sideList)
        round(btn, 9)
        local ind = new("Frame", { AnchorPoint = Vector2.new(0, .5), Position = UDim2.new(0, 0, .5, 0), Size = UDim2.fromOffset(3, 0), BackgroundColor3 = "Accent", BorderSizePixel = 0 }, btn)
        round(ind, 2)
        local ic = CreateIcon(t.icon, 18, btn, { Position = UDim2.fromOffset((SB_MIN - 10 - 18) / 2, (TAB_H - 18) / 2) })
        local nameLbl = text(btn, t.name, 12, T.Sub, true, { Position = UDim2.fromOffset(SB_MIN - 10, 0), Size = UDim2.new(1, -(SB_MIN - 10), 1, 0) })
        t.setActive = function(on, animate)
            local p1, p2 = { BackgroundTransparency = on and 0 or 1 }, { Size = UDim2.fromOffset(3, on and 20 or 0) }
            nameLbl.TextColor3 = on and T.Text or T.Sub
            SetIconState(ic, on and "active" or "normal")
            if animate then tween(btn, .18, p1) tween(ind, .2, p2, Enum.EasingStyle.Back)
            else btn.BackgroundTransparency = p1.BackgroundTransparency ind.Size = p2.Size end
        end
        btn.MouseEnter:Connect(function()
            if t.isActive or IS_TOUCH then return end
            tween(btn, .12, { BackgroundTransparency = .6 })
            SetIconState(ic, "hover")
        end)
        btn.MouseLeave:Connect(function()
            if t.isActive then return end
            tween(btn, .15, { BackgroundTransparency = 1 })
            SetIconState(ic, "normal")
        end)
        bindTooltip(btn, t.name)
        btn.Activated:Connect(function()
            if searchBox.Text ~= "" then searchBox.Text = "" end
            switchTab(t.name)
        end)
    end

    local searchToken = 0
    local function emptyState(parent, msg)
        local c = new("Frame", { Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, LayoutOrder = 5 }, parent)
        local ic = CreateIcon("search", 26, c, { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 14) })
        SetIconState(ic, "disabled")
        text(c, msg, 12, "Sub", false, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center })
    end
    local function runSearch()
        tip.Visible = false
        local q = searchBox.Text:lower():match("^%s*(.-)%s*$")
        clearBtn.Visible = searchBox.Text ~= ""
        for _, c in ipairs(searchPage:GetChildren()) do
            if c:IsA("GuiObject") then
                for _, d in ipairs(c:GetDescendants()) do
                    for _, ic in ipairs(Icons) do if ic.root == d then DestroyIcon(ic) break end end
                end
                c:Destroy()
            end
        end
        pruneBindings()
        if q == "" then
            if currentPage == searchPage then showPage(TabByName[S._tab].page, false) end
            return
        end
        text(searchPage, "SEARCH RESULTS", 11, "Accent", true, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0 })
        local n = 0
        for _, f in ipairs(FeatList) do
            if f.kind ~= "textbox" and n < 30 and ((f.name:lower():find(q, 1, true)) or ((f.desc or ""):lower():find(q, 1, true)) or f.tab:lower():find(q, 1, true)) then
                buildRow(f, searchPage)
                n += 1
            end
        end
        if n == 0 then emptyState(searchPage, "No features found.") end
        showPage(searchPage, false)
    end
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        clearBtn.Visible = searchBox.Text ~= ""
        searchToken += 1
        local mine = searchToken
        task.delay(.18, function() if mine == searchToken and alive then runSearch() end end)
    end)

    local liveFns = {}
    local function runLive(force)
        if not alive or not state.open then return end
        local page = currentPage
        for _, l in ipairs(liveFns) do
            if force or l.page == page then pcall(l.fn) end
        end
    end
    UI.runLive = runLive
    UI.onTheme = function() runLive(true) if UI.themeLbl then UI.themeLbl.Text = (S.theme_preset or "Obsidian Dark") end end

    local function statGrid(parent, order)
        local g = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, parent)
        new("UIGridLayout", { CellSize = UDim2.new(.5, -4, 0, 50), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }, g)
        return g
    end
    local function statTile(grid, page, label, getFn, tipText)
        local c = new("Frame", { BackgroundColor3 = "Card", BackgroundTransparency = "Tr", BorderSizePixel = 0, LayoutOrder = #grid:GetChildren() }, grid)
        round(c, 9) stroke(c, "Border", 1, .2)
        text(c, label:upper(), 9, "Sub", true, { Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 12) })
        local v = text(c, "", 13, T.Text, true, { Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 20) })
        local function update()
            local ok, val, col = pcall(getFn)
            v.Text = ok and tostring(val) or "N/A"
            v.TextColor3 = (ok and col and T[col]) or T.Text
        end
        liveFns[#liveFns + 1] = { page = page, fn = update }
        c.Destroying:Connect(function()
            for i, l in ipairs(liveFns) do if l.fn == update then table.remove(liveFns, i) break end end
        end)
        bindTooltip(c, tipText)
        update()
        return c
    end
    local function sectionLabel(parent, label, order)
        return text(parent, label, 11, "Accent", true, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order })
    end
    local function cashText(getter, fmtFn)
        return function()
            local v = getter()
            if v == nil then return "Not provided by game", "Warn" end
            return fmtFn and fmtFn(v) or formatNumber(v)
        end
    end

    local function buildHome(page)
        local hero = new("Frame", { Size = UDim2.new(1, 0, 0, 128), BackgroundColor3 = "Card", BackgroundTransparency = "Tr", BorderSizePixel = 0, LayoutOrder = 1 }, page)
        round(hero, 12) stroke(hero, "Border", 1, .1)
        new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(214, 214, 222)) }, hero)
        local frame = new("Frame", { Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(14, 18), BackgroundColor3 = "Bg", BorderSizePixel = 0 }, hero)
        round(frame, 14) stroke(frame, "Accent", 1.5, .15)
        local img = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Crop, BorderSizePixel = 0, ImageTransparency = 1 }, frame)
        round(img, 14)
        local initial = text(frame, (Player.DisplayName:sub(1, 1) or "?"):upper(), 30, "Accent", true, { Size = UDim2.new(1, 0, 1, -14), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
        local msg = text(frame, "Loading", 10, "Sub", true, { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })
        local retry = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, frame)
        text(hero, Player.DisplayName, 18, "Text", true, { Position = UDim2.fromOffset(122, 16), Size = UDim2.new(1, -136, 0, 24) })
        text(hero, "@" .. Player.Name, 12, "Sub", false, { Position = UDim2.fromOffset(122, 41), Size = UDim2.new(1, -136, 0, 18) })
        text(hero, "USER ID  " .. tostring(Player.UserId), 10, "Sub", true, { Position = UDim2.fromOffset(122, 66), Size = UDim2.new(1, -136, 0, 14) })
        text(hero, "ACCOUNT AGE  " .. (type(Player.AccountAge) == "number" and (tostring(Player.AccountAge) .. " days") or "N/A"), 10, "Sub", true, { Position = UDim2.fromOffset(122, 82), Size = UDim2.new(1, -136, 0, 14) })
        local chip = new("Frame", { Position = UDim2.fromOffset(122, 102), Size = UDim2.fromOffset(112, 18), BackgroundColor3 = "AccentDim", BorderSizePixel = 0 }, hero)
        round(chip, 9)
        text(chip, "SCRIPT ACTIVE", 9, "Good", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })

        local av = { busy = false, status = "loading" }
        UI.avatar = av
        local function fetchAvatar()
            if av.busy then return end
            av.busy = true
            av.status = "loading"
            if img.Image == "" then msg.Visible = true msg.Text = "Loading" initial.Visible = true end
            task.spawn(function()
                local content, ready
                for attempt = 1, 4 do
                    if not alive then break end
                    local ok, c, r = pcall(function()
                        return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size150x150)
                    end)
                    if ok and type(c) == "string" and c ~= "" then
                        content, ready = c, r
                        if r then break end
                    end
                    task.wait(attempt)
                end
                av.busy = false
                av.done = true
                if not alive or not frame.Parent then return end
                if content then
                    img.Image = content
                    tween(img, .3, { ImageTransparency = 0 })
                    msg.Visible = false
                    initial.Visible = false
                    av.status = ready and "loaded" or "loaded (placeholder image)"
                elseif img.Image == "" then
                    av.status = "failed"
                    msg.Visible = true
                    msg.Text = "Tap to retry"
                end
            end)
        end
        UI.fetchAvatar = fetchAvatar
        retry.Activated:Connect(function() if img.Image == "" then fetchAvatar() end end)
        local respawnToken = 0
        Root.add(Player.CharacterAdded:Connect(function()
            respawnToken += 1
            local mine = respawnToken
            task.delay(2, function() if alive and mine == respawnToken then fetchAvatar() end end)
        end))

        sectionLabel(page, "QUICK OVERVIEW", 2)
        local grid = statGrid(page, 3)
        local p = page
        statTile(grid, p, "Game", function() return game.Name ~= "" and game.Name or "Unknown" end, "Current game")
        statTile(grid, p, "Place ID", function() return game.PlaceId end)
        statTile(grid, p, "Server JobId", function() return game.JobId ~= "" and (game.JobId:sub(1, 8) .. "...") or "Studio / unavailable" end, game.JobId)
        statTile(grid, p, "Session Uptime", function() return formatTime(os.clock() - sessionStart) end)
        statTile(grid, p, "Players", function() return #Players:GetPlayers() .. " / " .. Players.MaxPlayers end)
        statTile(grid, p, "Active Features", function() return activeCount() end)
        statTile(grid, p, "Current Cash", cashText(getCash))
        statTile(grid, p, "Cash Gained", cashText(function() local c = getCash() return c and cashBase and (c - cashBase) or nil end))
        statTile(grid, p, "Cash Per Second", cashText(cashPerSecond))
        statTile(grid, p, "Script Status", function()
            if bootWarnings > 0 then return "Running, " .. bootWarnings .. " warning(s)", "Warn" end
            return "Running", "Good"
        end)
    end

    local function buildStatistics(page)
        sectionLabel(page, "LIVE STATISTICS", 1)
        local grid = statGrid(page, 2)
        local p = page
        statTile(grid, p, "FPS", function() return math.floor(fpsValue + .5) end)
        statTile(grid, p, "Ping", function()
            local v = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            return math.floor(v) .. " ms"
        end)
        statTile(grid, p, "Memory", function() return math.floor(Stats:GetTotalMemoryUsageMb()) .. " MB" end)
        statTile(grid, p, "Players", function() return #Players:GetPlayers() end)
        statTile(grid, p, "Session Uptime", function() return formatTime(os.clock() - sessionStart) end)
        statTile(grid, p, "Cash Gained", cashText(function() local c = getCash() return c and cashBase and (c - cashBase) or nil end))
        statTile(grid, p, "Cash Per Second", cashText(cashPerSecond))
        statTile(grid, p, "Speed Power", cashText(function() return numAttr("SpeedPower") end))
        statTile(grid, p, "Pickaxe Tier", cashText(function() return numAttr("PickaxeTier") end, tostring))
        statTile(grid, p, "Carrying", function() local c = Player:GetAttribute("Carrying") return c == nil and "Nothing" or tostring(c) end)
    end

    local function diagRow(page, section, label, getFn)
        local c = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = "Card", BackgroundTransparency = "Tr", BorderSizePixel = 0, LayoutOrder = #page:GetChildren() }, page)
        round(c, 8) stroke(c, "Border", 1, .3)
        text(c, label, 12, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(.55, -12, 1, 0) })
        local v = text(c, "", 12, T.Sub, true, { Position = UDim2.new(.55, 0, 0, 0), Size = UDim2.new(.45, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
        local function update()
            local ok, val, col = pcall(getFn)
            v.Text = ok and tostring(val) or "error"
            v.TextColor3 = (ok and col and T[col]) or T.Text
        end
        liveFns[#liveFns + 1] = { page = page, fn = update }
        diagItems[#diagItems + 1] = { label = section .. " / " .. label, fn = function() return (getFn()) end }
        update()
    end
    local function yesNo(v) if v then return "Available", "Good" end return "Missing", "Warn" end

    local function buildDiagnostics(page)
        sectionLabel(page, "ENVIRONMENT", 1)
        diagRow(page, "Env", "File access", function() return yesNo(HAS_FILES) end)
        diagRow(page, "Env", "Clipboard", function() return yesNo(HAS_CLIPBOARD) end)
        diagRow(page, "Env", "HTTP request", function() return yesNo(HTTP_REQUEST ~= nil) end)
        diagRow(page, "Env", "FPS cap", function() return yesNo(HAS_FPSCAP) end)
        diagRow(page, "Env", "Input mode", function() return IS_TOUCH and "Touch" or "Keyboard / mouse" end)
        diagRow(page, "Env", "Viewport", function() local v = gui.AbsoluteSize return math.floor(v.X) .. " x " .. math.floor(v.Y) end)
        sectionLabel(page, "GAME DEPENDENCIES", #page:GetChildren())
        diagRow(page, "Game", "Workspace.Build.ZoneBuilds", function()
            local b = workspace:FindFirstChild("Build")
            return yesNo(b and b:FindFirstChild("ZoneBuilds") ~= nil)
        end)
        for _, rn in ipairs({ "PetsInventoryRemote", "PickaxeShopRequest", "UpgradePlotRequest", "TreadmillSessionRemote" }) do
            diagRow(page, "Game", rn, function() return yesNo(getRemote(rn) ~= nil) end)
        end
        diagRow(page, "Game", "Cash attribute", function() return yesNo(numAttr("Cash") ~= nil) end)
        diagRow(page, "Game", "PickaxeTier attribute", function() return yesNo(numAttr("PickaxeTier") ~= nil) end)
        sectionLabel(page, "INTERFACE", #page:GetChildren())
        diagRow(page, "UI", "Avatar thumbnail", function()
            local s = UI.avatar and UI.avatar.status or "not started"
            return s, (s:find("loaded") and "Good") or (s == "failed" and "Bad") or "Warn"
        end)
        diagRow(page, "UI", "Theme", function() return S.theme_preset or "Obsidian Dark" end)
        diagRow(page, "UI", "Themed objects", function() return #bindings end)
        diagRow(page, "UI", "Icons alive", function() return #Icons end)
        diagRow(page, "UI", "Features total", function() return #FeatList end)
        diagRow(page, "UI", "Features supported", function()
            local n = 0
            for _, f in ipairs(FeatList) do if not f.unavailable and (f.kind == "toggle" or f.kind == "button") then n += 1 end end
            return n, "Good"
        end)
        diagRow(page, "UI", "Features unsupported", function()
            local n = 0
            for _, f in ipairs(FeatList) do if f.unavailable then n += 1 end end
            return n, n > 0 and "Warn" or "Good"
        end)
        diagRow(page, "UI", "Boot warnings", function() return bootWarnings, bootWarnings > 0 and "Warn" or "Good" end)
    end

    local function buildAbout(page)
        local card = makeCard(page, 188)
        text(card, APP_NAME .. "  " .. EDITION, 18, "Text", true, { Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 26) })
        local lines = {
            "Version " .. VERSION .. "  |  Build " .. BUILD,
            "Target game: Steal an Egg",
            "Features without a verified game dependency are marked NEEDS INTEGRATION, NOT PROVIDED or UNAVAILABLE and stay disabled instead of being faked.",
            "Farm helpers use remotes named in KryvenHub and check that each one exists at runtime before sending anything.",
            "Nothing on this hub has been verified inside the live game by its author.",
        }
        local y = 42
        for _, l in ipairs(lines) do
            local h = #l > 70 and 34 or 18
            text(card, l, 11, "Sub", false, { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, h), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top })
            y += h + 4
        end
    end

    local function buildThemePreview(page)
        sectionLabel(page, "CURRENT THEME PREVIEW", 1)
        local pv = new("Frame", { Size = UDim2.new(1, 0, 0, 112), BackgroundColor3 = "Bg", BorderSizePixel = 0, LayoutOrder = 2 }, page)
        round(pv, 10) stroke(pv, "Border", 1, 0)
        local side = new("Frame", { Size = UDim2.new(0, 34, 1, 0), BackgroundColor3 = "Panel", BorderSizePixel = 0 }, pv)
        round(side, 10)
        for i = 1, 3 do
            new("Frame", { Size = UDim2.fromOffset(16, 3), Position = UDim2.fromOffset(9, 14 + (i - 1) * 16), BackgroundColor3 = i == 1 and "Accent" or "Sub", BorderSizePixel = 0 }, side)
        end
        UI.themeLbl = text(pv, S.theme_preset or "Obsidian Dark", 14, "Text", true, { Position = UDim2.fromOffset(46, 8), Size = UDim2.new(1, -170, 0, 20) })
        text(pv, "Secondary text sample", 11, "Sub", false, { Position = UDim2.fromOffset(46, 29), Size = UDim2.new(1, -170, 0, 16) })
        local mock = new("Frame", { Position = UDim2.fromOffset(46, 52), Size = UDim2.new(1, -60, 0, 24), BackgroundColor3 = "Card", BorderSizePixel = 0 }, pv)
        round(mock, 7) stroke(mock, "Border", 1, .2)
        local tr = new("Frame", { Size = UDim2.fromOffset(32, 16), Position = UDim2.new(1, -42, .5, -8), BackgroundColor3 = "Accent", BorderSizePixel = 0 }, mock)
        round(tr, 8)
        local kn = new("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(1, -16, .5, -6), BackgroundColor3 = "OnAccent", BorderSizePixel = 0 }, tr)
        round(kn, 6)
        text(mock, "Sample feature", 11, "Text", true, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -60, 1, 0) })
        local keys = { "Bg", "Panel", "Border", "Accent", "Text", "Sub" }
        for i, k in ipairs(keys) do
            local sq = new("Frame", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(46 + (i - 1) * 24, 86), BackgroundColor3 = k, BorderSizePixel = 0 }, pv)
            round(sq, 5) stroke(sq, "Border", 1, 0)
        end
        local pill = new("Frame", { Size = UDim2.fromOffset(64, 22), Position = UDim2.new(1, -76, 0, 84), BackgroundColor3 = "AccentDim", BorderSizePixel = 0 }, pv)
        round(pill, 7)
        text(pill, "BUTTON", 10, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center })
    end

    local custom = { Home = buildHome, Statistics = buildStatistics, Diagnostics = buildDiagnostics, About = buildAbout, Theme = buildThemePreview }
    for _, t in ipairs(Tabs) do
        t.page = newPage()
        text(t.page, t.name:upper(), 11, "Accent", true, { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0 })
        if custom[t.name] then custom[t.name](t.page) end
        for _, f in ipairs(t.items) do buildRow(f, t.page) end
        if t.name ~= "Home" and t.name ~= "About" and #t.items == 0 and not custom[t.name] then emptyState(t.page, "Nothing here yet.") end
        buildTab(t)
    end
    searchPage = newPage()
    UI.searchPage = searchPage
    UI.searchBox = searchBox
end

local function unload()
    alive = false
    for _, f in ipairs(FeatList) do
        if f.kind == "toggle" and S[f.id] and f.fn then pcall(f.fn, false) S[f.id] = false end
    end
    pcall(saveConfig, true)
    for _, reg in pairs(activeTween) do
        for _, tw in pairs(reg) do pcall(function() tw:Cancel() end) end
    end
    table.clear(Icons)
    table.clear(bindings)
    table.clear(liveNotifs)
    Root.clear()
    _G.__CAZX_CLEANUP = nil
end
_G.__CAZX_CLEANUP = unload

local bootLog = {}
local function bootWarn(stageName, err)
    bootWarnings += 1
    bootLog[#bootLog + 1] = stageName .. ": " .. tostring(err)
    warn("[CAZX] " .. stageName .. ": " .. tostring(err))
end

local boot = new("CanvasGroup", { Name = "CazielxBoot", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
    Size = UDim2.fromOffset(360, 290), BackgroundColor3 = "Panel", BorderSizePixel = 0, ZIndex = 300, GroupTransparency = 1 }, gui)
round(boot, 16)
local bootStroke = stroke(boot, "Accent", 1.2, .4)
local bootScale = new("UIScale", { Scale = .92 }, boot)
local topGlow = new("Frame", { Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = "Accent", BorderSizePixel = 0 }, boot)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(.86, 1) }, topGlow)
local bootLogo = CreateIcon("logo", 36, boot, { AnchorPoint = Vector2.new(.5, 0), Position = UDim2.new(.5, 0, 0, 16) })
SetIconState(bootLogo, "active")
text(boot, APP_NAME, 20, "Text", true, { Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center })
text(boot, EDITION .. "  |  v" .. VERSION .. "  |  Build " .. BUILD, 10, "Sub", false, { Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })

local RING_N, RING_R = 28, 40
local ringSegs = {}
local litCount = 0
for i = 1, RING_N do
    local ang = (i - 1) / RING_N * math.pi * 2 - math.pi / 2
    ringSegs[i] = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.fromOffset(3, 10), BackgroundColor3 = T.Off, BorderSizePixel = 0,
        Position = UDim2.fromOffset(180 + math.cos(ang) * RING_R, 156 + math.sin(ang) * RING_R), Rotation = math.deg(ang) + 90 }, boot)
    round(ringSegs[i], 2)
end
local bootPct = text(boot, "0%", 17, "Text", true, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromOffset(180, 156), Size = UDim2.fromOffset(64, 24), TextXAlignment = Enum.TextXAlignment.Center })
local bootStatus = text(boot, "Initializing Core", 12, T.Text, false, { Position = UDim2.fromOffset(20, 208), Size = UDim2.new(1, -40, 0, 18), TextXAlignment = Enum.TextXAlignment.Center })
local bootTrack = new("Frame", { Position = UDim2.fromOffset(30, 234), Size = UDim2.new(1, -60, 0, 5), BackgroundColor3 = "Off", BorderSizePixel = 0 }, boot)
round(bootTrack, 3)
local bootFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = "Accent", BorderSizePixel = 0 }, bootTrack)
round(bootFill, 3)
local bootStage = text(boot, "STAGE 0 / 10", 9, "Sub", true, { Position = UDim2.fromOffset(0, 248), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center })

local function repaintRing()
    for i = 1, RING_N do ringSegs[i].BackgroundColor3 = i <= litCount and T.Accent or T.Off end
end
local function setRing(p)
    targetP = p
end
UI.onTheme = repaintRing

local shownP, targetP = 0, 0
local sweep = RunService.Heartbeat:Connect(function(dt)
    shownP += (targetP - shownP) * math.min(1, dt * 9)
    local lc = math.floor(shownP * RING_N + .5)
    if lc ~= litCount then litCount = lc repaintRing() bootPct.Text = math.floor(shownP * 100 + .5) .. "%" end
    local head = (os.clock() * 14) % RING_N
    for i = 1, RING_N do
        local d = (head - i) % RING_N
        local a = math.clamp(d / 10, 0, 1)
        ringSegs[i].BackgroundTransparency = i <= litCount and (a * .4) or (.5 + a * .4)
    end
end)
Root.add(sweep)
local glow = TweenService:Create(bootStroke, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = .05 })
Root.add(function() glow:Cancel() end)
glow:Play()

local function fitBoot()
    local vp = gui.AbsoluteSize
    if vp.X < 10 then return end
    bootScale.Scale = math.clamp(math.min(vp.X / 390, vp.Y / 320), .5, 1.15)
end
fitBoot()
local bootSizeConn = Root.add(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoot))
tween(boot, .3, { GroupTransparency = 0 })

local pendingConfig
local stages = {}
local function stage(name, fn) stages[#stages + 1] = { name, fn } end

stage("Initializing Core", function()
    assert(gui.Parent, "ScreenGui is not parented")
    assert(#Tabs > 0, "No tabs registered")
    assert(#FeatList > 0, "No features registered")
end)
stage("Loading Dependencies", function()
    local missing = {}
    for _, n in ipairs({ "Players", "RunService", "UserInputService", "TweenService", "Lighting", "TeleportService", "HttpService", "GuiService", "Stats", "VirtualUser", "ReplicatedStorage" }) do
        if not pcall(game.GetService, game, n) then missing[#missing + 1] = n end
    end
    local okHL, hl = pcall(Instance.new, "Highlight")
    if okHL then hl:Destroy() else missing[#missing + 1] = "Highlight" end
    assert(#missing == 0, "Missing: " .. table.concat(missing, ", "))
end)
stage("Checking Environment", function()
    assert(PlayerGui and PlayerGui.Parent, "PlayerGui unavailable")
    local failed = {}
    for _, f in ipairs(FeatList) do
        if f.check then
            local ok, good, why = pcall(f.check)
            if not ok then f.unavailable = "Check failed" failed[#failed + 1] = f.id
            elseif not good then f.unavailable = why or "Unavailable" end
        end
    end
    assert(#failed == 0, "Checks failed: " .. table.concat(failed, ", "))
end)
stage("Initializing Theme Engine", function()
    computeTheme()
    assert(T.Accent and T.Bg and T.Panel, "Theme tokens incomplete")
    assert(PRESETS[S.theme_preset or "Obsidian Dark"], "Unknown theme preset")
    applyTheme(false)
end)
stage("Loading Configuration", function()
    local json = readStoredConfig()
    if not json then return end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    assert(ok and type(data) == "table", "Stored configuration is corrupt")
    pendingConfig = data
    preloadTheme(data)
end)
stage("Building Interface", function()
    buildInterface()
    local prev = UI.onTheme
    UI.onTheme = function() if prev then prev() end repaintRing() end
    assert(UI.win and UI.win.Parent, "Window was not created")
end)
stage("Initializing Feature Registry", function()
    assert(UI.win, "Interface unavailable")
    if pendingConfig then
        local ok, msg = applyConfig(pendingConfig)
        assert(ok, msg)
    end
    updateActive()
end)
stage("Preparing Player Data", function()
    assert(UI.fetchAvatar, "Home page unavailable")
    UI.fetchAvatar()
    pcall(sampleStats)
    local waited = 0
    while not (UI.avatar and UI.avatar.done) and waited < 4 do
        waited += task.wait(.05)
    end
    assert(UI.avatar and UI.avatar.status ~= "failed", "Avatar thumbnail could not be loaded (tap the avatar to retry)")
end)
stage("Finalizing Interface", function()
    assert(UI.win, "Interface unavailable")
    UI.applySidebar(false)
    applyScale()
    switchTab(TabByName[S._tab] and S._tab or "Home", true)
    applyTheme(false)
    updateActive()
    Root.add(RunService.Heartbeat:Connect(function() frameCount += 1 end))
    task.spawn(function()
        while alive do
            task.wait(1)
            if not alive then break end
            local now = os.clock()
            fpsValue = frameCount / math.max(now - lastFpsAt, .001)
            frameCount, lastFpsAt = 0, now
            pcall(sampleStats)
            if UI.runLive then pcall(UI.runLive) end
        end
    end)
end)
stage("Ready", function()
    assert(UI.win and alive, "Interface is not ready")
end)

local total = #stages
for i, st in ipairs(stages) do
    bootStatus.TextColor3 = T.Text
    bootStatus.Text = st[1]
    bootStage.Text = ("STAGE %d / %d"):format(i, total)
    local ok, err = pcall(st[2])
    if not ok then
        bootWarn(st[1], err)
        bootStatus.TextColor3 = T.Bad
        bootStatus.Text = "Error: " .. st[1]
        task.wait(.45)
    end
    local p = i / total
    tween(bootFill, .35, { Size = UDim2.new(p, 0, 1, 0) }, Enum.EasingStyle.Quint)
    setRing(p)
    task.wait(.1)
end

if not UI.win then
    bootStatus.Text = "Interface failed to build. See output."
    task.wait(5)
else
    targetP = 1
    local w = 0
    while shownP < .985 and w < 1 do w += task.wait() end
    bootPct.Text = "100%"
    bootStatus.TextColor3 = bootWarnings > 0 and T.Warn or T.Good
    bootStatus.Text = bootWarnings > 0 and ("Ready with " .. bootWarnings .. " warning(s)") or "Ready"
    task.wait(.25)
    UI.openWindow()
    if bootWarnings > 0 then notify(bootLog[1], "warn", 6) end
end

sweep:Disconnect()
glow:Cancel()
bootSizeConn:Disconnect()
tween(boot, .3, { GroupTransparency = 1 })
tween(bootScale, .3, { Scale = bootScale.Scale * 1.06 })
task.wait(.32)
DestroyIcon(bootLogo)
if boot.Parent then boot:Destroy() end
