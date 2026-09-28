-- level_farm.lua — ManualLevelLookup + LevelFarm + underwater routing
local Spirit = getgenv().Spirit
if not Spirit then error("[level_farm] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[level_farm] tasks.lua not loaded") end

local Services          = Spirit.Services
local Workspace         = Spirit.Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- UNDERWATER CITY ROUTING
-- ═══════════════════════════════════════════════════════════════
local UW_ENTRANCE_CF      = CFrame.new(4047.98, -4.00, -1814.70)
local UW_EXIT_CF          = CFrame.new(61172.18, -4.00, 1946.88)
local UW_ZONE_MIN_X       = 50000
local UW_TRIGGER_COOLDOWN = 4

local uwState = {lastTrigger = 0, lastAction = ""}

local function inUnderwaterZone(pos)
    return pos and pos.X > UW_ZONE_MIN_X
end

local function scanPromptNear(pos, radius)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                if (parent.Position - pos).Magnitude <= radius then return obj end
            end
        end
    end
    return nil
end

local function scanClickNear(pos, radius)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                if (parent.Position - pos).Magnitude <= radius then return obj end
            end
        end
    end
    return nil
end

local function triggerUnderwater(action)
    if tick() - uwState.lastTrigger < UW_TRIGGER_COOLDOWN then return false end
    if uwState.lastAction == action
       and tick() - uwState.lastTrigger < UW_TRIGGER_COOLDOWN * 2 then
        return false
    end
    uwState.lastTrigger = tick()
    uwState.lastAction  = action

    local hrp = Spirit.HumanoidRootPart
    if not hrp then return false end

    local prompt = scanPromptNear(hrp.Position, 35)
    if prompt and fireproximityprompt then
        pcall(fireproximityprompt, prompt)
        return true
    end

    local click = scanClickNear(hrp.Position, 35)
    if click and fireclickdetector then
        pcall(fireclickdetector, click)
        return true
    end

    local target = (action == "enter") and UW_ENTRANCE_CF or UW_EXIT_CF
    local nearest, nearestD = nil, 40
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanTouch then
            local d = (obj.Position - target.Position).Magnitude
            if d < nearestD then nearest, nearestD = obj, d end
        end
    end
    if nearest and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, nearest, 0)
            task.wait(0.05)
            firetouchinterest(hrp, nearest, 1)
        end)
        return true
    end
    return false
end
Spirit.TriggerUnderwater = triggerUnderwater

local function ensureUnderwaterPath(destCF)
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return false end

    local playerInUW = inUnderwaterZone(hrp.Position)
    local destInUW   = inUnderwaterZone(destCF and destCF.Position)

    if destInUW and not playerInUW then
        local distToEnt = (hrp.Position - UW_ENTRANCE_CF.Position).Magnitude
        if distToEnt > 15 then
            Spirit.SetTask("MainTask", "Level Farm | Routing to UW entrance (" .. math.floor(distToEnt) .. ")")
            Spirit.TweenController.Create(UW_ENTRANCE_CF + Vector3.new(0, 4, 0))
            return true
        end
        triggerUnderwater("enter")
        return true
    end

    if playerInUW and not destInUW then
        local distToExit = (hrp.Position - UW_EXIT_CF.Position).Magnitude
        if distToExit > 15 then
            Spirit.SetTask("MainTask", "Level Farm | Routing to UW exit (" .. math.floor(distToExit) .. ")")
            Spirit.TweenController.Create(UW_EXIT_CF + Vector3.new(0, 4, 0))
            return true
        end
        triggerUnderwater("exit")
        return true
    end

    return false
end

