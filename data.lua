-- data.lua — Config, tables, NPC locations, quest-tier maps
local Spirit = getgenv().Spirit
if not Spirit then error("[data] core.lua not loaded") end

Config = Config or {
    Team = "Pirates",
    Configuration = {
        HopWhenIdle = true, AutoHop = true, AutoHopDelay = 60 * 60,
        FpsBoost = false, blackscreen = false, LowGraphics = true,
    },
    Items = {
        AutoFullyMelees = true, Saber = true, CursedDualKatana = true,
        SoulGuitar = true, RaceV2 = true, AutoRaceV3 = true,
        AutoRandomFruit = false, AutoQuest = true,
    },
    Sword = {
        ["Shark Saw"]=true, ["Wardens Sword"]=true, ["Pole (1st Form)"]=true,
        ["Gravity Blade"]=true, ["Longsword"]=true, ["Rengoku"]=true,
        ["Flail"]=true, ["Twin Hooks"]=true,
    },
    BossWeapons = {
        ["Awakened Ice Admiral"]=true, ["Tide Keeper"]=true, ["Deandre"]=true,
        ["Urban"]=true, ["Diablo"]=true, ["Soul Reaper"]=true, ["Cake Prince"]=true,
        ["Core"]=true, ["Darkbeard"]=true, ["Katakuri"]=true, ["Beautiful Pirates"]=true,
    },
    Melee = {
        AutoBuy = true, CheckMasteryAfterBuy = true,
        RaidAtV1Mastery = 400, GodhumanAtV2Mastery = 400,
    },
    AutoKen = true,
    BringMobs = true,
    PanicMode = {
        Enabled = true, LowHealthPercent = 20, SafeHealthPercent = 75,
        EscapeHeight = 2000, CheckInterval = 1,
    },
    Settings = { StayInSea2UntilHaveDarkFragments = true },
    AutoSea2 = true,
    AutoSea3 = true,
    AutoRaidIce_TargetFragments = 5000,
    Extras = {
        NoAnimation      = true,
        AutoRedeemCodes  = true,
        AutoGachaFruit   = false,
        GachaMinBeli     = 100000,
        AutoCollectFruit = true,
        CollectInterval  = 10,
        CollectMode      = "walk",       -- "walk" = CollectDrops tween+pickup, "teleport" = fruit → player
        AutoRandomFruit  = false,
        RandomFruitDelay = 60,           -- seconds between Cousin Buy rolls
        RandomFruitMinBeli = 500000,
    },
    Farming = {
        AutoEliteHunter          = false,
        AutoDoughKing            = false,
        DoughKingStopAfterMirror = true,
        AutoMaterial             = false,
        MaterialTarget           = "",
        MaterialTargetCount      = 100,
        KillAura                 = false,
        KillAuraRadius           = 2000,
        AutoChest                = false,
        AutoChestHop             = false,
        AutoChestCount           = 20,
        StopChestAtChalice       = true,
        SwordMastery600          = false,
        AutoBoss                 = false,
    },
}
Spirit.Config = Config
getgenv().Config = Config

Spirit.MeleesTable = {
    "Black Leg", "Electro", "Fishman Karate", "Dragon Claw", "Superhuman",
    "Death Step", "Electric Claw", "Sharkman Karate", "Dragon Talon", "Godhuman"
}
Spirit.MeleesId = {
    "BlackLeg", "Electro", "FishmanKarate", "DragonClaw", "Superhuman",
    "DeathStep", "ElectricClaw", "SharkmanKarate", "DragonTalon", "Godhuman"
}

Spirit.MeleePrices = {
    ["Black Leg"]       = {Price = {Beli = 150000},    Id = "BlackLeg"},
    ["Electro"]         = {Price = {Beli = 500000},    Id = "Electro"},
    ["Fishman Karate"]  = {Price = {Beli = 750000},    Id = "FishmanKarate"},
    ["Dragon Claw"]     = {Price = {Fragments = 1500}, Id = "DragonClaw"},
    ["Superhuman"]      = {Price = {Beli = 3000000},   Id = "Superhuman"},
    ["Death Step"]      = {Price = {Beli = 2500000, Fragments = 5000}, Id = "DeathStep"},
    ["Sharkman Karate"] = {Price = {Beli = 2500000, Fragments = 5000}, Id = "SharkmanKarate"},
    ["Electric Claw"]   = {Price = {Beli = 2500000, Fragments = 5000}, Id = "ElectricClaw"},
    ["Dragon Talon"]    = {Price = {Beli = 2500000, Fragments = 5000}, Id = "DragonTalon"},
    ["Godhuman"]        = {Price = {Beli = 5000000, Fragments = 5000}, Id = "Godhuman"},
}

