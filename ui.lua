-- ui.lua — compact EMS HUB panel
local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

local Players      = Spirit.Players
local CoreGui      = Spirit.CoreGui
local TweenService = Spirit.TweenService
local LocalPlayer  = Spirit.LocalPlayer

-- Nuke old instances
for _, container in ipairs({CoreGui, LocalPlayer:FindFirstChild("PlayerGui")}) do
    if container then
        pcall(function()
            local old = container:FindFirstChild("EmsHubUI")
            if old then old:Destroy() end
        end)
    end
end

local EmsUI = {Instances = {}}
Spirit.EmsUI = EmsUI

-- Palette — monochrome base + single warm amber accent
local C = {
    bg        = Color3.fromRGB(11, 11, 13),
    surface   = Color3.fromRGB(18, 18, 21),
    surface2  = Color3.fromRGB(24, 24, 28),
    line      = Color3.fromRGB(38, 38, 44),
    text      = Color3.fromRGB(232, 232, 234),
    textDim   = Color3.fromRGB(107, 107, 114),
    textFaint = Color3.fromRGB(74, 74, 82),
    accent    = Color3.fromRGB(229, 181, 103),
    ok        = Color3.fromRGB(111, 207, 142),
}

local FONT_LABEL = Enum.Font.Gotham
local FONT_VALUE = Enum.Font.RobotoMono
local FONT_BRAND = Enum.Font.GothamBlack
local FONT_CODE  = Enum.Font.Code

-- Root
local gui = Instance.new("ScreenGui")
gui.Name           = "EmsHubUI"
gui.Parent         = CoreGui
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 100
gui.IgnoreGuiInset = true
EmsUI.ScreenGui = gui

-- Panel — thin sidebar, anchored left
local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Parent           = gui
panel.AnchorPoint      = Vector2.new(0, 0.5)
panel.Position         = UDim2.new(0, 24, 0.5, 0)
panel.Size             = UDim2.new(0, 340, 0, 400)
panel.BackgroundColor3 = C.bg
panel.BorderSizePixel  = 0
panel.Active           = true
panel.Draggable        = true
panel.ClipsDescendants = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = C.line
panelStroke.Thickness = 1
EmsUI.Panel = panel

-- Header
local header = Instance.new("Frame")
header.Parent           = panel
header.Size             = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = C.bg
header.BorderSizePixel  = 0

local brandDot = Instance.new("Frame")
brandDot.Parent           = header
brandDot.Position         = UDim2.new(0, 14, 0, 18)
brandDot.Size             = UDim2.new(0, 8, 0, 8)
brandDot.BackgroundColor3 = C.accent
brandDot.BorderSizePixel  = 0
Instance.new("UICorner", brandDot).CornerRadius = UDim.new(1, 0)

local brand = Instance.new("TextLabel")
brand.Parent              = header
brand.BackgroundTransparency = 1
brand.Position            = UDim2.new(0, 28, 0, 0)
brand.Size                = UDim2.new(1, -100, 1, 0)
brand.Text                = "EMS"
brand.Font                = FONT_BRAND
brand.TextSize            = 14
brand.TextColor3          = C.text
brand.TextXAlignment      = Enum.TextXAlignment.Left

-- Live pill (right side of header)
local statusPill = Instance.new("Frame")
statusPill.Parent           = header
statusPill.AnchorPoint      = Vector2.new(1, 0.5)
statusPill.Position         = UDim2.new(1, -14, 0.5, 0)
statusPill.Size             = UDim2.new(0, 62, 0, 20)
statusPill.BackgroundColor3 = C.surface2
statusPill.BorderSizePixel  = 0
Instance.new("UICorner", statusPill).CornerRadius = UDim.new(1, 0)

local pillDot = Instance.new("Frame")
pillDot.Parent           = statusPill
pillDot.Position         = UDim2.new(0, 8, 0.5, -3)
pillDot.Size             = UDim2.new(0, 6, 0, 6)
pillDot.BackgroundColor3 = C.ok
pillDot.BorderSizePixel  = 0
Instance.new("UICorner", pillDot).CornerRadius = UDim.new(1, 0)

local pillText = Instance.new("TextLabel")
pillText.Parent              = statusPill
pillText.BackgroundTransparency = 1
pillText.Position            = UDim2.new(0, 18, 0, 0)
pillText.Size                = UDim2.new(1, -22, 1, 0)
pillText.Text                = "LIVE"
pillText.Font                = FONT_LABEL
pillText.TextSize            = 10
pillText.TextColor3          = C.textDim
pillText.TextXAlignment      = Enum.TextXAlignment.Left

