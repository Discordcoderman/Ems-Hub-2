-- ui.lua — compact HUD matched to reference layout
--   · top status + waiting + stat strip
--   · combat block (mastery bar + mob HP)
--   · 7-button control row
--   · next-melee tracker
--   · 2-column inventory grid
--   · bottom toggle bar
--   · big E toggle top-left, idle hover at Y = 952, anti-lag
local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

local Players       = Spirit.Players
local RunService    = Spirit.RunService
local CoreGui       = Spirit.CoreGui
local LocalPlayer   = Spirit.LocalPlayer
local Lighting      = Spirit.Services.Lighting
local ScriptStorage = Spirit.ScriptStorage

for _, container in ipairs({CoreGui, LocalPlayer:FindFirstChild("PlayerGui")}) do
    if container then
        pcall(function()
            local old = container:FindFirstChild("EmsHubUI")
            if old then old:Destroy() end
        end)
    end
end

local EmsUI = {Instances = {}, Config = {AntiLag = true, IdleHeight = 952}}
Spirit.EmsUI = EmsUI

-- ── Palette ────────────────────────────────────────────────────
local C = {
    bg        = Color3.fromRGB(10, 10, 14),
    panel     = Color3.fromRGB(20, 20, 26),
    panelSoft = Color3.fromRGB(32, 32, 40),
    track     = Color3.fromRGB(46, 46, 54),
    line      = Color3.fromRGB(52, 52, 62),
    text      = Color3.fromRGB(242, 242, 246),
    textDim   = Color3.fromRGB(168, 168, 178),
    textFaint = Color3.fromRGB(112, 112, 124),
    brand     = Color3.fromRGB(186, 108, 240),
    brandHot  = Color3.fromRGB(232, 140, 255),
    green     = Color3.fromRGB(86, 200, 86),
    greenSoft = Color3.fromRGB(120, 220, 120),
    gold      = Color3.fromRGB(232, 190, 82),
    red       = Color3.fromRGB(220, 72, 72),
    redSoft   = Color3.fromRGB(240, 100, 100),
    blue      = Color3.fromRGB(102, 176, 255),
    shadow    = Color3.fromRGB(0, 0, 0),
}

local FONT_LABEL = Enum.Font.Gotham
local FONT_MED   = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_BRAND = Enum.Font.GothamBlack
local FONT_VALUE = Enum.Font.RobotoMono
local FONT_CODE  = Enum.Font.Code

local function corner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 4)
    return c
