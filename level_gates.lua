-- level_gates.lua — Ken V1 gate only.
-- Sea 2 and Sea 3 transitions are owned by quest_sea2.lua and
-- quest_sea3.lua. This file does not touch them.
--
-- Ken V1: level 300+, Saber owned, 750k Beli, Upper Skylands temple.
local Spirit = getgenv().Spirit
if not Spirit then error("[level_gates] core.lua not loaded") end

local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage
local Remotes       = Spirit.Remotes

local KEN_LEVEL   = 300
local KEN_COST    = 750000
local KEN_RETRY_S = 6

local kenBought = false
local kenLastTry = 0
local kenAtNPC   = false

local function playerHasTag(tag)
    local ok, v = pcall(function() return LocalPlayer:HasTag(tag) end)
    return ok and v == true
end

local function ownsKen()
    return playerHasTag("Ken")
end

local function findInstinctTeacher()
    local candidates = {
        workspace:FindFirstChild("NPCs"),
        game.ReplicatedStorage:FindFirstChild("NPCs"),
    }
    for _, folder in ipairs(candidates) do
        if folder then
            for _, npc in ipairs(folder:GetChildren()) do
                if npc.Name == "Instinct Teacher"
                   or npc.Name == "Lord of Destruction" then
                    local hrp = npc:FindFirstChild("HumanoidRootPart")
                    if hrp then return hrp.CFrame end
                    if npc:IsA("Model") then
                        return npc:GetModelCFrame()
                    end
                end
            end
        end
    end
    return nil
end

local UPPER_SKYLANDS_TEMPLE = CFrame.new(-7894, 5546, -380)

local function hasSaber()
    local char = LocalPlayer.Character
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    if char and char:FindFirstChild("Saber") then return true end
    if bp and bp:FindFirstChild("Saber") then return true end
    if ScriptStorage.Backpack and ScriptStorage.Backpack["Saber"] then return true end
    return false
end

local function tryKen()
    if kenBought or ownsKen() then
        kenBought = true
        return
    end

    local lvl = ScriptStorage.PlayerData.Level or 0
    if lvl < KEN_LEVEL then return end

    if os.time() - kenLastTry < KEN_RETRY_S then return end
    kenLastTry = os.time()

    local beli  = ScriptStorage.PlayerData.Beli or 0
    local saber = hasSaber()

    if not saber then return end
    if beli < KEN_COST then return end
    if not LocalPlayer.Character then return end

    local teacherCF = findInstinctTeacher() or UPPER_SKYLANDS_TEMPLE
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dist = (hrp.Position - teacherCF.Position).Magnitude
    if dist > 15 then
        kenAtNPC = false
        Spirit.TweenController.Create(teacherCF + Vector3.new(0, 5, 3))
        return
    end

    kenAtNPC = true

    local ok, res = pcall(function()
        return Remotes.CommF_:InvokeServer("KenTalk", "Buy")
    end)

    if ok and res == 1 then
        kenBought = true
    end
end

task.spawn(function()
    local waited = 0
    while not LocalPlayer:FindFirstChild("Data") and waited < 60 do
        task.wait(0.5)
        waited = waited + 0.5
    end

    while task.wait(1) do
        pcall(tryKen)
    end
end)

Spirit.__level_gates_ready = true
