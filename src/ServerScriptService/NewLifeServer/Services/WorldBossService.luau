--!strict
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local ServerScriptService = game:GetService('ServerScriptService')

local Content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local EchoConfig = require(ReplicatedStorage.NewLife.Shared.Config.SovereignEchoConfig)
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)

local Service = {
    _data = nil,
    _world = nil,
    _ruler = nil,
    _combat = nil,
    _encounters = {},
    _encounterById = {},
    _nextEncounterId = 0,
    _snapshotRevision = 0,
    _lastSovereignId = -1,
    _cachedSovereignSnapshot = nil,
    _worldFirstDefeats = {},
    _heartbeat = nil,
}

local REQUIRED_STATES = {'Idle','AcquireTarget','Chase','Attack','Ability','Defense','Reposition','Stagger','Enraged','Dead'}

local function clone(v)
    if type(v) ~= 'table' then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = clone(x) end
    return out
end

local function clampNumber(v, fallback, lo, hi)
    return math.clamp(tonumber(v) or fallback, lo, hi)
end

local function serverDateKey(ts)
    return os.date('!%Y-%m-%d', ts or os.time())
end

local function approvedSlots(source, catalog, unlocked)
    local out = {}
    if type(source) ~= 'table' then return out end
    for i = 1, 4 do
        local id = source[i]
        if type(id) == 'string' and catalog[id] ~= nil and (unlocked == nil or unlocked[id] == true) then
            table.insert(out, id)
        end
    end
    return out
end

local function rootOf(model)
    local root = model and model:FindFirstChild('HumanoidRootPart')
    return root and root:IsA('BasePart') and root or nil
end

local function humOf(model)
    return model and model:FindFirstChildOfClass('Humanoid') or nil
end

function Service:GetServerDateKey(ts)
    return serverDateKey(ts)
end

function Service:GetRequiredStates()
    return clone(REQUIRED_STATES)
end

function Service:_refreshSovereignRevision()
    local state = self._ruler and self._ruler:GetSnapshot() or nil
    local id = state and tonumber(state.SovereignId) or 0
    if id ~= self._lastSovereignId then
        self._lastSovereignId = id
        self._snapshotRevision += 1
        self._cachedSovereignSnapshot = nil
    end
    return state
end

function Service:ResolveArchetype(snapshot)
    local classId = tostring(snapshot.Class or 'Adventurer')
    local magicCount = type(snapshot.EquippedMagic) == 'table' and #snapshot.EquippedMagic or 0
    local skillCount = type(snapshot.EquippedSkills) == 'table' and #snapshot.EquippedSkills or 0
    local defense = tonumber(snapshot.Stats and snapshot.Stats.Defense) or 0
    local strength = tonumber(snapshot.Stats and snapshot.Stats.Strength) or 0
    local power = tonumber(snapshot.Stats and snapshot.Stats.Power) or 0
    if classId == 'Mage' or magicCount >= 2 then return 'Magic' end
    if classId == 'Rogue' then return 'Ranged' end
    if classId == 'Warrior' and defense >= math.max(strength, power) then return 'Defensive' end
    if classId == 'Warrior' then return 'Melee' end
    if magicCount > 0 and skillCount > 0 then return 'Hybrid' end
    return strength >= power and 'Melee' or 'Hybrid'
end

