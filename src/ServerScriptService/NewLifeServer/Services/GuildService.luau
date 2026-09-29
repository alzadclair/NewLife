--!strict
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local DataStoreService = game:GetService('DataStoreService')
local HttpService = game:GetService('HttpService')
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local NetProtocol = require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local Service = {
    _started=false, _data=nil, _store=nil, _nameStore=nil,
    _guilds={} :: {[string]: any}, _nameToId={} :: {[string]: string}, _invites={} :: {[number]: any},
}

local function normalizedName(name: string): string
    return string.lower((string.gsub(name, '^%s*(.-)%s*$', '%1')))
end

local function validName(name: any): boolean
    return type(name)=='string' and #name>=GameConfig.Guilds.MinNameLength and #name<=GameConfig.Guilds.MaxNameLength and string.match(name, '^[%w%s%-_]+$')~=nil
end

local function validTag(tag: any): boolean
    return type(tag)=='string' and #tag>=1 and #tag<=GameConfig.Guilds.MaxTagLength and string.match(tag, '^[%w]+$')~=nil
end

local function rankForXP(xp: number): (number, string)
    local sequence=GameConfig.Guilds.RankSequence
    local index=math.clamp(math.floor(math.max(0,xp)/GameConfig.Guilds.GuildRankXPPerStep)+1,1,#sequence)
    return index, sequence[index]
end

function Service:_socialRemote(): RemoteEvent?
    local r=ReplicatedStorage.NewLife.Remotes:FindFirstChild(NetProtocol.Remotes.SocialUpdate)
    return r and r:IsA('RemoteEvent') and r or nil
end

function Service:_emit(player: Player, kind: string, payload: any)
    local r=self:_socialRemote(); if r then r:FireClient(player,kind,payload) end
end

function Service:_snapshot(guild)
    local members={}
    for userId,member in pairs(guild.Members) do
        table.insert(members,{UserId=tonumber(userId) or 0,Name=member.Name,Role=member.Role,JoinedAt=member.JoinedAt})
    end
    table.sort(members,function(a,b) return a.UserId<b.UserId end)
    return {Id=guild.Id,Name=guild.Name,Tag=guild.Tag,OwnerUserId=guild.OwnerUserId,Members=members,Reputation=guild.Reputation,ProgressionXP=guild.ProgressionXP,GuildRank=guild.GuildRank,GuildRankIndex=guild.GuildRankIndex,GuildRankHistory=guild.GuildRankHistory or {},WorldGuildRanking=guild.WorldGuildRanking,CompetitiveScore=guild.CompetitiveScore,CreatedAt=guild.CreatedAt}
end

function Service:_syncOnline(guild)
    local snap=self:_snapshot(guild)
    for userId,member in pairs(guild.Members) do
        local player=Players:GetPlayerByUserId(tonumber(userId) or 0)
        if player then
            self._data:SetGuildMembership(player,guild.Id,guild.Name,guild.Tag,member.Role,member.JoinedAt)
            player:SetAttribute('GuildRank',guild.GuildRank)
            player:SetAttribute('WorldGuildRanking',guild.WorldGuildRanking or 0)
            self:_emit(player,'GuildUpdate',snap)
        end
    end
end

function Service:_saveGuild(guild)
    self._guilds[guild.Id]=guild
    self._nameToId[normalizedName(guild.Name)]=guild.Id
    if RunService:IsStudio() or not self._store then return true end
    local ok=pcall(function() self._store:SetAsync('guild_'..guild.Id,guild) end)
    return ok
end

function Service:_loadGuild(guildId: string)
    if guildId=='' then return nil end
    if self._guilds[guildId] then return self._guilds[guildId] end
    if RunService:IsStudio() or not self._store then return nil end
    local ok,value=pcall(function() return self._store:GetAsync('guild_'..guildId) end)
    if ok and type(value)=='table' then
        self._guilds[guildId]=value
        self._nameToId[normalizedName(value.Name)]=guildId
        return value
    end
    return nil
end

function Service:GetGuildForPlayer(player: Player)
    local profile=self._data and self._data:GetProfile(player)
    local guildId=profile and profile.Guild and profile.Guild.Id or ''
    return self:_loadGuild(guildId)
end

function Service:GetOnlineGuildMembers(player: Player): {Player}
    local out={}
    local guild=self:GetGuildForPlayer(player)
    if not guild then return out end
    for userId,_ in pairs(guild.Members) do
        local p=Players:GetPlayerByUserId(tonumber(userId) or 0)
        if p then table.insert(out,p) end
    end
    return out
end

function Service:_hasPermission(player: Player,guild,permission: string): boolean
    local member=guild and guild.Members[tostring(player.UserId)]
    local role=member and GameConfig.Guilds.Roles[member.Role]
    return role~=nil and role[permission]==true
end
function Service:Create(player: Player,name: string,tag: string): (boolean,string)
    if not validName(name) then return false,'InvalidName' end
    if not validTag(tag) then return false,'InvalidTag' end
    local profile=self._data:GetProfile(player)
    if not profile then return false,'ProfileMissing' end
    if profile.Guild and profile.Guild.Id~='' then return false,'AlreadyInGuild' end
    name=string.gsub(name,'^%s*(.-)%s*$','%1')
    tag=string.upper(tag)
    local key=normalizedName(name)
    if self._nameToId[key] then return false,'NameTaken' end
    local id='G-'..string.sub(HttpService:GenerateGUID(false),1,16)
    if not RunService:IsStudio() and self._nameStore then
        local ok,result=pcall(function()
            return self._nameStore:UpdateAsync('name_'..key,function(old) return old or id end)
        end)
        if not ok or result~=id then return false,'NameTaken' end
    end
    local guild={Id=id,Name=name,Tag=tag,OwnerUserId=player.UserId,Members={},Reputation=0,ProgressionXP=0,GuildRankIndex=1,GuildRank=GameConfig.Guilds.RankSequence[1],GuildRankHistory={{Timestamp=os.time(),Rank=GameConfig.Guilds.RankSequence[1],XP=0}},WorldGuildRanking=nil,CompetitiveScore=0,CreatedAt=os.time()}
    guild.Members[tostring(player.UserId)]={Name=player.Name,Role='Owner',JoinedAt=os.time()}
    self:_saveGuild(guild)
    self._data:SetGuildMembership(player,id,name,tag,'Owner',guild.CreatedAt)
    player:SetAttribute('GuildRank',guild.GuildRank)
    player:SetAttribute('WorldGuildRanking',0)
    self:_emit(player,'GuildUpdate',self:_snapshot(guild))
    return true,'OK'
end
function Service:Invite(player: Player,targetUserId: number): (boolean,string)
    local guild=self:GetGuildForPlayer(player)
    if not guild then return false,'NotInGuild' end
    if not self:_hasPermission(player,guild,'Invite') then return false,'PermissionDenied' end
    local target=Players:GetPlayerByUserId(targetUserId)
    if not target or target==player then return false,'InvalidTarget' end
    local targetProfile=self._data:GetProfile(target)
    if not targetProfile then return false,'TargetProfileMissing' end
    if targetProfile.Guild and targetProfile.Guild.Id~='' then return false,'TargetAlreadyInGuild' end
    local count=0
    for _ in pairs(guild.Members) do count+=1 end
    if count>=GameConfig.Guilds.MaxMembers then return false,'GuildFull' end
    self._invites[targetUserId]={GuildId=guild.Id,InviterUserId=player.UserId,ExpiresAt=os.clock()+GameConfig.Guilds.InviteSeconds}
    self:_emit(target,'GuildInvite',{GuildId=guild.Id,GuildName=guild.Name,GuildTag=guild.Tag,InviterUserId=player.UserId,InviterName=player.Name,ExpiresIn=GameConfig.Guilds.InviteSeconds})
    return true,'OK'
end

function Service:RespondInvite(player: Player,accept: boolean): (boolean,string)
    local invite=self._invites[player.UserId]
    self._invites[player.UserId]=nil
    if not invite then return false,'NoInvite' end
    if os.clock()>invite.ExpiresAt then return false,'InviteExpired' end
    if not accept then return true,'Declined' end
    local profile=self._data:GetProfile(player)
    if not profile then return false,'ProfileMissing' end
    if profile.Guild and profile.Guild.Id~='' then return false,'AlreadyInGuild' end
    local guild=self:_loadGuild(invite.GuildId)
    if not guild then return false,'GuildMissing' end
    local count=0
    for _ in pairs(guild.Members) do count+=1 end
    if count>=GameConfig.Guilds.MaxMembers then return false,'GuildFull' end
    local joined=os.time()
    guild.Members[tostring(player.UserId)]={Name=player.Name,Role='Recruit',JoinedAt=joined}
    self:_saveGuild(guild)
    self._data:SetGuildMembership(player,guild.Id,guild.Name,guild.Tag,'Recruit',joined)
    self:_syncOnline(guild)
    return true,'OK'
end
function Service:Leave(player: Player): (boolean,string)
    local guild=self:GetGuildForPlayer(player)
    if not guild then return false,'NotInGuild' end
    local key=tostring(player.UserId)
    if guild.OwnerUserId==player.UserId then
        local count=0; for _ in pairs(guild.Members) do count+=1 end
        if count>1 then return false,'TransferOwnerRequired' end
        guild.Members[key]=nil
        self._guilds[guild.Id]=nil
        self._nameToId[normalizedName(guild.Name)]=nil
        self._data:ClearGuildMembership(player)
        player:SetAttribute('GuildRank','')
        player:SetAttribute('WorldGuildRanking',0)
        return true,'Disbanded'
    end
    guild.Members[key]=nil
    self:_saveGuild(guild)
    self._data:ClearGuildMembership(player)
    player:SetAttribute('GuildRank','')
    player:SetAttribute('WorldGuildRanking',0)
    self:_syncOnline(guild)
    return true,'OK'
end

function Service:Kick(player: Player,targetUserId: number): (boolean,string)
    local guild=self:GetGuildForPlayer(player)
    if not guild then return false,'NotInGuild' end
    if not self:_hasPermission(player,guild,'Kick') then return false,'PermissionDenied' end
    if targetUserId==guild.OwnerUserId then return false,'CannotKickOwner' end
    local key=tostring(targetUserId)
    if not guild.Members[key] then return false,'TargetNotMember' end
    guild.Members[key]=nil
    self:_saveGuild(guild)
    local target=Players:GetPlayerByUserId(targetUserId)
    if target then
        self._data:ClearGuildMembership(target)
        target:SetAttribute('GuildRank','')
        target:SetAttribute('WorldGuildRanking',0)
        self:_emit(target,'GuildRemoved',{GuildId=guild.Id})
    end
    self:_syncOnline(guild)
    return true,'OK'
end

function Service:SetRole(player: Player,targetUserId: number,roleName: string): (boolean,string)
    local guild=self:GetGuildForPlayer(player)
    if not guild then return false,'NotInGuild' end
    if not self:_hasPermission(player,guild,'SetRole') then return false,'PermissionDenied' end
    if roleName=='Owner' or not GameConfig.Guilds.Roles[roleName] then return false,'InvalidRole' end
    if targetUserId==guild.OwnerUserId then return false,'CannotChangeOwnerRole' end
    local member=guild.Members[tostring(targetUserId)]
    if not member then return false,'TargetNotMember' end
    member.Role=roleName
    self:_saveGuild(guild)
    self:_syncOnline(guild)
    return true,'OK'
end

function Service:TransferOwner(player: Player,targetUserId: number): (boolean,string)
    local guild=self:GetGuildForPlayer(player)
    if not guild then return false,'NotInGuild' end
    if guild.OwnerUserId~=player.UserId then return false,'OwnerRequired' end
    if targetUserId==player.UserId then return false,'AlreadyOwner' end
    local target=guild.Members[tostring(targetUserId)]
    if not target then return false,'TargetNotMember' end
    local current=guild.Members[tostring(player.UserId)]
    if current then current.Role='Officer' end
    target.Role='Owner'
    guild.OwnerUserId=targetUserId
    self:_saveGuild(guild)
    self:_syncOnline(guild)
    return true,'OK'
end
function Service:AddProgressionXP(player: Player, amount: number): (boolean,string)
    local guild=self:GetGuildForPlayer(player)
    if not guild then return false,'NotInGuild' end
    if type(amount)~='number' or amount<=0 then return false,'InvalidGuildXP' end
    guild.ProgressionXP=math.max(0,(guild.ProgressionXP or 0)+math.floor(amount))
    local oldRank=guild.GuildRank
    local index,rank=rankForXP(guild.ProgressionXP)
    guild.GuildRankIndex=index; guild.GuildRank=rank
    guild.GuildRankHistory=type(guild.GuildRankHistory)=='table' and guild.GuildRankHistory or {}
    if oldRank~=rank then table.insert(guild.GuildRankHistory,{Timestamp=os.time(),Rank=rank,XP=guild.ProgressionXP}) end
    self:_saveGuild(guild); self:_syncOnline(guild)
    return true,'OK'
end

function Service:Start(dataService)
    if self._started then return end
    self._started=true; self._data=dataService
    if not RunService:IsStudio() then
        local ok,s=pcall(function() return DataStoreService:GetDataStore('NewLife_GuildData_v1') end)
        if ok then self._store=s end
        local okNames,n=pcall(function() return DataStoreService:GetDataStore('NewLife_GuildNames_v1') end)
        if okNames then self._nameStore=n end
    end
    Players.PlayerAdded:Connect(function(player)
        task.defer(function()
            local profile=self._data:GetProfile(player)
            local guildId=profile and profile.Guild and profile.Guild.Id or ''
            local guild=self:_loadGuild(guildId)
            if guild and guild.Members[tostring(player.UserId)] then self:_syncOnline(guild) end
        end)
    end)
    Players.PlayerRemoving:Connect(function(player) self._invites[player.UserId]=nil end)
end
return Service