end
local function stroke(parent, col, thickness)
    local s = Instance.new("UIStroke", parent)
    s.Color = col or C.line
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end
local function shortNum(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM", n / 1e6) end
    if n >= 1e5 then return string.format("%.1fK", n / 1e3) end
    if n >= 1e3 then return tostring(math.floor(n)) end
    return tostring(math.floor(n))
end
local function commaNum(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return out
end

-- ── Root ───────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "EmsHubUI"
gui.Parent         = CoreGui
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 100
gui.IgnoreGuiInset = true
EmsUI.ScreenGui = gui

-- ═══════════════════════════════════════════════════════════════
-- BIG E TOGGLE — top-left
-- ═══════════════════════════════════════════════════════════════
local eBtn = Instance.new("TextButton")
eBtn.Name             = "EmsEButton"
eBtn.Parent           = gui
eBtn.Position         = UDim2.new(0, 20, 0, 20)
eBtn.Size             = UDim2.new(0, 56, 0, 56)
eBtn.BackgroundColor3 = C.bg
eBtn.Text             = "E"
eBtn.Font             = FONT_BRAND
eBtn.TextSize         = 30
eBtn.TextColor3       = C.brandHot
eBtn.BorderSizePixel  = 0
eBtn.AutoButtonColor  = false
eBtn.Active           = true
eBtn.Draggable        = true
eBtn.ZIndex           = 50
corner(eBtn, 28)
local eStroke = Instance.new("UIStroke", eBtn)
eStroke.Color = C.brand
eStroke.Thickness = 2
eStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

eBtn.MouseEnter:Connect(function()
    eBtn.BackgroundColor3 = C.panel
    eBtn.TextColor3 = C.text
end)
eBtn.MouseLeave:Connect(function()
    eBtn.BackgroundColor3 = C.bg
    eBtn.TextColor3 = C.brandHot
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN PANEL
-- ═══════════════════════════════════════════════════════════════
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Parent           = gui
panel.AnchorPoint      = Vector2.new(0.5, 0)
panel.Position         = UDim2.new(0.5, 0, 0, 20)
panel.Size             = UDim2.new(0, 560, 0, 490)
panel.BackgroundColor3 = C.bg
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel  = 0
panel.Active           = true
panel.Draggable        = true
corner(panel, 6)
stroke(panel, C.line)
EmsUI.Panel = panel

-- ── Layout constants ─────────────────────────────────────────
local PAD      = 10
local W        = 560
local CONTENTW = W - PAD * 2

-- ── Helper: section divider ──────────────────────────────────
local function divider(y)
    local d = Instance.new("Frame")
    d.Parent = panel
    d.Position = UDim2.new(0, PAD, 0, y)
    d.Size = UDim2.new(1, -PAD * 2, 0, 1)
    d.BackgroundColor3 = C.line
    d.BackgroundTransparency = 0.4
    d.BorderSizePixel = 0
end

-- ── Helper: thin track bar ───────────────────────────────────
local function makeBar(y, h, fillColor, textLeft, textRight)
    local wrap = Instance.new("Frame")
    wrap.Parent = panel
    wrap.Position = UDim2.new(0, PAD, 0, y)
    wrap.Size = UDim2.new(1, -PAD * 2, 0, h)
    wrap.BackgroundColor3 = C.track
    wrap.BorderSizePixel = 0
    wrap.ClipsDescendants = true
    corner(wrap, h / 2)

    local fill = Instance.new("Frame")
    fill.Parent = wrap
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = fillColor
    fill.BorderSizePixel = 0
    corner(fill, h / 2)

    local lblL = Instance.new("TextLabel")
    lblL.Parent = wrap
    lblL.BackgroundTransparency = 1
    lblL.Position = UDim2.new(0, 10, 0, 0)
    lblL.Size = UDim2.new(0.5, -10, 1, 0)
    lblL.Text = textLeft or ""
    lblL.Font = FONT_BOLD
    lblL.TextSize = math.max(10, h - 4)
    lblL.TextColor3 = C.text
    lblL.TextXAlignment = Enum.TextXAlignment.Left
    lblL.ZIndex = 2

    local lblR = Instance.new("TextLabel")
    lblR.Parent = wrap
    lblR.BackgroundTransparency = 1
    lblR.Position = UDim2.new(0.5, 0, 0, 0)
    lblR.Size = UDim2.new(0.5, -10, 1, 0)
    lblR.Text = textRight or ""
    lblR.Font = FONT_BOLD
    lblR.TextSize = math.max(10, h - 4)
    lblR.TextColor3 = C.text
    lblR.TextXAlignment = Enum.TextXAlignment.Right
    lblR.ZIndex = 2

    return wrap, fill, lblL, lblR
end

-- ═══════════════════════════════════════════════════════════════
-- STATUS ROW — green dot + task text
-- ═══════════════════════════════════════════════════════════════
local statusDot = Instance.new("Frame")
statusDot.Parent = panel
statusDot.Position = UDim2.new(0, PAD + 4, 0, 12)
statusDot.Size = UDim2.new(0, 10, 0, 10)
statusDot.BackgroundColor3 = C.green
statusDot.BorderSizePixel = 0
corner(statusDot, 5)

local statusLbl = Instance.new("TextLabel")
statusLbl.Parent = panel
statusLbl.BackgroundTransparency = 1
statusLbl.Position = UDim2.new(0, PAD + 22, 0, 8)
statusLbl.Size = UDim2.new(1, -PAD * 2 - 22, 0, 18)
statusLbl.Text = "Auto Farm Level | Attacking mob"
statusLbl.Font = FONT_BOLD
statusLbl.TextSize = 15
statusLbl.TextColor3 = C.text
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.StatusLabel = statusLbl

-- ── Waiting line ─────────────────────────────────────────────
local waitLbl = Instance.new("TextLabel")
waitLbl.Parent = panel
waitLbl.BackgroundTransparency = 1
waitLbl.Position = UDim2.new(0, PAD, 0, 28)
waitLbl.Size = UDim2.new(1, -PAD * 2, 0, 18)
waitLbl.Text = "Waiting —"
waitLbl.Font = FONT_BOLD
waitLbl.TextSize = 15
waitLbl.TextColor3 = C.gold
waitLbl.TextXAlignment = Enum.TextXAlignment.Center
waitLbl.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.WaitLabel = waitLbl

-- ── Stats strip ──────────────────────────────────────────────
local statsRow = Instance.new("Frame")
statsRow.Parent = panel
statsRow.Position = UDim2.new(0, PAD, 0, 48)
statsRow.Size = UDim2.new(1, -PAD * 2, 0, 18)
statsRow.BackgroundTransparency = 1

local statLabels = {}
local statKeys = {"LV", "FRAG", "BELI", "FPS", "TIME"}
for i, key in ipairs(statKeys) do
    local cell = Instance.new("Frame")
    cell.Parent = statsRow
    cell.Position = UDim2.new((i - 1) / 5, 0, 0, 0)
    cell.Size = UDim2.new(1 / 5, 0, 1, 0)
    cell.BackgroundTransparency = 1

    local k = Instance.new("TextLabel")
    k.Parent = cell
    k.BackgroundTransparency = 1
    k.Position = UDim2.new(0, 0, 0, 0)
    k.Size = UDim2.new(0, 40, 1, 0)
    k.Text = key
    k.Font = FONT_BOLD
    k.TextSize = 13
    k.TextColor3 = C.green
    k.TextXAlignment = Enum.TextXAlignment.Left

    local v = Instance.new("TextLabel")
    v.Parent = cell
    v.BackgroundTransparency = 1
    v.Position = UDim2.new(0, 40, 0, 0)
    v.Size = UDim2.new(1, -40, 1, 0)
    v.Text = "—"
    v.Font = FONT_BOLD
    v.TextSize = 13
    v.TextColor3 = C.text
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextTruncate = Enum.TextTruncate.AtEnd

    statLabels[key] = v
end

divider(72)

-- ═══════════════════════════════════════════════════════════════
-- COMBAT BLOCK
-- ═══════════════════════════════════════════════════════════════
local combatHeader = Instance.new("TextLabel")
combatHeader.Parent = panel
combatHeader.BackgroundTransparency = 1
combatHeader.Position = UDim2.new(0, PAD, 0, 80)
combatHeader.Size = UDim2.new(1, -PAD * 2, 0, 16)
combatHeader.Text = "Combat                       0 / 400"
combatHeader.Font = FONT_BOLD
combatHeader.TextSize = 13
combatHeader.TextColor3 = C.text
combatHeader.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.CombatHeader = combatHeader

local combatText = Instance.new("TextLabel")
combatText.Parent = panel
combatText.BackgroundTransparency = 1
combatText.Position = UDim2.new(0.5, 0, 0, 80)
combatText.Size = UDim2.new(0.5, -PAD, 0, 16)
combatText.Text = "0 / 400"
combatText.Font = FONT_BOLD
combatText.TextSize = 13
combatText.TextColor3 = C.text
combatText.TextXAlignment = Enum.TextXAlignment.Right

local _, combatFill, _, combatR = makeBar(98, 14, C.red, "", "0 / 400")
EmsUI.CombatFill = combatFill
EmsUI.CombatText = combatR

local mobRow = Instance.new("Frame")
mobRow.Parent = panel
mobRow.Position = UDim2.new(0, PAD, 0, 118)
mobRow.Size = UDim2.new(1, -PAD * 2, 0, 16)
mobRow.BackgroundTransparency = 1

local mobName = Instance.new("TextLabel")
mobName.Parent = mobRow
mobName.BackgroundTransparency = 1
mobName.Size = UDim2.new(0.5, 0, 1, 0)
mobName.Position = UDim2.new(0, 0, 0, 0)
mobName.Text = "—"
mobName.Font = FONT_BOLD
mobName.TextSize = 13
mobName.TextColor3 = C.text
mobName.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.MobName = mobName

local mobHp = Instance.new("TextLabel")
mobHp.Parent = mobRow
mobHp.BackgroundTransparency = 1
mobHp.Size = UDim2.new(0.5, 0, 1, 0)
mobHp.Position = UDim2.new(0.5, 0, 0, 0)
mobHp.Text = "0 / 0"
mobHp.Font = FONT_BOLD
mobHp.TextSize = 13
mobHp.TextColor3 = C.textDim
mobHp.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.MobHp = mobHp

divider(140)

-- ═══════════════════════════════════════════════════════════════
-- BUTTON ROW — 7 buttons
-- ═══════════════════════════════════════════════════════════════
local btnRow = Instance.new("Frame")
btnRow.Parent = panel
btnRow.Position = UDim2.new(0, PAD, 0, 152)
btnRow.Size = UDim2.new(1, -PAD * 2, 0, 26)
btnRow.BackgroundTransparency = 1

local BTN_LABELS = {
    "PASTE JOBID TO JOIN",
    "HIDE",
    "3D OFF",
    "HOP",
    "REJOIN",
    "COPY ID",
    "STOP",
}
local BTN_RED_IDX = {[3] = true, [7] = true}

local BUTTONS = {}
for i, lbl in ipairs(BTN_LABELS) do
    local w = (i == 1) and 0.26 or 0.1233
    local x = (i == 1) and 0 or (0.26 + (i - 2) * 0.1233)
    local b = Instance.new("TextButton")
    b.Parent = btnRow
    b.Position = UDim2.new(x, 0, 0, 0)
    b.Size = UDim2.new(w, -3, 1, 0)
    b.BackgroundColor3 = C.panelSoft
    b.Text = lbl
    b.Font = FONT_BOLD
    b.TextSize = 10
    b.TextColor3 = C.text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    corner(b, 4)

    -- 3D OFF gets red "3D" span in reference. We split text into two
    -- labels for that one.
    if BTN_RED_IDX[i] then
        b.Text = ""
        local pre = Instance.new("TextLabel")
        pre.Parent = b
        pre.BackgroundTransparency = 1
        pre.Position = UDim2.new(0, 0, 0, 0)
        pre.Size = UDim2.new(0.55, 0, 1, 0)
        pre.Text = (i == 3) and "" or lbl:sub(1, 4)
        pre.Font = FONT_BOLD
        pre.TextSize = 10
        pre.TextColor3 = C.text
        pre.TextXAlignment = Enum.TextXAlignment.Right

        local red = Instance.new("TextLabel")
        red.Parent = b
        red.BackgroundTransparency = 1
        red.Position = UDim2.new(0.55, 0, 0, 0)
        red.Size = UDim2.new(0.45, 0, 1, 0)
        red.Text = (i == 3) and "3D" or lbl:sub(5)
        red.Font = FONT_BOLD
        red.TextSize = 10
        red.TextColor3 = C.red
        red.TextXAlignment = Enum.TextXAlignment.Left

        if i == 3 then
            pre.Text = ""
            red.Text = "3D"
            red.Position = UDim2.new(0, 0, 0, 0)
            red.Size = UDim2.new(0.55, 0, 1, 0)
            red.TextXAlignment = Enum.TextXAlignment.Center
            local off = Instance.new("TextLabel")
            off.Parent = b
            off.BackgroundTransparency = 1
            off.Position = UDim2.new(0.55, 0, 0, 0)
            off.Size = UDim2.new(0.45, 0, 1, 0)
            off.Text = "OFF"
            off.Font = FONT_BOLD
            off.TextSize = 10
            off.TextColor3 = C.text
            off.TextXAlignment = Enum.TextXAlignment.Left
        end
    end

    BUTTONS[i] = b
end

-- Button wiring
BUTTONS[1].MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then setclipboard(game.JobId) end
    end)
end)
BUTTONS[2].MouseButton1Click:Connect(function()
    panel.Visible = false
end)
BUTTONS[3].MouseButton1Click:Connect(function()
    if EmsUI.Config.AntiLag then
        EmsUI.Config.AntiLag = false
    else
        EmsUI.EnableAntiLag()
    end
end)
BUTTONS[4].MouseButton1Click:Connect(function()
    pcall(function() Spirit.Hop() end)
end)
BUTTONS[5].MouseButton1Click:Connect(function()
    pcall(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end)
end)
BUTTONS[6].MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then setclipboard(game.JobId) end
    end)
