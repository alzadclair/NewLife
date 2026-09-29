--!strict
local T = {Name = 'Bootstrap_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end

    -- T10_600: DungeonService is wired with PlayerDataService and EnemyService
    local dungeon = services.DungeonService
    check('T10_600_DungeonDataWired', dungeon._data ~= nil)
    check('T10_601_DungeonEnemyWired', dungeon._enemy ~= nil)

    -- T10_602: DungeonService is configured with WorldBossService and WorldService
    check('T10_602_DungeonWorldBossWired', dungeon._worldBoss ~= nil)
    check('T10_603_DungeonWorldWired', dungeon._world ~= nil)

    -- T10_604: DungeonService has feedback remote
    check('T10_604_DungeonFeedbackWired', dungeon._feedback ~= nil)

    -- T10_605: WorldBossService is wired
    local worldBoss = services.WorldBossService
    check('T10_605_WorldBossDataWired', worldBoss._data ~= nil)
    check('T10_606_WorldBossWorldWired', worldBoss._world ~= nil)
    check('T10_607_WorldBossRulerWired', worldBoss._ruler ~= nil)
    check('T10_608_WorldBossCombatWired', worldBoss._combat ~= nil)

    -- T10_609: WorldService is wired
    local world = services.WorldService
    check('T10_609_WorldDataWired', world._data ~= nil)
    check('T10_610_WorldCombatWired', world._combat ~= nil)
    check('T10_611_WorldEnemyWired', world._enemy ~= nil)

    -- T10_612: PlayerDataService is started
    local data = services.PlayerDataService
    check('T10_612_DataServiceStarted', data._started == true)

    -- T10_613: WorldService is started
    check('T10_613_WorldServiceStarted', world._started == true)

    return pass, fail, errs
end

return T