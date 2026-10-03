-- ui.lua — Bacon Hub reference layout, exact colours
--   · status + wait line + 5-stat strip
--   · combat bar + mob row
--   · 4-button control row (job-id buttons removed)
--   · next-melee block with Beli requirement
--   · 2-column inventory grid
--   · bottom bar: Random Fruit (live cooldown), Bones, Unavailable, CD
--   · big E toggle, no idle hover, anti-lag
local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

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

do
    local hrp = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local stale = hrp:FindFirstChild("EmsIdleHover")
        if stale then stale:Destroy() end
    end
end

local EmsUI = {Instances = {}, Config = {AntiLag = true}}
Spirit.EmsUI = EmsUI

-- ── Palette — reference-exact ────────────────────────────────
local C = {
    bg        = Color3.fromRGB(10, 10, 12),
    bgSoft    = Color3.fromRGB(18, 18, 22),
    panel     = Color3.fromRGB(28, 28, 34),
    track     = Color3.fromRGB(64, 64, 70),
    trackSoft = Color3.fromRGB(44, 44, 50),
    line      = Color3.fromRGB(48, 48, 56),
    text      = Color3.fromRGB(255, 255, 255),
    textGrey  = Color3.fromRGB(200, 200, 206),
    textDim   = Color3.fromRGB(140, 140, 148),
    textFaint = Color3.fromRGB(96, 96, 104),
    green     = Color3.fromRGB(86, 210, 86),
    gold      = Color3.fromRGB(232, 176, 56),
    red       = Color3.fromRGB(224, 64, 64),
    brand     = Color3.fromRGB(186, 108, 240),
    brandHot  = Color3.fromRGB(232, 140, 255),
}