end)
BUTTONS[7].MouseButton1Click:Connect(function()
    _G.Stop = true
    pcall(function()
        if Spirit.SetTask then Spirit.SetTask("MainTask", "Stopped") end
    end)
end)

divider(190)

-- ═══════════════════════════════════════════════════════════════
-- NEXT MELEE
-- ═══════════════════════════════════════════════════════════════
local nextMeleeHeader = Instance.new("TextLabel")
nextMeleeHeader.Parent = panel
nextMeleeHeader.BackgroundTransparency = 1
nextMeleeHeader.Position = UDim2.new(0, PAD, 0, 200)
nextMeleeHeader.Size = UDim2.new(1, -PAD * 2, 0, 16)
nextMeleeHeader.Text = "NEXT MELEE"
nextMeleeHeader.Font = FONT_BOLD
nextMeleeHeader.TextSize = 12
nextMeleeHeader.TextColor3 = C.text
nextMeleeHeader.TextXAlignment = Enum.TextXAlignment.Center

local nextMeleeName = Instance.new("TextLabel")
nextMeleeName.Parent = panel
nextMeleeName.BackgroundTransparency = 1
nextMeleeName.Position = UDim2.new(0, PAD, 0, 218)
nextMeleeName.Size = UDim2.new(1, -PAD * 2, 0, 18)
nextMeleeName.Text = "—"
nextMeleeName.Font = FONT_BOLD
nextMeleeName.TextSize = 15
nextMeleeName.TextColor3 = C.gold
nextMeleeName.TextXAlignment = Enum.TextXAlignment.Center
EmsUI.NextMeleeName = nextMeleeName

