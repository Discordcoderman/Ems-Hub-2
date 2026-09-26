-- main.lua — startup side effects + main tick loop
local Spirit = getgenv().Spirit
if not Spirit then error("[main] core.lua not loaded") end
if not Spirit.FunctionsHandler then error("[main] tasks.lua not loaded") end
if not Spirit.EmsUI then error("[main] ui.lua not loaded") end

local Services          = Spirit.Services
local LocalPlayer       = Spirit.LocalPlayer
local ReplicatedStorage = Services.ReplicatedStorage
local Remotes           = Spirit.Remotes
local ScriptStorage     = Spirit.ScriptStorage
local SetTask           = Spirit.SetTask
local SetText           = Spirit.SetText

-- ═══════════════════════════════════════════════════════════════
-- NOTIFICATION LISTENERS
-- ═══════════════════════════════════════════════════════════════
local Notify = {Listeners = {}}
Spirit.TorchEnabledTime = 0
Spirit.DoneCdkTick      = 0

Spirit.NotificationCallBack = function(msg)
    for pattern, fn in pairs(Notify.Listeners) do
        if string.find(string.lower(msg), string.lower(pattern)) then
            pcall(fn, msg)
        end
    end
end

local function RegisterNotify(pattern, fn) Notify.Listeners[pattern] = fn end
Spirit.RegisterNotifyListener = RegisterNotify

RegisterNotify("go!",    function() Spirit.LastRaidAlert  = os.time() end)
RegisterNotify("raid",   function() Spirit.LastRaidAlert2 = os.time() end)
RegisterNotify("torch",  function() Spirit.TorchEnabledTime = os.time() end)
RegisterNotify("scroll reacts", function() Spirit.DoneCdkTick = os.time() end)
RegisterNotify("level",  function() Spirit.AddPoint() end)
RegisterNotify("elite",  function()
    if Spirit.FunctionsHandler.Yama and Spirit.FunctionsHandler.Yama.Set then
        Spirit.FunctionsHandler.Yama:Set("EliteCount",
            Remotes.CommF_:InvokeServer("EliteHunter", "Progress"))
    end
end)

RegisterNotify("quest completed", function()
    pcall(function()
        if Spirit.QuestController and Spirit.QuestController.Reset then
            Spirit.QuestController:Reset()
        end
    end)
    Spirit.J:RefreshQuest()
end)

RegisterNotify("been spotted approaching", function()
    if Spirit.FunctionsHandler.PirateRaid then
        Spirit.FunctionsHandler.PirateRaid:Set("Senque", os.time())
    end
end)
RegisterNotify("job", function()
    if Spirit.FunctionsHandler.PirateRaid then
        Spirit.FunctionsHandler.PirateRaid:Set("Senque", 0)
    end
end)

pcall(function()
    local orig = require(ReplicatedStorage.Notification).new
    local hooked
    hooked = hookfunction(orig, function(a, b)
        pcall(function()
            Spirit.NotificationCallBack(tostring(a or "") .. tostring(b or ""))
        end)
        return hooked(a, b)
    end)
end)

-- Quest safety net — resets stale remote state.
task.spawn(function()
    local emptyStreak = 0
    while task.wait(1) do
        local mob = nil
        pcall(function() mob = Spirit.GetCurrentClaimQuest() end)
        if mob then
            emptyStreak = 0
        else
            emptyStreak = emptyStreak + 1
            if emptyStreak >= 5
               and Spirit.QuestController
               and Spirit.QuestController.CurrentQuest ~= "" then
                pcall(function() Spirit.QuestController:Reset() end)
                emptyStreak = 0
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- FPS BOOST
-- ═══════════════════════════════════════════════════════════════
local GRAYABLE = {
    BasePart = true, MeshPart = true, UnionOperation = true,
    Decal = true, Texture = true, ParticleEmitter = true,
    Trail = true, Smoke = true, Fire = true,
}

local function GrayAndOptimize(obj)
    if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") then
        obj.Material    = Enum.Material.Plastic
        obj.Reflectance = 0
        if not obj.Name:find("Handle") and not obj.Name:find("Attachment") then
            pcall(function() obj.Color = Color3.fromRGB(128, 128, 128) end)
        end
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj.Transparency = 1
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail")
        or obj:IsA("Smoke") or obj:IsA("Fire") then
        obj.Enabled = false
    end
end

if Spirit.Config and Spirit.Config.Configuration and Spirit.Config.Configuration.FpsBoost then
    task.spawn(function()
        pcall(function()
            local L = Services.Lighting
            L.GlobalShadows = false
            L.Brightness    = 1
            L.Ambient       = Color3.fromRGB(128, 128, 128)
            if settings and settings().Rendering then
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end
            for _, d in ipairs(workspace:GetDescendants()) do pcall(GrayAndOptimize, d) end
            workspace.DescendantAdded:Connect(function(d)
                if not (Spirit.Config and Spirit.Config.Configuration and Spirit.Config.Configuration.FpsBoost) then return end
                if not GRAYABLE[d.ClassName] then return end
                pcall(GrayAndOptimize, d)
            end)
        end)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- IDLE KICK PREVENTION
-- ═══════════════════════════════════════════════════════════════
LocalPlayer.Idled:Connect(function()
    Services.VirtualUser:CaptureController()
    Services.VirtualUser:ClickButton2(Vector2.new())
end)

-- ═══════════════════════════════════════════════════════════════
-- STARTUP SIDE EFFECTS
-- ═══════════════════════════════════════════════════════════════
SetTask("MainTask", "Level Farming")
SetTask("SubTask", "Idle")

pcall(function() Spirit.AddPoint() end)
pcall(function() Spirit.J:RefreshQuest() end)
pcall(function() Spirit.RefreshInventory() end)
pcall(function() Spirit.RefreshRace() end)

pcall(function()
    Remotes.CommE.OnClientEvent:Connect(function(...)
        local args = {...}
        if args[1] and string.find(tostring(args[1]), "Item") then
            Spirit.RefreshInventory()
        end
    end)
end)

pcall(function() Remotes.CommF_:InvokeServer("Cousin", "Buy") end)

-- Idle timer writer (feeds UI uptime label)
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local elapsed = os.time() - Spirit.timeee
            local total   = elapsed + (Spirit.OldSessionTime or 0)
            if writefile then
                pcall(writefile, ".tdif-" .. LocalPlayer.Name, tostring(total))
            end
            SetText("LiveTime", Spirit.DispTime(elapsed, true))
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════════
SetText("MainTextLabel", "Loaded — waiting for player data...")

while task.wait() do
    pcall(Spirit.RefreshPlayerData)

    if ScriptStorage.PlayerData.Level and ScriptStorage.PlayerData.Level > 0 then
        local ok, err = xpcall(Spirit.RefreshTasksData, debug.traceback)
        if not ok then
            task.wait(1)
        end
    else
        task.wait(1)
    end
end
