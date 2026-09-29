--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)

local CharacterService = {
    _started = false,
    _dataService = nil,
    _stateService = nil,
    _regenAccumulator = 0,
}

local function numberAttr(instance: Instance, name: string, fallback: number): number
    local value = instance:GetAttribute(name)
    return type(value) == "number" and value or fallback
end

local function horizontalDirection(character: Model, requested: Vector3?): Vector3
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return Vector3.zAxis end
    local direction = requested
    if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.05 then
        direction = root.CFrame.LookVector
    end
    direction = Vector3.new(direction.X, 0, direction.Z)
    if direction.Magnitude < 0.05 then direction = Vector3.new(0, 0, -1) end
    return direction.Unit
end

function CharacterService:_setupCharacter(player: Player, character: Model)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid or not humanoid:IsA("Humanoid") then return end
    if player:GetAttribute("ProfileLoaded") ~= true and self._dataService then
        self._dataService:LoadPlayer(player)
    end

    local maxHealth = numberAttr(player, "Health", 100)
    local maxMana = numberAttr(player, "Mana", 100)
    local maxStamina = numberAttr(player, "Stamina", 100)
    humanoid.MaxHealth = maxHealth
    humanoid.Health = maxHealth
    humanoid.WalkSpeed = GameConfig.Character.WalkSpeed

    character:SetAttribute("Health", maxHealth)
    character:SetAttribute("MaxHealth", maxHealth)
    character:SetAttribute("Mana", maxMana)
    character:SetAttribute("MaxMana", maxMana)
    character:SetAttribute("Stamina", maxStamina)
    character:SetAttribute("MaxStamina", maxStamina)
    character:SetAttribute("Strength", numberAttr(player, "Strength", 10))
    character:SetAttribute("Defense", numberAttr(player, "Defense", 5))
    character:SetAttribute("Power", numberAttr(player, "Power", 10))

    self._stateService:ClearTransient(character)
    self._stateService:SetState(character, "Dead", false)
    self._stateService:SetState(character, "Alive", true)

    humanoid.HealthChanged:Connect(function(health)
        if character.Parent then character:SetAttribute("Health", math.max(0, health)) end
    end)
    humanoid.Died:Connect(function()
        if self._progressionService and not character:GetAttribute("DeathPenaltyApplied") then character:SetAttribute("DeathPenaltyApplied",true); self._dataService:ApplyDeathPenalty(player) end
        self._stateService:ClearTransient(character)
        self._stateService:SetState(character, "Alive", false)
        self._stateService:SetState(character, "Dead", true)
    end)
end

function CharacterService:IsActionable(player: Player): boolean
    local character = player.Character
    if not character then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    return not self._stateService:IsInState(character, "Dead") and not self._stateService:IsInState(character, "Stunned")
end

function CharacterService:SpendStamina(character: Model, amount: number): boolean
    local stamina = numberAttr(character, "Stamina", 0)
    if stamina < amount then return false end
    character:SetAttribute("Stamina", math.max(0, stamina - amount))
    return true
end

function CharacterService:SetSprint(player: Player, enabled: boolean): boolean
    local character = player.Character
    if not character or not self:IsActionable(player) then return false end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return false end
    if enabled and (numberAttr(character, "Stamina", 0) <= 0 or self._stateService:IsInState(character, "Blocking")) then return false end
    self._stateService:SetState(character, "Sprinting", enabled)
    humanoid.WalkSpeed = enabled and GameConfig.Character.SprintWalkSpeed or GameConfig.Character.WalkSpeed
    return true
end

function CharacterService:SetBlock(player: Player, enabled: boolean): boolean
    local character = player.Character
    if not character or not self:IsActionable(player) then return false end
    if enabled and (self._stateService:IsInState(character, "Dodging") or self._stateService:IsInState(character, "Dashing")) then return false end
    if enabled then self:SetSprint(player, false) end
    self._stateService:SetState(character, "Blocking", enabled)
    return true
end

function CharacterService:_mobility(player: Player, stateName: string, direction: Vector3?, staminaCost: number, speed: number, duration: number): boolean
    local character = player.Character
    if not character or not self:IsActionable(player) then return false end
    if self._stateService:IsInState(character, "Attacking") or self._stateService:IsInState(character, "Blocking") then return false end
    if not self:SpendStamina(character, staminaCost) then return false end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return false end
    self:SetSprint(player, false)
    self._stateService:SetState(character, stateName, true)
    local dir = horizontalDirection(character, direction)
    local requestedDistance = speed * duration
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    local hit = workspace:Raycast(root.Position, dir * requestedDistance, params)
    local travelDistance = requestedDistance
    if hit then
        travelDistance = math.max(0, hit.Distance - 2)
    end
    if travelDistance > 0 then
        character:PivotTo(character:GetPivot() + dir * travelDistance)
    end
    task.delay(duration, function()
        if character.Parent then
            self._stateService:SetState(character, stateName, false)
        end
    end)
    return true
end

function CharacterService:Dodge(player: Player, direction: Vector3?): boolean
    return self:_mobility(player, "Dodging", direction, GameConfig.Combat.DodgeStaminaCost, GameConfig.Combat.DodgeSpeed, GameConfig.Combat.DodgeDuration)
end

function CharacterService:Dash(player: Player, direction: Vector3?): boolean
    return self:_mobility(player, "Dashing", direction, GameConfig.Combat.DashStaminaCost, GameConfig.Combat.DashSpeed, GameConfig.Combat.DashDuration)
end

function CharacterService:Start(dataService, stateService, progressionService)
    if self._started then return end
    self._started = true
    self._dataService = dataService
    self._stateService = stateService
    self._progressionService = progressionService
    Players.RespawnTime = GameConfig.Combat.RespawnSeconds

    local function attachPlayer(player: Player)
        player.CharacterAdded:Connect(function(character) self:_setupCharacter(player, character) end)
        if player.Character then task.spawn(function() self:_setupCharacter(player, player.Character :: Model) end) end
    end
    Players.PlayerAdded:Connect(attachPlayer)
    for _, player in Players:GetPlayers() do attachPlayer(player) end

    RunService.Heartbeat:Connect(function(dt)
        self._regenAccumulator += dt
        if self._regenAccumulator < GameConfig.Character.ResourceTickSeconds then return end
        local step = self._regenAccumulator
        self._regenAccumulator = 0
        for _, player in Players:GetPlayers() do
            local character = player.Character
            if not character or not self._stateService:IsInState(character, "Alive") then continue end
            local mana = numberAttr(character, "Mana", 0)
            local maxMana = numberAttr(character, "MaxMana", mana)
            character:SetAttribute("Mana", math.min(maxMana, mana + GameConfig.Character.ManaRegenPerSecond * step))
            local stamina = numberAttr(character, "Stamina", 0)
            local maxStamina = numberAttr(character, "MaxStamina", stamina)
            if self._stateService:IsInState(character, "Sprinting") then
                stamina = math.max(0, stamina - GameConfig.Character.SprintStaminaPerSecond * step)
                character:SetAttribute("Stamina", stamina)
                if stamina <= 0 then self:SetSprint(player, false) end
            elseif not self._stateService:IsInState(character, "Blocking") then
                character:SetAttribute("Stamina", math.min(maxStamina, stamina + GameConfig.Character.StaminaRegenPerSecond * step))
            end
        end
    end)
end

return CharacterService
