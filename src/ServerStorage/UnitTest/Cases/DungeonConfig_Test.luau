--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Config = require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)

local T = {Name = 'DungeonConfig_Phase10'}

function T.Run()
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end

    -- T10_001: Exactly 33 ranks
    check('T10_001_RankCount33', #Config.Ranks == 33)

    -- T10_002: First=F, Last=5-V
    check('T10_002_BoundsFto5V', Config.Ranks[1] == 'F' and Config.Ranks[#Config.Ranks] == '5-V')

    -- T10_003: Exact rank order F..5-V
    local expected = {
        'F','E','C','B','A','S','SS','SSS',
        '1-I','1-II','1-III','1-IV','1-V',
        '2-I','2-II','2-III','2-IV','2-V',
        '3-I','3-II','3-III','3-IV','3-V',
        '4-I','4-II','4-III','4-IV','4-V',
        '5-I','5-II','5-III','5-IV','5-V',
    }
    local orderOk = true
    for i, r in ipairs(expected) do
        if Config.Ranks[i] ~= r then orderOk = false; break end
    end
    check('T10_003_ExactRankOrder', orderOk)

    -- T10_004: GetRankIndex correctness
    check('T10_004_GetRankIndex', Config.GetRankIndex('F') == 1 and Config.GetRankIndex('5-V') == 33 and Config.GetRankIndex('S') == 6)

    -- T10_005: GetRank by index
    check('T10_005_GetRankByIndex', Config.GetRank(1) == 'F' and Config.GetRank(33) == '5-V' and Config.GetRank(6) == 'S')

    -- T10_006: Tier scaling: F tier < 5-V tier for all numeric fields
    local tierF = Config.GetTier(1)
    local tier5V = Config.GetTier(33)
    check('T10_006_TierScaling',
        tier5V.EnemyHealth > tierF.EnemyHealth and
        tier5V.EnemyDamage > tierF.EnemyDamage and
        tier5V.EnemyDefense > tierF.EnemyDefense and
        tier5V.EliteChance > tierF.EliteChance and
        tier5V.HazardBudget >= tierF.HazardBudget and
        tier5V.ModifierCount >= tierF.ModifierCount and
        tier5V.RoomMax >= tierF.RoomMax and
        tier5V.RewardQuality > tierF.RewardQuality and
        tier5V.BossComplexity > tierF.BossComplexity
    )

    -- T10_007: RoomTypes contains Entrance and Boss
    check('T10_007_RoomTypesEntranceBoss', table.find(Config.RoomTypes, 'Entrance') ~= nil and table.find(Config.RoomTypes, 'Boss') ~= nil)

    -- T10_008: RequiredPath is Entrance->Boss
    check('T10_008_RequiredPath', Config.RequiredPath[1] == 'Entrance' and Config.RequiredPath[2] == 'Boss' and #Config.RequiredPath == 2)

    -- T10_009: Lifecycle has all 7 states
    check('T10_009_LifecycleStates',
        #Config.Lifecycle == 7 and
        Config.Lifecycle[1] == 'Generating' and
        table.find(Config.Lifecycle, 'Ready') ~= nil and
        table.find(Config.Lifecycle, 'Active') ~= nil and
        table.find(Config.Lifecycle, 'BossAvailable') ~= nil and
        table.find(Config.Lifecycle, 'Completed') ~= nil and
        table.find(Config.Lifecycle, 'Failed') ~= nil and
        table.find(Config.Lifecycle, 'Closing') ~= nil
    )

    -- T10_010: Windless modifier has DisableGuidingWind
    check('T10_010_WindlessModifier', Config.Modifiers.Windless ~= nil and Config.Modifiers.Windless.DisableGuidingWind == true)

    -- T10_011: EnemyPools has Low/Mid/High/Apex
    check('T10_011_EnemyPools', Config.EnemyPools.Low ~= nil and Config.EnemyPools.Mid ~= nil and Config.EnemyPools.High ~= nil and Config.EnemyPools.Apex ~= nil)

    -- T10_012: Bosses defined
    check('T10_012_BossDefs', Config.Bosses.DungeonWarden ~= nil and Config.Bosses.RiftCustodian ~= nil)

    -- T10_013: WorldEventRank is 5-V
    check('T10_013_WorldEventRank', Config.WorldEventRank == '5-V')

    -- T10_014: FiveVBaseChance < 0.01 (protected)
    check('T10_014_FiveVProtected', Config.FiveVBaseChance < 0.01 and Config.FiveVBaseChance > 0)

    -- T10_015: Reroll config
    check('T10_015_RerollConfig', Config.Reroll.Down > 0 and Config.Reroll.Same > 0 and Config.Reroll.Up > 0 and Config.Reroll.MaxStep >= 1)

    -- T10_016: All modifiers have Description
    local allDesc = true
    for id, mod in pairs(Config.Modifiers) do
        if type(mod.Description) ~= 'string' then allDesc = false; break end
    end
    check('T10_016_ModifierDescriptions', allDesc)

    -- T10_017: ModifierCount clamped 1-4
    local tier1 = Config.GetTier(1)
    local tier33 = Config.GetTier(33)
    check('T10_017_ModifierCountClamped', tier1.ModifierCount >= 1 and tier33.ModifierCount <= 4)

    -- T10_018: MinRank/MaxRank constants
    check('T10_018_MinMaxRank', Config.MinRank == 'F' and Config.MaxRank == '5-V')

    -- T10_019: MaxHistory = 30
    check('T10_019_MaxHistory30', Config.MaxHistory == 30)

    return pass, fail, errs
end

return T