local _, nextMeleeFill, _, nextMeleeTxt = makeBar(240, 16, C.track, "", "Beli 0 / 0")
-- override fill to the visible grey "in-progress" style: swap in a
-- darker fill drawn under the text, plus a lighter track
nextMeleeFill.BackgroundColor3 = C.panelSoft
nextMeleeTxt.Font = FONT_BOLD
nextMeleeTxt.TextSize = 12
EmsUI.NextMeleeFill = nextMeleeFill
EmsUI.NextMeleeTxt = nextMeleeTxt

divider(266)

-- ═══════════════════════════════════════════════════════════════
-- INVENTORY GRID — 2 columns
-- ═══════════════════════════════════════════════════════════════
local invHeader = Instance.new("TextLabel")
invHeader.Parent = panel
invHeader.BackgroundTransparency = 1
invHeader.Position = UDim2.new(0, PAD, 0, 276)
invHeader.Size = UDim2.new(1, -PAD * 2, 0, 16)
invHeader.Text = "INVENTORY"
invHeader.Font = FONT_BOLD
invHeader.TextSize = 12
invHeader.TextColor3 = C.text
invHeader.TextXAlignment = Enum.TextXAlignment.Center

local INV_LEFT  = {"Cursed Dual Katana", "Soul Guitar", "Shark Anchor", "Elite"}
local INV_RIGHT = {"Mirror Fractal", "Valkyrie Helm", "Dark Dagger", "Tushita"}
local invLabels = {left = {}, right = {}}