local FONT_LABEL = Enum.Font.Gotham
local FONT_MED   = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_BRAND = Enum.Font.GothamBlack
local FONT_VALUE = Enum.Font.RobotoMono

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
local function commaNum(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if out:sub(1, 1) == "," then out = out:sub(2) end
    return out
end
-- stat display: comma under 100k, then short K/M
local function statNum(n)
    n = math.floor(tonumber(n) or 0)
    if n < 100000 then return commaNum(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    return string.format("%dK", math.floor(n / 1e3))
end
-- short display: always short (used for requirements)
local function shortNum(n)
    n = math.floor(tonumber(n) or 0)
    if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%dK", math.floor(n / 1e3)) end
    return tostring(n)
end

-- ── Root ─────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name           = "EmsHubUI"
gui.Parent         = CoreGui
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 100
gui.IgnoreGuiInset = true
EmsUI.ScreenGui = gui

-- ═══════════════════════════════════════════════════════════════
-- BIG E TOGGLE
-- ═══════════════════════════════════════════════════════════════
local eBtn = Instance.new("TextButton")
eBtn.Name             = "EmsEButton"
eBtn.Parent           = gui
eBtn.Position         = UDim2.new(0, 16, 0, 16)
eBtn.Size             = UDim2.new(0, 52, 0, 52)
eBtn.BackgroundColor3 = C.bg
eBtn.Text             = "E"
eBtn.Font             = FONT_BRAND
eBtn.TextSize         = 28
eBtn.TextColor3       = C.brandHot
eBtn.BorderSizePixel  = 0
eBtn.AutoButtonColor  = false
eBtn.Active           = true
eBtn.Draggable        = true
eBtn.ZIndex           = 50
corner(eBtn, 26)
stroke(eBtn, C.brand, 2)

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
panel.Position         = UDim2.new(0.5, 0, 0, 18)
panel.Size             = UDim2.new(0, 500, 0, 460)
panel.BackgroundColor3 = C.bg
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel  = 0
panel.Active           = true
panel.Draggable        = true
corner(panel, 4)
EmsUI.Panel = panel

-- ── Status row ────────────────────────────────────────────────
local statusDot = Instance.new("Frame")
statusDot.Parent = panel
statusDot.Position = UDim2.new(0, 16, 0, 16)
statusDot.Size = UDim2.new(0, 11, 0, 11)
statusDot.BackgroundColor3 = C.green
statusDot.BorderSizePixel = 0
corner(statusDot, 6)

local statusLbl = Instance.new("TextLabel")
statusLbl.Parent = panel
statusLbl.BackgroundTransparency = 1
statusLbl.Position = UDim2.new(0, 34, 0, 10)
statusLbl.Size = UDim2.new(1, -48, 0, 22)
statusLbl.Text = "Auto Farm Level | Attacking mob"
statusLbl.Font = FONT_BOLD
statusLbl.TextSize = 15
statusLbl.TextColor3 = C.text
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.StatusLabel = statusLbl

-- ── Wait line ────────────────────────────────────────────────
local waitLbl = Instance.new("TextLabel")
waitLbl.Parent = panel
waitLbl.BackgroundTransparency = 1
waitLbl.Position = UDim2.new(0, 14, 0, 36)
waitLbl.Size = UDim2.new(1, -28, 0, 20)
waitLbl.Text = "Waiting —"
waitLbl.Font = FONT_BOLD
waitLbl.TextSize = 15
waitLbl.TextColor3 = C.gold
waitLbl.TextXAlignment = Enum.TextXAlignment.Center
waitLbl.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.WaitLabel = waitLbl

-- ── Stat strip (LV / FRAG / BELI / FPS / TIME) ───────────────
local statsRow = Instance.new("Frame")
statsRow.Parent = panel
statsRow.Position = UDim2.new(0, 14, 0, 62)
statsRow.Size = UDim2.new(1, -28, 0, 20)
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
    k.Size = UDim2.new(0, 42, 1, 0)
    k.Text = key
    k.Font = FONT_BOLD
    k.TextSize = 14
    k.TextColor3 = C.green
    k.TextXAlignment = Enum.TextXAlignment.Left

    local v = Instance.new("TextLabel")
    v.Parent = cell
    v.BackgroundTransparency = 1
    v.Position = UDim2.new(0, 44, 0, 0)
    v.Size = UDim2.new(1, -46, 1, 0)
    v.Text = "—"
    v.Font = FONT_BOLD
    v.TextSize = 14
    v.TextColor3 = C.text
    v.TextXAlignment = Enum.TextXAlignment.Left
    v.TextTruncate = Enum.TextTruncate.AtEnd

    statLabels[key] = v
end

-- ── Combat header ────────────────────────────────────────────
local combatHeader = Instance.new("TextLabel")
combatHeader.Parent = panel
combatHeader.BackgroundTransparency = 1
combatHeader.Position = UDim2.new(0, 14, 0, 88)
combatHeader.Size = UDim2.new(0.5, -14, 0, 18)
combatHeader.Text = "Combat"
combatHeader.Font = FONT_BOLD
combatHeader.TextSize = 14
combatHeader.TextColor3 = C.text
combatHeader.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.CombatHeader = combatHeader

local combatRight = Instance.new("TextLabel")
combatRight.Parent = panel
combatRight.BackgroundTransparency = 1
combatRight.Position = UDim2.new(0.5, 0, 0, 88)
combatRight.Size = UDim2.new(0.5, -14, 0, 18)
combatRight.Text = "0 / 400"
combatRight.Font = FONT_BOLD
combatRight.TextSize = 14
combatRight.TextColor3 = C.text
combatRight.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.CombatText = combatRight

-- ── Combat bar ───────────────────────────────────────────────
local combatWrap = Instance.new("Frame")
combatWrap.Parent = panel
combatWrap.Position = UDim2.new(0, 14, 0, 110)
combatWrap.Size = UDim2.new(1, -28, 0, 18)
combatWrap.BackgroundColor3 = C.trackSoft
combatWrap.BorderSizePixel = 0
combatWrap.ClipsDescendants = true
corner(combatWrap, 9)

local combatFill = Instance.new("Frame")
combatFill.Parent = combatWrap
combatFill.Size = UDim2.new(0, 0, 1, 0)
combatFill.BackgroundColor3 = C.red
combatFill.BorderSizePixel = 0
corner(combatFill, 9)
EmsUI.CombatFill = combatFill

-- ── Mob row ──────────────────────────────────────────────────
local mobName = Instance.new("TextLabel")
mobName.Parent = panel
mobName.BackgroundTransparency = 1
mobName.Position = UDim2.new(0, 14, 0, 134)
mobName.Size = UDim2.new(0.5, -14, 0, 18)
mobName.Text = "—"
mobName.Font = FONT_BOLD
mobName.TextSize = 13
mobName.TextColor3 = C.text
mobName.TextXAlignment = Enum.TextXAlignment.Left
mobName.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.MobName = mobName

local mobHp = Instance.new("TextLabel")
mobHp.Parent = panel
mobHp.BackgroundTransparency = 1
mobHp.Position = UDim2.new(0.5, 0, 0, 134)
mobHp.Size = UDim2.new(0.5, -14, 0, 18)
mobHp.Text = ""
mobHp.Font = FONT_BOLD
mobHp.TextSize = 13
mobHp.TextColor3 = C.textGrey
mobHp.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.MobHp = mobHp

-- ── Button row — HIDE / 3D OFF / HOP / STOP ──────────────────
local btnRow = Instance.new("Frame")
btnRow.Parent = panel
btnRow.Position = UDim2.new(0, 14, 0, 160)
btnRow.Size = UDim2.new(1, -28, 0, 26)
btnRow.BackgroundTransparency = 1

local function makeBtn(x, w, text)
    local b = Instance.new("TextButton")
    b.Parent = btnRow
    b.Position = UDim2.new(x, 0, 0, 0)
    b.Size = UDim2.new(w, -3, 1, 0)
    b.BackgroundColor3 = C.panel
    b.Text = text
    b.Font = FONT_BOLD
    b.TextSize = 12
    b.TextColor3 = C.text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    corner(b, 4)
    return b
end

local hideBtn   = makeBtn(0,     0.25, "HIDE")
local threeBtn  = makeBtn(0.25,  0.25, "")
local hopBtn    = makeBtn(0.50,  0.25, "HOP")
local stopBtn   = makeBtn(0.75,  0.25, "")

-- 3D OFF — "3D" red, "OFF" white
local three3D = Instance.new("TextLabel")
three3D.Parent = threeBtn
three3D.BackgroundTransparency = 1
three3D.Position = UDim2.new(0, 0, 0, 0)
three3D.Size = UDim2.new(0.55, 0, 1, 0)
three3D.Text = "3D"
three3D.Font = FONT_BOLD
three3D.TextSize = 12
three3D.TextColor3 = C.red
three3D.TextXAlignment = Enum.TextXAlignment.Right

local threeOff = Instance.new("TextLabel")
threeOff.Parent = threeBtn
threeOff.BackgroundTransparency = 1
threeOff.Position = UDim2.new(0.55, 0, 0, 0)
threeOff.Size = UDim2.new(0.45, 0, 1, 0)
threeOff.Text = "OFF"
threeOff.Font = FONT_BOLD
threeOff.TextSize = 12
threeOff.TextColor3 = C.text
threeOff.TextXAlignment = Enum.TextXAlignment.Left

-- STOP — "ST" white, "OP" red
local stopSt = Instance.new("TextLabel")
stopSt.Parent = stopBtn
stopSt.BackgroundTransparency = 1
stopSt.Position = UDim2.new(0, 0, 0, 0)
stopSt.Size = UDim2.new(0.5, 0, 1, 0)
stopSt.Text = "ST"
stopSt.Font = FONT_BOLD
stopSt.TextSize = 12
stopSt.TextColor3 = C.text
stopSt.TextXAlignment = Enum.TextXAlignment.Right

local stopOp = Instance.new("TextLabel")
stopOp.Parent = stopBtn
stopOp.BackgroundTransparency = 1
stopOp.Position = UDim2.new(0.5, 0, 0, 0)
stopOp.Size = UDim2.new(0.5, 0, 1, 0)
stopOp.Text = "OP"
stopOp.Font = FONT_BOLD
stopOp.TextSize = 12
stopOp.TextColor3 = C.red
stopOp.TextXAlignment = Enum.TextXAlignment.Left

hideBtn.MouseButton1Click:Connect(function() panel.Visible = false end)
threeBtn.MouseButton1Click:Connect(function()
    if EmsUI.Config.AntiLag then EmsUI.Config.AntiLag = false
    else EmsUI.EnableAntiLag() end
end)
hopBtn.MouseButton1Click:Connect(function()
    pcall(function() Spirit.Hop() end)
end)
stopBtn.MouseButton1Click:Connect(function()
    _G.Stop = true
    pcall(function() Spirit.SetTask("MainTask", "Stopped") end)
end)

-- ── NEXT MELEE ───────────────────────────────────────────────
local nextMeleeHeader = Instance.new("TextLabel")
nextMeleeHeader.Parent = panel
nextMeleeHeader.BackgroundTransparency = 1
nextMeleeHeader.Position = UDim2.new(0, 14, 0, 196)
nextMeleeHeader.Size = UDim2.new(1, -28, 0, 16)
nextMeleeHeader.Text = "NEXT MELEE"
nextMeleeHeader.Font = FONT_BOLD
nextMeleeHeader.TextSize = 13
nextMeleeHeader.TextColor3 = C.text
nextMeleeHeader.TextXAlignment = Enum.TextXAlignment.Center

local nextMeleeName = Instance.new("TextLabel")
nextMeleeName.Parent = panel
nextMeleeName.BackgroundTransparency = 1
nextMeleeName.Position = UDim2.new(0, 14, 0, 216)
nextMeleeName.Size = UDim2.new(1, -28, 0, 20)
nextMeleeName.Text = "—"
nextMeleeName.Font = FONT_BOLD
nextMeleeName.TextSize = 15
nextMeleeName.TextColor3 = C.gold
nextMeleeName.TextXAlignment = Enum.TextXAlignment.Center
EmsUI.NextMeleeName = nextMeleeName

local nmBar = Instance.new("Frame")
nmBar.Parent = panel
nmBar.Position = UDim2.new(0, 14, 0, 240)
nmBar.Size = UDim2.new(1, -28, 0, 16)
nmBar.BackgroundColor3 = C.trackSoft
nmBar.BorderSizePixel = 0
nmBar.ClipsDescendants = true
corner(nmBar, 8)

local nmFill = Instance.new("Frame")
nmFill.Parent = nmBar
nmFill.Size = UDim2.new(0, 0, 1, 0)
nmFill.BackgroundColor3 = C.panel
nmFill.BorderSizePixel = 0
corner(nmFill, 8)
EmsUI.NextMeleeFill = nmFill

local nmText = Instance.new("TextLabel")
nmText.Parent = nmBar
nmText.BackgroundTransparency = 1
nmText.Size = UDim2.new(1, 0, 1, 0)
nmText.Text = "Beli 0 / 0"
nmText.Font = FONT_BOLD
nmText.TextSize = 12
nmText.TextColor3 = C.text
nmText.ZIndex = 2
EmsUI.NextMeleeTxt = nmText

-- ── INVENTORY ────────────────────────────────────────────────
local invHeader = Instance.new("TextLabel")
invHeader.Parent = panel
invHeader.BackgroundTransparency = 1
invHeader.Position = UDim2.new(0, 14, 0, 266)
invHeader.Size = UDim2.new(1, -28, 0, 16)
invHeader.Text = "INVENTORY"
invHeader.Font = FONT_BOLD
invHeader.TextSize = 13
invHeader.TextColor3 = C.text
invHeader.TextXAlignment = Enum.TextXAlignment.Center

local INV_LEFT  = {"Cursed Dual Katana", "Soul Guitar", "Shark Anchor", "Elite"}
local INV_RIGHT = {"Mirror Fractal", "Valkyrie Helm", "Dark Dagger", "Tushita"}
local invLabels = {left = {}, right = {}}

local function makeInvRow(parent, y, name)
    local row = Instance.new("Frame")
    row.Parent = parent
    row.Position = UDim2.new(0, 0, 0, y)
    row.Size = UDim2.new(1, 0, 0, 20)
    row.BackgroundTransparency = 1

    local dot = Instance.new("Frame")
    dot.Parent = row
    dot.Position = UDim2.new(0, 6, 0.5, -4)
    dot.Size = UDim2.new(0, 8, 0, 8)
    dot.BackgroundColor3 = C.red
    dot.BorderSizePixel = 0
    corner(dot, 4)

    local lbl = Instance.new("TextLabel")
    lbl.Parent = row
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 22, 0, 0)
    lbl.Size = UDim2.new(1, -26, 1, 0)
    lbl.Text = name
    lbl.Font = FONT_BOLD
    lbl.TextSize = 14
    lbl.TextColor3 = C.text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd

    return dot, lbl
end

local invLeftCol = Instance.new("Frame")
invLeftCol.Parent = panel
invLeftCol.Position = UDim2.new(0, 24, 0, 288)
invLeftCol.Size = UDim2.new(0.5, -30, 0, 86)
invLeftCol.BackgroundTransparency = 1

local invRightCol = Instance.new("Frame")
invRightCol.Parent = panel
invRightCol.Position = UDim2.new(0.5, 6, 0, 288)
invRightCol.Size = UDim2.new(0.5, -30, 0, 86)
invRightCol.BackgroundTransparency = 1

for i, name in ipairs(INV_LEFT) do
    local dot, lbl = makeInvRow(invLeftCol, (i - 1) * 22, name)
    invLabels.left[name] = {dot = dot, lbl = lbl}
end
for i, name in ipairs(INV_RIGHT) do
    local dot, lbl = makeInvRow(invRightCol, (i - 1) * 22, name)
    invLabels.right[name] = {dot = dot, lbl = lbl}
end

-- ── Bottom bar ───────────────────────────────────────────────
local fruitBtn = Instance.new("TextButton")
fruitBtn.Parent = panel
fruitBtn.Position = UDim2.new(0, 14, 0, 388)
fruitBtn.Size = UDim2.new(0, 168, 0, 26)
fruitBtn.BackgroundColor3 = C.panel
fruitBtn.Text = "Random Fruit"
fruitBtn.Font = FONT_BOLD
fruitBtn.TextSize = 13
fruitBtn.TextColor3 = C.text
fruitBtn.BorderSizePixel = 0
fruitBtn.AutoButtonColor = false
corner(fruitBtn, 4)
EmsUI.FruitBtn = fruitBtn

local bonesLbl = Instance.new("TextLabel")
bonesLbl.Parent = panel
bonesLbl.BackgroundTransparency = 1
bonesLbl.Position = UDim2.new(0, 16, 0, 418)
bonesLbl.Size = UDim2.new(0, 168, 0, 20)
bonesLbl.Text = "Bones 0"
bonesLbl.Font = FONT_BOLD
bonesLbl.TextSize = 14
bonesLbl.TextColor3 = C.text
bonesLbl.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.BonesLabel = bonesLbl

local unavailLbl = Instance.new("TextLabel")
unavailLbl.Parent = panel
unavailLbl.BackgroundTransparency = 1
unavailLbl.Position = UDim2.new(1, -182, 0, 388)
unavailLbl.Size = UDim2.new(0, 168, 0, 20)
unavailLbl.Text = "Unavailable"
unavailLbl.Font = FONT_BOLD
unavailLbl.TextSize = 15
unavailLbl.TextColor3 = C.red
unavailLbl.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.UnavailLabel = unavailLbl

local cdLbl = Instance.new("TextLabel")
cdLbl.Parent = panel
cdLbl.BackgroundTransparency = 1
cdLbl.Position = UDim2.new(1, -182, 0, 412)
cdLbl.Size = UDim2.new(0, 168, 0, 20)
cdLbl.Text = "0 | CD --:--"
cdLbl.Font = FONT_VALUE
cdLbl.TextSize = 14
cdLbl.TextColor3 = C.text
cdLbl.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.CDLabel = cdLbl

-- ── Random Fruit toggle ─────────────────────────────────────
fruitBtn.MouseButton1Click:Connect(function()
    local E = Spirit.Config and Spirit.Config.Extras
    if not E then return end
    E.AutoRandomFruit = not E.AutoRandomFruit
end)

-- ── Panel visibility ────────────────────────────────────────
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
    local bp    = ScriptStorage.Backpack or {}
    for _, entry in ipairs(order) do
        if bp[entry.name] then
            local m = owned[entry.name]
            if m and m < entry.target then return entry, m end
        end
    end
    return nil, nil
end

local function nextUnboughtMelee()
    local order = Spirit.MASTERY_TRAIN_ORDER or {}
    local bp    = ScriptStorage.Backpack or {}
    for _, entry in ipairs(order) do
        if not bp[entry.name] then return entry end
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

-- ── Cleanup on respawn ─────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        local stale = hrp:FindFirstChild("EmsIdleHover")
        if stale then stale:Destroy() end
    end
end)

