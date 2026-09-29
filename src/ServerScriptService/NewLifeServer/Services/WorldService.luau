--!strict
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')
local CollectionService = game:GetService('CollectionService')

local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local Content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local WorldFoundationConfig = require(ReplicatedStorage.NewLife.Shared.Config.WorldFoundationConfig)
local NetProtocol = require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local Service = {
    _started = false,
    _data = nil,
    _combat = nil,
    _enemy = nil,
    _quest = nil,
    _worldTime = 8.0,
    _timePhase = 'Day',
    _worldChronicle = {} :: {any},
    _activeEvent = nil :: any,
    _npcs = {} :: {[string]: Model},
    _eventInvaders = {} :: {Model},
    _lastGuardAttack = 0,
    _acc = 0,
}

local function formatClock(hours: number): string
    local h = math.floor(hours) % 24
    local m = math.floor((hours - math.floor(hours)) * 60)
    return string.format("%02d:%02d", h, m)
end

function Service:GetWorldState()
    return {
        WorldTime = self._worldTime,
        WorldTimeFormatted = formatClock(self._worldTime),
        TimePhase = self._timePhase,
        ActiveEvent = self._activeEvent,
        WorldChronicle = self._worldChronicle,
    }
end

function Service:GetWorldChronicle()
    return self._worldChronicle
end

function Service:AddWorldChronicle(text: string, category: string?)
    table.insert(self._worldChronicle, {
        Timestamp = os.time(),
        Text = text,
        Category = category or 'World',
    })
    ReplicatedStorage:SetAttribute('WorldChronicleCount', #self._worldChronicle)
end

function Service:BroadcastAnnouncement(text: string)
    print('[World Announcement] ' .. text)
    local remotes = ReplicatedStorage.NewLife:FindFirstChild('Remotes')
    local ann = remotes and remotes:FindFirstChild(NetProtocol.Remotes.WorldAnnouncement)
    if ann and ann:IsA('RemoteEvent') then
        ann:FireAllClients(text)
    end
end

function Service:GetRegionAt(position: Vector3)
    local best = nil
    local bestDist = math.huge
    for id, reg in pairs(WorldFoundationConfig.Regions) do
        local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(reg.Center.X, 0, reg.Center.Z)).Magnitude
        if dist <= reg.Radius and dist < bestDist then
            best = {
                Id = id,
                DisplayName = reg.DisplayName,
                Center = reg.Center,
                Radius = reg.Radius,
                SafeZone = reg.SafeZone,
                Kingdom = reg.Kingdom,
                Biome = reg.Biome,
            }
            bestDist = dist
        end
    end
    return best or Content.Regions.WhisperingWoods
end

function Service:GetNPCPosition(npcId: string): Vector3
    local foundationPosition = WorldFoundationConfig.NPCPositions[npcId]
    if foundationPosition then return foundationPosition end
    local def = Content.NPCs[npcId]
    if not def then return Vector3.zero end
    if self._timePhase == 'Night' and def.NightPosition then
        return def.NightPosition
    end
    return def.DayPosition or Vector3.zero
end

local function makeNPCRig(def)
    local model = Instance.new('Model')
    model.Name = def.DisplayName
    model:SetAttribute('NPCId', def.Id)
    model:SetAttribute('Role', def.Role)
    model:SetAttribute('Faction', def.Faction)
    model:SetAttribute('State', 'Idle')

    local root = Instance.new('Part')
    root.Name = 'HumanoidRootPart'
    root.Size = Vector3.new(2, 2, 1)
    root.Position = def.DayPosition or Vector3.new(0, 3, 0)
    root.Anchored = false
    root.CanCollide = true
    root.Parent = model

    local head = Instance.new('Part')
    head.Name = 'Head'
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Position = root.Position + Vector3.new(0, 2, 0)
    head.Parent = model

    local weld = Instance.new('WeldConstraint')
    weld.Part0 = root
    weld.Part1 = head
    weld.Parent = root

    local hum = Instance.new('Humanoid')
    hum.MaxHealth = def.Health or 100
    hum.Health = def.Health or 100
    hum.WalkSpeed = 10
    hum.Parent = model

    model.PrimaryPart = root
    CollectionService:AddTag(model, 'NL_NPC')
    return model
