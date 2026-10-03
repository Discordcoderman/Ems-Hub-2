-- bosses.lua — BossesTask, SpecialBossesTask, CakePrinceTask,
--              RaidController, AutoRaidIce
local Spirit = getgenv().Spirit
if not Spirit then error("[bosses] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[bosses] tasks.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes
local SetTask           = Spirit.SetTask
local CheckItem         = Spirit.CheckItem

local BOSS_SKIP = {
    ["Awakened Ice Admiral"] = true,
    ["Tide Keeper"]          = true,
}

local function ConfirmBossDead(bossName)
    for _ = 1, 6 do
        task.wait(0.3)
        local enemies = workspace:FindFirstChild("Enemies")
        local live = enemies and enemies:FindFirstChild(bossName)
        if live and live:FindFirstChild("Humanoid") and live.Humanoid.Health > 0 then
            return false
        end
    end
    return true
end

local function ResetAfterKill(name)
    if not ConfirmBossDead(name) then
        SetTask("SubTask", name .. " phase change — continuing")
        return
    end
    SetTask("SubTask", "Defeated " .. name .. " — reset")
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 0
        LocalPlayer.CharacterAdded:Wait()
    end
end

local BT = Spirit.FunctionsHandler.BossesTask

BT:RegisterMethod("Refresh", function()
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local picked
    for _, name in ipairs(Spirit.BossesOrder) do
        if not BOSS_SKIP[name] then
            local cfgBoss = Spirit.Config and Spirit.Config.BossWeapons
            if not cfgBoss or cfgBoss[name] ~= false then
                local lvl = Spirit.BossesOrderLevel[name]
                if lvl and (ScriptStorage.PlayerData.Level or 0) >= lvl then
                    local live = enemies:FindFirstChild(name)
                    if live and live:FindFirstChild("Humanoid") and live.Humanoid.Health > 0 then
                        picked = live
                    end
                end
            end
        end
    end
    if not picked then return nil end
    local dist = Spirit.CaculateDistance(picked.HumanoidRootPart.CFrame)
    if dist < (Spirit.SeaIndex == 2 and 3000 or 5000)
       or Spirit.BossesOrderWL[tostring(picked)]
       or ScriptStorage.PlayerData.Level == Spirit.MaxLevel then
        return picked
    end
end)

BT:RegisterMethod("Start", function(boss)
    if not boss then return end
    SetTask("MainTask", "Boss | " .. boss.Name)
    SetTask("SubTask", "HP " .. math.floor(boss.Humanoid.Health / boss.Humanoid.MaxHealth * 100) .. "%")
    Spirit.CombatController.Attack(tostring(boss))
    pcall(function()
        if boss.Parent == nil or (boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0) then
            ResetAfterKill(boss.Name)
        end
    end)
end)

local ST = Spirit.FunctionsHandler.SpecialBossesTask

ST:RegisterMethod("Refresh", function()
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local picked
    for name, lvl in pairs(Spirit.SpecialBossesOrder) do
        local cfgBoss = Spirit.Config and Spirit.Config.BossWeapons
        if (not cfgBoss or cfgBoss[name] ~= false) and (ScriptStorage.PlayerData.Level or 0) >= lvl then
            local live = enemies:FindFirstChild(name)
            if live and live:FindFirstChild("Humanoid") and live.Humanoid.Health > 0 then
                picked = live
            end
        end
    end
    if not picked then
        pcall(function()
            local b = Spirit.Remotes.CommF_:InvokeServer("Bones", "Check")
            if b and b > 0 then
                Spirit.Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
            end
        end)
    end
    return picked
end)

ST:RegisterMethod("Start", function(boss)
    if not boss then return end
    SetTask("MainTask", "Special Boss | " .. boss.Name)
    Spirit.CombatController.Attack(tostring(boss))
    pcall(function()
        if boss.Parent == nil or (boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0) then
            ResetAfterKill(boss.Name)
        end
    end)
end)

local CAKE_AREA_CF = CFrame.new(-2077, 252, -12373)
local CAKE_BOSS_CF = CFrame.new(-2151.82, 149.32, -12404.91)
local UNLOCK_MOBS  = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"}

local function CurrentTrainingMelee()
    for _, m in ipairs(Spirit.MASTERY_TRAIN_ORDER) do
        if CheckItem(m.name) then
            local mst = ScriptStorage.Melees[m.name] or 0
            if mst < m.target then return m.name, mst, m.target end
        end
    end
    return nil
end

local CP = Spirit.FunctionsHandler.CakePrinceTask

CP:RegisterMethod("Refresh", function()
    if Spirit.SeaIndex ~= 3 then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1500 then return nil end
    local name = CurrentTrainingMelee()
    if not name then return nil end
    return name
end)

CP:RegisterMethod("Start", function(trainingName)
    if not trainingName then return end
    local mastery, target = ScriptStorage.Melees[trainingName] or 0, 500
    for _, m in ipairs(Spirit.MASTERY_TRAIN_ORDER) do
        if m.name == trainingName then target = m.target break end
    end

    if mastery >= target then
        SetTask("SubTask", trainingName .. " done (" .. mastery .. ")")
        return
    end

    pcall(function()
        Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(trainingName)
    end)

    local cakeLoaf  = workspace.Map:FindFirstChild("CakeLoaf")
    local bigMirror = cakeLoaf and cakeLoaf:FindFirstChild("BigMirror")
    local enemies   = workspace.Enemies

    if not cakeLoaf then
        SetTask("MainTask", "Cake Mastery | " .. trainingName .. " (" .. mastery .. "/" .. target .. ") moving")
        Spirit.TweenController.Create(CAKE_AREA_CF)
        return
    end

    local mirrorOpen = bigMirror and bigMirror:FindFirstChild("Other") and bigMirror.Other.Transparency == 0
    local bossUp     = enemies:FindFirstChild("Cake Prince")

    if mirrorOpen or bossUp then
        local boss = enemies:FindFirstChild("Cake Prince")
        if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
            SetTask("MainTask", "Cake Mastery | " .. trainingName .. " (" .. mastery .. "/" .. target .. ")")
            Spirit.TweenController.Create(boss.HumanoidRootPart.CFrame + Vector3.new(0, 30, 0))
            Spirit.CombatController.Attack("Cake Prince")
        else
            Spirit.TweenController.Create(CAKE_BOSS_CF)
        end
        return
    end

    SetTask("MainTask", "Cake Mastery | " .. trainingName .. " (" .. mastery .. "/" .. target .. ") grinding")
    local killedStr = Remotes.CommF_:InvokeServer("CakePrinceSpawner")
    local killed = killedStr and tonumber(tostring(killedStr):match("%d+")) or 0
    local remaining = math.max(0, 500 - killed)

    if remaining <= 0 then
        Remotes.CommF_:InvokeServer("CakePrinceSpawner", true)
        task.wait(1)
        return
    end

    SetTask("MainTask", "Cake Prince | Unlock mobs — " .. remaining .. "/500")
    local mob
    for _, mobName in ipairs(UNLOCK_MOBS) do
        local m = enemies:FindFirstChild(mobName)
        if m and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0 then mob = m break end
    end
    if mob then
        Spirit.TweenController.Create(mob.HumanoidRootPart.CFrame + Vector3.new(0, 5, 0))
        Spirit.CombatController.Attack(UNLOCK_MOBS)
    else
        Spirit.TweenController.Create(CAKE_AREA_CF)
    end
end)

local RC = Spirit.FunctionsHandler.RaidController

RC:RegisterMethod("RefreshRaidType", function()
    local ok, raids = pcall(function() return require(ReplicatedStorage.Raids).raids end)
    if ok and raids then
        for _, r in pairs(raids) do
            if string.find(tostring(ScriptStorage.PlayerData.DevilFruit or ""), r) then
                RC:Set("CurrentChip", r)
                return
            end
        end
    end
    RC:Set("CurrentChip", "Flame")
end)

function Spirit.CheckSpecialMicrochip()
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    for _, container in ipairs({char, bp}) do
        if container then
            for _, v in ipairs(container:GetChildren()) do
                if v.Name == "Special Microchip" then return v end
            end
        end
    end
    return nil
end

local function pickCheapestFruit()
    for _, entry in pairs(ScriptStorage.Backpack) do
        if entry.Type == "Blox Fruit" or (entry.Name and entry.Name:find("Fruit")) then
            return entry
        end
    end
    for _, entry in pairs(ScriptStorage.Backpack) do
        if entry.Name and entry.Name:find("Fruit") then return entry end
    end
end

RC:RegisterMethod("GetCurrentRaidIsland", function()
    local origin = workspace:FindFirstChild("_WorldOrigin")
    if not origin or not origin:FindFirstChild("Locations") then return nil end
    local islands = {{}, {}, {}, {}, {}}
    for _, k in ipairs(origin.Locations:GetChildren()) do
        if string.find(k.Name, "Island ")
           and Spirit.CaculateDistance(k.Position, Vector3.new(0, 0, 0)) > 7000 then
            local num = tonumber(string.gsub(k.Name, "Island ", ""))
            if num and islands[num] then table.insert(islands[num], k) end
        end
    end
    for i = 5, 1, -1 do
        for _, isl in ipairs(islands[i]) do
            if Spirit.CaculateDistance(isl.Position) < 2000 then return isl end
        end
    end
    return nil
end)

RC:RegisterMethod("Refresh", function()
    if _G.MeleeRaidRequest then
        local island = RC.Methods.GetCurrentRaidIsland:Call()
        if island then return island end
        return true
    end

    local lv = ScriptStorage.PlayerData.Level or 0
    if lv < 1300 then return nil end
    if Spirit.CheckSpecialMicrochip() then return nil end
    local fr = ScriptStorage.PlayerData.Fragments or 0
    if lv < 1500 and fr > 2000 then return nil end
    if lv < Spirit.MaxLevel and fr > 5000 then return nil end
    if lv >= Spirit.MaxLevel and fr > 10000 then return nil end
    local fruit = pickCheapestFruit()
    if fruit then RC:Set("CurrentProgressLevel", fruit) end
    return fruit or RC.Methods.GetCurrentRaidIsland:Call() or Spirit.CheckSpecialMicrochip()
end)

RC:RegisterMethod("Start", function()
    if not RC:Get("CurrentChip") then RC.Methods.RefreshRaidType:Call() end
    local island = RC.Methods.GetCurrentRaidIsland:Call()
    Spirit.RefreshInventory()
    RC:Set("CurrentProgressLevel", nil)

    if not island then
        SetTask("MainTask", "Auto Raid | Buying chip - " .. RC:Get("CurrentChip"))
        if not Spirit.CheckSpecialMicrochip() then
            local fruit = pickCheapestFruit()
            if fruit then
                table.insert(ScriptStorage.IgnoreStoreFruits, fruit.Name)
                Remotes.CommF_:InvokeServer("LoadFruit", fruit.Name)
                Remotes.CommF_:InvokeServer("RaidsNpc", "Select", RC:Get("CurrentChip"))
                task.wait(2)
            end
        end
        local mapName = ({nil, "Circle Island", "Boat Castle"})[Spirit.SeaIndex]
        if mapName then
            local mapObj = workspace.Map:FindFirstChild(mapName) or workspace:FindFirstChild(mapName)
            if mapObj and not mapObj:FindFirstChild("RaidSummon2") then
                Spirit.TweenController.Create(mapObj:GetModelCFrame())
            end
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Special Microchip")
            local summon = mapObj and mapObj:FindFirstChild("RaidSummon2")
            if summon and summon:FindFirstChild("Button") then
                pcall(function() fireclickdetector(summon.Button.Main.ClickDetector) end)
            end
        end
        local t0 = os.time()
        repeat task.wait() until os.time() - (Spirit.LastRaidAlert2 or 0) < 20 or os.time() - t0 > 30
        if os.time() - t0 > 30 then
            ReplicatedStorage.__ServerBrowser:InvokeServer("teleport", game.JobId)
        end
    else
        SetTask("MainTask", "Auto Raid | " .. island.Name)
        local num = tonumber(string.match(island.Name, "(%d+)"))
        if num and num >= 4 then
            Spirit.TweenController.Create(island.Position + Vector3.new(0, 50, 0))
            task.wait(0.5)
            for _, v in ipairs(workspace.Enemies:GetChildren()) do
                pcall(function()
                    if v:FindFirstChild("Humanoid") then v.Humanoid.Health = 0 end
                    if v:FindFirstChild("HumanoidRootPart") then v.HumanoidRootPart.CanCollide = false end
                    v:BreakJoints()
                end)
            end
        else
            for _, e in ipairs(Spirit.GetMonAsSortedRange()) do
                if Spirit.CaculateDistance(e.HumanoidRootPart.Position) < 1000 then
                    Spirit.CombatController.Attack(e.Name)
                end
            end
        end
    end
end)

local ARI = Spirit.FunctionsHandler.AutoRaidIce
local ICE_CHIP_COOLDOWN = 2 * 60 * 60

ARI:RegisterMethod("GetCheapestFruit", function(maxPrice)
    maxPrice = maxPrice or 1000000
    local ok1, prices = pcall(function() return Remotes.CommF_:InvokeServer("GetFruits") end)
    local ok2, inv    = pcall(function() return Remotes.CommF_:InvokeServer("getInventoryFruits") end)
    if not ok1 or not ok2 then return nil end
    local priceMap = {}
    for _, v in pairs(prices) do
        if v.Price and v.Price <= maxPrice then priceMap[v.Name] = v.Price end
    end
    local best, lowest = nil, math.huge
    for _, f in pairs(inv) do
        if f.Name and priceMap[f.Name] and priceMap[f.Name] < lowest then
            lowest = priceMap[f.Name]
            best   = f.Name
        end
    end
    return best, lowest
end)

ARI:RegisterMethod("BuyChip", function()
    local lastBuy = Spirit.Storage:Get("RaidIceLastChipBuy") or 0
    if os.time() - lastBuy < ICE_CHIP_COOLDOWN then return false end
    local fruit = ARI.Methods.GetCheapestFruit:Call(1000000)
    if fruit then
        table.insert(ScriptStorage.IgnoreStoreFruits, fruit)
        Remotes.CommF_:InvokeServer("LoadFruit", fruit)
        task.wait(0.5)
        Remotes.CommF_:InvokeServer("RaidsNpc", "Select", "Ice")
        task.wait(1)
        Spirit.RefreshInventory()
        if Spirit.CheckSpecialMicrochip() then
            Spirit.Storage:Set("RaidIceLastChipBuy", os.time())
            Spirit.Storage:Save()
            return true
        end
    end
    return false
end)

ARI:RegisterMethod("Refresh", function()
    if _G.MeleeRaidRequest then return nil end
    local lv = ScriptStorage.PlayerData.Level or 0
    local fr = ScriptStorage.PlayerData.Fragments or 0
    local target = (Spirit.Config and Spirit.Config.AutoRaidIce_TargetFragments) or 5000
    if lv < 1300 then return nil end
    if fr >= target then return nil end
    if Spirit.CheckSpecialMicrochip() then return true end
    local island = RC.Methods.GetCurrentRaidIsland:Call()
    if island then return true end
    local lastBuy = Spirit.Storage:Get("RaidIceLastChipBuy") or 0
    if os.time() - lastBuy >= ICE_CHIP_COOLDOWN then return true end
    return nil
end)

ARI:RegisterMethod("Start", function()
    local target = (Spirit.Config and Spirit.Config.AutoRaidIce_TargetFragments) or 5000
    local fr = ScriptStorage.PlayerData.Fragments or 0
    if fr >= target then return end

    local island = RC.Methods.GetCurrentRaidIsland:Call()
    if island then
        SetTask("MainTask", "Raid Ice | " .. fr .. "/" .. target .. " | " .. island.Name)
        local num = tonumber(string.match(island.Name, "(%d+)"))
        if num and num >= 3 then
            Spirit.TweenController.Create(island.Position + Vector3.new(0, 50, 0))
            task.wait(0.5)
            pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)
            for _, v in ipairs(workspace.Enemies:GetChildren()) do
                pcall(function()
                    if v:FindFirstChild("Humanoid") then v.Humanoid.Health = 0 end
                    v:BreakJoints()
                end)
            end
        else
            for _, e in ipairs(Spirit.GetMonAsSortedRange()) do
                if Spirit.CaculateDistance(e.HumanoidRootPart.Position) < 1500 then
                    Spirit.CombatController.Attack(e.Name)
                    return
                end
            end
            Spirit.TweenController.Create(island.Position + Vector3.new(0, 100, 0))
        end
        return
    end

    if not Spirit.CheckSpecialMicrochip() then
        if not ARI.Methods.BuyChip:Call() then return end
        task.wait(2)
        Spirit.RefreshInventory()
    end
    if not Spirit.CheckSpecialMicrochip() then return end

    local mapName = ({nil, "Circle Island", "Boat Castle"})[Spirit.SeaIndex]
    if not mapName then return end
    local mapObj = workspace.Map:FindFirstChild(mapName) or workspace:FindFirstChild(mapName)
    if not mapObj then return end

    if not mapObj:FindFirstChild("RaidSummon2") then
        Spirit.TweenController.Create(mapObj:GetModelCFrame())
        task.wait(1)
        return
    end

    Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Special Microchip")
    local summon = mapObj:FindFirstChild("RaidSummon2")
    local ok = false
    for retry = 1, 3 do
        if retry > 1 then task.wait(3) end
        pcall(function()
            local prompt = summon:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt and fireproximityprompt then
                fireproximityprompt(prompt)
                ok = true
            else
                local click = summon:FindFirstChildWhichIsA("ClickDetector", true)
                if click then fireclickdetector(click); ok = true end
            end
        end)
        if ok then break end
    end

    SetTask("MainTask", "Raid Ice | Waiting raid start")
    local t0 = os.time()
    repeat task.wait(0.5) until os.time() - (Spirit.LastRaidAlert2 or 0) < 20
                          or os.time() - (Spirit.LastRaidAlert  or 0) < 20
                          or os.time() - t0 > 35
    if os.time() - t0 > 35 then
        Spirit.Report("[RaidIce] Raid didn't start")
    else
        Spirit.LastRaidAlert = 0
    end
end)

Spirit.__bosses_ready = true