-- ═══════════════════════════════════════════════════════════════
-- ManualLevelLookup — mob / quest / CFrame per level tier
-- ═══════════════════════════════════════════════════════════════
local function ManualLevelLookup()
    local lv = ScriptStorage.PlayerData.Level or 0
    local Mon, Qdata, Qname, NameMon = "", 0, "", ""
    local PosQ, PosM = nil, nil

    if Spirit.SeaIndex == 1 then
        if lv >= 1 and lv <= 9 then
            Mon="Bandit"; Qdata=1; Qname="BanditQuest1"; NameMon="Bandit"
            PosQ=CFrame.new(1054.143, 14.752, 1555.539)
            PosM=CFrame.new(1045.962646484375, 27.00250816345215, 1560.8203125)
        elseif lv >= 10 and lv <= 14 then
            Mon="Monkey"; Qdata=1; Qname="JungleQuest"; NameMon="Monkey"
            PosQ=CFrame.new(-1681.747, 50.131, 174.628)
            PosM=CFrame.new(-1448.51806640625, 67.85301208496094, 11.46579647064209)
        elseif lv >= 15 and lv <= 29 then
            Mon="Gorilla"; Qdata=2; Qname="JungleQuest"; NameMon="Gorilla"
            PosQ=CFrame.new(-1681.747, 50.131, 174.628)
            PosM=CFrame.new(-1129.8836669921875, 40.46354675296875, -525.4237060546875)
        elseif lv >= 30 and lv <= 39 then
            Mon="Pirate"; Qdata=1; Qname="BuggyQuest1"; NameMon="Pirate"
            PosQ=CFrame.new(-1153.246, 17.356, 3862.523)
            PosM=CFrame.new(-1103.513427734375, 13.752052307128906, 3896.091064453125)
        elseif lv >= 40 and lv <= 59 then
            Mon="Brute"; Qdata=2; Qname="BuggyQuest1"; NameMon="Brute"
            PosQ=CFrame.new(-1153.246, 17.356, 3862.523)
            PosM=CFrame.new(-1140.083740234375, 14.809885025024414, 4322.92138671875)
        elseif lv >= 60 and lv <= 74 then
            Mon="Desert Bandit"; Qdata=1; Qname="DesertQuest"; NameMon="Desert Bandit"
            PosQ=CFrame.new(919.388, 5.959, 4203.755)
            PosM=CFrame.new(924.7998046875, 6.44867467880249, 4481.5859375)
        elseif lv >= 75 and lv <= 89 then
            Mon="Desert Officer"; Qdata=2; Qname="DesertQuest"; NameMon="Desert Officer"
            PosQ=CFrame.new(919.388, 5.959, 4203.755)
            PosM=CFrame.new(1608.2822265625, 8.614224433898926, 4371.00732421875)
        elseif lv >= 90 and lv <= 99 then
            Mon="Snow Bandit"; Qdata=1; Qname="SnowQuest"; NameMon="Snow Bandit"
            PosQ=CFrame.new(1402.995, 78.091, -1312.046)
            PosM=CFrame.new(1354.347900390625, 87.27277374267578, -1393.946533203125)
        elseif lv >= 100 and lv <= 119 then
            Mon="Snowman"; Qdata=2; Qname="SnowQuest"; NameMon="Snowman"
            PosQ=CFrame.new(1402.995, 78.091, -1312.046)
            PosM=CFrame.new(1201.6412353515625, 144.57958984375, -1550.0670166015625)
        elseif lv >= 120 and lv <= 149 then
            Mon="Chief Petty Officer"; Qdata=1; Qname="MarineQuest2"; NameMon="Chief Petty Officer"
            PosQ=CFrame.new(-4698.115, 5.943, 4226.318)
            PosM=CFrame.new(-4881.23095703125, 22.65204429626465, 4273.75244140625)
        elseif lv >= 150 and lv <= 174 then
            Mon="Sky Bandit"; Qdata=1; Qname="SkyQuest"; NameMon="Sky Bandit"
            PosQ=CFrame.new(-5404.493, 410.791, -693.521)
            PosM=CFrame.new(-4953.20703125, 295.74420166015625, -2899.22900390625)
        elseif lv >= 175 and lv <= 249 then
            Mon="Dark Master"; Qdata=2; Qname="SkyQuest"; NameMon="Dark Master"
            PosQ=CFrame.new(-5404.493, 410.791, -693.521)
            PosM=CFrame.new(-5259.8447265625, 391.3976745605469, -2229.035400390625)
        elseif lv >= 250 and lv <= 274 then
            Mon="Toga Warrior"; Qdata=1; Qname="ColosseumQuest"; NameMon="Toga Warrior"
            PosQ=CFrame.new(-1343.188, 13.535, -2927.292)
            PosM=CFrame.new(-1820.21484375, 51.68385696411133, -2740.6650390625)
        elseif lv >= 275 and lv <= 299 then
            Mon="Gladiator"; Qdata=2; Qname="ColosseumQuest"; NameMon="Gladiator"
            PosQ=CFrame.new(-1343.188, 13.535, -2927.292)
            PosM=CFrame.new(-1292.838134765625, 56.380882263183594, -3339.031494140625)
        elseif lv >= 300 and lv <= 324 then
            Mon="Military Soldier"; Qdata=1; Qname="MagmaQuest"; NameMon="Military Soldier"
            PosQ=CFrame.new(-5309.464, 18.531, 8488.051)
            PosM=CFrame.new(-5411.16455078125, 11.081554412841797, 8454.29296875)
        elseif lv >= 325 and lv <= 374 then
            Mon="Military Spy"; Qdata=2; Qname="MagmaQuest"; NameMon="Military Spy"
            PosQ=CFrame.new(-5309.464, 18.531, 8488.051)
            PosM=CFrame.new(-5802.8681640625, 86.26241302490234, 8828.859375)
        elseif lv >= 375 and lv <= 399 then
            Mon="Fishman Warrior"; Qdata=1; Qname="FishmanQuest"; NameMon="Fishman Warrior"
            PosQ=CFrame.new(61405.594, 24.995, 1630.361)
            PosM=CFrame.new(60878.30078125, 18.482830047607422, 1543.7574462890625)
        elseif lv >= 400 and lv <= 449 then
            Mon="Fishman Commando"; Qdata=2; Qname="FishmanQuest"; NameMon="Fishman Commando"
            PosQ=CFrame.new(61405.594, 24.995, 1630.361)
            PosM=CFrame.new(61922.6328125, 18.482830047607422, 1493.934326171875)
        elseif lv >= 450 and lv <= 474 then
            Mon="God's Guard"; Qdata=1; Qname="SkyExp1Quest"; NameMon="God's Guard"
            PosQ=CFrame.new(-4314.29, 1087.13, -559.59)
            PosM=CFrame.new(-4710.04296875, 845.2769775390625, -1927.3079833984375)
        elseif lv >= 475 and lv <= 524 then
            Mon="Shanda"; Qdata=2; Qname="SkyExp1Quest"; NameMon="Shanda"
            PosQ=CFrame.new(-5950.65, 5469.16, 2088.56)
            PosM=CFrame.new(-7678.48974609375, 5566.40380859375, -497.2156066894531)
        elseif lv >= 525 and lv <= 549 then
            Mon="Royal Squad"; Qdata=1; Qname="SkyExp2Quest"; NameMon="Royal Squad"
            PosQ=CFrame.new(-7027.94, 5591.90, 1355.00)
            PosM=CFrame.new(-7624.25244140625, 5658.13330078125, -1467.354248046875)
        elseif lv >= 550 and lv <= 624 then
            Mon="Royal Soldier"; Qdata=2; Qname="SkyExp2Quest"; NameMon="Royal Soldier"
            PosQ=CFrame.new(-7027.94, 5591.90, 1355.00)
            PosM=CFrame.new(-7836.75341796875, 5645.6640625, -1790.6236572265625)
        elseif lv >= 625 and lv <= 649 then
            Mon="Galley Pirate"; Qdata=1; Qname="FountainQuest"; NameMon="Galley Pirate"
            PosQ=CFrame.new(5264.832, 76.150, 4085.860)
            PosM=CFrame.new(5551.02197265625, 78.90135192871094, 3930.412841796875)
        elseif lv >= 650 then
            Mon="Galley Captain"; Qdata=2; Qname="FountainQuest"; NameMon="Galley Captain"
            PosQ=CFrame.new(5264.832, 76.150, 4085.860)
            PosM=CFrame.new(5441.95166015625, 42.50205993652344, 4950.09375)
        end

    elseif Spirit.SeaIndex == 2 then
        if lv >= 700 and lv <= 724 then
            Mon="Raider"; Qdata=1; Qname="Area1Quest"; NameMon="Raider"
            PosQ=CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985)
            PosM=CFrame.new(-728.3267211914062, 52.779319763183594, 2345.7705078125)
        elseif lv >= 725 and lv <= 774 then
            Mon="Mercenary"; Qdata=2; Qname="Area1Quest"; NameMon="Mercenary"
            PosQ=CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985)
            PosM=CFrame.new(-1004.3244018554688, 80.15886688232422, 1424.619384765625)
        elseif lv >= 775 and lv <= 799 then
            Mon="Swan Pirate"; Qdata=1; Qname="Area2Quest"; NameMon="Swan Pirate"
            PosQ=CFrame.new(638.43811, 71.769989, 918.282898, 0.139203906, 0, 0.99026376, 0, 1, 0, -0.99026376, 0, 0.139203906)
            PosM=CFrame.new(1068.664306640625, 137.61428833007812, 1322.1060791015625)
        elseif lv >= 800 and lv <= 874 then
            Mon="Factory Staff"; Qdata=2; Qname="Area2Quest"; NameMon="Factory Staff"
            PosQ=CFrame.new(632.698608, 73.1055908, 918.666321, -0.0319722369, 0, -0.999488771, 0, 1, 0, 0.999488771, 0, -0.0319722369)
            PosM=CFrame.new(73.07867431640625, 81.86344146728516, -27.470672607421875)
        elseif lv >= 875 and lv <= 899 then
            Mon="Marine Lieutenant"; Qdata=1; Qname="MarineQuest3"; NameMon="Marine Lieutenant"
            PosQ=CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268)
            PosM=CFrame.new(-2821.372314453125, 75.89727783203125, -3070.089111328125)
        elseif lv >= 900 and lv <= 949 then
            Mon="Marine Captain"; Qdata=2; Qname="MarineQuest3"; NameMon="Marine Captain"
            PosQ=CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268)
            PosM=CFrame.new(-1861.2310791015625, 80.17658233642578, -3254.697509765625)
        elseif lv >= 950 and lv <= 974 then
            Mon="Zombie"; Qdata=1; Qname="ZombieQuest"; NameMon="Zombie"
            PosQ=CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146)
            PosM=CFrame.new(-5657.77685546875, 78.96973419189453, -928.68701171875)
        elseif lv >= 975 and lv <= 999 then
            Mon="Vampire"; Qdata=2; Qname="ZombieQuest"; NameMon="Vampire"
            PosQ=CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146)
            PosM=CFrame.new(-6037.66796875, 32.18463897705078, -1340.6597900390625)
        elseif lv >= 1000 and lv <= 1049 then
            Mon="Snow Trooper"; Qdata=1; Qname="SnowMountainQuest"; NameMon="Snow Trooper"
            PosQ=CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106)
            PosM=CFrame.new(549.1473388671875, 427.3870544433594, -5563.69873046875)
        elseif lv >= 1050 and lv <= 1099 then
            Mon="Winter Warrior"; Qdata=2; Qname="SnowMountainQuest"; NameMon="Winter Warrior"
            PosQ=CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106)
            PosM=CFrame.new(1142.7451171875, 475.6398010253906, -5199.41650390625)
        elseif lv >= 1100 and lv <= 1124 then
            Mon="Lab Subordinate"; Qdata=1; Qname="IceSideQuest"; NameMon="Lab Subordinate"
            PosQ=CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, 0, -0.891015649, 0, 1, 0, 0.891015649, 0, 0.453972578)
            PosM=CFrame.new(-5707.4716796875, 15.951709747314453, -4513.39208984375)
        elseif lv >= 1125 and lv <= 1174 then
            Mon="Horned Warrior"; Qdata=2; Qname="IceSideQuest"; NameMon="Horned Warrior"
            PosQ=CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, 0, -0.891015649, 0, 1, 0, 0.891015649, 0, 0.453972578)
            PosM=CFrame.new(-6341.36669921875, 15.951770782470703, -5723.162109375)
        elseif lv >= 1175 and lv <= 1199 then
            Mon="Magma Ninja"; Qdata=1; Qname="FireSideQuest"; NameMon="Magma Ninja"
            PosQ=CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213)
            PosM=CFrame.new(-5449.6728515625, 76.65874481201172, -5808.20068359375)
        elseif lv >= 1200 and lv <= 1249 then
            Mon="Lava Pirate"; Qdata=2; Qname="FireSideQuest"; NameMon="Lava Pirate"
            PosQ=CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213)
            PosM=CFrame.new(-5213.33154296875, 49.73788070678711, -4701.451171875)
        elseif lv >= 1250 and lv <= 1274 then
            Mon="Ship Deckhand"; Qdata=1; Qname="ShipQuest1"; NameMon="Ship Deckhand"
            PosQ=CFrame.new(1037.80127, 125.092171, 32911.6016)
            PosM=CFrame.new(1212.0111083984375, 150.79205322265625, 33059.24609375)
        elseif lv >= 1275 and lv <= 1299 then
            Mon="Ship Engineer"; Qdata=2; Qname="ShipQuest1"; NameMon="Ship Engineer"
            PosQ=CFrame.new(1037.80127, 125.092171, 32911.6016)
            PosM=CFrame.new(919.4786376953125, 43.54401397705078, 32779.96875)
        elseif lv >= 1300 and lv <= 1324 then
            Mon="Ship Steward"; Qdata=1; Qname="ShipQuest2"; NameMon="Ship Steward"
            PosQ=CFrame.new(968.80957, 125.092171, 33244.125)
            PosM=CFrame.new(919.4385375976562, 129.55599975585938, 33436.03515625)
        elseif lv >= 1325 and lv <= 1349 then
            Mon="Ship Officer"; Qdata=2; Qname="ShipQuest2"; NameMon="Ship Officer"
            PosQ=CFrame.new(968.80957, 125.092171, 33244.125)
            PosM=CFrame.new(1036.0179443359375, 181.4390411376953, 33315.7265625)
        elseif lv >= 1350 and lv <= 1374 then
            Mon="Arctic Warrior"; Qdata=1; Qname="FrostQuest"; NameMon="Arctic Warrior"
            PosQ=CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909)
            PosM=CFrame.new(5966.24609375, 62.97002029418945, -6179.3828125)
        elseif lv >= 1375 and lv <= 1424 then
            Mon="Snow Lurker"; Qdata=2; Qname="FrostQuest"; NameMon="Snow Lurker"
            PosQ=CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909)
            PosM=CFrame.new(5407.07373046875, 69.19437408447266, -6880.88037109375)
        elseif lv >= 1425 and lv <= 1449 then
            Mon="Sea Soldier"; Qdata=1; Qname="ForgottenQuest"; NameMon="Sea Soldier"
            PosQ=CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, 0, -0.13915664, 0, 1, 0, 0.13915664, 0, 0.990270376)
            PosM=CFrame.new(-3028.2236328125, 64.67451477050781, -9775.4267578125)
        elseif lv >= 1450 then
            Mon="Water Fighter"; Qdata=2; Qname="ForgottenQuest"; NameMon="Water Fighter"
            PosQ=CFrame.new(-3054, 240, -10146)
            PosM=CFrame.new(-3291, 252, -10501)
        end

    elseif Spirit.SeaIndex == 3 then
        if lv >= 1500 and lv <= 1524 then
            Mon="Pirate Millionaire"; Qdata=1; Qname="PiratePortQuest"; NameMon="Pirate Millionaire"
            PosQ=CFrame.new(-290.074677, 42.9034653, 5581.58984, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627)
            PosM=CFrame.new(-245.9963836669922, 47.30615234375, 5584.1005859375)
        elseif lv >= 1525 and lv <= 1574 then
            Mon="Pistol Billionaire"; Qdata=2; Qname="PiratePortQuest"; NameMon="Pistol Billionaire"
            PosQ=CFrame.new(-290.074677, 42.9034653, 5581.58984, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627)
            PosM=CFrame.new(-187.3301544189453, 86.23987579345703, 6013.513671875)
        elseif lv >= 1575 and lv <= 1599 then
            Mon="Dragon Crew Warrior"; Qdata=1; Qname="DragonCrewQuest"; NameMon="Dragon Crew Warrior"
            PosQ=CFrame.new(6738.96142578125, 127.81645965576172, -713.511474609375)
            PosM=CFrame.new(6920.71435546875, 56.15597152709961, -942.5044555664062)
        elseif lv >= 1600 and lv <= 1624 then
            Mon="Dragon Crew Archer"; Qdata=2; Qname="DragonCrewQuest"; NameMon="Dragon Crew Archer"
            PosQ=CFrame.new(6738.96142578125, 127.81645965576172, -713.511474609375)
            PosM=CFrame.new(6817.91259765625, 484.804443359375, 513.4141235351562)
        elseif lv >= 1625 and lv <= 1649 then
            Mon="Hydra Enforcer"; Qdata=1; Qname="VenomCrewQuest"; NameMon="Hydra Enforcer"
            PosQ=CFrame.new(5213.8740234375, 1004.5042724609375, 758.6944580078125)
            PosM=CFrame.new(4584.69287109375, 1002.6435546875, 705.7958984375)
        elseif lv >= 1650 and lv <= 1699 then
            Mon="Venomous Assailant"; Qdata=2; Qname="VenomCrewQuest"; NameMon="Venomous Assailant"
            PosQ=CFrame.new(5213.8740234375, 1004.5042724609375, 758.6944580078125)
            PosM=CFrame.new(4638.78564453125, 1078.94091796875, 881.8002319335938)
        elseif lv >= 1700 and lv <= 1724 then
            Mon="Marine Commodore"; Qdata=1; Qname="MarineTreeIsland"; NameMon="Marine Commodore"
            PosQ=CFrame.new(2180.54126, 27.8156815, -6741.5498, -0.965929747, 0, 0.258804798, 0, 1, 0, -0.258804798, 0, -0.965929747)
            PosM=CFrame.new(2286.0078125, 73.13391876220703, -7159.80908203125)
        elseif lv >= 1725 and lv <= 1774 then
            Mon="Marine Rear Admiral"; Qdata=2; Qname="MarineTreeIsland"; NameMon="Marine Rear Admiral"
            PosQ=CFrame.new(2179.98828125, 28.731239318848, -6740.0551757813)
            PosM=CFrame.new(3656.773681640625, 160.52406311035156, -7001.5986328125)
        elseif lv >= 1775 and lv <= 1799 then
            Mon="Fishman Raider"; Qdata=2; Qname="DeepForestIsland3"; NameMon="Fishman Raider"
            PosQ=CFrame.new(3142.67822, 108.42981, 7482.37988, 0.34205412, 0, 0.939680243, 0, 1, 0, -0.939680243, 0, 0.34205412)
            PosM=CFrame.new(-10407.5263671875, 331.76263427734375, -8368.5166015625)
        elseif lv >= 1800 and lv <= 1824 then
            Mon="Fishman Captain"; Qdata=1; Qname="DeepForestIsland3"; NameMon="Fishman Captain"
            PosQ=CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213)
            PosM=CFrame.new(-10994.701171875, 352.38140869140625, -9002.1103515625)
        elseif lv >= 1825 and lv <= 1849 then
            Mon="Forest Pirate"; Qdata=2; Qname="DeepForestIsland"; NameMon="Forest Pirate"
            PosQ=CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, -0, -0.707079291, 0, 1, -0, 0.707079291, 0, 0.707134247)
            PosM=CFrame.new(-13274.478515625, 332.3781433105469, -7769.58056640625)
        elseif lv >= 1850 and lv <= 1899 then
            Mon="Forest Pirate"; Qdata=1; Qname="DeepForestIsland"; NameMon="Forest Pirate"
            PosQ=CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, -0, -0.707079291, 0, 1, -0, 0.707079291, 0, 0.707134247)
            PosM=CFrame.new(-13680.607421875, 501.08154296875, -6991.189453125)
        elseif lv >= 1900 and lv <= 1924 then
            Mon="Jungle Pirate"; Qdata=2; Qname="DeepForestIsland"; NameMon="Jungle Pirate"
            PosQ=CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002)
            PosM=CFrame.new(-12256.16015625, 331.73828125, -10485.8369140625)
        elseif lv >= 1925 and lv <= 1974 then
            Mon="Musketeer Pirate"; Qdata=2; Qname="DeepForestIsland2"; NameMon="Musketeer Pirate"
            PosQ=CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002)
            PosM=CFrame.new(-13457.904296875, 391.545654296875, -9859.177734375)
        elseif lv >= 1975 and lv <= 1999 then
            Mon="Reborn Skeleton"; Qdata=1; Qname="HauntedQuest1"; NameMon="Reborn Skeleton"
            PosQ=CFrame.new(-9479.2168, 141.215088, 5566.09277, 0, 0, 1, 0, 1, -0, -1, 0, 0)
            PosM=CFrame.new(-8763.7236328125, 165.72299194335938, 6159.86181640625)
        elseif lv >= 2000 and lv <= 2024 then
            Mon="Living Zombie"; Qdata=2; Qname="HauntedQuest1"; NameMon="Living Zombie"
            PosQ=CFrame.new(-9479.2168, 141.215088, 5566.09277, 0, 0, 1, 0, 1, -0, -1, 0, 0)
            PosM=CFrame.new(-10144.1318359375, 138.62667846679688, 5838.0888671875)
        elseif lv >= 2025 and lv <= 2049 then
            Mon="Demonic Soul"; Qdata=1; Qname="HauntedQuest2"; NameMon="Demonic Soul"
            PosQ=CFrame.new(-9516.99316, 172.017181, 6078.46533, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            PosM=CFrame.new(-9505.8720703125, 172.10482788085938, 6158.9931640625)
        elseif lv >= 2050 and lv <= 2074 then
            Mon="Posessed Mummy"; Qdata=2; Qname="HauntedQuest2"; NameMon="Posessed Mummy"
            PosQ=CFrame.new(-9516.99316, 172.017181, 6078.46533, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            PosM=CFrame.new(-9582.0224609375, 6.251527309417725, 6205.478515625)
        elseif lv >= 2075 and lv <= 2099 then
            Mon="Peanut Scout"; Qdata=1; Qname="NutsIslandQuest"; NameMon="Peanut Scout"
            PosQ=CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            PosM=CFrame.new(-2143.241943359375, 47.72198486328125, -10029.9951171875)
        elseif lv >= 2100 and lv <= 2124 then
            Mon="Peanut President"; Qdata=1; Qname="NutsIslandQuest"; NameMon="Peanut President"
            PosQ=CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            PosM=CFrame.new(-1859.35400390625, 38.10316848754883, -10422.4296875)
        elseif lv >= 2125 and lv <= 2149 then
            Mon="Ice Cream Chef"; Qdata=1; Qname="IceCreamIslandQuest"; NameMon="Ice Cream Chef"
            PosQ=CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            PosM=CFrame.new(-872.24658203125, 65.81957244873047, -10919.95703125)
        elseif lv >= 2150 and lv <= 2199 then
            Mon="Ice Cream Commander"; Qdata=2; Qname="IceCreamIslandQuest"; NameMon="Ice Cream Commander"
            PosQ=CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            PosM=CFrame.new(-558.06103515625, 112.04895782470703, -11290.7744140625)
        elseif lv >= 2200 and lv <= 2224 then
            Mon="Cookie Crafter"; Qdata=1; Qname="CakeQuest1"; NameMon="Cookie Crafter"
            PosQ=CFrame.new(-2021.32007, 37.7982254, -12028.7295, 0.957576931, -8.80302053e-08, 0.288177818, 6.9301187e-08, 1, 7.51931211e-08, -0.288177818, -5.2032135e-08, 0.957576931)
            PosM=CFrame.new(-2374.13671875, 37.79826354980469, -12125.30859375)
        elseif lv >= 2225 and lv <= 2249 then
            Mon="Cake Guard"; Qdata=2; Qname="CakeQuest1"; NameMon="Cake Guard"
            PosQ=CFrame.new(-2021.32007, 37.7982254, -12028.7295, 0.957576931, -8.80302053e-08, 0.288177818, 6.9301187e-08, 1, 7.51931211e-08, -0.288177818, -5.2032135e-08, 0.957576931)
            PosM=CFrame.new(-1598.3070068359375, 43.773197174072266, -12244.5810546875)
        elseif lv >= 2250 and lv <= 2274 then
            Mon="Baking Staff"; Qdata=1; Qname="CakeQuest2"; NameMon="Baking Staff"
            PosQ=CFrame.new(-1927.91602, 37.7981339, -12842.5391, -0.96804446, 4.22142143e-08, 0.250778586, 4.74911062e-08, 1, 1.49904711e-08, -0.250778586, 2.64211941e-08, -0.96804446)
            PosM=CFrame.new(-1887.8099365234375, 77.6185073852539, -12998.3505859375)
        elseif lv >= 2275 and lv <= 2299 then
            Mon="Head Baker"; Qdata=2; Qname="CakeQuest2"; NameMon="Head Baker"
            PosQ=CFrame.new(-1927.91602, 37.7981339, -12842.5391, -0.96804446, 4.22142143e-08, 0.250778586, 4.74911062e-08, 1, 1.49904711e-08, -0.250778586, 2.64211941e-08, -0.96804446)
            PosM=CFrame.new(-2216.188232421875, 82.884521484375, -12869.2939453125)
        elseif lv >= 2300 and lv <= 2324 then
            Mon="Cocoa Warrior"; Qdata=1; Qname="ChocQuest1"; NameMon="Cocoa Warrior"
            PosQ=CFrame.new(233.22836303710938, 29.876001358032227, -12201.2333984375)
            PosM=CFrame.new(-21.55328369140625, 80.57499694824219, -12352.3876953125)
        elseif lv >= 2325 and lv <= 2349 then
            Mon="Chocolate Bar Battler"; Qdata=2; Qname="ChocQuest1"; NameMon="Chocolate Bar Battler"
            PosQ=CFrame.new(233.22836303710938, 29.876001358032227, -12201.2333984375)
            PosM=CFrame.new(582.590576171875, 77.18809509277344, -12463.162109375)
        elseif lv >= 2350 and lv <= 2374 then
            Mon="Sweet Thief"; Qdata=1; Qname="ChocQuest2"; NameMon="Sweet Thief"
            PosQ=CFrame.new(150.5066375732422, 30.693693161010742, -12774.5029296875)
            PosM=CFrame.new(165.1884765625, 76.05885314941406, -12600.8369140625)
        elseif lv >= 2375 and lv <= 2399 then
            Mon="Candy Rebel"; Qdata=2; Qname="ChocQuest2"; NameMon="Candy Rebel"
            PosQ=CFrame.new(150.5066375732422, 30.693693161010742, -12774.5029296875)
            PosM=CFrame.new(134.86563110351562, 77.2476806640625, -12876.5478515625)
        elseif lv >= 2400 and lv <= 2424 then
            Mon="Candy Pirate"; Qdata=1; Qname="CandyQuest1"; NameMon="Candy Pirate"
            PosQ=CFrame.new(-1150.0400390625, 20.378934860229492, -14446.3349609375)
            PosM=CFrame.new(-1310.5003662109375, 26.016523361206055, -14562.404296875)
        elseif lv >= 2425 and lv <= 2449 then
            Mon="Snow Demon"; Qdata=2; Qname="CandyQuest1"; NameMon="Snow Demon"
            PosQ=CFrame.new(-1150.0400390625, 20.378934860229492, -14446.3349609375)
            PosM=CFrame.new(-880.2006225585938, 71.24776458740234, -14538.609375)
        elseif lv >= 2450 and lv <= 2474 then
            Mon="Isle Outlaw"; Qdata=1; Qname="TikiQuest1"; NameMon="Isle Outlaw"
            PosQ=CFrame.new(-16547.748046875, 61.13533401489258, -173.41360473632812)
            PosM=CFrame.new(-16442.814453125, 116.13899993896484, -264.4637756347656)
        elseif lv >= 2475 and lv <= 2524 then
            Mon="Island Boy"; Qdata=2; Qname="TikiQuest1"; NameMon="Island Boy"
            PosQ=CFrame.new(-16547.748046875, 61.13533401489258, -173.41360473632812)
            PosM=CFrame.new(-16901.26171875, 84.06756591796875, -192.88906860351562)
        elseif lv >= 2525 and lv <= 2574 then
            Mon="Isle Champion"; Qdata=1; Qname="TikiQuest2"; NameMon="Isle Champion"
            PosQ=CFrame.new(-16539.078125, 55.68632888793945, 1051.5738525390625)
            PosM=CFrame.new(-16641.6796875, 235.7825469970703, 1031.282958984375)
        elseif lv >= 2575 and lv <= 2599 then
            Mon="Skull Slayer"; Qdata=2; Qname="TikiQuest3"; NameMon="Skull Slayer"
            PosQ=CFrame.new(-16665.1914, 104.596405, 1579.69434, 0.951068401, -0, -0.308980465, 0, 1, -0, 0.308980465, 0, 0.951068401)
            PosM=CFrame.new(-16887.7305, 113.074638, 1629.97778, -0.559032857, 1.2313353e-08, -0.829145491, 1.05618814e-09, 1, 1.41385428e-08, 0.829145491, 7.02817626e-09, -0.559032857)
        elseif lv >= 2600 and lv <= 2624 then
            Mon="Reef Bandit"; Qdata=1; Qname="SubmergedQuest1"; NameMon="Reef Bandit"
            PosQ=CFrame.new(10778.875, -2087.72437, 9265.18359, 0.934615612, -9.33109447e-08, -0.355659455, 9.17655143e-08, 1, -2.12154276e-08, 0.355659455, -1.28090019e-08, 0.934615612)
            PosM=CFrame.new(11019.1318, -2146.06812, 9342.3916, -0.719955266, -1.74275385e-08, 0.69402045, 5.76556367e-08, 1, 8.49211546e-08, -0.69402045, 1.01153624e-07, -0.719955266)
        elseif lv >= 2625 and lv <= 2649 then
            Mon="Coral Pirate"; Qdata=2; Qname="SubmergedQuest1"; NameMon="Coral Pirate"
            PosQ=CFrame.new(10778.875, -2087.72437, 9265.18359, 0.934615612, -9.33109447e-08, -0.355659455, 9.17655143e-08, 1, -2.12154276e-08, 0.355659455, -1.28090019e-08, 0.934615612)
            PosM=CFrame.new(10808.6006, -2030.36145, 9364.2334, -0.775185347, -0.0359364748, 0.6307109, 0.0615428537, 0.989336014, 0.132010356, -0.628728986, 0.141148239, -0.764707148)
        elseif lv >= 2650 and lv <= 2674 then
            Mon="Sea Chanter"; Qdata=1; Qname="SubmergedQuest2"; NameMon="Sea Chanter"
            PosQ=CFrame.new(10880.6855, -2086.20044, 10032.624, -0.321384728, 9.87648434e-08, -0.946948707, 7.13271007e-08, 1, 8.00902953e-08, 0.946948707, -4.18033075e-08, -0.321384728)
            PosM=CFrame.new(10671.2715, -2057.59155, 10047.2588)
        elseif lv >= 2675 and lv <= 2699 then
            Mon="Ocean Prophet"; Qdata=2; Qname="SubmergedQuest2"; NameMon="Ocean Prophet"
            PosQ=CFrame.new(10880.6855, -2086.20044, 10032.624, -0.321384728, 9.87648434e-08, -0.946948707, 7.13271007e-08, 1, 8.00902953e-08, 0.946948707, -4.18033075e-08, -0.321384728)
            PosM=CFrame.new(11008.5195, -2007.72839, 10223.0791, -0.688615739, 2.33523378e-09, -0.725126445, 2.99292546e-09, 1, 3.78221315e-10, 0.725126445, -1.90980032e-09, -0.688615739)
        elseif lv >= 2700 and lv <= 2724 then
            Mon="High Disciple"; Qdata=1; Qname="SubmergedQuest3"; NameMon="High Disciple"
            PosQ=CFrame.new(9640.08789, -1992.44507, 9613.65234, -0.957327187, 4.11991223e-08, 0.289006323, 1.5775445e-08, 1, -9.02985846e-08, -0.289006323, -8.18860855e-08, -0.957327187)
            PosM=CFrame.new(9750.41602, -1966.93884, 9753.36035, -0.749824047, 5.57797613e-08, -0.661637306, 2.03500754e-08, 1, 6.1243199e-08, 0.661637306, 3.24572511e-08, -0.749824047)
        elseif lv >= 2725 then
            Mon="Grand Devotee"; Qdata=2; Qname="SubmergedQuest3"; NameMon="Grand Devotee"
            PosQ=CFrame.new(9640.08789, -1992.44507, 9613.65234, -0.957327187, 4.11991223e-08, 0.289006323, 1.5775445e-08, 1, -9.02985846e-08, -0.289006323, -8.18860855e-08, -0.957327187)
            PosM=CFrame.new(9611.70508, -1993.47119, 9882.68848, -0.591375351, 4.14332426e-08, -0.806396425, 4.73774868e-08, 1, 1.66361875e-08, 0.806396425, -2.83668058e-08, -0.591375351)
        end
    end

    if Mon == "" or not PosM then return nil end
    return {Mon = Mon, Qdata = Qdata, Qname = Qname, NameMon = NameMon, PosQ = PosQ, PosM = PosM}
end
Spirit.ManualLevelLookup = ManualLevelLookup

-- ═══════════════════════════════════════════════════════════════
-- LevelFarm
-- ═══════════════════════════════════════════════════════════════
local LF = Spirit.FunctionsHandler.LevelFarm
local BonesCooldown = 0

local LastTargetKey       = nil
local LastAcceptAttempt   = 0
local LastAbandon         = 0
local LastDebug           = 0
local AtGiverSince        = 0
local AcceptFailCount     = 0
local LastDialogClick     = 0

local function mobMatches(guiMob, targetMob)
    if not guiMob or not targetMob then return false end
    if guiMob == targetMob then return true end
    if guiMob == targetMob .. "s" then return true end
    if targetMob == guiMob .. "s" then return true end
    if guiMob == targetMob .. "es" then return true end
    if targetMob == guiMob .. "es" then return true end
    return false
end

local function clickQuestDialog(targetMob)
    if os.time() - LastDialogClick < 2 then return false end

    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end

    local function scanContainer(container)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                local txt = ""
                if obj:IsA("TextButton") and obj.Text then
                    txt = tostring(obj.Text)
                end
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("TextLabel") and child.Text then
                        txt = txt .. " " .. tostring(child.Text)
                    end
                end

                if txt:find(targetMob, 1, true) then
                    LastDialogClick = os.time()

                    pcall(function() obj:Activate() end)
                    if typeof(firesignal) == "function" then
                        pcall(function() firesignal(obj.MouseButton1Click) end)
                    end

                    local pos = obj.AbsolutePosition + obj.AbsoluteSize / 2
                    pcall(function()
                        local VIM = game:GetService("VirtualInputManager")
                        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
                        task.wait(0.06)
                        VIM:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
                    end)
                    return true
                end
            end
        end
        return false
    end

    for _, gui in ipairs(pg:GetChildren()) do
        if scanContainer(gui) then return true end
    end

    local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and coreGui then
        for _, gui in ipairs(coreGui:GetChildren()) do
            if scanContainer(gui) then return true end
        end
    end
    return false
end

LF:RegisterMethod("Refresh", function()
    if _G.SeaTransitionActive then return nil end
    if _G.FruitPriorityActive then return nil end
    if _G.SkyTransitionActive then return nil end
    return 4
end)

LF:RegisterMethod("Start", function(step)
    local currentLevel = ScriptStorage.PlayerData.Level or 0
    if currentLevel >= 700 and Spirit.SeaIndex == 1 then return end

    if Spirit.SeaIndex == 3 then
        if (ScriptStorage.Backpack.Bones or {Count = 0}).Count >= 50 then
            if os.time() > (BonesCooldown or 0) then
                local a, b, c, cooldown = Remotes.CommF_:InvokeServer("Bones", "Check")
                if tonumber(a or 1) == 0 then
                    local parts = Spirit.Split(cooldown, ":")
                    local secs = ((tonumber(parts[1]) * 60) + tonumber(parts[2])) * 60
                    BonesCooldown = os.time() + secs
                else
                    Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
                end
            end
        end
    end

    local Q = ManualLevelLookup()
    if not Q then
        Spirit.Report("LevelFarm: no mob for lv=" .. tostring(currentLevel))
        return
    end

    if Q.PosQ and ensureUnderwaterPath(Q.PosQ) then return end

    local now = os.time()
    local targetKey = Q.Qname .. "|" .. tostring(Q.Qdata) .. "|" .. Q.NameMon

    if LastTargetKey ~= targetKey then
        LastTargetKey     = targetKey
        LastAcceptAttempt = 0
        LastAbandon       = 0
        AtGiverSince      = 0
        AcceptFailCount   = 0
        pcall(function() Spirit.QuestController:Reset() end)
    end

    local guiMob      = Spirit.GetCurrentClaimQuest()
    local controller  = Spirit.QuestController
    local completedAt = controller and controller.JustCompletedAt or 0
    local justCompleted = (completedAt > 0) and (now - completedAt < 3)

    if guiMob and mobMatches(guiMob, Q.NameMon) then
        AcceptFailCount = 0
        Spirit.SetTask("MainTask", "Level Farm | " .. Q.Mon)
        Spirit.CombatController.Attack(Q.Mon)
        return
    end

    if guiMob then
        if now - LastAbandon > 5 then
            LastAbandon = now
            Spirit.J.AbandonQuest(Spirit.J)
        end
        Spirit.SetTask("MainTask", "Level Farm | Abandoning: " .. tostring(guiMob))
        return
    end

    if not justCompleted and (now - LastAcceptAttempt < 5) then
        Spirit.SetTask("MainTask", "Level Farm | Waiting for quest GUI...")
        return
    end

    if not Q.PosQ then return end
    local dist = Spirit.CaculateDistance(Q.PosQ)

    if dist > 15 then
        Spirit.SetTask("MainTask", "Level Farm | Walking to " .. Q.Mon .. " (" .. math.floor(dist) .. ")")
        Spirit.TweenController.Create(Q.PosQ + Vector3.new(0, 5, 3))
        AtGiverSince = 0
        return
    end

    if AtGiverSince == 0 then AtGiverSince = now end

    clickQuestDialog(Q.NameMon)

    if now - LastAcceptAttempt > 5 then
        LastAcceptAttempt = now
        AcceptFailCount   = AcceptFailCount + 1
        pcall(function()
            Spirit.J.StartQuest(Spirit.J, Q.Qname, Q.Qdata)
        end)
    end

    if AcceptFailCount >= 3 then
        clickQuestDialog(Q.NameMon)
    end

    if now - AtGiverSince > 10 then
        Spirit.SetTask("MainTask", "Level Farm | " .. Q.Mon .. " (bypass)")
        Spirit.CombatController.Attack(Q.Mon)
        return
    end

    Spirit.SetTask("MainTask", "Level Farm | Accepting " .. Q.Mon)
end)

Spirit.__level_farm_ready = true