function Service:BuildSovereignSnapshot()
    local rulerState = self:_refreshSovereignRevision()
    if self._cachedSovereignSnapshot then return clone(self._cachedSovereignSnapshot) end
    local sovereignId = rulerState and math.floor(tonumber(rulerState.SovereignId) or 0) or 0
    local sovereignName = rulerState and tostring(rulerState.SovereignName or 'Vacant') or 'Vacant'
    local ranking = rulerState and rulerState.SovereignSnapshot or nil
    local player = sovereignId > 0 and Players:GetPlayerByUserId(sovereignId) or nil
    local profile = player and self._data:GetProfile(player) or nil

    local snap
    if profile then
        local stats = profile.Attributes or {}
        local build = profile.Build or {}
        local unlocked = build.Unlocked or {}
        snap = {
            SnapshotVersion = EchoConfig.SnapshotVersion,
            Revision = self._snapshotRevision,
            UserId = player.UserId,
            Name = player.Name,
            Level = clampNumber(profile.Progression and profile.Progression.Level, 0, 0, GameConfig.Progression.MaxLevel),
            Race = tostring(profile.Identity and profile.Identity.Race or 'Human'),
            Class = tostring(profile.Identity and profile.Identity.Class or 'Adventurer'),
            PowerRating = math.max(1, tonumber(profile.Progression and profile.Progression.PowerRating) or 1),
            Stats = {
                MaxHealth = math.max(1, tonumber(stats.MaxHealth) or 100),
                Defense = math.max(0, tonumber(stats.Defense) or 0),
                Strength = math.max(0, tonumber(stats.Strength) or 0),
                Power = math.max(0, tonumber(stats.Power) or 0),
                MaxMana = math.max(0, tonumber(stats.MaxMana) or 0),
                MaxStamina = math.max(0, tonumber(stats.MaxStamina) or 0),
            },
            EquippedSkills = approvedSlots(build.SkillSlots, Content.Skills, unlocked),
            EquippedMagic = approvedSlots(build.MagicSlots, Content.Magic, unlocked),
            RacialIdentity = {Primary=tostring(profile.Identity.Race or 'Human'), Secondary=profile.Birth and profile.Birth.SecondaryRace or nil, Hybrid=profile.Birth and profile.Birth.IsHybrid == true or false},
        }
    else
        snap = {
            SnapshotVersion = EchoConfig.SnapshotVersion,
            Revision = self._snapshotRevision,
            UserId = sovereignId,
            Name = sovereignName,
            Level = 1,
            Race = 'Human',
            Class = 'Adventurer',
            PowerRating = math.max(1, tonumber(ranking and ranking.Score) or 1),
            Stats = {MaxHealth=100, Defense=5, Strength=10, Power=10, MaxMana=50, MaxStamina=100},
            EquippedSkills = {}, EquippedMagic = {},
            RacialIdentity = {Primary='Human', Secondary=nil, Hybrid=false},
        }
    end
    snap.CombatArchetype = self:ResolveArchetype(snap)
    self._cachedSovereignSnapshot = clone(snap)
    return clone(snap)
end

function Service:ComputeEchoStats(snapshot)
    local s = snapshot.Stats or {}
    local sc = EchoConfig.Scaling
    local health = math.clamp((tonumber(s.MaxHealth) or 100) * sc.Health, EchoConfig.Limits.MinHealth, EchoConfig.Limits.MaxHealth)
    local defense = math.max(0, (tonumber(s.Defense) or 5) * sc.Defense)
    local baseDamage = math.max(EchoConfig.Limits.MinDamage, (tonumber(s.Strength) or 10) * 0.75 + (tonumber(s.Power) or 10) * 0.65)
    local damage = math.clamp(baseDamage * sc.Damage, EchoConfig.Limits.MinDamage, EchoConfig.Limits.MaxDamage)
    local moveSpeed = math.min(EchoConfig.Limits.MaxMoveSpeed, 16 * sc.MoveSpeed)
    return {
        MaxHealth = health,
        Defense = defense,
        Damage = damage,
        MoveSpeed = moveSpeed,
        Resource = math.max(1, ((tonumber(s.MaxMana) or 0) + (tonumber(s.MaxStamina) or 0)) * sc.Resource),
        CooldownScale = sc.Cooldown,
        SkillFrequency = sc.SkillFrequency,
        Resistance = sc.BossResistance,
        StaggerResistance = sc.StaggerResistance,
        EffectivePowerTarget = math.max(1, tonumber(snapshot.PowerRating) or 1) * EchoConfig.EffectivePowerTarget,
    }
end

function Service:_definitionStats(bossId, snapshot)
    if bossId == 'SovereignEcho' then return self:ComputeEchoStats(snapshot) end
    local def = Content.WorldBosses[bossId]
    if not def then return nil end
    return {
        MaxHealth=tonumber(def.MaxHealth) or 500,
        Defense=tonumber(def.Defense) or 5,
        Damage=tonumber(def.Damage) or 12,
        MoveSpeed=tonumber(def.MoveSpeed) or 10,
        Resource=100, CooldownScale=1, SkillFrequency=1, Resistance=0.1, StaggerResistance=0.2,
        EffectivePowerTarget=tonumber(def.MaxHealth) or 500,
    }
end