-- Divider under header
local div = Instance.new("Frame")
div.Parent           = panel
div.Position         = UDim2.new(0, 14, 0, 44)
div.Size             = UDim2.new(1, -28, 0, 1)
div.BackgroundColor3 = C.line
div.BorderSizePixel  = 0

-- Stat grid — 2x2
local grid = Instance.new("Frame")
grid.Parent              = panel
grid.Position            = UDim2.new(0, 14, 0, 58)
grid.Size                = UDim2.new(1, -28, 0, 134)
grid.BackgroundTransparency = 1
local gridLayout = Instance.new("UIGridLayout", grid)
gridLayout.CellSize    = UDim2.new(0.5, -6, 0, 62)
gridLayout.CellPadding = UDim2.new(0, 12, 0, 10)
gridLayout.SortOrder   = Enum.SortOrder.LayoutOrder

local function statCell(label, order)
    local cell = Instance.new("Frame")
    cell.Parent           = grid
    cell.LayoutOrder      = order
    cell.BackgroundColor3 = C.surface
    cell.BorderSizePixel  = 0
    Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Parent              = cell
    lbl.BackgroundTransparency = 1
    lbl.Position            = UDim2.new(0, 12, 0, 8)
    lbl.Size                = UDim2.new(1, -24, 0, 12)
    lbl.Text                = label
    lbl.Font                = FONT_LABEL
    lbl.TextSize            = 9
    lbl.TextColor3          = C.textDim
    lbl.TextXAlignment      = Enum.TextXAlignment.Left

    local val = Instance.new("TextLabel")
    val.Parent              = cell
    val.BackgroundTransparency = 1
    val.Position            = UDim2.new(0, 12, 0, 22)
    val.Size                = UDim2.new(1, -24, 0, 32)
    val.Text                = "—"
    val.Font                = FONT_VALUE
    val.TextSize            = 20
    val.TextColor3          = C.text
    val.TextXAlignment      = Enum.TextXAlignment.Left
    val.TextYAlignment      = Enum.TextYAlignment.Top
    val.TextTruncate        = Enum.TextTruncate.AtEnd
    return val
end

EmsUI.LevelLabel = statCell("LEVEL", 1)
EmsUI.BeliLabel  = statCell("BELI", 2)
EmsUI.FragLabel  = statCell("FRAGMENTS", 3)
EmsUI.RaceLabel  = statCell("RACE", 4)

-- Status block
local statusBlock = Instance.new("Frame")
statusBlock.Parent           = panel
statusBlock.Position         = UDim2.new(0, 14, 0, 202)
statusBlock.Size             = UDim2.new(1, -28, 0, 62)
statusBlock.BackgroundColor3 = C.surface
statusBlock.BorderSizePixel  = 0
Instance.new("UICorner", statusBlock).CornerRadius = UDim.new(0, 6)

local statusLbl = Instance.new("TextLabel")
statusLbl.Parent              = statusBlock
statusLbl.BackgroundTransparency = 1
statusLbl.Position            = UDim2.new(0, 12, 0, 8)
statusLbl.Size                = UDim2.new(1, -24, 0, 12)
statusLbl.Text                = "STATUS"
statusLbl.Font                = FONT_LABEL
statusLbl.TextSize            = 9
statusLbl.TextColor3          = C.textDim
statusLbl.TextXAlignment      = Enum.TextXAlignment.Left

local mainTaskLbl = Instance.new("TextLabel")
mainTaskLbl.Parent              = statusBlock
mainTaskLbl.BackgroundTransparency = 1
mainTaskLbl.Position            = UDim2.new(0, 12, 0, 22)
mainTaskLbl.Size                = UDim2.new(1, -24, 0, 18)
mainTaskLbl.Text                = "Idle"
mainTaskLbl.Font                = FONT_CODE
mainTaskLbl.TextSize            = 12
mainTaskLbl.TextColor3          = C.text
mainTaskLbl.TextXAlignment      = Enum.TextXAlignment.Left
mainTaskLbl.TextTruncate        = Enum.TextTruncate.AtEnd

local subTaskLbl = Instance.new("TextLabel")
subTaskLbl.Parent              = statusBlock
subTaskLbl.BackgroundTransparency = 1
subTaskLbl.Position            = UDim2.new(0, 12, 0, 40)
subTaskLbl.Size                = UDim2.new(1, -24, 0, 16)
subTaskLbl.Text                = "—"
subTaskLbl.Font                = FONT_CODE
subTaskLbl.TextSize            = 11
subTaskLbl.TextColor3          = C.textDim
subTaskLbl.TextXAlignment      = Enum.TextXAlignment.Left
subTaskLbl.TextTruncate        = Enum.TextTruncate.AtEnd

