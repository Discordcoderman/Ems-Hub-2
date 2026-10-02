-- level_gates.lua — ability ownership + purchase gate.
--
-- Owns the buy for Buso, Soru, Geppo (level 70) and Ken (300+).
-- Ownership is checked three ways per ability before any buy fires:
--   1. player tag     (Buso / Soru / FlashStep / Geppo / Skywalk / Ken)
--   2. character child (HasBuso / HasKen)
--   3. session flag   (set once a buy fires successfully this session)
-- If any of the three reports owned, no buy attempt is made.
--
-- Uses Spirit.OwnsAbility() from core.lua.
local Spirit = getgenv().Spirit
if not Spirit then error("[level_gates] core.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes

local ABILITY_LEVEL   = 70
local ABILITY_RETRY_S = 6
local lastAbilityTry  = {Buso = 0, Soru = 0, Geppo = 0}

local function buyAbility(name, invokeArg, sessionFlag)
    if Spirit.OwnsAbility(name) then return end

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
    buyAbility("Buso",  "Buso",  "_busoBought")
    buyAbility("Soru",  "Soru",  "_soruBought")
    buyAbility("Geppo", "Geppo", "_geppoBought")
end

-- ═══════════════════════════════════════════════════════════════
-- KEN V1
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
    return Spirit.OwnsItem("Saber")
end

local function tryKen()
    if Spirit.OwnsAbility("Ken") then
        Spirit.kenBought = true
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < KEN_LEVEL then return end
    if os.time() - kenLastTry < KEN_RETRY_S then return end
    kenLastTry = os.time()

    if not hasSaber() then return end

    local beli = ScriptStorage.PlayerData.Beli or 0
    if beli < KEN_COST then return end
    if not LocalPlayer.Character then return end

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
    if ok and res == 1 then
        Spirit.kenBought = true
    end
end

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
