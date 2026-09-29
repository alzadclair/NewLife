--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local Config = require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)

local T = {Name = 'WorldBossService_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end
    local worldBoss = services.WorldBossService
    local player = services.Player

    -- T10_300: SpawnDungeonBoss uses ExternalRewards=true
    -- We verify by checking the method delegates to SpawnBoss with correct options
    -- SpawnDungeonBoss calls SpawnBoss with {Context='Dungeon', ExternalRewards=true, SuppressWorldAnnouncement=true}
    -- We can verify this by spawning and checking the encounter properties
    local arenaPos = Content.Dungeons.FirstDungeon.ArenaPosition
    local callbackFired = false
    local enc = worldBoss:SpawnDungeonBoss('EchoSentinel', arenaPos + Vector3.new(0,0,50), function()
        callbackFired = true
    end)
    check('T10_300_SpawnDungeonBoss', enc ~= nil)

    if enc then
        -- T10_301: ExternalRewards=true
        check('T10_301_ExternalRewards', enc.ExternalRewards == true)

        -- T10_302: SuppressWorldAnnouncement=true
        check('T10_302_SuppressAnnouncement', enc.SuppressWorldAnnouncement == true)

        -- T10_303: Context is Dungeon
        check('T10_303_ContextDungeon', enc.Context == 'Dungeon')

        -- T10_304: OnDefeated callback is set
        check('T10_304_OnDefeatedSet', enc.OnDefeated ~= nil)

        -- T10_305: Boss model has correct attributes
        check('T10_305_BossModelAttrs',
            enc.Model:GetAttribute('WorldBossId') == 'EchoSentinel' and
            enc.Model:GetAttribute('BossState') ~= nil
        )

        -- T10_306: Normal/Elite/Boss reuse - enemy definitions are shared
        -- Verify that dungeon enemy pool uses same Content.Enemies definitions
        local poolHasValidEnemies = true
        for _, pool in pairs(Config.EnemyPools) do
            for _, enemyId in ipairs(pool) do
                if not Content.Enemies[enemyId] then poolHasValidEnemies = false; break end
            end
        end
        check('T10_306_EnemyPoolReuse', poolHasValidEnemies)

        -- T10_307: Dungeon boss uses WorldBosses definition (reuse)
        check('T10_307_BossDefReuse', Content.WorldBosses.EchoSentinel ~= nil)

        -- T10_308: Boss has humanoid with health
        local hum = enc.Model:FindFirstChildOfClass('Humanoid')
        check('T10_308_BossHasHumanoid', hum ~= nil and hum.MaxHealth > 0)

        -- Clean up the spawned boss
        enc.Finished = true
        if enc.Model and enc.Model.Parent then enc.Model:Destroy() end
        worldBoss._encounters[enc.Model] = nil
        worldBoss._encounterById[enc.Id] = nil
    else
        -- If spawn failed, still count the checks as failures
        for _, n in {'T10_301_ExternalRewards','T10_302_SuppressAnnouncement','T10_303_ContextDungeon','T10_304_OnDefeatedSet','T10_305_BossModelAttrs','T10_306_EnemyPoolReuse','T10_307_BossDefReuse','T10_308_BossHasHumanoid'} do
            fail += 1; table.insert(errs, n..' FAIL (spawn nil)')
        end
    end

    -- T10_309: DungeonWarden and RiftCustodian boss definitions exist in Config
    check('T10_309_DungeonBossDefs', Config.Bosses.DungeonWarden ~= nil and Config.Bosses.RiftCustodian ~= nil)

    -- T10_310: Boss definitions have RewardTable='DynamicDungeon'
    check('T10_310_BossRewardTable', Config.Bosses.DungeonWarden.RewardTable == 'DynamicDungeon')

    return pass, fail, errs
end

return T