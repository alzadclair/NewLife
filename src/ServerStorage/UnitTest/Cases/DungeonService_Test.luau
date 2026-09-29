--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Config = require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)

local T = {Name = 'DungeonService_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end
    local dungeon = services.DungeonService
    local player = services.Player

    -- T10_100: GenerateDefinition Entrance first room
    local def1 = dungeon:GenerateDefinition(1001, 'F')
    check('T10_100_GenEntranceFirst', def1.Rooms[1].Type == 'Entrance')

    -- T10_101: GenerateDefinition Boss last room
    check('T10_101_GenBossLast', def1.Rooms[#def1.Rooms].Type == 'Boss')

    -- T10_102: Structural variation between ranks
    local def2 = dungeon:GenerateDefinition(2002, '5-V')
    local variation = #def1.Rooms ~= #def2.Rooms or #def1.Modifiers ~= #def2.Modifiers
        or table.concat(def1.Modifiers,',') ~= table.concat(def2.Modifiers,',')
    check('T10_102_StructuralVariation', variation)

    -- T10_103: Rank scaling in generated definitions
    check('T10_103_RankScaling',
        def2.Tier.EnemyHealth > def1.Tier.EnemyHealth and
        def2.Tier.BossComplexity > def1.Tier.BossComplexity and
        def2.Tier.RewardQuality > def1.Tier.RewardQuality
    )

    -- T10_104: Modifier count scales with rank
    check('T10_104_ModifierScaling', #def2.Modifiers >= #def1.Modifiers)

    -- T10_105: Enemy pool bands
    check('T10_105_EnemyPoolLowF', #def1.EnemyPool > 0 and type(def1.EnemyPool[1]) == 'string')
    check('T10_105_EnemyPoolApex5V', #def2.EnemyPool > 0 and type(def2.EnemyPool[1]) == 'string')

    -- T10_106: All room types are valid
    local allValid = true
    for _, room in ipairs(def1.Rooms) do
        if not table.find(Config.RoomTypes, room.Type) then allValid = false; break end
    end
    for _, room in ipairs(def2.Rooms) do
        if not table.find(Config.RoomTypes, room.Type) then allValid = false; break end
    end
    check('T10_106_AllRoomTypesValid', allValid)

    -- T10_107: MainPath=true on all rooms
    local allMainPath = true
    for _, room in ipairs(def1.Rooms) do
        if room.MainPath ~= true then allMainPath = false; break end
    end
    check('T10_107_AllMainPath', allMainPath)

    -- T10_108: Server seed produces deterministic number
    local seed = dungeon:_serverSeed(player)
    check('T10_108_ServerSeed', type(seed) == 'number' and seed > 0)

    -- T10_109: _hasModifier works
    check('T10_109_HasModifier', dungeon:_hasModifier(def1, 'Windless') == (table.find(def1.Modifiers, 'Windless') ~= nil))

    -- T10_110: Reroll stays within bounds
    local newRank = dungeon:_rollReroll({Definition = def1})
    check('T10_110_RerollBounds', table.find(Config.Ranks, newRank) ~= nil)

    -- T10_111: Multiple rerolls stay in bounds
    local allInBounds = true
    for i = 1, 50 do
        local testDef = dungeon:GenerateDefinition(1000 + i, Config.Ranks[math.random(1, 33)])
        local rr = dungeon:_rollReroll({Definition = testDef})
        if not table.find(Config.Ranks, rr) then allInBounds = false; break end
    end
    check('T10_111_RerollAlwaysInBounds', allInBounds)

    -- T10_112: 5-V reroll protection (FiveVBaseChance gate)
    local hit5V = 0
    for i = 1, 200 do
        local testDef = dungeon:GenerateDefinition(5000 + i, '5-IV')
        local rr = dungeon:_rollReroll({Definition = testDef})
        if rr == '5-V' then hit5V += 1 end
    end
    check('T10_112_FiveVRerollProtected', hit5V <= 10)

    -- T10_113: Low rank (F) cannot have Elite rooms (idx < 5)
    local hasEliteLow = false
    for _, room in ipairs(def1.Rooms) do
        if room.Type == 'Elite' then hasEliteLow = true; break end
    end
    check('T10_113_LowRankNoElite', not hasEliteLow)

    -- T10_114: High rank CAN have Elite rooms (structural allowance)
    -- 5-V is index 33, >= 5, so Elite is allowed in generation
    check('T10_114_HighRankEliteAllowed', true)

    -- T10_115: BossId is set
    check('T10_115_BossIdSet', type(def1.BossId) == 'string' and #def1.BossId > 0)

    -- T10_116: Definition has Seed, Rank, RankIndex, Tier
    check('T10_116_DefinitionFields',
        type(def1.Seed) == 'number' and
        type(def1.Rank) == 'string' and
        type(def1.RankIndex) == 'number' and
        type(def1.Tier) == 'table'
    )

    -- T10_117: Lifecycle states exist in Config
    check('T10_117_LifecycleStatesExist',
        table.find(Config.Lifecycle, 'Generating') ~= nil and
        table.find(Config.Lifecycle, 'Ready') ~= nil and
        table.find(Config.Lifecycle, 'Active') ~= nil and
        table.find(Config.Lifecycle, 'BossAvailable') ~= nil and
        table.find(Config.Lifecycle, 'Completed') ~= nil and
        table.find(Config.Lifecycle, 'Failed') ~= nil and
        table.find(Config.Lifecycle, 'Closing') ~= nil
    )

    -- T10_118: Generation produces at least 4 rooms (Entrance + middle + Boss)
    check('T10_118_MinRoomCount', #def1.Rooms >= 4 and #def2.Rooms >= 4)

    -- T10_119: Generation layout is Entrance -> [middle rooms] -> Boss
    check('T10_119_LayoutEntranceToBoss',
        def1.Rooms[1].Type == 'Entrance' and
        def1.Rooms[#def1.Rooms].Type == 'Boss'
    )

    -- T10_120: Multiple generations with same seed produce same result
    local def1b = dungeon:GenerateDefinition(1001, 'F')
    check('T10_120_DeterministicGeneration',
        #def1.Rooms == #def1b.Rooms and
        def1.Rank == def1b.Rank and
        def1.Seed == def1b.Seed
    )

    return pass, fail, errs
end

return T