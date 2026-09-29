--!strict
local LocalizationService = game:GetService('LocalizationService')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local LocalizationConfig = require(ReplicatedStorage.NewLife.Shared.Config.LocalizationConfig)

local HUD = {
    _started = false,
    _connections = {},
    _root = nil,
}
local player = Players.LocalPlayer

local function disconnectAll(t)
    for _, x in t do x:Disconnect() end
    table.clear(t)
end

local function ratio(a, b)
    if b <= 0 then return 0 end
    return math.clamp(a / b, 0, 1)
end

local order = {'Dead', 'Stunned', 'Parrying', 'Blocking', 'Dodging', 'Dashing', 'Attacking', 'Sprinting', 'Alive'}

function HUD:_updateCharacter(character)
    local r = self._root
    if not r then return end
    if not character then
        r.Status.Text = 'Waiting for character...'
        return
    end

    local h = character:GetAttribute('Health') or 0
    local mh = character:GetAttribute('MaxHealth') or 1
    local m = character:GetAttribute('Mana') or 0
    local mm = character:GetAttribute('MaxMana') or 1
    local s = character:GetAttribute('Stamina') or 0
    local ms = character:GetAttribute('MaxStamina') or 1

    r.HealthBar.Fill.Size = UDim2.fromScale(ratio(h, mh), 1)
    r.HealthBar.Value.Text = string.format('HP  %d / %d', math.floor(h + .5), math.floor(mh + .5))
    r.ManaBar.Fill.Size = UDim2.fromScale(ratio(m, mm), 1)
    r.ManaBar.Value.Text = string.format('MANA  %d / %d', math.floor(m + .5), math.floor(mm + .5))
    r.StaminaBar.Fill.Size = UDim2.fromScale(ratio(s, ms), 1)
    r.StaminaBar.Value.Text = string.format('STAMINA  %d / %d', math.floor(s + .5), math.floor(ms + .5))
    r.Stats.Text = string.format('STR %d   DEF %d   POW %d', character:GetAttribute('Strength') or 0, character:GetAttribute('Defense') or 0, character:GetAttribute('Power') or 0)

    if r:FindFirstChild('CombatState') then
        local current = 'READY'
        for _, n in order do
            if character:GetAttribute('State_' .. n) == true then
                current = string.upper(n)
                break
            end
        end
        r.CombatState.Text = 'STATE  ' .. current
    end

    self:_updateWorldInfo()
end

function HUD:_bindCharacter(character)
    disconnectAll(self._connections)
    local names = {'Health', 'MaxHealth', 'Mana', 'MaxMana', 'Stamina', 'MaxStamina', 'Strength', 'Defense', 'Power', 'State_Alive', 'State_Attacking', 'State_Blocking', 'State_Sprinting', 'State_Stunned', 'State_Dead', 'State_Dodging', 'State_Dashing', 'State_Parrying', 'WindTargetName', 'WindDistance', 'WindBearing'}
    for _, n in names do
        table.insert(self._connections, character:GetAttributeChangedSignal(n):Connect(function()
            self:_updateCharacter(character)
        end))
    end
    self:_updateCharacter(character)
end

function HUD:_updateWorldInfo()
    local r = self._root
    if not r then return end

    if r:FindFirstChild('WorldInfo') then
        local region = player:GetAttribute('CurrentRegion') or 'Oakhaven Village'
        local safe = player:GetAttribute('InSafeZone') == true and 'SAFEZONE' or 'WILDERNESS'
        local clock = ReplicatedStorage:GetAttribute('WorldTimeFormatted') or '08:00'
        local phase = ReplicatedStorage:GetAttribute('WorldTimePhase') or 'Day'
        r.WorldInfo.Text = string.format('REGION %s [%s] | TIME %s (%s)', region, safe, clock, phase)
    end

    if r:FindFirstChild('WorldEvent') then
        local evName = ReplicatedStorage:GetAttribute('ActiveEventName') or ''
        if evName ~= '' then
            r.WorldEvent.Text = string.format('EVENT  %s', string.upper(evName))
            r.WorldEvent.TextColor3 = Color3.fromRGB(255, 215, 0)
        else
            r.WorldEvent.Text = 'EVENT  PEACEFUL'
            r.WorldEvent.TextColor3 = Color3.fromRGB(180, 220, 180)
        end
    end

    if r:FindFirstChild('GuidingWind') then
        r.GuidingWind.Visible = RunService:IsStudio()
        if RunService:IsStudio() then
            local char = player.Character
            local targetName = char and char:GetAttribute('WindTargetName') or 'Elder Rowan'
            local dist = char and char:GetAttribute('WindDistance') or 0
            local bearing = char and char:GetAttribute('WindBearing') or 'North'
            r.GuidingWind.Text = string.format('WIND DEBUG >> %s (%d studs %s)', targetName, dist, bearing)
        end
    end
