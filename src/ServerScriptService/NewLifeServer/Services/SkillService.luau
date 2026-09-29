--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local G = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local C = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local Content = C

local S = {
    _started = false,
    _data = nil,
    _combat = nil,
    _cooldowns = {} :: {[Player]: {[string]: number}},
}

local function cd(self, p, id)
    local t = self._cooldowns[p]
    if not t then
        t = {}
        self._cooldowns[p] = t
    end
    return t, id
end

local function targetHumanoid(target)
    if not target then return nil, nil end
    local model = target:IsA('Model') and target or target:FindFirstAncestorOfClass('Model')
    if not model then return nil, nil end
    local hum = model:FindFirstChildOfClass('Humanoid')
    return hum, model
end

local function spend(c: Model, res: string, amount: number): boolean
    local cur = c:GetAttribute(res) or 0
    if cur < amount then return false end
    c:SetAttribute(res, math.max(0, cur - amount))
    return true
end

function S:GainMastery(p: Player, id: string, base: number)
    local pr = self._data:GetProfile(p)
    local def = C.Skills[id]
    if not pr or not def then return 0 end

    local mult = 1.0
    if def.Type == 'Class' then
        mult = 0.5 + ((pr.Progression.ClassAptitude or 50) / 100)
    end
    -- Human racial passive bonus
    if pr.Build.Unlocked and pr.Build.Unlocked.AdaptivePotential then
        mult = mult * 1.10
    end

    local gain = math.max(1, math.floor(base * mult))
    pr.Build.Mastery[id] = (pr.Build.Mastery[id] or 0) + gain

    -- 1. Route Race Progression
    local curRace = pr.Identity.Race
    if def.Type == 'Racial' and pr.Build.RaceProgress and pr.Build.RaceProgress[curRace] then
        local rProg = pr.Build.RaceProgress[curRace]
        rProg.Mastery = (rProg.Mastery or 0) + gain
        rProg.Level = math.floor(rProg.Mastery / 50) + 1
    end

    -- 2. Route Class Progression
    local curClass = pr.Identity.Class
    if def.Type == 'Class' and pr.Build.ClassProgress and pr.Build.ClassProgress[curClass] then
        local cProg = pr.Build.ClassProgress[curClass]
        cProg.Mastery = (cProg.Mastery or 0) + gain
        cProg.Level = math.floor(cProg.Mastery / 50) + 1
    end

    -- 3. Check Class Unlocks by Mastery
    local classDef = Content.Classes[curClass]
    if classDef and classDef.Unlocks and pr.Build.ClassProgress[curClass] then
        local cMst = pr.Build.ClassProgress[curClass].Mastery
        for reqMst, skillsToUnlock in pairs(classDef.Unlocks) do
            if cMst >= reqMst then
                for _, uId in ipairs(skillsToUnlock) do
                    if not pr.Build.Unlocked[uId] then
                        pr.Build.Unlocked[uId] = true
                    end
                end
            end
        end
    end

    -- 4. Check Hybrid Secondary Active Unlock
    if pr.Birth and pr.Birth.IsHybrid and pr.Birth.SecondaryRace then
        local secRaceDef = Content.Races[pr.Birth.SecondaryRace]
        local rMst = pr.Build.RaceProgress[curRace] and pr.Build.RaceProgress[curRace].Mastery or 0
        if secRaceDef and secRaceDef.ActiveSkill and rMst >= (G.Progression.HybridSecondaryActiveUnlockMastery or 40) then
            if not pr.Build.Unlocked[secRaceDef.ActiveSkill] then
                pr.Build.Unlocked[secRaceDef.ActiveSkill] = true
            end
        end
    end

    -- 5. Evolution continuous racial progression (Canon: unbounded preparation beyond Lv1000)
    if id == 'Evolution' then
        local m = pr.Build.Mastery.Evolution or 0
        local stage = 1
        if m >= 300 then
            stage = 4 -- LimitBreaker
        elseif m >= 150 then
            stage = 3 -- Apex
        elseif m >= 50 then
            stage = 2 -- Resilience
        end
        pr.Build.EvolutionStage = stage
    end

    -- 6. Defier of Fate: advances ONLY when mastering a class outside natural aptitude (<60)
    if def.Type == 'Class' and (pr.Progression.ClassAptitude or 100) < (G.Progression.DefierAptitudeThreshold or 60) then
        pr.Build.DefierProgress = (pr.Build.DefierProgress or 0) + 1
        if pr.Build.DefierProgress >= G.Progression.DefierThreshold then
            pr.Build.DefierOfFate = true
        end
    end

    self._data:Apply(p)
    return gain
