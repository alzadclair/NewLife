--!strict
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local DataStoreService=game:GetService('DataStoreService')
local RunService=game:GetService('RunService')
local GameConfig=require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local Content=require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local Service={_data=nil,_world=nil,_guild=nil,_state=nil,_debugCandidates=nil}

local function clone(v) if type(v)~='table' then return v end local o={} for k,x in pairs(v) do o[k]=clone(x) end return o end
local function defaultState()
    local kingdoms={}
    for _,id in ipairs(GameConfig.Kingdoms.OrderedIds) do
        local d=Content.Kingdoms[id]
        kingdoms[id]={KingdomId=id,Treasury=d.Treasury or 0,DefenseLevel=d.DefenseLevel or 1,Prosperity=d.Prosperity or 0,Reputation=d.Reputation or 0,Population=clone(d.Population or {}),RulerId=0,RulerName='Vacant',HistoricalState=clone(d.HistoricalState or {}),History={}}
    end
    return {SchemaVersion=1,SovereignId=0,SovereignName='Vacant',SovereignSnapshot=nil,Kingdoms=kingdoms,Rankings={Power={},Guild={},PvP={},BossKills={},Assassin={},Exploration={},Wealth={},Arena={}},UpdatedAt=os.time()}
end
local function normalize(s)
    if type(s)~='table' then s=defaultState() end
    local d=defaultState()
    s.Kingdoms=type(s.Kingdoms)=='table' and s.Kingdoms or {}
    for _,id in ipairs(GameConfig.Kingdoms.OrderedIds) do
        local k=type(s.Kingdoms[id])=='table' and s.Kingdoms[id] or d.Kingdoms[id]
        k.KingdomId=id;k.Treasury=math.max(0,math.floor(tonumber(k.Treasury) or 0));k.DefenseLevel=math.clamp(math.floor(tonumber(k.DefenseLevel) or 1),1,GameConfig.WorldPower.MaxDefenseLevel)
        k.Prosperity=tonumber(k.Prosperity) or d.Kingdoms[id].Prosperity;k.Reputation=tonumber(k.Reputation) or 0;k.Population=type(k.Population)=='table' and k.Population or clone(d.Kingdoms[id].Population)
        k.RulerId=math.floor(tonumber(k.RulerId) or 0);k.RulerName=type(k.RulerName)=='string' and k.RulerName or 'Vacant';k.HistoricalState=type(k.HistoricalState)=='table' and k.HistoricalState or {};k.History=type(k.History)=='table' and k.History or {};s.Kingdoms[id]=k
    end
    s.Rankings=type(s.Rankings)=='table' and s.Rankings or d.Rankings;s.SovereignId=math.floor(tonumber(s.SovereignId) or 0);s.SovereignName=type(s.SovereignName)=='string' and s.SovereignName or 'Vacant';return s
end
function Service:_save()
    self._state.UpdatedAt=os.time()
    if RunService:IsStudio() then return true end
    local ok=pcall(function() DataStoreService:GetDataStore(GameConfig.WorldPower.DataStoreName):SetAsync('WorldState',self._state) end);return ok
end
function Service:_announce(text,category)
    if self._world then self._world:BroadcastAnnouncement(text);self._world:AddWorldChronicle(text,category) end
end
function Service:_candidates()
    if RunService:IsStudio() and self._debugCandidates then return clone(self._debugCandidates) end
    local out={}
    for _,p in ipairs(Players:GetPlayers()) do local prof=self._data:GetProfile(p);if prof then table.insert(out,{UserId=p.UserId,Name=p.Name,Power=prof.Progression.PowerRating or 0,Guild=tonumber(p:GetAttribute('GuildWorldRanking')) or 0,PvP=tonumber(prof.Progression.PvP) or 0,BossKills=tonumber(prof.Progression.BossKills) or 0,Assassin=tonumber(prof.Progression.Assassin) or 0,Exploration=tonumber(prof.Progression.Exploration) or 0,Wealth=prof.Progression.Gold or 0,Arena=tonumber(prof.Progression.Arena) or 0}) end end
    return out