EmsUI.StatusLabel    = mainTaskLbl
EmsUI.SubStatusLabel = subTaskLbl

-- Item strip — pill row
local itemRow = Instance.new("Frame")
itemRow.Parent              = panel
itemRow.Position            = UDim2.new(0, 14, 0, 274)
itemRow.Size                = UDim2.new(1, -28, 0, 24)
itemRow.BackgroundTransparency = 1
local itemLayout = Instance.new("UIListLayout", itemRow)
itemLayout.FillDirection = Enum.FillDirection.Horizontal
itemLayout.Padding       = UDim.new(0, 6)
itemLayout.SortOrder     = Enum.SortOrder.LayoutOrder

local itemDots = {}
local function makeItemPill(short, order)
    local pill = Instance.new("Frame")
    pill.Parent           = itemRow
    pill.LayoutOrder      = order
    pill.Size             = UDim2.new(0, 68, 1, 0)
    pill.BackgroundColor3 = C.surface
    pill.BorderSizePixel  = 0
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Parent           = pill
    dot.Position         = UDim2.new(0, 8, 0.5, -3)
    dot.Size             = UDim2.new(0, 6, 0, 6)
    dot.BackgroundColor3 = C.textFaint
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel")
    lbl.Parent              = pill
    lbl.BackgroundTransparency = 1
    lbl.Position            = UDim2.new(0, 18, 0, 0)
    lbl.Size                = UDim2.new(1, -22, 1, 0)
    lbl.Text                = short
    lbl.Font                = FONT_LABEL
    lbl.TextSize            = 10
    lbl.TextColor3          = C.textFaint
    lbl.TextXAlignment      = Enum.TextXAlignment.Left
    return dot, lbl
end

local ghDot, ghLbl = makeItemPill("GH", 1)
local cdkDot, cdkLbl = makeItemPill("CDK", 2)
local sgDot, sgLbl = makeItemPill("SG", 3)
local vhDot, vhLbl = makeItemPill("VH", 4)
itemDots.GodHuman    = {dot = ghDot, lbl = ghLbl}
itemDots.CDK         = {dot = cdkDot, lbl = cdkLbl}
itemDots.SkullGuitar = {dot = sgDot, lbl = sgLbl}
itemDots.Valkyrie    = {dot = vhDot, lbl = vhLbl}

-- Footer
local footer = Instance.new("Frame")
footer.Parent              = panel
footer.AnchorPoint         = Vector2.new(0, 1)
footer.Position            = UDim2.new(0, 14, 1, -14)
footer.Size                = UDim2.new(1, -28, 0, 20)
footer.BackgroundTransparency = 1

local uptimeLbl = Instance.new("TextLabel")
uptimeLbl.Parent              = footer
uptimeLbl.BackgroundTransparency = 1
uptimeLbl.Position            = UDim2.new(0, 0, 0, 0)
uptimeLbl.Size                = UDim2.new(0.5, 0, 1, 0)
uptimeLbl.Text                = "00:00:00"
uptimeLbl.Font                = FONT_CODE
uptimeLbl.TextSize            = 11
uptimeLbl.TextColor3          = C.textFaint
uptimeLbl.TextXAlignment      = Enum.TextXAlignment.Left

local redeemLbl = Instance.new("TextLabel")
redeemLbl.Parent              = footer
redeemLbl.BackgroundTransparency = 1
redeemLbl.Position            = UDim2.new(0.5, 0, 0, 0)
redeemLbl.Size                = UDim2.new(0.5, 0, 1, 0)
redeemLbl.Text                = ""
redeemLbl.Font                = FONT_LABEL
redeemLbl.TextSize            = 10
redeemLbl.TextColor3          = C.textFaint
redeemLbl.TextXAlignment      = Enum.TextXAlignment.Right
redeemLbl.TextTruncate        = Enum.TextTruncate.AtEnd

EmsUI.TimerLabel = uptimeLbl

