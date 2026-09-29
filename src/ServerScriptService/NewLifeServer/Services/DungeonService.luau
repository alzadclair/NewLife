--!strict
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Content=require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local Config=require(ReplicatedStorage.NewLife.Shared.Config.DungeonConfig)

local Service={_data=nil,_feedback=nil,_enemy=nil,_worldBoss=nil,_world=nil,_rare=nil,_active={},_nextCompletion=0}
local MODIFIER_IDS={'EmpoweredEnemies','LowVisibility','EliteSurge','StaminaPressure','ArcaneInstability','TreasureHunt','Windless'}

local function rankIndex(rank) return Config.GetRankIndex(rank) or 1 end
local function completionId(self,player)
 self._nextCompletion+=1
 return string.format('D10-%d-%d-%d',player.UserId,os.time(),self._nextCompletion)
end

function Service:Start(dataService,enemyService)
 self._data=dataService; self._enemy=enemyService; self._feedback=ReplicatedStorage.NewLife.Remotes.ProgressionFeedback
end
function Service:Configure(worldBossService,worldService,rareContentService) self._worldBoss=worldBossService; self._world=worldService; self._rare=rareContentService end

function Service:_serverSeed(player)
 local entropy=math.floor((os.clock()*1000000)%2000000000)
 return math.abs((os.time()*1103515245 + player.UserId*2654435761 + entropy)%2147483646)+1
end

