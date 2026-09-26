-- ui.lua — EMS HUB purple theme panel
local Spirit = getgenv().Spirit
if not Spirit then error("[ui] core.lua not loaded") end

local Players      = Spirit.Players
local CoreGui      = Spirit.CoreGui
local TweenService = Spirit.TweenService
local LocalPlayer  = Spirit.LocalPlayer

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

local C = {
    panel      = Color3.fromRGB(18, 12, 26),
    border     = Color3.fromRGB(120, 60, 180),
    borderSoft = Color3.fromRGB(60, 30, 90),
    text       = Color3.fromRGB(230, 230, 240),
    muted      = Color3.fromRGB(150, 130, 170),
    purple     = Color3.fromRGB(200, 100, 255),
    pink       = Color3.fromRGB(255, 120, 200),
    green      = Color3.fromRGB(80, 220, 120),
    red        = Color3.fromRGB(230, 60, 80),
    rowBg      = Color3.fromRGB(28, 18, 40),
    accentBar  = Color3.fromRGB(60, 220, 100),
}

local gui = Instance.new("ScreenGui")
gui.Name           = "EmsHubUI"
gui.Parent         = CoreGui
gui.ResetOnSpawn   = false
gui.DisplayOrder   = 100
gui.IgnoreGuiInset = true
EmsUI.ScreenGui = gui

local panel = Instance.new("Frame")
panel.Name               = "Panel"
panel.Parent             = gui
panel.AnchorPoint        = Vector2.new(0.5, 0.5)
panel.Position           = UDim2.new(0.5, 0, 0.5, 0)
panel.Size               = UDim2.new(0, 540, 0, 420)
panel.BackgroundColor3   = C.panel
panel.BorderSizePixel    = 0
panel.Active             = true
panel.Draggable          = true
panel.ClipsDescendants   = true
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Color     = C.border
panelStroke.Thickness = 1.5

local panelGrad = Instance.new("UIGradient", panel)
panelGrad.Rotation = 90
panelGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 14, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 8, 20)),
}
EmsUI.Panel = panel

local accentBar = Instance.new("Frame")
accentBar.Parent           = panel
accentBar.Size             = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = C.accentBar
accentBar.BorderSizePixel  = 0
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 2)

local header = Instance.new("Frame")
header.Parent                = panel
header.Position              = UDim2.new(0, 0, 0, 3)
header.Size                  = UDim2.new(1, 0, 0, 44)
header.BackgroundTransparency = 1

local titleLbl = Instance.new("TextLabel")
titleLbl.Parent              = header
titleLbl.BackgroundTransparency = 1
titleLbl.AnchorPoint         = Vector2.new(0.5, 0)
titleLbl.Position            = UDim2.new(0.5, 0, 0, 8)
titleLbl.Size                = UDim2.new(1, -80, 0, 22)
titleLbl.Text                = "EMS HUB"
titleLbl.Font                = Enum.Font.GothamBold
titleLbl.TextSize            = 18
titleLbl.TextColor3          = C.purple
titleLbl.TextXAlignment      = Enum.TextXAlignment.Center
local titleGrad = Instance.new("UIGradient", titleLbl)
titleGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 130, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 200)),
}

local subtitleLbl = Instance.new("TextLabel")
subtitleLbl.Parent              = header
subtitleLbl.BackgroundTransparency = 1
subtitleLbl.AnchorPoint         = Vector2.new(0.5, 0)
subtitleLbl.Position            = UDim2.new(0.5, 0, 0, 28)
subtitleLbl.Size                = UDim2.new(1, -80, 0, 12)
subtitleLbl.Text                = "v3.0 · BLOX FRUITS"
subtitleLbl.Font                = Enum.Font.GothamBold
subtitleLbl.TextSize            = 9
subtitleLbl.TextColor3          = C.muted
subtitleLbl.TextXAlignment      = Enum.TextXAlignment.Center

local closeBtn = Instance.new("TextButton")
closeBtn.Parent                = header
closeBtn.AnchorPoint           = Vector2.new(1, 0)
closeBtn.Position              = UDim2.new(1, -10, 0, 10)
closeBtn.Size                  = UDim2.new(0, 22, 0, 22)
closeBtn.BackgroundColor3      = C.rowBg
closeBtn.Text                  = "×"
closeBtn.TextColor3            = C.muted
closeBtn.Font                  = Enum.Font.GothamBold
closeBtn.TextSize              = 16
closeBtn.BorderSizePixel       = 0
closeBtn.AutoButtonColor       = false
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

