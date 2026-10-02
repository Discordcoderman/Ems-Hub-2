-- ui.lua — Bacon Hub style HUD
--   · top-left menu button + live pill
--   · top-center title / status / beli bar / fragment bar
--   · bottom-left gold Menu toggle, level circle, uptime
--   · bottom-right MELEE TRACKER card — auto-advances through
--     MASTERY_TRAIN_ORDER, skips already-owned melees, shows the
--     next melee to buy with its real Beli/Fragment requirements
--   · EnableAntiLag() called once at load — permanent optimisation
--
-- API compatibility with the rest of the suite is preserved:
--   EmsUI.SetText, SetStats, SetStatus, SetSubStatus,
--   SetRedeemStatus, Toggle, LevelLabel, BeliLabel, FragLabel,
--   RaceLabel, TimerLabel, ScreenGui, Panel
local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

local Players       = Spirit.Players
local CoreGui       = Spirit.CoreGui
local TweenService  = Spirit.TweenService
local LocalPlayer   = Spirit.LocalPlayer
local Lighting      = Spirit.Services.Lighting
local ScriptStorage = Spirit.ScriptStorage

-- Nuke any prior instance
for _, container in ipairs({CoreGui, LocalPlayer:FindFirstChild("PlayerGui")}) do
    if container then
        pcall(function()
            local old = container:FindFirstChild("EmsHubUI")
            if old then old:Destroy() end
        end)
    end
end

local EmsUI = {Instances = {}, Config = {AntiLag = true}}
Spirit.EmsUI = EmsUI

-- ── Palette ────────────────────────────────────────────────────
local C = {
    bg        = Color3.fromRGB(10, 10, 12),
    panel     = Color3.fromRGB(18, 18, 22),
    panelSoft = Color3.fromRGB(26, 26, 32),
    line      = Color3.fromRGB(46, 46, 54),
    text      = Color3.fromRGB(238, 238, 242),
    textDim   = Color3.fromRGB(150, 150, 160),
    textFaint = Color3.fromRGB(88, 88, 96),
    title     = Color3.fromRGB(198, 120, 255),
    green     = Color3.fromRGB(106, 204, 92),
    greenDark = Color3.fromRGB(28, 54, 28),
    blue      = Color3.fromRGB(72, 148, 232),
    blueDark  = Color3.fromRGB(24, 46, 88),
    gold      = Color3.fromRGB(232, 190, 82),
    red       = Color3.fromRGB(220, 92, 92),
    ok        = Color3.fromRGB(120, 210, 130),
    shadow    = Color3.fromRGB(0, 0, 0),
}

local FONT_LABEL = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_BRAND = Enum.Font.GothamBlack
local FONT_VALUE = Enum.Font.RobotoMono
local FONT_CODE  = Enum.Font.Code

-- ── Helpers ────────────────────────────────────────────────────
local function corner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 6)
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
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
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
-- TOP-LEFT — floating menu button + live pill
-- ═══════════════════════════════════════════════════════════════
local topLeft = Instance.new("Frame")
topLeft.Parent = gui
topLeft.Position = UDim2.new(0, 16, 0, 16)
topLeft.Size = UDim2.new(0, 220, 0, 32)
topLeft.BackgroundTransparency = 1

local menuBtn = Instance.new("TextButton")
menuBtn.Parent = topLeft
menuBtn.Size = UDim2.new(0, 32, 0, 32)
menuBtn.BackgroundColor3 = C.bg
menuBtn.Text = "☰"
menuBtn.TextColor3 = C.text
menuBtn.Font = FONT_BOLD
menuBtn.TextSize = 16
menuBtn.BorderSizePixel = 0
menuBtn.AutoButtonColor = false
corner(menuBtn, 16)
stroke(menuBtn, C.line)

local livePill = Instance.new("Frame")
livePill.Parent = topLeft
livePill.Position = UDim2.new(0, 40, 0, 6)
livePill.Size = UDim2.new(0, 78, 0, 20)
livePill.BackgroundColor3 = C.panel
livePill.BorderSizePixel = 0
corner(livePill, 10)
stroke(livePill, C.line)

