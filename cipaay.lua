--[[ CAZIELX ARCHX V2 FIXED
ROOT CAUSE: main chunk declared 247 top-level locals; Luau allows max 200 per function -> the whole file failed to COMPILE,
so the executor ran nothing (no UI, no loading screen, no error). buildInterface also captured ~80 upvalues (limit 60).
FIXES
 1. Top-level locals scoped into `do ... end` blocks (peak now ~157). Names still needed later are hoisted, logic unchanged.
 2. buildInterface reads its dependencies through two snapshot helpers (cazxEnvA/B) -> 13 upvalues instead of ~80.
 3. Startup diagnostics: STARTING / RUNNING / SUCCESS / FAILED / SKIPPED per stage, printed to console, stored in _G.CAZX_DIAG,
    full traceback on failure. Optional stages (artwork, config) report SKIPPED honestly instead of a fake SUCCESS.
 4. PlayerGui:WaitForChild now has a 15s timeout instead of yielding forever.
NOT CHANGED: features, theme, config format, UI identity, loading screen, existing pcall isolation of every stage.
NOTE: not executed in Delta or Roblox Studio (no Luau runtime in this environment) - verify in your executor.
]]
print("[CAZX][RUNNING] source compiled, startup begins")
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
local ContentProvider = game:GetService("ContentProvider")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 15)
assert(PlayerGui, "[CAZX][FAILED] PlayerGui not found within 15s")

if _G.__CAZX_CLEANUP then pcall(_G.__CAZX_CLEANUP) end

local APP_NAME = "CAZIELX"
local EDITION = "ARCHX"
local VERSION = "1.0.8 BETA"
local BUILD = "20261112"
local CHANGELOG = {
    "V1.0.8 BETA : one shared scheduler (single Heartbeat) for every feature loop, with overlap guard, error isolation and auto-stop after 8 consecutive errors.",
    "Farm: Auto Egg Scanner, Egg Distance Limit, Egg Rarity Filter, Ignore Eggs, Select All Eggs, Pause/Resume, egg respawn/vanish detection, Egg Collection History.",
    "Pets: Pet Scanner, Best Pet, Pet Inventory Tracker, Pet History, Rare Pet Threshold, New Pet Alerts (rarity read from attributes/values/name only).",
    "Money: session earnings (sum of real cash increases), average per egg, best pet, session tiles on Farm Status and Statistics.",
    "Webhook: per-event switches (egg, pet, rare pet, errors, session summary, game events), author line with player, richer statistics embed, session summary on demand and on unload.",
    "ESP: separate colors for skeleton, box, name/distance, highlight and eggs; Egg ESP now labels eggs; Rarity Indicator; Pet ESP shows the animal Tool other players carry.",
    "Event Detection: heuristic watcher on Workspace/ReplicatedStorage top level (no game names assumed).",
    "Config: Auto Save switch, visible warning when auto-save cannot write, defaults that must stay ON survive Reset.",
    "About: Open Link buttons (Discord, Social, Credit) with clipboard fallback. Loading artwork also accepts your own image file in the executor workspace.",
    "Not changed on purpose: items that need unverified game remotes stay marked NEEDS INTEGRATION instead of being faked.",
}
local CONFIG_FILE = "CAZIELX_ARCHX_config.json"
local IS_TOUCH = UIS.TouchEnabled and not UIS.KeyboardEnabled
local HAS_FILES = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"
local HAS_CLIPBOARD = typeof(setclipboard) == "function"
local HAS_FPSCAP = typeof(setfpscap) == "function"
local HTTP_REQUEST = (typeof(request) == "function" and request) or (typeof(http_request) == "function" and http_request) or nil
local FONT, BOLD, MONO = Enum.Font.Gotham, Enum.Font.GothamBold, Enum.Font.Code

local alive = true
local S = { _tab = "Home" }
local notify, markDirty, updateActive, applyScale, switchTab, applyTheme, placeAll, whEvent
local UI = {}
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

local computeTheme, bindings, pruneBindings, activeTween, tween, new, round, stroke, text, Icons, CreateIcon, SetIconColor, SetIconState, DestroyIcon, refreshIcons, iconHover, Tabs, TabByName, Feat, FeatList, addTab, def, na
do -- scope block (keeps main chunk under the 200-local limit)
local function lum(c) return .2126 * c.R + .7152 * c.G + .0722 * c.B end

function computeTheme()
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

bindings = {}
local COLOR_PROPS = { BackgroundColor3 = true, TextColor3 = true, ImageColor3 = true, Color = true, ScrollBarImageColor3 = true, PlaceholderColor3 = true }

