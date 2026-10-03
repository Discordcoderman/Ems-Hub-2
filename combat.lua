-- combat.lua — CombatController, BringMobs, fast-attack
--   · Search only reads workspace.Enemies — no ReplicatedStorage fallback
--   · Attack rejects any target not parented to workspace.Enemies
--   · No-target branch returns idle, never tweens to a fallback
local Spirit = getgenv().Spirit
if not Spirit then error("[combat] core.lua not loaded") end
if not Spirit.TweenController then error("[combat] tween.lua not loaded") end

local Services          = Spirit.Services
local Workspace         = Services.Workspace
local ReplicatedStorage = Services.ReplicatedStorage
local LocalPlayer       = Spirit.LocalPlayer
local ScriptStorage     = Spirit.ScriptStorage
local Remotes           = Spirit.Remotes

local function CheckItem(itemName)
    if not itemName then return false end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") and (v.Name == itemName or string.find(v.Name, itemName, 1, true)) then
                return v
            end
        end
    end
    local char = Spirit.Character
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and (v.Name == itemName or string.find(v.Name, itemName, 1, true)) then
                return v
            end
        end
    end
    return false
end
Spirit.CheckItem = CheckItem

if not isnetworkowner then
    isnetworkowner = function(part)
        if not part or not part.Parent then return false end
        if part.Anchored then return false end
        return true
    end
end

local Net = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
local RE_RegisterAttack = Net:WaitForChild("RE/RegisterAttack")
local RE_RegisterHit    = Net:WaitForChild("RE/RegisterHit")

local function GetAllBladeHits()
    local hits = {}
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return hits end
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return hits end
    for _, e in ipairs(enemies:GetChildren()) do
        if e:FindFirstChild("Humanoid")
           and e:FindFirstChild("HumanoidRootPart")
           and e.Humanoid.Health > 0
           and (e.HumanoidRootPart.Position - hrp.Position).Magnitude <= 65 then
            table.insert(hits, e)
        end
    end
    return hits
end

local function Getplayerhit()
    local hits = {}
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return hits end
    local chars = Workspace:FindFirstChild("Characters")
    if not chars then return hits end
    for _, e in ipairs(chars:GetChildren()) do
        if e.Name ~= LocalPlayer.Name
           and e:FindFirstChild("Humanoid")
           and e:FindFirstChild("HumanoidRootPart")
           and e.Humanoid.Health > 0
           and (e.HumanoidRootPart.Position - hrp.Position).Magnitude <= 65 then
            table.insert(hits, e)
        end
    end
    return hits
end

local FastAttack = {}
function FastAttack:Attack()
    local targets = {}
    for _, v in ipairs(GetAllBladeHits()) do table.insert(targets, v) end
    for _, v in ipairs(Getplayerhit())   do table.insert(targets, v) end
    if #targets == 0 then return end

    local payload = {[1] = nil, [2] = {}, [4] = "078da5141"}
    for _, target in ipairs(targets) do
        RE_RegisterAttack:FireServer(0)
        if not payload[1] then
            payload[1] = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
        end
        table.insert(payload[2], {[1] = target, [2] = target.HumanoidRootPart})
        table.insert(payload[2], target)
    end
    RE_RegisterHit:FireServer(unpack(payload))
end

task.spawn(function()
    while task.wait(0.06) do
        if _G.FastAttack == os.time() then
            pcall(function() FastAttack:Attack() end)
        end
    end
end)

local W_Attack = {}
function W_Attack.Attack(_) pcall(function() _G.FastAttack = os.time() end) end
Spirit.W_Attack = W_Attack
Spirit.FastAttackReady = FastAttack

local _aimLock = nil
function Spirit.LockAimPositionTo(pos)
    _aimLock = pos
    task.delay(0.5, function() _aimLock = nil end)
end

local CombatController = {
    GRAB = false,
    GRAB_DISTANCE         = (Spirit.SeaIndex == 1) and 250 or 350,
    MAX_ATTACK_DURATION   = 2,
    MAX_ATTACK_DURATION_2 = 60,
    LEVITATE_TIME         = 0,
    CurrentIndex          = 1,
}
Spirit.CombatController = CombatController

local LastFound    = os.time()
local LastFire12   = 0
local GrabDebounce = 0
Spirit.LastFound   = LastFound