local liveDot = Instance.new("Frame")
liveDot.Parent = livePill
liveDot.Position = UDim2.new(0, 8, 0.5, -3)
liveDot.Size = UDim2.new(0, 6, 0, 6)
liveDot.BackgroundColor3 = C.ok
liveDot.BorderSizePixel = 0
corner(liveDot, 3)

local liveTxt = Instance.new("TextLabel")
liveTxt.Parent = livePill
liveTxt.BackgroundTransparency = 1
liveTxt.Position = UDim2.new(0, 18, 0, 0)
liveTxt.Size = UDim2.new(1, -22, 1, 0)
liveTxt.Text = "LIVE"
liveTxt.Font = FONT_LABEL
liveTxt.TextSize = 10
liveTxt.TextColor3 = C.textDim
liveTxt.TextXAlignment = Enum.TextXAlignment.Left

-- ═══════════════════════════════════════════════════════════════
-- TOP-CENTER — title / status / beli bar / fragment bar
-- ═══════════════════════════════════════════════════════════════
local hud = Instance.new("Frame")
hud.Parent = gui
hud.AnchorPoint = Vector2.new(0.5, 0)
hud.Position = UDim2.new(0.5, 0, 0, 22)
hud.Size = UDim2.new(0, 460, 0, 158)
hud.BackgroundColor3 = C.bg
hud.BackgroundTransparency = 0.15
hud.BorderSizePixel = 0
corner(hud, 12)
stroke(hud, C.line)
EmsUI.Panel = hud

-- Brand row: icon + title
local brandIcon = Instance.new("ImageLabel")
brandIcon.Parent = hud
brandIcon.Position = UDim2.new(0, 16, 0, 12)
brandIcon.Size = UDim2.new(0, 26, 0, 26)
brandIcon.BackgroundTransparency = 1
brandIcon.Image = "rbxassetid://110860238184556" -- generic hub mark; swap if you have one
brandIcon.ImageColor3 = C.title

local titleLbl = Instance.new("TextLabel")
titleLbl.Parent = hud
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 52, 0, 10)
titleLbl.Size = UDim2.new(1, -70, 0, 30)
titleLbl.Text = "EMS Hub · Kaitun"
titleLbl.Font = FONT_BRAND
titleLbl.TextSize = 22
titleLbl.TextColor3 = C.title
titleLbl.TextXAlignment = Enum.TextXAlignment.Center

-- Status line
local statusLbl = Instance.new("TextLabel")
statusLbl.Parent = hud
statusLbl.BackgroundTransparency = 1
statusLbl.Position = UDim2.new(0, 16, 0, 46)
statusLbl.Size = UDim2.new(1, -32, 0, 20)
statusLbl.Text = "Status : Idle"
statusLbl.Font = FONT_LABEL
statusLbl.TextSize = 15
statusLbl.TextColor3 = C.text
statusLbl.TextXAlignment = Enum.TextXAlignment.Center
statusLbl.TextTruncate = Enum.TextTruncate.AtEnd

-- Progress bar factory
local function makeBar(yPos, fillColor, bgColor)
    local wrap = Instance.new("Frame")
    wrap.Parent = hud
    wrap.Position = UDim2.new(0, 16, 0, yPos)
    wrap.Size = UDim2.new(1, -32, 0, 22)
    wrap.BackgroundColor3 = bgColor
    wrap.BorderSizePixel = 0
    wrap.ClipsDescendants = true
    corner(wrap, 11)

    local fill = Instance.new("Frame")
    fill.Parent = wrap
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = fillColor
    fill.BorderSizePixel = 0
    corner(fill, 11)

    local txt = Instance.new("TextLabel")
    txt.Parent = wrap
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.Font = FONT_BOLD
    txt.TextSize = 13
    txt.TextColor3 = C.text
    txt.Text = "0 / 0"
    txt.TextXAlignment = Enum.TextXAlignment.Center
    txt.ZIndex = 2

    return wrap, fill, txt