Spirit.V1ToV2 = {
    ["Black Leg"]      = "Death Step",
    ["Electro"]        = "Electric Claw",
    ["Fishman Karate"] = "Sharkman Karate",
    ["Dragon Claw"]    = "Dragon Talon",
}

Spirit.MASTERY_TRAIN_ORDER = {
    {name = "Black Leg",       target = 400, tier = "V1"},
    {name = "Electro",         target = 400, tier = "V1"},
    {name = "Fishman Karate",  target = 400, tier = "V1"},
    {name = "Dragon Claw",     target = 400, tier = "V1"},
    {name = "Superhuman",      target = 400, tier = "V1"},
    {name = "Death Step",      target = 400, tier = "V2"},
    {name = "Sharkman Karate", target = 400, tier = "V2"},
    {name = "Electric Claw",   target = 400, tier = "V2"},
    {name = "Dragon Talon",    target = 400, tier = "V2"},
}

Spirit.BindedMeleeNPCNames = {
    BlackLeg="Dark Step Teacher", Electro="Mad Scientist",
    FishmanKarate="Water Kung-fu Teacher", DeathStep="Phoeyu, the Reformed",
    SharkmanKarate="Sharkman Teacher", DragonTalon="Uzoth",
    ElectricClaw="Previous Hero", Godhuman="Ancient Monk",
}

Spirit.TeacherLocations = {
    ["Water Kung-fu Teacher"] = {
        [1] = CFrame.new(61586.96, 19.58, 987.59),
        [2] = CFrame.new(-4957.68, 35.94, -4665.6),
        [3] = CFrame.new(-5023.91, 371.02, -3191.46),
    },
    ["Mad Scientist"] = {
        [1] = CFrame.new(-5382.79, 12.55, -2148.82),
        [2] = CFrame.new(-4866.16, 33.92, -4767.11),
        [3] = CFrame.new(-4996.06, 313.21, -3201.83),
    },
    ["Dark Step Teacher"] = {
        [1] = CFrame.new(-983.62, 12.44, 3990.46),
        [2] = CFrame.new(-4752.44, 33.92, -4848.04),
        [3] = CFrame.new(-5045.61, 370.01, -3182.31),
    },
    ["Phoeyu, the Reformed"] = {
        [2] = CFrame.new(6356.47, 296.1, -6762.78),
        [3] = CFrame.new(-4999.24, 314.01, -3221.58),
    },
    ["Sharkman Teacher"] = {
        [2] = CFrame.new(-2599.63, 238.19, -10316),
        [3] = CFrame.new(-4971.21, 313.88, -3223.08),
    },
    ["Previous Hero"] = { [3] = CFrame.new(-10371.48, 330.76, -10131.42) },
    ["Uzoth"]         = { [3] = CFrame.new(5661.89, 1210.87, 863.17) },
    ["Ancient Monk"]  = { [3] = CFrame.new(-13774.1, 333.73, -9879.91) },
}

Spirit.MeleeTeacher = {
    ["Fishman Karate"]  = "Water Kung-fu Teacher",
    ["Electro"]         = "Mad Scientist",
    ["Black Leg"]       = "Dark Step Teacher",
    ["Death Step"]      = "Phoeyu, the Reformed",
    ["Sharkman Karate"] = "Sharkman Teacher",
    ["Electric Claw"]   = "Previous Hero",
    ["Dragon Talon"]    = "Uzoth",
    ["Godhuman"]        = "Ancient Monk",
}

Spirit.DropItemData = {
    ["Buddy Sword"] = {Sea = 3, Level = 1500, Boss = "Cake Queen"},
    ["Canvander"]   = {Sea = 3, Level = 1500, Boss = "Beautiful Pirate"},
    ["Twin Hooks"]  = {Sea = 3, Level = 1500, Boss = "Captain Elephant"},
    ["Venom Bow"]   = {Sea = 3, Level = 1500, Boss = "Hydra Leader"},
}