end

function HUD:_updateProgression()
    local r = self._root
    if not r then return end

    local rMst = player:GetAttribute('RaceMastery') or 0
    -- AUDIT FIX 1: RaceLevel mathematically strictly floor(Mastery / 50) + 1
    local rLvl = player:GetAttribute('RaceLevel') or (math.floor(rMst / 50) + 1)
    local cMst = player:GetAttribute('ClassMastery') or 0
    local cLvl = player:GetAttribute('ClassLevel') or (math.floor(cMst / 50) + 1)
    local unlCount = player:GetAttribute('UnlockedCount') or 0

    if r:FindFirstChild('Progression') then
        r.Progression.Text = string.format('LV %d   XP %d/%d   PR %d | R-MST %d (L%d)  C-MST %d (L%d)',
            player:GetAttribute('Level') or 0,
            player:GetAttribute('XP') or 0,
            player:GetAttribute('XPToNext') or 0,
            player:GetAttribute('PowerRating') or 0,
            rMst, rLvl, cMst, cLvl
        )
    end

    if r:FindFirstChild('Identity') then
        local isHyb = player:GetAttribute('IsHybrid') == true
        local sec = player:GetAttribute('SecondaryRace') or ''
        local rStr = player:GetAttribute('RaceId') or 'Human'
        if isHyb and sec ~= '' then
            rStr = rStr .. '/' .. sec .. ' (Hybrid)'
        end
        r.Identity.Text = string.format('%s (R-MST:%d) | %s (C-MST:%d) | %s',
            rStr, rMst,
            player:GetAttribute('ClassId') or 'Adventurer', cMst,
            player:GetAttribute('FateSeed') or '-'
        )
    end

    if r:FindFirstChild('Aptitudes') then
        local hasMag = player:GetAttribute('HasMagic') == true
        local magStr = hasMag and (tostring(player:GetAttribute('MagicAptitude') or 0) .. '%') or 'NONE'
        local trStr = player:GetAttribute('BirthTraits') or 'None'
        r.Aptitudes.Text = string.format('CLASS %d%% | MAGIC %s | TRAITS: %s',
            player:GetAttribute('ClassAptitude') or 0,
            magStr,
            trStr
        )
    end

    if r:FindFirstChild('Build') then
        r.Build.Text = string.format('BUILD S1:%s S2:%s | M1:%s M2:%s | UNLOCKED: %d',
            tostring(player:GetAttribute('SkillSlot1') or '-'),
            tostring(player:GetAttribute('SkillSlot2') or '-'),
            tostring(player:GetAttribute('MagicSlot1') or '-'),
            tostring(player:GetAttribute('MagicSlot2') or '-'),
            unlCount
        )
    end

    if r:FindFirstChild('Mastery') then
        local evoStage = player:GetAttribute('EvolutionStageName') or 'Adaptation'
        local classSkillMst = player:GetAttribute('Mastery_AdventurerStrike') or player:GetAttribute('Mastery_HeavyCleave') or player:GetAttribute('Mastery_ShadowStep') or 0
        local defierProg = player:GetAttribute('DefierProgress') or 0
        -- AUDIT FIX 2: DefierOfFate ACTIVE only appears when DefierProgress >= 3 and DefierOfFate is true
        local defierActive = (player:GetAttribute('DefierOfFate') == true) and (defierProg >= 3)
        r.Mastery.Text = string.format('MASTERY EVO:%d [%s] CLASS:%d ARC:%d EMB:%d | DEFIER %d%s',
            player:GetAttribute('Mastery_Evolution') or 0,
            evoStage,
            classSkillMst,
            player:GetAttribute('Mastery_ArcBolt') or 0,
            player:GetAttribute('Mastery_EmberBurst') or 0,
            defierProg,
            defierActive and ' ACTIVE' or ''
        )
    end

    if r:FindFirstChild('Economy') then
        r.Economy.Text = string.format('GOLD %d   TITLE %s', player:GetAttribute('Gold') or 0, player:GetAttribute('ActiveTitle') or '-')
    end
    if r:FindFirstChild('Politics') then
        r.Politics.Text = string.format('KINGDOM %s | WORLD #%s | SOVEREIGN %s | RULER %s | REP %d | ROLE %s', player:GetAttribute('KingdomName') or '-', tostring(player:GetAttribute('WorldRank') or '-'), player:GetAttribute('WorldSovereignName') or 'Vacant', player:GetAttribute('KingdomRulerName') or 'Vacant', player:GetAttribute('KingdomReputation') or 0, player:GetAttribute('PoliticalRole') or 'Citizen')
    end

    self:_updateWorldInfo()
