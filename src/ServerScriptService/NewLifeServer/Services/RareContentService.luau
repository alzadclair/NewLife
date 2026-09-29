--!strict
local DataStoreService=game:GetService('DataStoreService')
local HttpService=game:GetService('HttpService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Config=require(ReplicatedStorage.NewLife.Shared.Config.RareContentConfig)

local Service={_data=nil,_world=nil,_store=nil,_worldState={Monthly={},Uniqueness={},RareHistory={}},_locks={},_studioClaims={}}
local function utcMonth(ts)
    local d=os.date('!*t',ts or os.time())
    return string.format('%04d-%02d',d.year,d.month)
end
local function hash01(s)
    local h=2166136261
    for i=1,#s do h=bit32.bxor(h,string.byte(s,i)); h=(h*16777619)%4294967296 end
    return (h%1000000)/1000000
end
local function serverScope()
    if game.PrivateServerId~='' then return 'private:'..game.PrivateServerId end
    return 'place:'..tostring(game.PlaceId)
end
local function compactHistory(history,entry)
    table.insert(history,entry)
    while #history>20 do table.remove(history,1) end
end
local function getRare(profile)
    profile.RareContent=type(profile.RareContent)=='table' and profile.RareContent or {}
    local r=profile.RareContent
    r.ExtinctClassId=type(r.ExtinctClassId)=='string' and r.ExtinctClassId or ''
    r.LegendarySkills=type(r.LegendarySkills)=='table' and r.LegendarySkills or {}
    r.LegendaryMagic=type(r.LegendaryMagic)=='table' and r.LegendaryMagic or {}
    r.RareItems=type(r.RareItems)=='table' and r.RareItems or {}
    r.EquippedRelics=type(r.EquippedRelics)=='table' and r.EquippedRelics or {}
    r.RareHistory=type(r.RareHistory)=='table' and r.RareHistory or {}
    return r
end
local function newItem(itemType,owner,source,eventId,version)
    local now=os.time()
    return {UniqueItemId=HttpService:GenerateGUID(false),ItemType=itemType,CreatedAt=now,CreatedServerId=serverScope(),FirstOwnerUserId=owner,CurrentOwnerUserId=owner,OwnershipHistory={{UserId=owner,At=now,Reason='Created'}},AcquisitionSource=source,WorldEventId=eventId or '',Version=version or Config.Version,ConsumedAt=0}
end
function Service.GetMonthKey(ts) return utcMonth(ts) end
function Service.BuildMonthlyDecision(monthKey,scope,itemType,chance)
    local roll=hash01(scope..'|'..monthKey..'|'..itemType..'|phase12')
    return {MonthKey=monthKey,DecisionMade=true,Available=roll<(chance or 0),Claimed=false,OpportunityId=string.format('%s:%s:%s',scope,monthKey,itemType),Roll=roll}
end
function Service.ValidateConfig()
    local classes=0 for _ in pairs(Config.ExtinctClasses) do classes+=1 end
    return classes==5 and Config.GetRelicCount()==45 and #Config.RelicCategories==9 and #Config.RelicLineages==5
end
function Service.ApplyExtinctReset(profile,classId)
    if not Config.ExtinctClasses[classId] then return false,'InvalidClass' end
    local rare=getRare(profile)
    if rare.ExtinctClassId~='' then return false,'AlreadyExtinct' end
    rare.ExtinctClassId=classId
    profile.Identity.Class=classId
    profile.Progression.Level=1
    profile.Progression.XP=0
    profile.Build.ClassProgress=profile.Build.ClassProgress or {}
    profile.Build.ClassProgress[classId]={Mastery=0,Level=1}
    local def=Config.ExtinctClasses[classId]
    profile.Build.Unlocked[def.ActiveSkill]=true
    profile.Build.Unlocked[def.PassiveSkill]=true
    return true,'OK'
end
function Service.ApplyRelicStats(profile,attrs)
    local rare=getRare(profile); local counts={}
    for _,relicId in pairs(rare.EquippedRelics) do
        local def=Config.Relics[relicId]
        if def then
            counts[def.Lineage]=(counts[def.Lineage] or 0)+1
            for stat,val in pairs(def.Stats or {}) do if attrs[stat]~=nil then attrs[stat]+=val end end
        end
    end
    for lineage,count in pairs(counts) do
        local set=Config.SetSynergy[lineage]
        if set and count>=2 then for stat,val in pairs(set.TwoPiece.Stats) do if attrs[stat]~=nil then attrs[stat]+=val end end end
        if set and count>=3 then for stat,val in pairs(set.ThreePiece.Stats) do if attrs[stat]~=nil then attrs[stat]+=val end end end
    end
    return attrs
end
function Service:Start(dataService,worldService)
    self._data=dataService; self._world=worldService
    if not RunService:IsStudio() then self._store=DataStoreService:GetDataStore(Config.WorldStateStoreName) end
    self:_ensureMonth()
    self:_ensureOpenWorldHook()
end
function Service:_ensureMonth()
    local month=utcMonth(); local scope=serverScope(); local key='Monthly:'..scope..':'..month
    if RunService:IsStudio() then
        self._worldState.Monthly[month]=self._worldState.Monthly[month] or {}
        for _,t in ipairs(Config.MonthlyOpportunityTypes) do self._worldState.Monthly[month][t]=self._worldState.Monthly[month][t] or Service.BuildMonthlyDecision(month,scope,t,Config.MonthlyChance[t]) end
        return self._worldState.Monthly[month]
    end
    local ok,res=pcall(function() return self._store:UpdateAsync(key,function(old)
        old=type(old)=='table' and old or {}
        for _,t in ipairs(Config.MonthlyOpportunityTypes) do old[t]=old[t] or Service.BuildMonthlyDecision(month,scope,t,Config.MonthlyChance[t]) end
        return old
    end) end)
    if ok and type(res)=='table' then self._worldState.Monthly[month]=res end
    return self._worldState.Monthly[month]
end
function Service:_ensureOpenWorldHook()
    local nl=workspace:FindFirstChild('NewLife'); local world=nl and nl:FindFirstChild('World'); local foundation=world and world:FindFirstChild('OpenWorldFoundation')
    if not foundation then return end
    local part=foundation:FindFirstChild(Config.OpenWorldHook.Id)
    if not part then
        part=Instance.new('Part'); part.Name=Config.OpenWorldHook.Id; part.Anchored=true; part.Size=Vector3.new(4,4,4); part.Position=Config.OpenWorldHook.Position; part:SetAttribute('RareContentHook',true); part:SetAttribute('DisplayNameKey',Config.OpenWorldHook.DisplayNameKey); part.Parent=foundation
    end
end
function Service:_claimOpportunity(player,itemType,source)
    local profile=self._data:GetProfile(player); if not profile then return false,'NoProfile' end
    local rare=getRare(profile); local month=utcMonth(); local scope=serverScope(); local tableMonth=self:_ensureMonth(); local opp=tableMonth and tableMonth[itemType]
    if not opp or not opp.Available then return false,'NoOpportunity' end
    if opp.Claimed then return false,'AlreadyClaimed' end

    local record=newItem(itemType,player.UserId,source,opp.OpportunityId,Config.Version)
    local claimedOpp=opp
    if RunService:IsStudio() then
        opp.Claimed=true; opp.ClaimedBy=player.UserId; opp.ClaimedAt=os.time(); opp.ItemUniqueId=record.UniqueItemId
    else
        local key='Monthly:'..scope..':'..month
        local now=os.time()
        local ok,res=pcall(function() return self._store:UpdateAsync(key,function(old)
            old=type(old)=='table' and old or {}
            for _,t in ipairs(Config.MonthlyOpportunityTypes) do old[t]=old[t] or Service.BuildMonthlyDecision(month,scope,t,Config.MonthlyChance[t]) end
            local target=old[itemType]
            if target and target.Available and not target.Claimed then
                target.Claimed=true
                target.ClaimedBy=player.UserId
                target.ClaimedAt=now
                target.ItemUniqueId=record.UniqueItemId
            end
            return old
        end) end)
        if not ok or type(res)~='table' then return false,'StoreError' end
        self._worldState.Monthly[month]=res
        claimedOpp=res[itemType]
        if not claimedOpp or not claimedOpp.Available then return false,'NoOpportunity' end
        if claimedOpp.ItemUniqueId~=record.UniqueItemId or claimedOpp.ClaimedBy~=player.UserId then return false,'AlreadyClaimed' end
    end

    rare.RareItems[record.UniqueItemId]=record
    compactHistory(rare.RareHistory,{At=os.time(),Type='Acquire',ItemType=itemType,UniqueItemId=record.UniqueItemId,Source=source})
    compactHistory(self._worldState.RareHistory,{At=os.time(),Type='RareAcquired',ItemType=itemType,OwnerUserId=player.UserId,WorldEventId=claimedOpp.OpportunityId})
    self._data:AddPlayerChronicle(player,'Acquired a rare '..itemType..'.','RareAcquisition')
    if self._world then self._world:AddWorldChronicle(itemType..' was claimed from a monthly rare opportunity.','RareAcquisition') end
    return true,record.UniqueItemId
end
function Service:TryAcquireOpenWorld(player)
    local character=player.Character
    local root=character and character:FindFirstChild('HumanoidRootPart')
    local nl=workspace:FindFirstChild('NewLife'); local world=nl and nl:FindFirstChild('World'); local foundation=world and world:FindFirstChild('OpenWorldFoundation')
    local hook=foundation and foundation:FindFirstChild(Config.OpenWorldHook.Id)
    if not root or not hook or not hook:IsA('BasePart') then return false,'Unavailable' end
    if (root.Position-hook.Position).Magnitude>(Config.OpenWorldHook.InteractDistance or 14) then return false,'TooFar' end
    local order={'ExtinctClassBook','LegendarySkillBook','LegendaryMagicBook'}
    for _,t in ipairs(order) do local ok,id=self:_claimOpportunity(player,t,Config.AcquisitionSources.OpenWorld); if ok then return true,id,t end end
    return false,'NoOpportunity'
end
function Service:OnDungeonCleared(player)
    local order={'LegendarySkillBook','LegendaryMagicBook','ExtinctClassBook'}
    for _,t in ipairs(order) do local ok,id=self:_claimOpportunity(player,t,Config.AcquisitionSources.Dungeon); if ok then return true,id,t end end
    return false,'NoOpportunity'
end
function Service:UseRareItem(player,uniqueId)
    if self._locks[player.UserId] then return false,'Busy' end
    self._locks[player.UserId]=true
    local profile=self._data:GetProfile(player); local rare=profile and getRare(profile); local item=rare and rare.RareItems[uniqueId]
    if not item or item.CurrentOwnerUserId~=player.UserId or (item.ConsumedAt or 0)>0 then self._locks[player.UserId]=nil; return false,'InvalidOwnership' end
    local ok,reason=false,'Unsupported'
    if item.ItemType=='ExtinctClassBook' then
        if rare.ExtinctClassId~='' then reason='AlreadyExtinct' else
            local seed=math.abs(player.UserId+os.time()+#rare.RareHistory*7919); local rng=Random.new(seed); local classId=Config.ExtinctClassOrder[rng:NextInteger(1,#Config.ExtinctClassOrder)]
            ok,reason=Service.ApplyExtinctReset(profile,classId)
            if ok then item.ConsumedAt=os.time(); self._data:AddPlayerChronicle(player,'Became a Predestined through an Extinct Class Book.','Predestined'); if self._world then self._world:BroadcastAnnouncement(Config.AnnouncementPredestined); self._world:AddWorldChronicle(Config.AnnouncementPredestined,'Predestined') end end
        end
    elseif item.ItemType=='LegendarySkillBook' then
        rare.LegendarySkills[Config.LegendarySkill.Id]=true; profile.Build.Unlocked[Config.LegendarySkill.Id]=true; item.ConsumedAt=os.time(); ok=true; reason='OK'; self._data:AddPlayerChronicle(player,'Unlocked a Legendary Skill.','LegendarySkill')
    elseif item.ItemType=='LegendaryMagicBook' then
        rare.LegendaryMagic[Config.LegendaryMagic.Id]=true; profile.Build.Unlocked[Config.LegendaryMagic.Id]=true; item.ConsumedAt=os.time(); ok=true; reason='OK'; self._data:AddPlayerChronicle(player,'Unlocked a Legendary Magic.','LegendaryMagic')
    end
    if ok then compactHistory(rare.RareHistory,{At=os.time(),Type='Consume',UniqueItemId=uniqueId,ItemType=item.ItemType}) end
    self._locks[player.UserId]=nil; if ok then self._data:RecalculateAttributes(player); self._data:Apply(player) end
    return ok,reason
end
function Service:TransferItem(fromPlayer,toPlayer,uniqueId,context)
    if fromPlayer==toPlayer then return false,'SameOwner' end
    local a=self._data:GetProfile(fromPlayer); local b=self._data:GetProfile(toPlayer); if not a or not b then return false,'NoProfile' end
    local ar,br=getRare(a),getRare(b); local item=ar.RareItems[uniqueId]
    if not item or item.CurrentOwnerUserId~=fromPlayer.UserId or (item.ConsumedAt or 0)>0 then return false,'InvalidOwnership' end
    if br.RareItems[uniqueId] then return false,'Duplicate' end
    if item.ItemType=='Relic' then
        for _,equippedRelicId in pairs(ar.EquippedRelics or {}) do
            if equippedRelicId==item.RelicId then return false,'Equipped' end
        end
        local uniqueOk=self:_updateRelicUniquenessOwner(item,toPlayer.UserId)
        if not uniqueOk then return false,'UniquenessUpdateFailed' end
    end
    local at=os.time()
    local source=type(context)=='table' and context.TransferSource or 'Transfer'
    local tx=type(context)=='table' and context.TransactionId or ''
    ar.RareItems[uniqueId]=nil
    item.CurrentOwnerUserId=toPlayer.UserId
    item.TransferSource=source
    item.TransactionId=tx
    item.TransferTimestamp=at
    compactHistory(item.OwnershipHistory,{UserId=toPlayer.UserId,At=at,Reason='Transfer',TransferSource=source,TransactionId=tx})
    br.RareItems[uniqueId]=item
    return true,'OK'
end
function Service:GrantRareForTest(player,itemType)
    if not RunService:IsStudio() then return nil end
    local profile=self._data and self._data:GetProfile(player); if not profile then return nil end
    local rare=getRare(profile); local item=newItem(itemType,player.UserId,'StudioTest','',Config.Version); rare.RareItems[item.UniqueItemId]=item; return item.UniqueItemId
end
function Service:SetOpportunityForTest(itemType,available,claimed)
    if not RunService:IsStudio() then return false end
    local month=utcMonth(); self._worldState.Monthly[month]=self._worldState.Monthly[month] or {}
    self._worldState.Monthly[month][itemType]={MonthKey=month,DecisionMade=true,Available=available==true,Claimed=claimed==true,OpportunityId='StudioTest:'..month..':'..itemType}
    return true
end
function Service:_uniquenessKey(relicId,policy)
    if policy=='WorldUnique' then return 'Uniq:World:'..relicId end
    if policy=='ServerLimited' then return 'Uniq:Server:'..serverScope()..':'..relicId end
    return nil
end
function Service:_claimRelicUniqueness(userId,itemUniqueId,relicId,policy)
    if policy~='WorldUnique' and policy~='ServerLimited' then return true,'OK' end
    local key=self:_uniquenessKey(relicId,policy); if not key then return true,'OK' end
    if RunService:IsStudio() then
        local current=self._worldState.Uniqueness[key]
        if current and current.ItemUniqueId~=itemUniqueId then return false,'UniquenessClaimed' end
        self._worldState.Uniqueness[key]={RelicId=relicId,Policy=policy,ItemUniqueId=itemUniqueId,CurrentOwnerUserId=userId,UpdatedAt=os.time()}
        return true,'OK'
    end
    local now=os.time()
    local ok,res=pcall(function() return self._store:UpdateAsync(key,function(old)
        if type(old)=='table' and old.ItemUniqueId and old.ItemUniqueId~=itemUniqueId then return old end
        return {RelicId=relicId,Policy=policy,ItemUniqueId=itemUniqueId,CurrentOwnerUserId=userId,UpdatedAt=now}
    end) end)
    if not ok or type(res)~='table' then return false,'StoreError' end
    if res.ItemUniqueId~=itemUniqueId then return false,'UniquenessClaimed' end
    self._worldState.Uniqueness[key]=res
    return true,'OK'
end
function Service:_updateRelicUniquenessOwner(item,userId)
    if item.ItemType~='Relic' then return true end
    local def=Config.Relics[item.RelicId]; if not def then return false end
    local policy=def.UniquenessPolicy
    if policy~='WorldUnique' and policy~='ServerLimited' then return true end
    local ok=self:_claimRelicUniqueness(userId,item.UniqueItemId,item.RelicId,policy)
    return ok
end
function Service:GrantRelicForTest(profile,relicId,userId)
    local def=Config.Relics[relicId]; if not def then return nil end
    local rare=getRare(profile); local item=newItem('Relic',userId or 0,'Test','',Config.Version); item.RelicId=relicId
    local ok=self:_claimRelicUniqueness(userId or 0,item.UniqueItemId,relicId,def.UniquenessPolicy)
    if not ok then return nil end
    rare.RareItems[item.UniqueItemId]=item; return item.UniqueItemId
end
function Service:EquipRelic(player,uniqueId)
    local p=self._data:GetProfile(player); if not p then return false,'NoProfile' end
    local rare=getRare(p); local item=rare.RareItems[uniqueId]; if not item or item.ItemType~='Relic' or item.CurrentOwnerUserId~=player.UserId then return false,'InvalidOwnership' end
    local def=Config.Relics[item.RelicId]; if not def then return false,'InvalidRelic' end
    local uniqueOk,uniqueReason=self:_claimRelicUniqueness(player.UserId,item.UniqueItemId,item.RelicId,def.UniquenessPolicy)
    if not uniqueOk then return false,uniqueReason end
    rare.EquippedRelics[def.Category]=item.RelicId; self._data:RecalculateAttributes(player); self._data:Apply(player); return true,'OK'
end
function Service:UnequipRelic(player,category)
    local p=self._data:GetProfile(player); if not p then return false,'NoProfile' end
    local rare=getRare(p); if not rare.EquippedRelics[category] then return false,'Empty' end
    rare.EquippedRelics[category]=nil; self._data:RecalculateAttributes(player); self._data:Apply(player); return true,'OK'
end
function Service:GetWorldState() return self._worldState end
return Service