end

function Service:GetNPC(npcId: string): Model?
    local current = self._npcs[npcId]
    if current and current.Parent then
        return current
    end
    local folder = workspace:FindFirstChild('WorldNPCs')
    if folder then
        local def = Content.NPCs[npcId]
        if def then
            local model = folder:FindFirstChild(def.DisplayName) or folder:FindFirstChild(def.Id)
            if model and model:IsA('Model') then
                self._npcs[npcId] = model
                return model
            end
        end
    end
    return nil
end

function Service:SpawnNPCs()
    local folder = workspace:FindFirstChild('WorldNPCs') or Instance.new('Folder')
    folder.Name = 'WorldNPCs'
    folder.Parent = workspace

    for id, def in pairs(Content.NPCs) do
        if def.DayPosition then
            local existing = folder:FindFirstChild(def.DisplayName) or folder:FindFirstChild(def.Id)
            if existing and existing:IsA('Model') then
                self._npcs[id] = existing
            else
                local rig = makeNPCRig(def)
                rig.Parent = folder
                self._npcs[id] = rig
            end
        end
    end
end

function Service:InteractWithNPC(player: Player, npcId: string)
    local def = Content.NPCs[npcId]
    if not def or not self._data then return nil end

    local rel = self._data:GetNPCRelationship(player, npcId)
    local rep = rel.Reputation or 0
    local fam = rel.Familiarity or 0

    self._data:AddFamiliarity(player, npcId, 1)
    if fam == 0 then
        self._data:AddReputation(player, npcId, 2)
    end

    local dialogue = ""
    local model = self:GetNPC(npcId)
    local isCowering = model and model:GetAttribute('State') == 'Cowering'

    if npcId == 'GuardKael' then
        if isCowering then
            dialogue = "Hold the line! Protect the citizens of Oakhaven!"
        elseif self._data:GetNPCMemory(player, 'GuardKael', 'SavedVillage') then
            dialogue = "Salute, Hero! Thanks to you, Oakhaven stood strong against the beasts. We will never forget it."
        elseif rep >= 10 then
            dialogue = "Welcome back, trusted friend. The perimeter is secure."
        else
            dialogue = "Stay sharp, traveler. I keep watch over Oakhaven Village."
        end
    elseif npcId == 'ElderRowan' then
        if isCowering then
            dialogue = "Heavens preserve us! Someone drive those beasts away!"
        elseif self._data:GetNPCMemory(player, 'ElderRowan', 'SavedVillage') then
            dialogue = "Ah, our valiant protector! The stars chronicled your courage when the wolves struck."
        elseif self._data:GetNPCMemory(player, 'ElderRowan', 'Completed_FirstHunt') then
            dialogue = "Well done on your hunt in the woods. The villagers sleep safer tonight."
        else
            dialogue = "Greetings, traveler. Speak with me if you seek tasks to aid our settlement."
        end
    elseif npcId == 'MerchantBoran' then
        if isCowering then
            dialogue = "Eeeek! Protect me! The beasts are invading!"
        else
            dialogue = "Welcome to my shop! Finest wares from all five kingdoms."
        end
    else
        dialogue = "Greetings, wanderer."
    end

    return {
        NPCId = npcId,
        DisplayName = def.DisplayName,
        Role = def.Role,
        Reputation = rep,
        Familiarity = fam + 1,
        Dialogue = dialogue,
    }
end