end

function HUD:_updateBossHud()
    local r = self._root
    if not r then return end
    local panel = r:FindFirstChild('BossHUD')
    if not panel then return end
    local active = player:GetAttribute('BossActive') == true
    panel.Visible = active
    if not active then return end
    local hp = tonumber(player:GetAttribute('BossHealth')) or 0
    local maxHp = math.max(1, tonumber(player:GetAttribute('BossMaxHealth')) or 1)
    panel.NameLabel.Text = string.format('%s  [%s]', tostring(player:GetAttribute('BossName') or 'WORLD BOSS'), tostring(player:GetAttribute('BossRank') or 'WORLD'))
    panel.HP.Fill.Size = UDim2.fromScale(ratio(hp, maxHp), 1)
    panel.HP.Value.Text = string.format('HP  %d / %d', math.floor(hp + .5), math.floor(maxHp + .5))
    local identity = tostring(player:GetAttribute('BossIdentity') or '')
    local phase = tostring(player:GetAttribute('BossPhase') or '')
    local status = tostring(player:GetAttribute('BossStatus') or '')
    panel.Info.Text = string.format('%s | %s%s', phase, status, identity ~= '' and (' | Echo of ' .. identity) or '')
end

function HUD:_updateDungeonHud()
    local r=self._root; if not r then return end
    local panel=r:FindFirstChild('DungeonHUD'); if not panel then return end
    local active=player:GetAttribute('DungeonActive')==true; panel.Visible=active; if not active then return end
    panel.Text=string.format('%s  [%s]\n%s  |  Rooms %d/%d\nModifiers: %s  |  Boss: %s',
        tostring(player:GetAttribute('DungeonName') or 'DUNGEON'), tostring(player:GetAttribute('DungeonRank') or 'F'),
        tostring(player:GetAttribute('DungeonObjective') or 'Explore'), tonumber(player:GetAttribute('DungeonRoomsCleared')) or 0,
        tonumber(player:GetAttribute('DungeonRoomsTotal')) or 0, tostring(player:GetAttribute('DungeonModifiers') or '-'),
        tostring(player:GetAttribute('DungeonBossStatus') or 'Locked'))
end

function HUD:RefreshSnapshot(snapshot)
    local r = self._root
    if not r or type(snapshot) ~= 'table' then return end
    local p = snapshot.Profile or snapshot
    local q = p.Quests and p.Quests.FirstHunt
    if r:FindFirstChild('Quest') then
        r.Quest.Text = q and string.format('QUEST %s %d/2', q.State or '?', q.Kills or 0) or 'QUEST First Hunt: talk to Elder Rowan'
    end
    if r:FindFirstChild('Inventory') then
        local inv = p.Inventory or {}
        r.Inventory.Text = string.format('INV Gel:%d Core:%d DCore:%d', inv.SlimeGel or 0, inv.BruteCore or 0, inv.DungeonCore or 0)
    end
    if p.Birth and p.Birth.Summary and r:FindFirstChild('Status') then
        r.Status.Text = p.Birth.Summary
    end
    self:_updateProgression()
end

function HUD:SetStatus(key)
    if self._root then
        self._root.Status.Text = LocalizationConfig.Translate(LocalizationService.RobloxLocaleId, key)
    end
end

function HUD:SetAnnouncement(announcement)
    if self._root and self._root:FindFirstChild('Status') then
        self._root.Status.Text = tostring(announcement)
        self._root.Status.TextColor3 = Color3.fromRGB(255, 230, 100)
        task.delay(4, function()
            if self._root and self._root:FindFirstChild('Status') then
                self._root.Status.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
        end)
    end
end

