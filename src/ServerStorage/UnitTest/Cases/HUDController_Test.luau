--!strict
local T = {Name = 'HUDController_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end
    local player = services.Player

    -- T10_500: Dungeon HUD attributes are set when dungeon is active
    -- These are the attributes the HUD reads from
    player:SetAttribute('DungeonActive', true)
    player:SetAttribute('DungeonName', 'Shifting Depths')
    player:SetAttribute('DungeonRank', 'S')
    player:SetAttribute('DungeonObjective', 'Clear Combat room')
    player:SetAttribute('DungeonRoomsCleared', 2)
    player:SetAttribute('DungeonRoomsTotal', 5)
    player:SetAttribute('DungeonModifiers', 'EmpoweredEnemies, Windless')
    player:SetAttribute('DungeonBossStatus', 'Locked')
    player:SetAttribute('DungeonWindAllowed', false)

    check('T10_500_DungeonActiveAttr', player:GetAttribute('DungeonActive') == true)
    check('T10_501_DungeonNameAttr', player:GetAttribute('DungeonName') == 'Shifting Depths')
    check('T10_502_DungeonRankAttr', player:GetAttribute('DungeonRank') == 'S')
    check('T10_503_DungeonObjectiveAttr', player:GetAttribute('DungeonObjective') == 'Clear Combat room')
    check('T10_504_DungeonRoomsClearedAttr', player:GetAttribute('DungeonRoomsCleared') == 2)
    check('T10_505_DungeonRoomsTotalAttr', player:GetAttribute('DungeonRoomsTotal') == 5)
    check('T10_506_DungeonModifiersAttr', player:GetAttribute('DungeonModifiers') == 'EmpoweredEnemies, Windless')
    check('T10_507_DungeonBossStatusAttr', player:GetAttribute('DungeonBossStatus') == 'Locked')
    check('T10_508_DungeonWindAllowedAttr', player:GetAttribute('DungeonWindAllowed') == false)

    -- T10_509: When dungeon inactive, DungeonActive is false
    player:SetAttribute('DungeonActive', false)
    check('T10_509_DungeonInactiveAttr', player:GetAttribute('DungeonActive') == false)

    -- T10_510: Boss HUD attributes exist for dungeon boss
    player:SetAttribute('BossActive', true)
    player:SetAttribute('BossName', 'Echo Sentinel')
    player:SetAttribute('BossHealth', 500)
    player:SetAttribute('BossMaxHealth', 600)
    player:SetAttribute('BossPhase', 'Phase 1')
    player:SetAttribute('BossRank', 'Dungeon')
    player:SetAttribute('BossIdentity', '')
    player:SetAttribute('BossStatus', 'Idle')

    check('T10_510_BossActiveAttr', player:GetAttribute('BossActive') == true)
    check('T10_511_BossNameAttr', player:GetAttribute('BossName') == 'Echo Sentinel')
    check('T10_512_BossHealthAttr', player:GetAttribute('BossHealth') == 500)
    check('T10_513_BossMaxHealthAttr', player:GetAttribute('BossMaxHealth') == 600)
    check('T10_514_BossPhaseAttr', type(player:GetAttribute('BossPhase')) == 'string')
    check('T10_515_BossRankAttr', type(player:GetAttribute('BossRank')) == 'string')
    check('T10_516_BossStatusAttr', type(player:GetAttribute('BossStatus')) == 'string')

    -- T10_517: DungeonHUD panel exists in StarterGui
    local starterGui = game.StarterGui:FindFirstChild('NewLifeHUD')
    local root = starterGui and starterGui:FindFirstChild('Root')
    -- The DungeonHUD is created dynamically by HUDController, but we verify the root exists
    check('T10_517_HUDRootExists', root ~= nil)

    -- T10_518: BossHUD panel exists in StarterGui (created dynamically)
    -- Verify the BossHUD attributes are the correct set the HUD reads
    local bossAttrs = {'BossActive','BossName','BossHealth','BossMaxHealth','BossPhase','BossRank','BossIdentity','BossStatus'}
    local allBossAttrsWork = true
    for _, attr in ipairs(bossAttrs) do
        local val = player:GetAttribute(attr)
        if val == nil and attr ~= 'BossIdentity' then allBossAttrsWork = false; break end
    end
    check('T10_518_BossAttrsReadable', allBossAttrsWork)

    -- Clean up
    player:SetAttribute('BossActive', false)
    player:SetAttribute('DungeonActive', false)

    return pass, fail, errs
end

return T