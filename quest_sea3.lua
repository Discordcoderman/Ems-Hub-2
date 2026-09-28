-- quest_sea3.lua — Sea 2 → Sea 3 (Bartilo chain)
--
-- BartiloQuestProgress("Bartilo") → 0/1/2/3
--   0 = Swan phase, 1 = Jeremy, 2 = Flamingo puzzle, 3 = rip_indra + Zou
-- ZQuestProgress("Check") → 0/1/2
--
-- Gate: level 850.
local Spirit = getgenv().Spirit
if not Spirit then error("[quest_sea3] core.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes
local SetTask       = Spirit.SetTask

local SEA3 = Spirit.SEA3
local ZOU_PLACE_IDS = SEA3.ZOU_PLACE_IDS

local STEP_COOLDOWN     = 1.5
local lastStep          = ""
local lastStepAt        = 0
local cachedBartilo     = nil
local cachedBartiloAt   = 0
local cachedPlatforms   = nil
local cachedPlatformsAt = 0
local puzzleRestartCount = 0
local puzzleLastAttempt  = 0

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

local function getBartilo()
    if os.time() - cachedBartiloAt < 30 and cachedBartilo then return cachedBartilo end
    cachedBartilo   = findModelByName({"Bartilo"})
    cachedBartiloAt = os.time()
    return cachedBartilo
end

local function discoverFlamingoPlatforms()
    if os.time() - cachedPlatformsAt < 15 and cachedPlatforms then
        return cachedPlatforms
    end
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end

    local puzzleCenter = SEA3.FLAMINGO_PUZZLE_CF.Position
    local found = {}
    local byIndex = {}

    for _, obj in ipairs(map:GetDescendants()) do
        if obj:IsA("BasePart") then
            local d = (obj.Position - puzzleCenter).Magnitude
            if d < 120 then
                local lower = string.lower(obj.Name)
                if string.find(lower, "flamingo", 1, true)
                   or string.find(lower, "platform", 1, true)
                   or string.find(lower, "puzzle", 1, true) then
                    local num = tonumber(obj.Name:match("(%d+)"))
                    if num and num >= 1 and num <= 8 then
                        local isLit = false
                        pcall(function()
                            if obj.Material == Enum.Material.Neon
                               or obj.Material == Enum.Material.Glass then
                                isLit = true
                            end
                            if obj.BrickColor
                               and obj.BrickColor.Name:lower():find("neon") then
                                isLit = true
                            end
                        end)
                        byIndex[num] = {part = obj, position = obj.Position, lit = isLit}
                    end
                end
            end
        end
    end

    for i = 1, 8 do
        if byIndex[i] then table.insert(found, byIndex[i]) end
    end

    cachedPlatforms   = (#found > 0) and found or nil
    cachedPlatformsAt = os.time()
    return cachedPlatforms
end

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
    return false
end

local function step(name, msg)
    if lastStep ~= name then
        lastStep   = name
        lastStepAt = os.time()
    end
    if msg then SetTask("MainTask", msg) end
end

local function questGuiHas(keyword, count)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    for _, obj in ipairs(pg:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton"))
           and obj.Text and obj.Text ~= "" then
            local t = tostring(obj.Text)
            if t:find(keyword, 1, true)
               and (not count or t:find(count, 1, true)) then
                return true
            end
        end
    end
    return false
end

local function solveFlamingoPuzzle()
    SetTask("MainTask", "Auto Sea 3 | Flamingo puzzle")

    local platforms = discoverFlamingoPlatforms()
    local positions = {}
    if platforms and #platforms >= 8 then
        for i = 1, 8 do
            positions[i] = platforms[i].position
        end
    else
        for i, cf in ipairs(SEA3.FLAMINGO_PLATFORM_CFS) do
            positions[i] = cf.Position
        end
    end

    if #positions == 0 then
        Spirit.Report("[Sea3] Flamingo puzzle — no platforms discovered")
        return false
    end

    if puzzleRestartCount >= 3 and (tick() - puzzleLastAttempt) < 90 then
        return false
    end

    for i, pos in ipairs(positions) do
        SetTask("SubTask", "Platform " .. i .. "/8")

        local arriveDeadline = tick() + 12
        while tick() < arriveDeadline do
            local hrp = Spirit.HumanoidRootPart
            if not hrp then return false end
            local d = (hrp.Position - pos).Magnitude
            if d < 6 then break end
            Spirit.TweenController.Create(CFrame.new(pos))
            task.wait(0.2)
        end

        local hrp = Spirit.HumanoidRootPart
        if hrp then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            task.wait(0.35)
        end
    end

    puzzleRestartCount = puzzleRestartCount + 1
    puzzleLastAttempt  = tick()
    return true
end

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if not (Spirit.Config and Spirit.Config.AutoSea3) then
                if _G.SeaTransitionActive then _G.SeaTransitionActive = false end
                return
            end
            if Spirit.SeaIndex == 3 then
                if _G.SeaTransitionActive then _G.SeaTransitionActive = false end
                return
            end
            if Spirit.SeaIndex ~= 2 then return end
            -- Level 850 gate.
            if (ScriptStorage.PlayerData.Level or 0) < 850 then return end
            if ZOU_PLACE_IDS[game.PlaceId] then return end

            _G.SeaTransitionActive = true

            if os.time() - lastStepAt < STEP_COOLDOWN then return end

            local b = Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
            if type(b) ~= "number" then
                step("wait-state", "Auto Sea 3 | Waiting for Bartilo state")
                return
            end

            local bartilo   = getBartilo()
            local bartiloCF = cfOf(bartilo) or SEA3.BARTILO_LOCATIONS[2]

            if b == 0 then
                local hasSwanQuest = questGuiHas("Swan", "50")
                if hasSwanQuest then
                    step("swan", "Auto Sea 3 | Swan Pirates ×50")
                    Spirit.CombatController.Attack("Swan Pirate")
                    return
                end
                step("bartilo-swan", "Auto Sea 3 | Talk to Bartilo")
                local d = distanceTo(bartiloCF)
                if d > 12 then
                    Spirit.TweenController.Create(bartiloCF + Vector3.new(0, 4, 3))
                    return
                end
                lastStepAt = os.time()
                pcall(function()
                    Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
                end)
                pcall(fireNear, bartiloCF.Position, 12)
                return
            end

            if b == 1 then
                local jeremy = Workspace.Enemies:FindFirstChild("Jeremy")
                if jeremy and jeremy:FindFirstChild("Humanoid")
                   and jeremy.Humanoid.Health > 0 then
                    step("jeremy", "Auto Sea 3 | Jeremy")
                    Spirit.CombatController.Attack("Jeremy")
                    return
                end
                step("bartilo-jeremy", "Auto Sea 3 | Talk to Bartilo")
                local d = distanceTo(bartiloCF)
                if d > 12 then
                    Spirit.TweenController.Create(bartiloCF + Vector3.new(0, 4, 3))
                    return
                end
                lastStepAt = os.time()
                pcall(function()
                    Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
                end)
                pcall(fireNear, bartiloCF.Position, 12)
                return
            end

            if b == 2 then
                local solved = solveFlamingoPuzzle()
                if not solved then
                    step("bartilo-puzzle", "Auto Sea 3 | Talk to Bartilo")
                    local d = distanceTo(bartiloCF)
                    if d > 12 then
                        Spirit.TweenController.Create(bartiloCF + Vector3.new(0, 4, 3))
                        return
                    end
                    lastStepAt = os.time()
                    pcall(function()
                        Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
                    end)
                    pcall(fireNear, bartiloCF.Position, 12)
                end
                return
            end

            if b == 3 then
                local z = Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")

                if z == 0 then
                    local riprip = Workspace.Enemies:FindFirstChild("rip_indra True Form")
                        or Workspace.Enemies:FindFirstChild("rip_indra")

                    if riprip and riprip:FindFirstChild("Humanoid")
                       and riprip.Humanoid.Health > 0 then
                        step("kill-riprip", "Auto Sea 3 | rip_indra True Form")
                        Spirit.CombatController.Attack("rip_indra True Form")

                        local t0 = tick()
                        repeat task.wait(0.3)
                            local still = Workspace.Enemies:FindFirstChild("rip_indra True Form")
                                or Workspace.Enemies:FindFirstChild("rip_indra")
                            if still and still:FindFirstChild("Humanoid")
                               and still.Humanoid.Health > 0 then
                                Spirit.CombatController.Attack(still.Name)
                            end
                        until not (Workspace.Enemies:FindFirstChild("rip_indra True Form")
                                    or Workspace.Enemies:FindFirstChild("rip_indra"))
                           or (tick() - t0) > 120

                        task.wait(1.5)
                        return
                    end

                    step("summon-riprip", "Auto Sea 3 | Summoning rip_indra")
                    local d = distanceTo(SEA3.RIPPLE_ENTRY_CF)
                    if d > 12 then
                        Spirit.TweenController.Create(SEA3.RIPPLE_ENTRY_CF + Vector3.new(0, 4, 3))
                        return
                    end

                    lastStepAt = os.time()
                    if not _G.RipIndraBegun then
                        pcall(function()
                            Remotes.CommF_:InvokeServer("ZQuestProgress", "Begin")
                        end)
                        _G.RipIndraBegun = true
                    end
                    pcall(fireNear, SEA3.RIPPLE_ENTRY_CF.Position, 15)
                    return
                end

                if z == 1 then
                    step("travel-zou", "Auto Sea 3 | Traveling to Zou")
                    lastStepAt = os.time()
                    pcall(function()
                        Remotes.CommF_:InvokeServer("TravelZou")
                    end)

                    local t0 = tick()
                    repeat task.wait(1) until
                        ZOU_PLACE_IDS[game.PlaceId]
                        or Spirit.SeaIndex == 3
                        or (tick() - t0) > 60

                    if Spirit.SeaIndex == 3 or ZOU_PLACE_IDS[game.PlaceId] then
                        _G.SeaTransitionActive = false
                        _G.RipIndraBegun = false
                        lastStep = ""
                    end
                    return
                end

                local don = Workspace.Enemies:FindFirstChild("Don Swan")
                if don and don:FindFirstChild("Humanoid")
                   and don.Humanoid.Health > 0 then
                    step("don-swan", "Auto Sea 3 | Don Swan")
                    Spirit.CombatController.Attack("Don Swan")
                    return
                end

                step("bartilo-final", "Auto Sea 3 | Talk to Bartilo (final)")
                local d = distanceTo(bartiloCF)
                if d > 12 then
                    Spirit.TweenController.Create(bartiloCF + Vector3.new(0, 4, 3))
                    return
                end
                lastStepAt = os.time()
                pcall(function()
                    Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo")
                end)
                pcall(fireNear, bartiloCF.Position, 12)
            end
        end)
    end
end)

Spirit.__quest_sea3_ready = true
