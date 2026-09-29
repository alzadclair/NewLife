--!strict
local Players=game:GetService('Players')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local GameConfig=require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local NetProtocol=require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)
local CombatService={_stateService=nil,_characterService=nil,_enemyService=nil,_worldBossService=nil,_lastAttack={}}
local feedback=ReplicatedStorage.NewLife.Remotes:WaitForChild(NetProtocol.Remotes.CombatFeedback)
local function num(i,n,f) local v=i:GetAttribute(n); return type(v)=='number' and v or f end
local function playerFor(model) return Players:GetPlayerFromCharacter(model) end
local function send(p,k,pay) if p then feedback:FireClient(p,k,pay) end end
function CombatService:Start(state,character,enemy) self._stateService=state; self._characterService=character; self._enemyService=enemy; Players.PlayerRemoving:Connect(function(p) self._lastAttack[p]=nil end) end
function CombatService:_validateTarget(character,target)
 if target==nil then return nil,nil end
 if not target:IsA('Model') or target==character or not target:IsDescendantOf(workspace) then return nil,'InvalidTarget' end
 local hum=target:FindFirstChildOfClass('Humanoid'); local root=target:FindFirstChild('HumanoidRootPart'); local my=character:FindFirstChild('HumanoidRootPart')
 if not hum or hum.Health<=0 or not root or not root:IsA('BasePart') or not my or not my:IsA('BasePart') then return nil,'InvalidTarget' end
 if (root.Position-my.Position).Magnitude>GameConfig.Network.MaxTargetDistance then return nil,'OutOfRange' end
 return target,nil
end
function CombatService:_deal(attacker,target,raw,kb)
 local hum=target:FindFirstChildOfClass('Humanoid'); if not hum or hum.Health<=0 then return false,'InvalidTarget',0 end
 local ap=attacker and playerFor(attacker) or nil; local tp=playerFor(target)
 if self._stateService:IsInState(target,'Dodging') then send(tp,'Dodge',{Amount=0}); send(ap,'Evaded',{Amount=0}); return true,'Dodged',0 end
 if self._stateService:IsInState(target,'Parrying') and attacker then self._stateService:SetState(attacker,'Stunned',true); task.delay(GameConfig.Combat.ParryStunSeconds,function() if attacker.Parent then self._stateService:SetState(attacker,'Stunned',false) end end); send(tp,'Parry',{}); send(ap,'Parried',{}); return true,'Parried',0 end
 local damage=math.max(GameConfig.Combat.MinimumDamage,raw-num(target,'Defense',0)*GameConfig.Combat.DefenseScale)
 if self._stateService:IsInState(target,'Blocking') then local st=num(target,'Stamina',0); if st>=GameConfig.Combat.BlockStaminaCost then target:SetAttribute('Stamina',st-GameConfig.Combat.BlockStaminaCost); damage*=GameConfig.Combat.BlockDamageMultiplier; send(tp,'Block',{Amount=damage}) else target:SetAttribute('Stamina',0); self._stateService:SetState(target,'Blocking',false); send(tp,'GuardBreak',{Amount=damage}) end end
 hum:TakeDamage(damage)
 if ap and self._worldBossService and self._worldBossService:IsWorldBoss(target) then
  self._worldBossService:MarkHit(target,ap,damage)
 elseif ap and self._enemyService then
  self._enemyService:MarkHit(target,ap)
 end
 send(ap,'Hit',{Amount=damage,Target=target.Name}); send(tp,'Damage',{Amount=damage,Source=attacker and attacker.Name or 'Enemy'}); return true,'Hit',damage
end
function CombatService:_attack(player,target,heavy)
 local c=player.Character; if not c then return false,'NoCharacter' end; local h=c:FindFirstChildOfClass('Humanoid'); if not h or h.Health<=0 then return false,'NotAlive' end
 local key=heavy and 'HeavyAttack' or 'LightAttack'; local per=self._lastAttack[player] or {}; self._lastAttack[player]=per; local now=os.clock(); if now-(per[key] or 0)<GameConfig.Network.RateLimits[key] then return false,'Cooldown' end; per[key]=now
 self._stateService:SetState(c,'Blocking',false); self._stateService:SetState(c,'Attacking',true); task.delay(heavy and GameConfig.Combat.HeavyStateSeconds or GameConfig.Combat.AttackStateSeconds,function() if c.Parent then self._stateService:SetState(c,'Attacking',false) end end)
 local m,err=self:_validateTarget(c,target); if err then return false,err end; if not m then return true,'Swing' end
 local strength=num(c,'Strength',0); local power=num(c,'Power',0); local raw=heavy and (GameConfig.Combat.HeavyBaseDamage+strength*GameConfig.Combat.HeavyStrengthScale+power*GameConfig.Combat.HeavyPowerScale) or (GameConfig.Combat.BaseDamage+strength*GameConfig.Combat.StrengthScale+power*GameConfig.Combat.PowerScale); if player and player:GetAttribute('HasMagic')==false then raw=raw*GameConfig.Progression.NoMagicPhysicalBonus end
 local ok,res=self:_deal(c,m,raw,heavy and GameConfig.Combat.KnockbackHeavy or GameConfig.Combat.KnockbackLight); return ok,res
end
function CombatService:HandleLightAttack(p,t) return self:_attack(p,t,false) end
function CombatService:HandleHeavyAttack(p,t) return self:_attack(p,t,true) end
function CombatService:HandleParry(p) local c=p.Character; if not c or not self._characterService:IsActionable(p) then return false end; if not self._characterService:SpendStamina(c,GameConfig.Combat.ParryStaminaCost) then return false end; self._characterService:SetBlock(p,false); self._stateService:SetState(c,'Parrying',true); task.delay(GameConfig.Combat.ParryWindow,function() if c.Parent then self._stateService:SetState(c,'Parrying',false) end end); return true end
function CombatService:HandleEnemyAttack(e,t) return self:_deal(e,t,GameConfig.Combat.EnemyDamage+num(e,'Strength',0)*0.4,10) end
return CombatService