end

local _, beliFill, beliTxt = makeBar(72, C.green, C.greenDark)
local _, fragFill, fragTxt = makeBar(102, C.blue,  C.blueDark)
EmsUI.BeliFill = beliFill
EmsUI.FragFill = fragFill

-- Small caption row (level / race)
local captionLbl = Instance.new("TextLabel")
captionLbl.Parent = hud
captionLbl.BackgroundTransparency = 1
captionLbl.Position = UDim2.new(0, 16, 0, 130)
captionLbl.Size = UDim2.new(1, -32, 0, 16)
captionLbl.Text = "Level — · Race —"
captionLbl.Font = FONT_LABEL
captionLbl.TextSize = 11
captionLbl.TextColor3 = C.textDim
captionLbl.TextXAlignment = Enum.TextXAlignment.Center
EmsUI.CaptionLabel = captionLbl

-- ═══════════════════════════════════════════════════════════════
-- BOTTOM-LEFT — gold Menu toggle, level circle, uptime
-- ═══════════════════════════════════════════════════════════════
local bottomLeft = Instance.new("Frame")
bottomLeft.Parent = gui
bottomLeft.AnchorPoint = Vector2.new(0, 1)
bottomLeft.Position = UDim2.new(0, 16, 1, -16)
bottomLeft.Size = UDim2.new(0, 240, 0, 72)
bottomLeft.BackgroundTransparency = 1

local menuToggle = Instance.new("TextButton")
menuToggle.Parent = bottomLeft
menuToggle.Position = UDim2.new(0, 0, 1, -32)
menuToggle.Size = UDim2.new(0, 96, 0, 30)
menuToggle.BackgroundColor3 = C.gold
menuToggle.Text = "MENU"
menuToggle.Font = FONT_BRAND
menuToggle.TextSize = 13
menuToggle.TextColor3 = Color3.fromRGB(30, 22, 4)
menuToggle.BorderSizePixel = 0
menuToggle.AutoButtonColor = false
corner(menuToggle, 6)

local levelCircle = Instance.new("Frame")
levelCircle.Parent = bottomLeft
levelCircle.Position = UDim2.new(0, 104, 1, -36)
levelCircle.Size = UDim2.new(0, 40, 0, 40)
levelCircle.BackgroundColor3 = C.panel
levelCircle.BorderSizePixel = 0
corner(levelCircle, 20)
stroke(levelCircle, C.gold, 2)

local levelTxt = Instance.new("TextLabel")
levelTxt.Parent = levelCircle
levelTxt.BackgroundTransparency = 1
levelTxt.Size = UDim2.new(1, 0, 1, -6)
levelTxt.Position = UDim2.new(0, 0, 0, 2)
levelTxt.Text = "1"
levelTxt.Font = FONT_BRAND
levelTxt.TextSize = 16
levelTxt.TextColor3 = C.gold

local lvlCaption = Instance.new("TextLabel")
lvlCaption.Parent = levelCircle
lvlCaption.BackgroundTransparency = 1
lvlCaption.Position = UDim2.new(0, 0, 0, 24)
lvlCaption.Size = UDim2.new(1, 0, 0, 10)
lvlCaption.Text = "CẤP"
lvlCaption.Font = FONT_LABEL
lvlCaption.TextSize = 8
lvlCaption.TextColor3 = C.textFaint
EmsUI.LevelLabel = levelTxt

local uptimePill = Instance.new("Frame")
uptimePill.Parent = bottomLeft
uptimePill.Position = UDim2.new(0, 152, 1, -30)
uptimePill.Size = UDim2.new(0, 84, 0, 24)
uptimePill.BackgroundColor3 = C.panel
uptimePill.BorderSizePixel = 0
corner(uptimePill, 12)
stroke(uptimePill, C.line)