function HUD:SetGuidingWind(payload)
    if self._root and self._root:FindFirstChild('GuidingWind') and type(payload) == 'table' then
        local label = self._root.GuidingWind
        label.Visible = RunService:IsStudio() or payload.DebugFallback == true
        if label.Visible then
            label.Text = string.format('WIND DEBUG >> %s (%d studs %s)', payload.TargetName or 'Unknown', payload.Distance or 0, payload.Bearing or 'North')
        end
    end
end

function HUD:SetFeedback(kind, payload)
    if not self._root then return end
    local a = type(payload) == 'table' and payload.Amount or nil
    if kind == 'Hit' and type(a) == 'number' then
        self._root.Status.Text = string.format('HIT %.0f', a)
    elseif kind == 'Damage' and type(a) == 'number' then
        self._root.Status.Text = string.format('DAMAGE %.0f', a)
    else
        self._root.Status.Text = string.upper(kind)
    end
end

function HUD:SetProgressionFeedback(kind, payload)
    if self._root then
        self._root.Status.Text = tostring(kind)
    end
    local rf = ReplicatedStorage.NewLife.Remotes.RequestInitialState
    local ok, s = pcall(function() return rf:InvokeServer() end)
    if ok and type(s) == 'table' then
        self:RefreshSnapshot(s)
    else
        self:_updateProgression()
    end
end

function HUD:_updateTarget()
    if not self._root or not self._root:FindFirstChild('Target') then return end
    local n = player:GetAttribute('LockOnTargetName')
    self._root.Target.Text = (type(n) == 'string' and n ~= '') and ('TARGET  ' .. string.upper(n)) or 'TARGET  NONE'
end