end
function Service:RecomputeRankings()
    local candidates=self:_candidates()
    for _,cat in ipairs(GameConfig.Rankings.Categories) do
        local list=clone(candidates);table.sort(list,function(a,b) local av=tonumber(a[cat]) or 0;local bv=tonumber(b[cat]) or 0;if av==bv then return a.UserId<b.UserId end return av>bv end)
        local snap={};for i,x in ipairs(list) do snap[i]={Rank=i,UserId=x.UserId,Name=x.Name,Score=tonumber(x[cat]) or 0} end;self._state.Rankings[cat]=snap
    end
    local power=self._state.Rankings.Power or {};local oldS=self._state.SovereignId;local top=power[1]
    self._state.SovereignId=top and top.UserId or 0;self._state.SovereignName=top and top.Name or 'Vacant';self._state.SovereignSnapshot=top and clone(top) or nil
    if oldS~=self._state.SovereignId and top then self:_announce('New World Sovereign: '..top.Name,'Politics') end
    for index,id in ipairs(GameConfig.Kingdoms.OrderedIds) do
        local rank=index+1;local entry=power[rank];local k=self._state.Kingdoms[id];local oldId=k.RulerId;k.RulerId=entry and entry.UserId or 0;k.RulerName=entry and entry.Name or 'Vacant'
        if oldId~=k.RulerId and entry then table.insert(k.History,{Timestamp=os.time(),Type='RulerChange',UserId=entry.UserId,Name=entry.Name,Rank=rank});self:_announce(string.format('%s has a new ruler: %s',Content.Kingdoms[id].Name,entry.Name),'Politics') end
    end
    for _,p in ipairs(Players:GetPlayers()) do self:ApplyPlayer(p) end;self:_save();return self:GetSnapshot()
end
function Service:ApplyPlayer(player)
    local kingdomId=player:GetAttribute('KingdomId') or GameConfig.Kingdoms.DefaultKingdom;local k=self._state.Kingdoms[kingdomId];local rank=0
    for i,e in ipairs(self._state.Rankings.Power or {}) do if e.UserId==player.UserId then rank=i break end end
    local role='Citizen';if self._state.SovereignId==player.UserId then role='World Sovereign' elseif k and k.RulerId==player.UserId then role='Ruler' end
    player:SetAttribute('WorldRank',rank);player:SetAttribute('WorldSovereignName',self._state.SovereignName);player:SetAttribute('KingdomRulerName',k and k.RulerName or 'Vacant');player:SetAttribute('PoliticalRole',role)
end
function Service:GetSnapshot()
    return {SovereignId=self._state.SovereignId,SovereignName=self._state.SovereignName,SovereignSnapshot=clone(self._state.SovereignSnapshot),Kingdoms=clone(self._state.Kingdoms),Rankings=clone(self._state.Rankings),UpdatedAt=self._state.UpdatedAt}
end
function Service:InvestDefense(player)
    local kingdomId=player:GetAttribute('KingdomId') or GameConfig.Kingdoms.DefaultKingdom;local k=self._state.Kingdoms[kingdomId];if not k then return false,'InvalidKingdom' end
    if k.RulerId~=player.UserId then return false,'NotRuler' end
    local cost=GameConfig.WorldPower.InvestDefenseCost;if k.Treasury<cost then return false,'InsufficientTreasury' end
    k.Treasury-=cost;k.DefenseLevel=math.min(GameConfig.WorldPower.MaxDefenseLevel,k.DefenseLevel+GameConfig.WorldPower.InvestDefenseGain);table.insert(k.History,{Timestamp=os.time(),Type='InvestDefense',ActorId=player.UserId,Cost=cost,DefenseLevel=k.DefenseLevel})
    if cost>=GameConfig.WorldPower.MajorInvestmentThreshold then self:_announce(string.format('%s invested in defense; Defense Level is now %d',Content.Kingdoms[kingdomId].Name,k.DefenseLevel),'Politics') end
    self:_save();return true,{KingdomId=kingdomId,Treasury=k.Treasury,DefenseLevel=k.DefenseLevel,Cost=cost}
