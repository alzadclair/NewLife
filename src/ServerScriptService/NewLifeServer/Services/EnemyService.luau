--!strict
local CollectionService = game:GetService('CollectionService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)

local Service = {
    _started = false,
    _state = nil,
    _combat = nil,
    _progression = nil,
    _quest = nil,
    _dungeon = nil,
    _guild = nil,
    _enemies = {},
    _lastAttack = {},
    _acc = 0,
}

local function makeRig(enemyId, pos)
    local def = Content.Enemies[enemyId]
    if not def then return nil end
    local model = Instance.new('Model')
    model.Name = def.DisplayName
    model:SetAttribute('EnemyId', enemyId)
    model:SetAttribute('EnemyKind', def.Kind)

    local root = Instance.new('Part')
    root.Name = 'HumanoidRootPart'
    root.Size = Vector3.new(2, 2, 1)
    root.Anchored = false
    root.CanCollide = true
    root.Position = pos
    root.Parent = model

    local head = Instance.new('Part')
    head.Name = 'Head'
    head.Size = Vector3.new(2, 1, 1)
    head.Position = pos + Vector3.new(0, 2, 0)
    head.Parent = model

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = root
    weld.Part1 = head
    weld.Parent = root

    local hum = Instance.new('Humanoid')
    hum.MaxHealth = def.MaxHealth
    hum.Health = def.MaxHealth
    hum.WalkSpeed = GameConfig.Combat.EnemyMoveSpeed
    hum.Parent = model

    model.PrimaryPart = root
    local folder = workspace:FindFirstChild('NewLife') and workspace.NewLife:FindFirstChild('NPCs')
    model.Parent = folder or workspace
    CollectionService:AddTag(model, 'NL_Enemy')

    model:SetAttribute('Strength', def.Strength)
    model:SetAttribute('Defense', def.Defense)
    model:SetAttribute('Power', def.Power)
    model:SetAttribute('Health', def.MaxHealth)
    model:SetAttribute('MaxHealth', def.MaxHealth)
    return model
end

function Service:SpawnEnemy(enemyId, pos)
    local model = makeRig(enemyId, pos)
    if not model then return nil end
    self._enemies[model] = {id = enemyId, lastHit = nil}

    if not self._state then
        local services = script.Parent
        local StateService = services and services:FindFirstChild('StateService') and require(services.StateService)
        self._state = StateService
    end
    if self._state then
        self._state:ClearTransient(model)
        self._state:SetState(model, 'Dead', false)
        self._state:SetState(model, 'Alive', true)
    end

    local hum = model:FindFirstChildOfClass('Humanoid')
    if hum then
        hum.HealthChanged:Connect(function(h)
            if model.Parent then model:SetAttribute('Health', math.max(0, h)) end
        end)
        hum.Died:Connect(function() self:_onDied(model) end)
    end
    return model
end

function Service:MarkHit(model, player)
    local e = self._enemies[model]
    if e then e.lastHit = player end
end

function Service:_onDied(model)
    local e = self._enemies[model]
    if not e then return end
    if self._state then
        self._state:SetState(model, 'Alive', false)
        self._state:SetState(model, 'Dead', true)
    end
    local killer = e.lastHit
    local enemyId = e.id
    if killer and killer.Parent == Players then
        if self._progression then self._progression:RewardEnemy(killer, enemyId) end
        if self._quest then self._quest:OnEnemyKilled(killer, enemyId) end
        if self._dungeon then self._dungeon:OnEnemyKilled(killer, enemyId) end
        if self._guild then self._guild:AddProgressionXP(killer, GameConfig.Guilds.EnemyKillXP) end
    end
    self._enemies[model] = nil
    local def = Content.Enemies[enemyId]
    if def and def.RespawnSeconds and def.RespawnSeconds > 0 then
        local pos = model:GetPivot().Position
        task.delay(def.RespawnSeconds, function()
            if self._started then self:SpawnEnemy(enemyId, pos) end
        end)
    end
    task.delay(0.2, function()
        if model.Parent then model:Destroy() end
    end)
end

function Service:GetNearestEnemy(pos, maxDist)
    local best = nil
    local dmax = maxDist or 60
    for m in pairs(self._enemies) do
        local root = m:FindFirstChild('HumanoidRootPart')
        local hum = m:FindFirstChildOfClass('Humanoid')
        if root and root:IsA('BasePart') and hum and hum.Health > 0 then
            local d = (root.Position - pos).Magnitude
            if d < dmax then best = m; dmax = d end
        end
    end
    return best
end

function Service:_nearestPlayer(pos)
    local best = nil
    local bd = GameConfig.Combat.EnemyDetectRange
    for _, p in Players:GetPlayers() do
        local c = p.Character
        local r = c and c:FindFirstChild('HumanoidRootPart')
        local h = c and c:FindFirstChildOfClass('Humanoid')
        if c and r and r:IsA('BasePart') and h and h.Health > 0 then
            local d = (r.Position - pos).Magnitude
            if d < bd then best = c; bd = d end
        end
    end
    return best
end

function Service:Start(state, combat, progression, quest, dungeon, guild)
    if self._started then return end
    self._started = true
    self._state = state
    self._combat = combat
    self._progression = progression
    self._quest = quest
    self._dungeon = dungeon
    self._guild = guild

    local folder = workspace.NewLife:FindFirstChild('NPCs') or Instance.new('Folder')
    folder.Name = 'NPCs'
    folder.Parent = workspace.NewLife
    for _, m in ipairs(folder:GetChildren()) do
        if m:GetAttribute('EnemyId') then m:Destroy() end
    end
    self:SpawnEnemy('TrainingSlime', Vector3.new(14, 3, 0))
    self:SpawnEnemy('StoneBrute', Vector3.new(26, 3, 0))

    RunService.Heartbeat:Connect(function(dt)
        self._acc += dt
        if self._acc < 0.1 then return end
        self._acc = 0

        for m in pairs(self._enemies) do
            local root = m:FindFirstChild('HumanoidRootPart')
            local hum = m:FindFirstChildOfClass('Humanoid')
            if not root or not hum or hum.Health <= 0 then continue end
            local target = self:_nearestPlayer(root.Position)
            if not target then continue end
            local tr = target:FindFirstChild('HumanoidRootPart')
            if not tr or not tr:IsA('BasePart') then continue end
            local delta = tr.Position - root.Position
            local dist = delta.Magnitude
            if dist > GameConfig.Combat.EnemyAttackRange then
                local d = Vector3.new(delta.X, 0, delta.Z)
                if d.Magnitude > 0.01 then hum:Move(d.Unit, false) end
            else
                local last = self._lastAttack[m] or 0
                if os.clock() - last >= GameConfig.Combat.EnemyAttackCooldown then
                    self._lastAttack[m] = os.clock()
                    if self._combat then self._combat:HandleEnemyAttack(m, target) end
                end
            end
        end
    end)
end

return Service