local divider = Instance.new("Frame")
divider.Parent           = panel
divider.Position         = UDim2.new(0, 12, 0, 52)
divider.Size             = UDim2.new(1, -24, 0, 1)
divider.BackgroundColor3 = C.borderSoft
divider.BorderSizePixel  = 0

local columns = Instance.new("Frame")
columns.Parent                = panel
columns.Position              = UDim2.new(0, 12, 0, 62)
columns.Size                  = UDim2.new(1, -24, 0, 290)
columns.BackgroundTransparency = 1
local colLayout = Instance.new("UIListLayout", columns)
colLayout.FillDirection = Enum.FillDirection.Horizontal
colLayout.Padding       = UDim.new(0, 12)
colLayout.SortOrder     = Enum.SortOrder.LayoutOrder

local leftCol = Instance.new("Frame")
leftCol.Parent                = columns
leftCol.LayoutOrder           = 1
leftCol.Size                  = UDim2.new(0.5, -6, 1, 0)
leftCol.BackgroundTransparency = 1

local leftHeader = Instance.new("TextLabel")
leftHeader.Parent              = leftCol
leftHeader.BackgroundTransparency = 1
leftHeader.Position            = UDim2.new(0, 4, 0, 0)
leftHeader.Size                = UDim2.new(1, 0, 0, 20)
leftHeader.Text                = "Account Stats"
leftHeader.Font                = Enum.Font.GothamBold
leftHeader.TextSize            = 13
leftHeader.TextColor3          = C.purple
leftHeader.TextXAlignment      = Enum.TextXAlignment.Left

local leftList = Instance.new("Frame")
leftList.Parent                = leftCol
leftList.Position              = UDim2.new(0, 0, 0, 26)
leftList.Size                  = UDim2.new(1, 0, 1, -26)
leftList.BackgroundTransparency = 1
local leftListLayout = Instance.new("UIListLayout", leftList)
leftListLayout.Padding   = UDim.new(0, 6)
leftListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeStatRow(label, order)
    local row = Instance.new("Frame")
    row.Parent               = leftList
    row.LayoutOrder          = order
    row.Size                 = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3     = C.rowBg
    row.BackgroundTransparency = 0.4
    row.BorderSizePixel      = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Parent              = row
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position            = UDim2.new(0, 10, 0, 4)
    nameLbl.Size                = UDim2.new(1, -20, 0, 13)
    nameLbl.Text                = label
    nameLbl.Font                = Enum.Font.GothamBold
    nameLbl.TextSize            = 9
    nameLbl.TextColor3          = C.muted
    nameLbl.TextXAlignment      = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel")
    valLbl.Parent              = row
    valLbl.BackgroundTransparency = 1
    valLbl.Position            = UDim2.new(0, 10, 0, 18)
    valLbl.Size                = UDim2.new(1, -20, 0, 18)
    valLbl.Text                = "—"
    valLbl.Font                = Enum.Font.GothamBold
    valLbl.TextSize            = 13
    valLbl.TextColor3          = C.text
    valLbl.TextXAlignment      = Enum.TextXAlignment.Left
    valLbl.TextTruncate        = Enum.TextTruncate.AtEnd
    return valLbl
end

EmsUI.LevelLabel = makeStatRow("LEVEL", 1)
EmsUI.RaceLabel  = makeStatRow("RACE", 2)
EmsUI.BeliLabel  = makeStatRow("BELI", 3)
EmsUI.FragLabel  = makeStatRow("FRAGMENTS", 4)
EmsUI.MeleeLabel = makeStatRow("TRAINING", 5)
EmsUI.TimerLabel = makeStatRow("UPTIME", 6)

local rightCol = Instance.new("Frame")
rightCol.Parent                = columns
rightCol.LayoutOrder           = 2
rightCol.Size                  = UDim2.new(0.5, -6, 1, 0)
rightCol.BackgroundTransparency = 1

local rightHeader = Instance.new("TextLabel")
rightHeader.Parent              = rightCol
rightHeader.BackgroundTransparency = 1
rightHeader.Position            = UDim2.new(0, 4, 0, 0)
rightHeader.Size                = UDim2.new(1, 0, 0, 20)
rightHeader.Text                = "Account Items"
rightHeader.Font                = Enum.Font.GothamBold
rightHeader.TextSize            = 13
rightHeader.TextColor3          = C.pink
rightHeader.TextXAlignment      = Enum.TextXAlignment.Left

