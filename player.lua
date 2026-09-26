-- player.lua — LocalPlayerController + ability flow
--   Level 70  → Buso, Soru, Geppo
--   Ken @ 300 → owned by level_gates.lua, not here
-- Ownership checked 3 ways: player tag, character child, session flag.
local Spirit = getgenv().Spirit
if not Spirit then error("[player] core.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local Remotes       = Spirit.Remotes
local ScriptStorage = Spirit.ScriptStorage
local SetTask       = Spirit.SetTask

local ABILITY_LEVEL = 70

local function playerHasTag(tag)
    local ok, v = pcall(function() return LocalPlayer:HasTag(tag) end)
    return ok and v == true
end

local function charHasChild(name)
    local char = LocalPlayer.Character
    if not char then return false end
    return char:FindFirstChild(name) ~= nil
end

local function ownsBuso()
    if Spirit._busoBought then return true end
    if playerHasTag("Buso") then Spirit._busoBought = true; return true end
    if charHasChild("HasBuso") then Spirit._busoBought = true; return true end
    return false
end

local function ownsSoru()
    if Spirit._soruBought then return true end
    if playerHasTag("Soru") or playerHasTag("FlashStep") then
        Spirit._soruBought = true; return true
    end
    return false
end

local function ownsGeppo()
    if Spirit._geppoBought then return true end
    if playerHasTag("Geppo") or playerHasTag("Skywalk") then
        Spirit._geppoBought = true; return true
    end
    return false
end

local function ownsKen()
    if Spirit.kenBought then return true end
    if playerHasTag("Ken") then Spirit.kenBought = true; return true end
    return false
end

local LPC = Spirit.FunctionsHandler.LocalPlayerController

LPC:RegisterMethod("EquipTool", function(toolName)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") and (v.Name == tostring(toolName) or v.ToolTip == toolName) then return end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return end
    for _, v in ipairs(bp:GetChildren()) do
        if v:IsA("Tool") and v.Name ~= "Tool"
           and (v.Name == tostring(toolName) or v.ToolTip == toolName) then
            hum:EquipTool(v)
            return
        end
    end
end)

LPC:RegisterMethod("ToggleAbilities", function(ability, forceOn)
    if ability == "Buso" then
        local char = LocalPlayer.Character
        if not char then return end
        local has = char:FindFirstChild("HasBuso")
        if (forceOn and not has) or (not forceOn and has) then
            Remotes.CommF_:InvokeServer("Buso")
        end
    end
end)

LPC:RegisterMethod("ConfigurationAbilitiesToggle", function() end)

-- ═══════════════════════════════════════════════════════════════
-- ABILITY PURCHASE — fires once, then stops
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    repeat task.wait(1) until Spirit.Character and Spirit.Character:FindFirstChildOfClass("Humanoid")
    repeat task.wait(1) until LocalPlayer:FindFirstChild("Data")
    task.wait(3)

    while task.wait(5) do
        pcall(function()
            local lv = ScriptStorage.PlayerData.Level or 0
            if lv < ABILITY_LEVEL then return end
            if not LocalPlayer.Character then return end

            if not ownsBuso() then
                Remotes.CommF_:InvokeServer("BuyHaki", "Buso")
                Spirit._busoBought = true
            end

            if not ownsSoru() then
                Remotes.CommF_:InvokeServer("BuyHaki", "Soru")
                Spirit._soruBought = true
            end

            if not ownsGeppo() then
                Remotes.CommF_:InvokeServer("BuyHaki", "Geppo")
                Spirit._geppoBought = true
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO AURA — keep Buso active only if owned
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            if not ownsBuso() then return end
            local char = Spirit.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then return end
            if char:FindFirstChild("HasBuso") then return end
            Remotes.CommF_:InvokeServer("Buso")
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO KEN — only after Ken is owned (Ken buy is in level_gates)
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoKen) then return end
            if not ownsKen() then return end
            local char = Spirit.Character
            if not char then return end
            if char:FindFirstChild("HasKen") then return end
            local CommE = game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommE")
            if CommE then CommE:FireServer("Ken", true) end
        end)
    end
end)

Spirit.__player_ready = true
