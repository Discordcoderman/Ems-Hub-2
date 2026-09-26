-- swords.lua — Saber, Tushita, Yama, CDK, SoulGuitar, stub quests
local Spirit = getgenv().Spirit
if not Spirit then error("[swords] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[swords] tasks.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes
local SetTask           = Spirit.SetTask
local CheckItem         = Spirit.CheckItem

-- ═══════════════════════════════════════════════════════════════
-- SABER
-- Stages 1–8. Refresh exits when Saber is in the backpack.
-- ═══════════════════════════════════════════════════════════════
local Saber = Spirit.FunctionsHandler.Saber

Saber:RegisterMethod("Refresh", function()
    if ScriptStorage.Backpack.Saber then return nil end
    if CheckItem("Saber") then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 200 then return nil end

    local prog = Remotes.CommF_:InvokeServer("ProQuestProgress")
    if not prog then return nil end

    local allPlatesDone = true
    local hasPlateKey   = false
    for _, p in pairs(prog.Plates or {}) do
        hasPlateKey = true
        if p == false then allPlatesDone = false break end
    end
    if not hasPlateKey then allPlatesDone = false end

    local step
    if not allPlatesDone        then step = 1
    elseif not prog.UsedTorch    then step = 2
    elseif not prog.UsedCup      then step = 3
    elseif not prog.TalkedSon    then step = 4
    elseif not prog.KilledMob    then step = 5
    elseif not prog.UsedRelic    then step = 6
    elseif not prog.KilledShanks then step = 7
    else step = 8 end

    Saber:Set("CurrentProgressLevel", step)
    Saber:Set("LastestRefreshSenque", os.time())
    return step
end)

Saber:RegisterMethod("Start", function(step)
    if not step then return end

    if step == 1 then
        SetTask("MainTask", "Saber | Activating quest plates")
        local plates = {}
        pcall(function()
            local jungle = workspace.Map.Jungle
            if jungle and jungle:FindFirstChild("QuestPlates") then
                for _, pl in ipairs(jungle.QuestPlates:GetChildren()) do
                    if pl:FindFirstChild("Button") then table.insert(plates, pl) end
                end
            end
        end)
        for i, pl in ipairs(plates) do
            SetTask("MainTask", "Saber | Plate " .. i .. "/" .. #plates)
            local deadline = tick() + 15
            while Spirit.CaculateDistance(pl.Button.CFrame) > 15 and tick() < deadline do
                task.wait()
                Spirit.TweenController.Create(pl.Button.CFrame)
            end
            task.wait(0.5)
        end

    elseif step == 2 then
        SetTask("MainTask", "Saber | Torch")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "GetTorch")
        task.wait(1)
        Remotes.CommF_:InvokeServer("ProQuestProgress", "DestroyTorch")

    elseif step == 3 then
        SetTask("MainTask", "Saber | Cup")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "GetCup")
        if ScriptStorage.Tools.Cup then
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call("Cup")
            task.wait(1)
            Remotes.CommF_:InvokeServer("ProQuestProgress", "FillCup", LocalPlayer.Character.Cup)
        end
        Remotes.CommF_:InvokeServer("ProQuestProgress", "SickMan")

    elseif step == 4 then
        SetTask("MainTask", "Saber | Rich Son")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")

    elseif step == 5 then
        SetTask("MainTask", "Saber | Mob Leader")
        Spirit.CombatController.Attack("Mob Leader")

    elseif step == 6 then
        SetTask("MainTask", "Saber | Relic")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
        Remotes.CommF_:InvokeServer("ProQuestProgress", "PlaceRelic")

    elseif step == 7 then
        SetTask("MainTask", "Saber | Killing Saber Expert")
        Spirit.CombatController.Attack("Saber Expert")

    elseif step == 8 then
        SetTask("MainTask", "Saber | Collecting Saber drop")
        local pickup
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Tool") and obj.Name == "Saber" then
                pickup = obj
                break
            end
        end
        if pickup then
            local handle = pickup:FindFirstChild("Handle")
                or pickup:FindFirstChildWhichIsA("BasePart")
            if handle then
                Spirit.TweenController.Create(handle.CFrame)
                local hrp = Spirit.HumanoidRootPart
                if hrp and (hrp.Position - handle.Position).Magnitude < 10 then
                    pcall(function()
                        if firetouchinterest then
                            firetouchinterest(hrp, handle, 0)
                            task.wait(0.05)
                            firetouchinterest(hrp, handle, 1)
                        end
                    end)
                end
            end
        else
            Spirit.TweenController.Create(CFrame.new(-1405, 30, -55))
        end
    end
end)