end
function Service:DebugSetCandidates(list) if not RunService:IsStudio() then return false end self._debugCandidates=clone(list);return true end
function Service:DebugCreditTreasury(kingdomId,amount) if not RunService:IsStudio() then return false end local k=self._state.Kingdoms[kingdomId];if not k then return false end;k.Treasury+=math.max(0,math.floor(amount));return true end
function Service:DebugRunTests(player)
    if not RunService:IsStudio() then return {Error='StudioOnly'} end
    local results={}
    local profile=self._data:GetProfile(player)
    results.T800_KingdomDefinitions=(#GameConfig.Kingdoms.OrderedIds==5 and Content.Kingdoms.FrostPeak~=nil)
    results.T801_Schema8=(profile~=nil and profile.SchemaVersion==8 and type(profile.Kingdom)=='table')
    local okMem=self._data:SetKingdomMembership(player,'VerdantReign','T802')
    results.T802_Membership=(okMem==true and player:GetAttribute('KingdomId')=='VerdantReign')
    local okRep,rep=self._data:AddKingdomReputation(player,'VerdantReign',25)
    results.T803_Reputation=(okRep==true and player:GetAttribute('KingdomReputation')==rep)
    local uid=player.UserId
    local candidates={
        {UserId=990001,Name='SovereignTest',Power=6000,Guild=60,PvP=6,BossKills=6,Assassin=6,Exploration=6,Wealth=6000,Arena=6},
        {UserId=uid,Name=player.Name,Power=5000,Guild=50,PvP=5,BossKills=5,Assassin=5,Exploration=5,Wealth=5000,Arena=5},
        {UserId=990003,Name='Ruler3',Power=4000,Guild=40,PvP=4,BossKills=4,Assassin=4,Exploration=4,Wealth=4000,Arena=4},
        {UserId=990004,Name='Ruler4',Power=3000,Guild=30,PvP=3,BossKills=3,Assassin=3,Exploration=3,Wealth=3000,Arena=3},
        {UserId=990005,Name='Ruler5',Power=2000,Guild=20,PvP=2,BossKills=2,Assassin=2,Exploration=2,Wealth=2000,Arena=2},
        {UserId=990006,Name='Ruler6',Power=1000,Guild=10,PvP=1,BossKills=1,Assassin=1,Exploration=1,Wealth=1000,Arena=1},
    }
    self:DebugSetCandidates(candidates)
    local snap=self:RecomputeRankings()
    results.T804_RankingCalc=(snap.Rankings.Power[1].Score==6000 and snap.Rankings.Wealth[2].UserId==uid)
    results.T805_Sovereign=(snap.SovereignId==990001 and snap.SovereignName=='SovereignTest')
    results.T806_Rulers=(snap.Kingdoms.VerdantReign.RulerId==uid and snap.Kingdoms.FrostPeak.RulerId==990006)
    results.T807_DistinctSovereign=(snap.SovereignId~=snap.Kingdoms.VerdantReign.RulerId)
    local beforeChron=#self._world:GetWorldChronicle()
    self:DebugCreditTreasury('VerdantReign',300)
    local before=self:GetSnapshot().Kingdoms.VerdantReign
    local okInv=self:InvestDefense(player)
    local after=self:GetSnapshot().Kingdoms.VerdantReign
    results.T808_InvestDefense=(okInv==true and after.Treasury==before.Treasury-GameConfig.WorldPower.InvestDefenseCost and after.DefenseLevel==before.DefenseLevel+GameConfig.WorldPower.InvestDefenseGain)
    results.T809_Chronicle=(#self._world:GetWorldChronicle()>beforeChron)
    self._data:SetKingdomMembership(player,'IronHold','T810')
    local ironBefore=self:GetSnapshot().Kingdoms.IronHold
    local denied,why=self:InvestDefense(player)
    local ironAfter=self:GetSnapshot().Kingdoms.IronHold
    results.T810_NonRulerBlocked=(denied==false and why=='NotRuler' and ironBefore.Treasury==ironAfter.Treasury and ironBefore.DefenseLevel==ironAfter.DefenseLevel)
    candidates[1].Power=4900;candidates[2].Power=7000;self:DebugSetCandidates(candidates)
    local snap2=self:RecomputeRankings()
    results.T811_DynamicOffice=(snap2.SovereignId==uid and snap2.Kingdoms.VerdantReign.RulerId==990001)
    results.T812_HUDAttrs=(player:GetAttribute('WorldRank')==1 and player:GetAttribute('WorldSovereignName')==player.Name and type(player:GetAttribute('PoliticalRole'))=='string')
    results.T813_Categories=true
    for _,cat in ipairs(GameConfig.Rankings.Categories) do if type(snap2.Rankings[cat])~='table' then results.T813_Categories=false end end
    results.T814_PlayerHistory=(profile and #profile.Kingdom.PoliticalHistory>=1)
    results.T815_WorldStateSeparate=(self._state~=profile and type(self._state.Kingdoms)=='table')
    -- prepare deterministic ruler state for client-network validation
    self._data:SetKingdomMembership(player,'VerdantReign','T816')
    candidates[1].Power=8000;candidates[2].Power=7000;self:DebugSetCandidates(candidates);self:RecomputeRankings();self:DebugCreditTreasury('VerdantReign',500)
    results.NetworkBefore=self:GetSnapshot().Kingdoms.VerdantReign
    return results
end

function Service:Start(data,world,guild)
    self._data=data;self._world=world;self._guild=guild;local loaded=nil
    if not RunService:IsStudio() then pcall(function() loaded=DataStoreService:GetDataStore(GameConfig.WorldPower.DataStoreName):GetAsync('WorldState') end) end
    self._state=normalize(loaded);Players.PlayerAdded:Connect(function(p) task.defer(function() self:RecomputeRankings();self:ApplyPlayer(p) end) end);Players.PlayerRemoving:Connect(function() task.defer(function() self:RecomputeRankings() end) end)
    task.defer(function() self:RecomputeRankings() end)
    if RunService:IsStudio() then
        local bridge=game:GetService('ServerScriptService'):FindFirstChild('Phase8TestBridge') or Instance.new('BindableFunction')
        bridge.Name='Phase8TestBridge';bridge.Parent=game:GetService('ServerScriptService')
        bridge.OnInvoke=function(command,player)
            if command=='Run' then return self:DebugRunTests(player or Players:GetPlayers()[1]) end
            if command=='Snapshot' then return self:GetSnapshot() end
            return nil
        end
    end
end
function Service:CreditTreasury(kingdomId, amount, transactionId)
    if type(kingdomId) ~= 'string' or type(amount) ~= 'number' or amount <= 0 or math.floor(amount) ~= amount then
        return false, 'InvalidAmount'
    end
    local state = self._state or self._worldState
    local kingdoms = state and state.Kingdoms
    local kingdom = kingdoms and kingdoms[kingdomId]
    if not kingdom then return false, 'InvalidKingdom' end
    kingdom.Treasury = math.max(0, math.floor(tonumber(kingdom.Treasury) or 0)) + amount
    kingdom.TreasuryHistory = type(kingdom.TreasuryHistory) == 'table' and kingdom.TreasuryHistory or {}
    table.insert(kingdom.TreasuryHistory, {At = os.time(), Amount = amount, Source = 'EconomyTax', TransactionId = transactionId or ''})
    while #kingdom.TreasuryHistory > 30 do table.remove(kingdom.TreasuryHistory, 1) end
    if self._save then self:_save() end
    return true, kingdom.Treasury
end

return Service