local function Sort1(entity)
    if not entity or not entity:FindFirstChild("HumanoidRootPart") then return math.huge end
    return math.floor(Spirit.CaculateDistance(entity.HumanoidRootPart.CFrame))
end

-- ═══════════════════════════════════════════════════════════════
-- Search — workspace.Enemies ONLY. No ReplicatedStorage fallback.
-- ═══════════════════════════════════════════════════════════════
function CombatController.Search(names)
    local enemies = Workspace:FindFirstChild("Enemies")
    if not enemies then return nil end

    local candidates = {}
    for _, entity in ipairs(enemies:GetChildren()) do
        if table.find(names, entity.Name)
           and entity:FindFirstChild("Humanoid")
           and entity.Humanoid.Health > 0 then
            if (entity:GetAttribute("FailureCount") or 0) < 3 then
                table.insert(candidates, entity)
            end
        end
    end
    table.sort(candidates, function(a, b) return Sort1(a) < Sort1(b) end)
    return candidates[1]
end

function CombatController.Grab(mobName)
    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)
    if not CombatController.GRAB then return end
    if GrabDebounce == os.time() then return end
    GrabDebounce = os.time()
    local MonResult = Spirit.MonResult
    if not MonResult or not MonResult:FindFirstChild("HumanoidRootPart") then return end
    if MonResult.Parent ~= Workspace.Enemies then return end

    local targetPos = MonResult.HumanoidRootPart.Position
    local AreaMob   = false

    for _, enemy in ipairs(Workspace.Enemies:GetChildren()) do
        if enemy ~= MonResult and enemy.Name == mobName then
            local hum  = enemy:FindFirstChildOfClass("Humanoid")
            local root = enemy:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local dist = (root.Position - targetPos).Magnitude
                if dist <= 3000 then
                    local bv = root:FindFirstChild("FarmingVelocity")
                    if not bv then
                        bv = Instance.new("BodyVelocity")
                        bv.Name     = "FarmingVelocity"
                        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
                        bv.Velocity = Vector3.zero
                        bv.Parent   = root
                    end
                    if dist <= 10 then AreaMob = true end
                    if not AreaMob and (not isnetworkowner or pcall(isnetworkowner, root)) then
                        root.CFrame = MonResult.HumanoidRootPart.CFrame
                    end
                    enemy:SetAttribute("IsGrabbed", true)
                end
            end
        end
    end
end

local function EquipToolDynamic(toolName)
    local FH = Spirit.FunctionsHandler
    if FH and FH.LocalPlayerController and FH.LocalPlayerController.Methods
       and FH.LocalPlayerController.Methods.EquipTool then
        FH.LocalPlayerController.Methods.EquipTool:Call(toolName)
    end
end
Spirit.EquipToolDynamic = EquipToolDynamic

local function SweetChaliceInCombat()
    local tool = ScriptStorage.Tools["Sweet Chalice"]
    if not tool then return false end
    local ok, guide = pcall(function() return getsenv(ReplicatedStorage.GuideModule) end)
    if not ok or not guide or not guide._G then return false end
    return guide._G.InCombat and true or false
end