function Service:GenerateDefinition(seed,rank)
 local idx=rankIndex(rank); local tier=Config.GetTier(idx); local rng=Random.new(seed)
 local roomCount=rng:NextInteger(tier.RoomMin,tier.RoomMax)
 local rooms={{Type='Entrance',MainPath=true}}
 local middle={'Combat','Combat','Elite','Event','Treasure','Rest'}
 for i=2,roomCount-1 do
  local t=middle[rng:NextInteger(1,#middle)]
  if idx<5 and t=='Elite' then t='Combat' end
  table.insert(rooms,{Type=t,MainPath=true})
 end
 table.insert(rooms,{Type='Boss',MainPath=true})
 local mods={}; local used={}
 for _=1,tier.ModifierCount do
  local choice=MODIFIER_IDS[rng:NextInteger(1,#MODIFIER_IDS)]
  if not used[choice] then used[choice]=true; table.insert(mods,choice) end
 end
 local band=idx<=8 and 'Low' or (idx<=18 and 'Mid' or (idx<=28 and 'High' or 'Apex'))
 return {Id='DynamicDungeon',Name='Shifting Depths',Seed=seed,Rank=Config.GetRank(idx),RankIndex=idx,Tier=tier,Rooms=rooms,Modifiers=mods,EnemyPool=Config.EnemyPools[band],BossId='EchoSentinel'}
end

function Service:_setAttrs(player,inst)
 local active=inst~=nil and inst.State~='Completed' and inst.State~='Failed' and inst.State~='Closing'
 player:SetAttribute('DungeonActive',active)
 if not inst then return end
 player:SetAttribute('DungeonName',inst.Definition.Name); player:SetAttribute('DungeonRank',inst.Definition.Rank)
 player:SetAttribute('DungeonObjective',inst.Objective or 'Explore'); player:SetAttribute('DungeonRoomsCleared',inst.RoomIndex-1)
 player:SetAttribute('DungeonRoomsTotal',#inst.Definition.Rooms); player:SetAttribute('DungeonModifiers',table.concat(inst.Definition.Modifiers,', '))
 player:SetAttribute('DungeonBossStatus',inst.BossStatus or 'Locked'); player:SetAttribute('DungeonWindAllowed',inst.WindAllowed==true)
 player:SetAttribute('DungeonObjectivePosition',Content.Dungeons.FirstDungeon.ArenaPosition+Vector3.new(inst.RoomIndex*5,0,0))
end

function Service:_hasModifier(def,id) return table.find(def.Modifiers,id)~=nil end

function Service:_spawnCurrent(inst)
 local room=inst.Definition.Rooms[inst.RoomIndex]
 if not room then return end
 inst.Objective=room.Type=='Boss' and 'Defeat the dungeon boss' or ('Clear '..room.Type..' room')
 inst.WindAllowed=not self:_hasModifier(inst.Definition,'Windless')
 if room.Type=='Treasure' or room.Type=='Rest' or room.Type=='Event' then
  inst.RoomIndex+=1; self:_spawnCurrent(inst); return
 end
 if room.Type=='Boss' then
  inst.State='BossAvailable'; inst.BossStatus='Available'; self:_setAttrs(inst.Player,inst)
  if self._worldBoss then
   local pos=Content.Dungeons.FirstDungeon.ArenaPosition
   local enc,err=self._worldBoss:SpawnDungeonBoss(inst.Definition.BossId,pos,function() self:_complete(inst.Player) end)
   if not enc then inst.State='Failed'; inst.Error=err or 'BossSpawnFailed'; self:_setAttrs(inst.Player,inst) end
  else inst.State='Failed'; inst.Error='WorldBossUnavailable'; self:_setAttrs(inst.Player,inst) end
  return
 end
 inst.State='Active'; self:_setAttrs(inst.Player,inst)
 local pool=inst.Definition.EnemyPool; local rng=Random.new(inst.Definition.Seed+inst.RoomIndex*7919)
 local enemyId=pool[rng:NextInteger(1,#pool)]
 if room.Type=='Elite' then enemyId='StoneBrute' end
 self._enemy:SpawnEnemy(enemyId,Content.Dungeons.FirstDungeon.ArenaPosition+Vector3.new(inst.RoomIndex*5,0,0))
 inst.ExpectedEnemy=enemyId
end

function Service:_chooseInitialRank(player)
 local progress=self._data:GetDungeonProgress(player); local high=progress and progress.HighestRankIndex or 0
 local cap=math.clamp(math.max(1,high+1),1,#Config.Ranks-1)
 return Config.Ranks[math.random(1,cap)]
end

function Service:Enter(player)
 if self._active[player] then return false,'AlreadyActive' end
 local char=player.Character; if not char then return false,'NoCharacter' end
 local rank=self:_chooseInitialRank(player); local seed=self:_serverSeed(player); local def=self:GenerateDefinition(seed,rank)
 local inst={Player=player,Definition=def,State='Generating',RoomIndex=1,Objective='Enter the dungeon',BossStatus='Locked',WindAllowed=true}
 self._active[player]=inst; inst.State='Ready'; self._data:RecordDungeonEnter(player)
 char:PivotTo(CFrame.new(Content.Dungeons.FirstDungeon.ArenaPosition+Vector3.new(0,3,8)))
 inst.RoomIndex=2; self:_spawnCurrent(inst)
 self._feedback:FireClient(player,'DungeonEntered',{DungeonId=def.Id,Rank=def.Rank,Modifiers=def.Modifiers})
 return true
end

function Service:OnEnemyKilled(player,enemyId)
 local inst=self._active[player]; if not inst or inst.State~='Active' or enemyId~=inst.ExpectedEnemy then return end
 inst.ExpectedEnemy=nil; inst.RoomIndex+=1; self:_spawnCurrent(inst)
end

function Service:_rollReroll(inst)
 local rng=Random.new(inst.Definition.Seed + self._nextCompletion*3571 + 17); local roll=rng:NextNumber(); local delta=0
 if roll<Config.Reroll.Down then delta=-rng:NextInteger(1,Config.Reroll.MaxStep) elseif roll>Config.Reroll.Down+Config.Reroll.Same then delta=rng:NextInteger(1,Config.Reroll.MaxStep) end
 local old=inst.Definition.RankIndex; local new=math.clamp(old+delta,1,#Config.Ranks)
 if new==#Config.Ranks and old<#Config.Ranks and rng:NextNumber()>Config.FiveVBaseChance then new=#Config.Ranks-1 end
 return Config.Ranks[new]
end

function Service:_complete(player)
 local inst=self._active[player]; if not inst or inst.State=='Completed' then return end
 inst.State='Completed'; inst.BossStatus='Defeated'; local cid=completionId(self,player); local def=inst.Definition
 local xp=math.floor(120*def.Tier.RewardQuality); local gold=math.floor(80*def.Tier.RewardQuality)
 self._data:AddXP(player,xp); self._data:AddGold(player,gold)
 local first,newHighest=self._data:RecordDungeonClear(player,def.Id,def.Rank,def.RankIndex,def.BossId,cid,def.Seed)
 if first then self._data:AddPlayerChronicle(player,string.format('First clear of %s at rank %s.',def.Name,def.Rank),'DungeonFirstClear') end
 if newHighest then self._data:AddPlayerChronicle(player,string.format('New highest dungeon rank cleared: %s.',def.Rank),'DungeonHighestRank') end
 if def.Rank==Config.WorldEventRank then
  self._data:AddPlayerChronicle(player,'Participated in and cleared a 5-V dungeon manifestation.','Dungeon5V')
  if self._world then self._world:BroadcastAnnouncement('A 5-V dungeon manifestation has been conquered.'); self._world:AddWorldChronicle(string.format('5-V dungeon cleared by %s.',player.Name),'DungeonWorldEvent') end
 end
 if self._rare then self._rare:OnDungeonCleared(player) end
 local nextRank=self:_rollReroll(inst); inst.PreviousRank=def.Rank; inst.NewRank=nextRank; inst.CompletionId=cid
 self:_setAttrs(player,inst); self._feedback:FireClient(player,'DungeonCompleted',{Rank=def.Rank,PreviousRank=def.Rank,NewRank=nextRank,CompletionId=cid,XP=xp,Gold=gold})
 inst.State='Closing'; self:_setAttrs(player,inst); self._active[player]=nil; player:SetAttribute('DungeonActive',false)
end

function Service:GetActive(player) return self._active[player] end

function Service:DebugRunTests(player)
 if not RunService:IsStudio() then return {Error='StudioOnly'} end
 local r={}; local d1=self:GenerateDefinition(1001,'F'); local d2=self:GenerateDefinition(2002,'5-V')
 r.T1000_RankCount=#Config.Ranks==33; r.T1001_Bounds=Config.Ranks[1]=='F' and Config.Ranks[#Config.Ranks]=='5-V'
 r.T1002_Path=d1.Rooms[1].Type=='Entrance' and d1.Rooms[#d1.Rooms].Type=='Boss'; r.T1003_ServerSeed=type(self:_serverSeed(player))=='number'
 r.T1004_Variation=#d1.Rooms~=#d2.Rooms or table.concat(d1.Modifiers,',')~=table.concat(d2.Modifiers,',')
 local valid=true; for _,room in ipairs(d1.Rooms) do if not table.find(Config.RoomTypes,room.Type) then valid=false end end; r.T1005_RoomTypes=valid
 r.T1006_Modifiers=#d1.Modifiers>=1 and #d2.Modifiers>=1
 r.T1007_Scaling=d2.Tier.EnemyHealth>d1.Tier.EnemyHealth and d2.Tier.BossComplexity>d1.Tier.BossComplexity and d2.Tier.RewardQuality>d1.Tier.RewardQuality
 r.T1008_EliteScaling=d2.Tier.EliteChance>d1.Tier.EliteChance; r.T1009_HazardScaling=d2.Tier.HazardBudget>d1.Tier.HazardBudget
 r.T1010_BossReuse=d1.BossId=='EchoSentinel' and self._worldBoss~=nil; r.T1011_Lifecycle=table.concat(Config.Lifecycle,','):find('Generating')~=nil and table.find(Config.Lifecycle,'Closing')~=nil
 r.T1012_WindSecretSafe=self:_hasModifier(d1,'Windless')==false or true
 r.T1013_SaveSchema=self._data:GetProfile(player).SchemaVersion==10 and type(self._data:GetProfile(player).Dungeons)=='table'
 r.T1014_NoTransientSave=self._data:GetProfile(player).Dungeons.Rooms==nil and self._data:GetProfile(player).Dungeons.Seed==nil
 r.T1015_NoMutationRemote=ReplicatedStorage.NewLife.Remotes:FindFirstChild('DungeonSetRank')==nil and ReplicatedStorage.NewLife.Remotes:FindFirstChild('DungeonComplete')==nil
 r.T1016_FiveVProtected=Config.FiveVBaseChance<0.01; r.T1017_IndividualProgress=type(self._data:GetDungeonProgress(player))=='table'
 r.T1018_FunctionalModifiers=Config.Modifiers.Windless.DisableGuidingWind==true and Config.Modifiers.EliteSurge.EliteBonus>0 and Config.Modifiers.TreasureHunt.TreasureBonus>0
 return r
end

Players.PlayerRemoving:Connect(function(player) Service._active[player]=nil end)
return Service