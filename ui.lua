-- ui.lua — Bacon Hub style compact HUD
--   · top-center: brand, status, long-form timer, stat rows, melee
--   · bottom-left: MENU toggle + level circle
--   · idle hover: when MainTask == "Idle" for 2s, character rises to
--     Y = 952 and holds — releases the moment any task resumes
--   · API compat: SetText / SetStats / SetStatus / Toggle / Panel
local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

local Players       = Spirit.Players
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
    bg        = Color3.fromRGB(8, 8, 10),
    panel     = Color3.fromRGB(14, 14, 18),
    line      = Color3.fromRGB(48, 48, 56),
    text      = Color3.fromRGB(240, 240, 244),
    textDim   = Color3.fromRGB(160, 160, 172),
    textFaint = Color3.fromRGB(96, 96, 108),
    brand     = Color3.fromRGB(186, 108, 240),
    brandHot  = Color3.fromRGB(232, 140, 255),
    blue      = Color3.fromRGB(102, 176, 255),
    gold      = Color3.fromRGB(232, 190, 82),
    green     = Color3.fromRGB(120, 210, 130),
    red       = Color3.fromRGB(220, 100, 100),
    shadow    = Color3.fromRGB(0, 0, 0),
}

local FONT_LABEL = Enum.Font.Gotham
local FONT_MED   = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_BRAND = Enum.Font.GothamBlack
local FONT_VALUE = Enum.Font.RobotoMono

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
-- MAIN PANEL — centered stack
-- ═══════════════════════════════════════════════════════════════
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Parent           = gui
panel.AnchorPoint      = Vector2.new(0.5, 0)
panel.Position         = UDim2.new(0.5, 0, 0, 24)
panel.Size             = UDim2.new(0, 340, 0, 262)
panel.BackgroundColor3 = C.bg
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel  = 0
panel.Active           = true
panel.Draggable        = true
corner(panel, 8)
stroke(panel, C.line)
EmsUI.Panel = panel

-- ── Brand title (two-line, like the screenshot) ───────────────
local brandTop = Instance.new("TextLabel")
brandTop.Parent = panel
brandTop.BackgroundTransparency = 1
brandTop.Position = UDim2.new(0, 0, 0, 10)
brandTop.Size = UDim2.new(1, 0, 0, 26)
brandTop.Text = "FREE"
brandTop.Font = FONT_BRAND
brandTop.TextSize = 24
brandTop.TextColor3 = C.brand
brandTop.TextXAlignment = Enum.TextXAlignment.Center
brandTop.TextStrokeTransparency = 0.6
brandTop.TextStrokeColor3 = C.shadow

local brandBot = Instance.new("TextLabel")
brandBot.Parent = panel
brandBot.BackgroundTransparency = 1
brandBot.Position = UDim2.new(0, 0, 0, 34)
brandBot.Size = UDim2.new(1, 0, 0, 26)
brandBot.Text = "KAITUN"
brandBot.Font = FONT_BRAND
brandBot.TextSize = 22
brandBot.TextColor3 = C.brandHot
brandBot.TextXAlignment = Enum.TextXAlignment.Center
brandBot.TextStrokeTransparency = 0.6
brandBot.TextStrokeColor3 = C.shadow

-- ── Status ────────────────────────────────────────────────────
local statusLbl = Instance.new("TextLabel")
statusLbl.Parent = panel
statusLbl.BackgroundTransparency = 1
statusLbl.Position = UDim2.new(0, 12, 0, 70)
statusLbl.Size = UDim2.new(1, -24, 0, 16)
statusLbl.Text = "Status : Idle"
statusLbl.Font = FONT_MED
statusLbl.TextSize = 13
statusLbl.TextColor3 = C.text
statusLbl.TextXAlignment = Enum.TextXAlignment.Center
statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.StatusLabel = statusLbl

