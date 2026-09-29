--!strict
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local ServerScriptService = game:GetService('ServerScriptService')

local RunUnitTest = {}

function RunUnitTest.Run(filter: string?, timeout: number?)
    if not RunService:IsStudio() then
        warn('[UnitTest] Only runs in Studio')
        return
    end

    timeout = timeout or 30
    local startTime = os.clock()

    -- Require all test modules
    local casesFolder = game.ServerStorage.UnitTest.Cases
    local testModules = {
        {Name = 'DungeonConfig', Module = require(casesFolder.DungeonConfig_Test)},
        {Name = 'DungeonService', Module = require(casesFolder.DungeonService_Test)},
        {Name = 'PlayerDataService', Module = require(casesFolder.PlayerDataService_Test)},
        {Name = 'WorldBossService', Module = require(casesFolder.WorldBossService_Test)},
        {Name = 'WorldService', Module = require(casesFolder.WorldService_Test)},
        {Name = 'HUDController', Module = require(casesFolder.HUDController_Test)},
        {Name = 'Bootstrap', Module = require(casesFolder.Bootstrap_Test)},
        {Name = 'Security', Module = require(casesFolder.Security_Test)},
    }

    -- Build services table for runtime tests
    local servicesFolder = ServerScriptService.NewLifeServer.Services
    local dataService = require(servicesFolder.PlayerDataService)
    local dungeonService = require(servicesFolder.DungeonService)
    local worldBossService = require(servicesFolder.WorldBossService)
    local worldService = require(servicesFolder.WorldService)
    local stateService = require(servicesFolder.StateService)
    local progressionService = require(servicesFolder.ProgressionService)
    local questService = require(servicesFolder.QuestService)
    local characterService = require(servicesFolder.CharacterService)
    local enemyService = require(servicesFolder.EnemyService)
    local combatService = require(servicesFolder.CombatService)
    local guildService = require(servicesFolder.GuildService)
    local rulerService = require(servicesFolder.RulerService)

    -- Get or create a player reference
    local player = Players:GetPlayers()[1]
    local playerAvailable = player ~= nil

    -- If no player, create a mock player for testing
    if not player then
        -- Create a minimal mock player for attribute-based tests
        local mockModel = Instance.new('Model')
        mockModel.Name = 'MockPlayer'
        local mockRoot = Instance.new('Part')
        mockRoot.Name = 'HumanoidRootPart'
        mockRoot.Size = Vector3.new(2,2,1)
        mockRoot.Position = Vector3.new(0, 10, 0)
        mockRoot.Anchored = true
        mockRoot.Parent = mockModel
        local mockHum = Instance.new('Humanoid')
        mockHum.MaxHealth = 100
        mockHum.Health = 100
        mockHum.Parent = mockModel
        mockModel.Parent = workspace

        player = {
            Name = 'MockPlayer',
            UserId = 1,
            Character = mockModel,
            Parent = game,
            GetAttribute = function(self, key) return nil end,
            SetAttribute = function(self, key, val)
                mockModel:SetAttribute(key, val)
            end,
        }
        -- Make SetAttribute/GetAttribute work on the mock
        player.SetAttribute = function(self, key, val)
            mockModel:SetAttribute(key, val)
        end
        player.GetAttribute = function(self, key)
            return mockModel:GetAttribute(key)
        end

        -- Create a profile for the mock player in data service
        if dataService._profiles then
            dataService._profiles[player] = dataService._profiles[player] or {
                SchemaVersion = 10,
                Birth = {FateSeed='MOCK', BirthDate=os.time(), Traits={'Sturdy'}, IsHybrid=false, SecondaryRace=nil, Summary='Mock'},
                Identity = {Race='Human', Class='Adventurer', FateSeed='MOCK'},
                Progression = {Level=1, XP=0, Gold=100, PowerRating=10, ClassAptitude=50, MagicAptitude=50, HasMagic=true},
                Build = {Unlocked={}, Mastery={}, SkillSlots={[1]='Evolution',[2]='AdventurerStrike'}, MagicSlots={[1]='ArcBolt',[2]='EmberBurst'}, DefierProgress=0, DefierOfFate=false, EvolutionStage=1, RaceProgress={Human={Mastery=0,Level=1}}, ClassProgress={Adventurer={Mastery=0,Level=1}}},
                Attributes = {},
                Inventory = {},
                Quests = {},
                Titles = {},
                Legacy = {Score=0, Choices={}},
                Relationships = {},
                PlayerChronicle = {},
                NPCMemory = {},
                Guild = {Id='', Name='', Tag='', Role='', JoinedAt=0},
                Social = {Nation='VerdantReign', BlockedUserIds={}, MutedUserIds={}, Reports={}},
                Kingdom = {CurrentId='VerdantReign', Reputations={}, PoliticalHistory={}, FutureLoyalty='', FutureGuildAffiliation=''},
                Bosses = {DailyRewardDates={}, Clears={}, FirstClears={}, History={}},
                Dungeons = {Entered=0, Completions=0, HighestRankIndex=0, HighestRank='', FirstClears={}, BossClears={}, History={}},
            }
        end
    end

    -- Assistant-command requires use their own module context, so initialize the same
    -- authoritative dependency graph here before assertions. Production Bootstrap remains unchanged.
    dataService:Start()
    if playerAvailable and not dataService:GetProfile(player) then dataService:LoadPlayer(player) end
    progressionService:Start(dataService)
    questService:Start(dataService)
    characterService:Start(dataService, stateService, progressionService)
    combatService:Start(stateService, characterService, nil)
    dungeonService:Start(dataService, enemyService)
    enemyService:Start(stateService, combatService, progressionService, questService, dungeonService, guildService)
    combatService._enemyService = enemyService
    worldService:Start(dataService, combatService, enemyService, questService)
    guildService:Start(dataService)
    rulerService:Start(dataService, worldService, guildService)
    worldBossService:Start(dataService, worldService, rulerService, combatService)
    combatService._worldBossService = worldBossService
    dungeonService:Configure(worldBossService, worldService)

    local services = {
        PlayerDataService = dataService,
        DungeonService = dungeonService,
        WorldBossService = worldBossService,
        WorldService = worldService,
        Player = player,
        PlayerAvailable = playerAvailable,
    }

    local totalPass, totalFail = 0, 0
    local allErrors = {}
    local results = {}

    for _, entry in ipairs(testModules) do
        -- Apply filter
        if filter and filter ~= '' and not entry.Name:lower():find(filter:lower()) then
            continue
        end

        local ok, p, f, e
        if entry.Module.Run then
            -- DungeonConfig doesn't need services, others do
            if entry.Name == 'DungeonConfig' then
                ok, p, f, e = pcall(function() return entry.Module.Run() end)
            else
                ok, p, f, e = pcall(function() return entry.Module.Run(services) end)
            end
        else
            ok = false
            p, f, e = 0, 1, {'No Run function'}
        end

        if not ok then
            -- pcall failed; p is the error message
            p, f, e = 0, 1, {tostring(p)}
        end

        totalPass += p
        totalFail += f
        if e and #e > 0 then
            for _, err in ipairs(e) do
                table.insert(allErrors, '['..entry.Name..'] '..err)
            end
        end

        table.insert(results, {
            Area = entry.Name,
            Passed = p,
            Failed = f,
        })

        -- Check timeout
        if os.clock() - startTime > timeout then
            warn('[UnitTest] Timeout exceeded after '..entry.Name)
            break
        end
    end

    -- Print results
    print('========================================')
    print('  PHASE 10 DUNGEON UNIT TEST RESULTS')
    print('========================================')
    for _, r in ipairs(results) do
        local status = r.Failed == 0 and 'PASS' or 'FAIL'
        print(string.format('  [%s] %s: %d passed, %d failed', status, r.Area, r.Passed, r.Failed))
    end
    print('----------------------------------------')
    if #allErrors > 0 then
        print('  ERRORS:')
        for _, err in ipairs(allErrors) do
            print('    '..err)
        end
    end
    print('----------------------------------------')
    local elapsed = os.clock() - startTime
    print(string.format('  TOTAL: %d passed, %d failed, %.2fs elapsed', totalPass, totalFail, elapsed))
    print('========================================')

    -- Check if real 2+ clients were possible
    local realPlayerCount = #Players:GetPlayers()
    print(string.format('  CLIENTS: %d real player(s) in server', realPlayerCount))
    print(string.format('  MULTI-CLIENT TEST: %s', realPlayerCount >= 2 and 'POSSIBLE' or 'NOT POSSIBLE (need 2+ clients)'))
    print('========================================')

    return {
        TotalPassed = totalPass,
        TotalFailed = totalFail,
        Errors = allErrors,
        Elapsed = elapsed,
        PlayerCount = realPlayerCount,
        Results = results,
    }
end

return RunUnitTest