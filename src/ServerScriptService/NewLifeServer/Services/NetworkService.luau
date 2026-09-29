--!strict
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local GameConfig = require(ReplicatedStorage.NewLife.Shared.Config.GameConfig)
local NetProtocol = require(ReplicatedStorage.NewLife.Shared.Modules.NetProtocol)

local Service = {_lastAction = {}}
local remotes = ReplicatedStorage.NewLife.Remotes
local actionRequest = remotes.ActionRequest
local requestInitialState = remotes.RequestInitialState

local function can(self, p, a)
    local lim = GameConfig.Network.RateLimits[a]
    if type(lim) ~= 'number' then return false end
    local m = self._lastAction[p] or {}
    self._lastAction[p] = m
    local now = os.clock()
    if now - (m[a] or 0) < lim then return false end
    m[a] = now
    return true
end

local function target(payload)
    return type(payload) == 'table' and typeof(payload.Target) == 'Instance' and payload.Target or nil
end

local function dir(payload)
    return type(payload) == 'table' and typeof(payload.Direction) == 'Vector3' and payload.Direction or nil
end

function Service:Start(data, state, character, combat, progression, quest, dungeonService, skillService, magicService, worldService, partyService, guildService, chatService, rulerService, rareContentService, economyService, tradeService, marketService)
    requestInitialState.OnServerInvoke = function(player)
        return {
            Profile = data:GetSnapshot(player),
            ServerTime = workspace:GetServerTimeNow(),
            FoundationVersion = GameConfig.Version,
            WorldState = worldService and worldService:GetWorldState(),
            WorldPower = rulerService and rulerService:GetSnapshot(),
            Economy = economyService and {Balance = economyService:GetBalance(player)},
            Market = marketService and marketService:Browse() or {},
        }
    end

    actionRequest.OnServerEvent:Connect(function(player, action, payload)
        if type(action) ~= 'string' or not can(self, player, action) then return end
        if action == NetProtocol.Actions.LightAttack then combat:HandleLightAttack(player, target(payload)); return end
        if action == NetProtocol.Actions.HeavyAttack then combat:HandleHeavyAttack(player, target(payload)); return end
        if action == NetProtocol.Actions.Dodge then character:Dodge(player, dir(payload)); return end
        if action == NetProtocol.Actions.Dash then character:Dash(player, dir(payload)); return end
        if action == NetProtocol.Actions.Parry then combat:HandleParry(player); return end
        if action == NetProtocol.Actions.Block and type(payload) == 'boolean' then character:SetBlock(player, payload); return end
        if action == NetProtocol.Actions.Sprint and type(payload) == 'boolean' then character:SetSprint(player, payload); return end
        if action == NetProtocol.Actions.RacialSkill then skillService:Use(player, 'Evolution', target(payload)); return end
        if action == NetProtocol.Actions.UseSkill and type(payload) == 'table' and type(payload.SkillId) == 'string' then
            skillService:Use(player, payload.SkillId, target(payload)); return
        end
        if action == NetProtocol.Actions.CastMagic and type(payload) == 'table' and type(payload.MagicId) == 'string' then
            magicService:Cast(player, payload.MagicId, target(payload)); return
        end
        if action == NetProtocol.Actions.EquipSkill and type(payload) == 'table' and type(payload.SkillId) == 'string' and type(payload.Slot) == 'number' then
            skillService:Equip(player, payload.SkillId, payload.Slot); return
        end
        if action == NetProtocol.Actions.GuidingWind then worldService:TriggerGuidingWind(player); return end
        if action == NetProtocol.Actions.PartyCreate then partyService:Create(player); return end
        if action == NetProtocol.Actions.PartyInvite and type(payload)=='table' and type(payload.TargetUserId)=='number' then partyService:Invite(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.PartyRespond and type(payload)=='table' and type(payload.Accept)=='boolean' then partyService:RespondInvite(player,payload.Accept); return end
        if action == NetProtocol.Actions.PartyLeave then partyService:Leave(player); return end
        if action == NetProtocol.Actions.PartyTransferLeader and type(payload)=='table' and type(payload.TargetUserId)=='number' then partyService:TransferLeader(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.PartyKick and type(payload)=='table' and type(payload.TargetUserId)=='number' then partyService:Kick(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.PartyShareQuest and type(payload)=='table' and type(payload.QuestId)=='string' then partyService:ShareQuest(player,payload.QuestId); return end
        if action == NetProtocol.Actions.SendChat then chatService:Send(player,payload); return end
        if action == NetProtocol.Actions.GuildCreate and type(payload)=='table' and type(payload.Name)=='string' and type(payload.Tag)=='string' then guildService:Create(player,payload.Name,payload.Tag); return end
        if action == NetProtocol.Actions.GuildInvite and type(payload)=='table' and type(payload.TargetUserId)=='number' then guildService:Invite(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.GuildRespond and type(payload)=='table' and type(payload.Accept)=='boolean' then guildService:RespondInvite(player,payload.Accept); return end
        if action == NetProtocol.Actions.GuildLeave then guildService:Leave(player); return end
        if action == NetProtocol.Actions.GuildKick and type(payload)=='table' and type(payload.TargetUserId)=='number' then guildService:Kick(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.GuildSetRole and type(payload)=='table' and type(payload.TargetUserId)=='number' and type(payload.Role)=='string' then guildService:SetRole(player,math.floor(payload.TargetUserId),payload.Role); return end
        if action == NetProtocol.Actions.GuildTransferOwner and type(payload)=='table' and type(payload.TargetUserId)=='number' then guildService:TransferOwner(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.SocialInspect and type(payload)=='table' and type(payload.TargetUserId)=='number' then
            local targetPlayer=Players:GetPlayerByUserId(math.floor(payload.TargetUserId))
            if targetPlayer and not data:IsBlocked(targetPlayer,player.UserId) then
                local profile=data:GetProfile(targetPlayer)
                local social=remotes:FindFirstChild(NetProtocol.Remotes.SocialUpdate)
                if profile and social and social:IsA('RemoteEvent') then social:FireClient(player,'SocialInspect',{UserId=targetPlayer.UserId,Name=targetPlayer.Name,Race=profile.Identity.Race,Class=profile.Identity.Class,Level=profile.Progression.Level,PowerRating=profile.Progression.PowerRating,Titles=data:GetPublicTitles(targetPlayer),Nation=profile.Social.Nation,Guild={Name=profile.Guild.Name,Tag=profile.Guild.Tag,Role=profile.Guild.Role}}) end
            end
            return
        end
        if action == NetProtocol.Actions.SocialBlock and type(payload)=='table' and type(payload.TargetUserId)=='number' and type(payload.Enabled)=='boolean' then data:SetBlocked(player,math.floor(payload.TargetUserId),payload.Enabled); return end
        if action == NetProtocol.Actions.SocialMute and type(payload)=='table' and type(payload.TargetUserId)=='number' and type(payload.Enabled)=='boolean' then data:SetMuted(player,math.floor(payload.TargetUserId),payload.Enabled); return end
        if action == NetProtocol.Actions.SocialReport and type(payload)=='table' and type(payload.TargetUserId)=='number' and type(payload.Reason)=='string' then data:AddSocialReport(player,math.floor(payload.TargetUserId),payload.Reason); return end
        if action == NetProtocol.Actions.InvestDefense then rulerService:InvestDefense(player); return end
        if action == NetProtocol.Actions.RareUseItem and rareContentService and type(payload)=='table' and type(payload.UniqueItemId)=='string' then rareContentService:UseRareItem(player,payload.UniqueItemId); return end
        if action == NetProtocol.Actions.RareEquipRelic and rareContentService and type(payload)=='table' and type(payload.UniqueItemId)=='string' then rareContentService:EquipRelic(player,payload.UniqueItemId); return end
        if action == NetProtocol.Actions.RareUnequipRelic and rareContentService and type(payload)=='table' and type(payload.Category)=='string' then rareContentService:UnequipRelic(player,payload.Category); return end
        if action == NetProtocol.Actions.RareOpenWorldClaim and rareContentService then rareContentService:TryAcquireOpenWorld(player); return end
        if action == NetProtocol.Actions.VendorBuy and economyService and type(payload)=='table' and type(payload.NPCId)=='string' and type(payload.ItemId)=='string' and type(payload.Quantity)=='number' then economyService:VendorBuy(player,payload.NPCId,payload.ItemId,math.floor(payload.Quantity)); return end
        if action == NetProtocol.Actions.VendorSell and economyService and type(payload)=='table' and type(payload.NPCId)=='string' and type(payload.ItemId)=='string' and type(payload.Quantity)=='number' then economyService:VendorSell(player,payload.NPCId,payload.ItemId,math.floor(payload.Quantity)); return end
        if action == NetProtocol.Actions.TradeInvite and tradeService and type(payload)=='table' and type(payload.TargetUserId)=='number' then tradeService:Invite(player,math.floor(payload.TargetUserId)); return end
        if action == NetProtocol.Actions.TradeRespond and tradeService and type(payload)=='table' and type(payload.Accept)=='boolean' then tradeService:Respond(player,payload.Accept); return end
        if action == NetProtocol.Actions.TradeOfferItem and tradeService and type(payload)=='table' and type(payload.ItemId)=='string' and type(payload.Quantity)=='number' then tradeService:OfferItem(player,payload.ItemId,math.floor(payload.Quantity)); return end
        if action == NetProtocol.Actions.TradeOfferGold and tradeService and type(payload)=='table' and type(payload.Amount)=='number' then tradeService:OfferGold(player,math.floor(payload.Amount)); return end
        if action == NetProtocol.Actions.TradeOfferRare and tradeService and type(payload)=='table' and type(payload.UniqueItemId)=='string' and type(payload.Enabled)=='boolean' then tradeService:OfferRare(player,payload.UniqueItemId,payload.Enabled); return end
        if action == NetProtocol.Actions.TradeConfirm and tradeService then tradeService:Confirm(player); return end
        if action == NetProtocol.Actions.TradeCancel and tradeService then tradeService:Cancel(player,'ClientCancel'); return end
        if action == NetProtocol.Actions.MarketList and marketService and type(payload)=='table' and type(payload.ItemId)=='string' and type(payload.Quantity)=='number' and type(payload.Price)=='number' then marketService:List(player,payload.ItemId,math.floor(payload.Quantity),math.floor(payload.Price),type(payload.UniqueItemId)=='string' and payload.UniqueItemId or nil); return end
        if action == NetProtocol.Actions.MarketCancel and marketService and type(payload)=='table' and type(payload.ListingId)=='string' then marketService:Cancel(player,payload.ListingId); return end
        if action == NetProtocol.Actions.MarketPurchase and marketService and type(payload)=='table' and type(payload.ListingId)=='string' then marketService:Purchase(player,payload.ListingId); return end
        if action == NetProtocol.Actions.MarketBrowse and marketService then marketService:Browse(); return end
        if action == NetProtocol.Actions.Interact then
            local c = player.Character
            local r = c and c:FindFirstChild('HumanoidRootPart')
            if not r or not r:IsA('BasePart') then return end

            -- 1. NPC interaction via payload or proximity
            if type(payload) == 'table' and type(payload.NPCId) == 'string' and worldService then
                local res = worldService:InteractWithNPC(player, payload.NPCId)
                if res then
                    local sys = remotes:FindFirstChild(NetProtocol.Remotes.SystemMessage)
                    if sys and sys:IsA('RemoteEvent') then
                        sys:FireClient(player, string.format("[%s] %s", res.DisplayName, res.Dialogue))
                    end
                end
                return
            end

            -- 2. Legacy Guide Mira
            local npcs = workspace.NewLife:FindFirstChild('NPCs')
            local guide = npcs and npcs:FindFirstChild('Guide Mira')
            local dungeonEntrance = workspace.NewLife:FindFirstChild('DungeonEntrance')
            if guide and guide:IsA('BasePart') and (guide.Position - r.Position).Magnitude <= GameConfig.Network.InteractDistance then
                quest:InteractGuide(player)
                return
            end
            if dungeonEntrance and dungeonEntrance:IsA('BasePart') and (dungeonEntrance.Position - r.Position).Magnitude <= GameConfig.Network.InteractDistance then
                dungeonService:Enter(player)
                return
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(p) self._lastAction[p] = nil end)
end

return Service