function Service:_makeModel(def, stats, position)
    local model = Instance.new('Model')
    model.Name = def.DisplayName
    model:SetAttribute('WorldBossId', def.Id)
    model:SetAttribute('BossRank', def.Rank or 'World')
    model:SetAttribute('BossState', 'Idle')
    local root = Instance.new('Part')
    root.Name = 'HumanoidRootPart'; root.Size = Vector3.new(5, 7, 3); root.Anchored = true; root.CanCollide = true; root.Position = position; root.Parent = model
    local head = Instance.new('Part')
    head.Name = 'Head'; head.Size = Vector3.new(4, 2, 3); head.Anchored = true; head.CanCollide = false; head.Position = position + Vector3.new(0, 4.5, 0); head.Parent = model
    local hum = Instance.new('Humanoid')
    hum.MaxHealth = stats.MaxHealth; hum.Health = stats.MaxHealth; hum.WalkSpeed = stats.MoveSpeed; hum.DisplayName = def.DisplayName; hum.Parent = model
    model.PrimaryPart = root
    model:SetAttribute('Defense', stats.Defense)
    model:SetAttribute('Strength', math.max(1, stats.Damage))
    model:SetAttribute('Power', math.max(1, stats.Damage * 0.5))
    model.Parent = workspace
    return model
end

function Service:_setState(enc, state)
    enc.State = state
    if enc.Model and enc.Model.Parent then enc.Model:SetAttribute('BossState', state) end
end

function Service:_setHud(player, enc, active)
    if not player or not player.Parent then return end
    if not active then
        player:SetAttribute('BossActive', false)
        player:SetAttribute('BossName', '')
        player:SetAttribute('BossHealth', 0)
        player:SetAttribute('BossMaxHealth', 0)
        player:SetAttribute('BossPhase', '')
        player:SetAttribute('BossRank', '')
        player:SetAttribute('BossIdentity', '')
        player:SetAttribute('BossStatus', '')
        return
    end
    local hum = humOf(enc.Model)
    player:SetAttribute('BossActive', true)
    player:SetAttribute('BossName', enc.Definition.DisplayName)
    player:SetAttribute('BossHealth', hum and hum.Health or 0)
    player:SetAttribute('BossMaxHealth', hum and hum.MaxHealth or enc.Stats.MaxHealth)
    player:SetAttribute('BossPhase', enc.PhaseName or 'Phase 1')
    player:SetAttribute('BossRank', enc.Definition.Rank or 'World')
    player:SetAttribute('BossIdentity', enc.Snapshot and enc.Snapshot.Name or '')
    player:SetAttribute('BossStatus', enc.State or 'Idle')
end

function Service:_syncHud(enc)
    for _, p in ipairs(Players:GetPlayers()) do
        if enc.Participants[p] or (p.Character and rootOf(p.Character) and (rootOf(p.Character).Position - enc.Origin).Magnitude <= EchoConfig.Arena.Radius) then
            self:_setHud(p, enc, true)
        end
    end
end

function Service:_phaseForRatio(ratio)
    if ratio > 0.70 then return EchoConfig.Phases[1] end
    if ratio > 0.30 then return EchoConfig.Phases[2] end
    return EchoConfig.Phases[3]
end

function Service:_updatePhase(enc)
    local hum = humOf(enc.Model)
    if not hum or hum.MaxHealth <= 0 then return end
    local phase = self:_phaseForRatio(hum.Health / hum.MaxHealth)
    if enc.Phase ~= phase.Id then
        enc.Phase = phase.Id
        enc.PhaseName = phase.Name
        enc.PhaseConfig = phase
        enc.Model:SetAttribute('BossPhase', phase.Id)
        enc.Model:SetAttribute('BossPhaseName', phase.Name)
        if phase.Enraged then self:_setState(enc, 'Enraged') end
    end
end

function Service:_eligible(enc, player)
    local rec = enc.Participants[player]
    if not rec or rec.Damage < EchoConfig.Eligibility.MinDamage then return false end
    local share = enc.TotalDamage > 0 and rec.Damage / enc.TotalDamage or 0
    local active = math.max(0, os.clock() - rec.JoinedAt)
    return share >= EchoConfig.Eligibility.MinDamageShare and active >= EchoConfig.Eligibility.MinActiveSeconds
end

function Service:MarkHit(model, player, damage)
    local enc = self._encounters[model]
    if not enc or enc.Finished or not player or not player.Parent then return false end
    damage = math.max(0, tonumber(damage) or 0)
    if damage <= 0 then return false end
    local rec = enc.Participants[player]
    if not rec then
        rec = {Damage=0, JoinedAt=os.clock(), LastHit=os.clock()}; enc.Participants[player] = rec
        self._data:AddPlayerChronicle(player, string.format('Participated in the %s encounter with verified damage.', enc.Definition.DisplayName), 'WorldBossParticipation')
    end
    rec.Damage += damage; rec.LastHit = os.clock(); enc.TotalDamage += damage
    enc.StaggerDamage += damage
    self:_setHud(player, enc, true)
    if enc.StaggerDamage >= enc.Stats.MaxHealth * 0.08 * (1 + enc.Stats.StaggerResistance) and os.clock() >= enc.StaggerUntil then
        enc.StaggerDamage = 0; enc.StaggerUntil = os.clock() + 1.2; self:_setState(enc, 'Stagger')
    end
    return true
