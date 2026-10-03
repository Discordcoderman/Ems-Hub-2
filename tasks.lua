-- tasks.lua — FunctionsHandler registry + TasksOrder + priority dispatcher
local Spirit = getgenv().Spirit
if not Spirit then error("[tasks] core.lua not loaded") end

local FunctionsHandler = {Initalized = false}
Spirit.FunctionsHandler = FunctionsHandler

setmetatable(FunctionsHandler, {
    __index = function(FH, key)
        local existing = rawget(FH, key)
        if existing and existing.Initalized then return existing end

        return {
            Initalized = false,
            Register = function(enable)
                if enable == false then return end

                local Result = {
                    CacheListener = {},
                    RealCache     = {},
                    Methods       = {},
                    Constants     = {},
                    Events        = {},
                    Initalized    = true,
                }

                function Result.RegisterMethod(self, name, callback)
                    self.Methods[name] = {
                        Name     = name,
                        Callback = callback,
                        Call     = function(_, ...) return callback(...) end,
                        Events   = {},
                    }
                    return true
                end

                setmetatable(Result.Constants, {
                    __newindex = function()
                        assert(false, "cannot change constant value!")
                    end,
                })

                function Result.Set(self, k, v)
                    self.CacheListener[k] = v
                    return v
                end

                function Result.Get(self, k)
                    return self.Constants[k] or self.RealCache[k]
                end

                function Result.AddVariableChangeListener(self, k, handler)
                    self.Events[k] = handler
                end

                Result.CacheListener.__parent = Result
                setmetatable(Result.CacheListener, {
                    __newindex = function(t, k, v)
                        local parent = rawget(t, "__parent")
                        if parent then
                            local handler = parent.Events[k]
                            if handler then
                                pcall(handler, k, v)
                            end
                            parent.RealCache[k] = v
                        end
                    end,
                })

                rawset(FH, key, Result)
            end,
        }
    end,
})

function FunctionsHandler.SynchorizeUntilModuleLoaded(module, timeout)
    local start = os.time()
    while not module.Initalized do
        task.wait()
        local elapsed = os.time() - start
        assert(not (timeout and elapsed > timeout), "timed out")
    end
end

local TASKS_TO_REGISTER = {
    "LocalPlayerController","ExpRedeem","LevelFarm","Saber","Rengoku","Yama","Tushita",
    "SpikeyTrident","SharkAchor","Pole","FoxLamp","DarkDagger","Canvander","BuddySword",
    "HallowScythe","CursedDualKatana","AcidumRifle","Kabucha","VenomBow","SoulGuitar",
    "DragonStorm","InsictV2","RainbowSaviour","DarkBladeV2","SecondSeaPuzzle",
    "ColosseumPuzzle","Trevor","EvoRace","Wenlocktoad","DarkBladeV3","ThirdSeaPuzzle",
    "DojoQuest","RaceAwakening","PirateRaid","SwordBossTask","CakePrinceTask",
    "RaidController","AutoRaidIce","MeleesController","Superhuman","DeathStep",
    "SharkmanKarate","ElectricClaw","DragonTalon","Godhuman","BossesTask",
    "SpecialBossesTask","CollectDrops","CollectBerries","UtillyItemsActivitation",
    "AutoEliteHunterTask", "AutoDoughKingTask", "AutoMaterialTask",
    "KillAuraTask", "AutoChestTask", "SwordMastery600Task", "AutoBossTask",
    "V2MeleeTask",
}
for _, taskName in ipairs(TASKS_TO_REGISTER) do
    FunctionsHandler[taskName]:Register()
end

Spirit.TasksOrder = {
    "Saber",
    "MeleesController",
    "V2MeleeTask",              -- V2 melee flow, before bosses
    "CollectDrops",
    "AutoEliteHunterTask",
    "AutoDoughKingTask",
    "AutoMaterialTask",
    "SwordMastery600Task",
    "AutoBossTask",
    "KillAuraTask",
    "AutoChestTask",
    "SpecialBossesTask", "SwordBossTask", "BossesTask",
    "RaidController", "AutoRaidIce",
    "LevelFarm",
    "Tushita", "Yama", "CursedDualKatana", "SoulGuitar",
    "EvoRace", "RaceAwakening",
    "Trevor", "UtillyItemsActivitation",
    "ColosseumPuzzle", "ThirdSeaPuzzle",
    "SecondSeaPuzzle",
}

local ParsingTimes = 0
Spirit.ParsingTimes = ParsingTimes

local warnedTasks = {}
Spirit.CurrentTask = nil

local function runFruitPriority()
    if not _G.FruitPriorityActive then return false end
    local cd = FunctionsHandler.CollectDrops
    if cd and cd.Initalized and cd.Methods and cd.Methods.Refresh then
        local r = cd.Methods.Refresh:Call(Spirit.ParsingTimes < 100)
        if r then
            Spirit.ParsingTimes = Spirit.ParsingTimes + 1
            if Spirit.EmsUI and Spirit.EmsUI.SetText then
                Spirit.EmsUI.SetText("DebugLine", "CollectDrops")
            end
            if cd.Methods.Start then cd.Methods.Start:Call(r) end
            return true
        end
    end
    _G.FruitPriorityActive = false
    return false