end

function S:Use(p: Player, id: string, target: any)
    local pr = self._data:GetProfile(p)
    local c = p.Character
    local def = C.Skills[id]
    if not pr or not c or not def or not def.Active or not pr.Build.Unlocked[id] then
        return false, 'Locked'
    end
    if (pr.Progression.Level or 0) < ((def.Requirements and def.Requirements.Level) or 0) then
        return false, 'Requirement'
    end

    local t, k = cd(self, p, id)
    local now = os.clock()
    if now - (t[k] or 0) < def.Cooldown then
        return false, 'Cooldown'
    end

    local hum, model = targetHumanoid(target)
    if def.Range > 0 then
        local root = c:FindFirstChild('HumanoidRootPart')
        local tr = model and model:FindFirstChild('HumanoidRootPart')
        if not root or not tr or (root.Position - tr.Position).Magnitude > def.Range then
            return false, 'Range'
        end
    end

    if not spend(c, def.Resource, def.Cost) then
        return false, 'Resource'
    end
    t[k] = now

    -- Damage application
    if def.Damage and hum and hum.Health > 0 then
        local dmg = def.Damage
        if not pr.Progression.HasMagic and def.Type ~= 'Magic' then
            dmg = dmg * G.Progression.NoMagicPhysicalBonus
        end
        hum:TakeDamage(dmg)
        if self._combat and self._combat._enemyService and model then
            self._combat._enemyService:MarkHit(model, p)
        end
    end

    if id == 'Evolution' then
        pr.Legacy.Score = (pr.Legacy.Score or 0) + 1
    end

    self:GainMastery(p, id, def.MasteryGain or G.Progression.MasteryBaseGain)
    self._data:Apply(p)

    -- Skill Specific Behaviors (applied after Apply so character attributes reflect active buff/heal/restore)
    if id == 'FieldMedicine' then
        local charHum = c:FindFirstChildOfClass('Humanoid')
        local maxH = c:GetAttribute('MaxHealth') or 100
        local curH = c:GetAttribute('Health') or (charHum and charHum.Health) or maxH
        local newH = math.min(maxH, curH + (def.Heal or 25))
        c:SetAttribute('Health', newH)
        if charHum then charHum.Health = newH end
    elseif id == 'StoneSkin' then
        local oldDef = c:GetAttribute('Defense') or 0
        c:SetAttribute('Defense', oldDef + (def.DefenseBuff or 10))
        task.delay(def.BuffDuration or 6, function()
            if c and c.Parent then
                c:SetAttribute('Defense', math.max(0, (c:GetAttribute('Defense') or 0) - (def.DefenseBuff or 10)))
            end
        end)
    elseif id == 'BattleCry' then
        local oldDef = c:GetAttribute('Defense') or 0
        c:SetAttribute('Defense', oldDef + (def.DefenseBuff or 8))
        task.delay(def.BuffDuration or 6, function()
            if c and c.Parent then
                c:SetAttribute('Defense', math.max(0, (c:GetAttribute('Defense') or 0) - (def.DefenseBuff or 8)))
            end
        end)
    elseif id == 'FeralRoar' then
        local oldStr = c:GetAttribute('Strength') or 0
        c:SetAttribute('Strength', oldStr + (def.StrengthBuff or 6))
        task.delay(def.BuffDuration or 6, function()
            if c and c.Parent then
                c:SetAttribute('Strength', math.max(0, (c:GetAttribute('Strength') or 0) - (def.StrengthBuff or 6)))
            end
        end)
    elseif id == 'ManaFlow' then
        local maxM = c:GetAttribute('MaxMana') or 100
        local curM = c:GetAttribute('Mana') or 0
        c:SetAttribute('Mana', math.min(maxM, curM + (def.ManaRestore or 25)))
    end

    return true, 'OK'
end

function S:Equip(p: Player, slot: number, id: string): (boolean, string)
    local pr = self._data:GetProfile(p)
    local def = C.Skills[id]
    if not pr or not def or not pr.Build.Unlocked[id] then
        return false, 'Invalid'
    end
    if def.Type == 'Magic' then
        if slot < 1 or slot > 2 then return false, 'SlotRange' end
        pr.Build.MagicSlots[slot] = id
    else
        if slot < 1 or slot > 2 then return false, 'SlotRange' end
        pr.Build.SkillSlots[slot] = id
    end
    self._data:Apply(p)
    return true, 'OK'
end

function S:Start(dataService, combatService)
    self._data = dataService
    self._combat = combatService
    self._started = true
end

return S
