-- utility.lua — Trevor, PirateRaid, CollectDrops
--
-- Fruit collector semantics:
--   1. Only "collected" when verified in player's fruit inventory.
--   2. When collected → release priority, farming resumes.
--   3. When inventory full → flag up, Refresh returns nil, farming
--      continues. Recovery probe clears the flag every 5 min.
--   4. When fruit vanished but isn't ours → blacklist 5 min.
local Spirit = getgenv().Spirit
if not Spirit then error("[utility] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[utility] tasks.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes
local SetTask           = Spirit.SetTask
local CheckItem         = Spirit.CheckItem

_G.FruitPriorityActive = false

local Trevor = Spirit.FunctionsHandler.Trevor

Trevor:RegisterMethod("GetFruit", function()
    for _, item in pairs(ScriptStorage.Backpack) do
        if item.Name and item.Name:find("Fruit") and item.Value
           and item.Value > 1000000 and item.Value < 2500000 then
            return item
        end
    end
end)

Trevor:RegisterMethod("Refresh", function()
    if Trevor:Get("IsCompleted") then return nil end
    if (ScriptStorage.PlayerData.Level or 0) < 1100 then return nil end
    local fruit = Trevor.Methods.GetFruit:Call()
    if fruit then Trevor:Set("Fruit", fruit) end
    if not Trevor:Get("IsCompleted") then
        local ok, r = pcall(function() return Remotes.CommF_:InvokeServer("TalkTrevor", "1") end)
        Trevor:Set("IsCompleted", ok and r == 0)
    end
    return (not Trevor:Get("IsCompleted")) and fruit
end)

Trevor:RegisterMethod("Start", function()
    local fruit = Trevor:Get("Fruit")
    if not fruit then return end
    Trevor:Set("Fruit", nil)
    table.insert(ScriptStorage.IgnoreStoreFruits, fruit.Name)
    Remotes.CommF_:InvokeServer("LoadFruit", fruit.Name)
    task.wait()
    Spirit.FunctionsHandler.LocalPlayerController.Methods.EquipTool:Call(Spirit.FruitIdToName(fruit.Name))
    Remotes.CommF_:InvokeServer("TalkTrevor", "1")
    Remotes.CommF_:InvokeServer("TalkTrevor", "2")
    Remotes.CommF_:InvokeServer("TalkTrevor", "3")
    task.wait(1)
    Trevor:Set("IsCompleted", true)
end)

local PR = Spirit.FunctionsHandler.PirateRaid

PR:RegisterMethod("Refresh", function()
    local t = PR:Get("Senque")
    return t and (os.time() - t < 500)
end)

PR:RegisterMethod("Start", function()
    local list = Spirit.GetMonAsSortedRange()
    local anchor = Vector3.new(-5543.5327148438, 313.80062866211, -2964.2585449219)
    if list[1] then
        local hrp = list[1]:FindFirstChild("HumanoidRootPart")
        local hum = list[1]:FindFirstChild("Humanoid")
        if hrp and hum and hum.Health > 0
           and Spirit.CaculateDistance(hrp.CFrame, anchor) < 500 then
            Spirit.CombatController.Attack(list[1].Name)
            return
        end
    end
    Spirit.TweenController.Create(anchor)
end)

local CD = Spirit.FunctionsHandler.CollectDrops

local priorityTarget = nil
local priorityName   = nil

local ownedFruitCache = {}
local blacklist       = {}
local fruitAttempts   = {}

local lastCacheRefresh = 0
local lastScan         = 0
local cachedFruit      = nil
local lastCollectAt    = 0

local ARRIVE_HORIZ          = 25
local ARRIVE_TIMEOUT        = 30
local RETWEEN_EVERY         = 3
local TOUCH_DURATION        = 6
local BLACKLIST_TIME        = 300
local POST_COLLECT_COOLDOWN = 15
local VERIFY_WAIT           = 0.6

local function horizDist(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt(dx * dx + dz * dz)
end

local function resolveFruitName(fruit)
    if not fruit then return nil end
    local attr = fruit:GetAttribute("OriginalName")
    if attr and attr ~= "" then return tostring(attr) end
    local child = fruit:FindFirstChild("OriginalName")
    if child and (child:IsA("StringValue") or child:IsA("ValueBase")) then
        local v = tostring(child.Value)
        if v ~= "" then return v end
    end
    return nil
end

local function isFruitModel(obj)
    if not obj or not obj.Parent then return false end
    if not obj:IsA("Model") then return false end
    if not obj:FindFirstChild("FruitAnimator") then return false end
    return resolveFruitName(obj) ~= nil
end

local function findHandle(fruit)
    if not fruit then return nil end
    local direct = fruit:FindFirstChild("Handle")
    if direct and direct:IsA("BasePart") then return direct end
    for _, obj in ipairs(fruit:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name == "Handle" then return obj end
    end
    for _, obj in ipairs(fruit:GetDescendants()) do
        if obj:IsA("BasePart") then return obj end
    end
    return nil
end

local function isBlacklisted(name)
    local exp = blacklist[name]
    if not exp then return false end
    if os.time() > exp then
        blacklist[name] = nil
        return false
    end
    return true
end

local function blacklistFruit(name)
    blacklist[name] = os.time() + BLACKLIST_TIME
end

local function refreshOwnedFruits()
    if os.time() - lastCacheRefresh < 60 then return end
    lastCacheRefresh = os.time()
    local ok, inv = pcall(function()
        return Remotes.CommF_:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if type(v) == "table" and v.Name then
                ownedFruitCache[v.Name] = true
            end
        end
    end
end

local function ownsFruitFresh(name)
    if not name then return false end
    local ok, inv = pcall(function()
        return Remotes.CommF_:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if type(v) == "table" and v.Name == name then
                ownedFruitCache[name] = true
                return true
            end
        end
    end
    return false
end

local function toolInBackpack(originalName)
    if not originalName then return nil end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if not bp then return nil end
    for _, tool in ipairs(bp:GetChildren()) do
        if tool:IsA("Tool") then
            local attr = tool:GetAttribute("OriginalName")
            if attr == originalName then return tool end
            if tool.Name == originalName then return tool end
            if tool.Name == originalName .. " Fruit" then return tool end
        end
    end
    return nil
end

local function releasePriority()
    priorityTarget = nil
    priorityName   = nil
    lastScan       = 0
    cachedFruit    = nil
    _G.FruitPriorityActive = false
end

local function markCollected(name)
    fruitAttempts[name]   = nil
    ownedFruitCache[name] = true
    lastCollectAt         = os.time()
    releasePriority()
end

local function attemptStore(name, tool, fruit)
    if _G.FruitStorageFull then return false end

    if tool and Spirit.StoreFruitSafe then
        Spirit.StoreFruitSafe(name, tool)
    elseif fruit and fruit.Parent and Spirit.StoreFruitSafe then
        Spirit.StoreFruitSafe(name, fruit)
    end

    task.wait(VERIFY_WAIT)
    return ownsFruitFresh(name)
end

CD:RegisterMethod("Refresh", function()
    if _G.FruitStorageFull then return nil end
    if os.time() - lastCollectAt < POST_COLLECT_COOLDOWN then return nil end

    if priorityTarget then
        if priorityTarget.Parent then return priorityTarget end
        releasePriority()
        return nil
    end

    refreshOwnedFruits()

    if os.time() - lastScan < 1 then return cachedFruit end
    lastScan    = os.time()
    cachedFruit = nil

    for _, obj in ipairs(workspace:GetDescendants()) do
        if isFruitModel(obj) then
            local name = resolveFruitName(obj)
            if name and not isBlacklisted(name) and not ownedFruitCache[name] then
                cachedFruit = obj
                return cachedFruit
            end
        end
    end
    return nil
end)

CD:RegisterMethod("Start", function(fruit)
    if not fruit or not fruit.Parent then return end
    if _G.FruitStorageFull then return end

    local name = resolveFruitName(fruit)
    if not name then
        releasePriority()
        return
    end

    if ownsFruitFresh(name) then
        markCollected(name)
        return
    end

    if priorityTarget ~= fruit then
        priorityTarget = fruit
        priorityName   = name
        _G.FruitPriorityActive = true
    end

    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local handle = findHandle(fruit)
    if not handle or not handle.Position then
        blacklistFruit(name)
        releasePriority()
        return
    end

    local fp    = handle.Position
    local horiz = horizDist(hrp.Position, fp)

    if horiz > ARRIVE_HORIZ then
        SetTask("MainTask", "Fruit: " .. name .. " (" .. math.floor(horiz) .. " studs)")
        Spirit.TweenController.Create(CFrame.new(fp))

        local arriveDeadline = tick() + ARRIVE_TIMEOUT
        local lastRetween    = tick()
        while tick() < arriveDeadline do
            if _G.FruitStorageFull then
                releasePriority()
                return
            end
            if not fruit.Parent then break end
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then break end
            if horizDist(h.Position, fp) < ARRIVE_HORIZ then break end
            if tick() - lastRetween > RETWEEN_EVERY then
                Spirit.TweenController.Create(CFrame.new(fp))
                lastRetween = tick()
            end
            task.wait(0.1)
        end
    end

    if not fruit.Parent then
        local tool = toolInBackpack(name)
        if attemptStore(name, tool, nil) then
            markCollected(name)
            return
        end
        blacklistFruit(name)
        releasePriority()
        return
    end

    if Spirit.TweenInstance then
        pcall(function() Spirit.TweenInstance:Cancel() end)
    end
    Spirit.shouldTween = false

    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h and handle.Parent then
        h.CFrame = CFrame.new(fp + Vector3.new(0, 3, 0))
        task.wait(0.1)
    end

    SetTask("MainTask", "Fruit: " .. name .. " — picking up")
    local touchDeadline = tick() + TOUCH_DURATION
    while tick() < touchDeadline do
        if _G.FruitStorageFull then
            releasePriority()
            return
        end
        if not fruit.Parent then break end

        local h2 = findHandle(fruit)
        if not h2 or not h2.Parent then break end

        pcall(function()
            if firetouchinterest then
                local cc = LocalPlayer.Character
                local hh = cc and cc:FindFirstChild("HumanoidRootPart")
                if hh then
                    if horizDist(hh.Position, h2.Position) > 5 then
                        hh.CFrame = CFrame.new(h2.Position + Vector3.new(0, 3, 0))
                    end
                    firetouchinterest(hh, h2, 0)
                    task.wait(0.05)
                    firetouchinterest(hh, h2, 1)
                end
            end
        end)
        task.wait(0.4)
    end

    if not fruit.Parent then
        local tool = toolInBackpack(name)
        if attemptStore(name, tool, nil) then
            markCollected(name)
            return
        end
        if _G.FruitStorageFull then
            releasePriority()
            return
        end
        blacklistFruit(name)
        releasePriority()
        return
    end

    local tool = toolInBackpack(name)
    if tool then
        if attemptStore(name, tool, nil) then
            markCollected(name)
            return
        end
        if _G.FruitStorageFull then
            releasePriority()
            return
        end
        local attempts = (fruitAttempts[name] or 0) + 1
        fruitAttempts[name] = attempts
        if attempts >= 3 then blacklistFruit(name) end
        releasePriority()
        return
    end

    if attemptStore(name, nil, fruit) then
        markCollected(name)
        return
    end

    if _G.FruitStorageFull then
        releasePriority()
        return
    end

    local attempts = (fruitAttempts[name] or 0) + 1
    fruitAttempts[name] = attempts
    if attempts >= 3 then blacklistFruit(name) end
    releasePriority()
end)

local SSP = Spirit.FunctionsHandler.SecondSeaPuzzle
SSP:RegisterMethod("Refresh", function() return nil end)
SSP:RegisterMethod("Start", function() end)

for _, name in ipairs({"ColosseumPuzzle", "ThirdSeaPuzzle", "CollectBerries", "ExpRedeem"}) do
    local H = Spirit.FunctionsHandler[name]
    H:RegisterMethod("Refresh", function() return nil end)
    H:RegisterMethod("Start", function() end)
end

local UI = Spirit.FunctionsHandler.UtillyItemsActivitation
UI:RegisterMethod("Refresh", function() return nil end)
UI:RegisterMethod("Start", function() end)

Spirit.__utility_ready = true