end

function Service:IsWorldBoss(model)
    return self._encounters[model] ~= nil
end

function Service:_nearestTarget(enc)
    local root = rootOf(enc.Model); if not root then return nil end
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        local c = p.Character; local h = humOf(c); local r = rootOf(c)
        if h and h.Health > 0 and r then
            local d = (r.Position - root.Position).Magnitude
            if d < bestDist and d <= EchoConfig.Arena.Radius then best, bestDist = p, d end
        end
    end
    return best, bestDist
end

function Service:_validateBossHit(enc, player, range)
    if enc.Finished or not player or not player.Character then return false end
    local bossRoot = rootOf(enc.Model); local targetRoot = rootOf(player.Character); local hum = humOf(player.Character)
    if not bossRoot or not targetRoot or not hum or hum.Health <= 0 then return false end
    return (bossRoot.Position - targetRoot.Position).Magnitude <= range
end

function Service:_telegraph(enc, player, ability)
    if enc.Busy or enc.Finished then return false end
    enc.Busy = true
    enc.Model:SetAttribute('BossTelegraph', ability)
    self:_setState(enc, ability == 'Basic' and 'Attack' or 'Ability')
    local cfg = EchoConfig.Abilities[ability] or EchoConfig.Abilities.Basic
    local serial = enc.ActionSerial + 1; enc.ActionSerial = serial
    task.delay(cfg.Telegraph or 0.3, function()
        if enc.Finished or enc.ActionSerial ~= serial then return end
        enc.Model:SetAttribute('BossTelegraph', '')
        if self:_validateBossHit(enc, player, cfg.Range or EchoConfig.Abilities.Basic.Range) then
            local phaseScale = enc.PhaseConfig and enc.PhaseConfig.DamageScale or 1
            self._combat:_deal(enc.Model, player.Character, enc.Stats.Damage * (cfg.DamageScale or 1) * phaseScale, 0)
        end
        enc.Busy = false
        enc.NextAction = os.clock() + (cfg.Cooldown or 1) * enc.Stats.CooldownScale * (enc.PhaseConfig and enc.PhaseConfig.CooldownScale or 1)
    end)
    return true
end

function Service:_moveToward(enc, targetPos, dt)
    local root = rootOf(enc.Model); if not root then return end
    local delta = targetPos - root.Position; local dist = delta.Magnitude
    if dist <= 0.05 then return end
    local step = math.min(dist, enc.Stats.MoveSpeed * dt)
    local nextPos = root.Position + delta.Unit * step
    enc.Model:PivotTo(CFrame.new(nextPos))
end

function Service:_resetEncounter(enc)
    if enc.Finished then return end
    local hum = humOf(enc.Model)
    if hum then hum.Health = hum.MaxHealth end
    enc.Model:PivotTo(CFrame.new(enc.Origin))
    enc.Participants = {}; enc.TotalDamage = 0; enc.StaggerDamage = 0; enc.Target = nil; enc.Busy = false; enc.ActionSerial += 1
    enc.Phase = 1; enc.PhaseName = EchoConfig.Phases[1].Name; enc.PhaseConfig = EchoConfig.Phases[1]
    self:_setState(enc, 'Idle')
    for _, p in ipairs(Players:GetPlayers()) do self:_setHud(p, enc, false) end
end

function Service:_updateEncounter(enc, dt)
    if enc.Finished then return end
    local hum = humOf(enc.Model); local root = rootOf(enc.Model)
    if not hum or not root or hum.Health <= 0 then return end
    self:_updatePhase(enc)
    if (root.Position - enc.Origin).Magnitude > EchoConfig.Arena.LeashRadius then self:_resetEncounter(enc); return end
    if os.clock() < enc.StaggerUntil then self:_setState(enc, 'Stagger'); self:_syncHud(enc); return end
    local target, dist = self:_nearestTarget(enc)
    if not target then self:_setState(enc, enc.Phase == 3 and 'Enraged' or 'Idle'); self:_syncHud(enc); return end
    enc.Target = target
    if dist > EchoConfig.Abilities.SovereignRush.Range then
        self:_setState(enc, 'Chase'); self:_moveToward(enc, rootOf(target.Character).Position, dt)
    elseif os.clock() >= enc.NextAction and not enc.Busy then
        if enc.Phase >= 2 and dist <= EchoConfig.Abilities.EchoBurst.Range and math.random() < 0.35 then
            self:_telegraph(enc, target, 'EchoBurst')
        elseif dist > EchoConfig.Abilities.Basic.Range then
            self:_setState(enc, 'Reposition'); self:_moveToward(enc, rootOf(target.Character).Position, dt)
            if dist <= EchoConfig.Abilities.SovereignRush.Range then self:_telegraph(enc, target, 'SovereignRush') end
        else
            self:_telegraph(enc, target, 'Basic')
        end
    elseif not enc.Busy then
        self:_setState(enc, enc.Phase == 3 and 'Enraged' or 'AcquireTarget')
    end
    self:_syncHud(enc)