end

local function runRaidPriority()
    local RC = FunctionsHandler.RaidController

    local raidActive = false
    if RC and RC.Initalized and RC.Methods.GetCurrentRaidIsland then
        raidActive = RC.Methods.GetCurrentRaidIsland:Call() ~= nil
    end

    if not (raidActive or _G.MeleeRaidRequest) then return false end

    Spirit.ParsingTimes = Spirit.ParsingTimes + 1
    Spirit.CurrentTask = "RaidController"
    if Spirit.EmsUI and Spirit.EmsUI.SetText then
        Spirit.EmsUI.SetText("DebugLine", "RaidController")
    end

    if RC and RC.Initalized and RC.Methods.Start then
        RC.Methods.Start:Call()
    end
    return true
end

local function runFactoryCore()
    local enemyFolder = workspace:FindFirstChild("Enemies")
    if not enemyFolder then return false end
    local core = enemyFolder:FindFirstChild("Core")
    if not core then return false end
    local hum = core:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end

    Spirit.ParsingTimes = Spirit.ParsingTimes + 1
    Spirit.CurrentTask = "FactoryCore"
    if Spirit.EmsUI and Spirit.EmsUI.SetText then
        Spirit.EmsUI.SetText("DebugLine", "FactoryCore")
    end
    Spirit.SetTask("MainTask", "Factory Core | Engaging")
    Spirit.CombatController.Attack("Core")
    return true
end

local function runPirateRaidPriority()
    local PR = FunctionsHandler.PirateRaid
    if not PR or not PR.Initalized then return false end
    if not PR.Methods.Refresh then return false end

    local r = PR.Methods.Refresh:Call(Spirit.ParsingTimes < 100)
    if not r then return false end

    Spirit.ParsingTimes = Spirit.ParsingTimes + 1
    Spirit.CurrentTask = "PirateRaid"
    if Spirit.EmsUI and Spirit.EmsUI.SetText then
        Spirit.EmsUI.SetText("DebugLine", "PirateRaid")
    end
    if PR.Methods.Start then PR.Methods.Start:Call(r) end
    return true
end

-- Nothing enabled, nothing running — stay put.
local function allWorkDisabled()
    local cfg = Spirit.Config
    if not cfg then return false end
    if not cfg.Farming then return false end

    local anyFarmingActive =
        cfg.Farming.AutoEliteHunter or cfg.Farming.AutoDoughKing
        or cfg.Farming.AutoMaterial   or cfg.Farming.KillAura
        or cfg.Farming.AutoChest      or cfg.Farming.SwordMastery600
        or cfg.Farming.AutoBoss
    if anyFarmingActive then return false end

    local anyItemsActive = cfg.Items and (
        cfg.Items.Saber or cfg.Items.AutoFullyMelees
        or cfg.Items.CursedDualKatana or cfg.Items.SoulGuitar
        or cfg.Items.RaceV2 or cfg.Items.AutoRaceV3
    )
    if anyItemsActive then return false end

    if cfg.AutoSea2 then return false end
    if cfg.AutoSea3 then return false end
    if cfg.AutoRaidIce_TargetFragments and cfg.AutoRaidIce_TargetFragments > 0 then return false end

    return true
end

function Spirit.RefreshTasksData()
    if _G.Stop then return end
    if _G.SeaTransitionActive then return end
    if _G.SkyTransitionActive then return end

    if allWorkDisabled() then
        Spirit.SetTask("MainTask", "Idle")
        Spirit.SetTask("SubTask", "—")
        return
    end

    if runFruitPriority()      then return end
    if runRaidPriority()       then return end
    if runFactoryCore()        then return end
    if runPirateRaidPriority() then return end

    for _, taskName in ipairs(Spirit.TasksOrder) do
        local handler = FunctionsHandler[taskName]

        if not handler.Initalized then
            if not warnedTasks[taskName] then
                warnedTasks[taskName] = true
            end
        else
            local refresh = handler.Methods.Refresh
            local start   = handler.Methods.Start

            if refresh then
                local result = refresh:Call(Spirit.ParsingTimes < 100)
                Spirit.ParsingTimes = Spirit.ParsingTimes + 1
                ParsingTimes = Spirit.ParsingTimes

                if result and Spirit.ParsingTimes > 100 then
                    Spirit.CurrentTask = taskName
                    if Spirit.EmsUI and Spirit.EmsUI.SetText then
                        Spirit.EmsUI.SetText("DebugLine", taskName)
                    end
                    if start then start:Call(result) end
                    return
                end
            end
        end
    end
end

Spirit.__tasks_ready = true