-- Dynamic World Events
function Service:StartEvent(eventId: string): boolean
    local def = Content.Events[eventId]
    if not def then return false end

    if self._activeEvent then
        self:StopEvent()
    end

    self._activeEvent = {
        Id = eventId,
        DisplayName = def.DisplayName,
        Type = def.Type,
        Region = def.Region,
        StartTime = os.time(),
        Duration = def.Duration or 60,
    }

    ReplicatedStorage:SetAttribute('ActiveEventId', eventId)
    ReplicatedStorage:SetAttribute('ActiveEventName', def.DisplayName)

    if def.Type == 'Invasion' then
        self:BroadcastAnnouncement("[WORLD EVENT] " .. def.DisplayName .. " has begun near " .. (Content.Regions[def.Region].DisplayName or def.Region) .. "!")
        self:AddWorldChronicle("Hostile wolf pack invaded " .. (Content.Regions[def.Region].DisplayName or def.Region) .. " outskirts.", "Invasion")

        -- Spawn invaders
        self._eventInvaders = {}
        local count = def.EnemyCount or 2
        for i = 1, count do
            local offset = Vector3.new((i - 1) * 6, 0, (i - 1) * 4)
            local spawnPos = (def.SpawnPosition or Vector3.new(25, 3, 15)) + offset
            local mob = self._enemy:SpawnEnemy(def.EnemyId or 'TrainingSlime', spawnPos)
            if mob then
                mob:SetAttribute('IsEventInvader', true)
                table.insert(self._eventInvaders, mob)
            end
        end
    elseif def.Type == 'Peaceful' then
        self:BroadcastAnnouncement("[WORLD EVENT] The " .. def.DisplayName .. " has blessed Oakhaven Village! Health and Mana recovery boosted.")
        self:AddWorldChronicle("The village celebrated the tranquil " .. def.DisplayName .. ".", "Blessing")

        for _, p in Players:GetPlayers() do
            local reg = p:GetAttribute('CurrentRegion')
            if reg == Content.Regions.Oakhaven.DisplayName then
                self._data:AddPlayerChronicle(p, "Basked in the serene Harvest Blessing of Oakhaven.", "Blessing")
            end
        end
    end

    return true
end

function Service:StopEvent(success: boolean?)
    if not self._activeEvent then return end
    local ev = self._activeEvent
    self._activeEvent = nil
    ReplicatedStorage:SetAttribute('ActiveEventId', '')
    ReplicatedStorage:SetAttribute('ActiveEventName', '')

    if ev.Type == 'Invasion' then
        if success then
            self:BroadcastAnnouncement("[WORLD EVENT] The " .. ev.DisplayName .. " has been successfully repelled!")
            self:AddWorldChronicle("Defenders successfully repelled the " .. ev.DisplayName .. ".", "Victory")

            for _, p in Players:GetPlayers() do
                self._data:AddReputation(p, 'GuardKael', 15)
                self._data:AddReputation(p, 'ElderRowan', 10)
                self._data:SetNPCMemory(p, 'GuardKael', 'SavedVillage', true)
                self._data:SetNPCMemory(p, 'ElderRowan', 'SavedVillage', true)
                self._data:AddPlayerChronicle(p, "Repelled the " .. ev.DisplayName .. " threatening Oakhaven Village.", "Achievement")
            end
        else
            self:BroadcastAnnouncement("[WORLD EVENT] The " .. ev.DisplayName .. " has dispersed into the wild.")
        end

        for _, mob in ipairs(self._eventInvaders) do
            if mob and mob.Parent then mob:Destroy() end
        end
        self._eventInvaders = {}
    elseif ev.Type == 'Peaceful' then
        self:BroadcastAnnouncement("[WORLD EVENT] The peaceful " .. ev.DisplayName .. " has drawn to a gentle close.")
    end
end

