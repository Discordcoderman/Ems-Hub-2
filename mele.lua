-- mele.lua — MeleesController: purchase chain + raid watcher
-- Every buy is gated on the previous melee's 400 mastery.
-- _G.MeleeBuyPending holds gacha until the chain completes.
local Spirit = getgenv().Spirit
if not Spirit then error("[mele] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[mele] tasks.lua not loaded") end

local ReplicatedStorage = Spirit.Services.ReplicatedStorage
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes
local SetTask           = Spirit.SetTask
local CheckItem         = Spirit.CheckItem

local TRAIN_SEQUENCE = {
    {name = "Black Leg",       target = 400},
    {name = "Electro",         target = 400},
    {name = "Fishman Karate",  target = 400},
    {name = "Dragon Claw",     target = 400},
    {name = "Superhuman",      target = 400},
    {name = "Death Step",      target = 400},
    {name = "Sharkman Karate", target = 400},
    {name = "Electric Claw",   target = 400},
    {name = "Dragon Talon",    target = 400},
}

local BUY_SEQUENCE = {
    { name = "Black Leg",       key = "BlackLeg",
      price = {Beli = 150000} },

    { name = "Electro",         key = "Electro",
      price = {Beli = 500000},
      needMastery = {{"Black Leg", 400}} },

    { name = "Fishman Karate",  key = "FishmanKarate",
      price = {Beli = 750000},
      needMastery = {{"Electro", 400}} },

    { name = "Dragon Claw",     key = "DragonClaw",
      price = {Fragments = 1500},
      needMastery = {{"Fishman Karate", 400}},
      needRaids = 3 },

    { name = "Superhuman",      key = "Superhuman",
      price = {Beli = 3000000},
      needMastery = {{"Black Leg", 400}, {"Electro", 400}, {"Fishman Karate", 400}} },

    { name = "Death Step",      key = "DeathStep",
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Black Leg", 400}},
      needKey = "Library Key" },

    { name = "Sharkman Karate", key = "SharkmanKarate",
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Fishman Karate", 400}},
      needKey = "Water Key" },

    { name = "Electric Claw",   key = "ElectricClaw",
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Electro", 400}} },

    { name = "Dragon Talon",    key = "DragonTalon",
      price = {Beli = 2500000, Fragments = 5000},
      needMastery = {{"Dragon Claw", 400}},
      needFireEssence = true },

    { name = "Godhuman",        key = "Godhuman",
      price = {Beli = 5000000, Fragments = 5000},
      needMastery = {{"Superhuman", 400}, {"Death Step", 400},
                     {"Sharkman Karate", 400}, {"Electric Claw", 400},
                     {"Dragon Talon", 400}},
      needMaterials = true },
}

local GODHUMAN_MATERIALS = {
    {"Dragon Scale",   10},
    {"Fish Tail",      20},
    {"Mystic Droplet", 10},
    {"Magma Ore",      20},
}

local mele = {currentTrainName = nil, currentTrainIdx = nil, lastMasteryCheck = 0}
Spirit.MeleeState = mele

local function masteryOf(name) return ScriptStorage.Melees[name] or 0 end

local function findTrainingMelee()
    local lastOwned
    for i, entry in ipairs(TRAIN_SEQUENCE) do
        if CheckItem(entry.name) then
            lastOwned = {name = entry.name, idx = i}
            if masteryOf(entry.name) < entry.target then
                return entry.name, i, entry.target
            end
        end
    end
    if lastOwned then return lastOwned.name, lastOwned.idx end
    return nil, nil, nil
end

local function findNextUnowned()
    for _, entry in ipairs(BUY_SEQUENCE) do
        if not CheckItem(entry.name) then return entry end
    end
    return nil
end

local function raidsDoneFor(entry)
    if not entry.needRaids then return 0 end
    return _G.MeleeRaidsDone or 0
end

local function HasStaticReqs(entry)
    if entry.needMastery then
        for _, req in ipairs(entry.needMastery) do
            if not CheckItem(req[1]) then return false end
            if masteryOf(req[1]) < req[2] then return false end
        end
    end
    if entry.needKey and not CheckItem(entry.needKey) then return false end
    if entry.needFireEssence and not CheckItem("Fire Essence") then return false end
    if entry.needMaterials then
        for _, mat in ipairs(GODHUMAN_MATERIALS) do
            local count = (ScriptStorage.Backpack[mat[1]] and ScriptStorage.Backpack[mat[1]].Count) or 0
            if count < mat[2] then return false end
        end
    end
    return true
end

local function HasPrice(entry)
    for cur, amount in pairs(entry.price or {}) do
        local have = (cur == "Beli"      and (ScriptStorage.PlayerData.Beli or 0))
                  or (cur == "Fragments" and (ScriptStorage.PlayerData.Fragments or 0))
                  or 0
        if have < amount then return false end
    end
    return true
end

local function GoToTeacher(meleeName)
    local teacher = Spirit.MeleeTeacher[meleeName]
    if not teacher then return true end
    local locs = Spirit.TeacherLocations[teacher]
    if not locs then return true end
    local cf = locs[Spirit.SeaIndex]
    if not cf then
        if Spirit.SeaIndex == 1 then
            Remotes.CommF_:InvokeServer("TravelDressrosa")
        elseif Spirit.SeaIndex == 2 then
            Remotes.CommF_:InvokeServer("TravelZou")
        end
        return false
    end
    if Spirit.CaculateDistance(cf) > 10 then
        Spirit.TweenController.Create(cf)
        return false
    end
    return true
end

local MC = Spirit.FunctionsHandler.MeleesController

MC:RegisterMethod("Refresh", function()
    if not Spirit.Config then return nil end
    if not Spirit.Config.Items or not Spirit.Config.Items.AutoFullyMelees then return nil end
    if not Spirit.Config.Melee or not Spirit.Config.Melee.AutoBuy then return nil end

    local next_buy = findNextUnowned()

    if not next_buy then
        _G.MeleeRaidRequest = false
        _G.MeleeBuyPending  = false
        return nil
    end

    if not (HasStaticReqs(next_buy) and HasPrice(next_buy)) then
        _G.MeleeRaidRequest = false
        _G.MeleeBuyPending  = true
        return nil
    end

    if next_buy.needRaids and raidsDoneFor(next_buy) < next_buy.needRaids then
        _G.MeleeRaidRequest = true
        _G.MeleeBuyPending  = true
        SetTask("MainTask", next_buy.name .. " prep | Raids "
            .. raidsDoneFor(next_buy) .. "/" .. next_buy.needRaids)
        return nil
    end

    _G.MeleeRaidRequest = false
    _G.MeleeBuyPending  = true
    return {kind = "buy", entry = next_buy}
end)

MC:RegisterMethod("Start", function(action)
    if not action or action.kind ~= "buy" then return end
    local entry = action.entry

    if not GoToTeacher(entry.name) then
        SetTask("MainTask", "Auto Melee | Moving to " .. entry.name .. " teacher")
        return
    end

    SetTask("MainTask", "Auto Melee | Buying " .. entry.name)
    Spirit.BuyMelee(entry.key, true)
    task.wait(0.3)
    Spirit.BuyMelee(entry.key)
    task.wait(0.6)
    Spirit.RefreshInventory()

    if entry.name == "Dragon Claw" then
        _G.MeleeRaidsDone = 0
    end

    if entry.name == "Godhuman" then
        _G.MeleeBuyPending = false
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MASTERY LOOP — every 4 minutes, pick the first owned melee
-- below its target and set _G.SelectWeapon
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(2) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.AutoFullyMelees) then return end
            local now = os.time()
            if now - mele.lastMasteryCheck < 240 then return end
            mele.lastMasteryCheck = now
            local target, idx, want = findTrainingMelee()
            if not target then return end
            mele.currentTrainName = target
            mele.currentTrainIdx  = idx
            _G.SelectWeapon = target
            SetTask("SubTask", "Training " .. target
                .. " (" .. masteryOf(target) .. "/" .. (want or 400) .. ")")
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- RAID COMPLETION WATCHER
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local inRaid, inRaidSince = false, 0
    while task.wait(2) do
        pcall(function()
            local RC = Spirit.FunctionsHandler.RaidController
            if not RC or not RC.Methods.GetCurrentRaidIsland then return end
            local island = RC.Methods.GetCurrentRaidIsland:Call()
            if island then
                if not inRaid then
                    inRaid = true
                    inRaidSince = tick()
                end
            elseif inRaid then
                if tick() - inRaidSince > 30 then
                    _G.MeleeRaidsDone = (_G.MeleeRaidsDone or 0) + 1
                end
                inRaid = false
                inRaidSince = 0
            end
        end)
    end
end)

Spirit.__mele_ready = true