local rightList = Instance.new("Frame")
rightList.Parent                = rightCol
rightList.Position              = UDim2.new(0, 0, 0, 26)
rightList.Size                  = UDim2.new(1, 0, 1, -26)
rightList.BackgroundTransparency = 1
local rightListLayout = Instance.new("UIListLayout", rightList)
rightListLayout.Padding   = UDim.new(0, 6)
rightListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeItemRow(label, order)
    local row = Instance.new("Frame")
    row.Parent               = rightList
    row.LayoutOrder          = order
    row.Size                 = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3     = C.rowBg
    row.BackgroundTransparency = 0.4
    row.BorderSizePixel      = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local dot = Instance.new("Frame")
    dot.Parent           = row
    dot.AnchorPoint      = Vector2.new(0, 0.5)
    dot.Position         = UDim2.new(0, 10, 0.5, 0)
    dot.Size             = UDim2.new(0, 10, 0, 10)
    dot.BackgroundColor3 = C.red
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Parent              = row
    nameLbl.BackgroundTransparency = 1
    nameLbl.Position            = UDim2.new(0, 28, 0, 0)
    nameLbl.Size                = UDim2.new(1, -34, 1, 0)
    nameLbl.Text                = label
    nameLbl.Font                = Enum.Font.GothamBold
    nameLbl.TextSize            = 11
    nameLbl.TextColor3          = C.text
    nameLbl.TextXAlignment      = Enum.TextXAlignment.Left
    return dot
end

local itemDots = {
    GodHuman    = makeItemRow("GodHuman", 1),
    CDK         = makeItemRow("Cursed Dual Katana", 2),
    Valkyrie    = makeItemRow("Valkyrie Helm", 3),
    SkullGuitar = makeItemRow("Skull Guitar", 4),
    MirrorFract = makeItemRow("Mirror Fractal", 5),
    PullLever   = makeItemRow("Pull Lever", 6),
}

local footerBox = Instance.new("Frame")
footerBox.Parent               = panel
footerBox.Position             = UDim2.new(0, 12, 1, -58)
footerBox.Size                 = UDim2.new(1, -24, 0, 46)
footerBox.BackgroundColor3     = C.rowBg
footerBox.BackgroundTransparency = 0.4
footerBox.BorderSizePixel      = 0
Instance.new("UICorner", footerBox).CornerRadius = UDim.new(0, 6)

local statusText = Instance.new("TextLabel")
statusText.Parent              = footerBox
statusText.BackgroundTransparency = 1
statusText.Position            = UDim2.new(0, 12, 0, 4)
statusText.Size                = UDim2.new(1, -24, 0, 18)
statusText.Text                = "Idle"
statusText.Font                = Enum.Font.GothamBold
statusText.TextSize            = 11
statusText.TextColor3          = C.text
statusText.TextXAlignment      = Enum.TextXAlignment.Left
statusText.TextTruncate        = Enum.TextTruncate.AtEnd

local subStatusText = Instance.new("TextLabel")
subStatusText.Parent              = footerBox
subStatusText.BackgroundTransparency = 1
subStatusText.Position            = UDim2.new(0, 12, 0, 22)
subStatusText.Size                = UDim2.new(1, -24, 0, 18)
subStatusText.Text                = "Waiting..."
subStatusText.Font                = Enum.Font.Gotham
subStatusText.TextSize            = 10
subStatusText.TextColor3          = C.muted
subStatusText.TextXAlignment      = Enum.TextXAlignment.Left
subStatusText.TextTruncate        = Enum.TextTruncate.AtEnd

EmsUI.StatusLabel    = statusText
EmsUI.SubStatusLabel = subStatusText

local floatBtn = Instance.new("TextButton")
floatBtn.Name             = "EmsFloat"
floatBtn.Parent           = gui
floatBtn.Size             = UDim2.new(0, 48, 0, 48)
floatBtn.AnchorPoint      = Vector2.new(0, 0.5)
floatBtn.Position         = UDim2.new(0, 15, 0.5, -24)
floatBtn.BackgroundColor3 = C.panel
floatBtn.Text             = "E"
floatBtn.TextColor3       = C.purple
floatBtn.Font             = Enum.Font.FredokaOne
floatBtn.TextSize         = 22
floatBtn.BorderSizePixel  = 0
floatBtn.Draggable        = true
floatBtn.Active           = true
floatBtn.ZIndex           = 100
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
local fbStroke = Instance.new("UIStroke", floatBtn)
fbStroke.Color     = C.border
fbStroke.Thickness = 1.5
floatBtn.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)

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
                    statusText.Text = text
                elseif key == "Task2" then
                    subStatusText.Text = text
                elseif key == "LiveTime" then
                    EmsUI.TimerLabel.Text = text
                end
            end)
        end
    end