pcall(function()
    Remotes.RefreshQuestPro.OnClientEvent:Connect(function()
        pcall(function() Saber.Methods.Refresh:Call() end)
    end)
end)

-- ═══════════════════════════════════════════════════════════════
-- TUSHITA
-- ═══════════════════════════════════════════════════════════════
local Tushita = Spirit.FunctionsHandler.Tushita

Tushita:RegisterMethod("Refresh", function()
    if ScriptStorage.Backpack.Tushita then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 2000 then return nil end
    if Spirit.SeaIndex ~= 3 then return nil end
    local prog = Tushita:Get("Progress")
    if not prog then
        prog = Remotes.CommF_:InvokeServer("TushitaProgress")
        Tushita:Set("Progress", prog)
    end
    if not prog then return nil end
    if not prog.OpenedDoor then
        if ScriptStorage.Enemies["rip_indra True Form"] then
            Tushita:Set("Progress", nil); return 1
        end
    else
        if ScriptStorage.Enemies["Longma"] then
            Tushita:Set("Progress", nil); return 2
        end
    end
end)

Tushita:RegisterMethod("Start", function(step)
    if step == 1 then
        SetTask("MainTask", "Tushita | Place torches")
        Spirit.TweenController.Create(CFrame.new(5714, math.random(19, 21), 256))
        if ScriptStorage.Tools["Holy Torch"] then
            for i = 1, 5 do Remotes.CommF_:InvokeServer("TushitaProgress", "Torch", i) end
        end
    elseif step == 2 then
        SetTask("MainTask", "Tushita | Longma")
        Spirit.CombatController.Attack("Longma")
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- YAMA
-- ═══════════════════════════════════════════════════════════════
local Yama = Spirit.FunctionsHandler.Yama

Yama:RegisterMethod("Refresh", function()
    if Spirit.SeaIndex ~= 3 then return nil end
    if ScriptStorage.Backpack.Yama then return nil end
    if not Yama:Get("EliteCount") then
        Yama:Set("EliteCount", Remotes.CommF_:InvokeServer("EliteHunter", "Progress"))
    end
    if (Yama:Get("EliteCount") or 0) >= 30 then return true end
end)

Yama:RegisterMethod("Start", function()
    SetTask("MainTask", "Yama | Click Sealed Katana")
    repeat
        task.wait()
        Spirit.TweenController.Create(ReplicatedStorage.FakeIslands.Waterfall:GetModelCFrame())
    until workspace.Map:FindFirstChild("Waterfall")
      and workspace.Map.Waterfall:FindFirstChild("SealedKatana")
    fireclickdetector(workspace.Map.Waterfall.SealedKatana.Hitbox.ClickDetector)
end)

-- ═══════════════════════════════════════════════════════════════
-- CURSED DUAL KATANA
-- ═══════════════════════════════════════════════════════════════
local CDK = Spirit.FunctionsHandler.CursedDualKatana

CDK:RegisterMethod("GetHazeMon", function()
    local list = {}
    for _, c in ipairs(LocalPlayer.QuestHaze:GetChildren()) do
        if c.Value > 0 then table.insert(list, c) end
    end
    table.sort(list, function(a, b)
        return Spirit.CaculateDistance(a:GetAttribute("Position"))
             < Spirit.CaculateDistance(b:GetAttribute("Position"))
    end)
    return list[1] and tostring(list[1]) or nil
end)

CDK:RegisterMethod("DoDimension", function(name)
    local t0 = os.time()
    repeat
        task.wait()
        Spirit.TweenController.Create(LocalPlayer.Character.HumanoidRootPart.CFrame)
        if os.time() - t0 > 60 then return end
    until os.time() - (Spirit.TorchEnabledTime or 0) < 10
    Spirit.Hop()
end)

CDK:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.CursedDualKatana) then return nil end
    local bp = ScriptStorage.Backpack
    if (ScriptStorage.PlayerData.Level or 0) < 2200 then return nil end
    if bp["Cursed Dual Katana"] then return nil end
    if not bp.Tushita or (bp.Tushita.Mastery or 0) < 350
       or not bp.Yama or (bp.Yama.Mastery or 0) < 350 then
        return {"trainSwords"}
    end
    if Spirit.SeaIndex ~= 3 then return nil end
    local prog = CDK:Get("Progress") or Remotes.CommF_:InvokeServer("CDKQuest", "Progress")
    if not prog then return nil end
    CDK:Set("Progress", prog)
    if workspace.Map.Turtle.Cursed:FindFirstChild("Breakable") then return {"break"} end
    if prog.Good == 4 and prog.Evil == 4 then return {"burn 2"} end
    if prog.Good == 3 or prog.Evil == 3 then return {"burn"} end
    if prog.Opened then
        for k, v in pairs(prog) do
            if k ~= "Opened" and k ~= "Finished" and v < 3 then
                local swordMap = {Good = "Tushita", Evil = "Yama"}
                ScriptStorage.CdkCache = {k, v + 1}
                if not ScriptStorage.Tools[swordMap[k]] then
                    Remotes.CommF_:InvokeServer("LoadItem", swordMap[k])
                end
                Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", k)
                SetTask("MainTask", "CDK | " .. swordMap[k] .. " " .. k)
                return false
            end
        end
    end