local function bind(o, prop, key)
    bindings[#bindings + 1] = { o, prop, key }
    o[prop] = T[key]
end

function pruneBindings()
    local j = 0
    for i = 1, #bindings do
        local b = bindings[i]
        if b[1].Parent then j += 1 bindings[j] = b end
    end
    for i = #bindings, j + 1, -1 do bindings[i] = nil end
end

activeTween = setmetatable({}, { __mode = "k" })
function tween(obj, t, props, style, dir)
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

function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if type(v) == "string" and (COLOR_PROPS[k] or k == "BackgroundTransparency") then bind(o, k, v)
        else o[k] = v end
    end
    if parent then o.Parent = parent end
    return o
end
function round(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
function stroke(o, key, th, tr)
    return new("UIStroke", { Color = key or "Border", Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
function text(parent, t, size, key, bold, extra)
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
    webhook = { { "o", 3, 5, 11, 9, 3 }, { "o", 10, 10, 11, 9, 3 }, { "l", 11, 9, 14, 12 }, { "l", 14, 12, 17, 15 }, { "d", 5, 9, 1.2 }, { "d", 19, 15, 1.2 } },
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

Icons = {}
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
function CreateIcon(name, size, parent, props)
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
function SetIconColor(ic, color)
    if not ic or not ic.root.Parent then return end
    ic.override = color
    paintIcon(ic, true)
end
function SetIconState(ic, state)
    if not ic or not ic.root.Parent or ic.state == state then return end
    ic.state = state
    ic.override = nil
    paintIcon(ic, true)
end
function DestroyIcon(ic)
    if not ic then return end
    local i = table.find(Icons, ic)
    if i then table.remove(Icons, i) end
    if ic.root then ic.root:Destroy() end
end
function refreshIcons(animate)
    local j = 0
    for i = 1, #Icons do
        local ic = Icons[i]
        if ic.root.Parent then j += 1 Icons[j] = ic paintIcon(ic, animate) end
    end
    for i = #Icons, j + 1, -1 do Icons[i] = nil end
end
function iconHover(btn, ic, isActive)
    if IS_TOUCH then return end
    btn.MouseEnter:Connect(function() if not isActive or not isActive() then SetIconState(ic, "hover") end end)
    btn.MouseLeave:Connect(function() SetIconState(ic, (isActive and isActive()) and "active" or "normal") end)
end

Tabs, TabByName, Feat, FeatList = {}, {}, {}, {}

function addTab(name, icon)
    local t = { name = name, icon = icon, items = {} }
    Tabs[#Tabs + 1] = t
    TabByName[name] = t
    return t
end

function def(tabName, id, f)
    assert(not Feat[id], "duplicate feature id " .. id)
    f.id, f.tab, f.views = id, tabName, {}
    Feat[id] = f
    FeatList[#FeatList + 1] = f
    table.insert(TabByName[tabName].items, f)
    if f.kind == "toggle" then S[id] = false
    elseif f.kind == "slider" or f.kind == "dropdown" then S[id] = f.default
    elseif f.kind == "color" then S[id] = ""
    elseif f.kind == "input" then
        if not f.private then S[id] = f.default or "" end
    end
    return f
end

local NEEDS = "Needs this game's own remotes/objects. They are not verified, so nothing is faked."
function na(tabName, id, name, desc, reason, badge)
    def(tabName, id, { kind = "toggle", name = name, desc = desc, unavailable = reason or NEEDS, badge = badge or "NEEDS INTEGRATION" })
end

end -- scope block
local function refreshViews(f)
    for _, u in pairs(f.views) do pcall(u) end
end

local valid, setValue, V2, THEME_IDS, encodeConfig, applyConfig, importJSON, readStoredConfig, saveConfig, loadConfig, resetConfig, gui, WIN_W, WIN_H, TITLE_H, SB_OPEN, SB_MIN, ROW_H, TAB_H, state, uiRefs, baseScale, notifScale, liveNotifs
do -- scope block (keeps main chunk under the 200-local limit)
function valid(f, v)
    if f.kind == "slider" then return type(v) == "number" end
    if f.kind == "dropdown" then return type(v) == "string" and table.find(f.options, v) ~= nil end
    if f.kind == "color" then return type(v) == "string" and (v == "" or hexColor(v) ~= nil) end
    if f.kind == "toggle" then return type(v) == "boolean" end
    if f.kind == "input" then return type(v) == "string" and #v <= 300 and (v == "" or not f.validate or f.validate(v) == true) end
    return false
end

function setValue(id, v, silent)
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
    elseif f.kind == "input" then
        if f.private or f.unavailable or not valid(f, v) then return false end
        if S[id] == v then refreshViews(f) return true end
        S[id] = v
        if f.fn then pcall(f.fn, v) end
    end
    refreshViews(f)
    markDirty()
    return true
end

V2 = { on = {} } -- all V2 helpers live here (keeps the top-level local count flat)
local memoryConfig
local dirty = false
THEME_IDS = { "theme_preset", "theme_accent", "theme_bg", "theme_panel", "theme_border", "theme_text", "theme_sub", "theme_tr", "anim_level", "ui_scale" }

function encodeConfig()
    local out = { v = 2, tab = S._tab, state = {}, pos = { wx = POS.win.x, wy = POS.win.y, fx = POS.float.x, fy = POS.float.y } }
    for _, f in ipairs(FeatList) do
        if f.kind == "toggle" or f.kind == "slider" or f.kind == "dropdown" or f.kind == "color" or (f.kind == "input" and not f.private) then out.state[f.id] = S[f.id] end
    end
    return HttpService:JSONEncode(out)
end

function applyConfig(data)
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

function importJSON(str)
    if type(str) ~= "string" or str:match("^%s*$") then return false, "Config is empty" end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, str)
    if not ok then return false, "Invalid JSON" end
    return applyConfig(data)
end

function readStoredConfig()
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

function saveConfig(silent)
    local json = encodeConfig()
    memoryConfig = json
    if HAS_FILES then
        local ok = pcall(writefile, CONFIG_FILE, json)
        if not silent then notify(ok and "Configuration saved to file" or "File write failed (kept in session)", ok and "good" or "warn")
        elseif not ok and os.clock() - (V2.lastSaveWarn or -100) > 60 then
            V2.lastSaveWarn = os.clock()
            notify("Auto-save failed: file write error (settings kept for this session)", "warn", 4)
        end
    elseif not silent then
        notify("No file access: saved for this session only", "warn")
    end
end

function loadConfig(silent)
    local json = readStoredConfig()
    if not json then
        if not silent then notify("No saved configuration found", "warn") end
        return
    end
    local ok, msg = importJSON(json)
    if not silent then notify(ok and ("Loaded. " .. msg) or msg, ok and "good" or "bad") end
end

function resetConfig()
    for _, f in ipairs(FeatList) do
        if f.kind == "toggle" then setValue(f.id, V2.on[f.id] == true, true)
        elseif f.kind == "slider" or f.kind == "dropdown" then setValue(f.id, f.default, true)
        elseif f.kind == "color" then setValue(f.id, "", true)
        elseif f.kind == "input" and not f.private then setValue(f.id, f.default or "", true) end
    end
    notify("Configuration reset to defaults", "good")
end

markDirty = function()
    if dirty or S.cfg_autosave == false then return end
    dirty = true
    task.delay(1.5, function()
        dirty = false
        if alive then pcall(saveConfig, true) end
    end)
end

gui = Root.add(new("ScreenGui", { Name = "CazielxArchx", ResetOnSpawn = false, DisplayOrder = 100,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true }, PlayerGui))

WIN_W, WIN_H, TITLE_H = 700, 440, 44
SB_OPEN, SB_MIN = 158, 52
ROW_H = IS_TOUCH and 52 or 46
TAB_H = IS_TOUCH and 44 or 38
state = { open = false, min = false, max = false, sb = not IS_TOUCH, unloadArmed = false }
uiRefs = {}

function baseScale()
    local vp = gui.AbsoluteSize
    if vp.X < 10 or vp.Y < 10 then return 1 end
    local fit = math.max(math.min((vp.X - 12) / WIN_W, (vp.Y - 12) / WIN_H), .4)
    local s = math.min(fit, 1.15) * (S.ui_scale or 1)
    return math.min(s, fit)
end

local notifHolder = new("Frame", { Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(280, 400), ZIndex = 50 }, gui)
notifScale = new("UIScale", { Scale = 1 }, notifHolder)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, notifHolder)
liveNotifs = {}
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

end -- scope block
local tip, bindTooltip, beginDrag, isPress, rejoin, loop, getRemote, numAttr, getCash, humanoidOverride
do -- scope block (keeps main chunk under the 200-local limit)
tip = new("TextLabel", { Visible = false, AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = "Bg",
    TextColor3 = "Text", Font = FONT, TextSize = 12, TextWrapped = true, Text = "", ZIndex = 200,
    BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, gui)
round(tip, 6) stroke(tip, "Accent", 1, .4)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }, tip)
new("UISizeConstraint", { MaxSize = Vector2.new(260, 220) }, tip)

function bindTooltip(obj, msg)
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
function beginDrag(input, update, finish)
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
function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

addTab("Home", "home") addTab("Farm", "farm") addTab("Automation", "automation") addTab("Movement", "movement")
addTab("Visuals", "visuals") addTab("Player", "player") addTab("Statistics", "statistics") addTab("Server", "server")
addTab("Webhook", "webhook") addTab("Settings", "settings") addTab("Theme", "theme") addTab("Diagnostics", "diagnostics") addTab("About", "about")

function rejoin()
    if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, Player)
    else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, Player) end
end
Root.add(TeleportService.TeleportInitFailed:Connect(function(_, _, msg) notify("Teleport failed: " .. tostring(msg), "bad", 5) end))

-- (hoisted) local loop
do
    -- One shared scheduler (a single Heartbeat connection) replaces one thread per feature loop.
    -- Every task has an overlap guard, error isolation and stops itself after 8 consecutive errors.
    local tasks, conn = {}, nil
    V2.sched = { errors = 0, lastErr = "none", count = function() return #tasks end }
    local function tick()
        local now = os.clock()
        local j = 0
        for i = 1, #tasks do
            local h = tasks[i]
            if h.alive and alive then
                j += 1
                tasks[j] = h
                if not h.paused and not h.busy and now >= h.nextAt then
                    h.busy = true
                    task.spawn(function()
                        local ok, err = pcall(h.step, h)
                        h.busy = false
                        h.nextAt = os.clock() + h.interval
                        if ok then
                            h.fails = 0
                        else
                            h.fails += 1
                            V2.sched.errors += 1
                            V2.sched.lastErr = tostring(err)
                            warn("[CAZX] " .. tostring(err))
                            if h.fails >= 8 then
                                h.alive = false
                                if notify then pcall(notify, "A feature loop stopped after 8 consecutive errors. See Diagnostics.", "bad", 5) end
                            end
                        end
                    end)
                end
            end
        end
        for i = #tasks, j + 1, -1 do tasks[i] = nil end
    end
    loop = function(interval, step)
        local h = { alive = true, paused = false, busy = false, fails = 0, step = step, interval = interval, nextAt = 0 }
        tasks[#tasks + 1] = h
        if not conn then
            conn = RunService.Heartbeat:Connect(tick)
            Root.add(function()
                if conn then conn:Disconnect() conn = nil end
                table.clear(tasks)
            end)
        end
        return h
    end
end

function getRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    if r and r:IsA("RemoteEvent") then return r end
    return nil
end
local function fireRemote(name, ...)
    local r = getRemote(name)
    if not r then return false end
    return (pcall(r.FireServer, r, ...))
end
function numAttr(name)
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
function getCash()
    return numAttr("Cash") or findStat({ "Cash", "Coins", "Money", "Gold" })
end

function humanoidOverride(prop, valueFn, aux)
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
                if t:IsA("Tool") and t.Name ~= "Bat" and not t.Name:lower():find("axe", 1, true) then return true end
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
end -- scope block
local FarmInfo, farmErr, instPos, getBase, farmEvent, isAxeName, eggLabel
do -- scope block (keeps main chunk under the 200-local limit)
FarmInfo = { base = nil, baseWhy = "not scanned", eggs = 0, eggState = "TESTING", interact = "not checked", breakState = "OFF", errors = {}, broken = 0, animals = 0, t0 = os.clock(), status = "OFF", target = "none", lastAnimal = "none", catalog = "not scanned", carrying = false, paused = false, respawns = 0, vanished = 0 }
local farmFields -- assigned in the webhook section
V2.session = { earnings = 0, bestIdx = 0, bestName = "none", history = {}, pets = {}, petCounts = {}, petTotal = 0, lastCash = nil }
function farmErr(msg)
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
function instPos(inst)
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
function getBase(force)
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

-- ===== Auto Farm (your own base only; every step is reported honestly, nothing is faked) =====
local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "secret" }
local farmSkip = setmetatable({}, { __mode = "k" })
local lastFail = {}

function farmEvent(title, desc, kind, fields, evType)
    if not (S.wh_events and whEvent) then return end
    if evType and S["wh_ev_" .. evType] == false then return end
    pcall(whEvent, title, desc, kind, fields)
end
local function farmFail(msg)
    farmErr(msg)
    local now = os.clock()
    if lastFail[msg] and now - lastFail[msg] < 30 then return end
    lastFail[msg] = now
    notify("Auto Farm: " .. msg, "bad", 4)
    farmEvent("Farm error", msg, "bad", nil, "error")
end

function isAxeName(n)
    n = n:lower()
    return n:find("axe", 1, true) ~= nil and n:find("pickaxe", 1, true) == nil
end
local function findAxe()
    for _, c in ipairs({ Player.Character, Player:FindFirstChild("Backpack") }) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and isAxeName(t.Name) then return t end
            end
        end
    end
    return nil
end
local function heldKey()
    local names = {}
    for _, c in ipairs({ Player:FindFirstChild("Backpack"), Player.Character }) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t.Name ~= "Bat" and not t.Name:lower():find("axe", 1, true) then names[#names + 1] = t.Name end
            end
        end
    end
    table.sort(names)
    return table.concat(names, "|")
end

function eggLabel(egg)
    local holder = egg.Parent
    for _, k in ipairs({ "EggName", "EggType", "Type", "Name" }) do
        local v = egg:GetAttribute(k)
        if v == nil and holder then v = holder:GetAttribute(k) end
        if type(v) == "string" and v ~= "" then return v end
    end
    return holder and holder.Name or "Egg"
end
function V2.rarityIndex(v)
    if type(v) == "number" then
        local n = math.floor(v)
        if n >= 1 then return math.min(n, 99) end
        return 0
    end
    if type(v) == "string" then
        local str = v:lower()
        local i = table.find(RARITY_ORDER, str)
        if i then return i end
        for k = #RARITY_ORDER, 1, -1 do
            if str:find("%f[%a]" .. RARITY_ORDER[k] .. "%f[%A]") then return k end
        end
    end
    return 0
end
-- Rarity is only reported when the game exposes it: attribute, ValueBase named Rarity, or a rarity word in the name.
function V2.rarityInfo(inst, nameHint)
    if inst then
        for _, o in ipairs({ inst, inst.Parent }) do
            if o then
                for _, key in ipairs({ "Rarity", "RarityName", "Tier" }) do
                    local ok, a = pcall(o.GetAttribute, o, key)
                    local i = ok and V2.rarityIndex(a) or 0
                    if i > 0 then return i, RARITY_ORDER[i] or ("tier " .. i), "attribute " .. key end
                end
                local rv = o:FindFirstChild("Rarity")
                if rv and rv:IsA("ValueBase") then
                    local ok, a = pcall(function() return rv.Value end)
                    local i = ok and V2.rarityIndex(a) or 0
                    if i > 0 then return i, RARITY_ORDER[i] or ("tier " .. i), "value Rarity" end
                end
            end
        end
    end
    local i = V2.rarityIndex(nameHint or (inst and inst.Name))
    if i > 0 then return i, RARITY_ORDER[i] or ("tier " .. i), "name" end
    return 0, "unknown", "none"
end
function V2.rareMin()
    return table.find(RARITY_ORDER, tostring(S.pet_rare_min or "legendary")) or #RARITY_ORDER
end

-- Egg respawn / vanish detection: compares each scan with the eggs seen before (weak table, no leaks).
V2.knownEggs = setmetatable({}, { __mode = "k" })
function V2.trackEggs(eggs)
    local known, first = V2.knownEggs, not FarmInfo.eggSnap
    local present = {}
    for _, e in ipairs(eggs) do
        present[e] = true
        if not known[e] then
            known[e] = true
            if not first then FarmInfo.respawns += 1 end
        end
    end
    for e in pairs(known) do
        if not present[e] then
            known[e] = nil
            FarmInfo.vanished += 1
        end
    end
    FarmInfo.eggSnap = true
end

function V2.parseList(str)
    local out = {}
    for tok in tostring(str or ""):gmatch("[^,]+") do
        local t = tok:match("^%s*(.-)%s*$"):lower()
        if t ~= "" then out[#out + 1] = t end
    end
    return out
end
function V2.labelHas(label, list)
    for _, tok in ipairs(list) do
        if label:find(tok, 1, true) then return true end
    end
    return false
end

local function pickTarget(eggs, hrp)
    local filter, ignore = V2.parseList(S.farm_filter), V2.parseList(S.farm_ignore)
    local mode = S.farm_priority or "Nearest"
    local limit = S.farm_maxdist or 2000
    local maxDist = limit < 2000 and limit or math.huge
    local minRar = table.find(RARITY_ORDER, tostring(S.farm_minrar or ""):lower()) or 0
    local now = os.clock()
    local best, bestKey
    for _, e in ipairs(eggs) do
        local skipUntil = farmSkip[e]
        if e.Parent and not (skipUntil and skipUntil > now) then
            local name = eggLabel(e)
            local label = name:lower()
            local idx, rname = V2.rarityInfo(e, name)
            local match = #filter == 0 or V2.labelHas(label, filter)
            local ignored = V2.labelHas(label, ignore) or (rname ~= "unknown" and V2.labelHas(rname:lower(), ignore))
            local d = (e.Position - hrp.Position).Magnitude
            if not ignored and d <= maxDist and idx >= minRar and not (mode == "Selected only" and not match) then
                local key = d
                if mode == "Selected first" then key = (match and 0 or 1e6) + d
                elseif mode == "Highest rarity" then key = -idx * 1e6 + d end
                if not bestKey or key < bestKey then best, bestKey = e, key end
            end
        end
    end
    return best
end

-- Read-only egg scan shared by the Egg Scanner button, Auto Egg Scanner and Scan Farm Status.
function V2.scanEggs(report)
    local base = getBase(false)
    if not base then
        FarmInfo.eggState = "no base"
        if report then notify("Base not detected: " .. tostring(FarmInfo.baseWhy), "warn", 5) end
        return nil, "Base not detected: " .. tostring(FarmInfo.baseWhy)
    end
    local eggs, why = findEggs(base)
    if why then
        FarmInfo.eggState = "ERROR: " .. why
        return nil, why
    end
    FarmInfo.eggs = #eggs
    V2.trackEggs(eggs)
    if #eggs == 0 then
        FarmInfo.catalog, FarmInfo.eggState = "no eggs in base", "NO EGGS IN BASE"
        if report then notify("Egg Scanner: no eggs in your base", "warn", 4) end
        return eggs
    end
    local counts, order = {}, {}
    for _, e in ipairs(eggs) do
        local l = eggLabel(e)
        local _, rl = V2.rarityInfo(e, l)
        if rl ~= "unknown" then l = l .. " [" .. rl .. "]" end
        if not counts[l] then counts[l] = 0 order[#order + 1] = l end
        counts[l] += 1
    end
    local parts = {}
    for _, l in ipairs(order) do parts[#parts + 1] = l .. " x" .. counts[l] end
    FarmInfo.catalog = table.concat(parts, ", ")
    FarmInfo.eggState = #eggs .. " egg(s) detected"
    if report then notify("Eggs: " .. FarmInfo.catalog, "info", 6) end
    return eggs
end

-- Pet Scanner: animal Tools (any Tool that is not the axe/Bat) in Backpack + hands, best rarity first.
function V2.scanPets()
    local list = {}
    for _, c in ipairs({ Player:FindFirstChild("Backpack"), Player.Character }) do
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t.Name ~= "Bat" and not t.Name:lower():find("axe", 1, true) then
                    local idx, rl = V2.rarityInfo(t, t.Name)
                    list[#list + 1] = { tool = t, name = t.Name, idx = idx, rarity = rl, held = c == Player.Character }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.idx ~= b.idx then return a.idx > b.idx end
        return a.name < b.name
    end)
    return list
end

local function watchAnimals(bag)
    local seen = setmetatable({}, { __mode = "k" })
    local ignoreUntil = 0
    local function onTool(t)
        if not t:IsA("Tool") or seen[t] then return end
        seen[t] = true
        if os.clock() < ignoreUntil then return end
        if t.Name == "Bat" or t.Name:lower():find("axe", 1, true) then return end
        local idx, rl = V2.rarityInfo(t, t.Name)
        local ses = V2.session
        FarmInfo.animals += 1
        FarmInfo.lastAnimal = t.Name .. (idx > 0 and (" [" .. rl .. "]") or "")
        ses.pets[#ses.pets + 1] = { at = os.date("%H:%M:%S"), name = t.Name, rarity = rl, idx = idx }
        while #ses.pets > 100 do table.remove(ses.pets, 1) end
        ses.petCounts[t.Name] = (ses.petCounts[t.Name] or 0) + 1
        ses.petTotal += 1
        if idx > ses.bestIdx or ses.bestName == "none" then
            ses.bestIdx, ses.bestName = idx, t.Name .. (idx > 0 and (" (" .. rl .. ")") or "")
        end
        local isRare = idx > 0 and idx >= V2.rareMin()
        local fields = {
            { name = "Pet", value = t.Name, inline = true },
            { name = "Rarity", value = idx > 0 and rl or "not exposed by the game", inline = true },
        }
        if S.pet_alert then notify("New pet: " .. t.Name .. (idx > 0 and (" [" .. rl .. "]") or ""), isRare and "good" or "info", 3) end
        farmEvent("Animal collected", ("**%s** appeared in your inventory"):format(t.Name), "good", fields, "pet")
        if isRare then farmEvent("Rare pet obtained", ("**%s** (%s)"):format(t.Name, rl), "warn", fields, "rare") end
    end
    local function hook(container, cb)
        if not container then return end
        for _, t in ipairs(container:GetChildren()) do seen[t] = true end
        cb.add(container.ChildAdded:Connect(onTool))
    end
    local bpBag = newBag()
    bag.add(bpBag.clear)
    local function hookBackpack()
        bpBag.clear()
        ignoreUntil = os.clock() + 1.5
        hook(Player:FindFirstChild("Backpack"), bpBag)
    end
    hookBackpack()
    bag.add(Player.ChildAdded:Connect(function(c) if c.Name == "Backpack" then hookBackpack() end end))
    hookCharacter(bag, function(char, cb)
        ignoreUntil = os.clock() + 1.5
        hook(char, cb)
    end)
end

-- Shared pet tracker: Auto Farm and New Pet Alerts both use it; the watcher exists only while somebody needs it.
V2.petRefs = 0
function V2.petTrackStart()
    V2.petRefs += 1
    if V2.petRefs == 1 then
        V2.petBag = newBag()
        watchAnimals(V2.petBag)
    end
    local released = false
    return function()
        if released then return end
        released = true
        V2.petRefs -= 1
        if V2.petRefs <= 0 then
            V2.petRefs = 0
            if V2.petBag then V2.petBag.clear() V2.petBag = nil end
        end
    end
end
Root.add(function() if V2.petBag then V2.petBag.clear() V2.petBag = nil end end)

local function stopWalk()
    local h = getHum()
    local r = h and h.RootPart
    if h and r then h:MoveTo(r.Position) end
end

local farmLoop, farmBag
def("Farm", "farm_auto", { kind = "toggle", name = "Auto Farm [TESTING]", desc = "Walks to eggs in YOUR base, equips the axe and hits them. Skips unreachable eggs and keeps running after respawn.", fn = function(on)
    if farmLoop then farmLoop.alive = false farmLoop = nil end
    if farmBag then farmBag.clear() farmBag = nil end
    FarmInfo.carrying = false
    if not on then
        FarmInfo.status, FarmInfo.target = "OFF", "none"
        pcall(stopWalk)
        if FarmInfo.broken > 0 or FarmInfo.animals > 0 then farmEvent("Farm session ended", "Auto Farm was turned off", "info", farmFields(), "session") end
        return
    end
    if S.farm_break then FarmInfo.status = "OFF" return false, "Turn Auto Break off first: both would hit the same eggs" end
    if not getHum() then FarmInfo.status = "ERROR: no character" return false, "Character is not ready (respawning?)" end
    if not getBase(true) then FarmInfo.status = "ERROR: base not detected" return false, "Base not detected: " .. tostring(FarmInfo.baseWhy) end
    if not findAxe() then FarmInfo.status = "ERROR: no axe" return false, "No axe Tool found in your Backpack or Character" end
    FarmInfo.broken, FarmInfo.animals, FarmInfo.t0, FarmInfo.status = 0, 0, os.clock(), "STARTING"
    farmBag = newBag()
    farmBag.add(V2.petTrackStart())
    local st = { cache = nil, cacheAt = 0, hits = 0, fails = 0, label = "Egg" }
    farmLoop = loop(.15, function()
        local char = Player.Character
        local hum = getHum()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not hrp then
            FarmInfo.status, FarmInfo.target, st.target = "RESPAWNING", "none", nil
            return
        end
        if FarmInfo.paused then
            if FarmInfo.status ~= "PAUSED" then pcall(stopWalk) end
            FarmInfo.status = "PAUSED"
            return
        end
        if FarmInfo.carrying then FarmInfo.status = "CARRYING TO BASE" return end
        local now = os.clock()
        local b = getBase(false)
        if not b then
            b = getBase(true)
            if not b then FarmInfo.status = "NO BASE (retrying)" return end
        end
        if not st.cache or now - st.cacheAt > 1.5 then
            local eggs, why = findEggs(b)
            if why then FarmInfo.status = "ERROR: " .. why farmFail(why) return end
            st.cache, st.cacheAt = eggs, now
            FarmInfo.eggs = #eggs
            V2.trackEggs(eggs)
        end
        if st.target then
            local gone = not st.target.Parent
            if gone or (farmSkip[st.target] and farmSkip[st.target] > now) then
                if gone and st.hits > 0 then
                    FarmInfo.broken += 1
                    local hist = V2.session.history
                    hist[#hist + 1] = { at = os.date("%H:%M:%S"), label = st.label, hits = st.hits, rarity = st.rname or "unknown" }
                    while #hist > 60 do table.remove(hist, 1) end
                    farmEvent("Egg broken", ("**%s** left your base after %d hit(s)"):format(st.label, st.hits), "good",
                        { { name = "Egg", value = tostring(st.label), inline = true }, { name = "Rarity", value = tostring(st.rname or "unknown"), inline = true } }, "egg")
                end
                st.target = nil
            end
        end
        if not st.target then
            local e = pickTarget(st.cache, hrp)
            if not e then FarmInfo.status, FarmInfo.target = "WAITING (no valid egg)", "none" return end
            st.target, st.label, st.hits, st.fails, st.since = e, eggLabel(e), 0, 0, now
            st.lastDist, st.progressAt, st.lastHit = nil, now, 0
            st.kind, st.obj = eggInteraction(e)
            st.ridx, st.rname = V2.rarityInfo(e, st.label)
        end
        FarmInfo.target = st.label
        local e = st.target
        local dist = (e.Position - hrp.Position).Magnitude
        if not st.lastDist or dist < st.lastDist - .5 then st.lastDist, st.progressAt = dist, now end
        local kind, obj = st.kind, st.obj
        local reach = 9
        if kind == "prompt" and obj and obj.Parent then reach = math.max((obj.MaxActivationDistance or 10) - 2, 4) end
        if dist > reach then
            FarmInfo.status = ("WALKING TO %s (%d studs)"):format(st.label, math.floor(dist))
            hum:MoveTo(e.Position)
            if now - st.progressAt > 5 then
                farmSkip[e] = now + 20
                farmFail("could not reach " .. st.label .. ", skipping it for 20s")
                st.target = nil
            end
            return
        end
        if now - st.since > 90 then
            farmSkip[e] = now + 30
            farmFail(st.label .. " did not break within 90s (" .. st.hits .. " hits), skipping it")
            st.target = nil
            return
        end
        if now - st.lastHit < (S.farm_delay or .25) then return end
        st.lastHit = now
        local axe = findAxe()
        if not axe then FarmInfo.status = "ERROR: axe missing" farmFail("axe Tool not found in Backpack/Character") return end
        if axe.Parent ~= char then
            hum:EquipTool(axe)
            FarmInfo.status = "EQUIPPING AXE"
            return
        end
        FarmInfo.status = "BREAKING " .. st.label
        local ok, err
        if kind == "prompt" and obj and typeof(fireproximityprompt) == "function" then ok, err = pcall(fireproximityprompt, obj)
        elseif kind == "click" and obj and typeof(fireclickdetector) == "function" then ok, err = pcall(fireclickdetector, obj)
        else ok, err = pcall(function() axe:Activate() end) end
        if ok then
            st.hits += 1
            st.fails = 0
        else
            st.fails += 1
            farmErr(err)
            if st.fails >= 5 then
                farmSkip[e] = now + 30
                farmFail("hit action failed 5 times: " .. tostring(err))
                st.target = nil
            end
        end
    end)
end })

local carryLoop
def("Farm", "farm_carry", { kind = "toggle", name = "Auto Carry [TESTING]", desc = "Walks to your base while you hold an animal Tool (any Tool except the axe), then lets Auto Farm continue.", fn = function(on)
    if carryLoop then carryLoop.alive = false carryLoop = nil end
    FarmInfo.carrying = false
    if not on then pcall(stopWalk) return end
    if not getBase(true) then return false, "Base not detected: " .. tostring(FarmInfo.baseWhy) end
    local delivered
    carryLoop = loop(.4, function()
        local char = Player.Character
        local hum = getHum()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or hum.Health <= 0 or not hrp then FarmInfo.carrying = false return end
        if FarmInfo.paused then return end
        local key = heldKey()
        if key == "" then FarmInfo.carrying, delivered = false, nil return end
        local b = getBase(false)
        local p = b and instPos(b)
        if not p or key == delivered then FarmInfo.carrying = false return end
        if (p - hrp.Position).Magnitude > 20 then
            FarmInfo.carrying = true
            hum:MoveTo(p)
        else
            FarmInfo.carrying, delivered = false, key
        end
    end)
end })

def("Farm", "farm_eggscan", { kind = "button", name = "Egg Scanner", desc = "Lists the egg types in your base with rarity (rarity only when the game exposes it).", run = function()
    local eggs, why = V2.scanEggs(true)
    if not eggs then return false, why end
end })
def("Farm", "farm_filter", { kind = "input", name = "Egg Selector", desc = "Comma-separated names to target (matches the egg type text). Empty means any egg.", placeholder = "e.g. golden, dragon", default = "",
    validate = function(v) return #v <= 120 end })
def("Farm", "farm_priority", { kind = "dropdown", name = "Best Egg Priority", desc = "Nearest | Selected first | Selected only | Highest rarity (uses a Rarity attribute if the egg exposes one, else distance).",
    options = { "Nearest", "Selected first", "Selected only", "Highest rarity" }, default = "Nearest" })
def("Farm", "farm_delay", { kind = "slider", name = "Hit Interval (s)", desc = "Delay between hit attempts. The server decides how fast an egg really breaks.", min = .1, max = 1, step = .05, default = .25 })
def("Farm", "farm_stop", { kind = "button", name = "Stop Farm", desc = "Turns off Auto Farm, Auto Break, Auto Carry and Place Best Pets.", run = function()
    for _, id in ipairs({ "farm_auto", "farm_break", "farm_carry", "auto_best", "farm_pause" }) do
        if S[id] then setValue(id, false) end
    end
end })

-- ===== V2: egg filters, pause/resume, pet tools and session statistics =====
do
    local scanH
    def("Farm", "farm_autoscan", { kind = "toggle", name = "Auto Egg Scanner", desc = "Re-scans your base every 2s: egg count, types with rarity, respawned and vanished eggs (read-only).", fn = function(on)
        if scanH then scanH.alive = false scanH = nil end
        if not on then return end
        scanH = loop(2, function()
            if FarmInfo.scanBackoff and os.clock() < FarmInfo.scanBackoff then return end
            local eggs = V2.scanEggs(false)
            FarmInfo.scanBackoff = (not eggs) and (os.clock() + 8) or nil
        end)
    end })
end
def("Farm", "farm_maxdist", { kind = "slider", name = "Egg Distance Limit", desc = "Ignore eggs farther than this many studs. The maximum means no limit.", min = 50, max = 2000, step = 50, default = 2000 })
def("Farm", "farm_minrar", { kind = "dropdown", name = "Egg Rarity Filter", desc = "Only target eggs at or above this rarity. Works only if the egg exposes a Rarity attribute/value or a rarity word in its name; otherwise those eggs are skipped while a filter is set.",
    options = { "Any", table.unpack(RARITY_ORDER) }, default = "Any" })
def("Farm", "farm_ignore", { kind = "input", name = "Ignore Eggs", desc = "Comma-separated names or rarities that are never targeted.", placeholder = "e.g. common, basic", default = "",
    validate = function(v) return #v <= 120 end })
def("Farm", "farm_selectall", { kind = "button", name = "Select All Eggs", desc = "Clears selector, ignore list, rarity filter and distance limit so every egg is a valid target.", run = function()
    setValue("farm_filter", "", true) setValue("farm_ignore", "", true) setValue("farm_minrar", "Any", true)
    setValue("farm_maxdist", 2000, true) setValue("farm_priority", "Nearest", true)
    notify("All eggs selected (filters cleared)", "good", 2.5)
end })
def("Farm", "farm_pause", { kind = "toggle", name = "Pause Farm", desc = "Pauses Auto Farm and Auto Carry without losing statistics. Turn it off to resume.", fn = function(on)
    FarmInfo.paused = on
    if on then pcall(stopWalk) end
end })
def("Farm", "farm_history", { kind = "button", name = "Egg Collection History", desc = "Shows the last eggs you broke this session.", run = function()
    local h = V2.session.history
    if #h == 0 then return false, "No eggs broken yet this session" end
    local parts = {}
    for i = #h, math.max(1, #h - 4), -1 do parts[#parts + 1] = ("%s %s x%d"):format(h[i].at, h[i].label, h[i].hits) end
    notify(#h .. " egg(s): " .. table.concat(parts, " | "), "info", 8)
end })
def("Farm", "pet_scan", { kind = "button", name = "Pet Scanner", desc = "Lists animal Tools in your Backpack/hands (any Tool except the axe) with rarity when the game exposes it.", run = function()
    local pets = V2.scanPets()
    if #pets == 0 then return false, "No animal Tools in your Backpack or hands" end
    local parts = {}
    for i = 1, math.min(#pets, 8) do
        local p = pets[i]
        parts[#parts + 1] = p.name .. (p.idx > 0 and (" [" .. p.rarity .. "]") or "") .. (p.held and " (held)" or "")
    end
    notify(#pets .. " pet(s): " .. table.concat(parts, ", ") .. (#pets > 8 and ", ..." or ""), "info", 7)
end })
def("Farm", "pet_best", { kind = "button", name = "Best Pet Detection", desc = "Finds the highest-rarity animal Tool you carry.", run = function()
    local pets = V2.scanPets()
    if #pets == 0 then return false, "No animal Tools in your Backpack or hands" end
    local b = pets[1]
    if b.idx > 0 then notify(("Best pet: %s [%s]"):format(b.name, b.rarity), "good", 5)
    else notify("No rarity info exposed by the game. First animal: " .. b.name, "warn", 5) end
end })
def("Farm", "pet_inv", { kind = "button", name = "Pet Inventory Tracker", desc = "Animal Tools you hold now, plus how many you obtained this session.", run = function()
    local pets = V2.scanPets()
    local counts, order = {}, {}
    for _, p in ipairs(pets) do
        if not counts[p.name] then counts[p.name] = 0 order[#order + 1] = p.name end
        counts[p.name] += 1
    end
    local parts = {}
    for _, n in ipairs(order) do parts[#parts + 1] = n .. " x" .. counts[n] end
    notify(("Holding: %s | Obtained this session: %d"):format(#pets > 0 and table.concat(parts, ", ") or "none", V2.session.petTotal), "info", 7)
end })
def("Farm", "pet_history", { kind = "button", name = "Pet Collection History", desc = "Shows the last pets that entered your Backpack while a pet watcher was running.", run = function()
    local h = V2.session.pets
    if #h == 0 then return false, "No pets recorded yet (turn on Auto Farm or New Pet Alerts first)" end
    local parts = {}
    for i = #h, math.max(1, #h - 4), -1 do parts[#parts + 1] = h[i].at .. " " .. h[i].name .. (h[i].idx > 0 and (" [" .. h[i].rarity .. "]") or "") end
    notify(#h .. " pet(s): " .. table.concat(parts, " | "), "info", 8)
end })
def("Farm", "pet_rare_min", { kind = "dropdown", name = "Pet Rarity Filter (Rare Alerts)", desc = "Pets at or above this rarity count as rare: highlighted alert and Rare Pet webhook.", options = RARITY_ORDER, default = "legendary" })
def("Farm", "session_reset", { kind = "button", name = "Reset Session Stats", desc = "Clears farm counters, earnings, best pet and the history lists.", run = function()
    V2.session = { earnings = 0, bestIdx = 0, bestName = "none", history = {}, pets = {}, petCounts = {}, petTotal = 0, lastCash = getCash() }
    FarmInfo.broken, FarmInfo.animals, FarmInfo.respawns, FarmInfo.vanished = 0, 0, 0, 0
    FarmInfo.lastAnimal, FarmInfo.t0 = "none", os.clock()
    notify("Session statistics reset", "good", 2)
end })

-- ===== Discord webhook (client side). The URL lives in its own file and is never part of the exported config. =====
end -- scope block
local WH, whValidate, whPost, whEmbed, whLoad
do -- scope block (keeps main chunk under the 200-local limit)
local WEBHOOK_FILE = "CAZIELX_ARCHX_webhook.json"
WH = { url = "", state = "NOT CONFIGURED", kind = "Warn", detail = "no URL set", sent = 0, failed = 0, lastAt = 0, queue = {}, pumping = false }

function whValidate(u)
    if type(u) ~= "string" then return false, "URL is empty" end
    u = u:match("^%s*(.-)%s*$")
    if u == "" then return false, "URL is empty" end
    local host, id = u:match("^https://([%w%.]+)/api/webhooks/(%d+)/[%w%-_]+$")
    if not host then host, id = u:match("^https://([%w%.]+)/api/v%d+/webhooks/(%d+)/[%w%-_]+$") end
    if not host then return false, "Not a Discord webhook URL (expected https://discord.com/api/webhooks/ID/TOKEN)" end
    if host ~= "discord.com" and host ~= "discordapp.com" and host ~= "ptb.discord.com" and host ~= "canary.discord.com" then
        return false, "Host must be discord.com"
    end
    return true, u
end
local function whMask(u)
    if type(u) ~= "string" or u == "" then return "" end
    local id = u:match("/webhooks/(%d+)/")
    return id and ("discord.com/api/webhooks/" .. id .. "/************") or "************"
end
local function whSetState(s, kind, detail)
    WH.state, WH.kind = s, kind or "Warn"
    if detail then WH.detail = detail end
end

-- blocking POST; returns ok, reason, rateLimited
function whPost(payload)
    if not HTTP_REQUEST then return false, "No HTTP request function in this environment" end
    local ok, url = whValidate(WH.url)
    if not ok then return false, url end
    local okE, body = pcall(HttpService.JSONEncode, HttpService, payload)
    if not okE then return false, "Payload encode failed" end
    local okR, res = pcall(HTTP_REQUEST, { Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
    if not okR then return false, "Request error: " .. tostring(res) end
    if type(res) ~= "table" then return false, "No response from the request function" end
    local code = res.StatusCode or res.status_code
    if type(code) == "number" and code >= 200 and code < 300 then return true, "HTTP " .. code end
    if code == 429 then return false, "Rate limited by Discord (HTTP 429)", true end
    if code == 401 or code == 404 then return false, ("Webhook rejected (HTTP %d): invalid or deleted webhook"):format(code) end
    return false, "HTTP " .. tostring(code or "?") .. (res.StatusMessage and (" " .. tostring(res.StatusMessage)) or "")
end

local EMBED_COLOR = { info = 0x40C4FF, good = 0x28D68E, warn = 0xFFB84D, bad = 0xEE4254 }
function whEmbed(title, desc, kind, fields)
    return { username = "CAZIELX ARCHX", embeds = { {
        author = { name = Player.DisplayName .. " (@" .. Player.Name .. ")" },
        title = title, description = desc, color = EMBED_COLOR[kind or "info"], fields = fields,
        footer = { text = APP_NAME .. " " .. EDITION .. "  |  v" .. VERSION },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    } } }
end

local function whPump()
    if WH.pumping then return end
    WH.pumping = true
    task.spawn(function()
        while alive and #WH.queue > 0 do
            local wait = 2 - (os.clock() - WH.lastAt)
            if wait > 0 then task.wait(wait) end
            local item = table.remove(WH.queue, 1)
            WH.lastAt = os.clock()
            local ok, why, limited = whPost(item)
            if ok then
                WH.sent += 1
                whSetState("CONNECTED", "Good", why .. " @ " .. os.date("%H:%M:%S"))
            else
                WH.failed += 1
                whSetState(limited and "RATE LIMITED" or "ERROR", "Bad", tostring(why))
                if limited then task.wait(5) end
            end
        end
        WH.pumping = false
    end)
end

whEvent = function(title, desc, kind, fields)
    if not S.wh_enable or WH.url == "" then return false end
    while #WH.queue >= 10 do table.remove(WH.queue, 1) end
    WH.queue[#WH.queue + 1] = whEmbed(title, desc, kind, fields)
    whPump()
    return true
end

local function whSave()
    local ok, u = whValidate(WH.url)
    if not ok then return false, u end
    if not HAS_FILES then return false, "No file API in this environment: the URL is kept for this session only and is NOT saved" end
    local okE, json = pcall(HttpService.JSONEncode, HttpService, { v = 1, url = u })
    if not okE then return false, "Encode failed" end
    local okW, err = pcall(writefile, WEBHOOK_FILE, json)
    if not okW then return false, "File write failed: " .. tostring(err) end
    return true
end
function whLoad()
    if not HAS_FILES then return false, "No file API in this environment" end
    local okX, exists = pcall(isfile, WEBHOOK_FILE)
    if not okX or not exists then return false, "No saved webhook found" end
    local okR, c = pcall(readfile, WEBHOOK_FILE)
    if not okR then return false, "File read failed" end
    local okD, d = pcall(HttpService.JSONDecode, HttpService, c)
    if not okD or type(d) ~= "table" then return false, "Saved webhook file is corrupt" end
    local ok, u = whValidate(d.url)
    if not ok then return false, "Saved URL is invalid: " .. tostring(u) end
    WH.url = u
    whSetState("LOADED", "Warn", "not tested yet")
    return true
end

local function fmtDur(sec)
    sec = math.floor(sec)
    return ("%dh %02dm %02ds"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end
local function shortNum(n)
    if type(n) ~= "number" then return "N/A" end
    local a = math.abs(n)
    for _, u in ipairs({ { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        if a >= u[1] then return ("%.2f%s"):format(n / u[1], u[2]) end
    end
    return tostring(math.floor(n * 100 + .5) / 100)
end
farmFields = function()
    local up = os.clock() - FarmInfo.t0
    local rate = FarmInfo.broken / math.max(up / 3600, 1 / 3600)
    local earn = V2.session.earnings
    return {
        { name = "Eggs processed", value = tostring(FarmInfo.broken), inline = true },
        { name = "Pets obtained", value = tostring(FarmInfo.animals), inline = true },
        { name = "Eggs / hour", value = ("%.1f"):format(rate), inline = true },
        { name = "Best pet", value = tostring(V2.session.bestName), inline = true },
        { name = "Cash gained", value = shortNum(earn), inline = true },
        { name = "Avg / egg", value = FarmInfo.broken > 0 and shortNum(earn / FarmInfo.broken) or "N/A", inline = true },
        { name = "Farm status", value = tostring(FarmInfo.status), inline = true },
        { name = "Uptime", value = fmtDur(up), inline = true },
        { name = "Last error", value = tostring(FarmInfo.errors[#FarmInfo.errors] or "none"), inline = false },
    }
end

def("Webhook", "wh_url", { kind = "input", private = true, name = "Webhook URL", desc = "Discord webhook. Kept in its own file, never in exported configs.",
    placeholder = "https://discord.com/api/webhooks/ID/TOKEN", mask = whMask, get = function() return WH.url end,
    set = function(v)
        if v == "" then
            WH.url = ""
            whSetState("NOT CONFIGURED", "Warn", "URL cleared (not saved)")
            refreshViews(Feat.wh_url)
            return true
        end
        local ok, u = whValidate(v)
        if not ok then return false, u end
        WH.url = u
        whSetState("URL SET", "Warn", "not saved, not tested")
        refreshViews(Feat.wh_url)
        return true
    end })
def("Webhook", "wh_enable", { kind = "toggle", name = "Enable Webhook", desc = "Allows events and statistics to be posted to Discord.", fn = function(on)
    if not on then WH.queue = {} return end
    if not HTTP_REQUEST then return false, "This environment has no HTTP request function (request / http_request)" end
    local ok, why = whValidate(WH.url)
    if not ok then return false, "Cannot enable: " .. tostring(why) end
end })
def("Webhook", "wh_events", { kind = "toggle", name = "Event Notifications", desc = "Posts farm events: egg broken, animal collected (with Rarity if the item exposes it), errors.", fn = function() end })
local statsLoop
def("Webhook", "wh_stats", { kind = "toggle", name = "Farming Statistics", desc = "Posts a farming summary on the interval below.", fn = function(on)
    if statsLoop then statsLoop.alive = false statsLoop = nil end
    if not on then return end
    if not S.wh_enable then return false, "Enable Webhook first" end
    local nextAt = os.clock() + (S.wh_interval or 10) * 60
    statsLoop = loop(5, function()
        if os.clock() < nextAt then return end
        nextAt = os.clock() + (S.wh_interval or 10) * 60
        whEvent("Farming Statistics", "Periodic summary", "info", farmFields())
    end)
end })
def("Webhook", "wh_interval", { kind = "slider", name = "Statistics Interval (min)", desc = "Time between statistics posts.", min = 1, max = 60, step = 1, default = 10 })
for _, e in ipairs({
    { "wh_ev_egg", "Notify: Egg Broken", "Post when an egg you hit leaves your base." },
    { "wh_ev_pet", "Notify: Any New Pet", "Post for every new animal Tool." },
    { "wh_ev_rare", "Notify: Rare Pet", "Post when a pet reaches the Pet Rarity Filter." },
    { "wh_ev_error", "Notify: Errors", "Post farm errors." },
    { "wh_ev_session", "Notify: Session Summary", "Post a summary when Auto Farm stops or the hub unloads." },
    { "wh_ev_event", "Notify: Game Events", "Post when Event Detection spots something." },
}) do
    def("Webhook", e[1], { kind = "toggle", name = e[2], desc = e[3] .. " Needs Event Notifications on.", fn = function() end })
    S[e[1]] = true
    V2.on[e[1]] = true
end
def("Webhook", "wh_summary", { kind = "button", name = "Send Session Summary", desc = "Posts the current farm statistics to Discord now.", run = function()
    if not S.wh_enable then return false, "Enable Webhook first" end
    if not whEvent("Session summary", "Requested from the hub", "info", farmFields()) then return false, "Webhook URL is not set" end
    notify("Session summary queued", "good", 2)
end })
def("Webhook", "wh_test", { kind = "button", name = "Test Webhook", desc = "Sends one test embed and shows the real HTTP result.", run = function()
    if not HTTP_REQUEST then
        whSetState("UNAVAILABLE", "Bad", "no HTTP request function")
        return false, "This environment has no HTTP request function (request / http_request)"
    end
    local ok, why = whValidate(WH.url)
    if not ok then
        whSetState("NOT CONFIGURED", "Bad", tostring(why))
        return false, tostring(why)
    end
    whSetState("SENDING...", "Warn", "test in progress")
    task.spawn(function()
        local sent, reason = whPost(whEmbed("CAZIELX ARCHX | Test", "Webhook test sent from the hub.", "info", {
            { name = "Player", value = Player.DisplayName, inline = true },
            { name = "Game", value = game.Name ~= "" and game.Name or tostring(game.PlaceId), inline = true },
        }))
        if sent then
            WH.sent += 1
            whSetState("CONNECTED", "Good", tostring(reason) .. " @ " .. os.date("%H:%M:%S"))
            notify("Discord test delivered (" .. tostring(reason) .. ")", "good", 3)
        else
            WH.failed += 1
            whSetState("ERROR", "Bad", tostring(reason))
            notify("Webhook test failed: " .. tostring(reason), "bad", 6)
        end
    end)
end })
def("Webhook", "wh_save", { kind = "button", name = "Save Webhook", desc = "Validates and saves the URL to its own file.", run = function()
    local ok, why = whSave()
    if not ok then whSetState("NOT SAVED", "Bad", tostring(why)) return false, tostring(why) end
    whSetState("SAVED", "Good", "saved to " .. WEBHOOK_FILE)
    notify("Webhook URL saved", "good", 2.5)
end })
def("Webhook", "wh_load", { kind = "button", name = "Load Webhook", desc = "Loads the saved URL from file.", run = function()
    local ok, why = whLoad()
    if not ok then return false, tostring(why) end
    refreshViews(Feat.wh_url)
    notify("Webhook URL loaded", "good", 2.5)
end })
def("Webhook", "wh_clear", { kind = "button", name = "Clear Webhook", desc = "Removes the URL from this session and from the saved file.", run = function()
    if S.wh_enable then setValue("wh_enable", false, true) end
    if S.wh_stats then setValue("wh_stats", false, true) end
    WH.url, WH.queue = "", {}
    if HAS_FILES then
        if typeof(delfile) == "function" then pcall(delfile, WEBHOOK_FILE) else pcall(writefile, WEBHOOK_FILE, "{}") end
    end
    whSetState("NOT CONFIGURED", "Warn", "URL cleared")
    refreshViews(Feat.wh_url)
    notify("Webhook cleared", "info", 2)
end })

for _, e in ipairs({ { "min_gen", "Minimum Generation Filter" },
    { "titanic", "Titanic Eggs" }, { "keep_gd", "Keep Gold And Diamond" }, { "sell_weak", "Sell Weakest When Full" } }) do
    na("Farm", e[1], e[2], "Needs game integration.")
end
for _, e in ipairs({ { "inv_trail", "Buy Trails" }, { "inv_gear", "Use Best Gear" }, { "up_tread", "Upgrade Treadmill" },
    { "claim_rewards", "Claim Rewards" }, { "claim_now", "Claim Now" }, { "sell_now", "Sell Now" } }) do
    na("Farm", e[1], e[2], "Needs game integration.")
end

end -- scope block
local speed
do -- scope block (keeps main chunk under the 200-local limit)
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
    { "ev_predict", "Event Predictor" } }) do
    na("Automation", e[1], e[2], "Needs game integration.")
end
do
    local EVENT_WORDS = { "event", "halloween", "christmas", "easter", "boss", "invasion", "meteor", "blizzard", "admin", "lucky" }
    local evBag
    def("Automation", "ev_alert", { kind = "toggle", name = "Event Detection", desc = "Heuristic: watches the top level of Workspace and ReplicatedStorage (and their attributes) for new things whose names look like events. No game-specific names are assumed.", fn = function(on)
        if evBag then evBag.clear() evBag = nil end
        if not on then return end
        local bag = newBag()
        evBag = bag
        local lastAt = {}
        local function looks(n)
            n = tostring(n):lower()
            for _, w in ipairs(EVENT_WORDS) do
                if n:find(w, 1, true) then return true end
            end
            return false
        end
        local function report(kind, name, detail)
            local key = kind .. name
            local now = os.clock()
            if lastAt[key] and now - lastAt[key] < 60 then return end
            lastAt[key] = now
            notify("Possible event: " .. name .. " (" .. kind .. ")", "info", 5)
            farmEvent("Possible game event", ("**%s** (%s)%s"):format(name, kind, detail and (" " .. detail) or ""), "warn", nil, "event")
        end
        for _, root in ipairs({ workspace, ReplicatedStorage }) do
            bag.add(root.ChildAdded:Connect(function(c)
                if looks(c.Name) and not Players:FindFirstChild(c.Name) then report("new object in " .. root.Name, c.Name) end
            end))
            bag.add(root.AttributeChanged:Connect(function(a)
                if looks(a) then report("attribute on " .. root.Name, a, "= " .. tostring(root:GetAttribute(a))) end
            end))
        end
    end })
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

speed = humanoidOverride("WalkSpeed", function() return S.speed_value end)
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
local R15_BONES = {
    { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6_BONES = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
local esp = { ents = {}, frame = 0 }

local function espColor() return hexColor(S.esp_custom) or ESP_COLORS[S.esp_color] or ESP_COLORS.Blue end
local function espTypeColor(key) return hexColor(S["esp_c_" .. key]) or espColor() end

local function espNewEnt(plr, parent)
    local folder = Instance.new("Folder")
    folder.Name = plr.Name
    folder.Parent = parent
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderSizePixel = 0
    box.Visible = false
    box.Parent = folder
    local bs = Instance.new("UIStroke")
    bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    bs.Parent = box
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(.5, 1)
    label.Size = UDim2.fromOffset(200, 14)
    label.Font = BOLD
    label.TextSize = 12
    label.TextStrokeTransparency = .5
    label.Visible = false
    label.Parent = folder
    local bones = {}
    for i = 1, #R15_BONES do
        local l = Instance.new("Frame")
        l.AnchorPoint = Vector2.new(.5, .5)
        l.BorderSizePixel = 0
        l.Visible = false
        l.Parent = folder
        bones[i] = l
    end
    return { folder = folder, box = box, stroke = bs, label = label, bones = bones }
end

local function espHide(ent)
    ent.box.Visible = false
    ent.label.Visible = false
    for _, l in ipairs(ent.bones) do l.Visible = false end
    if ent.hl then ent.hl:Destroy() ent.hl, ent.hlChar = nil, nil end
end
local function espDrop(plr)
    local ent = esp.ents[plr]
    if not ent then return end
    esp.ents[plr] = nil
    if ent.hl then pcall(function() ent.hl:Destroy() end) end
    pcall(function() ent.folder:Destroy() end)
end

local function espUpdate(plr, cam, myPos)
    local ent = esp.ents[plr]
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and head and hum) or hum.Health <= 0 then
        if ent then espHide(ent) end
        return
    end
    local dist = (hrp.Position - myPos).Magnitude
    if dist > (S.esp_range or 1000) then
        if ent then espHide(ent) end
        return
    end
    if not ent then
        ent = espNewEnt(plr, esp.gui)
        esp.ents[plr] = ent
    end
    local tr, th = S.esp_trans or 0, S.esp_thick or 1.5
    local cHl, cBox, cName, cSkel = espTypeColor("hl"), espTypeColor("box"), espTypeColor("name"), espTypeColor("skel")

    if S.esp_hl then
        if ent.hlChar ~= char or not ent.hl or not ent.hl.Parent then
            if ent.hl then ent.hl:Destroy() end
            local hl = Instance.new("Highlight")
            hl.Name = "CAZX_ESP"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = char
            hl.Parent = char
            ent.hl, ent.hlChar = hl, char
        end
        if ent.hl.FillColor ~= cHl then ent.hl.FillColor = cHl ent.hl.OutlineColor = cHl end
        ent.hl.FillTransparency = math.clamp(.35 + tr * .65, 0, 1)
        ent.hl.OutlineTransparency = tr
    elseif ent.hl then
        ent.hl:Destroy()
        ent.hl, ent.hlChar = nil, nil
    end

    local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y * .5 + .2, 0))
    local bot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
    if top.Z <= 0 or bot.Z <= 0 then
        ent.box.Visible, ent.label.Visible = false, false
        for _, l in ipairs(ent.bones) do l.Visible = false end
        return
    end
    local h = math.max(math.abs(bot.Y - top.Y), 8)
    local w = h * .55
    local cx = (top.X + bot.X) * .5

    if S.esp_box then
        ent.box.Position = UDim2.fromOffset(cx - w / 2, top.Y)
        ent.box.Size = UDim2.fromOffset(w, h)
        ent.stroke.Color, ent.stroke.Thickness, ent.stroke.Transparency = cBox, th, tr
        ent.box.Visible = true
    else
        ent.box.Visible = false
    end

    if S.esp_name or S.esp_dist or S.esp_pet then
        local s = S.esp_name and plr.DisplayName or ""
        if S.esp_dist then s = (s ~= "" and (s .. "  ") or "") .. ("[%d]"):format(math.floor(dist)) end
        if S.esp_pet then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool and tool.Name ~= "Bat" and not isAxeName(tool.Name) then s = (s ~= "" and (s .. "  ") or "") .. "<" .. tool.Name .. ">" end
        end
        ent.label.Text = s
        ent.label.TextColor3 = cName
        ent.label.TextTransparency = tr
        ent.label.Position = UDim2.fromOffset(cx, top.Y - 3)
        ent.label.Visible = true
    else
        ent.label.Visible = false
    end

    if S.esp_skel then
        local rig = char:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES
        for i, pair in ipairs(ent.bones) do
            local bone = rig[i]
            local a = bone and char:FindFirstChild(bone[1])
            local b = bone and char:FindFirstChild(bone[2])
            local shown = false
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local pa = cam:WorldToViewportPoint(a.Position)
                local pb = cam:WorldToViewportPoint(b.Position)
                if pa.Z > 0 and pb.Z > 0 then
                    local dx, dy = pb.X - pa.X, pb.Y - pa.Y
                    pair.Position = UDim2.fromOffset((pa.X + pb.X) * .5, (pa.Y + pb.Y) * .5)
                    pair.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), th)
                    pair.Rotation = math.deg(math.atan2(dy, dx))
                    if pair.BackgroundColor3 ~= cSkel then pair.BackgroundColor3 = cSkel end
                    pair.BackgroundTransparency = tr
                    shown = true
                end
            end
            pair.Visible = shown
        end
    else
        for _, l in ipairs(ent.bones) do l.Visible = false end
    end
end

local function espStop()
    if esp.bag then esp.bag.clear() esp.bag = nil end
    for p in pairs(esp.ents) do espDrop(p) end
    esp.gui = nil
end
local function espStart()
    espStop()
    local sg = Instance.new("ScreenGui")
    sg.Name = "CazxEsp"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 90
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = PlayerGui
    local bag = newBag()
    bag.add(sg)
    esp.bag, esp.gui, esp.frame, esp.warned = bag, sg, 0, false
    bag.add(Players.PlayerRemoving:Connect(espDrop))
    bag.add(RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        esp.frame += 1
        local list = Players:GetPlayers()
        local stagger = #list > 30
        local mc = Player.Character
        local mh = mc and mc:FindFirstChild("HumanoidRootPart")
        local myPos = mh and mh.Position or cam.CFrame.Position
        for _, plr in ipairs(list) do
            if plr ~= Player and (not stagger or (esp.frame + plr.UserId) % 2 == 0) then
                local ok, err = pcall(espUpdate, plr, cam, myPos)
                if not ok and not esp.warned then
                    esp.warned = true
                    warn("[CAZX] ESP: " .. tostring(err))
                    farmErr("ESP: " .. tostring(err))
                end
            end
        end
    end))
end

def("Visuals", "esp_players", { kind = "toggle", name = "Player ESP", desc = "Master switch for the player visuals chosen below (screen-space, event-free, cleaned up when a player leaves).", fn = function(on)
    if not on then espStop() return end
    if not (S.esp_skel or S.esp_box or S.esp_name or S.esp_dist or S.esp_hl) then
        setValue("esp_skel", true, true)
        setValue("esp_name", true, true)
    end
    espStart()
end })
for _, e in ipairs({
    { "esp_skel", "Skeleton ESP", "Bone skeleton over each player (R15 and R6)." },
    { "esp_box", "Box ESP", "Bounding box around each player." },
    { "esp_name", "Name ESP", "Display name above each player." },
    { "esp_dist", "Distance ESP", "Distance in studs above each player." },
    { "esp_hl", "Highlight ESP", "Colored highlight through walls." },
}) do
    def("Visuals", e[1], { kind = "toggle", name = e[2], desc = e[3], fn = function() end })
end
def("Visuals", "esp_color", { kind = "dropdown", name = "ESP Color", desc = "Preset color. Custom ESP Color overrides it when set.", options = { "Blue", "Red", "Green", "Purple", "White" }, default = "Blue" })
def("Visuals", "esp_custom", { kind = "color", name = "Custom ESP Color", desc = "Hex like #ff4466 or tap a swatch. Empty uses the preset.", key = "Accent", palette = true })
def("Visuals", "esp_trans", { kind = "slider", name = "ESP Transparency", desc = "0 is solid, 0.9 is almost invisible.", min = 0, max = .9, step = .05, default = .1 })
def("Visuals", "esp_thick", { kind = "slider", name = "ESP Thickness", desc = "Line thickness for box and skeleton.", min = 1, max = 4, step = .5, default = 1.5 })
def("Visuals", "esp_range", { kind = "slider", name = "ESP Max Distance", desc = "Players farther than this are not drawn (saves FPS).", min = 100, max = 3000, step = 50, default = 1000 })

end -- scope block
local bootWarnings, preloadTheme, fpsValue, frameCount, lastFpsAt, sampleStats, buildInterface
do -- scope block (keeps main chunk under the 200-local limit)
local eggEsp
V2.rarityColors = { Color3.fromRGB(190, 190, 200), Color3.fromRGB(80, 220, 120), Color3.fromRGB(70, 140, 255), Color3.fromRGB(170, 90, 255),
    Color3.fromRGB(255, 184, 77), Color3.fromRGB(255, 84, 98), Color3.fromRGB(80, 230, 255), Color3.fromRGB(255, 110, 200) }
function V2.eggEspStyle(o, rec)
    if not rec.hl.Parent then return end
    local name = eggLabel(o)
    local idx, rl = V2.rarityInfo(o, name)
    local col = (S.esp_rarity and V2.rarityColors[idx]) or hexColor(S.esp_c_egg) or T.Accent
    rec.hl.FillColor, rec.hl.OutlineColor = col, Color3.new(1, 1, 1)
    rec.hl.FillTransparency = math.clamp(.35 + (S.esp_trans or .1) * .65, 0, 1)
    if S.esp_rarity then name = name .. (idx > 0 and ("  [" .. rl .. "]") or "  [rarity n/a]") end
    rec.lbl.Text = name
    rec.lbl.TextColor3 = col
end
function V2.refreshEggEsp()
    if not eggEsp then return end
    for o, rec in pairs(eggEsp.rec) do pcall(V2.eggEspStyle, o, rec) end
end
def("Visuals", "esp_egg", { kind = "toggle", name = "Egg ESP", desc = "Highlights and labels eggs under Workspace.Build.ZoneBuilds (event-driven, cleaned up when off).", fn = function(on)
    if eggEsp then
        eggEsp.bag.clear()
        for _, rec in pairs(eggEsp.rec) do pcall(function() rec.hl:Destroy() rec.bb:Destroy() end) end
        eggEsp = nil
    end
    if not on then return end
    local build = workspace:FindFirstChild("Build")
    local zones = build and build:FindFirstChild("ZoneBuilds")
    if not zones then return false, "Workspace.Build.ZoneBuilds was not found in this server" end
    local st = { bag = newBag(), rec = {} }
    eggEsp = st
    local function tag(o)
        if o.Name == "Egg" and o:IsA("BasePart") and not st.rec[o] then
            local holder = o.Parent
            local folder = holder and holder.Parent
            if folder and folder.Name == "Eggs" then
                local hl = Instance.new("Highlight")
                hl.Name = "CAZX_EGG"
                hl.Adornee = o
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = o
                local bb = Instance.new("BillboardGui")
                bb.Name = "CAZX_EGGLBL"
                bb.Adornee = o
                bb.AlwaysOnTop = true
                bb.Size = UDim2.fromOffset(190, 18)
                bb.StudsOffset = Vector3.new(0, 3, 0)
                bb.MaxDistance = S.esp_range or 1000
                bb.Parent = o
                local lbl = Instance.new("TextLabel")
                lbl.BackgroundTransparency = 1
                lbl.Size = UDim2.fromScale(1, 1)
                lbl.Font = BOLD
                lbl.TextSize = 12
                lbl.TextStrokeTransparency = .4
                lbl.Parent = bb
                st.rec[o] = { hl = hl, bb = bb, lbl = lbl }
                pcall(V2.eggEspStyle, o, st.rec[o])
            end
        end
    end
    for _, d in ipairs(zones:GetDescendants()) do tag(d) end
    st.bag.add(zones.DescendantAdded:Connect(tag))
    st.bag.add(zones.DescendantRemoving:Connect(function(o)
        local rec = st.rec[o]
        if rec then
            pcall(function() rec.hl:Destroy() rec.bb:Destroy() end)
            st.rec[o] = nil
        end
    end))
end })
na("Visuals", "esp_lucky", "Lucky Egg ESP", "Marks lucky eggs.", "The game's definition of a lucky egg is not known or verified, so it is not guessed.")
def("Visuals", "esp_rarity", { kind = "toggle", name = "Rarity Indicator", desc = "Egg ESP shows the rarity next to the egg name and colors it by rarity (only when the egg exposes a rarity).", fn = function() task.defer(V2.refreshEggEsp) end })
def("Visuals", "esp_pet", { kind = "toggle", name = "Pet ESP (carried)", desc = "Player ESP also shows the animal Tool each other player is holding. Pets standing in the world have no verified object, so they are not drawn.", fn = function() end })
for _, e in ipairs({ { "esp_c_skel", "Skeleton Color" }, { "esp_c_box", "Box Color" }, { "esp_c_name", "Name / Distance Color" }, { "esp_c_hl", "Highlight Color" }, { "esp_c_egg", "Egg ESP Color" } }) do
    def("Visuals", e[1], { kind = "color", name = e[2], desc = "Hex color for this ESP type. Empty uses the main ESP color.", key = "Accent", palette = true, fn = function() V2.refreshEggEsp() end })
end

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
do
    local release
    def("Statistics", "pet_alert", { kind = "toggle", name = "New Pet Alerts", desc = "Alert for every new animal Tool in your Backpack (works without Auto Farm). Rare pets are highlighted.", fn = function(on)
        if release then release() release = nil end
        if on then release = V2.petTrackStart() end
    end })
end

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
def("Settings", "cfg_autosave", { kind = "toggle", name = "Auto Save", desc = "Saves the configuration about 1.5s after any change. A warning appears if the file cannot be written.", fn = function() end })
S.cfg_autosave = true
V2.on.cfg_autosave = true
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
function V2.unloadNow()
    if S.wh_enable and WH.url ~= "" and S.wh_ev_session ~= false and HTTP_REQUEST then
        pcall(whPost, whEmbed("Session summary", "The hub was unloaded", "info", farmFields()))
    end
    if _G.__CAZX_CLEANUP then _G.__CAZX_CLEANUP() end
end
def("Settings", "cfg_unload", { kind = "button", name = "Unload Hub", desc = "Sends a session summary (if enabled), disables all features, closes connections and removes the UI.", run = function()
    task.defer(V2.unloadNow)
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
def("Theme", "loading_art", { kind = "input", name = "Loading Artwork", desc = "Your own image: a Roblox asset ID you uploaded (digits or rbxassetid://) or an image file in the executor workspace (.png/.jpg/.webp, needs getcustomasset). Applied on the next launch; empty uses the built-in logo.",
    placeholder = "e.g. 1234567890 or nagi.png", default = "",
    validate = function(v)
        if v:match("^%d+$") or v:match("^rbxassetid://%d+$") then return true end
        local lv = v:lower()
        return not v:find("..", 1, true) and v:match("^[%w%._%-/ ]+$") ~= nil and (lv:match("%.png$") ~= nil or lv:match("%.jpe?g$") ~= nil or lv:match("%.webp$") ~= nil)
    end })

local function isUrl(v)
    return type(v) == "string" and #v <= 300 and v:match("^https?://[%w%-%.]+[^%s]*$") ~= nil
end
local function copyLink(v, what)
    if type(v) ~= "string" or v == "" then return false, what .. " is empty. Set it above first." end
    if HAS_CLIPBOARD and pcall(setclipboard, v) then
        notify(what .. " copied", "good", 2)
        return
    end
    return false, "Clipboard is not available in this environment"
end
def("About", "about_dev", { kind = "input", name = "Developer Credit", desc = "Name shown on the About page.", placeholder = "developer name", default = "CAZIELX",
    validate = function(v) return #v <= 60 end })
def("About", "about_src", { kind = "input", name = "Original Source Credit", desc = "Who or what the original source came from. Left empty until you fill it in.", placeholder = "original author or project", default = "",
    validate = function(v) return #v <= 80 end })
def("About", "about_discord", { kind = "input", name = "Discord Link", desc = "Your invite link (http/https). Nothing is pre-filled.", placeholder = "https://", default = "", validate = isUrl })
def("About", "about_social", { kind = "input", name = "Social Link", desc = "Your social page link (http/https). Nothing is pre-filled.", placeholder = "https://", default = "", validate = isUrl })
def("About", "about_link", { kind = "input", name = "Credit Link", desc = "Link to the original source or credits page (http/https).", placeholder = "https://", default = "", validate = isUrl })
def("About", "about_copy_discord", { kind = "button", name = "Copy Discord Link", desc = "Copies the Discord link to the clipboard.", run = function() return copyLink(S.about_discord, "Discord link") end })
def("About", "about_copy_social", { kind = "button", name = "Copy Social Link", desc = "Copies the social link to the clipboard.", run = function() return copyLink(S.about_social, "Social link") end })
def("About", "about_copy_credit", { kind = "button", name = "Copy Credit Link", desc = "Copies the credit link to the clipboard.", run = function() return copyLink(S.about_link, "Credit link") end })
local function openLink(v, what)
    if type(v) ~= "string" or v == "" then return false, what .. " is empty. Set it above first." end
    if not isUrl(v) then return false, what .. " is not a valid http(s) link" end
    if pcall(function() GuiService:OpenBrowserWindow(v) end) then
        notify("Opening " .. what .. "...", "info", 2)
        return
    end
    if HAS_CLIPBOARD and pcall(setclipboard, v) then
        notify("This environment cannot open a browser. " .. what .. " copied instead.", "warn", 4)
        return
    end
    return false, "Cannot open links here and the clipboard is unavailable"
end
def("About", "about_open_discord", { kind = "button", name = "Open Discord", desc = "Opens the Discord link (falls back to copying it).", run = function() return openLink(S.about_discord, "Discord link") end })
def("About", "about_open_social", { kind = "button", name = "Open Social", desc = "Opens the social link (falls back to copying it).", run = function() return openLink(S.about_social, "Social link") end })
def("About", "about_open_credit", { kind = "button", name = "Open Credit", desc = "Opens the credit link (falls back to copying it).", run = function() return openLink(S.about_link, "Credit link") end })


bootWarnings = 0
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

function preloadTheme(data)
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
fpsValue, frameCount, lastFpsAt = 0, 0, os.clock()
function sampleStats()
    local now = os.clock()
    local cash = getCash()
    if cash then
        if not cashBase then cashBase = cash end
        local ses = V2.session
        if ses.lastCash and cash > ses.lastCash then ses.earnings += cash - ses.lastCash end
        ses.lastCash = cash
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
diagItems[#diagItems + 1] = { label = "Farm / Auto Farm", fn = function() return tostring(FarmInfo.status) end }
diagItems[#diagItems + 1] = { label = "Farm / Egg types", fn = function() return tostring(FarmInfo.catalog) end }
diagItems[#diagItems + 1] = { label = "Farm / Last Error", fn = function() return FarmInfo.errors[#FarmInfo.errors] or "none" end }
diagItems[#diagItems + 1] = { label = "Scheduler / Tasks", fn = function() return V2.sched.count() .. " active, " .. V2.sched.errors .. " error(s)" end }
diagItems[#diagItems + 1] = { label = "Scheduler / Last Error", fn = function() return V2.sched.lastErr end }
diagItems[#diagItems + 1] = { label = "Pets / Obtained", fn = function() return V2.session.petTotal .. " | best: " .. V2.session.bestName end }
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

local function cazxEnvA()
    return { Players = Players, UIS = UIS, Stats = Stats, Player = Player, APP_NAME = APP_NAME, EDITION = EDITION, VERSION = VERSION, BUILD = BUILD, CHANGELOG = CHANGELOG, IS_TOUCH = IS_TOUCH, HAS_FILES = HAS_FILES, HAS_CLIPBOARD = HAS_CLIPBOARD, HAS_FPSCAP = HAS_FPSCAP, HTTP_REQUEST = HTTP_REQUEST, FONT = FONT, MONO = MONO, S = S, UI = UI, POS = POS, Root = Root, ACCENT_SWATCHES = ACCENT_SWATCHES, T = T, hexColor = hexColor, bindings = bindings, pruneBindings = pruneBindings, tween = tween, new = new, round = round, stroke = stroke, text = text, Icons = Icons, CreateIcon = CreateIcon, SetIconColor = SetIconColor }
end
local function cazxEnvB()
    return { SetIconState = SetIconState, DestroyIcon = DestroyIcon, iconHover = iconHover, Tabs = Tabs, TabByName = TabByName, FeatList = FeatList, valid = valid, setValue = setValue, V2 = V2, gui = gui, WIN_W = WIN_W, WIN_H = WIN_H, TITLE_H = TITLE_H, SB_OPEN = SB_OPEN, SB_MIN = SB_MIN, ROW_H = ROW_H, TAB_H = TAB_H, state = state, uiRefs = uiRefs, tip = tip, bindTooltip = bindTooltip, beginDrag = beginDrag, isPress = isPress, getRemote = getRemote, numAttr = numAttr, getCash = getCash, FarmInfo = FarmInfo, WH = WH, whValidate = whValidate, formatNumber = formatNumber, formatTime = formatTime, cashPerSecond = cashPerSecond, activeCount = activeCount, diagItems = diagItems }
end
function buildInterface()
    -- Dependency snapshot: keeps this function under Luau's 60-upvalue limit.
    local EA, EB = cazxEnvA(), cazxEnvB()
    local Players, UIS, Stats, Player, APP_NAME, EDITION, VERSION, BUILD, CHANGELOG, IS_TOUCH, HAS_FILES, HAS_CLIPBOARD, HAS_FPSCAP, HTTP_REQUEST, FONT, MONO = (EA).Players, (EA).UIS, (EA).Stats, (EA).Player, (EA).APP_NAME, (EA).EDITION, (EA).VERSION, (EA).BUILD, (EA).CHANGELOG, (EA).IS_TOUCH, (EA).HAS_FILES, (EA).HAS_CLIPBOARD, (EA).HAS_FPSCAP, (EA).HTTP_REQUEST, (EA).FONT, (EA).MONO
    local S, UI, POS, Root, ACCENT_SWATCHES, T, hexColor, bindings, pruneBindings, tween, new, round, stroke, text, Icons, CreateIcon = (EA).S, (EA).UI, (EA).POS, (EA).Root, (EA).ACCENT_SWATCHES, (EA).T, (EA).hexColor, (EA).bindings, (EA).pruneBindings, (EA).tween, (EA).new, (EA).round, (EA).stroke, (EA).text, (EA).Icons, (EA).CreateIcon
    local SetIconColor, SetIconState, DestroyIcon, iconHover, Tabs, TabByName, FeatList, valid, setValue, V2, gui, WIN_W, WIN_H, TITLE_H, SB_OPEN, SB_MIN = (EA).SetIconColor, (EB).SetIconState, (EB).DestroyIcon, (EB).iconHover, (EB).Tabs, (EB).TabByName, (EB).FeatList, (EB).valid, (EB).setValue, (EB).V2, (EB).gui, (EB).WIN_W, (EB).WIN_H, (EB).TITLE_H, (EB).SB_OPEN, (EB).SB_MIN
    local ROW_H, TAB_H, state, uiRefs, tip, bindTooltip, beginDrag, isPress, getRemote, numAttr, getCash, FarmInfo, WH, whValidate, formatNumber, formatTime = (EB).ROW_H, (EB).TAB_H, (EB).state, (EB).uiRefs, (EB).tip, (EB).bindTooltip, (EB).beginDrag, (EB).isPress, (EB).getRemote, (EB).numAttr, (EB).getCash, (EB).FarmInfo, (EB).WH, (EB).whValidate, (EB).formatNumber, (EB).formatTime
    local cashPerSecond, activeCount, diagItems = (EB).cashPerSecond, (EB).activeCount, (EB).diagItems
    local win = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
        Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundColor3 = "Bg", BackgroundTransparency = "Tr", BorderSizePixel = 0,
        Visible = false, ClipsDescendants = true, Active = true }, gui)
    round(win, 12) stroke(win, "Border", 1.2, 0)
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
            task.defer(V2.unloadNow)
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

    local function buildInput(f, parent)
        local card, st = makeCard(parent, ROW_H + 36)
        nameDesc(card, f, 20)
        local box = new("TextBox", { Position = UDim2.fromOffset(10, ROW_H), Size = UDim2.new(1, -20, 0, 28), BackgroundColor3 = "Bg", Text = "",
            PlaceholderText = f.placeholder or "", PlaceholderColor3 = "Sub", TextColor3 = "Text", Font = MONO, TextSize = 12,
            ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ClipsDescendants = true, BorderSizePixel = 0 }, card)
        round(box, 7)
        local bs = stroke(box, "Border", 1, .1)
        new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
        attachFx(card, st, card)
        local function current()
            if f.private then return f.get() end
            return S[f.id] or ""
        end
        local function shown()
            local v = current()
            if f.mask and not box:IsFocused() then return f.mask(v) end
            return v
        end
        box.Focused:Connect(function()
            box.Text = current()
            tween(bs, .15, { Color = T.Accent })
        end)
        box.FocusLost:Connect(function()
            tween(bs, .15, { Color = T.Border })
            local v = box.Text:match("^%s*(.-)%s*$")
            if v ~= current() then
                if f.private then
                    local ok, msg = f.set(v)
                    if ok == false then notify(msg or "Invalid value", "warn", 4) end
                elseif not setValue(f.id, v) then
                    notify(f.name .. ": invalid value", "warn", 4)
                end
            end
            box.Text = shown()
        end)
        return card, function() if not box:IsFocused() then box.Text = shown() end end
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
        return card, function() swatch.BackgroundColor3 = hexColor(S[f.id]) or T[f.key] box.Text = S[f.id] end
    end

    local builders = { toggle = buildToggle, slider = buildSlider, dropdown = buildDropdown, button = buildButton, textbox = buildTextbox, color = buildColor, input = buildInput }
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
        statTile(grid, p, "Eggs Broken", function() return FarmInfo.broken end, "Eggs you hit that left your base while Auto Farm ran")
        statTile(grid, p, "Animals (new tools)", function() return FarmInfo.animals end, "New Tools seen in your Backpack while Auto Farm ran")
        statTile(grid, p, "Best Pet", function() return V2.session.bestName end, "Highest rarity among pets seen this session")
        statTile(grid, p, "Total Earnings", cashText(function() return getCash() and V2.session.earnings or nil end), "Sum of real cash increases seen this session (spending is not subtracted)")
        statTile(grid, p, "Avg Reward / Egg", function()
            if FarmInfo.broken == 0 then return "N/A" end
            return formatNumber(V2.session.earnings / FarmInfo.broken)
        end, "Earnings divided by eggs processed")
        statTile(grid, p, "Egg Respawns", function() return FarmInfo.respawns .. " new / " .. FarmInfo.vanished .. " gone" end, "Seen by the egg scanner or Auto Farm")
    end

    local function buildFarmStatus(page)
        sectionLabel(page, "LIVE STATUS", 1)
        local grid = statGrid(page, 2)
        local p = page
        statTile(grid, p, "Auto Farm", function()
            if not S.farm_auto then return "OFF" end
            local s = tostring(FarmInfo.status)
            return s, (s:find("ERROR") and "Bad") or (s:find("BREAKING") and "Good") or "Warn"
        end, "Current Auto Farm state")
        statTile(grid, p, "Target", function() return FarmInfo.target end)
        statTile(grid, p, "Eggs In Base", function() return FarmInfo.eggs end)
        statTile(grid, p, "Eggs Broken", function() return FarmInfo.broken end, "Counted when an egg you hit leaves your base")
        statTile(grid, p, "Animals (new tools)", function() return FarmInfo.animals end, "Counted from new Tools appearing in your Backpack while Auto Farm runs")
        statTile(grid, p, "Last Animal", function() return FarmInfo.lastAnimal end)
        statTile(grid, p, "Eggs / Hour", function()
            if not S.farm_auto then return "N/A" end
            return ("%.1f"):format(FarmInfo.broken / math.max((os.clock() - FarmInfo.t0) / 3600, 1 / 3600))
        end)
        statTile(grid, p, "Egg Types", function() return FarmInfo.catalog end, "Press Egg Scanner (or turn on Auto Egg Scanner) to refresh")
        statTile(grid, p, "Paused", function() return FarmInfo.paused and "PAUSED" or "No", FarmInfo.paused and "Warn" or nil end)
        statTile(grid, p, "Egg Respawns", function() return FarmInfo.respawns .. " new / " .. FarmInfo.vanished .. " gone" end)
        statTile(grid, p, "Best Pet", function() return V2.session.bestName end)
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

    local function buildWebhook(page)
        sectionLabel(page, "DISCORD DELIVERY", 1)
        local grid = statGrid(page, 2)
        local p = page
        statTile(grid, p, "Status", function() return WH.state, WH.kind end)
        statTile(grid, p, "Detail", function() return WH.detail end)
        statTile(grid, p, "Sent", function() return WH.sent end)
        statTile(grid, p, "Failed", function() return WH.failed, WH.failed > 0 and "Warn" or nil end)
        statTile(grid, p, "Queue", function() return #WH.queue end)
        statTile(grid, p, "HTTP", function() return HTTP_REQUEST and "Available" or "Missing", HTTP_REQUEST and "Good" or "Bad" end)
    end

    local function buildDiagnostics(page)
        sectionLabel(page, "ENVIRONMENT", 1)
        diagRow(page, "Env", "File access", function() return yesNo(HAS_FILES) end)
        diagRow(page, "Env", "Clipboard", function() return yesNo(HAS_CLIPBOARD) end)
        diagRow(page, "Env", "HTTP request", function() return yesNo(HTTP_REQUEST ~= nil) end)
        diagRow(page, "Webhook", "URL", function() local ok = whValidate(WH.url) return ok and "Set (valid)" or "Not set", ok and "Good" or "Warn" end)
        diagRow(page, "Webhook", "Status", function() return WH.state, WH.kind end)
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
        text(page, APP_NAME .. "  " .. EDITION, 20, "Text", true, { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1 })
        local grid = statGrid(page, 2)
        local p = page
        statTile(grid, p, "Version", function() return VERSION end)
        statTile(grid, p, "Build", function() return BUILD end)
        statTile(grid, p, "Developer", function() return (S.about_dev or "") ~= "" and S.about_dev or "not set" end)
        statTile(grid, p, "Original Source", function() return (S.about_src or "") ~= "" and S.about_src or "not set" end)
        sectionLabel(page, "UPDATE INFORMATION", 3)
        local card = makeCard(page, 20 + #CHANGELOG * 32)
        local y = 12
        for _, l in ipairs(CHANGELOG) do
            text(card, "- " .. l, 11, "Sub", false, { Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 30),
                TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top })
            y += 32
        end
        sectionLabel(page, "CREDITS AND LINKS", #page:GetChildren())
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

    local custom = { Home = buildHome, Statistics = buildStatistics, Webhook = buildWebhook, Diagnostics = buildDiagnostics, About = buildAbout, Theme = buildThemePreview, Farm = buildFarmStatus }
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

end -- scope block
do -- scope block (keeps main chunk under the 200-local limit)
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

-- Optional artwork: an asset ID the user uploaded themselves (Theme > Loading Artwork). Read before the UI exists.
local function parseArt(v)
    if type(v) ~= "string" then return nil end
    local id = v:match("^%d+$") or v:match("^rbxassetid://(%d+)$")
    if id then return "rbxassetid://" .. id end
    local lv = v:lower()
    if HAS_FILES and typeof(getcustomasset) == "function" and not v:find("..", 1, true) and v:match("^[%w%._%-/ ]+$")
        and (lv:match("%.png$") or lv:match("%.jpe?g$") or lv:match("%.webp$")) then
        local okf, exists = pcall(isfile, v)
        if okf and exists then
            local oka, asset = pcall(getcustomasset, v)
            if oka and type(asset) == "string" and asset ~= "" then return asset end
        end
    end
    return nil
end
local artId
do
    local okc, json = pcall(readStoredConfig)
    if okc and json then
        local okd, d = pcall(HttpService.JSONDecode, HttpService, json)
        if okd and type(d) == "table" and type(d.state) == "table" then artId = parseArt(d.state.loading_art) end
    end
end

local boot = new("CanvasGroup", { Name = "CazielxBoot", Size = UDim2.fromScale(1, 1), BackgroundColor3 = "Bg", BorderSizePixel = 0,
    ZIndex = 300, GroupTransparency = 1 }, gui)
local art = new("ImageLabel", { Name = "Artwork", AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5), Size = UDim2.fromScale(1.04, 1.04),
    BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, Image = artId or "", ImageTransparency = 1, BorderSizePixel = 0, ZIndex = 1 }, boot)
UI.bootArt = art

local fbRing = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .4), Size = UDim2.fromOffset(150, 150),
    BackgroundColor3 = "Accent", BackgroundTransparency = .9, BorderSizePixel = 0, ZIndex = 1 }, boot)
round(fbRing, 75)
local bootLogo = CreateIcon("logo", 64, boot, { AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .4), ZIndex = 2 })
SetIconState(bootLogo, "active")

local particles = {}
for i = 1, 18 do
    local depth = math.random()
    local sz = 2 + math.floor(depth * 3 + .5)
    local f = new("Frame", { Size = UDim2.fromOffset(sz, sz), AnchorPoint = Vector2.new(.5, .5), BackgroundColor3 = "Accent",
        BackgroundTransparency = .55 + (1 - depth) * .35, BorderSizePixel = 0, ZIndex = 2 }, boot)
    round(f, sz)
    particles[i] = { f = f, x = math.random(), y = math.random(), speed = .02 + depth * .05, sway = math.random() * 6.28, amp = .004 + depth * .01 }
end

local lightFrame = new("Frame", { AnchorPoint = Vector2.new(.5, .5), Size = UDim2.new(0, 160, 2.4, 0), Position = UDim2.fromScale(-.3, .5), Rotation = 16,
    BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 }, boot)
new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(.5, .93), NumberSequenceKeypoint.new(1, 1) }) }, lightFrame)
local lightTw = TweenService:Create(lightFrame, TweenInfo.new(3.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, .6), { Position = UDim2.fromScale(1.3, .5) })
Root.add(function() lightTw:Cancel() end)
lightTw:Play()

local shade = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4 }, boot)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .88), NumberSequenceKeypoint.new(.55, .72), NumberSequenceKeypoint.new(1, .12) }) }, shade)

local info = new("Frame", { AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -18), Size = UDim2.new(.86, 0, 0, 112),
    BackgroundTransparency = 1, ZIndex = 5 }, boot)
new("UISizeConstraint", { MaxSize = Vector2.new(460, 112) }, info)
text(info, APP_NAME, 26, "Text", true, { Size = UDim2.new(1, 0, 0, 30) })
text(info, EDITION .. "  |  v" .. VERSION .. "  |  Build " .. BUILD, 10, "Sub", false, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 14) })
local bootStatus = text(info, "Initializing Core", 12, T.Text, false, { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, -60, 0, 18) })
local bootPct = text(info, "0%", 12, "Accent", true, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 54), Size = UDim2.fromOffset(56, 18), TextXAlignment = Enum.TextXAlignment.Right })
local bootTrack = new("Frame", { Position = UDim2.fromOffset(0, 78), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = "Off", BorderSizePixel = 0 }, info)
round(bootTrack, 2)
local bootFill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = "Accent", BorderSizePixel = 0 }, bootTrack)
round(bootFill, 2)
local bootStage = text(info, "STAGE 0 / 0", 9, "Sub", true, { Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 14) })

local shownP, targetP, lastPct = 0, 0, -1
local bootT0 = os.clock()
local sweep = RunService.Heartbeat:Connect(function(dt)
    shownP += (targetP - shownP) * math.min(1, dt * 7)
    bootFill.Size = UDim2.new(math.clamp(shownP, 0, 1), 0, 1, 0)
    local pct = math.floor(shownP * 100 + .5)
    if pct ~= lastPct then lastPct = pct bootPct.Text = pct .. "%" end
    local t = os.clock() - bootT0
    for _, p in ipairs(particles) do
        p.y -= p.speed * dt
        if p.y < -.05 then p.y = 1.05 p.x = math.random() end
        p.f.Position = UDim2.fromScale(p.x + math.sin(t * .8 + p.sway) * p.amp, p.y)
    end
    art.Position = UDim2.new(.5, math.sin(t * .35) * 6, .5, math.cos(t * .27) * 4)
end)
Root.add(sweep)

info.Position = UDim2.new(.5, 0, 1, -2)
tween(boot, .4, { GroupTransparency = 0 })
tween(info, .55, { Position = UDim2.new(.5, 0, 1, -18) }, Enum.EasingStyle.Quint)

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
    for _, n in ipairs({ "Players", "RunService", "UserInputService", "TweenService", "Lighting", "TeleportService", "HttpService", "GuiService", "Stats", "VirtualUser", "ReplicatedStorage", "ContentProvider" }) do
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
stage("Loading Artwork", function()
    if not artId then return "SKIPPED", "no loading artwork configured" end
    local done = false
    task.spawn(function()
        pcall(function() ContentProvider:PreloadAsync({ art }) end)
        done = true
    end)
    local waited = 0
    while not done and waited < 4 do waited += task.wait(.05) end
    assert(done, "Artwork did not finish loading in 4s (check the asset ID)")
    assert(art.IsLoaded, "Artwork could not be loaded (asset ID invalid or not accessible)")
    tween(art, .7, { ImageTransparency = 0 }, Enum.EasingStyle.Quint)
    tween(fbRing, .4, { BackgroundTransparency = 1 })
    if bootLogo then DestroyIcon(bootLogo) bootLogo = nil end
end)
stage("Initializing Theme Engine", function()
    computeTheme()
    assert(T.Accent and T.Bg and T.Panel, "Theme tokens incomplete")
    assert(PRESETS[S.theme_preset or "Obsidian Dark"], "Unknown theme preset")
    applyTheme(false)
end)
stage("Loading Configuration", function()
    local json = readStoredConfig()
    if not json then return "SKIPPED", "no stored configuration (defaults used)" end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    assert(ok and type(data) == "table", "Stored configuration is corrupt")
    pendingConfig = data
    preloadTheme(data)
end)
stage("Loading Webhook", function()
    local ok, why = whLoad()
    if not ok and why ~= "No saved webhook found" and why ~= "No file API in this environment" then error(why) end
end)
stage("Building Interface", function()
    buildInterface()
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
    if S.wh_enable then
        whEvent("CAZIELX ARCHX online", "The hub finished loading.", "good", {
            { name = "Player", value = Player.DisplayName, inline = true },
            { name = "Game", value = game.Name ~= "" and game.Name or tostring(game.PlaceId), inline = true },
        })
    end
end)

local DIAG = { stages = {}, t0 = os.clock() }
_G.CAZX_DIAG = DIAG
local function diag(name, status, why)
    DIAG.stages[#DIAG.stages + 1] = { name = name, status = status, why = why, at = os.clock() - DIAG.t0 }
    local line = ("[CAZX][%s] %s%s"):format(status, name, why and (" :: " .. tostring(why)) or "")
    if status == "FAILED" then warn(line) else print(line) end
end

local total = #stages
for i, st in ipairs(stages) do
    bootStatus.TextColor3 = T.Text
    bootStatus.Text = st[1]
    bootStage.Text = ("STAGE %d / %d"):format(i, total)
    diag(st[1], "STARTING")
    local ok, err, why = xpcall(st[2], function(e) return tostring(e) .. "\n" .. debug.traceback("", 2) end)
    if ok and err == "SKIPPED" then
        diag(st[1], "SKIPPED", why)
    elseif ok then
        diag(st[1], "SUCCESS")
    else
        diag(st[1], "FAILED", err)
    end
    if not ok then
        bootWarn(st[1], err)
        bootStatus.TextColor3 = T.Bad
        bootStatus.Text = "Error: " .. st[1]
        task.wait(.45)
    end
    targetP = i / total
    task.wait(.06)
end

if not UI.win then
    diag("Main Interface", "FAILED", "window was never created")
    bootStatus.Text = "Interface failed to build. See output."
    task.wait(5)
else
    targetP = 1
    local w = 0
    while shownP < .985 and w < 1 do w += task.wait() end
    bootStatus.TextColor3 = bootWarnings > 0 and T.Warn or T.Good
    bootStatus.Text = bootWarnings > 0 and ("Ready with " .. bootWarnings .. " warning(s)") or "Ready"
    task.wait(.25)
    UI.openWindow()
    diag("Main Interface", "SUCCESS", ("opened in %.2fs, %d warning(s)"):format(os.clock() - DIAG.t0, bootWarnings))
    if bootWarnings > 0 then notify(bootLog[1], "warn", 6) end
end

tween(boot, .45, { GroupTransparency = 1 })
tween(art, .45, { Size = UDim2.fromScale(1.1, 1.1) }, Enum.EasingStyle.Quint)
task.wait(.5)
sweep:Disconnect()
lightTw:Cancel()
if bootLogo then DestroyIcon(bootLogo) bootLogo = nil end
if boot.Parent then boot:Destroy() end

end -- scope block