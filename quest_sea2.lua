-- quest_sea2.lua — Sea 1 → Sea 2 (Ice Admiral chain)
--
-- Server state source of truth: DressrosaQuestProgress remote
--   returns a table with .TalkedDetective and .KilledIceBoss
--
-- Flow:
--   1. Talk to Military Detective on Prison Island  → TalkedDetective
--   2. Walk to Ice door at Frozen Village → invoke "UseKey" → Ice Admiral spawns
--   3. Kill Ice Admiral                             → KilledIceBoss
--   4. Return to Detective → invoke "Detective" to close investigation
--   5. Invoke TravelDressrosa → place flips
--
-- Static CFrames live in Spirit.SEA2 (data.lua). Discovery overrides
-- them at runtime where NPCs are found by name.
local Spirit = getgenv().Spirit
if not Spirit then error("[quest_sea2] core.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask

local SEA2 = Spirit.SEA2
local DRESSROSA_PLACE_IDS = {
    [4442272183]     = true,
    [79091703265657] = true,
}

local STEP_COOLDOWN = 1.5
local lastStep      = ""
local lastStepAt    = 0
local cachedNpcs    = {detective = nil, captain = nil, detectiveAt = 0, captainAt = 0}
local ICE_KILL_TIMEOUT = 120

-- ═══════════════════════════════════════════════════════════════
-- NPC DISCOVERY — cache for 30s to avoid GetDescendants() spam
-- ═══════════════════════════════════════════════════════════════
local function findModelByName(nameList, folders)
    folders = folders or {
        Workspace:FindFirstChild("NPCs"),
        game.ReplicatedStorage:FindFirstChild("NPCs"),
        Workspace:FindFirstChild("Map"),
    }
    for _, folder in ipairs(folders) do
        if folder then
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("Model") then
                    local lower = string.lower(obj.Name)
                    for _, sub in ipairs(nameList) do
                        if string.find(lower, string.lower(sub), 1, true) then
                            return obj
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function cfOf(model)
    if not model then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame end
    local ok, cf = pcall(function() return model:GetModelCFrame() end)
    if ok then return cf end
    return nil
end

local function getDetective()
    if os.time() - cachedNpcs.detectiveAt < 30 and cachedNpcs.detective then
        return cachedNpcs.detective
    end
    local m = findModelByName(SEA2.DETECTIVE_NAMES)
    cachedNpcs.detective   = m
    cachedNpcs.detectiveAt = os.time()
    return m
end

local function getCaptain()
    if os.time() - cachedNpcs.captainAt < 30 and cachedNpcs.captain then
        return cachedNpcs.captain
    end
    local m = findModelByName(SEA2.CAPTAIN_NAMES)
    cachedNpcs.captain   = m
    cachedNpcs.captainAt = os.time()
    return m
end

local function findIceDoor()
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local best, bestD = nil, 500
    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if string.find(name, "door", 1, true)
               or string.find(name, "secret", 1, true) then
                local p = obj:IsA("BasePart") and obj.Position
                           or (obj:FindFirstChild("HumanoidRootPart")
                               and obj.HumanoidRootPart.Position)
                if p then
                    local d = (p - SEA2.FROZEN_VILLAGE_CF.Position).Magnitude
                    if d < bestD then best, bestD = obj, d end
                end
            end
        end
    end
    return best
end

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
local function distanceTo(cf)
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return math.huge end
    return (hrp.Position - cf.Position).Magnitude
end

local function fireNear(pos, radius)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local p = obj.Parent
            if p and p:IsA("BasePart")
               and (p.Position - pos).Magnitude <= radius
               and fireproximityprompt then
                pcall(fireproximityprompt, obj)
                return true
            end
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ClickDetector") then
            local p = obj.Parent
            if p and p:IsA("BasePart")
               and (p.Position - pos).Magnitude <= radius
               and fireclickdetector then
                pcall(fireclickdetector, obj)
                return true
            end
        end
    end
    return false
end

local function step(name, msg)
    if lastStep ~= name then
        lastStep   = name
        lastStepAt = os.time()
    end
    if msg then SetTask("MainTask", msg) end
end

-- ═══════════════════════════════════════════════════════════════
-- STATE MACHINE
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoSea2) then
                if _G.SeaTransitionActive then _G.SeaTransitionActive = false end
                return
            end
            if Spirit.SeaIndex ~= 1 then
                if _G.SeaTransitionActive and Spirit.SeaIndex == 2 then
                    _G.SeaTransitionActive = false
                end
                return
            end
            if (ScriptStorage.PlayerData.Level or 0) < 700 then return end
            if DRESSROSA_PLACE_IDS[game.PlaceId] then return end

            _G.SeaTransitionActive = true

            if os.time() - lastStepAt < STEP_COOLDOWN then return end

            local prog = Remotes.CommF_:InvokeServer("DressrosaQuestProgress")
            if type(prog) ~= "table" then
                step("wait-state", "Auto Sea 2 | Waiting for quest state")
                return
            end

            -- ── Step 1: Talk to Military Detective ──
            if not prog.TalkedDetective then
                step("detective-first", "Auto Sea 2 | Talk to Military Detective")
                local detective = getDetective()
                local cf        = cfOf(detective) or SEA2.PRISON_ISLAND_CF
                local d         = distanceTo(cf)

                if d > 12 then
                    Spirit.TweenController.Create(cf + Vector3.new(0, 4, 3))
                    return
                end

                lastStepAt = os.time()
                pcall(function()
                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
                end)
                pcall(fireNear, cf.Position, 12)
                return
            end

            -- ── Step 2 + 3: Door → Ice Admiral ──
            if not prog.KilledIceBoss then
                local ice = Workspace.Enemies:FindFirstChild("Ice Admiral")
                local iceAlive = ice
                    and ice:FindFirstChild("Humanoid")
                    and ice.Humanoid.Health > 0

                if iceAlive then
                    step("kill-ice", "Auto Sea 2 | Fighting Ice Admiral")
                    Spirit.CombatController.Attack("Ice Admiral")

                    local t0 = tick()
                    repeat task.wait(0.3)
                        local still = Workspace.Enemies:FindFirstChild("Ice Admiral")
                        if still and still:FindFirstChild("Humanoid")
                           and still.Humanoid.Health > 0 then
                            Spirit.CombatController.Attack("Ice Admiral")
                        end
                    until not Workspace.Enemies:FindFirstChild("Ice Admiral")
                       or (tick() - t0) > ICE_KILL_TIMEOUT
                    return
                end

                -- No Ice Admiral yet — walk to door and fire UseKey.
                local doorModel = findIceDoor()
                local doorCF    = cfOf(doorModel) or SEA2.ICE_DOOR_CF
                local d         = distanceTo(doorCF)

                if d > 15 then
                    step("walk-door", "Auto Sea 2 | Walking to Ice door")
                    Spirit.TweenController.Create(doorCF + Vector3.new(0, 5, 3))
                    return
                end

                step("at-door", "Auto Sea 2 | Using Secret Key on door")
                lastStepAt = os.time()

                pcall(function()
                    Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
                end)
                pcall(fireNear, doorCF.Position, 15)

                -- Tween back inside range — server needs us close for spawn.
                Spirit.TweenController.Create(doorCF + Vector3.new(0, 5, 3))
                return
            end

            -- ── Step 4: Return to Detective, close investigation ──
            local detective = getDetective()
            local detCF     = cfOf(detective) or SEA2.PRISON_ISLAND_CF
            local dd        = distanceTo(detCF)
            if dd > 12 then
                step("detective-return", "Auto Sea 2 | Return to Military Detective")
                Spirit.TweenController.Create(detCF + Vector3.new(0, 4, 3))
                return
            end
            pcall(function()
                Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
            end)
            pcall(fireNear, detCF.Position, 12)

            -- ── Step 5: Travel to Dressrosa ──
            step("travel", "Auto Sea 2 | Traveling to Dressrosa")
            lastStepAt = os.time()
            pcall(function()
                Remotes.CommF_:InvokeServer("TravelDressrosa")
            end)

            local t0 = tick()
            repeat task.wait(1) until
                DRESSROSA_PLACE_IDS[game.PlaceId]
                or Spirit.SeaIndex == 2
                or (tick() - t0) > 45

            if Spirit.SeaIndex == 2 or DRESSROSA_PLACE_IDS[game.PlaceId] then
                _G.SeaTransitionActive = false
                lastStep = ""
            end
        end)
    end
end)

Spirit.__quest_sea2_ready = true
