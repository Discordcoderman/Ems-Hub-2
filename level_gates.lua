-- level_gates.lua — ability ownership + purchase gate.
--
-- Owns the single source of truth for buying:
--   Buso  (Aura)     @ level 70
--   Soru  (Flash Step) @ level 70
--   Geppo (Sky Walk) @ level 70
--   Ken              @ level 300 + Saber + 750k Beli + Instinct Teacher
--
-- Sea 2 and Sea 3 transitions live in quest_sea2.lua / quest_sea3.lua.
-- This file does not touch them.
--
-- Ownership checked three ways per ability:
--   1. player tag (Buso / Soru / FlashStep / Geppo / Skywalk / Ken)
--   2. character child (HasBuso / HasKen)
--   3. session flag — set once a buy fires successfully
--
-- If ANY of the three reports owned, no buy attempt is made.
local Spirit = getgenv().Spirit
if not Spirit then error("[level_gates] core.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- OWNERSHIP CHECKS
-- ═══════════════════════════════════════════════════════════════
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
    if charHasChild("HasKen") then Spirit.kenBought = true; return true end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- LEVEL 70 ABILITIES — Buso, Soru, Geppo
-- Buy each at most once. Ownership gate skips every subsequent tick.
-- ═══════════════════════════════════════════════════════════════
local ABILITY_LEVEL = 70
local ABILITY_RETRY_S = 6
local lastAbilityTry = {Buso = 0, Soru = 0, Geppo = 0}

local function buyAbility(name, ownsFn, invokeArg, sessionFlag)
    if ownsFn() then return end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < ABILITY_LEVEL then return end
    if not LocalPlayer.Character then return end

    if os.time() - lastAbilityTry[name] < ABILITY_RETRY_S then return end
    lastAbilityTry[name] = os.time()

    local ok = pcall(function()
        Remotes.CommF_:InvokeServer("BuyHaki", invokeArg)
    end)
    if ok then
        Spirit[sessionFlag] = true
    end
end

local function tryBaseAbilities()
    buyAbility("Buso",  ownsBuso,  "Buso",  "_busoBought")
    buyAbility("Soru",  ownsSoru,  "Soru",  "_soruBought")
    buyAbility("Geppo", ownsGeppo, "Geppo", "_geppoBought")
end

-- ═══════════════════════════════════════════════════════════════
-- KEN V1 — level 300 + Saber + 750k Beli + Upper Skylands
-- ═══════════════════════════════════════════════════════════════
local KEN_LEVEL   = 300
local KEN_COST    = 750000
local KEN_RETRY_S = 6
local kenLastTry  = 0

local function findInstinctTeacher()
    local candidates = {
        workspace:FindFirstChild("NPCs"),
        game.ReplicatedStorage:FindFirstChild("NPCs"),
    }
    for _, folder in ipairs(candidates) do
        if folder then
            for _, npc in ipairs(folder:GetChildren()) do
                if npc.Name == "Instinct Teacher"
                   or npc.Name == "Lord of Destruction" then
                    local hrp = npc:FindFirstChild("HumanoidRootPart")
                    if hrp then return hrp.CFrame end
                    if npc:IsA("Model") then
                        return npc:GetModelCFrame()
                    end
                end
            end
        end
    end
    return nil
end

local UPPER_SKYLANDS_TEMPLE = CFrame.new(-7894, 5546, -380)

local function hasSaber()
    local char = LocalPlayer.Character
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    if char and char:FindFirstChild("Saber") then return true end
    if bp and bp:FindFirstChild("Saber") then return true end
    if ScriptStorage.Backpack and ScriptStorage.Backpack["Saber"] then return true end
    return false
end

local function tryKen()
    -- Already owned — nothing to do.
    if ownsKen() then
        Spirit.kenBought = true
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < KEN_LEVEL then return end

    if os.time() - kenLastTry < KEN_RETRY_S then return end
    kenLastTry = os.time()

    -- Gate 1: Saber must be owned.
    if not hasSaber() then return end

    -- Gate 2: Beli.
    local beli = ScriptStorage.PlayerData.Beli or 0
    if beli < KEN_COST then return end

    -- Gate 3: live character.
    if not LocalPlayer.Character then return end

    -- Gate 4: must be at the Instinct Teacher in Upper Skylands.
    local teacherCF = findInstinctTeacher() or UPPER_SKYLANDS_TEMPLE
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dist = (hrp.Position - teacherCF.Position).Magnitude
    if dist > 15 then
        Spirit.TweenController.Create(teacherCF + Vector3.new(0, 5, 3))
        return
    end

    local ok, res = pcall(function()
        return Remotes.CommF_:InvokeServer("KenTalk", "Buy")
    end)

    -- Server returns 1 for owned. Treat as success and latch.
    if ok and res == 1 then
        Spirit.kenBought = true
    end
end

-- ═══════════════════════════════════════════════════════════════
-- LOOP
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 60 do
        task.wait(0.5)
        waited = waited + 0.5
    end

    while task.wait(1) do
        pcall(tryBaseAbilities)
        pcall(tryKen)
    end
end)

Spirit.__level_gates_ready = true