function Service:_updateGuardsAndCivilians()
    local guardRig = self:GetNPC('GuardKael')
    local guardDef = Content.NPCs.GuardKael
    local guardRoot = guardRig and guardRig:FindFirstChild('HumanoidRootPart')

    -- 1. Check for hostile invaders
    local nearestInvader = nil
    local nearestDist = guardDef.DetectionRange or 35
    for _, mob in ipairs(self._eventInvaders) do
        local r = mob and mob:FindFirstChild('HumanoidRootPart')
        local h = mob and mob:FindFirstChildOfClass('Humanoid')
        if r and h and h.Health > 0 and guardRoot then
            local dist = (r.Position - guardRoot.Position).Magnitude
            if dist < nearestDist then
                nearestInvader = mob
                nearestDist = dist
            end
        end
    end

    -- Guard attack logic
    if nearestInvader and guardRig and guardRoot then
        local hum = guardRig:FindFirstChildOfClass('Humanoid')
        local invRoot = nearestInvader:FindFirstChild('HumanoidRootPart')
        local invHum = nearestInvader:FindFirstChildOfClass('Humanoid')
        if hum and invRoot then
            hum:MoveTo(invRoot.Position)
            if (invRoot.Position - guardRoot.Position).Magnitude <= 10 then
                if os.clock() - self._lastGuardAttack >= 1.0 then
                    self._lastGuardAttack = os.clock()
                    if invHum then
                        invHum:TakeDamage(guardDef.Damage or 18)
                    end
                end
            end
        end
    end

    -- 2. Civilians Cowering Reaction
    local civilianIds = {'MerchantBoran', 'ElderRowan'}
    for _, cId in ipairs(civilianIds) do
        local cRig = self:GetNPC(cId)
        local cRoot = cRig and cRig:FindFirstChild('HumanoidRootPart')
        if cRig and cRoot then
            local inDanger = false
            for _, mob in ipairs(self._eventInvaders) do
                local r = mob and mob:FindFirstChild('HumanoidRootPart')
                local h = mob and mob:FindFirstChildOfClass('Humanoid')
                if r and h and h.Health > 0 then
                    if (r.Position - cRoot.Position).Magnitude <= 25 then
                        inDanger = true
                        break
                    end
                end
            end
            cRig:SetAttribute('State', inDanger and 'Cowering' or 'Idle')
        end
    end

    -- 3. Check if all event invaders are defeated
    if self._activeEvent and self._activeEvent.Type == 'Invasion' and #self._eventInvaders > 0 then
        local allDead = true
        for _, mob in ipairs(self._eventInvaders) do
            local h = mob:FindFirstChildOfClass('Humanoid')
            if h and h.Health > 0 and mob.Parent then
                allDead = false
                break
            end
        end
        if allDead then
            self:StopEvent(true)
        end
    end
end

function Service:_updateNPCMovement()
    for npcId, def in pairs(Content.NPCs) do
        if def.DayPosition then
            local model = self:GetNPC(npcId)
            if model then
                local root = model:FindFirstChild('HumanoidRootPart')
                local hum = model:FindFirstChildOfClass('Humanoid')
                local state = model:GetAttribute('State')
                if root and hum and state ~= 'Cowering' then
                    if npcId == 'GuardKael' and #self._eventInvaders > 0 and self._activeEvent then
                        continue
                    end
                    local targetPos = self:GetNPCPosition(npcId)
                    local dist = (root.Position - targetPos).Magnitude
                    if dist > 3 then
                        hum:MoveTo(targetPos)
                    end
                end
            end
        end
    end
end

function Service:_updateGuidingWind(player: Player)
    local char = player.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then return end

    local p = self._data and self._data:GetProfile(player) or nil
    local targetPos = Vector3.new(-15, 3, 0) -- Default Elder Rowan
    local targetName = "Elder Rowan"

    if player:GetAttribute('DungeonActive') == true then
        if player:GetAttribute('DungeonWindAllowed') ~= true then
            char:SetAttribute('WindTargetName', 'Guiding Wind unavailable')
            char:SetAttribute('WindDistance', 0)
            char:SetAttribute('WindBearing', 'Disabled')
            return
        end
        local dungeonPos = player:GetAttribute('DungeonObjectivePosition')
        if typeof(dungeonPos) == 'Vector3' then targetPos = dungeonPos end
        targetName = tostring(player:GetAttribute('DungeonObjective') or 'Main dungeon objective')
    elseif p and p.Quests then
        local fh = p.Quests.FirstHunt
        if fh and fh.State == 'Active' then
            targetPos = Vector3.new(120, 3, 0) -- Whispering Woods slimes
            targetName = "Whispering Woods (Slime Hunt)"
        elseif fh and fh.State == 'Completed' then
            targetPos = Vector3.new(-15, 3, 0)
            targetName = "Elder Rowan (Turn In)"
        end
    end

    local delta = targetPos - root.Position
    local dist = math.floor(delta.Magnitude)
    local angle = math.atan2(delta.X, delta.Z) * 180 / math.pi
    local bearing = "North"
    if angle >= -22.5 and angle < 22.5 then bearing = "South"
    elseif angle >= 22.5 and angle < 67.5 then bearing = "South-East"
    elseif angle >= 67.5 and angle < 112.5 then bearing = "East"
    elseif angle >= 112.5 and angle < 157.5 then bearing = "North-East"
    elseif angle >= -67.5 and angle < -22.5 then bearing = "South-West"
    elseif angle >= -112.5 and angle < -67.5 then bearing = "West"
    elseif angle >= -157.5 and angle < -112.5 then bearing = "North-West"
    end

    char:SetAttribute('WindTargetName', targetName)
    char:SetAttribute('WindDistance', dist)
    char:SetAttribute('WindBearing', bearing)

    local remotes = ReplicatedStorage.NewLife:FindFirstChild('Remotes')
    local wind = remotes and remotes:FindFirstChild(NetProtocol.Remotes.GuidingWindUpdate)
    if wind and wind:IsA('RemoteEvent') then
        local direction = delta.Magnitude > 0 and delta.Unit or Vector3.zero
        wind:FireClient(player, {
            TargetName = targetName,
            TargetPosition = targetPos,
            Direction = direction,
            Distance = dist,
            Bearing = bearing,
            Duration = GameConfig.World.GuidingWindDuration,
            Strength = GameConfig.World.GuidingWindStrength,
            EnvironmentalFeedback = true,
            DebugFallback = RunService:IsStudio(),
        })
    end
