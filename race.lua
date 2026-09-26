-- race.lua — EvoRace V2 + RaceAwakening V3 + Wenlocktoad
local Spirit = getgenv().Spirit
if not Spirit then error("[race] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[race] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local LocalPlayer   = Spirit.LocalPlayer
local SetTask       = Spirit.SetTask

-- ═══════════════════════════════════════════════════════════════
-- RACE V2 (EvoRace)
-- Alchemist chain — Flowers 1, 2, 3 → consume → race V2.
--   Flower 1: touch world object "Flower1" (Fountain City area)
--   Flower 2: touch world object "Flower2"
--   Flower 3: drops from Swan Pirates (Sea 2, level 900+)
-- ═══════════════════════════════════════════════════════════════
local EVO = Spirit.FunctionsHandler.EvoRace

EVO:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.RaceV2) then return nil end
    if Spirit.SeaIndex ~= 2 then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 900 then return nil end
    if (ScriptStorage.PlayerData.Beli or 0) < 1000000 then return nil end
    if ScriptStorage.PlayerData.RaceLevel ~= 1 then return nil end
    return true
end)

EVO:RegisterMethod("Start", function()
    -- Server-side flag for the Alchemist quest. "1" begins the flow.
    Remotes.CommF_:InvokeServer("Alchemist", "1")
    Remotes.CommF_:InvokeServer("Alchemist", "2")

    for i = 1, 2 do
        SetTask("SubTask", "RaceV2 | Flower " .. i)
        local tool  = ScriptStorage.Tools["Flower " .. i]
        local world = workspace:FindFirstChild("Flower" .. i)
        if not tool and world and world.Transparency == 0 then
            SetTask("MainTask", "Auto Race V2 | Flower " .. i)
            local deadline = tick() + 45
            while not ScriptStorage.Tools["Flower " .. i] and tick() < deadline do
                task.wait()
                Spirit.TweenController.Create(world.CFrame + Vector3.new(0, math.random(-1, 2), 0))
            end
        end
    end

    if not ScriptStorage.Tools["Flower 3"] then
        SetTask("MainTask", "RaceV2 | Farming Swan Pirate")
        Spirit.CombatController.Attack("Swan Pirate")
    else
        SetTask("MainTask", "RaceV2 | Completing")
        local char = LocalPlayer.Character
        if char and char.HumanoidRootPart and char.HumanoidRootPart.CFrame.Y < 50000 then
            Spirit.TweenController.Create(char.HumanoidRootPart.CFrame + Vector3.new(0, 50, 0))
        end
        Remotes.CommF_:InvokeServer("Alchemist", "3")
        Spirit.RefreshRace()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- RACE AWAKENING (V3)
-- Wenlocktoad chain. Race-specific:
--   Human:  Jeremy → Diamond → Orbitus (3 bosses)
--   Rabbit: 30 chest models in sequence
--   Fishman: Fishman Karate Z on Sea Beasts
-- ═══════════════════════════════════════════════════════════════
local RA = Spirit.FunctionsHandler.RaceAwakening
local state = {humanStage = 0, minkChests = 0}

local HUMAN_WAIT_CF = {
    [0] = CFrame.new(2333.209228515625, 449.2427062988281, 699.5128784179688),
    [1] = CFrame.new(-1713.5589599609375, 198.99554443359375, -104.31584167480469),
    [2] = CFrame.new(-2148.7568359375, 73.27831268310547, -4304.4130859375),
}
local HUMAN_BOSS = {[0] = "Jeremy", [1] = "Diamond", [2] = "Orbitus"}

RA:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoRaceV3) then return nil end
    local data = LocalPlayer:FindFirstChild("Data")
    if not data or not data:FindFirstChild("Race") then return nil end
    if data.Race:FindFirstChild("Evolved") then return nil end
    local race = data.Race.Value
    if race ~= "Human" and race ~= "Fishman" and race ~= "Rabbit" then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1400 then return nil end
    if (ScriptStorage.PlayerData.Beli or 0) < 2000000 then return nil end
    -- Wenlocktoad check "3" returns -2 when already evolved.
    local ok, wRes = pcall(function() return Remotes.CommF_:InvokeServer("Wenlocktoad", "3") end)
    if ok and wRes == -2 then return nil end
    return true
end)

RA:RegisterMethod("Start", function()
    local data = LocalPlayer:FindFirstChild("Data")
    if not data or not data:FindFirstChild("Race") then return end
    local race  = data.Race.Value
    local check = Remotes.CommF_:InvokeServer("Wenlocktoad", "1")

    -- Wenlocktoad state machine:
    --   0 = not started → "2" begins
    --   2 = trials complete → "3" finishes
    --   1 = trials in progress (fall through to race logic)
    if check == 0 then
        Remotes.CommF_:InvokeServer("Wenlocktoad", "2")
        return
    elseif check == 2 then
        Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
        return
    elseif check ~= 1 then
        return
    end

    if race == "Human" then
        if state.humanStage >= 3 then
            Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
            state.humanStage = 0
            return
        end
        local bossName = HUMAN_BOSS[state.humanStage]
        local boss     = ScriptStorage.Enemies[bossName]
        if not boss then
            Spirit.TweenController.Create(HUMAN_WAIT_CF[state.humanStage])
            return
        end
        if boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
            SetTask("MainTask", "RaceV3 | " .. bossName)
            Spirit.CombatController.Attack(bossName)
        else
            state.humanStage = state.humanStage + 1
        end

    elseif race == "Rabbit" then
        if state.minkChests >= 30 then
            Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
            return
        end
        local folder = workspace:FindFirstChild("ChestModels")
        if not folder then return end
        local chests = folder:GetChildren()
        local chest  = chests[state.minkChests + 1]
        if chest and chest:FindFirstChild("WorldPivot") then
            Spirit.TweenController.Create(chest.WorldPivot.Position)
            if Spirit.CaculateDistance(chest.WorldPivot.Position) < 10 then
                state.minkChests = state.minkChests + 1
            end
        end

    elseif race == "Fishman" then
        SetTask("MainTask", "RaceV3 | Fishman — Sea Beast")
        local beasts = workspace:FindFirstChild("SeaBeasts")
        if not beasts then Spirit.Hop() return end
        pcall(function() Remotes.CommF_:InvokeServer("BuyFishmanKarate") end)
        for _, b in ipairs(beasts:GetChildren()) do
            local h   = b:FindFirstChild("Health")
            local hrp = b:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Value > 0 then
                Spirit.TweenController.Create(hrp.CFrame * CFrame.new(0, 3, 0))
                pcall(function()
                    Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Fishman Karate")
                    Spirit.SendKey("Z", 0.3)
                end)
                return
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Wenlocktoad — stub (Real work is in RaceAwakening above)
-- ═══════════════════════════════════════════════════════════════
local WT = Spirit.FunctionsHandler.Wenlocktoad
WT:RegisterMethod("Refresh", function() return nil end)
WT:RegisterMethod("Start", function() end)

Spirit.__race_ready = true
