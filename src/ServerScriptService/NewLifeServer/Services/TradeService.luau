--!strict
local Players=game:GetService('Players')
local HttpService=game:GetService('HttpService')
local Service={_data=nil,_economy=nil,_rare=nil,_sessions={},_invites={},_locks={}}
local function now() return os.time() end
local function reset(s) s.ConfirmedA=false; s.ConfirmedB=false end
local function side(s,userId) if s.A==userId then return 'A' elseif s.B==userId then return 'B' end end
function Service:Start(data,economy,rare) self._data=data; self._economy=economy; self._rare=rare; Players.PlayerRemoving:Connect(function(p) self:Disconnect(p) end) end
function Service:Invite(player,targetUserId)
 if targetUserId==player.UserId then return false,'SelfTrade' end
 local target=Players:GetPlayerByUserId(targetUserId); if not target then return false,'Offline' end
 self._invites[targetUserId]={From=player.UserId,Expires=now()+30}; return true,'Invited'
end
function Service:Respond(player,accept)
 local i=self._invites[player.UserId]; if not i or i.Expires<now() then self._invites[player.UserId]=nil; return false,'NoInvite' end
 self._invites[player.UserId]=nil; if not accept then return true,'Declined' end
 local a=Players:GetPlayerByUserId(i.From); if not a then return false,'Offline' end
 local id='TRADE:'..HttpService:GenerateGUID(false); local s={Id=id,A=a.UserId,B=player.UserId,GoldA=0,GoldB=0,ItemsA={},ItemsB={},RareA={},RareB={},ConfirmedA=false,ConfirmedB=false,Expires=now()+120}; self._sessions[a.UserId]=s; self._sessions[player.UserId]=s; return true,id
end
function Service:_session(player) local s=self._sessions[player.UserId]; if s and s.Expires<now() then self:Cancel(player,'Timeout'); return nil end return s end
function Service:OfferGold(player,amount)
 local s=self:_session(player); if not s then return false,'NoSession' end
 if type(amount)~='number' or math.floor(amount)~=amount or amount<0 then return false,'InvalidAmount' end
 local p=self._data:GetProfile(player); if not p or p.Progression.Gold<amount then return false,'InsufficientFunds' end
 if side(s,player.UserId)=='A' then s.GoldA=amount else s.GoldB=amount end; reset(s); return true,'Updated'
end
function Service:OfferItem(player,itemId,qty)
 local s=self:_session(player); if not s then return false,'NoSession' end
 if type(itemId)~='string' or type(qty)~='number' or math.floor(qty)~=qty or qty<0 then return false,'InvalidOffer' end
 local policy=self._economy:GetItemPolicy(itemId); if not policy.Tradeable or policy.Transferability~='Tradeable' then return false,'NotTradeable' end
 local p=self._data:GetProfile(player); if not p or (p.Inventory[itemId] or 0)<qty then return false,'InsufficientItems' end
 local bag=side(s,player.UserId)=='A' and s.ItemsA or s.ItemsB; if qty==0 then bag[itemId]=nil else bag[itemId]=qty end; reset(s); return true,'Updated'
end
function Service:OfferRare(player,uniqueId,enabled)
 local s=self:_session(player); if not s then return false,'NoSession' end
 local p=self._data:GetProfile(player); local item=p and p.RareContent and p.RareContent.RareItems[uniqueId]; if not item or item.CurrentOwnerUserId~=player.UserId or (item.ConsumedAt or 0)>0 then return false,'InvalidOwnership' end
 if self._locks[uniqueId] and self._locks[uniqueId]~=s.Id then return false,'Locked' end
 local bag=side(s,player.UserId)=='A' and s.RareA or s.RareB
 if enabled then bag[uniqueId]=true; self._locks[uniqueId]=s.Id else bag[uniqueId]=nil; self._locks[uniqueId]=nil end; reset(s); return true,'Updated'
end
function Service:_release(s) for id in pairs(s.RareA) do if self._locks[id]==s.Id then self._locks[id]=nil end end for id in pairs(s.RareB) do if self._locks[id]==s.Id then self._locks[id]=nil end end end
function Service:Cancel(player,reason) local s=self._sessions[player.UserId]; if not s then return false,'NoSession' end; self:_release(s); self._sessions[s.A]=nil; self._sessions[s.B]=nil; return true,reason or 'Cancelled' end
function Service:Disconnect(player) if self._sessions[player.UserId] then self:Cancel(player,'Disconnect') end; self._invites[player.UserId]=nil end
function Service:Confirm(player)
 local s=self:_session(player); if not s then return false,'NoSession' end
 if side(s,player.UserId)=='A' then s.ConfirmedA=true else s.ConfirmedB=true end
 if not (s.ConfirmedA and s.ConfirmedB) then return true,'Confirmed' end
 local pa=Players:GetPlayerByUserId(s.A); local pb=Players:GetPlayerByUserId(s.B); if not pa or not pb then self:Cancel(player,'Offline'); return false,'Offline' end
 local a=self._data:GetProfile(pa); local b=self._data:GetProfile(pb); if not a or not b then return false,'NoProfile' end
 if a.Progression.Gold<s.GoldA or b.Progression.Gold<s.GoldB then reset(s); return false,'InsufficientFunds' end
 for id,q in pairs(s.ItemsA) do if (a.Inventory[id] or 0)<q then reset(s); return false,'InvalidOwnership' end end
 for id,q in pairs(s.ItemsB) do if (b.Inventory[id] or 0)<q then reset(s); return false,'InvalidOwnership' end end
 local snap={ga=a.Progression.Gold,gb=b.Progression.Gold,ia={},ib={}}
 for id,q in pairs(s.ItemsA) do snap.ia[id]=a.Inventory[id]; snap.ib[id]=b.Inventory[id] end
 for id,q in pairs(s.ItemsB) do snap.ia[id]=a.Inventory[id]; snap.ib[id]=b.Inventory[id] end
 local function move(src,dst,id,q) src.Inventory[id]=(src.Inventory[id] or 0)-q; if src.Inventory[id]<=0 then src.Inventory[id]=nil end; dst.Inventory[id]=(dst.Inventory[id] or 0)+q end
 a.Progression.Gold=a.Progression.Gold-s.GoldA+s.GoldB; b.Progression.Gold=b.Progression.Gold-s.GoldB+s.GoldA
 for id,q in pairs(s.ItemsA) do move(a,b,id,q) end; for id,q in pairs(s.ItemsB) do move(b,a,id,q) end
 for id in pairs(s.RareA) do local ok=self._rare:TransferItem(pa,pb,id,{TransferSource='PlayerTrade',TransactionId=s.Id}); if not ok then reset(s); return false,'RareTransferFailed' end end
 for id in pairs(s.RareB) do local ok=self._rare:TransferItem(pb,pa,id,{TransferSource='PlayerTrade',TransactionId=s.Id}); if not ok then reset(s); return false,'RareTransferFailed' end end
 self._economy:Record(a,{TransactionId=s.Id..':A',Type='PlayerTrade',Timestamp=now(),Source=s.A,Destination=s.B,Amount=s.GoldA,Status='Committed'}); self._economy:Record(b,{TransactionId=s.Id..':B',Type='PlayerTrade',Timestamp=now(),Source=s.B,Destination=s.A,Amount=s.GoldB,Status='Committed'})
 self._data:Apply(pa); self._data:Apply(pb); self:_release(s); self._sessions[s.A]=nil; self._sessions[s.B]=nil; return true,'Complete'
end
function Service:GetSession(player) return self:_session(player) end
function Service:GetLocks() return self._locks end
return Service