function CombatController.Attack(names, forceNear, forceDist, callback)
    if _G.FruitPriorityActive then return end
    if _G.SkyTransitionActive then return end
    if SweetChaliceInCombat() then
        pcall(function() if Spirit.TweenInstance then Spirit.TweenInstance:Cancel() end end)
        return
    end

    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)
    names = (type(names) == "string") and {names} or (names or {})

    Spirit.BringNames = names
    if #names >= 1 then
        Spirit.Mon = names[1]
    end

    for _, rawName in ipairs(names) do
        local nameStr = tostring(rawName)

        if (nameStr == "Deandre" or nameStr == "Urban"
            or (nameStr == "Diablo" and (os.time() - (LastFire12 or 0)) > 180)) then
            LastFire12 = os.time()
            Remotes.CommF_:InvokeServer("EliteHunter")
        end

        if forceNear then
            local sorted = Spirit.GetMonAsSortedRange()[1]
            local pos = sorted and sorted:FindFirstChild("HumanoidRootPart")
                        and sorted.HumanoidRootPart.Position
            if pos and Spirit.CaculateDistance(pos) < forceDist then
                Spirit.MonResult = sorted
            end
        else
            Spirit.MonResult = CombatController.Search(names)
        end

        local MonResult = Spirit.MonResult

        -- Reject anything not under workspace.Enemies. A ReplicatedStorage
        -- template has a saved CFrame in the sky — following it to Y+35
        -- is what sends the character to ~952m.
        if MonResult and MonResult.Parent ~= Workspace.Enemies then
            MonResult = nil
            Spirit.MonResult = nil
        end

        if MonResult then
            LastFound = os.time()
            Spirit.LastFound = LastFound
            local attackStart    = os.time()
            local unchangedStart = os.time()
            Spirit.SetTask("SubTask", "Attacking " .. tostring(MonResult.Name))

            while task.wait() do
                if _G.Stop then return end
                if _G.FruitPriorityActive then return end
                if _G.SkyTransitionActive then return end

                if SweetChaliceInCombat() then
                    pcall(function() if Spirit.TweenInstance then Spirit.TweenInstance:Cancel() end end)
                    return
                end

                local hum = MonResult:FindFirstChild("Humanoid")
                local hrp = MonResult:FindFirstChild("HumanoidRootPart")
                if not hum or hum.Health <= 0 then break end
                if not hrp then break end

                Spirit.TweenController.Create(Spirit.HoverOver(hrp.Position, 35))

                pcall(function() Spirit.BringMobsTo(MonResult) end)

                if Spirit.CaculateDistance(hrp.Position + Vector3.new(0, 35, 0)) < 150 then
                    if callback then pcall(callback) end
                    CombatController.Grab(names[1] or "")

                    if MonResult.Name ~= "Core" then
                        if ScriptStorage.PlayerData.Level > 100
                           and (os.time() - unchangedStart) >= CombatController.MAX_ATTACK_DURATION_2
                           and (hum.Health - hum.MaxHealth == 0) then
                            Spirit.SetTask("SubTask", "Mob HP unchanged 60s — repositioning")
                            unchangedStart = os.time()
                            Spirit.TweenController.Create(hrp.CFrame + Vector3.new(0, 3, 0))
                        end

                        if (os.time() - attackStart) >= CombatController.MAX_ATTACK_DURATION
                           and (hum.Health - hum.MaxHealth == 0) then
                            attackStart = os.time()
                            local oldPos = MonResult:GetAttribute("OldPosition")
                            if oldPos then
                                MonResult:SetPrimaryPartCFrame(CFrame.new(oldPos))
                                MonResult:SetAttribute("IgnoreGrab", true)
                                MonResult:SetAttribute("FailureCount",
                                    (MonResult:GetAttribute("FailureCount") or 0) + 1)
                                MonResult.HumanoidRootPart.CFrame = CFrame.new(oldPos)
                                task.wait()
                                return
                            end
                        end
                    end

                    local FarmFruitMastery = getgenv().FarmFruitMastery
                    local raidIsland = Spirit.FunctionsHandler
                        and Spirit.FunctionsHandler.RaidController
                        and Spirit.FunctionsHandler.RaidController.Methods
                        and Spirit.FunctionsHandler.RaidController.Methods.GetCurrentRaidIsland
                    local onRaid = raidIsland and raidIsland:Call() or false

                    if FarmFruitMastery
                       and (FarmFruitMastery - os.time()) < 3
                       and math.floor(hum.Health / hum.MaxHealth * 100) < 30
                       and not onRaid then
                        Spirit.TweenController.Create(hrp.CFrame + Vector3.new(0, 25, 0))
                        EquipToolDynamic("Blox Fruit")
                        Spirit.LockAimPositionTo(hrp.Position)
                        local keys = {"Z", "X", "C", "V"}
                        Spirit.SendKey(keys[math.random(1, #keys)], 0.31)
                    else
                        local selected = _G.SelectWeapon
                        if selected and CheckItem(selected) then
                            EquipToolDynamic(selected)
                        else
                            EquipToolDynamic(ScriptStorage.ForceToUseSword and "Sword" or "Melee")
                        end
                    end

                    W_Attack.Attack(MonResult)

                    if os.time() ~= unchangedStart then
                        unchangedStart = os.time()
                    end
                end
            end

        elseif not forceNear then
            -- No live target found. Return idle — do NOT tween anywhere.
            -- Tweening to a fallback position is what moved the character
            -- to a template spawn in the sky.
            return
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- BRING MOBS
-- ═══════════════════════════════════════════════════════════════
getgenv().BringMonster = getgenv().BringMonster or false

local lockedMobs = {}

local function alive(m)
    if not m or not m.Parent then return false end
    if m.Parent ~= Workspace.Enemies then return false end
    local h = m:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function isLocalOwned(part)
    if not part or not part.Parent then return false end
    if part.Anchored then return false end
    if isnetworkowner then
        local ok, res = pcall(isnetworkowner, part)
        return ok and res
    end
    return true
end

local function lockMob(v, hrp, hum)
    if not lockedMobs[v] then
        lockedMobs[v] = {
            walkSpeed  = hum.WalkSpeed,
            jumpPower  = hum.JumpPower,
            autoRotate = hum.AutoRotate,
        }
    end
    for _, a in ipairs(v:GetDescendants()) do
        if a:IsA("BasePart") and a.CanCollide then
            a.CanCollide = false
        end
    end
    local lock = hrp:FindFirstChild("BroughtLock")
    if not lock then
        lock = Instance.new("BodyVelocity")
        lock.Name     = "BroughtLock"
        lock.MaxForce = Vector3.new(10000, 10000, 10000)
        lock.Velocity = Vector3.zero
        lock.Parent   = hrp
    else
        lock.Velocity = Vector3.zero
    end
    hum.WalkSpeed = 0
end

local function releaseMob(v)
    local saved = lockedMobs[v]
    if not saved then return end
    if v.Parent then
        local hrp = v:FindFirstChild("HumanoidRootPart")
        local hum = v:FindFirstChild("Humanoid")
        if hrp then
            local lock = hrp:FindFirstChild("BroughtLock")
            if lock then lock:Destroy() end
        end
        if hum then
            pcall(function()
                hum.WalkSpeed  = saved.walkSpeed  or 16
                hum.JumpPower  = saved.jumpPower  or 50
                hum.AutoRotate = saved.autoRotate ~= false
            end)
        end
    end
    lockedMobs[v] = nil
end

function Spirit.BringMobsTo(targetMob)
    if not targetMob or not targetMob.Parent then return end
    if targetMob.Parent ~= Workspace.Enemies then return end
    local targetHRP = targetMob:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)

    local targetCFrame = targetHRP.CFrame
    for _, v in ipairs(Workspace.Enemies:GetChildren()) do
        if v ~= targetMob and v.Name == targetMob.Name and alive(v) then
            local hrp = v:FindFirstChild("HumanoidRootPart")
            local hum = v:FindFirstChild("Humanoid")
            if hrp and hum and isLocalOwned(hrp) then
                if (hrp.Position - targetCFrame.Position).Magnitude <= 500 then
                    lockMob(v, hrp, hum)
                    v:SetPrimaryPartCFrame(targetCFrame)
                end
            end
        end
    end
end

function Spirit.BringEnemy()
    if not getgenv().BringMonster then return end
    if _G.FruitPriorityActive then return end
    if _G.SkyTransitionActive then return end

    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    pcall(sethiddenproperty, LocalPlayer, "SimulationRadius", math.huge)

    local names = Spirit.BringNames
    if (not names or #names == 0) then
        if Spirit.Mon and Spirit.Mon ~= "" then
            names = {Spirit.Mon}
        else
            return
        end
    end

    local targetCFrame = root.CFrame - Vector3.new(0, 3, 0)
    local pulled = 0
    for _, v in ipairs(Workspace.Enemies:GetChildren()) do
        if pulled >= 20 then break end
        if not table.find(names, v.Name) then continue end
        local hrp = v:FindFirstChild("HumanoidRootPart")
        local hum = v:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end
        if (hrp.Position - root.Position).Magnitude > 350 then continue end
        if not isLocalOwned(hrp) then continue end
        lockMob(v, hrp, hum)
        v:SetPrimaryPartCFrame(targetCFrame)
        pulled = pulled + 1
    end

    for v in pairs(lockedMobs) do
        if not v.Parent then lockedMobs[v] = nil end
    end
end

task.spawn(function()
    while task.wait(0.05) do
        Spirit.BringEnemy()
    end
end)

task.spawn(function()
    local last = getgenv().BringMonster
    while task.wait(1) do
        local cur = getgenv().BringMonster
        if last and not cur then
            for v in pairs(lockedMobs) do pcall(releaseMob, v) end
            lockedMobs = {}
        end
        last = cur
    end
end)

Spirit.__combat_ready = true