end)

function EmsUI.SetStatus(text)    if text then statusText.Text = tostring(text) end end
function EmsUI.SetSubStatus(text) if text then subStatusText.Text = tostring(text) end end
function EmsUI.SetRedeemStatus(_) end
function EmsUI.Toggle() panel.Visible = not panel.Visible end

function EmsUI.SetStats(data)
    if not data then return end
    pcall(function()
        if data.Level then EmsUI.LevelLabel.Text = tostring(data.Level) end
        if data.Beli then
            local b = tonumber(data.Beli) or 0
            local s
            if b >= 1e9 then s = string.format("$%.2fB", b/1e9)
            elseif b >= 1e6 then s = string.format("$%.2fM", b/1e6)
            elseif b >= 1e3 then s = string.format("$%.1fK", b/1e3)
            else s = "$" .. tostring(b) end
            EmsUI.BeliLabel.Text = s
        end
        if data.Fragments then EmsUI.FragLabel.Text = tostring(data.Fragments) end
        if data.Race then EmsUI.RaceLabel.Text = tostring(data.Race) end
        if data.Melee then EmsUI.MeleeLabel.Text = tostring(data.Melee) end
        if data.Elapsed then
            local h = math.floor(data.Elapsed / 3600)
            local m = math.floor((data.Elapsed % 3600) / 60)
            local s = math.floor(data.Elapsed % 60)
            EmsUI.TimerLabel.Text = string.format("%dh %dm %ds", h, m, s)
        end
    end)
end

task.spawn(function()
    while task.wait(2) do
        pcall(function()
            local bp = Spirit.ScriptStorage.Backpack
            local function set(name, owned)
                local d = itemDots[name]
                if d and d.Parent then d.BackgroundColor3 = owned and C.green or C.red end
            end
            set("GodHuman",    bp["Godhuman"] ~= nil)
            set("CDK",         bp["Cursed Dual Katana"] ~= nil)
            set("Valkyrie",    bp["Valkyrie Helm"] ~= nil)
            set("SkullGuitar", bp["Skull Guitar"] ~= nil)
            set("MirrorFract", bp["Mirror Fractal"] ~= nil)
            pcall(function()
                local ok = Spirit.Remotes.CommF_:InvokeServer("CheckTempleDoor")
                set("PullLever", ok == true)
            end)
        end)
    end
end)

task.spawn(function()
    local start = os.time() - (Spirit.OldSessionTime or 0)
    while task.wait(1) do
        pcall(function()
            local Data = LocalPlayer:FindFirstChild("Data")
            if not Data then return end

            local level = Data:FindFirstChild("Level")     and Data.Level.Value     or 0
            local beli  = Data:FindFirstChild("Beli")      and Data.Beli.Value      or 0
            local frag  = Data:FindFirstChild("Fragments") and Data.Fragments.Value or 0

            local raceName = "Unknown"
            local raceObj  = Data:FindFirstChild("Race")
            if raceObj then
                if raceObj:IsA("StringValue") then raceName = raceObj.Value
                elseif raceObj:IsA("Folder") then
                    local v = raceObj:FindFirstChild("Value")
                    if v then raceName = v.Value end
                end
            end

            local meleeStr = "—"
            for _, mm in ipairs(Spirit.MASTERY_TRAIN_ORDER or {}) do
                local mst = Spirit.ScriptStorage.Melees[mm.name]
                if mst ~= nil then
                    if mst < mm.target then
                        meleeStr = mm.name .. " " .. mst .. "/" .. mm.target
                        break
                    end
                end
            end

            EmsUI.SetStats({
                Level = level, Beli = beli, Fragments = frag,
                Race  = raceName, Melee = meleeStr,
                Elapsed = os.time() - start,
            })
        end)
    end
end)

_G.EmsUI = EmsUI
getgenv().EmsUI = EmsUI
Spirit.EmsUI = EmsUI
Spirit.__ui_ready = true
