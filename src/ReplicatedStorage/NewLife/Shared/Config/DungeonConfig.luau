--!strict
local Config = {}

Config.Ranks = {
    'F','E','C','B','A','S','SS','SSS',
    '1-I','1-II','1-III','1-IV','1-V',
    '2-I','2-II','2-III','2-IV','2-V',
    '3-I','3-II','3-III','3-IV','3-V',
    '4-I','4-II','4-III','4-IV','4-V',
    '5-I','5-II','5-III','5-IV','5-V',
}
Config.MinRank = 'F'
Config.MaxRank = '5-V'
Config.MaxHistory = 30
Config.WorldEventRank = '5-V'
Config.FiveVBaseChance = 0.002
Config.Reroll = {Down=0.24, Same=0.46, Up=0.30, MaxStep=2}
Config.RoomTypes = {'Entrance','Combat','Elite','Event','Treasure','Rest','Boss'}
Config.Lifecycle = {'Generating','Ready','Active','BossAvailable','Completed','Failed','Closing'}
Config.RequiredPath = {'Entrance','Boss'}
Config.Modifiers = {
    EmpoweredEnemies={EnemyHealth=1.15,EnemyDamage=1.12,Description='Enemies gain controlled combat bonuses.'},
    LowVisibility={LowVisibility=true,Description='Reduced dungeon visibility.'},
    EliteSurge={EliteBonus=0.20,Description='Higher elite encounter pressure.'},
    StaminaPressure={StaminaPressure=0.18,Description='Combat periodically pressures stamina.'},
    ArcaneInstability={Hazard='ArcanePulse',Description='Arcane pulses become a room hazard.'},
    TreasureHunt={TreasureBonus=0.35,Description='More treasure opportunities.'},
    Windless={DisableGuidingWind=true,Description='Guiding Wind is disabled in this manifestation.'},
}
Config.EnemyPools = {
    Low={'TrainingSlime'},
    Mid={'TrainingSlime','StoneBrute'},
    High={'StoneBrute','TrainingSlime'},
    Apex={'StoneBrute'},
}
Config.Bosses = {
    DungeonWarden={Id='DungeonWarden',DisplayName='Dungeon Warden',Phases=3,Abilities={'Basic','EchoBurst','SovereignRush'},RewardTable='DynamicDungeon'},
    RiftCustodian={Id='RiftCustodian',DisplayName='Rift Custodian',Phases=3,Abilities={'Basic','SovereignRush'},RewardTable='DynamicDungeon'},
}

function Config.GetRankIndex(rank: string): number?
    return table.find(Config.Ranks, rank)
end

function Config.GetRank(rankOrIndex: any): string
    if type(rankOrIndex)=='number' then return Config.Ranks[math.clamp(math.floor(rankOrIndex),1,#Config.Ranks)] end
    return Config.Ranks[Config.GetRankIndex(tostring(rankOrIndex)) or 1]
end

function Config.GetTier(index: number)
    index=math.clamp(math.floor(index),1,#Config.Ranks)
    local t=(index-1)/(#Config.Ranks-1)
    return {
        EnemyHealth=1+1.8*t,
        EnemyDamage=1+1.35*t,
        EnemyDefense=1+0.9*t,
        EliteChance=0.08+0.34*t,
        HazardBudget=math.floor(t*4),
        ModifierCount=math.clamp(1+math.floor(t*3),1,4),
        RoomMin=4+math.floor(t*2),
        RoomMax=6+math.floor(t*5),
        RewardQuality=1+2.5*t,
        BossComplexity=1+math.floor(t*4),
    }
end

return Config