-- ── Long-form timer ───────────────────────────────────────────
local timerLbl = Instance.new("TextLabel")
timerLbl.Parent = panel
timerLbl.BackgroundTransparency = 1
timerLbl.Position = UDim2.new(0, 12, 0, 90)
timerLbl.Size = UDim2.new(1, -24, 0, 16)
timerLbl.Text = "0 Hours, 0 Minutes, 0 Seconds"
timerLbl.Font = FONT_LABEL
timerLbl.TextSize = 12
timerLbl.TextColor3 = C.textDim
timerLbl.TextXAlignment = Enum.TextXAlignment.Center
EmsUI.TimerLabel = timerLbl

-- ── Level / Beli row ─────────────────────────────────────────
local levelBeliRow = Instance.new("Frame")
levelBeliRow.Parent = panel
levelBeliRow.Position = UDim2.new(0, 12, 0, 118)
levelBeliRow.Size = UDim2.new(1, -24, 0, 18)
levelBeliRow.BackgroundTransparency = 1

local levelLbl = Instance.new("TextLabel")
levelLbl.Parent = levelBeliRow
levelLbl.BackgroundTransparency = 1
levelLbl.Size = UDim2.new(0.5, 0, 1, 0)
levelLbl.Position = UDim2.new(0, 0, 0, 0)
levelLbl.Text = "Level: 0"
levelLbl.Font = FONT_MED
levelLbl.TextSize = 13
levelLbl.TextColor3 = C.text
levelLbl.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.LevelLabel = levelLbl

local beliLbl = Instance.new("TextLabel")
beliLbl.Parent = levelBeliRow
beliLbl.BackgroundTransparency = 1
beliLbl.Size = UDim2.new(0.5, 0, 1, 0)
beliLbl.Position = UDim2.new(0.5, 0, 0, 0)
beliLbl.Text = "Beli: 0"
beliLbl.Font = FONT_MED
beliLbl.TextSize = 13
beliLbl.TextColor3 = C.text
beliLbl.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.BeliLabel = beliLbl

-- ── Fragment / Race row ──────────────────────────────────────
local fragRaceRow = Instance.new("Frame")
fragRaceRow.Parent = panel
fragRaceRow.Position = UDim2.new(0, 12, 0, 142)
fragRaceRow.Size = UDim2.new(1, -24, 0, 18)
fragRaceRow.BackgroundTransparency = 1

local fragLbl = Instance.new("TextLabel")
fragLbl.Parent = fragRaceRow
fragLbl.BackgroundTransparency = 1
fragLbl.Size = UDim2.new(0.5, 0, 1, 0)
fragLbl.Position = UDim2.new(0, 0, 0, 0)
fragLbl.Text = "Fragment: 0"
fragLbl.Font = FONT_MED
fragLbl.TextSize = 13
fragLbl.TextColor3 = C.blue
fragLbl.TextXAlignment = Enum.TextXAlignment.Left
EmsUI.FragLabel = fragLbl

local raceLbl = Instance.new("TextLabel")
raceLbl.Parent = fragRaceRow
raceLbl.BackgroundTransparency = 1
raceLbl.Size = UDim2.new(0.5, 0, 1, 0)
raceLbl.Position = UDim2.new(0.5, 0, 0, 0)
raceLbl.Text = "Race: —"
raceLbl.Font = FONT_MED
raceLbl.TextSize = 13
raceLbl.TextColor3 = C.blue
raceLbl.TextXAlignment = Enum.TextXAlignment.Right
EmsUI.RaceLabel = raceLbl

-- ── Melee line ───────────────────────────────────────────────
local meleeLbl = Instance.new("TextLabel")
meleeLbl.Parent = panel
meleeLbl.BackgroundTransparency = 1
meleeLbl.Position = UDim2.new(0, 12, 0, 172)
meleeLbl.Size = UDim2.new(1, -24, 0, 18)
meleeLbl.Text = "Melee: —"
meleeLbl.Font = FONT_MED
meleeLbl.TextSize = 13
meleeLbl.TextColor3 = C.gold
meleeLbl.TextXAlignment = Enum.TextXAlignment.Center
meleeLbl.TextTruncate = Enum.TextTruncate.AtEnd
EmsUI.MeleeLabel = meleeLbl