local function makeInvRow(parent, y, name, key)
    local row = Instance.new("Frame")
    row.Parent = parent
    row.Position = UDim2.new(0, 0, 0, y)
    row.Size = UDim2.new(1, 0, 0, 18)
    row.BackgroundTransparency = 1

    local dot = Instance.new("Frame")
    dot.Parent = row
    dot.Position = UDim2.new(0, 4, 0.5, -4)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.BackgroundColor3 = C.red
    dot.BorderSizePixel = 0
    corner(dot, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Parent = row
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 20, 0, 0)
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.Text = name
    lbl.Font = FONT_BOLD
    lbl.TextSize = 13
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    return dot, lbl
end

local invLeftCol = Instance.new("Frame")
invLeftCol.Parent = panel
invLeftCol.Position = UDim2.new(0, PAD + 10, 0, 298)
invLeftCol.Size = UDim2.new(0.5, -PAD - 10, 0, 76)
invLeftCol.BackgroundTransparency = 1

local invRightCol = Instance.new("Frame")
invRightCol.Parent = panel
invRightCol.Position = UDim2.new(0.5, 0, 0, 298)
invRightCol.Size = UDim2.new(0.5, -PAD, 0, 76)
invRightCol.BackgroundTransparency = 1

for i, name in ipairs(INV_LEFT) do
    local dot, lbl = makeInvRow(invLeftCol, (i - 1) * 20, name, name)
    invLabels.left[name] = {dot = dot, lbl = lbl}
end
for i, name in ipairs(INV_RIGHT) do
    local dot, lbl = makeInvRow(invRightCol, (i - 1) * 20, name, name)
    invLabels.right[name] = {dot = dot, lbl = lbl}
end

-- ═══════════════════════════════════════════════════════════════
-- BOTTOM BAR — Random Fruit toggle + Bones + Unavailable + CD
-- ═══════════════════════════════════════════════════════════════
local bottomBar = Instance.new("Frame")
bottomBar.Parent = panel
bottomBar.Position = UDim2.new(0, PAD, 0, 386)
bottomBar.Size = UDim2.new(1, -PAD * 2, 0, 90)
bottomBar.BackgroundTransparency = 1

