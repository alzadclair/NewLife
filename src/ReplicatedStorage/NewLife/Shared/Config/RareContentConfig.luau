--!strict
local Config = {}

Config.Version = 'phase12-v1'
Config.WorldStateStoreName = 'NewLife_RareWorldState_v1'
Config.AnnouncementPredestined = 'a Predestined was born.'
Config.Locales = {'pt-BR','en-US','es','ja','zh','ru'}

Config.MonthlyOpportunityTypes = {'ExtinctClassBook','LegendarySkillBook','LegendaryMagicBook'}
Config.MonthlyChance = {ExtinctClassBook=0.22, LegendarySkillBook=0.18, LegendaryMagicBook=0.16}

Config.ExtinctClasses = {
    ExtinctClass_01 = {ClassId='ExtinctClass_01',DisplayNameKey='class.extinct.01',Rarity='Extinct',ActiveSkill='ExtinctSkill_01',PassiveSkill='ExtinctPassive_01',CombatIdentity='Vanguard',Progression={MasteryPerUse=14},Unlock={Source='ExtinctClassBook',Permanent=true}},
    ExtinctClass_02 = {ClassId='ExtinctClass_02',DisplayNameKey='class.extinct.02',Rarity='Extinct',ActiveSkill='ExtinctSkill_02',PassiveSkill='ExtinctPassive_02',CombatIdentity='ArcaneBurst',Progression={MasteryPerUse=15},Unlock={Source='ExtinctClassBook',Permanent=true}},
    ExtinctClass_03 = {ClassId='ExtinctClass_03',DisplayNameKey='class.extinct.03',Rarity='Extinct',ActiveSkill='ExtinctSkill_03',PassiveSkill='ExtinctPassive_03',CombatIdentity='Skirmisher',Progression={MasteryPerUse=16},Unlock={Source='ExtinctClassBook',Permanent=true}},
    ExtinctClass_04 = {ClassId='ExtinctClass_04',DisplayNameKey='class.extinct.04',Rarity='Extinct',ActiveSkill='ExtinctSkill_04',PassiveSkill='ExtinctPassive_04',CombatIdentity='Bulwark',Progression={MasteryPerUse=14},Unlock={Source='ExtinctClassBook',Permanent=true}},
    ExtinctClass_05 = {ClassId='ExtinctClass_05',DisplayNameKey='class.extinct.05',Rarity='Extinct',ActiveSkill='ExtinctSkill_05',PassiveSkill='ExtinctPassive_05',CombatIdentity='SustainCaster',Progression={MasteryPerUse=15},Unlock={Source='ExtinctClassBook',Permanent=true}},
}
Config.ExtinctClassOrder = {'ExtinctClass_01','ExtinctClass_02','ExtinctClass_03','ExtinctClass_04','ExtinctClass_05'}

Config.LegendarySkill = {Id='LegendarySkill_01',DisplayNameKey='skill.legendary.01',Rarity='Legendary',Source='LegendarySkillBook'}
Config.LegendaryMagic = {Id='LegendaryMagic_01',DisplayNameKey='magic.legendary.01',Rarity='Legendary',Source='LegendaryMagicBook'}

Config.RelicCategories = {'Weapon','Armor','Helm','Gloves','Boots','Amulet','Ring','Focus','Cloak'}
Config.RelicLineages = {'Void','FallenKing','CrimsonMoon','EternalStorm','FirstHero'}
Config.UniquenessPolicies = {'Normal','Rare','ServerLimited','WorldUnique'}
Config.Relics = {}
local categoryBonus = {
    Weapon={Strength=2}, Armor={Defense=2}, Helm={MaxHealth=8}, Gloves={Strength=1,Power=1}, Boots={MaxStamina=8},
    Amulet={MaxMana=8}, Ring={Power=2}, Focus={MaxMana=6,Power=1}, Cloak={Defense=1,MaxHealth=5},
}
for ci, category in ipairs(Config.RelicCategories) do
    for li, lineage in ipairs(Config.RelicLineages) do
        local id=string.format('Relic_%s_%s',category,lineage)
        local policy=((ci+li)%11==0 and 'WorldUnique') or ((ci+li)%7==0 and 'ServerLimited') or ((ci+li)%3==0 and 'Rare') or 'Normal'
        Config.Relics[id]={RelicId=id,Category=category,Lineage=lineage,Rarity=(policy=='Normal' and 'Epic' or 'Legendary'),Stats=categoryBonus[category],Passive={Id='RelicPassive_'..lineage,Scale=1},Active=nil,EquipRules={Slot=category,MaxPerCategory=1},LevelRequirement=math.max(1,(ci-1)*5),RankRequirement='',ProvenanceRequired=true,SetId='Set_'..lineage,DisplayNameKey='relic.'..string.lower(category)..'.'..string.lower(lineage),DescriptionKey='relic.desc.'..string.lower(lineage),UniquenessPolicy=policy}
    end
end
Config.SetSynergy = {}
for _, lineage in ipairs(Config.RelicLineages) do
    Config.SetSynergy[lineage]={
        TwoPiece={Required=2,Stats={Power=2},Passive='Set2_'..lineage},
        ThreePiece={Required=3,Stats={MaxHealth=10,MaxMana=10},Passive='Set3_'..lineage},
    }
end

Config.OpenWorldHook = {Id='LostArchiveCache',DisplayNameKey='world.rare.lost_archive',Position=Vector3.new(220,4,40),InteractDistance=14,RegionHint='MossfallRuins'}
Config.AcquisitionSources = {Dungeon='DungeonMonthlyOpportunity',OpenWorld='LostArchiveCache'}

function Config.GetRelicCount()
    local n=0 for _ in pairs(Config.Relics) do n+=1 end return n
end
return Config