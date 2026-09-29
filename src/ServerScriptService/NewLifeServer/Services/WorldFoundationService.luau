--!strict
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

local Config = require(ReplicatedStorage.NewLife.Shared.Config.WorldFoundationConfig)

local Service = {
    _started = false,
    _enemy = nil,
    _dungeon = nil,
    _world = nil,
    _zoneEnemies = {} :: {Instance},
}

local function horizontalDistance(a: Vector3, b: Vector3): number
    return (Vector3.new(a.X,0,a.Z)-Vector3.new(b.X,0,b.Z)).Magnitude
end

function Service:GetRegionAt(position: Vector3)
    local bestName, best, bestDistance = nil, nil, math.huge
    for name, region in pairs(Config.Regions) do
        local dist = horizontalDistance(position, region.Center)
        if dist <= region.Radius and dist < bestDistance then
            bestName, best, bestDistance = name, region, dist
        end
    end
    return bestName, best
end

function Service:GetBiomeAt(position: Vector3): string?
    local _, region = self:GetRegionAt(position)
    return region and region.Biome or nil
end

function Service:_applyPlayerRegion(player: Player)
    local character = player.Character
    local root = character and character:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then return end
    local regionId, region = self:GetRegionAt(root.Position)
    player:SetAttribute('WorldRegionId', regionId or '')
    player:SetAttribute('CurrentBiome', region and region.Biome or '')
    player:SetAttribute('InSafeZone', region and region.SafeZone == true or false)
    if region then
        player:SetAttribute('CurrentRegion', region.DisplayName)
        player:SetAttribute('CurrentKingdom', region.Kingdom)
    end
end

function Service:_positionNPCs()
    local folder = Workspace:FindFirstChild('WorldNPCs')
    if not folder then return end
    for id, position in pairs(Config.NPCPositions) do
        local model = folder:FindFirstChild(id)
        if not model then
            local content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
            local def = content.NPCs[id]
            if def then model = folder:FindFirstChild(def.DisplayName) end
        end
        if model and model:IsA('Model') and model.PrimaryPart then
            model:PivotTo(CFrame.new(position))
        end
    end
end

function Service:_spawnZoneEnemies()
    if not self._enemy then return end
    for _, instance in ipairs(self._zoneEnemies) do
        if instance.Parent then instance:Destroy() end
    end
    table.clear(self._zoneEnemies)
    for zoneId, zone in pairs(Config.EnemyZones) do
        for i = 1, zone.Count do
            local angle = (i / math.max(1, zone.Count)) * math.pi * 2
            local radius = math.min(zone.Radius * 0.55, 22)
            local pos = zone.Center + Vector3.new(math.cos(angle)*radius, 3, math.sin(angle)*radius)
            local mob = self._enemy:SpawnEnemy(zone.EnemyId, pos)
            if mob then
                mob:SetAttribute('WorldEnemyZone', zoneId)
                mob:SetAttribute('WorldRegionId', zone.Region)
                table.insert(self._zoneEnemies, mob)
            end
        end
    end
end

function Service:_wireDungeonEntrance()
    local nl = Workspace:FindFirstChild('NewLife')
    local entrance = nl and nl:FindFirstChild('DungeonEntrance')
    if not entrance or not entrance:IsA('BasePart') then return end
    entrance.CFrame = CFrame.lookAt(Config.DungeonEntrance.Position, Config.DungeonEntrance.Position + Config.DungeonEntrance.Facing)
    entrance:SetAttribute('WorldRegionId', Config.DungeonEntrance.Region)
    entrance:SetAttribute('LocalizationKey', Config.DungeonEntrance.LocalizationKey)
    entrance:SetAttribute('DungeonFramework', 'Phase10')
    local prompt = entrance:FindFirstChildOfClass('ProximityPrompt') or Instance.new('ProximityPrompt')
    prompt.Name = 'DungeonPrompt'
    prompt.ActionText = 'Enter'
    prompt.ObjectText = 'Trial Cellar'
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0.25
    prompt.RequiresLineOfSight = false
    prompt.Parent = entrance
    if prompt:GetAttribute('NewLifeWired') ~= true then
        prompt:SetAttribute('NewLifeWired', true)
        prompt.Triggered:Connect(function(player)
            if self._dungeon then self._dungeon:Enter(player) end
        end)
    end
end

function Service:Start(enemyService, dungeonService, worldService)
    if self._started then return end
    self._started = true
    self._enemy = enemyService
    self._dungeon = dungeonService
    self._world = worldService

    ReplicatedStorage:SetAttribute('WorldFoundationVersion', Config.Version)
    ReplicatedStorage:SetAttribute('WorldVerticalSlice', Config.VerticalSlice)
    ReplicatedStorage:SetAttribute('WorldLocalizationReady', true)
    ReplicatedStorage:SetAttribute('WorldAmbienceHookCount', #Config.AmbienceHooks)
    ReplicatedStorage:SetAttribute('WorldVFXHookCount', #Config.VFXHooks)

    self:_positionNPCs()
    self:_spawnZoneEnemies()
    self:_wireDungeonEntrance()

    task.spawn(function()
        while self._started do
            for _, player in Players:GetPlayers() do self:_applyPlayerRegion(player) end
            task.wait(0.5)
        end
    end)
end

function Service:DebugSnapshot()
    local regionCount = 0
    for _ in pairs(Config.Regions) do regionCount += 1 end
    local kingdomCount = 0
    for _ in pairs(Config.KingdomAnchors) do kingdomCount += 1 end
    return {
        Version=Config.Version, Regions=regionCount, Kingdoms=kingdomCount,
        StreamingEnabled=Workspace.StreamingEnabled, EnemyZones=Config.EnemyZones,
        DungeonEntrance=Config.DungeonEntrance,
    }
end

return Service
