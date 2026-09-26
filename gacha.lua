-- gacha.lua — Zioles Gacha boot roll + continuous fruit auto-store
-- Patched: fruit-storage-full detection + auto-recovery probe.
local Spirit = getgenv().Spirit
if not Spirit then error("[gacha] core.lua not loaded") end

local Services          = Spirit.Services
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

-- ═══════════════════════════════════════════════════════════════
-- FRUIT STORE SAFE — shared helper for anywhere fruit is stored.
-- Returns true on success. Detects storage-full by N consecutive
-- failures where the tool is still in the backpack after the
-- StoreFruit invoke. Sets _G.FruitStorageFull so fruit priority
-- and the store watcher both skip until recovery.
-- ═══════════════════════════════════════════════════════════════
local fruitStoreFailures = 0
local FRUIT_STORE_FAIL_THRESHOLD = 3

_G.FruitStorageFull = _G.FruitStorageFull or false

function Spirit.StoreFruitSafe(name, tool)
    if _G.FruitStorageFull then return false end

    local ok = pcall(function()
        Remotes.CommF_:InvokeServer("StoreFruit", name, tool)
    end)
    task.wait(0.4)

    -- Success check: tool gone from backpack / character.
    local stillHeld = false
    if tool and tool.Parent then
        local parentName = tool.Parent.Name
        if parentName == "Backpack" or parentName ~= "Backpack" then
            stillHeld = true
        end
    end

    if not ok or stillHeld then
        fruitStoreFailures = fruitStoreFailures + 1
        if fruitStoreFailures >= FRUIT_STORE_FAIL_THRESHOLD then
            _G.FruitStorageFull = true
        end
        return false
    end

    fruitStoreFailures = 0
    return true
end