-- ── Footer — codes redeemed ──────────────────────────────────
local footerLbl = Instance.new("TextLabel")
footerLbl.Parent = panel
footerLbl.BackgroundTransparency = 1
footerLbl.Position = UDim2.new(0, 12, 0, 208)
footerLbl.Size = UDim2.new(1, -24, 0, 16)
footerLbl.Text = "0 Codes Redeemed"
footerLbl.Font = FONT_LABEL
footerLbl.TextSize = 11
footerLbl.TextColor3 = C.green
footerLbl.TextXAlignment = Enum.TextXAlignment.Center
EmsUI.FooterLabel = footerLbl

-- ── Thin divider above footer ────────────────────────────────
local div = Instance.new("Frame")
div.Parent = panel
div.Position = UDim2.new(0, 20, 0, 196)
div.Size = UDim2.new(1, -40, 0, 1)
div.BackgroundColor3 = C.line
div.BackgroundTransparency = 0.4
div.BorderSizePixel = 0

-- ── Bottom hint / uptime pill ────────────────────────────────
local uptimeLbl = Instance.new("TextLabel")
uptimeLbl.Parent = panel
uptimeLbl.BackgroundTransparency = 1
uptimeLbl.Position = UDim2.new(0, 12, 0, 228)
uptimeLbl.Size = UDim2.new(1, -24, 0, 22)
uptimeLbl.Text = "session 00:00:00"
uptimeLbl.Font = FONT_VALUE
uptimeLbl.TextSize = 11
uptimeLbl.TextColor3 = C.textFaint
uptimeLbl.TextXAlignment = Enum.TextXAlignment.Center
EmsUI.SessionLabel = uptimeLbl

-- ═══════════════════════════════════════════════════════════════
-- BOTTOM-LEFT — MENU toggle
-- ═══════════════════════════════════════════════════════════════
local menuBtn = Instance.new("TextButton")
menuBtn.Name = "EmsFloat"
menuBtn.Parent = gui
menuBtn.AnchorPoint = Vector2.new(0, 1)
menuBtn.Position = UDim2.new(0, 16, 1, -16)
menuBtn.Size = UDim2.new(0, 92, 0, 30)
menuBtn.BackgroundColor3 = C.gold
menuBtn.Text = "MENU"
menuBtn.Font = FONT_BRAND
menuBtn.TextSize = 13
menuBtn.TextColor3 = Color3.fromRGB(28, 20, 4)
menuBtn.BorderSizePixel = 0
menuBtn.AutoButtonColor = false
menuBtn.Draggable = true
menuBtn.Active = true
corner(menuBtn, 6)

local panelVisible = true
local function setPanelVisible(v)
    panelVisible = v
    panel.Visible = v
end
menuBtn.MouseButton1Click:Connect(function() setPanelVisible(not panelVisible) end)

-- ═══════════════════════════════════════════════════════════════
-- MELEE STATE — current training target
-- ═══════════════════════════════════════════════════════════════
local function currentMeleeString()
    local order = Spirit.MASTERY_TRAIN_ORDER or {}
    local owned = ScriptStorage.Melees or {}
    for _, entry in ipairs(order) do
        local m = owned[entry.name]
        if m and m < entry.target then
            return string.format("%s  %d / %d", entry.name, m, entry.target)
        end
    end
    for _, entry in ipairs(order) do
        if not owned[entry.name] then
            return string.format("%s  (not owned)", entry.name)
        end
    end
    return "all melees complete"
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
        t.WaterWaveSize     = 0
        t.WaterWaveSpeed    = 0
        t.WaterReflectance  = 0
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
-- IDLE HOVER — rise to Y = 952, hold, release when any task resumes
-- ═══════════════════════════════════════════════════════════════
local function engageIdleHover()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if Spirit._idleBP and Spirit._idleBP.Parent == hrp then
        Spirit._idleBP.Position = Vector3.new(hrp.Position.X,
            EmsUI.Config.IdleHeight, hrp.Position.Z)
        return
    end
    if Spirit._idleBP then
        pcall(function() Spirit._idleBP:Destroy() end)
        Spirit._idleBP = nil
    end

    local bp = Instance.new("BodyPosition")
    bp.Name     = "EmsIdleHover"
    bp.MaxForce = Vector3.new(1e4, 2e5, 1e4)
    bp.P        = 8000
    bp.D        = 400
    bp.Position = Vector3.new(hrp.Position.X, EmsUI.Config.IdleHeight, hrp.Position.Z)
    bp.Parent   = hrp
    Spirit._idleBP = bp
