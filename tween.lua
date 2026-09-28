-- tween.lua — TweenController with permanent noclip at 200 studs/s
local Spirit = getgenv().Spirit
if not Spirit then error("[tween] core.lua not loaded") end

local Services      = Spirit.Services
local Workspace     = Services.Workspace
local LocalPlayer   = Spirit.LocalPlayer
local ScriptStorage = Spirit.ScriptStorage

do
    local existing = Workspace:FindFirstChild("Rip_Indra")
    if existing then existing:Destroy() end
end

local block = Instance.new("Part", Workspace)
block.Size        = Vector3.new(1, 1, 1)
block.Name        = "Rip_Indra"
block.Anchored    = true
block.CanCollide  = false
block.CanTouch    = false
block.Transparency = 1
Spirit.block = block

Spirit.shouldTween       = false
Spirit.TweenDebounce     = false
Spirit.TweenInstance     = nil
Spirit.TweenInstance2    = nil
Spirit.TweenDestination  = nil

local function clearCollision(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            part.CanCollide = false
        end
    end
end
Spirit.SetCharacterCollision = function(_) end

task.spawn(function()
    while task.wait(0.1) do
        pcall(clearCollision, LocalPlayer.Character)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    clearCollision(char)
end)

task.spawn(function()
    while task.wait(5) do
        pcall(function()
            local map = Workspace:FindFirstChild("Map")
            if map then
                for _, obj in ipairs(map:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        local n = obj.Name:lower()
                        if n:find("waterbase") or n:find("water_base") or n:find("waterplains") then
                            obj.CanCollide = false
                        end
                    end
                end
            end
        end)
    end
end)

task.spawn(function()
    local lp = LocalPlayer
    repeat task.wait() until lp.Character and lp.Character.PrimaryPart
    block.CFrame = lp.Character.PrimaryPart.CFrame
    while task.wait() do
        pcall(function()
            if Spirit.shouldTween and block and block.Parent == Workspace then
                local char    = lp.Character
                local primary = char and char.PrimaryPart
                if primary and (primary.Position - block.Position).Magnitude <= 200 then
                    primary.CFrame = block.CFrame
                elseif primary then
                    block.CFrame = primary.CFrame
                end
            end
        end)
    end
end)

local HomePoints = {}
pcall(function()
    for _, v in ipairs(Spirit.Services.ReplicatedStorage.NPCs:GetChildren()) do
        if v.Name == "Set Home Point" then
            table.insert(HomePoints, v:GetModelCFrame())
        end
    end
end)
Spirit.HomePoints = HomePoints

local portalCooldown = 0
local function GetPortal(target)
    if tick() - portalCooldown < 2 then return nil end
    portalCooldown = tick()
    if not target then return nil end
    local targetPos
    if typeof(target) == "CFrame"  then targetPos = target.Position
    elseif typeof(target) == "Vector3" then targetPos = target
    else return nil end
    local portals = Spirit.Portals or {}
    if #portals == 0 then return nil end
    local distanceToTarget = Spirit.CaculateDistance(targetPos)
    local threshold        = distanceToTarget - 300
    local best, bestDist   = nil, 9e9
    for _, p in ipairs(portals) do
        local d = Spirit.CaculateDistance(p, targetPos)
        if d < threshold and d < bestDist then
            bestDist = d
            best     = p
        end
    end
    if best then
        pcall(function() Spirit.Remotes.CommF_:InvokeServer("requestEntrance", best) end)
        task.wait()
    end
    return nil
end
Spirit.GetPortal = GetPortal

function Spirit.HoverOver(a, height)
    height = height or 35
    return CFrame.new(Vector3.new(a.X, a.Y, a.Z) + Vector3.new(0, height, 0))
end

local TweenController = {}
Spirit.TweenController = TweenController

function TweenController.Update()
    local hrp = Spirit.HumanoidRootPart
    if not hrp then return end
    local a = hrp.CFrame
    if Spirit.CaculateDistance(a) > 250 then
        pcall(function()
            if Spirit.TweenInstance then Spirit.TweenInstance:Cancel() end
        end)
        Spirit.TweenDebounce = true
        hrp.CFrame = a
        Spirit.TweenDebounce = false
    end
    hrp.CFrame = a + Vector3.new(0, 3, 0)
end

function TweenController.Tween2(target, cf)
    if not target then return end
    Spirit.TweenInstance2 = Services.TweenService:Create(
        target,
        TweenInfo.new(Spirit.CaculateDistance(target.CFrame, cf) / 50, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(cf.X, cf.Y, cf.Z)}
    )
    Spirit.TweenInstance2:Play()
end

function TweenController.Create(target)
    if not target then return end
    if Spirit.TweenDebounce then return end

    local destCF
    if typeof(target) == "CFrame" then
        destCF = target
    elseif typeof(target) == "Vector3" then
        destCF = CFrame.new(target.X, target.Y, target.Z)
    else
        return
    end

    if Spirit.TweenInstance
       and Spirit.TweenInstance.PlaybackState == Enum.PlaybackState.Playing
       and Spirit.TweenDestination
       and (Spirit.TweenDestination.Position - destCF.Position).Magnitude < 4 then
        return
    end

    if Spirit.TweenInstance then
        pcall(function() Spirit.TweenInstance:Cancel() end)
    end

    local character = LocalPlayer.Character
    local hrp       = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local head = character:WaitForChild("Head")
    if not head:FindFirstChild("eltrul") then
        local bv = Instance.new("BodyVelocity")
        bv.Name     = "eltrul"
        bv.MaxForce = Vector3.new(0, math.huge, 0)
        bv.Velocity = Vector3.zero
        bv.Parent   = head
    end

    local distToDest = Spirit.CaculateDistance(destCF)
    if distToDest > 500 then
        if Spirit.SeaIndex == 3 and not ScriptStorage.Backpack["Valkyrie Helm"] then
            -- no portal routing into Sea 3 without Valkyrie Helm
        elseif Spirit.SeaIndex ~= 3 then
            pcall(GetPortal, destCF)
        end
    end

    if Spirit.SeaIndex == 3
       and Spirit.CaculateDistance(Vector3.new(11256, -2138, 9888), destCF)
           < (Spirit.CaculateDistance(destCF) - 700) then
        local gatePos = CFrame.new(-16269.0, 23, 1371)
        if Spirit.CaculateDistance(gatePos) > 60 then
            TweenController.Create(gatePos)
            task.wait(1)
            return
        end
        local net = require(game.ReplicatedStorage.Modules.Net)
        net:RemoteFunction("SubmarineWorkerSpeak"):InvokeServer("TravelToSubmergedIsland")
    end

    destCF = CFrame.new(destCF.Position)
    local dist = Spirit.CaculateDistance(hrp.CFrame, destCF)

    if dist <= 5 then
        hrp.CFrame   = destCF
        block.CFrame = destCF
        return
    end

    local duration = dist / 200

    Spirit.shouldTween      = true
    Spirit.TweenDestination = destCF
    Spirit.TweenInstance    = Services.TweenService:Create(
        block,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {CFrame = destCF}
    )
    Spirit.TweenInstance:Play()

    task.spawn(function()
        while Spirit.TweenInstance
              and Spirit.TweenInstance.PlaybackState == Enum.PlaybackState.Playing do
            if not Spirit.shouldTween then
                pcall(function() Spirit.TweenInstance:Cancel() end)
                break
            end
            task.wait(0.1)
        end
        Spirit.shouldTween = false
    end)
end

Spirit.__tween_ready = true