function HUD:Start()
    if self._started then return end
    self._started = true
    local pg = player:WaitForChild('PlayerGui')
    local gui = pg:WaitForChild('NewLifeHUD')
    self._root = gui:WaitForChild('Root')
    if not self._root:FindFirstChild('Politics') then
        local t=Instance.new('TextLabel');t.Name='Politics';t.BackgroundTransparency=1;t.TextColor3=Color3.fromRGB(210,220,235);t.TextXAlignment=Enum.TextXAlignment.Left;t.Font=Enum.Font.GothamMedium;t.TextSize=11;t.Size=UDim2.new(1,-16,0,18);t.Position=UDim2.new(0,8,1,-20);t.ZIndex=20;t.Parent=self._root
    end
    if not self._root:FindFirstChild('BossHUD') then
        local p=Instance.new('Frame');p.Name='BossHUD';p.Size=UDim2.new(0,390,0,66);p.Position=UDim2.new(0.5,-195,0,18);p.BackgroundColor3=Color3.fromRGB(13,18,28);p.BackgroundTransparency=0.12;p.BorderSizePixel=0;p.Visible=false;p.ZIndex=40;p.Parent=self._root
        local stroke=Instance.new('UIStroke');stroke.Color=Color3.fromRGB(115,135,165);stroke.Thickness=1;stroke.Parent=p
        local name=Instance.new('TextLabel');name.Name='NameLabel';name.BackgroundTransparency=1;name.TextColor3=Color3.fromRGB(235,235,245);name.Font=Enum.Font.GothamBold;name.TextSize=14;name.Size=UDim2.new(1,-12,0,20);name.Position=UDim2.fromOffset(6,3);name.ZIndex=41;name.Parent=p
        local hp=Instance.new('Frame');hp.Name='HP';hp.BackgroundColor3=Color3.fromRGB(42,42,50);hp.BorderSizePixel=0;hp.Size=UDim2.new(1,-16,0,16);hp.Position=UDim2.fromOffset(8,25);hp.ZIndex=41;hp.Parent=p
        local fill=Instance.new('Frame');fill.Name='Fill';fill.BackgroundColor3=Color3.fromRGB(155,52,70);fill.BorderSizePixel=0;fill.Size=UDim2.fromScale(1,1);fill.ZIndex=42;fill.Parent=hp
        local val=Instance.new('TextLabel');val.Name='Value';val.BackgroundTransparency=1;val.TextColor3=Color3.fromRGB(255,255,255);val.Font=Enum.Font.GothamBold;val.TextSize=10;val.Size=UDim2.fromScale(1,1);val.ZIndex=43;val.Parent=hp
        local info=Instance.new('TextLabel');info.Name='Info';info.BackgroundTransparency=1;info.TextColor3=Color3.fromRGB(195,205,225);info.Font=Enum.Font.GothamMedium;info.TextSize=10;info.Size=UDim2.new(1,-12,0,18);info.Position=UDim2.fromOffset(6,44);info.ZIndex=41;info.Parent=p
    end
    if not self._root:FindFirstChild('DungeonHUD') then
        local d=Instance.new('TextLabel');d.Name='DungeonHUD';d.Size=UDim2.new(0,360,0,62);d.Position=UDim2.new(1,-370,0,18);d.BackgroundColor3=Color3.fromRGB(13,18,28);d.BackgroundTransparency=.12;d.BorderSizePixel=0;d.TextColor3=Color3.fromRGB(225,235,250);d.TextXAlignment=Enum.TextXAlignment.Left;d.TextYAlignment=Enum.TextYAlignment.Top;d.Font=Enum.Font.GothamMedium;d.TextSize=11;d.TextWrapped=true;d.Visible=false;d.ZIndex=40;d.Parent=self._root
        local s=Instance.new('UIStroke');s.Color=Color3.fromRGB(95,125,165);s.Thickness=1;s.Parent=d
    end
    self._root.Title.Text = LocalizationConfig.Translate(LocalizationService.RobloxLocaleId, 'hud.title')

    player.CharacterAdded:Connect(function(ch) self:_bindCharacter(ch) end)
    player:GetAttributeChangedSignal('LockOnTargetName'):Connect(function() self:_updateTarget() end)
    player:GetAttributeChangedSignal('CurrentRegion'):Connect(function() self:_updateWorldInfo() end)
    player:GetAttributeChangedSignal('InSafeZone'):Connect(function() self:_updateWorldInfo() end)

    ReplicatedStorage:GetAttributeChangedSignal('WorldTimeFormatted'):Connect(function() self:_updateWorldInfo() end)
    ReplicatedStorage:GetAttributeChangedSignal('WorldTimePhase'):Connect(function() self:_updateWorldInfo() end)
    ReplicatedStorage:GetAttributeChangedSignal('ActiveEventName'):Connect(function() self:_updateWorldInfo() end)

    local attrs = {
        'Level', 'XP', 'XPToNext', 'PowerRating', 'Gold',
        'RaceId', 'ClassId', 'FateSeed', 'BirthTraits', 'IsHybrid', 'SecondaryRace',
        'EvolutionStage', 'EvolutionStageName', 'ClassAptitude', 'MagicAptitude', 'HasMagic',
        'ActiveTitle', 'InventoryVersion', 'QuestVersion',
        'SkillSlot1', 'SkillSlot2', 'MagicSlot1', 'MagicSlot2',
        'RaceMastery', 'RaceLevel', 'ClassMastery', 'ClassLevel', 'UnlockedCount',
        'Mastery_Evolution', 'Mastery_AdventurerStrike', 'Mastery_FieldMedicine',
        'Mastery_HeavyCleave', 'Mastery_BattleCry', 'Mastery_ShadowStep', 'Mastery_QuickSlash',
        'Mastery_ManaFlow', 'Mastery_StoneSkin', 'Mastery_FeralRoar',
        'Mastery_ArcBolt', 'Mastery_EmberBurst',
        'DefierProgress', 'DefierOfFate',
        'KingdomId','KingdomName','KingdomReputation','WorldRank','WorldSovereignName','KingdomRulerName','PoliticalRole'
    }
    for _, n in attrs do
        player:GetAttributeChangedSignal(n):Connect(function() self:_updateProgression() end)
    end
    local bossAttrs={'BossActive','BossName','BossHealth','BossMaxHealth','BossPhase','BossRank','BossIdentity','BossStatus'}
    for _,n in bossAttrs do player:GetAttributeChangedSignal(n):Connect(function() self:_updateBossHud() end) end
    local dungeonAttrs={'DungeonActive','DungeonName','DungeonRank','DungeonObjective','DungeonRoomsCleared','DungeonRoomsTotal','DungeonModifiers','DungeonBossStatus'}
    for _,n in dungeonAttrs do player:GetAttributeChangedSignal(n):Connect(function() self:_updateDungeonHud() end) end

    if player.Character then self:_bindCharacter(player.Character) end
    self:_updateTarget()
    self:_updateProgression()
    self:_updateBossHud()
    self:_updateDungeonHud()
end

return HUD
