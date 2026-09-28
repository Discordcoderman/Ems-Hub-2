-- race.lua — EvoRace V2 + RaceAwakening V3 + Wenlocktoad
--
-- Gate: BOTH V2 and V3 require SeaIndex == 3 (player has reached Zou)
-- and Beli >= 2,500,000. Before that, race tasks stay idle.
--
--   V2 → travels to Sea 2, gathers Flower 1, Flower 2, kills Swan
--        Pirates for Flower 3, then returns to Alchemist.
--   V3 → Wenlocktoad trials on Sea 3 for Human / Rabbit / Fishman.
--        Races outside that set are skipped silently.
local Spirit = getgenv().Spirit
if not Spirit then error("[race] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[race] tasks.lua not loaded") end

local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local LocalPlayer   = Spirit.LocalPlayer
local SetTask       = Spirit.SetTask

local RACE_BELI = 2500000

local function raceUnlocked()
    -- Player must be in Zou (Sea 3) — that's the unlock marker.
    return Spirit.SeaIndex == 3
end

local function raceMoneyReady()
    return (ScriptStorage.PlayerData.Beli or 0) >= RACE_BELI
end

-- ═══════════════════════════════════════════════════════════════
-- RACE V2 (EvoRace)
-- ═══════════════════════════════════════════════════════════════
local EVO = Spirit.FunctionsHandler.EvoRace

EVO:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.RaceV2) then return nil end
    if not raceUnlocked() then return nil end
    if not raceMoneyReady() then return nil end
    -- Not V2 yet.
    if ScriptStorage.PlayerData.RaceLevel ~= 1 then return nil end
    return true
end)

EVO:RegisterMethod("Start", function()
    -- V2 gathers flowers on Sea 2. Travel there first.
    if Spirit.SeaIndex ~= 2 then
        SetTask("MainTask", "Auto Race V2 | Sailing to Dressrosa")
        pcall(function() Remotes.CommF_:InvokeServer("TravelDressrosa") end)
        return
    end

    Remotes.CommF_:InvokeServer("Alchemist", "1")
    Remotes.CommF_:InvokeServer("Alchemist", "2")

    for i = 1, 2 do
        SetTask("SubTask", "RaceV2 | Flower " .. i)
        local tool  = ScriptStorage.Tools["Flower " .. i]
        local world = workspace:FindFirstChild("Flower" .. i)
        if not tool and world and world.Transparency == 0 then
            SetTask("MainTask", "Auto Race V2 | Flower " .. i)
            while not ScriptStorage.Tools["Flower " .. i] do
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
-- Only Human, Rabbit, Fishman are handled. Others skip silently.
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

    if not raceUnlocked() then return nil end
    if not raceMoneyReady() then return nil end
    -- Must be V2 first.
    if ScriptStorage.PlayerData.RaceLevel < 2 then return nil end

    local ok, wRes = pcall(function() return Remotes.CommF_:InvokeServer("Wenlocktoad", "3") end)
    if ok and wRes == -2 then return nil end
    return true
end)

RA:RegisterMethod("Start", function()
    local data = LocalPlayer:FindFirstChild("Data")
    if not data or not data:FindFirstChild("Race") then return end
    local race  = data.Race.Value
    local check = Remotes.CommF_:InvokeServer("Wenlocktoad", "1")

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
            SetTask("MainTask", "RaceV3 | Waiting for " .. bossName)
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
        if not folder then
            SetTask("MainTask", "RaceV3 | Waiting for chests to spawn")
            return
        end
        local chests = folder:GetChildren()
        local chest  = chests[state.minkChests + 1]
        if chest and chest:FindFirstChild("WorldPivot") then
            SetTask("MainTask", "RaceV3 | Chest " .. (state.minkChests + 1) .. "/30")
            Spirit.TweenController.Create(chest.WorldPivot.Position)
            if Spirit.CaculateDistance(chest.WorldPivot.Position) < 10 then
                state.minkChests = state.minkChests + 1
            end
        end

    elseif race == "Fishman" then
        SetTask("MainTask", "RaceV3 | Fishman — Sea Beast")
        local beasts = workspace:FindFirstChild("SeaBeasts")
        if not beasts then
            SetTask("MainTask", "RaceV3 | Waiting for Sea Beast")
            return
        end

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

local WT = Spirit.FunctionsHandler.Wenlocktoad
WT:RegisterMethod("Refresh", function() return nil end)
WT:RegisterMethod("Start", function() end)

Spirit.__race_ready = true