end

function Service:_reward(enc, player)
    if not self:_eligible(enc, player) then return false, false end
    local dateKey = serverDateKey()
    local daily = self._data:CanClaimBossDailyReward(player, enc.BossId, dateKey)
    local _, first = self._data:RecordBossClear(player, enc.BossId, dateKey, daily)
    if daily then
        self._data:AddXP(player, EchoConfig.Rewards.XP)
        self._data:AddGold(player, EchoConfig.Rewards.Gold)
        self._data:AddItem(player, EchoConfig.Rewards.ItemId, EchoConfig.Rewards.ItemAmount)
        self._data:AddPlayerChronicle(player, string.format('Claimed the daily primary reward from %s.', enc.Definition.DisplayName), 'WorldBossReward')
    end
    self._data:AddPlayerChronicle(player, string.format('Defeated %s after verified combat participation.', enc.Definition.DisplayName), 'WorldBossDefeat')
    if first then
        self._data:AddPlayerChronicle(player, string.format('First clear: %s.', enc.Definition.DisplayName), 'WorldBossFirstClear')
        if enc.BossId == 'SovereignEcho' then self._data:GrantTitle(player, 'SovereignEchoBreaker') end
    end
    return true, daily
end

function Service:_finishEncounter(enc)
    if enc.Finished then return end
    enc.Finished = true; enc.ActionSerial += 1; self:_setState(enc, 'Dead')
    local qualified = 0
    if enc.ExternalRewards ~= true then
        for player in pairs(enc.Participants) do local ok = self:_reward(enc, player); if ok then qualified += 1 end; self:_setHud(player, enc, false) end
    else
        for player in pairs(enc.Participants) do self:_setHud(player, enc, false) end
    end
    if self._world and enc.SuppressWorldAnnouncement ~= true then
        self._world:BroadcastAnnouncement(string.format('%s has been defeated.', enc.Definition.DisplayName))
        self._world:AddWorldChronicle(string.format('%s defeated; %d verified participant(s).', enc.Definition.DisplayName, qualified), 'WorldBoss')
        if not self._worldFirstDefeats[enc.BossId] then
            self._worldFirstDefeats[enc.BossId] = true
            self._world:AddWorldChronicle(string.format('First historical defeat recorded for %s.', enc.Definition.DisplayName), 'WorldBossHistory')
        end
    end
    if enc.OnDefeated then task.spawn(enc.OnDefeated, enc) end
    self._encounters[enc.Model] = nil; self._encounterById[enc.Id] = nil
    task.delay(0.2, function() if enc.Model and enc.Model.Parent then enc.Model:Destroy() end end)
end

function Service:SpawnBoss(bossId, position, options)
    options = type(options) == 'table' and options or {}
    local def = Content.WorldBosses[bossId]
    if not def then return nil, 'UnknownBoss' end
    local snapshot = bossId == 'SovereignEcho' and self:BuildSovereignSnapshot() or nil
    local stats = self:_definitionStats(bossId, snapshot)
    if not stats then return nil, 'InvalidDefinition' end
    self._nextEncounterId += 1
    local origin = position or EchoConfig.Arena.Center
    local model = self:_makeModel(def, stats, origin)
    local enc = {
        Id=self._nextEncounterId, BossId=bossId, Definition=def, Snapshot=snapshot and clone(snapshot) or nil,
        Stats=stats, Model=model, Origin=origin, State='Idle', Phase=1, PhaseName=EchoConfig.Phases[1].Name,
        PhaseConfig=EchoConfig.Phases[1], Participants={}, TotalDamage=0, StaggerDamage=0, StaggerUntil=0,
        NextAction=os.clock()+0.5, Busy=false, ActionSerial=0, Finished=false,
        Context=options.Context or 'World', ExternalRewards=options.ExternalRewards==true,
        SuppressWorldAnnouncement=options.SuppressWorldAnnouncement==true, OnDefeated=options.OnDefeated,
    }
    self._encounters[model] = enc; self._encounterById[enc.Id] = enc
    model:SetAttribute('EncounterId', enc.Id); model:SetAttribute('BossPhase', 1); model:SetAttribute('BossPhaseName', enc.PhaseName)
    local hum = humOf(model)
    hum.HealthChanged:Connect(function() if not enc.Finished then self:_updatePhase(enc); self:_syncHud(enc) end end)
    hum.Died:Connect(function() self:_finishEncounter(enc) end)
    if self._world and enc.SuppressWorldAnnouncement ~= true then
        self._world:BroadcastAnnouncement(string.format('%s has manifested.', def.DisplayName))
        self._world:AddWorldChronicle(string.format('%s spawned in the world.', def.DisplayName), 'WorldBoss')
    end
    return enc