end

function Service:TriggerGuidingWind(player: Player): (boolean, string)
    local char = player.Character
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root or not root:IsA('BasePart') then return false, 'CharacterMissing' end
    self:_updateGuidingWind(player)
    char:SetAttribute('GuidingWindTriggeredAt', workspace:GetServerTimeNow())
    return true, 'OK'
end

local function serverClockHours(): number
    local now = os.date('*t')
    return ((now.hour or 0) + (now.min or 0) / 60 + (now.sec or 0) / 3600) % 24
end

function Service:Start(dataService, combatService, enemyService, questService)
    if self._started then return end
    self._started = true
    self._data = dataService
    self._combat = combatService
    self._enemy = enemyService
    self._quest = questService

    self:SpawnNPCs()
    self:AddWorldChronicle("The realm initialized in the age of New Life.", "Server")
    self._worldTime = serverClockHours()

    RunService.Heartbeat:Connect(function(dt)
        -- 1. Production follows the server's real 24-hour local clock. Studio may accelerate it for debug.
        if RunService:IsStudio() then
            local scale = math.max(1, GameConfig.World.StudioDebugTimeScale or 1)
            self._worldTime = (self._worldTime + (dt * scale / 3600)) % 24
        else
            self._worldTime = serverClockHours()
        end
        Lighting.ClockTime = self._worldTime

        local oldPhase = self._timePhase
        self._timePhase = (self._worldTime >= 6 and self._worldTime < 18) and 'Day' or 'Night'
        if oldPhase ~= self._timePhase then
            if self._timePhase == 'Day' then
                self:BroadcastAnnouncement("[CYCLE] Dawn breaks over the kingdom. A new day begins.")
            else
                self:BroadcastAnnouncement("[CYCLE] Dusk falls upon the land. Night envelops the realm.")
            end
        end

        ReplicatedStorage:SetAttribute('WorldTime', self._worldTime)
        ReplicatedStorage:SetAttribute('WorldTimeFormatted', formatClock(self._worldTime))
        ReplicatedStorage:SetAttribute('WorldTimePhase', self._timePhase)

        self._acc += dt
        if self._acc < 0.5 then return end
        self._acc = 0

        -- 2. Update player regions & guiding wind
        for _, p in Players:GetPlayers() do
            local c = p.Character
            local r = c and c:FindFirstChild('HumanoidRootPart')
            if r and r:IsA('BasePart') then
                local reg = self:GetRegionAt(r.Position)
                p:SetAttribute('CurrentRegion', reg.DisplayName)
                p:SetAttribute('InSafeZone', reg.SafeZone == true)
            end
        end

        -- 3. Update NPC behavior
        self:_updateGuardsAndCivilians()
        self:_updateNPCMovement()
    end)
end

return Service