-- Random Fruit toggle
local fruitToggle = Instance.new("TextButton")
fruitToggle.Parent = bottomBar
fruitToggle.Position = UDim2.new(0, 0, 0, 0)
fruitToggle.Size = UDim2.new(0, 150, 0, 26)
fruitToggle.BackgroundColor3 = C.panelSoft
fruitToggle.Text = "Random Fruit"
fruitToggle.Font = FONT_BOLD
fruitToggle.TextSize = 13
fruitToggle.TextColor3 = C.text
fruitToggle.BorderSizePixel = 0
fruitToggle.AutoButtonColor = false
corner(fruitToggle, 4)

-- Bones counter
local bonesLbl = Instance.new("TextLabel")
bonesLbl.Parent = bottomBar
bonesLbl.BackgroundTransparency = 1
bonesLbl.Position = UDim2.new(0, 0, 0, 30)
bonesLbl.Size = UDim2.new(0, 150, 0, 20)
bonesLbl.Text = "Bones 0"
bonesLbl.Font = FONT_BOLD
bonesLbl.TextSize = 14
bonesLbl.TextColor3 = C.text
bonesLbl.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.BonesLabel = bonesLbl

-- Unavailable
local unavailLbl = Instance.new("TextLabel")
unavailLbl.Parent = bottomBar
unavailLbl.BackgroundTransparency = 1
unavailLbl.Position = UDim2.new(0.5, 0, 0, 0)
unavailLbl.Size = UDim2.new(0.5, 0, 0, 20)
unavailLbl.Text = "Unavailable"
unavailLbl.Font = FONT_BOLD
unavailLbl.TextSize = 15
unavailLbl.TextColor3 = C.red
unavailLbl.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.UnavailLabel = unavailLbl

-- CD line
local cdLbl = Instance.new("TextLabel")
cdLbl.Parent = bottomBar
cdLbl.BackgroundTransparency = 1
cdLbl.Position = UDim2.new(0.5, 0, 0, 26)
cdLbl.Size = UDim2.new(0.5, 0, 0, 20)
cdLbl.Text = "0 | CD --:--"
cdLbl.Font = FONT_VALUE
cdLbl.TextSize = 14
cdLbl.TextColor3 = C.text
cdLbl.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.CDLabel = cdLbl

-- ── Toggle wiring ────────────────────────────────────────────
local panelVisible = true
local function setPanelVisible(v)
    panelVisible = v
    panel.Visible = v
end
eBtn.MouseButton1Click:Connect(function() setPanelVisible(not panelVisible) end)

-- ═══════════════════════════════════════════════════════════════
-- MELEE HELPERS
-- ═══════════════════════════════════════════════════════════════
local function currentTrainingMelee()
    local order = Spirit.MASTERY_TRAIN_ORDER or {}
    local owned = ScriptStorage.Melees or {}
    for _, entry in ipairs(order) do
        local m = owned[entry.name]
        if m and m < entry.target then return entry, m end
    end
    return nil, nil
end

local function nextUnboughtMelee()
    local order = Spirit.MASTERY_TRAIN_ORDER or {}
    local owned = ScriptStorage.Melees or {}
    for _, entry in ipairs(order) do
        if not owned[entry.name] then return entry end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI-LAG
-- ═══════════════════════════════════════════════════════════════
local function stripInstance(obj)
    if not obj or not obj.Parent then return end
    if obj:IsA("BasePart") then
        obj.Material = Enum.Material.Plastic
        obj.Reflectance = 0
        obj.CastShadow = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail")
        or obj:IsA("Beam") or obj:IsA("Fire")
        or obj:IsA("Smoke") or obj:IsA("Sparkles") then
        obj.Enabled = false
    elseif obj:IsA("Sound") then
        obj.Volume = 0
        obj.Playing = false
    end
end