local uptimeTxt = Instance.new("TextLabel")
uptimeTxt.Parent = uptimePill
uptimeTxt.BackgroundTransparency = 1
uptimeTxt.Size = UDim2.new(1, -14, 1, 0)
uptimeTxt.Position = UDim2.new(0, 7, 0, 0)
uptimeTxt.Text = "00:00:00"
uptimeTxt.Font = FONT_CODE
uptimeTxt.TextSize = 11
uptimeTxt.TextColor3 = C.textDim
uptimeTxt.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.TimerLabel = uptimeTxt

-- ═══════════════════════════════════════════════════════════════
-- BOTTOM-RIGHT — MELEE TRACKER
-- ═══════════════════════════════════════════════════════════════
local meleeCard = Instance.new("Frame")
meleeCard.Parent = gui
meleeCard.AnchorPoint = Vector2.new(1, 1)
meleeCard.Position = UDim2.new(1, -16, 1, -16)
meleeCard.Size = UDim2.new(0, 320, 0, 130)
meleeCard.BackgroundColor3 = C.bg
meleeCard.BackgroundTransparency = 0.15
meleeCard.BorderSizePixel = 0
corner(meleeCard, 10)
stroke(meleeCard, C.line)
EmsUI.MeleeCard = meleeCard

local meleeHeader = Instance.new("TextLabel")
meleeHeader.Parent = meleeCard
meleeHeader.BackgroundTransparency = 1
meleeHeader.Position = UDim2.new(0, 14, 0, 8)
meleeHeader.Size = UDim2.new(1, -28, 0, 14)
meleeHeader.Text = "MELEE TRACKER"
meleeHeader.Font = FONT_BRAND
meleeHeader.TextSize = 11
meleeHeader.TextColor3 = C.gold
meleeHeader.TextXAlignment = Enum.TextXAlignment.Left

-- Current row
local curName = Instance.new("TextLabel")
curName.Parent = meleeCard
curName.BackgroundTransparency = 1
curName.Position = UDim2.new(0, 14, 0, 28)
curName.Size = UDim2.new(1, -28, 0, 16)
curName.Text = "Current —"
curName.Font = FONT_BOLD
curName.TextSize = 13
curName.TextColor3 = C.text
curName.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.MeleeCurrentName = curName

local curBarBg = Instance.new("Frame")
curBarBg.Parent = meleeCard
curBarBg.Position = UDim2.new(0, 14, 0, 48)
curBarBg.Size = UDim2.new(1, -28, 0, 14)
curBarBg.BackgroundColor3 = C.panelSoft
curBarBg.BorderSizePixel = 0
corner(curBarBg, 7)

local curBarFill = Instance.new("Frame")
curBarFill.Parent = curBarBg
curBarFill.Size = UDim2.new(0, 0, 1, 0)
curBarFill.BackgroundColor3 = C.gold
curBarFill.BorderSizePixel = 0
corner(curBarFill, 7)

local curBarTxt = Instance.new("TextLabel")
curBarTxt.Parent = curBarBg
curBarTxt.BackgroundTransparency = 1
curBarTxt.Size = UDim2.new(1, 0, 1, 0)
curBarTxt.Font = FONT_VALUE
curBarTxt.TextSize = 10
curBarTxt.TextColor3 = C.text
curBarTxt.Text = "0 / 400"
EmsUI.MeleeMasteryTxt = curBarTxt

-- Next row
local nextName = Instance.new("TextLabel")
nextName.Parent = meleeCard
nextName.BackgroundTransparency = 1
nextName.Position = UDim2.new(0, 14, 0, 70)
nextName.Size = UDim2.new(1, -28, 0, 14)
nextName.Text = "Next —"
nextName.Font = FONT_LABEL
nextName.TextSize = 11
nextName.TextColor3 = C.textDim
nextName.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.MeleeNextName = nextName