end)

CDK:RegisterMethod("Start", function(cache)
    if not cache or not cache[1] then return end
    local kind = cache[1]

    if kind == "trainSwords" then
        local bp = ScriptStorage.Backpack
        local tM = (bp.Tushita and bp.Tushita.Mastery) or 0
        local yM = (bp.Yama and bp.Yama.Mastery) or 0
        SetTask("MainTask", "CDK Prep | Tushita " .. tM .. "/350, Yama " .. yM .. "/350")
        local swordToTrain
        if not bp.Tushita then swordToTrain = "buy_tushita"
        elseif tM < 350 then swordToTrain = "Tushita"
        elseif not bp.Yama then swordToTrain = "buy_yama"
        elseif yM < 350 then swordToTrain = "Yama" end
        if swordToTrain == "buy_tushita" or swordToTrain == "buy_yama" then return end
        pcall(function()
            Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(swordToTrain)
        end)
        if not ScriptStorage.Enemies["Reborn Skeleton"]
           and not ScriptStorage.Enemies["Living Zombie"] then
            Spirit.TweenController.Create(Spirit.HAUNTED_CASTLE_BONES_CF)
            return
        end
        Spirit.CombatController.Attack({"Reborn Skeleton", "Living Zombie", "Demonic Soul", "Posessed Mummy"})
        return
    end

    if kind == "break" then
        SetTask("MainTask", "CDK | Breaking door")
        Spirit.TweenController.Create(workspace.Map.Turtle.Cursed.Breakable.CFrame)
        Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")
        Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor", true)
        workspace.Map.Turtle.Cursed.Breakable:Destroy()
        CDK:Set("Progress", nil)
    elseif kind == "burn 2" then
        SetTask("MainTask", "CDK | Burn 2")
        local ped = workspace.Map.Turtle.Cursed.Pedestal3
        if ped and ped.ProximityPrompt.Enabled then
            fireproximityprompt(ped.ProximityPrompt)
            task.wait(1)
            pcall(function() LocalPlayer.Character.Humanoid.Health = 0 end)
            task.wait(5)
        else
            Spirit.TweenController.Create(CFrame.new(-12341.66796875, 603.3455810546875, -6550.6064453125))
            task.wait(3)
            pcall(function() LocalPlayer.Character.Humanoid.Health = 0 end)
            task.wait(3)
        end
        CDK:Set("Progress", nil)
    elseif kind == "burn" then
        for i = 1, 3 do
            local ped = workspace.Map.Turtle.Cursed:FindFirstChild("Pedestal" .. i)
            if ped and ped.ProximityPrompt.Enabled then
                repeat task.wait(); Spirit.TweenController.Create(ped.CFrame)
                until Spirit.CaculateDistance(ped.CFrame) < 5
                fireproximityprompt(ped.ProximityPrompt)
                task.wait(3)
                pcall(function() LocalPlayer.Character.Humanoid.Health = 0 end)
            end
        end
        CDK:Set("Progress", nil)
    else
        local side, step = cache[1], cache[2]
        if side == "Evil" and step == 1 then
            local e = ScriptStorage.Enemies["Forest Pirate"]
            Spirit.TweenController.Create((e and e.HumanoidRootPart.CFrame) or CFrame.new())
        elseif side == "Evil" and step == 2 then
            Spirit.CombatController.Attack(CDK.Methods.GetHazeMon:Call())
        elseif side == "Evil" and step == 3 then
            SetTask("MainTask", "CDK | Soul Reaper")
            if ScriptStorage.Enemies["Soul Reaper"] then
                CDK.Methods.DoDimension:Call("Hell Dimension")
            end
        elseif side == "Good" and step == 1 then
            for _, npc in ipairs(ReplicatedStorage.NPCs:GetChildren()) do
                if npc.Name == "Luxury Boat Dealer" then
                    repeat
                        task.wait()
                        LocalPlayer.Character.HumanoidRootPart.CFrame = npc:GetModelCFrame()
                    until Spirit.CaculateDistance(npc:GetModelCFrame()) < 5
                    Remotes.CommF_:InvokeServer("CDKQuest", "BoatQuest")
                end
            end
        elseif side == "Good" and step == 3 then
            repeat
                task.wait()
                Spirit.CombatController.Attack("Cake Queen")
            until not ScriptStorage.Enemies["Cake Queen"]
            CDK.Methods.DoDimension:Call("Heavenly Dimension")
        end
        CDK:Set("Progress", nil)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- SOUL GUITAR
-- ═══════════════════════════════════════════════════════════════
local SG = Spirit.FunctionsHandler.SoulGuitar

local SPECIAL_ITEMS = {
    "God's Chalice", "Fist of Darkness", "Sweet Chalice",
    "Hallow Essence", "Mirror Fractal",
}

local function HasSpecial()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local ch = LocalPlayer.Character
    for _, name in ipairs(SPECIAL_ITEMS) do
        if bp and bp:FindFirstChild(name) then return true, name end
        if ch and ch:FindFirstChild(name) then return true, name end
    end
    return false, nil
end

local function GetChests()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Parent
           and string.find(string.lower(obj.Name), "chest") then
            table.insert(list, obj)
        end
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        local pos = hrp.Position
        table.sort(list, function(a, b)
            return (pos - a.Position).Magnitude < (pos - b.Position).Magnitude
        end)
    end
    return list
end

local function CollectChest(chest)
    pcall(function()
        if not chest or not chest.Parent then return end
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
        Spirit.TweenController.Create(chest.CFrame + Vector3.new(0, 3, 0))
        task.wait(0.35)
        if firetouchinterest then
            firetouchinterest(hrp, chest, 0)
            task.wait()
            firetouchinterest(hrp, chest, 1)
        end
    end)
end

SG:RegisterMethod("Refresh", function()
    if not (Spirit.Config and Spirit.Config.Items and Spirit.Config.Items.SoulGuitar) then return nil end
    if ScriptStorage.Backpack["Skull Guitar"] then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 2300 then return nil end

    local ecto = (ScriptStorage.Backpack["Ectoplasm"]
                  and ScriptStorage.Backpack["Ectoplasm"].Count) or 0
    if ecto < 250 then return 1 end

    if not ScriptStorage.Backpack["Dark Fragment"] then
        if ScriptStorage.Backpack["Fist of Darkness"] then return 10 end
        if #GetChests() > 0 then return 9 end
        return nil
    end

    if Spirit.SeaIndex ~= 3 then return 20 end

    local prog = Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Check")
    if not prog then return 7 end
    if not prog.Swamp       then return 2
    elseif not prog.Gravestones then return 3
    elseif not prog.Ghost    then return 4
    elseif not prog.Trophies then return 5
    elseif not prog.Pipes    then return 6
    end
end)

SG:RegisterMethod("Start", function(step)
    if step == 1 then
        if Spirit.SeaIndex ~= 2 then
            Remotes.CommF_:InvokeServer("TravelDressrosa")
            return
        end
        local ecto = (ScriptStorage.Backpack["Ectoplasm"]
                      and ScriptStorage.Backpack["Ectoplasm"].Count) or 0
        SetTask("MainTask", "SoulGuitar | Ectoplasm " .. ecto .. "/250")
        Spirit.CombatController.Attack({"Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer"})
    elseif step == 20 then
        Remotes.CommF_:InvokeServer("TravelZou")
    elseif step == 9 then
        for _, chest in ipairs(GetChests()) do
            if HasSpecial() then return end
            if chest and chest.Parent then
                SetTask("MainTask", "SoulGuitar | Chest " .. chest.Name)
                CollectChest(chest)
                task.wait(0.2)
            end
        end
        Spirit.Hop()
    elseif step == 10 then
        SetTask("MainTask", "SoulGuitar | Summon Blackbeard")
        Spirit.TweenController.Create(CFrame.new(-1742.0, 241.0, 1290.0))
        task.wait(1)
        pcall(function() Remotes.CommF_:InvokeServer("Blackbeard", "Spawn") end)
        task.wait(1)
        Spirit.CombatController.Attack("Blackbeard")
    elseif step == 2 then
        SetTask("MainTask", "SoulGuitar | Kill Living Zombies")
        Spirit.CombatController.Attack("Living Zombie")
    elseif step == 3 then
        SetTask("MainTask", "SoulGuitar | Placards")
        while Spirit.CaculateDistance(CFrame.new(-8800.0, 178, 6033)) > 10 do
            task.wait()
            Spirit.TweenController.Create(CFrame.new(-8800.0, 178, 6033))
        end
        local castle = workspace.Map["Haunted Castle"]
        for name, dir in pairs({
            Placard1 = "Right", Placard2 = "Right", Placard3 = "Left",
            Placard4 = "Right", Placard5 = "Left",  Placard6 = "Left", Placard7 = "Left",
        }) do
            pcall(function() fireclickdetector(castle[name][dir].ClickDetector) end)
        end
    elseif step == 4 then
        SetTask("MainTask", "SoulGuitar | Ghost")
        Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Ghost")
    elseif step == 5 then
        SetTask("MainTask", "SoulGuitar | Trophies")
        Remotes.CommF_:InvokeServer("soulGuitarBuy")
    elseif step == 6 then
        SetTask("MainTask", "SoulGuitar | Pipes")
        for pipeName, colorName in pairs(Spirit.Pipes or {}) do
            pcall(function()
                local pipe = workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model[pipeName]
                if pipe and pipe.BrickColor.Name ~= colorName then
                    repeat task.wait() fireclickdetector(pipe.ClickDetector)
                    until pipe.BrickColor.Name == colorName
                end
            end)
        end
        Remotes.CommF_:InvokeServer("soulGuitarBuy")
    elseif step == 7 then
        Remotes.CommF_:InvokeServer("gravestoneEvent", 2)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- Stubs for sword quests not yet implemented
-- ═══════════════════════════════════════════════════════════════
for _, name in ipairs({
    "Rengoku", "SpikeyTrident", "SharkAchor", "Pole", "FoxLamp",
    "DarkDagger", "Canvander", "BuddySword", "HallowScythe",
    "AcidumRifle", "Kabucha", "VenomBow", "DragonStorm",
    "InsictV2", "RainbowSaviour", "DarkBladeV2", "DarkBladeV3", "DojoQuest",
}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function() return nil end)
    H:RegisterMethod("Start", function() end)
end

Spirit.__swords_ready = true
