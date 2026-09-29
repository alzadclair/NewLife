--!strict
local HttpService=game:GetService('HttpService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Config=require(ReplicatedStorage.NewLife.Shared.Config.EconomyConfig)
local Content=require(ReplicatedStorage.NewLife.Shared.Config.ContentDefinitions)
local Service={_data=nil,_ruler=nil,_seen={}}
local function integer(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge and math.floor(n)==n end
local function copy(t) local o={} for k,v in pairs(t or {}) do o[k]=type(v)=='table' and copy(v) or v end return o end
local function ensure(profile)
 profile.Economy=type(profile.Economy)=='table' and profile.Economy or {}
 profile.Economy.Ledger=type(profile.Economy.Ledger)=='table' and profile.Economy.Ledger or {}
 profile.Economy.ProcessedTransactions=type(profile.Economy.ProcessedTransactions)=='table' and profile.Economy.ProcessedTransactions or {}
 profile.Economy.Receivables=type(profile.Economy.Receivables)=='table' and profile.Economy.Receivables or {}
 profile.Economy.Market=type(profile.Economy.Market)=='table' and profile.Economy.Market or {Sales=0,Purchases=0,FeesPaid=0,TaxPaid=0}
 return profile.Economy
end
local function capArray(a,n) while #a>n do table.remove(a,1) end end
local function txid(prefix) return (prefix or 'TX')..':'..HttpService:GenerateGUID(false) end
function Service.IsValidAmount(n) return integer(n) and n>0 and n<=Config.MaxGold end
function Service.ApplyDelta(profile,delta)
 if type(profile)~='table' or type(profile.Progression)~='table' or not integer(delta) then return false,'InvalidAmount' end
 local old=profile.Progression.Gold
 if not integer(old) or old<0 then return false,'InvalidBalance' end
 local new=old+delta
 if new<0 then return false,'InsufficientFunds' end
 if new>Config.MaxGold then return false,'Overflow' end
 profile.Progression.Gold=new; return true,new
end
function Service.Record(profile,entry)
 local e=ensure(profile); table.insert(e.Ledger,entry); capArray(e.Ledger,Config.LedgerCap); return entry
end
function Service:_newTx(kind,source,destination,amount,extra)
 local e={TransactionId=txid(kind),Type=kind,Timestamp=os.time(),Source=source,Destination=destination,Amount=amount,Fee=0,Status='Committed'}
 for k,v in pairs(extra or {}) do e[k]=v end
 return e
end
function Service:_markProcessed(profile,id)
 local e=ensure(profile); if e.ProcessedTransactions[id] then return false end
 e.ProcessedTransactions[id]=os.time()
 local keys={} for k,t in pairs(e.ProcessedTransactions) do table.insert(keys,{k=k,t=t}) end
 if #keys>Config.ProcessedTransactionCap then table.sort(keys,function(a,b) return a.t<b.t end); for i=1,#keys-Config.ProcessedTransactionCap do e.ProcessedTransactions[keys[i].k]=nil end end
 return true
end
function Service:Start(data,ruler) self._data=data; self._ruler=ruler end
function Service:GetBalance(player) local p=self._data and self._data:GetProfile(player); return p and p.Progression.Gold or 0 end
function Service:Earn(player,amount,kind,source,extra)
 if not Service.IsValidAmount(amount) then return false,'InvalidAmount' end
 local p=self._data and self._data:GetProfile(player); if not p then return false,'NoProfile' end
 local id=extra and extra.TransactionId or txid(kind or 'Earn')
 if not self:_markProcessed(p,id) then return false,'Replay' end
 local ok,why=Service.ApplyDelta(p,amount); if not ok then return false,why end
 local e=self:_newTx(kind or 'SystemGrantDebug',source or 'System',player.UserId,amount,extra); e.TransactionId=id; self:Record(p,e); self._data:Apply(player); return true,e
end
function Service:Spend(player,amount,kind,destination,extra)
 if not Service.IsValidAmount(amount) then return false,'InvalidAmount' end
 local p=self._data and self._data:GetProfile(player); if not p then return false,'NoProfile' end
 local id=extra and extra.TransactionId or txid(kind or 'Spend')
 if not self:_markProcessed(p,id) then return false,'Replay' end
 local ok,why=Service.ApplyDelta(p,-amount); if not ok then return false,why end
 local e=self:_newTx(kind or 'Fee',player.UserId,destination or 'System',amount,extra); e.TransactionId=id; self:Record(p,e); self._data:Apply(player); return true,e
end
function Service:GetItemPolicy(itemId)
 local p=Config.ItemPolicies[itemId] or {}; local d=copy(Config.DefaultPolicy); for k,v in pairs(p) do d[k]=v end
 local def=Content.Items[itemId]; if def then d.Rarity=def.Rarity or d.Rarity end
 return d
end
function Service:GetVendorPrice(player,npcId,itemId,isBuy)
 if npcId~=Config.MerchantBoran.NpcId then return nil,'InvalidVendor' end
 local npc=Content.NPCs[npcId]; local stock=npc and npc.Inventory and npc.Inventory[itemId]; if not stock then return nil,'NotSold' end
 local p=self._data and self._data:GetProfile(player); if not p then return nil,'NoProfile' end
 local rep=((p.Relationships or {})[npcId] or {}).Reputation or 0
 local modifier=math.clamp(1-rep*Config.MerchantBoran.ReputationStep,Config.MerchantBoran.MinModifier,Config.MerchantBoran.MaxModifier)
 local base=tonumber(stock.Price) or self:GetItemPolicy(itemId).BaseValue
 if isBuy then return math.max(1,math.floor(base*modifier+0.5)),modifier end
 return math.max(1,math.floor(self:GetItemPolicy(itemId).SellValue/math.max(modifier,0.01)+0.5)),modifier
end
function Service:VendorBuy(player,npcId,itemId,qty)
 if not integer(qty) or qty<=0 or qty>99 then return false,'InvalidQuantity' end
 local price=self:GetVendorPrice(player,npcId,itemId,true); if not price then return false,'InvalidItem' end
 local total=price*qty; if total>Config.MaxGold then return false,'Overflow' end
 local profile=self._data:GetProfile(player); if not profile then return false,'NoProfile' end
 local before=profile.Progression.Gold
 local ok,why=Service.ApplyDelta(profile,-total); if not ok then return false,why end
 if not self._data:AddItem(player,itemId,qty) then profile.Progression.Gold=before; return false,'InventoryRejected' end
 local e=self:_newTx('VendorBuy',player.UserId,npcId,total,{ItemId=itemId,Quantity=qty,UnitPrice=price}); self:Record(profile,e); self._data:Apply(player); return true,e
end
function Service:VendorSell(player,npcId,itemId,qty)
 if not integer(qty) or qty<=0 or qty>99 then return false,'InvalidQuantity' end
 local policy=self:GetItemPolicy(itemId); if policy.SellValue<=0 then return false,'NotSellable' end
 local profile=self._data:GetProfile(player); if not profile then return false,'NoProfile' end
 if (profile.Inventory[itemId] or 0)<qty then return false,'InsufficientItems' end
 local price=self:GetVendorPrice(player,npcId,itemId,false); if not price then return false,'InvalidItem' end
 local total=price*qty; local oldCount=profile.Inventory[itemId]; profile.Inventory[itemId]=oldCount-qty; if profile.Inventory[itemId]<=0 then profile.Inventory[itemId]=nil end
 local ok,why=Service.ApplyDelta(profile,total); if not ok then profile.Inventory[itemId]=oldCount; return false,why end
 local e=self:_newTx('VendorSell',npcId,player.UserId,total,{ItemId=itemId,Quantity=qty,UnitPrice=price}); self:Record(profile,e); self._data:Apply(player); return true,e
end
function Service:ComputeSettlement(price)
 if not Service.IsValidAmount(price) then return nil end
 local saleFee=math.floor(price*Config.SaleFeeRate+0.5); local tax=math.floor(price*Config.KingdomTaxRate+0.5); if saleFee+tax>=price then tax=math.max(0,price-saleFee-1) end
 return {Price=price,SaleFee=saleFee,Tax=tax,SellerNet=price-saleFee-tax}
end
function Service:GetConfig() return Config end
return Service