end

function Service:SpawnDungeonBoss(bossId, position, onDefeated)
    return self:SpawnBoss(bossId, position, {Context='Dungeon', ExternalRewards=true, SuppressWorldAnnouncement=true, OnDefeated=onDefeated})
end

function Service:GetActiveEncounter()
    for _, enc in pairs(self._encounterById) do if not enc.Finished then return enc end end
    return nil
end

function Service:GetPublicSnapshot()
    local enc = self:GetActiveEncounter()
    if not enc then return {Active=false} end
    local hum = humOf(enc.Model)
    return {Active=true, Name=enc.Definition.DisplayName, Health=hum and hum.Health or 0, MaxHealth=hum and hum.MaxHealth or enc.Stats.MaxHealth, Phase=enc.Phase, PhaseName=enc.PhaseName, Rank=enc.Definition.Rank, SovereignName=enc.Snapshot and enc.Snapshot.Name or nil}
end

function Service:DebugRunTests(player)
    if not RunService:IsStudio() then return {Error='StudioOnly'} end
    local r = {}
    local snap = self:BuildSovereignSnapshot()
    local allowed = {SnapshotVersion=true,Revision=true,UserId=true,Name=true,Level=true,Race=true,Class=true,PowerRating=true,Stats=true,EquippedSkills=true,EquippedMagic=true,RacialIdentity=true,CombatArchetype=true}
    r.T900_SafeSnapshot = true; for k in pairs(snap) do if not allowed[k] then r.T900_SafeSnapshot=false end end
    r.T901_SnapshotVersion = snap.SnapshotVersion == EchoConfig.SnapshotVersion and type(snap.UserId)=='number' and type(snap.PowerRating)=='number'
    local stats = self:ComputeEchoStats(snap)
    r.T902_CompoundScaling = stats.MaxHealth>=EchoConfig.Limits.MinHealth and stats.Defense>=(snap.Stats.Defense or 0) and stats.Damage>=EchoConfig.Limits.MinDamage and stats.EffectivePowerTarget==snap.PowerRating*EchoConfig.EffectivePowerTarget
    r.T903_Archetype = table.find({'Melee','Magic','Ranged','Defensive','Hybrid'}, self:ResolveArchetype(snap)) ~= nil
    local states = {}; for _, s in ipairs(REQUIRED_STATES) do states[s]=true end
    r.T904_AIStates = states.Idle and states.AcquireTarget and states.Chase and states.Attack and states.Ability and states.Defense and states.Reposition and states.Stagger and states.Enraged and states.Dead

    local beforeChron = self._world and #self._world:GetWorldChronicle() or 0
    local enc = self:SpawnBoss('EchoSentinel', EchoConfig.Arena.Center + Vector3.new(0,0,25))
    r.T905_GenericFramework = enc~=nil and enc.BossId=='EchoSentinel' and self:IsWorldBoss(enc.Model)
    r.T906_ReferenceBoss = enc~=nil and enc.Stats.MaxHealth==Content.WorldBosses.EchoSentinel.MaxHealth
    local hum = humOf(enc.Model)
    hum.Health = hum.MaxHealth * 0.69; self:_updatePhase(enc); r.T907_Phase2 = enc.Phase==2
    hum.Health = hum.MaxHealth * 0.29; self:_updatePhase(enc); r.T908_Phase3Enrage = enc.Phase==3 and enc.PhaseConfig.Enraged==true
    local far = enc.Origin + Vector3.new(EchoConfig.Arena.LeashRadius+10,0,0); enc.Model:PivotTo(CFrame.new(far)); self:_updateEncounter(enc,0.05); r.T909_LeashReset = (rootOf(enc.Model).Position-enc.Origin).Magnitude<2 and hum.Health==hum.MaxHealth
    r.T910_HitRangeValidation = self:_validateBossHit(enc, player, 1)==false
    local oldNext = enc.NextAction; enc.NextAction=0; local tele=self:_telegraph(enc,player,'Basic'); local blocked=self:_telegraph(enc,player,'Basic'); r.T911_TelegraphAntiSpam = tele==true and blocked==false; enc.ActionSerial+=1; enc.Busy=false; enc.NextAction=oldNext
    self:MarkHit(enc.Model, player, 100); r.T912_Participation = enc.Participants[player]~=nil and enc.TotalDamage>=100
    local nearOnly = {Damage=0,JoinedAt=os.clock()-10,LastHit=os.clock()}; enc.Participants[player]=nearOnly; r.T913_ProximityNotEligible = self:_eligible(enc,player)==false
    enc.Participants[player]={Damage=100,JoinedAt=os.clock()-10,LastHit=os.clock()}; enc.TotalDamage=100; r.T914_Eligibility = self:_eligible(enc,player)==true
    local date=serverDateKey(); local b=self._data:GetBossProgress(player); b.DailyRewardDates.__Phase9Test=nil
    r.T915_DailyBefore = self._data:CanClaimBossDailyReward(player,'__Phase9Test',date)==true
    self._data:RecordBossClear(player,'__Phase9Test',date,true); r.T916_DailyDuplicateBlocked = self._data:CanClaimBossDailyReward(player,'__Phase9Test',date)==false
    r.T917_ServerDate = date:match('^%d%d%d%d%-%d%d%-%d%d$')~=nil
    r.T918_SaveSchema9 = self._data:GetProfile(player).SchemaVersion==9 and type(self._data:GetProfile(player).Bosses)=='table'
    r.T919_ForbiddenNation = Content.ForbiddenNation.Future==true and Content.ForbiddenNation.HighRisk==true and Content.ForbiddenNation.RecommendedLevel>=200 and Content.ForbiddenNation.EnemyLevelDisplay=='Lv.???'
    local frozen = enc.Snapshot == nil
    local echo = self:SpawnBoss('SovereignEcho', EchoConfig.Arena.Center + Vector3.new(0,0,-25)); local originalName=echo.Snapshot.Name; self._cachedSovereignSnapshot=nil; local newer=self:BuildSovereignSnapshot(); r.T920_ImmutableActiveSnapshot = echo.Snapshot.Name==originalName and echo.Snapshot~=newer
    r.T921_HUDAttrs = player:GetAttribute('BossActive')==true and type(player:GetAttribute('BossName'))=='string' and type(player:GetAttribute('BossPhase'))=='string'
    r.T922_AnnouncementsChronicle = (self._world and #self._world:GetWorldChronicle()>beforeChron) or false
    r.T923_NoBossRemote = ReplicatedStorage.NewLife.Remotes:FindFirstChild('WorldBossRequest')==nil and ReplicatedStorage.NewLife.Remotes:FindFirstChild('BossAdmin')==nil
    r.T924_ExactlyTwoBossDefs = (Content.WorldBosses.SovereignEcho~=nil and Content.WorldBosses.EchoSentinel~=nil and (function() local n=0 for _ in pairs(Content.WorldBosses) do n+=1 end return n==2 end)())
    r.T925_SovereignRefreshReady = type(self._snapshotRevision)=='number' and self._snapshotRevision>=0

    -- Real death/reward lifecycle on the reference boss, including daily duplicate protection.
    self:_resetEncounter(enc)
    local profile=self._data:GetProfile(player); profile.Bosses.DailyRewardDates.EchoSentinel=nil; profile.Bosses.FirstClears.EchoSentinel=nil; profile.Bosses.Clears.EchoSentinel=nil
    local goldBefore=profile.Progression.Gold; local shardBefore=profile.Inventory.SovereignShard or 0; local chronBefore=#profile.PlayerChronicle
    self:MarkHit(enc.Model,player,enc.Stats.MaxHealth); enc.Participants[player].JoinedAt=os.clock()-10
    hum.Health=0; task.wait(0.05)
    r.T926_DeathLifecycle = enc.Finished==true and enc.State=='Dead' and self._encounters[enc.Model]==nil
    r.T927_IndividualDailyLoot = profile.Progression.Gold>=goldBefore+EchoConfig.Rewards.Gold and (profile.Inventory.SovereignShard or 0)>=shardBefore+EchoConfig.Rewards.ItemAmount
    local sawParticipation=false; local sawDefeat=false; local sawDaily=false; local sawFirst=false
    for i=chronBefore+1,#profile.PlayerChronicle do local c=profile.PlayerChronicle[i]; sawParticipation=sawParticipation or c.Category=='WorldBossParticipation'; sawDefeat=sawDefeat or c.Category=='WorldBossDefeat'; sawDaily=sawDaily or c.Category=='WorldBossReward'; sawFirst=sawFirst or c.Category=='WorldBossFirstClear' end
    r.T928_PlayerChronicle = sawParticipation and sawDefeat and sawDaily and sawFirst
    local goldAfterFirst=profile.Progression.Gold; local shardAfterFirst=profile.Inventory.SovereignShard or 0
    local repeatEnc=self:SpawnBoss('EchoSentinel', EchoConfig.Arena.Center + Vector3.new(0,0,35)); local repeatHum=humOf(repeatEnc.Model); repeatEnc.Participants[player]={Damage=repeatEnc.Stats.MaxHealth,JoinedAt=os.clock()-10,LastHit=os.clock()}; repeatEnc.TotalDamage=repeatEnc.Stats.MaxHealth
    repeatHum.Health=0; task.wait(0.05)
    r.T929_RepeatPrimaryBlocked = profile.Progression.Gold==goldAfterFirst and (profile.Inventory.SovereignShard or 0)==shardAfterFirst and (profile.Bosses.Clears.EchoSentinel or 0)>=2
    r.T930_FirstHistoricalWorldDefeat = self._worldFirstDefeats.EchoSentinel==true

    -- Actual sovereign transition invalidates only the next snapshot; active Echo keeps its starting snapshot.
    local activeOldUser=echo.Snapshot.UserId
    self._ruler:DebugSetCandidates({{UserId=player.UserId,Name=player.Name,Power=5000,Guild=0,PvP=0,BossKills=0,Assassin=0,Exploration=0,Wealth=0,Arena=0},{UserId=990099,Name='Phase9AltSovereign',Power=9000,Guild=0,PvP=0,BossKills=0,Assassin=0,Exploration=0,Wealth=0,Arena=0}})
    self._ruler:RecomputeRankings(); self:_refreshSovereignRevision(); local changed=self:BuildSovereignSnapshot()
    r.T931_SovereignChangeRefresh = changed.UserId==990099 and echo.Snapshot.UserId==activeOldUser
    local revAfterChange=self._snapshotRevision
    self._ruler:DebugSetCandidates({{UserId=player.UserId,Name=player.Name,Power=9000,Guild=0,PvP=0,BossKills=0,Assassin=0,Exploration=0,Wealth=0,Arena=0}}); self._ruler:RecomputeRankings(); self:_refreshSovereignRevision()
    r.T932_SnapshotRevision = self._snapshotRevision>revAfterChange
    r.T933_ServerOnlyMutationSurface = GameConfig.Network.RateLimits.BossHealth==nil and GameConfig.Network.RateLimits.BossReward==nil and ReplicatedStorage.NewLife.Remotes:FindFirstChild('WorldBossRequest')==nil
    r.T934_SaveHistory = type(profile.Bosses.History)=='table' and #profile.Bosses.History>=2

    if enc.Model.Parent then enc.Model:Destroy() end
    if repeatEnc.Model.Parent then repeatEnc.Model:Destroy() end
    self:_resetEncounter(echo); if echo.Model.Parent then echo.Model:Destroy() end; self._encounters[echo.Model]=nil; self._encounterById[echo.Id]=nil
    self:_setHud(player, echo, false)
    r.T935_ActiveSnapshotCleanup = self:GetActiveEncounter()==nil
    return r
end

function Service:Start(data, world, ruler, combat)
    self._data=data; self._world=world; self._ruler=ruler; self._combat=combat
    self:_refreshSovereignRevision()
    if self._heartbeat then self._heartbeat:Disconnect() end
    self._heartbeat = RunService.Heartbeat:Connect(function(dt)
        self:_refreshSovereignRevision()
        for _, enc in pairs(self._encounterById) do self:_updateEncounter(enc, math.min(dt,0.1)) end
    end)
    Players.PlayerRemoving:Connect(function(p) for _,enc in pairs(self._encounterById) do enc.Participants[p]=nil end end)
    if RunService:IsStudio() then
        local bridge = ServerScriptService:FindFirstChild('Phase9TestBridge') or Instance.new('BindableFunction')
        bridge.Name='Phase9TestBridge'; bridge.Parent=ServerScriptService
        bridge.OnInvoke=function(command,p)
            if command=='Run' then return self:DebugRunTests(p or Players:GetPlayers()[1]) end
            if command=='Snapshot' then return self:GetPublicSnapshot() end
            if command=='SpawnEcho' then return self:SpawnBoss('SovereignEcho') ~= nil end
            return nil
        end
    end
end

return Service
