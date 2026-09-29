--!strict
local Config = {
    SnapshotVersion = 1,
    EffectivePowerTarget = 10,
    Arena = {Center = Vector3.new(165, 3, 105), Radius = 85, LeashRadius = 95, ResetSeconds = 8},
    Scaling = {
        Health = 4.6,
        Defense = 2.15,
        Damage = 2.45,
        MoveSpeed = 1.30,
        Resource = 2.0,
        Cooldown = 0.68,
        SkillFrequency = 1.55,
        BossResistance = 0.35,
        StaggerResistance = 0.70,
    },
    Limits = {MinHealth = 800, MaxHealth = 250000, MinDamage = 18, MaxDamage = 600, MaxMoveSpeed = 26},
    Phases = {
        {Id = 1, Name = 'Echo Manifested', MinRatio = 0.70, CooldownScale = 1.00, MoveScale = 1.00, DamageScale = 1.00},
        {Id = 2, Name = 'Sovereign Resonance', MinRatio = 0.30, CooldownScale = 0.82, MoveScale = 1.10, DamageScale = 1.10},
        {Id = 3, Name = 'Echo Ascendant', MinRatio = 0.00, CooldownScale = 0.62, MoveScale = 1.22, DamageScale = 1.22, Enraged = true},
    },
    Abilities = {
        Basic = {Range = 7, Cooldown = 1.25, Telegraph = 0.30, DamageScale = 0.80},
        EchoBurst = {Range = 18, Cooldown = 6.0, Telegraph = 0.75, DamageScale = 1.10},
        SovereignRush = {Range = 30, Cooldown = 8.0, Telegraph = 0.55, DamageScale = 1.25},
        GuardEcho = {Cooldown = 10.0, Duration = 2.5, DefenseScale = 1.65},
    },
    Eligibility = {MinDamageShare = 0.02, MinDamage = 10, MinActiveSeconds = 1},
    Rewards = {XP = 900, Gold = 450, ItemId = 'SovereignShard', ItemAmount = 1},
    ReferenceBoss = {Id = 'EchoSentinel', DisplayName = 'Echo Sentinel', Rank = 'A', MaxHealth = 600, Damage = 16, Defense = 8, MoveSpeed = 10},
    ForbiddenNation = {Id = 'ForbiddenNation', DisplayName = 'Mysterious Nation', Future = true, HighRisk = true, RecommendedLevel = 200, EnemyLevelDisplay = 'Lv.???'},
}
for _, phase in ipairs(Config.Phases) do table.freeze(phase) end
table.freeze(Config.Phases)
table.freeze(Config.Scaling)
table.freeze(Config.Limits)
table.freeze(Config.Arena)
table.freeze(Config.Abilities.Basic)
table.freeze(Config.Abilities.EchoBurst)
table.freeze(Config.Abilities.SovereignRush)
table.freeze(Config.Abilities.GuardEcho)
table.freeze(Config.Abilities)
table.freeze(Config.Eligibility)
table.freeze(Config.Rewards)
table.freeze(Config.ReferenceBoss)
table.freeze(Config.ForbiddenNation)
table.freeze(Config)
return Config
