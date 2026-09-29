--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Config = require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)

local T = {Name = 'WorldService_GuidingWind_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end
    local world = services.WorldService
    local player = services.Player
    local char = player.Character

    -- T10_400: Guiding Wind dungeon behavior - main objective only
    -- Set dungeon active attributes to simulate dungeon state
    player:SetAttribute('DungeonActive', true)
    player:SetAttribute('DungeonWindAllowed', true)
    player:SetAttribute('DungeonObjective', 'Defeat the dungeon boss')
    player:SetAttribute('DungeonObjectivePosition', Vector3.new(110, 3, 0))

    -- Trigger guiding wind
    local ok, err = pcall(function() world:TriggerGuidingWind(player) end)
    task.wait(0.1)

    -- Check wind points to dungeon objective
    local windTarget = char and char:GetAttribute('WindTargetName')
    local windBearing = char and char:GetAttribute('WindBearing')
    check('T10_400_WindDungeonObjective', windTarget == 'Defeat the dungeon boss')
    check('T10_401_WindBearingSet', type(windBearing) == 'string' and #windBearing > 0)

    -- T10_402: Windless modifier disables guiding wind
    player:SetAttribute('DungeonWindAllowed', false)
    pcall(function() world:TriggerGuidingWind(player) end)
    task.wait(0.1)

    local windTargetDisabled = char and char:GetAttribute('WindTargetName')
    local windBearingDisabled = char and char:GetAttribute('WindBearing')
    check('T10_402_WindlessDisablesWind', windTargetDisabled == 'Guiding Wind unavailable' and windBearingDisabled == 'Disabled')

    -- T10_403: When not in dungeon, wind returns to default
    player:SetAttribute('DungeonActive', false)
    player:SetAttribute('DungeonWindAllowed', true)
    pcall(function() world:TriggerGuidingWind(player) end)
    task.wait(0.1)

    local windTargetNormal = char and char:GetAttribute('WindTargetName')
    check('T10_403_WindNormalOutside', windTargetNormal ~= 'Guiding Wind unavailable')

    -- T10_404: Windless modifier config has DisableGuidingWind=true
    check('T10_404_WindlessConfig', Config.Modifiers.Windless.DisableGuidingWind == true)

    -- T10_405: Guiding wind only shows main objective (not modifiers)
    player:SetAttribute('DungeonActive', true)
    player:SetAttribute('DungeonWindAllowed', true)
    player:SetAttribute('DungeonObjective', 'Clear Combat room')
    pcall(function() world:TriggerGuidingWind(player) end)
    task.wait(0.1)
    local windTargetMain = char and char:GetAttribute('WindTargetName')
    check('T10_405_WindMainObjectiveOnly', windTargetMain == 'Clear Combat room')

    -- T10_406: GuidingWindUpdate remote exists
    local remotes = ReplicatedStorage.NewLife:FindFirstChild('Remotes')
    local windRemote = remotes and remotes:FindFirstChild('GuidingWindUpdate')
    check('T10_406_GuidingWindRemoteExists', windRemote ~= nil and windRemote:IsA('RemoteEvent'))

    -- Clean up
    player:SetAttribute('DungeonActive', false)
    player:SetAttribute('DungeonWindAllowed', true)

    return pass, fail, errs
end

return T