end

local function releaseIdleHover()
    if Spirit._idleBP then
        pcall(function() Spirit._idleBP:Destroy() end)
        Spirit._idleBP = nil
    end
end

task.spawn(function()
    local idleStreak = 0
    while task.wait(1) do
        pcall(function()
            local task_ = ScriptStorage.Task or {}
            local mainTask = task_.MainTask or ""
            local transitioning = _G.SeaTransitionActive or _G.SkyTransitionActive
                or _G.FruitPriorityActive

            local isIdle = (mainTask == "Idle") and not transitioning
            if isIdle then idleStreak = idleStreak + 1 else idleStreak = 0 end

            if idleStreak >= 2 then
                engageIdleHover()
            else
                releaseIdleHover()
            end
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    Spirit._idleBP = nil
end)

-- ═══════════════════════════════════════════════════════════════
-- SetText bridge — Task1 → status, Task2 → ignored (no sub row)
-- ═══════════════════════════════════════════════════════════════
function EmsUI.SetText(key, text)
    pcall(function()
        if not text then return end
        text = tostring(text):gsub("<[^>]->", "")
        if key == "MainTextLabel" or key == "Task1" or key == "DebugLine" then
            local v = text:match("^MainTask%s*:%s*(.+)$") or text
            statusLbl.Text = "Status : " .. v
        elseif key == "LiveTime" then
            -- long-form is handled by the tick loop, not here
        end
    end)
end

function EmsUI.SetStatus(text)
    if not text then return end
    statusLbl.Text = "Status : " .. tostring(text):gsub("<[^>]->", "")
end
function EmsUI.SetSubStatus(_) end
function EmsUI.SetRedeemStatus(text)
    if not text then return end
    footerLbl.Text = tostring(text)
end
function EmsUI.Toggle() setPanelVisible(not panelVisible) end

function EmsUI.SetStats(_) end -- handled by the loop below

-- ═══════════════════════════════════════════════════════════════
-- Refresh loop
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local start = os.time() - (Spirit.OldSessionTime or 0)
    while task.wait(0.5) do
        pcall(function()
            local Data = LocalPlayer:FindFirstChild("Data")
            if Data then
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

                levelLbl.Text = string.format("Level: %d", level)
                beliLbl.Text  = string.format("Beli: %s", shortNum(beli))
                fragLbl.Text  = string.format("Fragment: %s", shortNum(frag))
                raceLbl.Text  = string.format("Race: %s", tostring(raceName))
            end

            -- Long-form uptime
            local elapsed = os.time() - start
            local h = math.floor(elapsed / 3600)
            local m = math.floor((elapsed % 3600) / 60)
            local s = math.floor(elapsed % 60)
            timerLbl.Text = string.format("%d Hours, %d Minutes, %d Seconds", h, m, s)
            uptimeLbl.Text = string.format("session %02d:%02d:%02d", h, m, s)

            -- Melee line
            meleeLbl.Text = "Melee: " .. currentMeleeString()

            -- Codes redeemed count
            local redeemed = Spirit.Storage and Spirit.Storage:Get("RedeemedCodes") or {}
            local count = 0
            if type(redeemed) == "table" then
                for _ in pairs(redeemed) do count = count + 1 end
            end
            footerLbl.Text = string.format("%d Codes Redeemed", count)
        end)
    end
end)

_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