-- Collapse button
local collapseBtn = Instance.new("TextButton")
collapseBtn.Name             = "EmsFloat"
collapseBtn.Parent           = gui
collapseBtn.AnchorPoint      = Vector2.new(0, 0.5)
collapseBtn.Position         = UDim2.new(0, 14, 0.5, 0)
collapseBtn.Size             = UDim2.new(0, 32, 0, 32)
collapseBtn.BackgroundColor3 = C.bg
collapseBtn.Text             = "E"
collapseBtn.TextColor3       = C.accent
collapseBtn.Font             = FONT_BRAND
collapseBtn.TextSize         = 14
collapseBtn.BorderSizePixel  = 0
collapseBtn.Draggable        = true
collapseBtn.Active           = true
collapseBtn.ZIndex           = 100
Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(1, 0)
local cbStroke = Instance.new("UIStroke", collapseBtn)
cbStroke.Color     = C.line
cbStroke.Thickness = 1

collapseBtn.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

-- ═══════════════════════════════════════════════════════════════
-- API — surface unchanged so the rest of the suite keeps working
-- ═══════════════════════════════════════════════════════════════
local _pending = { key = nil, text = nil, dirty = false }
function EmsUI.SetText(key, text)
    _pending.key   = key
    _pending.text  = text
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
                if key == "MainTextLabel" or key == "Task1" or key == "DebugLine" then
                    mainTaskLbl.Text = text
                elseif key == "Task2" then
                    subTaskLbl.Text = text
                elseif key == "LiveTime" then
                    uptimeLbl.Text = text
                end
            end)
        end
    end
end)

function EmsUI.SetStatus(text)    if text then mainTaskLbl.Text = tostring(text) end end
function EmsUI.SetSubStatus(text) if text then subTaskLbl.Text  = tostring(text) end end
function EmsUI.SetRedeemStatus(text)
    if text then redeemLbl.Text = tostring(text) end
end
function EmsUI.Toggle() panel.Visible = not panel.Visible end

function EmsUI.SetStats(data)
    if not data then return end
    pcall(function()
        if data.Level then EmsUI.LevelLabel.Text = tostring(data.Level) end
        if data.Beli then
            local b = tonumber(data.Beli) or 0
            local s
            if b >= 1e9 then s = string.format("%.2fB", b/1e9)
            elseif b >= 1e6 then s = string.format("%.2fM", b/1e6)
            elseif b >= 1e3 then s = string.format("%.1fK", b/1e3)
            else s = tostring(b) end
            EmsUI.BeliLabel.Text = "$" .. s
        end
        if data.Fragments then EmsUI.FragLabel.Text = tostring(data.Fragments) end
        if data.Race then EmsUI.RaceLabel.Text = tostring(data.Race) end
        if data.Elapsed then
            local h = math.floor(data.Elapsed / 3600)
            local m = math.floor((data.Elapsed % 3600) / 60)
            local s = math.floor(data.Elapsed % 60)
            uptimeLbl.Text = string.format("%02d:%02d:%02d", h, m, s)
        end
    end)
end

-- Item ownership refresh — greys out unowned pills, lights owned
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local bp = Spirit.ScriptStorage.Backpack
            local function set(slot, owned)
                local data = itemDots[slot]
                if data and data.dot and data.dot.Parent then
                    data.dot.BackgroundColor3 = owned and C.ok or C.textFaint
                    if data.lbl and data.lbl.Parent then
                        data.lbl.TextColor3 = owned and C.text or C.textFaint
                    end
                end
            end
            set("GodHuman",    bp["Godhuman"] ~= nil)
            set("CDK",         bp["Cursed Dual Katana"] ~= nil)
            set("SkullGuitar", bp["Skull Guitar"] ~= nil)
            set("Valkyrie",    bp["Valkyrie Helm"] ~= nil)
        end)
    end
end)

-- Stats refresh
task.spawn(function()
    local start = os.time() - (Spirit.OldSessionTime or 0)
    while task.wait(1) do
        pcall(function()
            local Data = LocalPlayer:FindFirstChild("Data")
            if not Data then return end

            local level = Data:FindFirstChild("Level")     and Data.Level.Value     or 0
            local beli  = Data:FindFirstChild("Beli")      and Data.Beli.Value      or 0
            local frag  = Data:FindFirstChild("Fragments") and Data.Fragments.Value or 0

            local raceName = "—"
            local raceObj  = Data:FindFirstChild("Race")
            if raceObj then
                if raceObj:IsA("StringValue") then raceName = raceObj.Value
                elseif raceObj:IsA("Folder") then
                    local v = raceObj:FindFirstChild("Value")
                    if v then raceName = v.Value end
                end
            end

            EmsUI.SetStats({
                Level = level, Beli = beli, Fragments = frag,
                Race = raceName,
                Elapsed = os.time() - start,
            })
        end)
    end
end)

_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