Spirit.SeaIndexes = {"Main", "Dressrosa", "Zou"}

Spirit.BossesOrder = {
    "Deandre", "Urban", "Diablo", "Soul Reaper",
    "Cake Queen", "Cake Prince", "Longma", "Don Swan",
    "Beautiful Pirate", "Captain Elephant", "Hydra Leader",
    "Kilo Admiral", "Stone", "Tide Keeper", "Awakened Ice Admiral",
}
Spirit.BossesOrderLevel = {
    ["Awakened Ice Admiral"]=700, ["Tide Keeper"]=700, ["Deandre"]=1500,
    ["Urban"]=1500, ["Diablo"]=1500, ["Soul Reaper"]=1500,
    ["Cake Queen"]=2175, ["Cake Prince"]=1500, ["Longma"]=2000,
    ["Don Swan"]=1100, ["Beautiful Pirate"]=1950, ["Captain Elephant"]=1875,
    ["Hydra Leader"]=1675, ["Kilo Admiral"]=1750, ["Stone"]=1550,
}
Spirit.BossesOrderWL = {
    ["Deandre"]=1500, ["Urban"]=1500, ["Diablo"]=1500, ["Don Swan"]=1100,
    ["Awakened Ice Admiral"]=700, ["Tide Keeper"]=700,
}
Spirit.SpecialBossesOrder = {
    ["Core"]=700, ["Darkbeard"]=700, ["Katakuri"]=2150, ["Beautiful Pirates"]=1500,
}

Spirit.HAUNTED_CASTLE_BONES_CF = CFrame.new(-8817.880859375, 191.16761779785, 6298.6557617188)
Spirit.BeautifulPiratesCF = CFrame.new(5319, 23, -93)

Spirit.BlankTablets = {"Segment6","Segment2","Segment8","Segment9","Segment5"}
Spirit.Trophy = {
    ["Segment1"]="Trophy1", ["Segment3"]="Trophy2", ["Segment4"]="Trophy3",
    ["Segment7"]="Trophy4", ["Segment10"]="Trophy5",
}
Spirit.Pipes = {
    ["Part1"]="Really black", ["Part2"]="Really black", ["Part3"]="Dusty Rose",
    ["Part4"]="Storm blue", ["Part5"]="Really black", ["Part6"]="Parsley green",
    ["Part7"]="Really black", ["Part8"]="Dusty Rose", ["Part9"]="Really black",
    ["Part10"]="Storm blue",
}

Spirit.Portals = ({
    {Vector3.new(-7894.6201171875, 5545.49169921875, -380.246346191406),
     Vector3.new(-4607.82275390625, 872.5422973632812, -1667.556884765625),
     Vector3.new(61163.8515625, 11.759522438049316, 1819.7841796875),
     Vector3.new(3876.280517578125, 35.10614013671875, -1939.3201904296875)},
    {Vector3.new(-288.46246337890625, 306.130615234375, 597.9988403320312),
     Vector3.new(2284.912109375, 15.152046203613281, 905.48291015625),
     Vector3.new(923.21252441406, 126.9760055542, 32852.83203125),
     Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422)},
    {},
})[Spirit.SeaIndex] or {}

Spirit.SEA2 = {
    PRISON_ISLAND_CF         = CFrame.new(5207, 20, 738),
    FROZEN_VILLAGE_CF        = CFrame.new(1298, 87, -1344),
    ICE_DOOR_CF              = CFrame.new(1406, 87, -1376),
    MIDDLE_TOWN_DOCKS_CF     = CFrame.new(-960, 8, 1600),
    DETECTIVE_NAMES          = {"Military Detective", "Detective"},
    CAPTAIN_NAMES            = {"Experienced Captain", "ExperiencedCaptain"},
}

