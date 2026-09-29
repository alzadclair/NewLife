--!strict
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DataStoreService = game:GetService('DataStoreService')

local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local Content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local AttributeConfig = require(ReplicatedStorage.NewLife.Shared.Config.AttributeConfig)

local Service = {
    _started = false,
    _store = nil,
    _profiles = {} :: {[Player]: any},
    _studioMemory = {} :: {[number]: any},
}

local function copy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in tbl do
        out[k] = type(v) == 'table' and copy(v) or v
    end
    return out
end

local function xpToNext(lvl: number): number
    return GameConfig.Progression.BaseXPToNext + (lvl * GameConfig.Progression.XPPerLevel)
end

local function generateFateSeed(userId: number): string
    local h = (userId * 1664525 + 1013904223) % 2147483647
    return string.format("FATE-%d-%d", h, os.time() % 100000)
end

local function rollBirthTraits(rng: Random): {string}
    local pool = {}
    for id, def in pairs(Content.Traits) do
        local weight = 1
        if def.Rarity == 'Common' then weight = 50
        elseif def.Rarity == 'Uncommon' then weight = 30
        elseif def.Rarity == 'Rare' then weight = 14
        elseif def.Rarity == 'Epic' then weight = 5
        elseif def.Rarity == 'Legendary' then weight = 1
        end
        for _ = 1, weight do
            table.insert(pool, id)
        end
    end

    local picked = {}
    local numTraits = rng:NextInteger(1, 2)
    for _ = 1, numTraits do
        if #pool > 0 then
            local idx = rng:NextInteger(1, #pool)
            local chosen = pool[idx]
            if not table.find(picked, chosen) then
                table.insert(picked, chosen)
            end
        end
    end
    if #picked == 0 then table.insert(picked, 'Sturdy') end
    return picked
end

local function defaultProfile(userId: number)
    local fateSeed = generateFateSeed(userId)
    local rng = Random.new(userId + os.time())
    local traits = rollBirthTraits(rng)
    local noMagic = rng:NextNumber() < GameConfig.Progression.NoMagicChance

    local isHybrid = rng:NextNumber() < 0.15
    local secondaryRace = isHybrid and 'Elf' or nil

    local classApt = math.floor(rng:NextNumber(40, 101))
    local magicApt = noMagic and 0 or math.floor(rng:NextNumber(35, 101))

    for _, trId in ipairs(traits) do
        local tDef = Content.Traits[trId]
        if tDef and tDef.StatBonus then
            if tDef.StatBonus.ClassAptitude then
                classApt = math.clamp(classApt + tDef.StatBonus.ClassAptitude, 0, 100)
            end
            if tDef.StatBonus.MagicAptitude and not noMagic then
                magicApt = math.clamp(magicApt + tDef.StatBonus.MagicAptitude, 0, 100)
            end
        end
    end

    local summary = string.format("Race: Human%s | Class: Adventurer | Fate: %s | Magic: %s | Traits: %s",
        isHybrid and " (Elf Hybrid)" or "",
        fateSeed,
        noMagic and "NO" or "YES",
        table.concat(traits, ", ")
    )

    return {
        SchemaVersion = GameConfig.SchemaVersion,
        Birth = {
            FateSeed = fateSeed,
            BirthDate = os.time(),
            Traits = traits,
            IsHybrid = isHybrid,
            SecondaryRace = secondaryRace,
            Summary = summary,
        },
        Attributes = copy(AttributeConfig.Defaults),
        Identity = {
            Race = 'Human',
            Class = 'Adventurer',
            FateSeed = fateSeed,
        },
        Progression = {
            Level = 0,
            XP = 0,
            Gold = 0,
            PowerRating = 0,
            ClassAptitude = classApt,
            MagicAptitude = magicApt,
            HasMagic = not noMagic,
        },
        Build = {
            Unlocked = {
                Evolution = true,
                AdaptivePotential = true,
                AdventurerStrike = true,
                FieldMedicine = false,
                VersatileExplorer = false,
                IronBody = true,
                ArcBolt = true,
                EmberBurst = true,
            },
            Mastery = {},
            SkillSlots = {[1] = 'Evolution', [2] = 'AdventurerStrike'},
            MagicSlots = {[1] = 'ArcBolt', [2] = 'EmberBurst'},
            DefierProgress = 0,
            DefierOfFate = false,
            EvolutionStage = 1,
            RaceProgress = {
                Human = { Mastery = 0, Level = 1 },
            },
            ClassProgress = {
                Adventurer = { Mastery = 0, Level = 1 },
            },
        },
        Inventory = {},
        Quests = {},
        Titles = {},
        Legacy = {Score = 0, Choices = {}},
        -- Phase 6 additions:
        Relationships = {
            GuardKael = { Reputation = 0, Familiarity = 0 },
            MerchantBoran = { Reputation = 0, Familiarity = 0 },
            ElderRowan = { Reputation = 0, Familiarity = 0 },
        },
        PlayerChronicle = {
            { Timestamp = os.time(), Text = "Awakened in the realm of New Life under fate " .. fateSeed, Category = "Birth" }
        },
        NPCMemory = {
            GuardKael = {},
            MerchantBoran = {},
            ElderRowan = {},
        },
        -- Phase 7 additions. Party remains session state; guild/social identity persists.
        Guild = {
            Id = '',
            Name = '',
            Tag = '',
            Role = '',
            JoinedAt = 0,
        },
        Social = {
            Nation = GameConfig.Social.DefaultNation,
            BlockedUserIds = {},
            MutedUserIds = {},
            Reports = {},
        },
        Kingdom = {
            CurrentId = GameConfig.Kingdoms.DefaultKingdom,
            Reputations = {VerdantReign=0, IronHold=0, Sunspire=0, ShadowKeep=0, FrostPeak=0},
            PoliticalHistory = {},
            FutureLoyalty = '',
            FutureGuildAffiliation = '',
        },
        -- Phase 9 persistent world-boss progress. Encounter state remains server-memory only.
        Bosses = {
            DailyRewardDates = {},
            Clears = {},
            FirstClears = {},
            History = {},
        },
        -- Phase 10 durable dungeon progression only; active instance state stays server-memory only.
        Dungeons = {
            Entered = 0,
            Completions = 0,
            HighestRankIndex = 0,
            HighestRank = '',
            FirstClears = {},
            BossClears = {},
            History = {},
        },
        RareContent = {
            ExtinctClassId = '',
            LegendarySkills = {},
            LegendaryMagic = {},
            RareItems = {},
            EquippedRelics = {},
            RareHistory = {},
        },
        Economy = {
            Ledger = {},
            ProcessedTransactions = {},
            Receivables = {},
            Market = {Sales = 0, Purchases = 0, FeesPaid = 0, TaxPaid = 0},
        },
    }
end

local function sanitize(p, userId)
    p.SchemaVersion = GameConfig.SchemaVersion
    p.Birth = type(p.Birth) == 'table' and p.Birth or {}
    p.Birth.FateSeed = type(p.Birth.FateSeed) == 'string' and p.Birth.FateSeed or generateFateSeed(userId)
    p.Birth.BirthDate = tonumber(p.Birth.BirthDate) or os.time()
    p.Birth.Traits = type(p.Birth.Traits) == 'table' and p.Birth.Traits or rollBirthTraits(Random.new(userId))
    p.Birth.IsHybrid = p.Birth.IsHybrid == true
    p.Birth.SecondaryRace = p.Birth.IsHybrid and (type(p.Birth.SecondaryRace) == 'string' and p.Birth.SecondaryRace or 'Elf') or nil
    p.Birth.Summary = type(p.Birth.Summary) == 'string' and p.Birth.Summary or string.format("Fate: %s | Traits: %s", p.Birth.FateSeed, table.concat(p.Birth.Traits, ", "))

    p.Identity = type(p.Identity) == 'table' and p.Identity or {Race = 'Human', Class = 'Adventurer', FateSeed = p.Birth.FateSeed}
    p.Identity.Race = Content.Races[p.Identity.Race] and p.Identity.Race or 'Human'
    p.Identity.Class = Content.Classes[p.Identity.Class] and p.Identity.Class or 'Adventurer'
    p.Identity.FateSeed = p.Birth.FateSeed

    p.Progression = type(p.Progression) == 'table' and p.Progression or {}
    local g = p.Progression
    g.Level = math.clamp(tonumber(g.Level) or 0, 0, GameConfig.Progression.MaxLevel)
    g.XP = math.max(0, tonumber(g.XP) or 0)
    g.Gold = math.max(0, tonumber(g.Gold) or 0)
    g.ClassAptitude = math.clamp(tonumber(g.ClassAptitude) or 50, 0, 100)
    g.MagicAptitude = math.clamp(tonumber(g.MagicAptitude) or 0, 0, 100)
    g.HasMagic = g.HasMagic ~= false

    p.Build = type(p.Build) == 'table' and p.Build or {}
    p.Build.Unlocked = type(p.Build.Unlocked) == 'table' and p.Build.Unlocked or {}
    p.Build.Mastery = type(p.Build.Mastery) == 'table' and p.Build.Mastery or {}
    p.Build.SkillSlots = type(p.Build.SkillSlots) == 'table' and p.Build.SkillSlots or {[1] = 'Evolution', [2] = 'AdventurerStrike'}
    p.Build.MagicSlots = type(p.Build.MagicSlots) == 'table' and p.Build.MagicSlots or {[1] = 'ArcBolt', [2] = 'EmberBurst'}
    p.Build.DefierProgress = tonumber(p.Build.DefierProgress) or 0
    p.Build.DefierOfFate = p.Build.DefierOfFate == true
    p.Build.EvolutionStage = tonumber(p.Build.EvolutionStage) or 1

    -- Phase 5 Progressions (ensuring Level is mathematically consistent with Mastery)
    p.Build.RaceProgress = type(p.Build.RaceProgress) == 'table' and p.Build.RaceProgress or {}
    if not p.Build.RaceProgress[p.Identity.Race] then
        p.Build.RaceProgress[p.Identity.Race] = { Mastery = 0, Level = 1 }
    else
        local rProg = p.Build.RaceProgress[p.Identity.Race]
        rProg.Level = math.floor((rProg.Mastery or 0) / 50) + 1
    end

    p.Build.ClassProgress = type(p.Build.ClassProgress) == 'table' and p.Build.ClassProgress or {}
    if not p.Build.ClassProgress[p.Identity.Class] then
        p.Build.ClassProgress[p.Identity.Class] = { Mastery = 0, Level = 1 }
    else
        local cProg = p.Build.ClassProgress[p.Identity.Class]
        cProg.Level = math.floor((cProg.Mastery or 0) / 50) + 1
    end

    -- Ensure starter unlocks
    local raceDef = Content.Races[p.Identity.Race]
    if raceDef then
        if raceDef.ActiveSkill then p.Build.Unlocked[raceDef.ActiveSkill] = true end
        if raceDef.PassiveSkill then p.Build.Unlocked[raceDef.PassiveSkill] = true end
    end
    local classDef = Content.Classes[p.Identity.Class]
    if classDef and classDef.StartingSkills then
        for _, sId in ipairs(classDef.StartingSkills) do
            p.Build.Unlocked[sId] = true
        end
    end
    -- Backward compatibility unlocks
    p.Build.Unlocked.IronBody = true
    p.Build.Unlocked.ArcBolt = true
    p.Build.Unlocked.EmberBurst = true

    p.Attributes = type(p.Attributes) == 'table' and p.Attributes or copy(AttributeConfig.Defaults)
    p.Inventory = type(p.Inventory) == 'table' and p.Inventory or {}
    p.Quests = type(p.Quests) == 'table' and p.Quests or {}
    p.Titles = type(p.Titles) == 'table' and p.Titles or {}
    p.Legacy = type(p.Legacy) == 'table' and p.Legacy or {Score = 0, Choices = {}}

    -- Phase 6 additions:
    p.Relationships = type(p.Relationships) == 'table' and p.Relationships or {}
    for npcId, _ in pairs(Content.NPCs) do
        if not p.Relationships[npcId] then
            p.Relationships[npcId] = { Reputation = 0, Familiarity = 0 }
        end
    end

    p.PlayerChronicle = type(p.PlayerChronicle) == 'table' and p.PlayerChronicle or {}
    if #p.PlayerChronicle == 0 then
        table.insert(p.PlayerChronicle, { Timestamp = os.time(), Text = "Awakened in New Life under fate " .. p.Birth.FateSeed, Category = "Birth" })
    end

    p.NPCMemory = type(p.NPCMemory) == 'table' and p.NPCMemory or {}
    for npcId, _ in pairs(Content.NPCs) do
        if not p.NPCMemory[npcId] then
            p.NPCMemory[npcId] = {}
        end
    end

    -- Phase 7 migration is additive and preserves every pre-existing field.
    p.Guild = type(p.Guild) == 'table' and p.Guild or {}
    p.Guild.Id = type(p.Guild.Id) == 'string' and p.Guild.Id or ''
    p.Guild.Name = type(p.Guild.Name) == 'string' and p.Guild.Name or ''
    p.Guild.Tag = type(p.Guild.Tag) == 'string' and p.Guild.Tag or ''
    p.Guild.Role = type(p.Guild.Role) == 'string' and p.Guild.Role or ''
    p.Guild.JoinedAt = math.max(0, tonumber(p.Guild.JoinedAt) or 0)

    p.Social = type(p.Social) == 'table' and p.Social or {}
    p.Social.Nation = type(p.Social.Nation) == 'string' and p.Social.Nation or GameConfig.Social.DefaultNation
    p.Social.BlockedUserIds = type(p.Social.BlockedUserIds) == 'table' and p.Social.BlockedUserIds or {}
    p.Social.MutedUserIds = type(p.Social.MutedUserIds) == 'table' and p.Social.MutedUserIds or {}
    p.Social.Reports = type(p.Social.Reports) == 'table' and p.Social.Reports or {}

    -- Phase 8 additive migration: kingdom identity, per-kingdom reputation and political history.
    p.Kingdom = type(p.Kingdom) == 'table' and p.Kingdom or {}
    p.Kingdom.CurrentId = Content.Kingdoms[p.Kingdom.CurrentId] and p.Kingdom.CurrentId or (Content.Kingdoms[p.Social.Nation] and p.Social.Nation or GameConfig.Kingdoms.DefaultKingdom)
    p.Kingdom.Reputations = type(p.Kingdom.Reputations) == 'table' and p.Kingdom.Reputations or {}
    for _, kingdomId in ipairs(GameConfig.Kingdoms.OrderedIds) do
        p.Kingdom.Reputations[kingdomId] = math.clamp(math.floor(tonumber(p.Kingdom.Reputations[kingdomId]) or 0), GameConfig.Kingdoms.ReputationMin, GameConfig.Kingdoms.ReputationMax)
    end
    p.Kingdom.PoliticalHistory = type(p.Kingdom.PoliticalHistory) == 'table' and p.Kingdom.PoliticalHistory or {}
    p.Kingdom.FutureLoyalty = type(p.Kingdom.FutureLoyalty) == 'string' and p.Kingdom.FutureLoyalty or ''
    p.Kingdom.FutureGuildAffiliation = type(p.Kingdom.FutureGuildAffiliation) == 'string' and p.Kingdom.FutureGuildAffiliation or ''
    p.Social.Nation = p.Kingdom.CurrentId

    -- Phase 9 additive migration: only durable reward/clear history is persisted.
    p.Bosses = type(p.Bosses) == 'table' and p.Bosses or {}
    p.Bosses.DailyRewardDates = type(p.Bosses.DailyRewardDates) == 'table' and p.Bosses.DailyRewardDates or {}
    p.Bosses.Clears = type(p.Bosses.Clears) == 'table' and p.Bosses.Clears or {}
    p.Bosses.FirstClears = type(p.Bosses.FirstClears) == 'table' and p.Bosses.FirstClears or {}
    p.Bosses.History = type(p.Bosses.History) == 'table' and p.Bosses.History or {}

    -- Phase 10 additive migration: compact dungeon progression; never persists live rooms/enemies/seed state.
    p.Dungeons = type(p.Dungeons) == 'table' and p.Dungeons or {}
    p.Dungeons.Entered = math.max(0, math.floor(tonumber(p.Dungeons.Entered) or 0))
    p.Dungeons.Completions = math.max(0, math.floor(tonumber(p.Dungeons.Completions) or 0))
    p.Dungeons.HighestRankIndex = math.max(0, math.floor(tonumber(p.Dungeons.HighestRankIndex) or 0))
    p.Dungeons.HighestRank = type(p.Dungeons.HighestRank) == 'string' and p.Dungeons.HighestRank or ''
    p.Dungeons.FirstClears = type(p.Dungeons.FirstClears) == 'table' and p.Dungeons.FirstClears or {}
    p.Dungeons.BossClears = type(p.Dungeons.BossClears) == 'table' and p.Dungeons.BossClears or {}
    p.Dungeons.History = type(p.Dungeons.History) == 'table' and p.Dungeons.History or {}

    -- Phase 12 additive migration: unique rare items, extinct class, legendary unlocks and relic loadout.
    p.RareContent = type(p.RareContent) == 'table' and p.RareContent or {}
    p.RareContent.ExtinctClassId = type(p.RareContent.ExtinctClassId) == 'string' and p.RareContent.ExtinctClassId or ''
    p.RareContent.LegendarySkills = type(p.RareContent.LegendarySkills) == 'table' and p.RareContent.LegendarySkills or {}
    p.RareContent.LegendaryMagic = type(p.RareContent.LegendaryMagic) == 'table' and p.RareContent.LegendaryMagic or {}
    p.RareContent.RareItems = type(p.RareContent.RareItems) == 'table' and p.RareContent.RareItems or {}
    p.RareContent.EquippedRelics = type(p.RareContent.EquippedRelics) == 'table' and p.RareContent.EquippedRelics or {}
    p.RareContent.RareHistory = type(p.RareContent.RareHistory) == 'table' and p.RareContent.RareHistory or {}
    if p.RareContent.ExtinctClassId ~= '' and Content.Classes[p.RareContent.ExtinctClassId] then
        p.Identity.Class = p.RareContent.ExtinctClassId
    end

    -- Phase 13 additive migration: only compact durable economy state is persisted.
    p.Economy = type(p.Economy) == 'table' and p.Economy or {}
    p.Economy.Ledger = type(p.Economy.Ledger) == 'table' and p.Economy.Ledger or {}
    p.Economy.ProcessedTransactions = type(p.Economy.ProcessedTransactions) == 'table' and p.Economy.ProcessedTransactions or {}
    p.Economy.Receivables = type(p.Economy.Receivables) == 'table' and p.Economy.Receivables or {}
    p.Economy.Market = type(p.Economy.Market) == 'table' and p.Economy.Market or {Sales = 0, Purchases = 0, FeesPaid = 0, TaxPaid = 0}
end

local function migrate(saved, userId: number)
    local p = defaultProfile(userId)
    if type(saved) ~= 'table' then return p end
    for k, v in saved do
        if p[k] ~= nil then p[k] = copy(v) end
    end
    sanitize(p, userId)
    return p
end

function Service:RecalculateAttributes(player: Player)
    local p = self._profiles[player]
    if not p then return end

    local base = copy(AttributeConfig.Defaults)
    local raceId = p.Identity.Race
    local classId = p.Identity.Class
    local raceDef = Content.Races[raceId]
    local classDef = Content.Classes[classId]
    local isHybrid = p.Birth.IsHybrid == true
    local secRaceId = p.Birth.SecondaryRace
    local secRaceDef = isHybrid and secRaceId and Content.Races[secRaceId] or nil

    -- 1. Race modifiers (with hybrid scaling)
    if raceDef and raceDef.AttributeModifiers then
        local scale = isHybrid and GameConfig.Progression.HybridStatScalePrimary or 1.0
        for stat, val in pairs(raceDef.AttributeModifiers) do
            if base[stat] then
                base[stat] += math.floor(val * scale)
            end
        end
    end
    if secRaceDef and secRaceDef.AttributeModifiers then
        local scale = GameConfig.Progression.HybridStatScaleSecondary or 0.40
        for stat, val in pairs(secRaceDef.AttributeModifiers) do
            if base[stat] then
                base[stat] += math.floor(val * scale)
            end
        end
    end

    -- Hybrid Stamina penalty
    if isHybrid and base.MaxStamina then
        base.MaxStamina = math.max(10, base.MaxStamina - (GameConfig.Progression.HybridStaminaPenalty or 5))
    end

    -- 2. Class modifiers
    if classDef and classDef.AttributeModifiers then
        for stat, val in pairs(classDef.AttributeModifiers) do
            if base[stat] then
                base[stat] += val
            end
        end
    end

    -- 3. Passives & Perks from Unlocked skills
    if p.Build and p.Build.Unlocked then
        for sId, unl in pairs(p.Build.Unlocked) do
            if unl then
                local sDef = Content.Skills[sId]
                if sDef and sDef.Type == 'Passive' and sDef.StatBonus then
                    for stat, val in pairs(sDef.StatBonus) do
                        if base[stat] then
                            base[stat] += val
                        end
                    end
                end
            end
        end
    end

    -- 4. Birth Traits
    if p.Birth and p.Birth.Traits then
        for _, trId in ipairs(p.Birth.Traits) do
            local tDef = Content.Traits[trId]
            if tDef and tDef.StatBonus then
                for stat, val in pairs(tDef.StatBonus) do
                    if base[stat] then
                        base[stat] += val
                    end
                end
            end
        end
    end

    -- 5. Human Evolution Stage Perks
    if raceId == 'Human' and p.Build.EvolutionStage and raceDef and raceDef.Perks then
        local stage = p.Build.EvolutionStage
        if stage >= 2 and raceDef.Perks[50] then
            base.MaxHealth += (raceDef.Perks[50].BonusHealth or 0)
        end
        if stage >= 3 and raceDef.Perks[150] then
            base.MaxStamina += (raceDef.Perks[150].BonusStamina or 0)
        end
    end

    -- 6. No-magic physical bonus
    if not p.Progression.HasMagic then
        base.Strength = math.floor(base.Strength * GameConfig.Progression.NoMagicPhysicalBonus)
        base.Defense = math.floor(base.Defense * GameConfig.Progression.NoMagicPhysicalBonus)
    end

    local okRare, RareContentService = pcall(function() return require(script.Parent.RareContentService) end)
    if okRare and RareContentService and RareContentService.ApplyRelicStats then RareContentService.ApplyRelicStats(p, base) end
    p.Attributes = base

    -- Apply to Character model safely without resetting current pools
    local char = player.Character
    if char then
        for name, val in pairs(base) do
            if name == 'MaxHealth' or name == 'MaxMana' or name == 'MaxStamina' then
                char:SetAttribute(name, val)
                local currentKey = name:sub(4)
                local current = char:GetAttribute(currentKey)
                if current ~= nil then
                    char:SetAttribute(currentKey, math.clamp(current, 0, val))
                end
            elseif name == 'Health' or name == 'Mana' or name == 'Stamina' then
                if char:GetAttribute(name) == nil then
                    char:SetAttribute(name, val)
                else
                    local maxVal = base['Max' .. name] or val
                    local current = char:GetAttribute(name)
                    char:SetAttribute(name, math.clamp(current, 0, maxVal))
                end
            else
                char:SetAttribute(name, val)
            end
        end
    end
end

function Service:RecalculatePower(player: Player)
    local p = self._profiles[player]
    if not p then return 0 end

    self:RecalculateAttributes(player)

    local a = p.Attributes
    local g = p.Progression
    local pr = math.floor(g.Level * 10 + a.Strength * 2 + a.Defense * 2 + a.Power * 3 + g.ClassAptitude * 0.5 + (g.HasMagic and g.MagicAptitude * 0.5 or 0))

    -- Trait power
    if p.Birth and p.Birth.Traits then
        for _, trId in ipairs(p.Birth.Traits) do
            local tDef = Content.Traits[trId]
            if tDef and tDef.PowerBonus then
                pr += tDef.PowerBonus
            end
        end
    end

    -- Race & Class Mastery and Levels
    local raceProg = p.Build.RaceProgress and p.Build.RaceProgress[p.Identity.Race]
    if raceProg then
        pr += math.floor((raceProg.Mastery or 0) * 0.3) + math.max(0, (raceProg.Level or 1) - 1) * 10
    end
    local classProg = p.Build.ClassProgress and p.Build.ClassProgress[p.Identity.Class]
    if classProg then
        pr += math.floor((classProg.Mastery or 0) * 0.3) + math.max(0, (classProg.Level or 1) - 1) * 10
    end

    -- Evolution stages (unbounded preparation)
    if p.Build and p.Build.EvolutionStage then
        pr += p.Build.EvolutionStage * 20
    end

    -- Hybrid bonus
    if p.Birth and p.Birth.IsHybrid then
        pr += 15
    end

    -- Defier of Fate bonus (only if active)
    local defierThresh = GameConfig.Progression.DefierThreshold or 3
    local defierProg = p.Build.DefierProgress or 0
    if p.Build and p.Build.DefierOfFate and defierProg >= defierThresh then
        pr += 50
    elseif defierProg > 0 then
        pr += defierProg * 10
    end

    g.PowerRating = pr
    player:SetAttribute('PowerRating', pr)
    return pr
end

function Service:Apply(player: Player)
    local p = self._profiles[player]
    if not p then return end

    self:RecalculatePower(player)

    player:SetAttribute('RaceId', p.Identity.Race)
    player:SetAttribute('ClassId', p.Identity.Class)
    player:SetAttribute('FateSeed', p.Birth.FateSeed or p.Identity.FateSeed)
    player:SetAttribute('BirthTraits', table.concat(p.Birth.Traits or {}, ', '))
    player:SetAttribute('IsHybrid', p.Birth.IsHybrid == true)
    player:SetAttribute('SecondaryRace', p.Birth.SecondaryRace or '')
    player:SetAttribute('BirthSummary', p.Birth.Summary or '')
    player:SetAttribute('EvolutionStage', p.Build.EvolutionStage or 1)
    local evoNames = {[1] = 'Adaptation', [2] = 'Resilience', [3] = 'Apex', [4] = 'LimitBreaker'}
    player:SetAttribute('EvolutionStageName', evoNames[p.Build.EvolutionStage or 1] or 'Adaptation')

    -- AUDIT FIX 1: Race & Class progression Level strictly computed from Mastery
    local raceProg = p.Build.RaceProgress and p.Build.RaceProgress[p.Identity.Race] or {Mastery = 0, Level = 1}
    raceProg.Level = math.floor((raceProg.Mastery or 0) / 50) + 1
    player:SetAttribute('RaceMastery', raceProg.Mastery or 0)
    player:SetAttribute('RaceLevel', raceProg.Level)

    local classProg = p.Build.ClassProgress and p.Build.ClassProgress[p.Identity.Class] or {Mastery = 0, Level = 1}
    classProg.Level = math.floor((classProg.Mastery or 0) / 50) + 1
    player:SetAttribute('ClassMastery', classProg.Mastery or 0)
    player:SetAttribute('ClassLevel', classProg.Level)

    -- Count unlocked skills
    local count = 0
    for _, u in pairs(p.Build.Unlocked) do
        if u then count += 1 end
    end
    player:SetAttribute('UnlockedCount', count)

    player:SetAttribute('Level', p.Progression.Level)
    player:SetAttribute('XP', p.Progression.XP)
    player:SetAttribute('XPToNext', xpToNext(p.Progression.Level))
    player:SetAttribute('Gold', p.Progression.Gold)
    player:SetAttribute('ClassAptitude', p.Progression.ClassAptitude)
    player:SetAttribute('MagicAptitude', p.Progression.MagicAptitude)
    player:SetAttribute('HasMagic', p.Progression.HasMagic)
    player:SetAttribute('LegacyScore', p.Legacy.Score or 0)
    player:SetAttribute('GuildId', p.Guild and p.Guild.Id or '')
    player:SetAttribute('GuildName', p.Guild and p.Guild.Name or '')
    player:SetAttribute('GuildTag', p.Guild and p.Guild.Tag or '')
    player:SetAttribute('GuildRole', p.Guild and p.Guild.Role or '')
    player:SetAttribute('NationId', p.Social and p.Social.Nation or GameConfig.Social.DefaultNation)
    local kingdomId = p.Kingdom and p.Kingdom.CurrentId or GameConfig.Kingdoms.DefaultKingdom
    local kingdomDef = Content.Kingdoms[kingdomId]
    player:SetAttribute('KingdomId', kingdomId)
    player:SetAttribute('KingdomName', kingdomDef and kingdomDef.Name or kingdomId)
    player:SetAttribute('KingdomReputation', p.Kingdom and p.Kingdom.Reputations and (p.Kingdom.Reputations[kingdomId] or 0) or 0)
    player:SetAttribute('PoliticalRole', player:GetAttribute('PoliticalRole') or 'Citizen')

    -- AUDIT FIX 2: DefierOfFate attribute is strictly TRUE only when DefierOfFate == true AND DefierProgress >= DefierThreshold
    local defierThresh = GameConfig.Progression.DefierThreshold or 3
    local defierProg = p.Build.DefierProgress or 0
    local isDefierActive = (p.Build.DefierOfFate == true) and (defierProg >= defierThresh)
    player:SetAttribute('DefierOfFate', isDefierActive)
    player:SetAttribute('DefierProgress', defierProg)

    player:SetAttribute('SkillSlot1', p.Build.SkillSlots[1] or '')
    player:SetAttribute('SkillSlot2', p.Build.SkillSlots[2] or '')
    player:SetAttribute('MagicSlot1', p.Build.MagicSlots[1] or '')
    player:SetAttribute('MagicSlot2', p.Build.MagicSlots[2] or '')

    for sId, mst in pairs(p.Build.Mastery) do
        player:SetAttribute('Mastery_' .. sId, mst)
    end

    player:SetAttribute('ProfileLoaded', true)
    player:SetAttribute('PersistenceMode', RunService:IsStudio() and 'StudioMemory' or 'DataStore')
end

function Service:SetRace(player: Player, raceId: string): (boolean, string)
    local p = self._profiles[player]
    local def = Content.Races[raceId]
    if not p or not def then return false, 'InvalidRace' end
    p.Identity.Race = raceId
    p.Build.RaceProgress = p.Build.RaceProgress or {}
    if not p.Build.RaceProgress[raceId] then
        p.Build.RaceProgress[raceId] = {Mastery = 0, Level = 1}
    end
    if def.ActiveSkill then p.Build.Unlocked[def.ActiveSkill] = true end
    if def.PassiveSkill then p.Build.Unlocked[def.PassiveSkill] = true end
    self:Apply(player)
    return true, 'OK'
end

function Service:SetClass(player: Player, classId: string): (boolean, string)
    local p = self._profiles[player]
    local def = Content.Classes[classId]
    if not p or not def then return false, 'InvalidClass' end
    p.Identity.Class = classId
    p.Build.ClassProgress = p.Build.ClassProgress or {}
    if not p.Build.ClassProgress[classId] then
        p.Build.ClassProgress[classId] = {Mastery = 0, Level = 1}
    end
    if def.StartingSkills then
        for _, sId in ipairs(def.StartingSkills) do
            p.Build.Unlocked[sId] = true
        end
    end
    self:Apply(player)
    return true, 'OK'
end

-- Phase 8 Kingdom APIs. Server services own all mutations; no direct client setter exists.
function Service:SetKingdomMembership(player: Player, kingdomId: string, reason: string?): (boolean, string)
    local p = self._profiles[player]
    if not p or not Content.Kingdoms[kingdomId] then return false, 'InvalidKingdom' end
    local old = p.Kingdom.CurrentId
    if old == kingdomId then return true, 'Unchanged' end
    p.Kingdom.CurrentId = kingdomId
    p.Social.Nation = kingdomId
    table.insert(p.Kingdom.PoliticalHistory, {Timestamp=os.time(), Type='Membership', From=old, To=kingdomId, Reason=reason or 'ServerDecision'})
    self:Apply(player)
    return true, 'OK'
end

function Service:AddKingdomReputation(player: Player, kingdomId: string, amount: number): (boolean, number)
    local p = self._profiles[player]
    if not p or not Content.Kingdoms[kingdomId] then return false, 0 end
    local current = p.Kingdom.Reputations[kingdomId] or 0
    local nextValue = math.clamp(current + math.floor(amount), GameConfig.Kingdoms.ReputationMin, GameConfig.Kingdoms.ReputationMax)
    p.Kingdom.Reputations[kingdomId] = nextValue
    if p.Kingdom.CurrentId == kingdomId then player:SetAttribute('KingdomReputation', nextValue) end
    return true, nextValue
end

function Service:GetKingdomState(player: Player)
    local p = self._profiles[player]
    return p and p.Kingdom or nil
end

-- NPC Relationship & Memory APIs
function Service:GetNPCRelationship(player: Player, npcId: string)
    local p = self._profiles[player]
    if not p or not p.Relationships then return { Reputation = 0, Familiarity = 0 } end
    if not p.Relationships[npcId] then
        p.Relationships[npcId] = { Reputation = 0, Familiarity = 0 }
    end
    return p.Relationships[npcId]
end

function Service:AddReputation(player: Player, npcId: string, amount: number)
    local p = self._profiles[player]
    if not p then return end
    local rel = self:GetNPCRelationship(player, npcId)
    rel.Reputation = (rel.Reputation or 0) + math.floor(amount)
    player:SetAttribute('Rep_' .. npcId, rel.Reputation)
end

function Service:AddFamiliarity(player: Player, npcId: string, amount: number)
    local p = self._profiles[player]
    if not p then return end
    local rel = self:GetNPCRelationship(player, npcId)
    rel.Familiarity = (rel.Familiarity or 0) + math.floor(amount)
    player:SetAttribute('Fam_' .. npcId, rel.Familiarity)
end

function Service:SetNPCMemory(player: Player, npcId: string, key: string, value: any)
    local p = self._profiles[player]
    if not p then return end
    p.NPCMemory = p.NPCMemory or {}
    p.NPCMemory[npcId] = p.NPCMemory[npcId] or {}
    p.NPCMemory[npcId][key] = value
end

function Service:GetNPCMemory(player: Player, npcId: string, key: string): any
    local p = self._profiles[player]
    if not p or not p.NPCMemory or not p.NPCMemory[npcId] then return nil end
    return p.NPCMemory[npcId][key]
end

-- Player Chronicle API
function Service:AddPlayerChronicle(player: Player, text: string, category: string?)
    local p = self._profiles[player]
    if not p then return end
    p.PlayerChronicle = p.PlayerChronicle or {}
    table.insert(p.PlayerChronicle, {
        Timestamp = os.time(),
        Text = text,
        Category = category or 'General',
    })
    player:SetAttribute('ChronicleCount', #p.PlayerChronicle)
end

function Service:GetPlayerChronicle(player: Player)
    local p = self._profiles[player]
    return p and p.PlayerChronicle or {}
end

function Service:GetProfile(player: Player)
    return self._profiles[player]
end

function Service:GetSnapshot(player: Player)
    local p = self._profiles[player]
    if not p then return nil end
    return {
        SchemaVersion = p.SchemaVersion or GameConfig.SchemaVersion,
        Birth = copy(p.Birth),
        Identity = copy(p.Identity),
        Progression = copy(p.Progression),
        Attributes = copy(p.Attributes),
        Build = copy(p.Build),
        Inventory = copy(p.Inventory),
        Quests = copy(p.Quests),
        Titles = copy(p.Titles),
        Legacy = {Score = (p.Legacy and p.Legacy.Score) or 0},
        Relationships = copy(p.Relationships),
        PlayerChronicle = copy(p.PlayerChronicle),
        NPCMemory = copy(p.NPCMemory),
        Guild = copy(p.Guild),
        Social = copy(p.Social),
        Kingdom = copy(p.Kingdom),
        Bosses = copy(p.Bosses),
        Dungeons = copy(p.Dungeons),
        RareContent = copy(p.RareContent),
        Economy = copy(p.Economy),
    }
end

function Service:SetGuildMembership(player: Player, guildId: string, guildName: string, guildTag: string, role: string, joinedAt: number?)
    local p = self._profiles[player]
    if not p then return false end
    p.Guild = p.Guild or {}
    p.Guild.Id = guildId
    p.Guild.Name = guildName
    p.Guild.Tag = guildTag
    p.Guild.Role = role
    p.Guild.JoinedAt = joinedAt or os.time()
    self:Apply(player)
    return true
end

function Service:ClearGuildMembership(player: Player)
    local p = self._profiles[player]
    if not p then return false end
    p.Guild = {Id = '', Name = '', Tag = '', Role = '', JoinedAt = 0}
    self:Apply(player)
    return true
end

local function userIdKey(userId: number): string
    return tostring(math.floor(userId))
end

function Service:IsBlocked(player: Player, userId: number): boolean
    local p = self._profiles[player]
    return p ~= nil and p.Social ~= nil and p.Social.BlockedUserIds[userIdKey(userId)] == true
end

function Service:IsMuted(player: Player, userId: number): boolean
    local p = self._profiles[player]
    return p ~= nil and p.Social ~= nil and p.Social.MutedUserIds[userIdKey(userId)] == true
end

function Service:SetBlocked(player: Player, userId: number, blocked: boolean): (boolean, string)
    local p = self._profiles[player]
    if not p or userId <= 0 or userId == player.UserId then return false, 'InvalidUser' end
    p.Social.BlockedUserIds = p.Social.BlockedUserIds or {}
    local key = userIdKey(userId)
    if blocked then
        local count = 0
        for _, v in pairs(p.Social.BlockedUserIds) do if v == true then count += 1 end end
        if count >= GameConfig.Social.MaxBlocked and p.Social.BlockedUserIds[key] ~= true then return false, 'BlockLimit' end
        p.Social.BlockedUserIds[key] = true
    else
        p.Social.BlockedUserIds[key] = nil
    end
    return true, 'OK'
end

function Service:SetMuted(player: Player, userId: number, muted: boolean): (boolean, string)
    local p = self._profiles[player]
    if not p or userId <= 0 or userId == player.UserId then return false, 'InvalidUser' end
    p.Social.MutedUserIds = p.Social.MutedUserIds or {}
    local key = userIdKey(userId)
    if muted then
        local count = 0
        for _, v in pairs(p.Social.MutedUserIds) do if v == true then count += 1 end end
        if count >= GameConfig.Social.MaxMuted and p.Social.MutedUserIds[key] ~= true then return false, 'MuteLimit' end
        p.Social.MutedUserIds[key] = true
    else
        p.Social.MutedUserIds[key] = nil
    end
    return true, 'OK'
end

function Service:AddSocialReport(player: Player, targetUserId: number, reason: string): (boolean, string)
    local p = self._profiles[player]
    if not p or targetUserId <= 0 or targetUserId == player.UserId then return false, 'InvalidUser' end
    if type(reason) ~= 'string' or reason == '' then return false, 'InvalidReason' end
    reason = string.sub(reason, 1, GameConfig.Chat.ReportReasonMaxLength)
    p.Social.Reports = p.Social.Reports or {}
    while #p.Social.Reports >= GameConfig.Social.MaxReports do table.remove(p.Social.Reports, 1) end
    table.insert(p.Social.Reports, {TargetUserId = targetUserId, Reason = reason, Timestamp = os.time()})
    return true, 'OK'
end

function Service:GetBossProgress(player: Player)
    local p = self._profiles[player]
    return p and p.Bosses or nil
end

function Service:CanClaimBossDailyReward(player: Player, bossId: string, serverDateKey: string): boolean
    local b = self:GetBossProgress(player)
    return b ~= nil and b.DailyRewardDates[bossId] ~= serverDateKey
end

function Service:RecordBossClear(player: Player, bossId: string, serverDateKey: string, grantDaily: boolean): (boolean, boolean)
    local b = self:GetBossProgress(player)
    if not b then return false, false end
    local first = b.FirstClears[bossId] ~= true
    b.Clears[bossId] = math.max(0, math.floor(tonumber(b.Clears[bossId]) or 0)) + 1
    if first then b.FirstClears[bossId] = true end
    if grantDaily then b.DailyRewardDates[bossId] = serverDateKey end
    table.insert(b.History, {Timestamp=os.time(), BossId=bossId, Date=serverDateKey, DailyReward=grantDaily == true, FirstClear=first})
    while #b.History > 50 do table.remove(b.History, 1) end
    player:SetAttribute('BossClearCount', (player:GetAttribute('BossClearCount') or 0) + 1)
    return true, first
end

function Service:GetDungeonProgress(player: Player)
    local p = self._profiles[player]
    return p and p.Dungeons or nil
end

function Service:RecordDungeonEnter(player: Player)
    local d = self:GetDungeonProgress(player)
    if not d then return false end
    d.Entered += 1
    player:SetAttribute('DungeonEnteredCount', d.Entered)
    return true
end

function Service:RecordDungeonClear(player: Player, dungeonId: string, rank: string, rankIndex: number, bossId: string, completionId: string, seed: number)
    local d = self:GetDungeonProgress(player)
    if not d then return false, false end
    local key = dungeonId .. ':' .. rank
    local first = d.FirstClears[key] ~= true
    d.Completions += 1
    d.FirstClears[key] = true
    d.BossClears[bossId] = math.max(0, math.floor(tonumber(d.BossClears[bossId]) or 0)) + 1
    local newHighest = rankIndex > d.HighestRankIndex
    if newHighest then d.HighestRankIndex = rankIndex; d.HighestRank = rank end
    table.insert(d.History, {Timestamp=os.time(),DungeonId=dungeonId,Rank=rank,RankIndex=rankIndex,BossId=bossId,CompletionId=completionId,Seed=seed,FirstClear=first})
    while #d.History > 30 do table.remove(d.History,1) end
    player:SetAttribute('DungeonCompletionCount', d.Completions)
    player:SetAttribute('DungeonHighestRank', d.HighestRank)
    return first, newHighest
end

function Service:GetPublicTitles(player: Player): {string}
    local p = self._profiles[player]
    local out = {}
    if p and p.Titles then
        for titleId, owned in pairs(p.Titles) do if owned == true then table.insert(out, titleId) end end
    end
    table.sort(out)
    return out
end

function Service:AddXP(player: Player, amount: number)
    local p = self._profiles[player]
    if not p or amount <= 0 then return end
    local g = p.Progression
    g.XP += math.floor(amount)
    while g.Level < GameConfig.Progression.MaxLevel do
        local need = xpToNext(g.Level)
        if g.XP < need then break end
        g.XP -= need
        g.Level += 1
    end
    if g.Level >= GameConfig.Progression.MaxLevel then
        g.Level = GameConfig.Progression.MaxLevel
        g.XP = 0
    end
    self:Apply(player)
end

function Service:AddGold(player: Player, amount: number)
    local p = self._profiles[player]
    if p then
        p.Progression.Gold = math.max(0, p.Progression.Gold + math.floor(amount))
        self:Apply(player)
    end
end

function Service:AddItem(player: Player, itemId: string, amount: number): boolean
    local p = self._profiles[player]
    local def = Content.Items[itemId]
    if not p or not def or type(amount) ~= 'number' or amount <= 0 or math.floor(amount) ~= amount then return false end
    local maxCount = def.StackMax * 99
    if (p.Inventory[itemId] or 0) + amount > maxCount then return false end
    p.Inventory[itemId] = (p.Inventory[itemId] or 0) + amount
    player:SetAttribute('InventoryVersion', (player:GetAttribute('InventoryVersion') or 0) + 1)
    return true
end

function Service:GetItemCount(player: Player, itemId: string): number
    local p = self._profiles[player]
    return p and math.max(0, math.floor(tonumber(p.Inventory[itemId]) or 0)) or 0
end

function Service:RemoveItem(player: Player, itemId: string, amount: number): boolean
    local p = self._profiles[player]
    if not p or type(amount) ~= 'number' or amount <= 0 or math.floor(amount) ~= amount then return false end
    local current = math.max(0, math.floor(tonumber(p.Inventory[itemId]) or 0))
    if current < amount then return false end
    local remaining = current - amount
    p.Inventory[itemId] = remaining > 0 and remaining or nil
    player:SetAttribute('InventoryVersion', (player:GetAttribute('InventoryVersion') or 0) + 1)
    return true
end

function Service:SetQuest(player: Player, id: string, state: any)
    local p = self._profiles[player]
    if p then
        p.Quests[id] = copy(state)
        player:SetAttribute('QuestVersion', (player:GetAttribute('QuestVersion') or 0) + 1)
    end
end

function Service:GrantTitle(player: Player, id: string): boolean
    local p = self._profiles[player]
    if p and Content.Titles[id] then
        p.Titles[id] = true
        player:SetAttribute('Title_' .. id, true)
        player:SetAttribute('ActiveTitle', id)
        return true
    end
    return false
end

function Service:ApplyDeathPenalty(player: Player)
    local p = self._profiles[player]
    if not p then return end
    p.Progression.Level = math.max(0, p.Progression.Level - GameConfig.Progression.DeathLevelLoss)
    p.Progression.XP = 0
    self:Apply(player)
end

function Service:LoadPlayer(player: Player)
    if self._profiles[player] then return self._profiles[player] end
    local saved = nil
    if RunService:IsStudio() then
        saved = self._studioMemory[player.UserId]
    elseif self._store then
        local ok, res = pcall(function() return self._store:GetAsync('player_' .. player.UserId) end)
        if ok then saved = res else warn('[NewLife] DataStore load failed', player.UserId) end
    end
    local p = migrate(saved, player.UserId)
    self._profiles[player] = p
    self:Apply(player)
    return p
end

function Service:SavePlayer(player: Player): boolean
    local p = self._profiles[player]
    if not p then return true end
    local payload = copy(p)
    if RunService:IsStudio() then
        self._studioMemory[player.UserId] = payload
        return true
    end
    if not self._store then return false end
    local ok = pcall(function()
        self._store:UpdateAsync('player_' .. player.UserId, function() return payload end)
    end)
    if not ok then warn('[NewLife] DataStore save failed', player.UserId) end
    return ok
end

function Service:Start()
    if self._started then return end
    self._started = true
    if not RunService:IsStudio() then
        local ok, s = pcall(function() return DataStoreService:GetDataStore(GameConfig.DataStoreName) end)
        if ok then self._store = s end
    end
    Players.PlayerAdded:Connect(function(p) self:LoadPlayer(p) end)
    Players.PlayerRemoving:Connect(function(p)
        self:SavePlayer(p)
        self._profiles[p] = nil
    end)
    for _, p in Players:GetPlayers() do
        self:LoadPlayer(p)
    end
end

return Service
