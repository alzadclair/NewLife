--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local Config = require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)

local T = {Name = 'PlayerDataService_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end
    local data = services.PlayerDataService
    local player = services.Player
    local profile = data:GetProfile(player)

    -- T10_200: SchemaVersion is 10
    check('T10_200_SchemaVersion10', profile ~= nil and profile.SchemaVersion == 10)

    if not profile then
        -- Cannot continue without profile
        for _, n in {'T10_201','T10_202','T10_203','T10_204','T10_205','T10_206','T10_207','T10_208','T10_209','T10_210','T10_211','T10_212','T10_213'} do
            fail += 1; table.insert(errs, n..' FAIL (no profile)')
        end
        return pass, fail, errs
    end

    -- T10_201: Dungeons table exists
    check('T10_201_DungeonsTableExists', type(profile.Dungeons) == 'table')

    -- T10_202: Dungeons has required durable fields
    local d = profile.Dungeons
    check('T10_202_DungeonsFields',
        type(d.Entered) == 'number' and
        type(d.Completions) == 'number' and
        type(d.HighestRankIndex) == 'number' and
        type(d.HighestRank) == 'string' and
        type(d.FirstClears) == 'table' and
        type(d.BossClears) == 'table' and
        type(d.History) == 'table'
    )

    -- T10_203: Dungeons does NOT have transient fields (Rooms, Seed)
    check('T10_203_NoTransientSave', d.Rooms == nil and d.Seed == nil)

    -- T10_204: RecordDungeonEnter increments Entered
    local before = d.Entered
    local enterOk = data:RecordDungeonEnter(player)
    check('T10_204_RecordEnter', enterOk == true and d.Entered == before + 1)

    -- T10_205: RecordDungeonClear records completion
    local compBefore = d.Completions
    local first, newHigh = data:RecordDungeonClear(player, 'DynamicDungeon', 'S', 6, 'EchoSentinel', 'D10-test-001', 12345)
    check('T10_205_RecordClear', d.Completions == compBefore + 1 and type(first) == 'boolean')

    -- T10_206: RecordDungeonClear updates HighestRankIndex
    data:RecordDungeonClear(player, 'DynamicDungeon', '5-V', 33, 'EchoSentinel', 'D10-test-002', 12346)
    check('T10_206_HighestRankUpdated', d.HighestRankIndex == 33 and d.HighestRank == '5-V')

    -- T10_207: History is capped at 30 (MaxHistory)
    for i = 1, 35 do
        data:RecordDungeonClear(player, 'DynamicDungeon', 'F', 1, 'EchoSentinel', 'D10-cap-'..i, 20000+i)
    end
    check('T10_207_HistoryCapped30', #d.History <= 30)

    -- T10_208: GetDungeonProgress returns table
    local prog = data:GetDungeonProgress(player)
    check('T10_208_GetDungeonProgress', type(prog) == 'table' and prog.Entered ~= nil)

    -- T10_209: FirstClears key format
    data:RecordDungeonClear(player, 'TestDungeon', 'A', 5, 'TestBoss', 'D10-fc-001', 99999)
    check('T10_209_FirstClearKey', d.FirstClears['TestDungeon:A'] == true)

    -- T10_210: BossClears increments
    local bcBefore = d.BossClears['TestBoss'] or 0
    data:RecordDungeonClear(player, 'TestDungeon2', 'A', 5, 'TestBoss', 'D10-bc-001', 99998)
    check('T10_210_BossClearsIncrement', (d.BossClears['TestBoss'] or 0) >= bcBefore + 1)

    -- T10_211: Schema 10 durable-only: no active instance state in profile
    check('T10_211_NoActiveState', d.ActiveInstances == nil and d.CurrentRoom == nil and d.CurrentSeed == nil)

    -- T10_212: GameConfig SchemaVersion matches
    check('T10_212_GameConfigSchema10', GameConfig.SchemaVersion == 10)

    -- T10_213: GetSnapshot includes Dungeons
    local snap = data:GetSnapshot(player)
    check('T10_213_SnapshotIncludesDungeons', snap ~= nil and type(snap.Dungeons) == 'table')

    -- T10_214: Individual rewards - AddXP and AddGold work for dungeon rewards
    local goldBefore = profile.Progression.Gold
    data:AddGold(player, 100)
    check('T10_214_IndividualGoldReward', profile.Progression.Gold >= goldBefore + 100)

    -- T10_215: Individual chronicle entries for dungeon events
    local chronBefore = #profile.PlayerChronicle
    data:AddPlayerChronicle(player, 'Test dungeon chronicle entry', 'DungeonTest')
    check('T10_215_IndividualChronicle', #profile.PlayerChronicle > chronBefore)

    return pass, fail, errs
end

return T