--!strict
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local HttpService = game:GetService('HttpService')
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local NetProtocol = require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local Service = {
    _started = false,
    _data = nil,
    _parties = {} :: {[string]: any},
    _playerParty = {} :: {[number]: string},
    _invites = {} :: {[number]: any},
}

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

function Service:_socialRemote(): RemoteEvent?
    local r = ReplicatedStorage.NewLife.Remotes:FindFirstChild(NetProtocol.Remotes.SocialUpdate)
    return r and r:IsA('RemoteEvent') and r or nil
end

function Service:_emit(player: Player, kind: string, payload: any)
    local remote = self:_socialRemote()
    if remote then remote:FireClient(player, kind, payload) end
end

function Service:_snapshot(party)
    local members = {}
    for userId, member in pairs(party.Members) do
        table.insert(members, {UserId=userId, Name=member.Name, IsLeader=userId==party.LeaderUserId})
    end
    table.sort(members, function(a, b) return a.UserId < b.UserId end)
    return {Id=party.Id, LeaderUserId=party.LeaderUserId, Members=members, MaxSize=GameConfig.Party.MaxSize, LootMode=GameConfig.Party.IndividualLoot and 'Individual' or 'Shared', CreatedAt=party.CreatedAt}
end

function Service:_syncParty(party)
    local snapshot = self:_snapshot(party)
    for userId, _ in pairs(party.Members) do
        local player = Players:GetPlayerByUserId(userId)
        if player then
            player:SetAttribute('PartyId', party.Id)
            player:SetAttribute('PartyLeader', userId == party.LeaderUserId)
            player:SetAttribute('PartySize', #snapshot.Members)
            self:_emit(player, 'PartyUpdate', snapshot)
        end
    end
end

function Service:_clearPlayer(player: Player)
    player:SetAttribute('PartyId', '')
    player:SetAttribute('PartyLeader', false)
    player:SetAttribute('PartySize', 0)
    self:_emit(player, 'PartyUpdate', nil)
end

function Service:GetPartyForPlayer(player: Player)
    local id = self._playerParty[player.UserId]
    return id and self._parties[id] or nil
end

function Service:GetPartyMembers(player: Player): {Player}
    local out = {}
    local party = self:GetPartyForPlayer(player)
    if not party then return out end
    for userId, _ in pairs(party.Members) do
        local p = Players:GetPlayerByUserId(userId)
        if p then table.insert(out, p) end
    end
    return out
end

function Service:Create(player: Player): (boolean, string)
    if self:GetPartyForPlayer(player) then return false, 'AlreadyInParty' end
    local id = 'P-' .. string.sub(HttpService:GenerateGUID(false), 1, 12)
    local party = {Id=id, LeaderUserId=player.UserId, Members={[player.UserId]={Name=player.Name, JoinedAt=os.time()}}, CreatedAt=os.time()}
    self._parties[id] = party
    self._playerParty[player.UserId] = id
    self:_syncParty(party)
    return true, 'OK'
end

function Service:Invite(player: Player, targetUserId: number): (boolean, string)
    local party = self:GetPartyForPlayer(player)
    if not party then return false, 'NotInParty' end
    if party.LeaderUserId ~= player.UserId then return false, 'LeaderRequired' end
    if targetUserId == player.UserId then return false, 'InvalidTarget' end
    local target = Players:GetPlayerByUserId(targetUserId)
    if not target then return false, 'TargetOffline' end
    if self:GetPartyForPlayer(target) then return false, 'TargetAlreadyInParty' end
    local count = 0
    for _ in pairs(party.Members) do count += 1 end
    if count >= GameConfig.Party.MaxSize then return false, 'PartyFull' end
    self._invites[targetUserId] = {PartyId=party.Id, InviterUserId=player.UserId, ExpiresAt=os.clock()+GameConfig.Party.InviteSeconds}
    self:_emit(target, 'PartyInvite', {PartyId=party.Id, InviterUserId=player.UserId, InviterName=player.Name, ExpiresIn=GameConfig.Party.InviteSeconds})
    return true, 'OK'
end

function Service:RespondInvite(player: Player, accept: boolean): (boolean, string)
    local invite = self._invites[player.UserId]
    self._invites[player.UserId] = nil
    if not invite then return false, 'NoInvite' end
    if os.clock() > invite.ExpiresAt then return false, 'InviteExpired' end
    if not accept then return true, 'Declined' end
    if self:GetPartyForPlayer(player) then return false, 'AlreadyInParty' end
    local party = self._parties[invite.PartyId]
    if not party then return false, 'PartyMissing' end
    local count = 0
    for _ in pairs(party.Members) do count += 1 end
    if count >= GameConfig.Party.MaxSize then return false, 'PartyFull' end
    party.Members[player.UserId] = {Name=player.Name, JoinedAt=os.time()}
    self._playerParty[player.UserId] = party.Id
    self:_syncParty(party)
    return true, 'OK'
end
function Service:TransferLeader(player: Player, targetUserId: number): (boolean, string)
    local party = self:GetPartyForPlayer(player)
    if not party then return false, 'NotInParty' end
    if party.LeaderUserId ~= player.UserId then return false, 'LeaderRequired' end
    if not party.Members[targetUserId] then return false, 'TargetNotMember' end
    if targetUserId == player.UserId then return false, 'AlreadyLeader' end
    party.LeaderUserId = targetUserId
    self:_syncParty(party)
    return true, 'OK'
end

function Service:Kick(player: Player, targetUserId: number): (boolean, string)
    local party = self:GetPartyForPlayer(player)
    if not party then return false, 'NotInParty' end
    if party.LeaderUserId ~= player.UserId then return false, 'LeaderRequired' end
    if targetUserId == player.UserId then return false, 'UseLeave' end
    if not party.Members[targetUserId] then return false, 'TargetNotMember' end
    party.Members[targetUserId] = nil
    self._playerParty[targetUserId] = nil
    local target = Players:GetPlayerByUserId(targetUserId)
    if target then self:_clearPlayer(target) end
    self:_syncParty(party)
    return true, 'OK'
end

function Service:Leave(player: Player): (boolean, string)
    local party = self:GetPartyForPlayer(player)
    if not party then return false, 'NotInParty' end
    party.Members[player.UserId] = nil
    self._playerParty[player.UserId] = nil
    self:_clearPlayer(player)
    local remaining = {}
    for userId, _ in pairs(party.Members) do table.insert(remaining, userId) end
    table.sort(remaining)
    if #remaining == 0 then
        self._parties[party.Id] = nil
        return true, 'Disbanded'
    end
    if party.LeaderUserId == player.UserId then party.LeaderUserId = remaining[1] end
    self:_syncParty(party)
    return true, 'OK'
end
function Service:ShareQuest(player: Player, questId: string): (boolean, string)
    if type(questId) ~= 'string' or questId == '' then return false, 'InvalidQuest' end
    local party = self:GetPartyForPlayer(player)
    if not party then return false, 'NotInParty' end
    local profile = self._data:GetProfile(player)
    local quest = profile and profile.Quests and profile.Quests[questId]
    if type(quest) ~= 'table' then return false, 'QuestMissing' end
    if quest.State == 'Completed' then return false, 'QuestAlreadyCompleted' end
    local shared = 0
    for userId, _ in pairs(party.Members) do
        if userId ~= player.UserId then
            local member = Players:GetPlayerByUserId(userId)
            local memberProfile = member and self._data:GetProfile(member)
            if member and memberProfile and memberProfile.Quests[questId] == nil then
                self._data:SetQuest(member, questId, copy(quest))
                shared += 1
                self:_emit(member, 'PartyQuestShared', {QuestId=questId, FromUserId=player.UserId})
            end
        end
    end
    return true, shared > 0 and 'Shared' or 'NoEligibleMembers'
end

function Service:Start(dataService)
    if self._started then return end
    self._started = true
    self._data = dataService
    Players.PlayerRemoving:Connect(function(player)
        self._invites[player.UserId] = nil
        if self:GetPartyForPlayer(player) then self:Leave(player) end
    end)
end
return Service
