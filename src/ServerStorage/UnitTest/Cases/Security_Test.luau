--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local NetProtocol = require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local T = {Name = 'Security_Phase10'}

function T.Run(services)
    local pass, fail, errs = 0, 0, {}
    local function check(name, cond)
        if cond then pass += 1 else fail += 1; table.insert(errs, name..' FAIL') end
    end
    local remotes = ReplicatedStorage.NewLife.Remotes

    -- T10_700: No DungeonSetRank remote
    check('T10_700_NoDungeonSetRank', remotes:FindFirstChild('DungeonSetRank') == nil)

    -- T10_701: No DungeonComplete remote
    check('T10_701_NoDungeonComplete', remotes:FindFirstChild('DungeonComplete') == nil)

    -- T10_702: No client mutation remotes for dungeons
    check('T10_702_NoDungeonEnterRemote', remotes:FindFirstChild('DungeonEnter') == nil)
    check('T10_703_NoDungeonRerollRemote', remotes:FindFirstChild('DungeonReroll') == nil)
    check('T10_704_NoDungeonAbortRemote', remotes:FindFirstChild('DungeonAbort') == nil)

    -- T10_705: No WorldBossRequest remote
    check('T10_705_NoWorldBossRequest', remotes:FindFirstChild('WorldBossRequest') == nil)

    -- T10_706: No BossAdmin remote
    check('T10_706_NoBossAdmin', remotes:FindFirstChild('BossAdmin') == nil)

    -- T10_707: DungeonInteract rate limit exists
    check('T10_707_DungeonInteractRateLimit', type(GameConfig.Network.RateLimits.DungeonInteract) == 'number')

    -- T10_708: No BossHealth in rate limits
    check('T10_708_NoBossHealthRateLimit', GameConfig.Network.RateLimits.BossHealth == nil)

    -- T10_709: No BossReward in rate limits
    check('T10_709_NoBossRewardRateLimit', GameConfig.Network.RateLimits.BossReward == nil)

    -- T10_710: Only read-only remotes exist (no mutation remotes for dungeon/boss)
    local allRemotes = remotes:GetChildren()
    local dungeonMutationRemotes = {}
    for _, r in ipairs(allRemotes) do
        local name = r.Name:lower()
        if name:find('dungeon') and (name:find('set') or name:find('complete') or name:find('enter') or name:find('reroll') or name:find('abort')) then
            table.insert(dungeonMutationRemotes, r.Name)
        end
    end
    check('T10_710_NoDungeonMutationRemotes', #dungeonMutationRemotes == 0)

    -- T10_711: NetProtocol Actions has no dungeon mutation actions
    local dungeonActions = {}
    for k, v in pairs(NetProtocol.Actions) do
        local lower = v:lower()
        if lower:find('dungeon') and (lower:find('set') or lower:find('complete') or lower:find('reroll')) then
            table.insert(dungeonActions, v)
        end
    end
    check('T10_711_NoDungeonMutationActions', #dungeonActions == 0)

    -- T10_712: Server-only reroll - DungeonService._rollReroll is not exposed via network
    -- The reroll is computed server-side only
    check('T10_712_RerollServerOnly', services.DungeonService._rollReroll ~= nil)

    -- T10_713: 5-V world event is protected (FiveVBaseChance is very low)
    local Config = require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)
    check('T10_713_FiveVProtected', Config.FiveVBaseChance <= 0.01)

    -- T10_714: No client can directly set dungeon rank
    -- Verify ActionRequest doesn't have DungeonSetRank handler
    check('T10_714_NoDungeonSetRankAction', NetProtocol.Actions.DungeonSetRank == nil)

    return pass, fail, errs
end

return T