-- Recovery probe — every 5 min, clear the flag so the next store
-- attempt can rebuild the failure count. If storage is still full,
-- the flag re-trips within 3 attempts.
task.spawn(function()
    while task.wait(300) do
        if _G.FruitStorageFull then
            _G.FruitStorageFull  = false
            fruitStoreFailures   = 0
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- FRUIT STORE WATCHER
-- ═══════════════════════════════════════════════════════════════
local ownFruitCache = {}
local lastCacheAt   = 0
local STORE_COOLDOWN = 1

local function refreshOwnFruitCache()
    if os.time() - lastCacheAt < 30 then return end
    lastCacheAt = os.time()
    local ok, inv = pcall(function()
        return Remotes.CommF_:InvokeServer("getInventoryFruits")
    end)
    if ok and type(inv) == "table" then
        for _, v in pairs(inv) do
            if type(v) == "table" and v.Name then
                ownFruitCache[v.Name] = true
            end
        end
    end
end

local function isIgnored(name, originalName)
    if not ScriptStorage.IgnoreStoreFruits then return false end
    for _, ig in ipairs(ScriptStorage.IgnoreStoreFruits) do
        if ig == name or ig == originalName then return true end
    end
    return false
end

local function storeFruitTool(tool)
    if not tool or not tool.Parent then return end
    if not tool:IsA("Tool") then return end

    local original = tool:GetAttribute("OriginalName")
    if not original or original == "" then
        if string.find(tool.Name, "Fruit") then
            original = string.gsub(tool.Name, " Fruit$", "")
        else
            return
        end
    end

    if isIgnored(tool.Name, original) then return end

    Spirit.StoreFruitSafe(original, tool)
    ownFruitCache[original] = true
end

local function scanContainer(container)
    if not container then return end
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Tool") then
            local tip       = child.ToolTip
            local nameFruit = string.find(child.Name, "Fruit")
            local origFruit = child:GetAttribute("OriginalName")
            if tip == "Blox Fruit" or nameFruit or origFruit then
                storeFruitTool(child)
            end
        end
    end
end

task.spawn(function()
    while task.wait(STORE_COOLDOWN) do
        -- Skip whole scan while storage is flagged full. Recovery
        -- probe clears the flag every 5 min.
        if not _G.FruitStorageFull then
            pcall(function()
                refreshOwnFruitCache()
                scanContainer(LocalPlayer:FindFirstChild("Backpack"))
                scanContainer(LocalPlayer.Character)
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- RF DISCOVERY
-- ═══════════════════════════════════════════════════════════════
local GachaRF
local gachaResolved = false

local function tryResolve()
    if gachaResolved and GachaRF and GachaRF.Parent then return GachaRF end
    gachaResolved = true

    do
        local net = ReplicatedStorage:FindFirstChild("Modules")
                    and ReplicatedStorage.Modules:FindFirstChild("Net")
        if net then
            local rf = net:FindFirstChild("RF/GachaNetworkRF")
                or net:FindFirstChild("GachaNetworkRF")
            if rf and rf:IsA("RemoteFunction") then
                GachaRF = rf
                return rf
            end
        end
    end

    do
        local net = ReplicatedStorage:FindFirstChild("Modules")
                    and ReplicatedStorage.Modules:FindFirstChild("Net")
        if net then
            for _, obj in ipairs(net:GetDescendants()) do
                if obj:IsA("RemoteFunction") and string.find(obj.Name, "Gacha") then
                    GachaRF = obj
                    return obj
                end
            end
        end
    end

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteFunction") and string.find(obj.Name, "Gacha") then
            GachaRF = obj
            return obj
        end
    end

    return nil
end

local function gachaCall(ctx)
    local rf = tryResolve()
    if not rf then return false, "no RF" end
    local ok, result = pcall(function()
        return rf:InvokeServer({
            SpokeNPC = "Blox Fruit Gacha",
            Context  = ctx,
            BoxName  = "ZiolesGacha",
        })
    end)
    if not ok then return false, tostring(result) end
    return true, result
end

local function storeSweepNow()
    if _G.FruitStorageFull then return end
    pcall(function()
        scanContainer(LocalPlayer:FindFirstChild("Backpack"))
        scanContainer(LocalPlayer.Character)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- BOOT ROLL
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 90 do
        task.wait(0.5)
        waited = waited + 0.5
    end
    if not LocalPlayer:FindFirstChild("Data") then return end

    task.wait(1)

    local ok, result = gachaCall("Check")
    if not ok then return end

    local ready = false
    if type(result) == "table" then
        ready = (result.RequirementsMet == true)
             or (result.CanPurchase == true)
             or (result.CanRoll == true)
             or (result.Available == true)
    elseif type(result) == "boolean" then
        ready = result
    end

    if not ready then return end

    local pok = gachaCall("Purchase")
    if pok then
        task.wait(1)
        storeSweepNow()
        task.wait(2)
        storeSweepNow()
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- ONGOING CYCLE — 30 min check, 6 h lock after success
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    while not LocalPlayer:FindFirstChild("Data") do task.wait(2) end
    task.wait(30)

    local nextAttempt = os.time() + 60
    while task.wait(30) do
        pcall(function()
            local E = Spirit.Config and Spirit.Config.Extras
            if E and E.AutoGachaFruit == false then return end
            if os.time() < nextAttempt then return end

            local ok, checkResult = gachaCall("Check")
            if not ok then
                nextAttempt = os.time() + 300
                return
            end

            local ready = false
            if type(checkResult) == "table" then
                ready = (checkResult.RequirementsMet == true)
                     or (checkResult.CanPurchase == true)
                     or (checkResult.CanRoll == true)
                     or (checkResult.Available == true)
            elseif type(checkResult) == "boolean" then
                ready = checkResult
            end

            if not ready then
                nextAttempt = os.time() + (30 * 60)
                return
            end

            local minBeli = (E and E.GachaMinBeli) or 100000
            local beli    = Spirit.ScriptStorage.PlayerData.Beli or 0
            if beli < minBeli then
                nextAttempt = os.time() + 120
                return
            end

            local pok = gachaCall("Purchase")
            if pok then
                nextAttempt = os.time() + (6 * 60 * 60)
                task.wait(1)
                storeSweepNow()
                task.wait(2)
                storeSweepNow()
            else
                nextAttempt = os.time() + (10 * 60)
            end
        end)
    end
end)

Spirit.__gacha_ready = true