local nextReq = Instance.new("TextLabel")
nextReq.Parent = meleeCard
nextReq.BackgroundTransparency = 1
nextReq.Position = UDim2.new(0, 14, 0, 86)
nextReq.Size = UDim2.new(1, -28, 0, 16)
nextReq.Text = "—"
nextReq.Font = FONT_VALUE
nextReq.TextSize = 11
nextReq.TextColor3 = C.text
nextReq.TextXAlignment = Enum.TextXAlignment.Left
nextReq.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.MeleeNextReq = nextReq

-- Owned / locked indicator
local reqStatus = Instance.new("TextLabel")
reqStatus.Parent = meleeCard
reqStatus.BackgroundTransparency = 1
reqStatus.Position = UDim2.new(0, 14, 0, 104)
reqStatus.Size = UDim2.new(1, -28, 0, 14)
reqStatus.Text = ""
reqStatus.Font = FONT_LABEL
reqStatus.TextSize = 11
reqStatus.TextColor3 = C.textDim
reqStatus.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.MeleeStatus = reqStatus

-- Menu toggle behaviour
local hudVisible = true
local function setHudVisible(v)
    hudVisible = v
    hud.Visible = v
    meleeCard.Visible = v
    bottomLeft.Visible = v
end
menuToggle.MouseButton1Click:Connect(function() setHudVisible(not hudVisible) end)
menuBtn.MouseButton1Click:Connect(function() setHudVisible(not hudVisible) end)

-- ═══════════════════════════════════════════════════════════════
-- MELEE STATE — reads live data, auto-advances
-- ═══════════════════════════════════════════════════════════════
local function meleeReqString(name)
    local p = Spirit.MeleePrices and Spirit.MeleePrices[name]
    if not p then return "—" end
    local parts = {}
    if p.Price and p.Price.Beli then
        table.insert(parts, "$" .. shortNum(p.Price.Beli))
    end
    if p.Price and p.Price.Fragments then
        table.insert(parts, shortNum(p.Price.Fragments) .. " frag")
    end
    if #parts == 0 then return "—" end
    return table.concat(parts, "  +  ")
end

local function getMeleeState()
    local order = Spirit.MASTERY_TRAIN_ORDER or {}
    local owned = ScriptStorage.Melees or {}

    local current, currentIdx = nil, 0

    -- 1st owned melee that hasn't hit its mastery target
    for i, entry in ipairs(order) do
        local m = owned[entry.name]
        if m and m < entry.target then
            current    = entry
            currentIdx = i
            break
        end
    end

    -- else: 1st melee not yet bought
    if not current then
        for i, entry in ipairs(order) do
            if not owned[entry.name] then
                current    = entry
                currentIdx = i
                break
            end
        end
    end

    -- next = 1st not-owned melee AFTER current, skipping anything already bought
    local nextM = nil
    if currentIdx > 0 then
        for j = currentIdx + 1, #order do
            if not owned[order[j].name] then
                nextM = order[j]
                break
            end
        end
    end

    return current, currentIdx, nextM
end

-- ═══════════════════════════════════════════════════════════════
-- ANTI-LAG — permanent optimisation pass
-- ═══════════════════════════════════════════════════════════════
local function stripInstance(obj)
    if not obj or not obj.Parent then return end
    if obj:IsA("BasePart") then
        obj.Material    = Enum.Material.Plastic
        obj.Reflectance = 0
        obj.CastShadow  = false
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

    -- Lighting / atmosphere
    pcall(function()
        Lighting.GlobalShadows   = false
        Lighting.Brightness      = 1
        Lighting.Ambient         = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient  = Color3.fromRGB(128, 128, 128)
        Lighting.FogEnd          = 100000
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") or e:IsA("Sky") then
                pcall(function() e.Enabled = false end)
            elseif e:IsA("Atmosphere") then
                e.Density = 0
                e.Haze = 0
            end
        end
    end)

    -- Render quality
    pcall(function()
        if settings and settings().Rendering then
            settings().Rendering.QualityLevel        = Enum.QualityLevel.Level01
            settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
        end
    end)

    -- Terrain simplification
    pcall(function()
        local t = workspace.Terrain
        t.WaterWaveSize     = 0
        t.WaterWaveSpeed    = 0
        t.WaterReflectance  = 0
        t.WaterTransparency = 1
        if t.Decoration then t.Decoration = false end
    end)

    -- Strip everything currently in workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(stripInstance, obj)
    end

    -- Hook future additions
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
-- SetText compatibility bridge
-- ═══════════════════════════════════════════════════════════════
local _pending = {key = nil, text = nil, dirty = false}
function EmsUI.SetText(key, text)
    _pending.key  = key
    _pending.text = text
    _pending.dirty = true