function EmsUI.EnableAntiLag()
    EmsUI.Config.AntiLag = true
    pcall(function()
        Lighting.GlobalShadows  = false
        Lighting.Brightness     = 1
        Lighting.Ambient        = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.FogEnd         = 100000
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") or e:IsA("Sky") then
                pcall(function() e.Enabled = false end)
            elseif e:IsA("Atmosphere") then
                e.Density = 0
                e.Haze = 0
            end
        end
    end)
    pcall(function()
        if settings and settings().Rendering then
            settings().Rendering.QualityLevel        = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end
    end)
    pcall(function()
        local t = workspace.Terrain
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
        t.WaterTransparency = 1
    end)
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(stripInstance, obj)
    end
    if not EmsUI._antiLagHooked then
        EmsUI._antiLagHooked = true
        workspace.DescendantAdded:Connect(function(obj)
            if not EmsUI.Config.AntiLag then return end
            if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture")
                or obj:IsA("ParticleEmitter") or obj:IsA("Trail")
                or obj:IsA("Beam") or obj:IsA("Fire")
                or obj:IsA("Smoke") or obj:IsA("Sparkles")
                or obj:IsA("Sound") then
                pcall(stripInstance, obj)
            end
        end)
    end
end
pcall(EmsUI.EnableAntiLag)

-- ═══════════════════════════════════════════════════════════════
-- IDLE HOVER — Y = 952
-- ═══════════════════════════════════════════════════════════════
local function engageIdleHover()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if Spirit._idleBP and Spirit._idleBP.Parent == hrp then
        Spirit._idleBP.Position = Vector3.new(hrp.Position.X, EmsUI.Config.IdleHeight, hrp.Position.Z)
        return
    end
    if Spirit._idleBP then pcall(function() Spirit._idleBP:Destroy() end); Spirit._idleBP = nil end
    local bp = Instance.new("BodyPosition")
    bp.Name = "EmsIdleHover"
    bp.MaxForce = Vector3.new(1e4, 2e5, 1e4)
    bp.P = 8000
    bp.D = 400
    bp.Position = Vector3.new(hrp.Position.X, EmsUI.Config.IdleHeight, hrp.Position.Z)
    bp.Parent = hrp
    Spirit._idleBP = bp
end
local function releaseIdleHover()
    if Spirit._idleBP then pcall(function() Spirit._idleBP:Destroy() end); Spirit._idleBP = nil end
end

task.spawn(function()
    local idleStreak = 0
    while task.wait(1) do
        pcall(function()
            local t = ScriptStorage.Task or {}
            local mainTask = t.MainTask or ""
            local transitioning = _G.SeaTransitionActive or _G.SkyTransitionActive or _G.FruitPriorityActive
            local isIdle = (mainTask == "Idle") and not transitioning
            if isIdle then idleStreak = idleStreak + 1 else idleStreak = 0 end
            if idleStreak >= 2 then engageIdleHover() else releaseIdleHover() end
        end)
    end
end)
LocalPlayer.CharacterAdded:Connect(function() Spirit._idleBP = nil end)

-- ═══════════════════════════════════════════════════════════════
-- SetText bridge
-- ═══════════════════════════════════════════════════════════════
function EmsUI.SetText(key, text)
    pcall(function()
        if not text then return end
        text = tostring(text):gsub("<[^>]->", "")
        if key == "MainTextLabel" or key == "Task1" or key == "DebugLine" then
            local v = text:match("^MainTask%s*:%s*(.+)$") or text
            statusLbl.Text = v
        elseif key == "Task2" then
            -- SubTask not surfaced in this layout; reserved
        end
    end)
end
function EmsUI.SetStatus(text)
    if not text then return end
    statusLbl.Text = tostring(text):gsub("<[^>]->", "")
end
function EmsUI.SetSubStatus(_) end
function EmsUI.SetRedeemStatus(_) end
function EmsUI.Toggle() setPanelVisible(not panelVisible) end
function EmsUI.SetStats(_) end

