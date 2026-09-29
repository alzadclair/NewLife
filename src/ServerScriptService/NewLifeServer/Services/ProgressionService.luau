--!strict
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Content=require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local GameConfig=require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local Service={_data=nil,_feedback=nil,_lastSkill={}}
function Service:Start(dataService)
 self._data=dataService; self._feedback=ReplicatedStorage.NewLife.Remotes.ProgressionFeedback
end
function Service:RewardEnemy(player,enemyId)
 local def=Content.Enemies[enemyId]; if not def then return end
 self._data:AddXP(player,def.XP or 0); self._data:AddGold(player,def.Gold or 0)
 for itemId,drop in (def.Drops or {}) do if math.random()<=drop.Chance then self._data:AddItem(player,itemId,math.random(drop.Min,drop.Max)) end end
 if self._feedback then self._feedback:FireClient(player,'EnemyReward',{EnemyId=enemyId,XP=def.XP or 0,Gold=def.Gold or 0}) end
end
function Service:UseRacialSkill(player)
 local p=self._data:GetProfile(player); local c=player.Character; if not p or not c then return false,'Missing' end
 local race=Content.Races[p.Identity.Race]; local skill=race and Content.Skills[race.RacialSkill]; if not skill then return false,'NoSkill' end
 local now=os.clock(); if now-(self._lastSkill[player] or 0)<GameConfig.Progression.RacialSkillCooldown then return false,'Cooldown' end; self._lastSkill[player]=now
 local hum=c:FindFirstChildOfClass('Humanoid'); if hum then hum.Health=math.min(hum.MaxHealth,hum.Health+(skill.Heal or 0)) end
 local st=c:GetAttribute('Stamina') or 0; local max=c:GetAttribute('MaxStamina') or st; c:SetAttribute('Stamina',math.min(max,st+(skill.StaminaRestore or 0)))
 self._feedback:FireClient(player,'RacialSkill',{Skill=race.RacialSkill}); return true,'OK'
end
return Service