-- ── SetText bridge ─────────────────────────────────────────
function EmsUI.SetText(key, text)
    pcall(function()
        if not text then return end
        text = tostring(text):gsub("<[^>]->", "")
        if key == "MainTextLabel" or key == "Task1" or key == "DebugLine" then
            local v = text:match("^MainTask%s*:%s*(.+)$") or text
            statusLbl.Text = v
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

-- ── FPS tracker ────────────────────────────────────────────
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
            local level, beli, frag = 0, 0, 0
            if Data then
                level = Data:FindFirstChild("Level") and tonumber(Data.Level.Value) or 0
                beli  = Data:FindFirstChild("Beli")  and tonumber(Data.Beli.Value)  or 0
                frag  = Data:FindFirstChild("Fragments") and tonumber(Data.Fragments.Value) or 0
            end

            local elapsed = os.time() - start
            local eh = math.floor(elapsed / 3600)
            local em = math.floor((elapsed % 3600) / 60)

            statLabels.LV.Text    = tostring(level)
            statLabels.FRAG.Text  = statNum(frag)
            statLabels.BELI.Text  = statNum(beli)
            statLabels.FPS.Text   = tostring(fps)
            statLabels.TIME.Text  = string.format("%dh %dm", eh, em)

            -- ── Combat bar — current training melee ──
            local melee, mastery = currentTrainingMelee()
            if melee then
                local target = melee.target
                local ratio = math.clamp(mastery / target, 0, 1)
                combatFill.Size = UDim2.new(ratio, 0, 1, 0)
                combatRight.Text = string.format("%d / %d", mastery, target)
                combatHeader.Text = "Combat · " .. melee.name
            else
                combatFill.Size = UDim2.new(0, 0, 1, 0)
                combatRight.Text = "0 / 400"
                combatHeader.Text = "Combat"
            end

            -- ── Wait line — next melee to buy ──
            local nm = nextUnboughtMelee()
            if nm then
                local price = Spirit.MeleePrices and Spirit.MeleePrices[nm.name]
                local needBeli = price and price.Price and price.Price.Beli or 0
                local needFrag = price and price.Price and price.Price.Fragments or 0
                if needFrag > 0 and needBeli > 0 then
                    waitLbl.Text = string.format(
                        "Waiting Beli %s / %s + %s frag for %s",
                        commaNum(beli), shortNum(needBeli),
                        shortNum(needFrag), nm.name)
                elseif needFrag > 0 then
                    waitLbl.Text = string.format(
                        "Waiting %s / %s fragments for %s",
                        commaNum(frag), shortNum(needFrag), nm.name)
                else
                    waitLbl.Text = string.format(
                        "Waiting Beli %s / %s for %s",
                        commaNum(beli), shortNum(needBeli), nm.name)
                end
                nextMeleeName.Text = nm.name
                local ratio = needBeli > 0
                    and math.clamp(beli / needBeli, 0, 1) or 1
                nmFill.Size = UDim2.new(ratio, 0, 1, 0)
                nmText.Text = string.format("Beli %s / %s",
                    commaNum(beli), shortNum(needBeli))
            else
                waitLbl.Text = "All melees owned"
                nextMeleeName.Text = "—"
                nmFill.Size = UDim2.new(1, 0, 1, 0)
                nmText.Text = "all owned"
            end

            -- ── Mob row ──
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

            -- ── Inventory ──
            local bp = ScriptStorage.Backpack or {}
            local function own(name)
                if name == "Elite" then return false end
                return bp[name] ~= nil
            end
            for name, ref in pairs(invLabels.left) do
                if name == "Elite" then
                    local eCount = 0
                    pcall(function()
                        eCount = Spirit.FunctionsHandler.Yama:Get("EliteCount") or 0
                    end)
                    ref.lbl.Text = string.format("Elite %d/30", eCount)
                    ref.dot.BackgroundColor3 = eCount >= 30 and C.green or C.red
                    ref.lbl.TextColor3 = eCount >= 30 and C.text or C.textGrey
                else
                    local owned = own(name)
                    ref.dot.BackgroundColor3 = owned and C.green or C.red
                    ref.lbl.TextColor3 = owned and C.text or C.textGrey
                end
            end
            for name, ref in pairs(invLabels.right) do
                local owned = own(name)
                ref.dot.BackgroundColor3 = owned and C.green or C.red
                ref.lbl.TextColor3 = owned and C.text or C.textGrey
            end

            -- ── Bottom bar ──
            local bones = (bp["Bones"] and bp["Bones"].Count) or 0
            bonesLbl.Text = string.format("Bones %d", bones)

            local unavail = (level < 700)
            unavailLbl.Text = unavail and "Unavailable" or "Available"
            unavailLbl.TextColor3 = unavail and C.red or C.green

            cdLbl.Text = string.format("%d | CD --:--", bones)

            -- ── Random Fruit button — real cooldown state ──
            local E = Spirit.Config and Spirit.Config.Extras
            if E then
                if not E.AutoRandomFruit then
                    fruitBtn.Text = "Random Fruit · OFF"
                    fruitBtn.TextColor3 = C.textDim
                else
                    local lastRoll = Spirit.Storage and Spirit.Storage:Get("LastRandomFruitRoll") or 0
                    local interval = E.RandomFruitDelay or 60
                    local remaining = math.max(0, interval - (os.time() - lastRoll))
                    if remaining > 0 then
                        fruitBtn.Text = string.format("Random Fruit · %ds", remaining)
                        fruitBtn.TextColor3 = C.gold
                    else
                        fruitBtn.Text = "Random Fruit · Ready"
                        fruitBtn.TextColor3 = C.green
                    end
                end
            end
        end)
    end
end)

_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