Spirit.SEA3 = {
    BARTILO_LOCATIONS = {
        [2] = CFrame.new(-456.29, 73.02, 299.90),
        [3] = CFrame.new(-1836, 11, 1714),
    },
    SWAN_PIRATE_CF         = CFrame.new(-456.29, 73.02, 299.90),
    SWAN_FARM_CF           = CFrame.new(1057.93, 137.61, 1242.08),
    JEREMY_CF              = CFrame.new(2099.88, 448.93, 648.00),
    BARTILO_PLATE_ENTRY_CF = CFrame.new(-1836, 11, 1714),
    BARTILO_PLATES = {                   -- resolved at runtime against workspace.Map.Dressrosa.BartiloPlates
        CFrame.new(-1850.49, 13.18, 1750.90),
        CFrame.new(-1858.87, 19.38, 1712.02),
        CFrame.new(-1803.94, 16.58, 1750.90),
        CFrame.new(-1858.56, 16.86, 1724.80),
        CFrame.new(-1869.54, 15.99, 1681.01),
        CFrame.new(-1800.10, 16.50, 1684.52),
        CFrame.new(-1819.26, 14.80, 1717.91),
        CFrame.new(-1813.52, 14.86, 1724.80),
    },
    RIPPLE_ENTRY_CF        = CFrame.new(2288.80, 15.19, 863.03),
    FLAMINGO_PUZZLE_CF     = CFrame.new(-1836, 11, 1714),
    ZOU_PLACE_IDS = {
        [100117331123089] = true,
        [7449423635]      = true,
    },
}

Spirit.DOUGH_KING = {
    eliteMobs      = {"Diablo", "Deandre", "Urban"},
    eliteKillsPer  = 30,
    cocoaTarget    = 10,
    cocoaMobs      = {"Chocolate Bar Battler", "Cocoa Warrior"},
    cocoaFarmCF    = CFrame.new(402, 81, -12259),
    cakeMobs       = {"Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker"},
    cakeAreaCF     = CFrame.new(-2077, 252, -12373),
    cakeSpawnCF    = CFrame.new(-2124, 69, -12401),
    doughKingCF    = CFrame.new(-1943.67, 251.50, -12337.88),
    tradeNPC       = "SweetChaliceNpc",
    spawnerRemote  = "CakePrinceSpawner",
}

Spirit.MATERIAL_SOURCES = {
    ["Angel Wings"]          = {sea=1, mobs={"Shanda","Royal Squad","Royal Soldier"},              cf=CFrame.new(-4698, 845, -1912)},
    ["Leather"]              = {sea=1, mobs={"Brute","Pirate"},                                   cf=CFrame.new(-1145, 15, 4350)},
    ["Scrap Metal"]          = {sea=1, mobs={"Brute","Pirate"},                                   cf=CFrame.new(-1145, 15, 4350)},
    ["Magma Ore"]            = {sea=2, mobs={"Magma Ninja","Lava Pirate"},                        cf=CFrame.new(-5428, 78, -5959)},
    ["Fish Tail"]            = {sea=3, mobs={"Fishman Raider","Fishman Captain"},                 cf=CFrame.new(-10993, 332, -8940)},
    ["Ectoplasm"]            = {sea=2, mobs={"Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer"}, cf=CFrame.new(911, 125, 33159)},
    ["Mystic Droplet"]       = {sea=2, mobs={"Sea Soldier","Water Fighter"},                      cf=CFrame.new(-3385, 239, -10542)},
    ["Radioactive Material"] = {sea=2, mobs={"Factory Staff"},                                    cf=CFrame.new(295, 73, -56)},
    ["Vampire Fang"]         = {sea=2, mobs={"Vampire"},                                          cf=CFrame.new(-6033, 7, -1317)},
    ["Conjured Cocoa"]       = {sea=3, mobs={"Chocolate Bar Battler","Cocoa Warrior"},            cf=CFrame.new(620, 78, -12581)},
    ["Dragon Scale"]         = {sea=3, mobs={"Dragon Crew Archer","Dragon Crew Warrior"},         cf=CFrame.new(6594, 383, 139)},
    ["Gunpowder"]            = {sea=3, mobs={"Pistol Billionaire"},                               cf=CFrame.new(-84, 85, 6132)},
    ["Mini Tusk"]            = {sea=3, mobs={"Mythological Pirate"},                              cf=CFrame.new(-13545, 470, -6917)},
    ["Demonic Wisp"]         = {sea=3, mobs={"Demonic Soul"},                                     cf=CFrame.new(-9495, 453, 5977)},
    ["Bones"]                = {sea=3, mobs={"Reborn Skeleton","Living Zombie","Demonic Soul","Posessed Mummy"}, cf=CFrame.new(-9495, 453, 5977)},
}

Spirit.__data_ready = true
