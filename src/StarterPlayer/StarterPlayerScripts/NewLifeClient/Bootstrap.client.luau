--!strict
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local controllers = script.Parent:WaitForChild('Controllers')
local InputController = require(controllers.InputController)
local HUDController = require(controllers.HUDController)
local GuidingWindVFXController = require(controllers.GuidingWindVFXController)
local LockOnController = require(controllers.LockOnController)
local NetProtocol = require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local remotes = ReplicatedStorage.NewLife.Remotes
local systemMessage = remotes:WaitForChild(NetProtocol.Remotes.SystemMessage)
local requestInitialState = remotes:WaitForChild(NetProtocol.Remotes.RequestInitialState)
local combatFeedback = remotes:WaitForChild(NetProtocol.Remotes.CombatFeedback)
local progressionFeedback = remotes:WaitForChild(NetProtocol.Remotes.ProgressionFeedback)
local worldAnnouncement = remotes:WaitForChild(NetProtocol.Remotes.WorldAnnouncement)
local guidingWindUpdate = remotes:WaitForChild(NetProtocol.Remotes.GuidingWindUpdate)
local socialUpdate = remotes:WaitForChild(NetProtocol.Remotes.SocialUpdate)
local chatMessage = remotes:WaitForChild(NetProtocol.Remotes.ChatMessage)

HUDController:Start()
LockOnController:Start()
InputController:Start(LockOnController)

systemMessage.OnClientEvent:Connect(function(key)
    if type(key) == 'string' then HUDController:SetStatus(key) end
end)

combatFeedback.OnClientEvent:Connect(function(kind, payload)
    if type(kind) == 'string' then HUDController:SetFeedback(kind, payload) end
end)

progressionFeedback.OnClientEvent:Connect(function(kind, payload)
    if type(kind) == 'string' then HUDController:SetProgressionFeedback(kind, payload) end
end)

worldAnnouncement.OnClientEvent:Connect(function(announcement)
    if type(announcement) == 'string' then HUDController:SetAnnouncement(announcement) end
end)

guidingWindUpdate.OnClientEvent:Connect(function(payload)
    if type(payload) == 'table' then
        HUDController:SetGuidingWind(payload)
        GuidingWindVFXController:Play(payload)
    end
end)

socialUpdate.OnClientEvent:Connect(function(kind, payload)
    if type(kind) == 'string' then
        HUDController:SetAnnouncement('SOCIAL ' .. kind)
    end
end)

chatMessage.OnClientEvent:Connect(function(packet)
    if type(packet) == 'table' and type(packet.Text) == 'string' then
        HUDController:SetAnnouncement(string.format('[%s] %s: %s', tostring(packet.Channel or 'Local'), tostring(packet.FromName or '?'), packet.Text))
    end
end)

local ok, state = pcall(function() return requestInitialState:InvokeServer() end)
if ok and type(state) == 'table' and state.Profile then
    HUDController:RefreshSnapshot(state)
    HUDController:SetStatus('hud.foundationOnline')
    print('[NewLife] FASE 11 open world client online', state.FoundationVersion)
else
    warn('[NewLife] Initial state request failed')
end
