-- loader.lua — EMS HUB boot entry
-- Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/Discordcoderman/Ems-Hub-2/main/loader.lua?t=" .. tostring(os.time()) .. "&r=" .. tostring(math.random(1, 1e6))))()

local BRANCH = "main"
local BASE = ("https://raw.githubusercontent.com/Discordcoderman/Ems-Hub-2/%s/%%s"):format(BRANCH)
local TEAM = "Pirates"

-- Per-run cache-buster. Same value used for every module fetch this boot,
-- unique per execution so the executor never serves a cached copy of any
-- module from a previous session.
local CACHE_BUST = "?t=" .. tostring(os.time())
    .. "&r=" .. tostring(math.random(1, 1000000))

local MODULES = {
    "core.lua",
    "data.lua",
    "tween.lua",
    "combat.lua",
    "quests.lua",
    "tasks.lua",
    "ui.lua",
    "player.lua",
    "mele.lua",
    "race.lua",
    "bosses.lua",
    "swords.lua",
    "gacha.lua",
    "utility.lua",
    "farming.lua",
    "quest_sea2.lua",
    "quest_sea3.lua",
    "level_farm.lua",
    "level_gates.lua",
    "main.lua",
}

local env = getgenv()

task.spawn(function()
    local lplayer = game:GetService("Players").LocalPlayer
    local deadline = os.time() + 90
    repeat
        task.wait()
        pcall(function()
            game.ReplicatedStorage.Remotes.CommF_:InvokeServer("SetTeam", TEAM)
        end)
        if os.time() > deadline then return end
    until lplayer.Character
end)

local function load_module(path)
    local url = BASE:format(path) .. CACHE_BUST
    local ok, src = pcall(game.HttpGet, game, url)
    if not ok or not src or src == "" then
        warn(("[EMS] fetch failed: %s"):format(path))
        return false
    end
    if src:sub(1, 9) == "<!DOCTYPE" or src:sub(1, 5) == "404: " then
        warn(("[EMS] %s returned HTML — verify the raw URL"):format(path))
        return false
    end
    local fn, compile_err = loadstring(src, "@" .. path)
    if not fn then
        warn(("[EMS] compile error in %s: %s"):format(path, tostring(compile_err)))
        return false
    end
    if type(setfenv) == "function" then pcall(setfenv, fn, env) end
    local run_ok, run_err = pcall(fn)
    if not run_ok then
        warn(("[EMS] runtime error in %s: %s"):format(path, tostring(run_err)))
        return false
    end
    return true
end

for _, path in ipairs(MODULES) do
    if not load_module(path) then
        warn(("[EMS] halted at %s"):format(path))
        return
    end
    task.wait(0.03)
end

print("[EMS] initialized")
