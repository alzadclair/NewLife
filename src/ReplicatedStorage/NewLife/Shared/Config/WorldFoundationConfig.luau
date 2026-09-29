--!strict
local W = {
    Version = '1.2.0-open-world-foundation',
    VerticalSlice = 'VerdantReign',
    KingdomAnchors = {
        VerdantReign = {Center=Vector3.new(0,0,0), Radius=520, Route='VerdantRoad', Landmark='WorldTree'},
        IronHold = {Center=Vector3.new(980,0,120), Radius=360, Route='IronPass', Landmark='IronCitadel'},
        Sunspire = {Center=Vector3.new(-900,0,500), Radius=360, Route='Sunroad', Landmark='SunspireObelisk'},
        ShadowKeep = {Center=Vector3.new(-850,0,-650), Radius=360, Route='UmbralTrail', Landmark='ShadowTower'},
        FrostPeak = {Center=Vector3.new(720,0,-850), Radius=380, Route='FrostRoad', Landmark='FrostPeak'},
    },
    ForbiddenNation = {
        Direction='North-East', ApproximateCenter=Vector3.new(1500,0,-1450), FutureBorderRadius=500,
        Landmark='VeiledMonolith', HighRisk=true, Future=true,
    },
    Biomes = {
        Grasslands={Material='Grass', Vegetation='Light', Ambience='ambience.grasslands', Lighting='WarmClear', EnemyPool={'TrainingSlime'}, WeatherHook='Temperate'},
        Forest={Material='Grass', Vegetation='Dense', Ambience='ambience.forest', Lighting='ForestCanopy', EnemyPool={'TrainingSlime','StoneBrute'}, WeatherHook='Temperate'},
        RiverLake={Material='Water', Vegetation='Shoreline', Ambience='ambience.water', Lighting='CoolReflective', EnemyPool={}, WeatherHook='WaterMist'},
        RockyHighlands={Material='Rock', Vegetation='Sparse', Ambience='ambience.highlands', Lighting='Highland', EnemyPool={'StoneBrute'}, WeatherHook='HighWind'},
        Snow={Future=true}, Desert={Future=true}, Swamp={Future=true}, Corrupted={Future=true}, Volcanic={Future=true}, Mystical={Future=true},
    },
    Regions = {
        Oakhaven={DisplayName='Oakhaven Village',Center=Vector3.new(0,6,0),Radius=92,SafeZone=true,Kingdom='VerdantReign',Biome='Grasslands',LocalizationKey='world.region.oakhaven'},
        Greenmeadow={DisplayName='Greenmeadow Fields',Center=Vector3.new(115,5,25),Radius=105,SafeZone=false,Kingdom='VerdantReign',Biome='Grasslands',Risk='Low',LocalizationKey='world.region.greenmeadow'},
        WhisperingWoods={DisplayName='Whispering Woods',Center=Vector3.new(250,8,-20),Radius=130,SafeZone=false,Kingdom='VerdantReign',Biome='Forest',Risk='Moderate',LocalizationKey='world.region.whisperingWoods'},
        Silverrun={DisplayName='Silverrun River',Center=Vector3.new(115,2,-115),Radius=90,SafeZone=false,Kingdom='VerdantReign',Biome='RiverLake',LocalizationKey='world.region.silverrun'},
        ElderRise={DisplayName='Elder Rise',Center=Vector3.new(355,24,-135),Radius=105,SafeZone=false,Kingdom='VerdantReign',Biome='RockyHighlands',Risk='Elite',LocalizationKey='world.region.elderRise'},
        MossfallRuins={DisplayName='Mossfall Ruins',Center=Vector3.new(305,12,105),Radius=75,SafeZone=false,Kingdom='VerdantReign',Biome='Forest',Risk='Moderate',LocalizationKey='world.region.mossfallRuins'},
    },
    EnemyZones = {
        LowRisk={Region='Greenmeadow',Center=Vector3.new(155,8,40),Radius=42,EnemyId='TrainingSlime',Count=3},
        Moderate={Region='WhisperingWoods',Center=Vector3.new(265,10,-5),Radius=52,EnemyId='TrainingSlime',Count=4},
        Elite={Region='ElderRise',Center=Vector3.new(350,30,-135),Radius=40,EnemyId='StoneBrute',Count=2},
    },
    DungeonEntrance = {Position=Vector3.new(315,13,112), Facing=Vector3.new(0,0,-1), Region='MossfallRuins', LocalizationKey='world.poi.trialCellar'},
    NPCPositions = {
        GuardKael=Vector3.new(34,7,-6), MerchantBoran=Vector3.new(-18,7,18), ElderRowan=Vector3.new(0,7,-24),
    },
    Landmarks = {
        WorldTree={Position=Vector3.new(70,8,-55),VisibleDistance=700,LocalizationKey='world.landmark.worldTree'},
        Watchtower={Position=Vector3.new(-55,8,28),VisibleDistance=450,LocalizationKey='world.landmark.watchtower'},
        MossfallArch={Position=Vector3.new(305,12,100),VisibleDistance=350,LocalizationKey='world.landmark.mossfallArch'},
        ElderRise={Position=Vector3.new(355,28,-135),VisibleDistance=600,LocalizationKey='world.landmark.elderRise'},
    },
    AmbienceHooks={'Forest','Wind','Water','Settlement','DungeonEntrance'},
    VFXHooks={'GuidingWind','Leaves','Dust','WaterMist','DungeonEntrance','RegionTransition'},
    LocalizationLocales={'pt-BR','en-US','es','ja','zh','ru'},
    Performance={StreamingEnabled=true, StreamingMinRadius=128, StreamingTargetRadius=384, VegetationBudget=260, FoundationPartBudget=900, CollisionSimplified=true},
}

for _, sectionName in ipairs({'KingdomAnchors','Biomes','Regions','EnemyZones','NPCPositions','Landmarks','Performance','ForbiddenNation','DungeonEntrance','AmbienceHooks','VFXHooks','LocalizationLocales'}) do
    local section = (W :: any)[sectionName]
    if type(section) == 'table' then table.freeze(section) end
end
table.freeze(W)
return W