end

task.spawn(function()
    while task.wait(0.05) do
        if _pending.dirty then
            local key, text = _pending.key, _pending.text
            _pending.dirty = false
            pcall(function()
                if not text then return end
                text = tostring(text):gsub("<[^>]->", "")
                if key == "MainTextLabel" or key == "Task1"
                    or key == "DebugLine" then
                    -- Task1 = "MainTask : value" → strip the prefix for display
                    local v = text:match("^MainTask%s*:%s*(.+)$") or text
                    statusLbl.Text = "Status : " .. v
                elseif key == "Task2" then
                    local v = text:match("^SubTask%s*:%s*(.+)$") or text
                    if v ~= "" and v ~= "—" and v ~= "Idle" then
                        captionLbl.Text = v
                    end
                elseif key == "LiveTime" then
                    uptimeTxt.Text = text
                end
            end)
        end
    end
end)

function EmsUI.SetStatus(text)
    if not text then return end
    statusLbl.Text = "Status : " .. tostring(text):gsub("<[^>]->", "")
end
function EmsUI.SetSubStatus(text)
    if text then captionLbl.Text = tostring(text) end
end
function EmsUI.SetRedeemStatus(_) end
function EmsUI.Toggle() setHudVisible(not hudVisible) end

-- ═══════════════════════════════════════════════════════════════
-- SetStats — Beli / Fragment bars driven by next-melee target
-- ═══════════════════════════════════════════════════════════════
local BELI_FALLBACK_TARGET = 10_000_000
local FRAG_FALLBACK_TARGET = 5_000

