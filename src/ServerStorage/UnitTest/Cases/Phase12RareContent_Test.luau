-- Phase 12 rare-content contract tests. T-1200+ only.
return function(t)
    local RS=game:GetService('ReplicatedStorage')
    local SS=game:GetService('ServerScriptService')
    local Config=require(RS.NewLife.Shared.Config.RareContentConfig)
    local Content=require(RS.NewLife.Shared.Config.ContentDefinitions)
    local Rare=require(SS.NewLifeServer.Services.RareContentService)
    local expect=t.expect

    local function profile()
        return {
            Birth={FateSeed='FATE-KEEP',BirthDate=123,Traits={'Sturdy'},Summary='keep'},
            Identity={Race='Human',Class='Warrior',FateSeed='FATE-KEEP'},
            Progression={Level=87,XP=999,Gold=777,HasMagic=true},
            Build={Unlocked={OldSkill=true},Mastery={OldSkill=55},SkillSlots={},MagicSlots={},RaceProgress={Human={Mastery=99,Level=2}},ClassProgress={Warrior={Mastery=77,Level=2}}},
            Titles={'PermanentTitle'},Legacy={Score=12,Choices={'A'}},PlayerChronicle={{Text='Old Chronicle'}},
            RareContent={ExtinctClassId='',LegendarySkills={},LegendaryMagic={},RareItems={},EquippedRelics={},RareHistory={}},
        }
    end

    t.test('T-1200 exactly five extinct classes',function() local n=0 for _ in pairs(Config.ExtinctClasses) do n+=1 end expect.equal(n,5) end)
    t.test('T-1201 extinct class order has five unique ids',function() local seen={} for _,id in ipairs(Config.ExtinctClassOrder) do expect.falsy(seen[id]);seen[id]=true end expect.equal(#Config.ExtinctClassOrder,5) end)
    t.test('T-1202 all extinct class ids exist in content',function() for id in pairs(Config.ExtinctClasses) do expect.truthy(Content.Classes[id]) end end)
    t.test('T-1203 extinct classes expose replaceable localization keys',function() for _,d in pairs(Config.ExtinctClasses) do expect.truthy(type(d.DisplayNameKey)=='string' and d.DisplayNameKey~='') end end)
    t.test('T-1204 extinct classes have distinct combat identities',function() local s={} for _,d in pairs(Config.ExtinctClasses) do s[d.CombatIdentity]=true end local n=0 for _ in pairs(s) do n+=1 end expect.equal(n,5) end)
    t.test('T-1205 each extinct class has active and passive skill',function() for _,d in pairs(Config.ExtinctClasses) do expect.truthy(Content.Skills[d.ActiveSkill]);expect.truthy(Content.Skills[d.PassiveSkill]);expect.truthy(Content.Skills[d.ActiveSkill].Active);expect.falsy(Content.Skills[d.PassiveSkill].Active) end end)
    t.test('T-1206 extinct reset sets selected class',function() local p=profile(); local ok=Rare.ApplyExtinctReset(p,'ExtinctClass_01');expect.truthy(ok);expect.equal(p.Identity.Class,'ExtinctClass_01');expect.equal(p.RareContent.ExtinctClassId,'ExtinctClass_01') end)
    t.test('T-1207 extinct reset returns level to one',function() local p=profile(); Rare.ApplyExtinctReset(p,'ExtinctClass_02');expect.equal(p.Progression.Level,1);expect.equal(p.Progression.XP,0) end)
    t.test('T-1208 extinct reset is one per character',function() local p=profile();expect.truthy(Rare.ApplyExtinctReset(p,'ExtinctClass_03'));local ok,reason=Rare.ApplyExtinctReset(p,'ExtinctClass_04');expect.falsy(ok);expect.equal(reason,'AlreadyExtinct') end)
    t.test('T-1209 fate seed survives reset',function() local p=profile();Rare.ApplyExtinctReset(p,'ExtinctClass_01');expect.equal(p.Birth.FateSeed,'FATE-KEEP');expect.equal(p.Identity.FateSeed,'FATE-KEEP') end)
    t.test('T-1210 birth identity survives reset',function() local p=profile();Rare.ApplyExtinctReset(p,'ExtinctClass_01');expect.equal(p.Birth.BirthDate,123);expect.equal(p.Birth.Summary,'keep') end)
    t.test('T-1211 titles and legacy survive reset',function() local p=profile();Rare.ApplyExtinctReset(p,'ExtinctClass_01');expect.equal(p.Titles[1],'PermanentTitle');expect.equal(p.Legacy.Score,12) end)
    t.test('T-1212 chronicle survives reset',function() local p=profile();Rare.ApplyExtinctReset(p,'ExtinctClass_01');expect.equal(p.PlayerChronicle[1].Text,'Old Chronicle') end)
    t.test('T-1213 race progress survives reset',function() local p=profile();Rare.ApplyExtinctReset(p,'ExtinctClass_01');expect.equal(p.Build.RaceProgress.Human.Mastery,99) end)
    t.test('T-1214 new extinct class mastery starts clean',function() local p=profile();Rare.ApplyExtinctReset(p,'ExtinctClass_05');expect.equal(p.Build.ClassProgress.ExtinctClass_05.Mastery,0);expect.equal(p.Build.ClassProgress.ExtinctClass_05.Level,1) end)
    t.test('T-1215 monthly decision deterministic across restart',function() local a=Rare.BuildMonthlyDecision('2026-09','server-a','ExtinctClassBook',0.5);local b=Rare.BuildMonthlyDecision('2026-09','server-a','ExtinctClassBook',0.5);expect.equal(a.Available,b.Available);expect.equal(a.OpportunityId,b.OpportunityId) end)
    t.test('T-1216 zero-opportunity month is representable',function() local d=Rare.BuildMonthlyDecision('2026-10','server-zero','ExtinctClassBook',0);expect.falsy(d.Available);expect.truthy(d.DecisionMade) end)
    t.test('T-1217 certain opportunity remains one record',function() local d=Rare.BuildMonthlyDecision('2026-10','server-one','LegendarySkillBook',1);expect.truthy(d.Available);expect.falsy(d.Claimed);expect.truthy(type(d.OpportunityId)=='string') end)
    t.test('T-1218 three monthly rare types configured',function() expect.equal(#Config.MonthlyOpportunityTypes,3) end)
    t.test('T-1219 legendary skill is functional content',function() local d=Content.Skills[Config.LegendarySkill.Id];expect.truthy(d);expect.truthy(d.Active);expect.equal(d.Resource,'Stamina');expect.truthy(d.Cooldown>0);expect.truthy(d.Damage>0) end)
    t.test('T-1220 legendary magic is functional content',function() local d=Content.Magic[Config.LegendaryMagic.Id];expect.truthy(d);expect.equal(d.Resource,'Mana');expect.truthy(d.Cooldown>0);expect.truthy(d.Cost>0);expect.truthy(d.Damage>0) end)
    t.test('T-1221 nine relic categories configured',function() expect.equal(#Config.RelicCategories,9) end)
    t.test('T-1222 five canonical relic lineages configured',function() expect.equal(#Config.RelicLineages,5);expect.equal(Config.RelicLineages[1],'Void');expect.equal(Config.RelicLineages[5],'FirstHero') end)
    t.test('T-1223 exactly forty-five relic configs exist',function() expect.equal(Config.GetRelicCount(),45) end)
    t.test('T-1224 every category-lineage pair exists',function() for _,c in ipairs(Config.RelicCategories) do for _,l in ipairs(Config.RelicLineages) do expect.truthy(Config.Relics['Relic_'..c..'_'..l]) end end end)
    t.test('T-1225 relic configs contain provenance and localization metadata',function() for _,d in pairs(Config.Relics) do expect.truthy(d.ProvenanceRequired);expect.truthy(type(d.DisplayNameKey)=='string');expect.truthy(type(d.UniquenessPolicy)=='string') end end)
    t.test('T-1226 uniqueness policies are valid',function() local v={} for _,p in ipairs(Config.UniquenessPolicies) do v[p]=true end for _,d in pairs(Config.Relics) do expect.truthy(v[d.UniquenessPolicy]) end end)
    t.test('T-1227 two-piece synergy applies stats',function() local p=profile();p.RareContent.EquippedRelics.Weapon='Relic_Weapon_Void';p.RareContent.EquippedRelics.Armor='Relic_Armor_Void';local a={Strength=0,Defense=0,Power=0,MaxHealth=100,MaxMana=100,MaxStamina=100};Rare.ApplyRelicStats(p,a);expect.truthy(a.Power>=2) end)
    t.test('T-1228 three-piece synergy applies stronger stats',function() local p=profile();p.RareContent.EquippedRelics.Weapon='Relic_Weapon_Void';p.RareContent.EquippedRelics.Armor='Relic_Armor_Void';p.RareContent.EquippedRelics.Helm='Relic_Helm_Void';local a={Strength=0,Defense=0,Power=0,MaxHealth=100,MaxMana=100,MaxStamina=100};Rare.ApplyRelicStats(p,a);expect.truthy(a.MaxHealth>=118);expect.truthy(a.MaxMana>=110) end)
    t.test('T-1229 mixed lineages do not trigger same-lineage set',function() local p=profile();p.RareContent.EquippedRelics.Weapon='Relic_Weapon_Void';p.RareContent.EquippedRelics.Armor='Relic_Armor_FirstHero';local a={Strength=0,Defense=0,Power=0,MaxHealth=100,MaxMana=100,MaxStamina=100};Rare.ApplyRelicStats(p,a);expect.equal(a.Power,0) end)
    t.test('T-1230 relic equip rules have one category slot',function() for _,d in pairs(Config.Relics) do expect.equal(d.EquipRules.Slot,d.Category);expect.equal(d.EquipRules.MaxPerCategory,1) end end)
    t.test('T-1231 config validation passes',function() expect.truthy(Rare.ValidateConfig()) end)
    t.test('T-1232 open-world hook is away from spawn',function() expect.truthy(Config.OpenWorldHook.Position.Magnitude>100);expect.equal(Config.OpenWorldHook.RegionHint,'MossfallRuins') end)
    t.test('T-1233 dungeon source is monthly-gated source',function() expect.equal(Config.AcquisitionSources.Dungeon,'DungeonMonthlyOpportunity') end)
    t.test('T-1234 predestined announcement meaning is exact',function() expect.equal(Config.AnnouncementPredestined,'a Predestined was born.') end)
    t.test('T-1235 six localization targets prepared',function() expect.equal(#Config.Locales,6);expect.equal(Config.Locales[1],'pt-BR');expect.equal(Config.Locales[2],'en-US') end)
    t.test('T-1236 invalid extinct class is rejected',function() local ok,reason=Rare.ApplyExtinctReset(profile(),'FakeExtinct');expect.falsy(ok);expect.equal(reason,'InvalidClass') end)
    t.test('T-1237 extinct unlock metadata is permanent',function() for _,d in pairs(Config.ExtinctClasses) do expect.truthy(d.Unlock.Permanent);expect.equal(d.Unlock.Source,'ExtinctClassBook') end end)
    t.test('T-1238 monthly opportunity uses server scope in id',function() local d=Rare.BuildMonthlyDecision('2026-11','scope-xyz','LegendaryMagicBook',1);expect.truthy(string.find(d.OpportunityId,'scope-xyz',1,true)~=nil) end)
    t.test('T-1239 relic config version is phase12',function() expect.equal(Config.Version,'phase12-v1') end)
    t.test('T-1240 open-world claim rejects distant intent',function()
        local foundation=workspace:FindFirstChild('NewLife') and workspace.NewLife:FindFirstChild('World') and workspace.NewLife.World:FindFirstChild('OpenWorldFoundation')
        local hook=foundation and foundation:FindFirstChild(Config.OpenWorldHook.Id)
        expect.truthy(hook and hook:IsA('BasePart'))
        local character=Instance.new('Model'); local root=Instance.new('Part'); root.Name='HumanoidRootPart'; root.Position=hook.Position+Vector3.new(Config.OpenWorldHook.InteractDistance+50,0,0); root.Parent=character; character.Parent=workspace
        local ok,reason=Rare:TryAcquireOpenWorld({Character=character})
        character:Destroy(); expect.falsy(ok); expect.equal(reason,'TooFar')
    end)
    t.test('T-1241 world-unique relic rejects a second unique item id',function()
        Rare._worldState.Uniqueness={}
        local relicId=nil for id,d in pairs(Config.Relics) do if d.UniquenessPolicy=='WorldUnique' then relicId=id break end end
        expect.truthy(relicId)
        local ok1=Rare:_claimRelicUniqueness(101,'item-a',relicId,'WorldUnique')
        local ok2,reason2=Rare:_claimRelicUniqueness(202,'item-b',relicId,'WorldUnique')
        expect.truthy(ok1); expect.falsy(ok2); expect.equal(reason2,'UniquenessClaimed')
    end)
    t.test('T-1242 uniqueness ownership can move for the same item id',function()
        Rare._worldState.Uniqueness={}
        local relicId=nil for id,d in pairs(Config.Relics) do if d.UniquenessPolicy=='WorldUnique' then relicId=id break end end
        expect.truthy(Rare:_claimRelicUniqueness(101,'item-transfer',relicId,'WorldUnique'))
        local ok=Rare:_claimRelicUniqueness(202,'item-transfer',relicId,'WorldUnique')
        expect.truthy(ok)
    end)
    t.test('T-1243 server-limited relic rejects duplicate item ids in scope',function()
        Rare._worldState.Uniqueness={}
        local relicId=nil for id,d in pairs(Config.Relics) do if d.UniquenessPolicy=='ServerLimited' then relicId=id break end end
        expect.truthy(relicId)
        expect.truthy(Rare:_claimRelicUniqueness(101,'server-item-a',relicId,'ServerLimited'))
        local ok,reason=Rare:_claimRelicUniqueness(202,'server-item-b',relicId,'ServerLimited')
        expect.falsy(ok); expect.equal(reason,'UniquenessClaimed')
    end)
end