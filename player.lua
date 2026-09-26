-- player.lua — LocalPlayerController + ability activation.
--
-- Buy logic for Buso / Soru / Geppo / Ken lives in level_gates.lua.
-- This file handles:
--   - LocalPlayerController methods (EquipTool, ToggleAbilities)
--   - Auto-aura — keeps Buso active if owned. Never buys.
--   - Auto-Ken  — keeps Ken active if owned. Never buys.
--
-- Ownership reads fall through to the same three checks as
-- level_gates so no re-evaluation happens twice.
local Spirit = getgenv().Spirit
if not Spirit then error("[player] core.lua not loaded") end

local LocalPlayer = Spirit.LocalPlayer
local Remotes     = Spirit.Remotes

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

local function ownsKen()
    if Spirit.kenBought then return true end
    if playerHasTag("Ken") then Spirit.kenBought = true; return true end
    if charHasChild("HasKen") then Spirit.kenBought = true; return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- LocalPlayerController — methods registry
-- ═══════════════════════════════════════════════════════════════
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
-- AUTO KEN — keep Ken active only if owned
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