-- ═══════════════════════════════════════════════════════════════
-- FPS tracking
-- ═══════════════════════════════════════════════════════════════
local fps = 60
local frameTimes = {}
RunService.RenderStepped:Connect(function(dt)
    table.insert(frameTimes, dt)
    if #frameTimes > 30 then table.remove(frameTimes, 1) end
    local sum = 0
    for _, v in ipairs(frameTimes) do sum = sum + v end
    if sum > 0 then fps = math.floor(#frameTimes / sum + 0.5) end
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN REFRESH LOOP
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local start = os.time() - (Spirit.OldSessionTime or 0)
    while task.wait(0.5) do
        pcall(function()
            local Data = LocalPlayer:FindFirstChild("Data")
            local level, beli, frag, raceName = 0, 0, 0, "—"
            if Data then
                level = Data:FindFirstChild("Level") and tonumber(Data.Level.Value) or 0
                beli  = Data:FindFirstChild("Beli")  and tonumber(Data.Beli.Value)  or 0
                frag  = Data:FindFirstChild("Fragments") and tonumber(Data.Fragments.Value) or 0
                local raceObj = Data:FindFirstChild("Race")
                if raceObj then
                    if raceObj:IsA("StringValue") then raceName = raceObj.Value
                    elseif raceObj:IsA("Folder") then
                        local v = raceObj:FindFirstChild("Value")
                        if v then raceName = v.Value end
                    end
                end
            end

            local elapsed = os.time() - start
            local eh = math.floor(elapsed / 3600)
            local em = math.floor((elapsed % 3600) / 60)

            statLabels.LV.Text = tostring(level)
            statLabels.FRAG.Text = tostring(frag)
            statLabels.BELI.Text = commaNum(beli)
            statLabels.FPS.Text = tostring(fps)
            statLabels.TIME.Text = string.format("%dh %dm", eh, em)

            -- ── Combat block ──
            local melee, mastery = currentTrainingMelee()
            if melee then
                local target = melee.target
                local ratio = math.clamp(mastery / target, 0, 1)
                combatFill.Size = UDim2.new(ratio, 0, 1, 0)
                combatR.Text = string.format("%d / %d", mastery, target)

                -- Waiting line
                local price = Spirit.MeleePrices and Spirit.MeleePrices[melee.name]
                local needBeli = price and price.Price and price.Price.Beli or 0
                if needBeli > 0 then
                    waitLbl.Text = string.format(
                        "Waiting %s / %s for %s",
                        commaNum(beli), shortNum(needBeli), melee.name)
                else
                    waitLbl.Text = string.format("Training %s — %d / %d",
                        melee.name, mastery, target)
                end
            else
                combatFill.Size = UDim2.new(1, 0, 1, 0)
                combatR.Text = "complete"
                waitLbl.Text = "All melees complete"
            end

            -- ── Mob name + HP ──
            local mon = Spirit.MonResult
            if mon and mon.Parent then
                local hum = mon:FindFirstChild("Humanoid")
                if hum then
                    mobName.Text = tostring(mon.Name)
                    mobHp.Text = string.format("%s / %s",
                        commaNum(hum.Health), commaNum(hum.MaxHealth))
                end
            else
                local t = ScriptStorage.Task or {}
                mobName.Text = t.SubTask or "—"
                mobHp.Text = ""
            end

            -- ── Next melee ──
            local nm = nextUnboughtMelee()
            if nm then
                nextMeleeName.Text = nm.name
                local price = Spirit.MeleePrices and Spirit.MeleePrices[nm.name]
                local needBeli = price and price.Price and price.Price.Beli or 0
                local haveBeli = beli
                local ratio = needBeli > 0
                    and math.clamp(haveBeli / needBeli, 0, 1) or 1
                nextMeleeFill.Size = UDim2.new(ratio, 0, 1, 0)
                nextMeleeTxt.Text = string.format("Beli %s / %s",
                    commaNum(haveBeli), shortNum(needBeli))
            else
                nextMeleeName.Text = "—"
                nextMeleeFill.Size = UDim2.new(1, 0, 1, 0)
                nextMeleeTxt.Text = "all owned"
            end

            -- ── Inventory ──
            local bp = ScriptStorage.Backpack or {}
            local function own(name)
                if name == "Elite" then return false end
                return bp[name] ~= nil
            end
            for name, ref in pairs(invLabels.left) do
                local owned = own(name)
                ref.dot.BackgroundColor3 = owned and C.green or C.red
                ref.lbl.TextColor3 = owned and C.text or C.textDim
            end
            for name, ref in pairs(invLabels.right) do
                local owned = own(name)
                ref.dot.BackgroundColor3 = owned and C.green or C.red
                ref.lbl.TextColor3 = owned and C.text or C.textDim
            end

            -- ── Bottom bar ──
            local bones = (bp["Bones"] and bp["Bones"].Count) or 0
            bonesLbl.Text = string.format("Bones %d", bones)

            local unavail = (level < 700)
            unavailLbl.Text = unavail and "Unavailable" or "Available"
            unavailLbl.TextColor3 = unavail and C.red or C.green

            local cdBase = Spirit.Config and Spirit.Config.Extras
                and Spirit.Config.Extras.CollectInterval or 0
            cdLbl.Text = string.format("%d | CD --:--", bones)
        end)
    end
end)

_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
