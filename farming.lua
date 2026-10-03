-- farming.lua — standalone farming tasks
--   · findMob searches ONLY workspace.Enemies — no ReplicatedStorage fallback
--   · V2MeleeTask handles Awakened Ice Admiral → Library Key → teacher
--   · AutoBossTask skips Tide Keeper + Awakened Ice Admiral
local Spirit = getgenv().Spirit
if not Spirit then error("[farming] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[farming] tasks.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask
local CheckItem     = Spirit.CheckItem

local function enabled(key)
    local F = Spirit.Config and Spirit.Config.Farming
    return F and F[key] == true
end

local function alive(model)
    if not model or not model.Parent then return false end
    -- Reject anything not parented to workspace.Enemies
    if model.Parent ~= workspace.Enemies then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

-- ═══════════════════════════════════════════════════════════════
-- findMob — workspace.Enemies ONLY. No ReplicatedStorage.
-- Returning a template model is what sends the character to Y=952.
-- ═══════════════════════════════════════════════════════════════
local function findMob(names)
    local best, bestDist = nil, math.huge
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return nil end

    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    for _, e in ipairs(enemies:GetChildren()) do
        local match = false
        if type(names) == "table" then
            match = table.find(names, e.Name) ~= nil
        else
            match = e.Name == names
        end
        if match then
            local h = e:FindFirstChildOfClass("Humanoid")
            local rp = e:FindFirstChild("HumanoidRootPart")
            if h and rp and h.Health > 0 then
                local d = (rp.Position - hrp.Position).Magnitude
                if d < bestDist then best, bestDist = e, d end
            end
        end
    end
    return best
end

local function matCount(name)
    local entry = ScriptStorage.Backpack[name]
    return entry and entry.Count or 0
end

local function hopAfter(delay)
    task.delay(delay or 3, function()
        pcall(function() Spirit.Hop() end)
    end)
end

local BOSS_SKIP = {
    ["Awakened Ice Admiral"] = true,
    ["Tide Keeper"]          = true,
}

-- ═══════════════════════════════════════════════════════════════
-- AUTO ELITE HUNTER
-- ═══════════════════════════════════════════════════════════════
local EH = Spirit.FunctionsHandler.AutoEliteHunterTask
local ehCooldown = 0
local ehTarget   = nil
local ehRequestPending = false

EH:RegisterMethod("Refresh", function()
    if not enabled("AutoEliteHunter") then return nil end
    if Spirit.SeaIndex ~= 3 then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1500 then return nil end
    if os.time() < ehCooldown then return nil end

    local questVisible = LocalPlayer.PlayerGui.Main.Quest.Visible
    local questText    = questVisible
        and LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text or ""

    if not questVisible then
        if ehRequestPending then return nil end
        ehRequestPending = true
        local ok, result = pcall(function()
            return Remotes.CommF_:InvokeServer("EliteHunter")
        end)
        ehRequestPending = false
        if ok and type(result) == "string" then
            local lower = result:lower()
            if lower:find("cooldown") or lower:find("wait") then
                ehCooldown = os.time() + 60
            end
        end
        return nil
    end

    for _, name in ipairs(Spirit.DOUGH_KING.eliteMobs) do
        if questText:find(name, 1, true) then
            ehTarget = name
            return "kill"
        end
    end
    return "kill"
end)

EH:RegisterMethod("Start", function(stage)
    if stage ~= "kill" then return end

    local mob = ehTarget and findMob(ehTarget) or findMob(Spirit.DOUGH_KING.eliteMobs)
    if mob then
        SetTask("MainTask", "Elite Hunter | " .. mob.Name)
        Spirit.CombatController.Attack(mob.Name)
    else
        SetTask("MainTask", "Elite Hunter | Hop — no elite spawned")
        if not EH:Get("hopQueued") or (os.time() - (EH:Get("hopQueued") or 0) > 5) then
            EH:Set("hopQueued", os.time())
            hopAfter(2)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO DOUGH KING
-- ═══════════════════════════════════════════════════════════════
local DK = Spirit.FunctionsHandler.AutoDoughKingTask

local function hasTool(name)
    return CheckItem(name) ~= false
end

local function bakeStage()
    if hasTool("Sweet Chalice") then return "summon" end
    if hasTool("God's Chalice") and matCount("Conjured Cocoa") >= Spirit.DOUGH_KING.cocoaTarget then
        return "trade"
    end
    if hasTool("God's Chalice") then return "cocoa" end
    return "elite"
end

DK:RegisterMethod("Refresh", function()
    if not enabled("AutoDoughKing") then return nil end
    if Spirit.SeaIndex ~= 3 then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1500 then return nil end

    if ScriptStorage.Backpack["Mirror Fractal"] then
        if Spirit.Config.Farming.DoughKingStopAfterMirror then return nil end
    end
    return bakeStage()
end)

DK:RegisterMethod("Start", function(stage)
    local cfg = Spirit.DOUGH_KING

    if stage == "elite" then
        SetTask("MainTask", "Dough King | Elite chain for God's Chalice")
        return
    end

    if stage == "cocoa" then
        SetTask("MainTask", "Dough King | Cocoa " .. matCount("Conjured Cocoa") .. "/" .. cfg.cocoaTarget)
        local mob = findMob(cfg.cocoaMobs)
        if mob then
            Spirit.CombatController.Attack(cfg.cocoaMobs)
        else
            Spirit.TweenController.Create(cfg.cocoaFarmCF)
        end
        return
    end

    if stage == "trade" then
        SetTask("MainTask", "Dough King | Trading Chalice + Cocoa")
        pcall(function()
            Remotes.CommF_:InvokeServer(cfg.tradeNPC)
        end)
        return
    end

    if stage == "summon" then
        local dk = Workspace.Enemies:FindFirstChild("Dough King")
        if dk and alive(dk) then
            SetTask("MainTask", "Dough King | Killing")
            Spirit.CombatController.Attack("Dough King")
            return
        end

        local cakeLoaf = Workspace.Map:FindFirstChild("CakeLoaf")
        if not cakeLoaf then
            SetTask("MainTask", "Dough King | Walking to Cake Loaf")
            Spirit.TweenController.Create(cfg.cakeAreaCF)
            return
        end

        SetTask("MainTask", "Dough King | Summoning")
        Spirit.TweenController.Create(cfg.doughKingCF)
        pcall(function()
            Remotes.CommF_:InvokeServer(cfg.spawnerRemote, true)
        end)
        return
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO MATERIAL
-- ═══════════════════════════════════════════════════════════════
local AM = Spirit.FunctionsHandler.AutoMaterialTask

AM:RegisterMethod("Refresh", function()
    if not enabled("AutoMaterial") then return nil end
    local F = Spirit.Config.Farming
    local pick = F.MaterialTarget
    if not pick or pick == "" then return nil end
    local source = Spirit.MATERIAL_SOURCES[pick]
    if not source then return nil end
    local target = F.MaterialTargetCount or 100
    if matCount(pick) >= target then return nil end
    return {name = pick, source = source, target = target}
end)

AM:RegisterMethod("Start", function(spec)
    local name, source, target = spec.name, spec.source, spec.target

    if source.sea and Spirit.SeaIndex ~= source.sea then
        SetTask("MainTask", "Material | Sailing to sea " .. source.sea)
        if source.sea == 2 then
            pcall(function() Remotes.CommF_:InvokeServer("TravelDressrosa") end)
        elseif source.sea == 3 then
            pcall(function() Remotes.CommF_:InvokeServer("TravelZou") end)
        end
        return
    end

    SetTask("MainTask", "Material | " .. name .. " " .. matCount(name) .. "/" .. target)

    local mob = findMob(source.mobs)
    if mob then
        Spirit.CombatController.Attack(source.mobs)
    else
        Spirit.TweenController.Create(source.cf)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- KILL AURA
-- ═══════════════════════════════════════════════════════════════
local KA = Spirit.FunctionsHandler.KillAuraTask

KA:RegisterMethod("Refresh", function()
    if not enabled("KillAura") then return nil end
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return nil end
    local radius = Spirit.Config.Farming.KillAuraRadius or 2000
    for _, e in ipairs(Workspace.Enemies:GetChildren()) do
        if alive(e) then
            local rp = e:FindFirstChild("HumanoidRootPart")
            if rp and (rp.Position - hrp.Position).Magnitude <= radius then
                return true
            end
        end
    end
    return nil
end)

KA:RegisterMethod("Start", function()
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return end
    local radius = Spirit.Config.Farming.KillAuraRadius or 2000

    pcall(function()
        sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
    end)

    for _, e in ipairs(Workspace.Enemies:GetChildren()) do
        if alive(e) then
            local rp = e:FindFirstChild("HumanoidRootPart")
            if rp and (rp.Position - hrp.Position).Magnitude <= radius then
                pcall(function()
                    e.Humanoid.Health = 0
                    e.Humanoid.WalkSpeed = 0
                    rp.CanCollide = false
                    if e:FindFirstChild("Head") then e.Head:Destroy() end
                    e:BreakJoints()
                end)
            end
        end
    end
    SetTask("SubTask", "Kill Aura | " .. radius .. " studs")
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO CHEST
-- ═══════════════════════════════════════════════════════════════
local AC = Spirit.FunctionsHandler.AutoChestTask
local chestCount  = 0
local lastChestAt = 0

AC:RegisterMethod("Refresh", function()
    if not enabled("AutoChest") then return nil end
    if os.time() - lastChestAt < 1 then return nil end

    if Spirit.Config.Farming.StopChestAtChalice then
        if CheckItem("God's Chalice") or CheckItem("Sweet Chalice")
           or CheckItem("Fist of Darkness") then
            return nil
        end
    end

    local tagged = game:GetService("CollectionService"):GetTagged("_ChestTagged")
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return nil end

    local best, bestDist = nil, math.huge
    for _, chest in ipairs(tagged) do
        if chest.Parent and not chest:GetAttribute("IsDisabled") then
            local p = chest:GetPivot().Position
            local d = (p - hrp.Position).Magnitude
            if d < bestDist then best, bestDist = chest, d end
        end
    end
    return best
end)

AC:RegisterMethod("Start", function(chest)
    lastChestAt = os.time()
    SetTask("MainTask", "Chest | " .. chest.Name)
    Spirit.TweenController.Create(chest:GetPivot())

    if Spirit.CaculateDistance(chest:GetPivot().Position) <= 10 then
        local hrp = Spirit.HumanoidRootPart
        if hrp and firetouchinterest then
            pcall(function()
                firetouchinterest(chest, hrp, 0)
                firetouchinterest(chest, hrp, 1)
            end)
        end
        chestCount = chestCount + 1
    end

    local F = Spirit.Config.Farming
    if F.AutoChestHop and chestCount >= (F.AutoChestCount or 20) then
        chestCount = 0
        hopAfter(2)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- SWORD MASTERY 600
-- ═══════════════════════════════════════════════════════════════
local SM = Spirit.FunctionsHandler.SwordMastery600Task

SM:RegisterMethod("Refresh", function()
    if not enabled("SwordMastery600") then return nil end
    local target = nil
    for _, entry in pairs(ScriptStorage.Backpack) do
        if entry.Type == "Sword" and (entry.Mastery or 0) < 600 then
            target = entry.Name
            break
        end
    end
    if not target then return nil end
    return target
end)

SM:RegisterMethod("Start", function(swordName)
    SetTask("MainTask", "Sword Mastery | " .. swordName)
    pcall(function()
        Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(swordName)
    end)

    local mob = findMob(Spirit.DOUGH_KING.cakeMobs)
    if mob then
        Spirit.CombatController.Attack(mob.Name)
    else
        Spirit.TweenController.Create(Spirit.DOUGH_KING.cakeAreaCF)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- AUTO BOSS — workspace.Enemies only, skips Ice Admiral + Tide Keeper
-- ═══════════════════════════════════════════════════════════════
local AB = Spirit.FunctionsHandler.AutoBossTask

AB:RegisterMethod("Refresh", function()
    if not enabled("AutoBoss") then return nil end
    local lv = ScriptStorage.PlayerData.Level or 0
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return nil end

    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local pick = nil
    for _, name in ipairs(Spirit.BossesOrder) do
        if not BOSS_SKIP[name] then
            local lvlReq = Spirit.BossesOrderLevel[name]
            if (not lvlReq) or lv >= lvlReq then
                local live = enemies:FindFirstChild(name)
                if live and alive(live) then
                    local rp = live:FindFirstChild("HumanoidRootPart")
                    if rp and (rp.Position - hrp.Position).Magnitude <= 5000 then
                        pick = name
                        break
                    end
                end
            end
        end
    end
    return pick
end)

AB:RegisterMethod("Start", function(bossName)
    SetTask("MainTask", "Boss | " .. bossName)
    Spirit.CombatController.Attack(bossName)
end)

-- ═══════════════════════════════════════════════════════════════
-- V2 MELEE FLOW
-- ═══════════════════════════════════════════════════════════════
local V2 = Spirit.FunctionsHandler.V2MeleeTask

local V2_MELEE_MAP = {
    ["Death Step"]      = {teacher = "Phoeyu, the Reformed", sea = 2,
                           v1 = "Black Leg",      buyId = "DeathStep"},
    ["Sharkman Karate"] = {teacher = "Sharkman Teacher",      sea = 2,
                           v1 = "Fishman Karate", buyId = "SharkmanKarate"},
    ["Electric Claw"]   = {teacher = "Previous Hero",          sea = 3,
                           v1 = "Electro",        buyId = "ElectricClaw"},
    ["Dragon Talon"]    = {teacher = "Uzoth",                  sea = 3,
                           v1 = "Dragon Claw",    buyId = "DragonTalon"},
}

local function getCurrentMeleeTarget()
    local order = Spirit.MASTERY_TRAIN_ORDER or {}
    local owned = ScriptStorage.Melees or {}
    local bp    = ScriptStorage.Backpack or {}
    for _, entry in ipairs(order) do
        if not bp[entry.name] then return entry end
        local m = owned[entry.name]
        if m and m < entry.target then return entry end
    end
    return nil
end

local function hasLibraryKey()
    if ScriptStorage.Backpack["Library Key"] then return true end
    local char = LocalPlayer.Character
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    if char and char:FindFirstChild("Library Key") then return true end
    if bp and bp:FindFirstChild("Library Key") then return true end
    return false
end

V2:RegisterMethod("Refresh", function()
    local target = getCurrentMeleeTarget()
    if not target then return nil end
    local spec = V2_MELEE_MAP[target.name]
    if not spec then return nil end
    local v1M = ScriptStorage.Melees[spec.v1] or 0
    if v1M < 400 then return nil end
    return {name = target.name, spec = spec}
end)

V2:RegisterMethod("Start", function(task)
    local name, spec = task.name, task.spec

    if Spirit.SeaIndex ~= spec.sea then
        SetTask("MainTask", "V2 Melee | Sailing to sea " .. spec.sea .. " for " .. name)
        if spec.sea == 2 then
            pcall(function() Remotes.CommF_:InvokeServer("TravelDressrosa") end)
        elseif spec.sea == 3 then
            pcall(function() Remotes.CommF_:InvokeServer("TravelZou") end)
        end
        return
    end

    if not hasLibraryKey() then
        SetTask("MainTask", "V2 Melee | Awakened Ice Admiral — Library Key")
        local enemies = Workspace:FindFirstChild("Enemies")
        local admiral = enemies and enemies:FindFirstChild("Awakened Ice Admiral")
        local admiralLive = admiral
            and admiral:FindFirstChild("Humanoid")
            and admiral.Humanoid.Health > 0
        if admiralLive then
            Spirit.CombatController.Attack("Awakened Ice Admiral")
        else
            local targetCF = (Spirit.SEA2 and Spirit.SEA2.ICE_DOOR_CF)
                or CFrame.new(1406, 87, -1376)
            Spirit.TweenController.Create(targetCF + Vector3.new(0, 20, 0))
        end
        return
    end

    SetTask("MainTask", "V2 Melee | Deliver key to " .. spec.teacher)
    local teacher
    for _, folder in ipairs({
        workspace:FindFirstChild("NPCs"),
        game.ReplicatedStorage:FindFirstChild("NPCs"),
    }) do
        if folder then
            teacher = folder:FindFirstChild(spec.teacher)
            if not teacher then
                for _, npc in ipairs(folder:GetChildren()) do
                    if npc:IsA("Model") then
                        if string.find(npc.Name, spec.teacher, 1, true)
                           or string.find(spec.teacher, npc.Name, 1, true) then
                            teacher = npc
                            break
                        end
                    end
                end
            end
            if teacher then break end
        end
    end

    if not teacher then
        Spirit.Report("[V2] Teacher not found: " .. spec.teacher)
        return
    end

    local teacherCF
    pcall(function()
        if teacher:FindFirstChild("HumanoidRootPart") then
            teacherCF = teacher.HumanoidRootPart.CFrame
        else
            teacherCF = teacher:GetModelCFrame()
        end
    end)
    if not teacherCF then return end

    local dist = Spirit.CaculateDistance(teacherCF.Position)
    if dist > 12 then
        Spirit.TweenController.Create(teacherCF + Vector3.new(0, 3, 3))
        return
    end

    pcall(function() Spirit.BuyMelee(spec.buyId, true) end)
    task.wait(0.4)
    pcall(function() Spirit.BuyMelee(spec.buyId) end)
    task.wait(0.4)
    Spirit.RefreshInventory()
end)

Spirit.__farming_ready = true