function EmsUI.SetStats(data)
    if not data then return end
    pcall(function()
        if data.Level then
            levelTxt.Text = tostring(data.Level)
        end
        if data.Elapsed then
            local h = math.floor(data.Elapsed / 3600)
            local m = math.floor((data.Elapsed % 3600) / 60)
            local s = math.floor(data.Elapsed % 60)
            uptimeTxt.Text = string.format("%02d:%02d:%02d", h, m, s)
        end
        if data.Race then
            captionLbl.Text = string.format("Level %s · Race %s",
                tostring(data.Level or "—"), tostring(data.Race))
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- Refresh loop — stats, bars, melee card
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local start = os.time() - (Spirit.OldSessionTime or 0)
    while task.wait(0.75) do
        pcall(function()
            local Data = LocalPlayer:FindFirstChild("Data")
            if not Data then return end

            local level = Data:FindFirstChild("Level")
                and tonumber(Data.Level.Value) or 0
            local beli  = Data:FindFirstChild("Beli")
                and tonumber(Data.Beli.Value) or 0
            local frag  = Data:FindFirstChild("Fragments")
                and tonumber(Data.Fragments.Value) or 0

            local raceName = "—"
            local raceObj  = Data:FindFirstChild("Race")
            if raceObj then
                if raceObj:IsA("StringValue") then
                    raceName = raceObj.Value
                elseif raceObj:IsA("Folder") then
                    local v = raceObj:FindFirstChild("Value")
                    if v then raceName = v.Value end
                end
            end

            -- Resolve targets from next-melee requirement (fallback to defaults)
            local _, _, nextM = getMeleeState()
            local beliTarget = BELI_FALLBACK_TARGET
            local fragTarget = FRAG_FALLBACK_TARGET
            if nextM then
                local p = Spirit.MeleePrices and Spirit.MeleePrices[nextM.name]
                if p and p.Price then
                    if p.Price.Beli      then beliTarget = math.max(p.Price.Beli, 1) end
                    if p.Price.Fragments then fragTarget = math.max(p.Price.Fragments, 1) end
                end
            end

            -- Green bar — Beli
            local beliRatio = math.clamp(beli / beliTarget, 0, 1)
            beliFill.Size = UDim2.new(beliRatio, 0, 1, 0)
            beliTxt.Text  = string.format("$%s / $%s",
                shortNum(beli), shortNum(beliTarget))

            -- Blue bar — Fragments
            local fragRatio = math.clamp(frag / fragTarget, 0, 1)
            fragFill.Size = UDim2.new(fragRatio, 0, 1, 0)
            fragTxt.Text  = string.format("%s / %s frag",
                shortNum(frag), shortNum(fragTarget))

            -- Caption
            captionLbl.Text = string.format("Level %d · Race %s",
                level, tostring(raceName))

            -- Uptime
            local elapsed = os.time() - start
            local h = math.floor(elapsed / 3600)
            local m = math.floor((elapsed % 3600) / 60)
            local s = math.floor(elapsed % 60)
            uptimeTxt.Text = string.format("%02d:%02d:%02d", h, m, s)

            -- ── Melee card ──────────────────────────────────
            local current, _, nextMelee = getMeleeState()
            local owned = ScriptStorage.Melees or {}

            if current then
                local m = owned[current.name]
                if m then
                    -- Owned — show mastery progress
                    local ratio = math.clamp(m / current.target, 0, 1)
                    curBarFill.Size = UDim2.new(ratio, 0, 1, 0)
                    curBarTxt.Text  = string.format("%s   %d / %d",
                        current.name, m, current.target)
                    curName.Text = "Current · " .. current.name
                    curName.TextColor3 = C.text
                else
                    -- Not owned yet — this is a buy target
                    curBarFill.Size = UDim2.new(0, 0, 1, 0)
                    curBarTxt.Text  = "Not owned — " .. current.name
                    curName.Text = "Current · " .. current.name .. "  (buy)"
                    curName.TextColor3 = C.gold
                end
            else
                curBarFill.Size = UDim2.new(1, 0, 1, 0)
                curBarTxt.Text  = "All melees complete"
                curName.Text    = "Current · —"
                curName.TextColor3 = C.ok
            end

            if nextMelee then
                nextName.Text = "Next · " .. nextMelee.name
                nextReq.Text  = meleeReqString(nextMelee.name)

                local p = Spirit.MeleePrices and Spirit.MeleePrices[nextMelee.name]
                if p and p.Price then
                    local needBeli = (p.Price.Beli or 0)
                    local needFrag = (p.Price.Fragments or 0)
                    local okBeli   = beli >= needBeli
                    local okFrag   = frag >= needFrag
                    local lvlReq   = (Spirit.BossesOrderLevel and 0) or 0

                    if okBeli and okFrag then
                        reqStatus.Text = "✔ requirements met — buyable"
                        reqStatus.TextColor3 = C.ok
                    else
                        local missing = {}
                        if not okBeli and needBeli > 0 then
                            table.insert(missing, "$" .. shortNum(needBeli - beli))
                        end
                        if not okFrag and needFrag > 0 then
                            table.insert(missing, shortNum(needFrag - frag) .. " frag")
                        end
                        reqStatus.Text = "✘ missing " .. table.concat(missing, " · ")
                        reqStatus.TextColor3 = C.red
                    end
                else
                    reqStatus.Text = ""
                end
            else
                nextName.Text = "Next · —"
                nextReq.Text  = "no further melee in order"
                reqStatus.Text = ""
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Compatibility shims for the old panel-based API
-- ═══════════════════════════════════════════════════════════════
EmsUI.BeliLabel = {Text = ""}
EmsUI.FragLabel = {Text = ""}
EmsUI.RaceLabel = {Text = ""}

_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
