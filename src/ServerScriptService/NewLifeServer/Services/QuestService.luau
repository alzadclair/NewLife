--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Content = require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local Service = {_data = nil, _feedback = nil}

function Service:Start(dataService)
    self._data = dataService
    self._feedback = ReplicatedStorage.NewLife.Remotes.ProgressionFeedback
end

function Service:InteractGuide(player: Player)
    local p = self._data:GetProfile(player)
    if not p then return end
    local q = p.Quests.FirstHunt
    if not q then
        self._data:SetQuest(player, 'FirstHunt', {State = 'Active', Kills = 0})
        self._data:AddPlayerChronicle(player, "Accepted quest 'First Hunt' from Elder Rowan.", "Quest")
        self._feedback:FireClient(player, 'QuestAccepted', {QuestId = 'FirstHunt'})
    elseif q.State == 'Completed' then
        self._feedback:FireClient(player, 'QuestStatus', {QuestId = 'FirstHunt', State = 'Completed'})
    end
end

function Service:OnEnemyKilled(player: Player, enemyId: string)
    local p = self._data:GetProfile(player)
    if not p then return end

    -- Check all quests
    for qId, qDef in pairs(Content.Quests) do
        local q = p.Quests[qId]
        if q and q.State == 'Active' and enemyId == qDef.TargetEnemyId then
            q.Kills = math.min(qDef.RequiredKills, (q.Kills or 0) + 1)
            if q.Kills >= qDef.RequiredKills then
                q.State = 'Completed'
                self._data:AddXP(player, qDef.Rewards.XP or 0)
                self._data:AddGold(player, qDef.Rewards.Gold or 0)
                if qDef.Rewards.Items then
                    for id, n in pairs(qDef.Rewards.Items) do
                        self._data:AddItem(player, id, n)
                    end
                end
                if qDef.Rewards.Title then
                    self._data:GrantTitle(player, qDef.Rewards.Title)
                end
                self._data:SetNPCMemory(player, qDef.GiverNpcId or 'ElderRowan', 'Completed_' .. qId, true)
                self._data:AddPlayerChronicle(player, "Completed quest: " .. (qDef.DisplayName or qId), "Quest")
                self._feedback:FireClient(player, 'QuestCompleted', {QuestId = qId})
            else
                self._feedback:FireClient(player, 'QuestProgress', {QuestId = qId, Kills = q.Kills, Required = qDef.RequiredKills})
            end
            self._data:SetQuest(player, qId, q)
        end
    end
end

return Service
