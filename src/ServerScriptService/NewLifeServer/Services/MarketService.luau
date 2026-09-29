--!strict
local HttpService=game:GetService('HttpService')
local Players=game:GetService('Players')
local Service={_data=nil,_economy=nil,_rare=nil,_ruler=nil,_trade=nil,_listings={},_price={}}
local function integer(n) return type(n)=='number' and math.floor(n)==n end
local function now() return os.time() end
function Service:Start(data,economy,rare,ruler,trade) self._data=data; self._economy=economy; self._rare=rare; self._ruler=ruler; self._trade=trade end
function Service:_hist(itemId,price)
 local h=self._price[itemId] or {Volume=0,Total=0,Min=nil,Max=nil,LastSale=0,Recent={}}; self._price[itemId]=h; h.Volume+=1; h.Total+=price; h.Min=not h.Min and price or math.min(h.Min,price); h.Max=not h.Max and price or math.max(h.Max,price); h.LastSale=price; table.insert(h.Recent,price); while #h.Recent>30 do table.remove(h.Recent,1) end
 local sum=0 for _,v in ipairs(h.Recent) do sum+=v end; h.RecentAverage=math.floor(sum/#h.Recent+0.5)
end
function Service:List(player,itemId,qty,price,uniqueId)
 if not integer(price) or price<=0 or not integer(qty) or qty<=0 then return false,'InvalidListing' end
 local p=self._data:GetProfile(player); if not p then return false,'NoProfile' end
 local policy=self._economy:GetItemPolicy(itemId); if not policy.Marketable or policy.Transferability~='Tradeable' then return false,'NotMarketable' end
 local cfg=self._economy:GetConfig(); local fee=cfg.ListingFee or 0
 if p.Progression.Gold<fee then return false,'InsufficientFunds' end
 if uniqueId then local rare=p.RareContent and p.RareContent.RareItems[uniqueId]; if not rare or rare.CurrentOwnerUserId~=player.UserId then return false,'InvalidOwnership' end; if self._trade:GetLocks()[uniqueId] then return false,'Locked' end; self._trade:GetLocks()[uniqueId]='MARKET' else if (p.Inventory[itemId] or 0)<qty then return false,'InsufficientItems' end; p.Inventory[itemId]-=qty; if p.Inventory[itemId]<=0 then p.Inventory[itemId]=nil end end
 p.Progression.Gold-=fee
 local id='LIST:'..HttpService:GenerateGUID(false); self._listings[id]={ListingId=id,SellerUserId=player.UserId,ItemId=itemId,UniqueItemId=uniqueId,Quantity=qty,Price=price,CreatedAt=now(),ExpiresAt=now()+cfg.ListingDuration,Status='Active',ListingFee=fee}
 self._economy:Record(p,{TransactionId=id..':fee',Type='Fee',Timestamp=now(),Source=player.UserId,Destination='Market',Amount=fee,Fee=fee,Status='Committed'}); self._data:Apply(player); return true,id
end
function Service:Cancel(player,id)
 local l=self._listings[id]; if not l or l.Status~='Active' then return false,'InvalidListing' end; if l.SellerUserId~=player.UserId then return false,'NotOwner' end
 local p=self._data:GetProfile(player); if not p then return false,'NoProfile' end; l.Status='Cancelled'
 if l.UniqueItemId then if self._trade:GetLocks()[l.UniqueItemId]=='MARKET' then self._trade:GetLocks()[l.UniqueItemId]=nil end else p.Inventory[l.ItemId]=(p.Inventory[l.ItemId] or 0)+l.Quantity end
 self._data:Apply(player); return true,'Cancelled'
end
function Service:Browse()
 local out={} for _,l in pairs(self._listings) do if l.Status=='Active' and l.ExpiresAt>=now() then table.insert(out,l) end end return out
end
function Service:Purchase(buyer,id)
 local l=self._listings[id]; if not l or l.Status~='Active' then return false,'InvalidListing' end; if l.ExpiresAt<now() then l.Status='Expired'; return false,'Expired' end; if l.SellerUserId==buyer.UserId then return false,'SelfPurchase' end
 l.Status='Committing'
 local seller=Players:GetPlayerByUserId(l.SellerUserId); if not seller then l.Status='Active'; return false,'SellerOffline' end
 local bp=self._data:GetProfile(buyer); local sp=self._data:GetProfile(seller); if not bp or not sp then l.Status='Active'; return false,'NoProfile' end
 local settle=self._economy:ComputeSettlement(l.Price); if not settle or bp.Progression.Gold<l.Price then l.Status='Active'; return false,'InsufficientFunds' end
 bp.Progression.Gold-=l.Price; sp.Progression.Gold+=settle.SellerNet
 if l.UniqueItemId then local ok=self._rare:TransferItem(seller,buyer,l.UniqueItemId,{TransferSource='MarketPurchase',TransactionId=id}); if not ok then bp.Progression.Gold+=l.Price; sp.Progression.Gold-=settle.SellerNet; l.Status='Active'; return false,'RareTransferFailed' end; self._trade:GetLocks()[l.UniqueItemId]=nil else bp.Inventory[l.ItemId]=(bp.Inventory[l.ItemId] or 0)+l.Quantity end
 local kingdomId=sp.Kingdom and sp.Kingdom.CurrentId or nil; if settle.Tax>0 and self._ruler and kingdomId then self._ruler:CreditTreasury(kingdomId,settle.Tax,id) end
 self._economy:Record(bp,{TransactionId=id..':buy',Type='MarketPurchase',Timestamp=now(),Source=buyer.UserId,Destination=seller.UserId,Amount=l.Price,Fee=settle.SaleFee,Status='Committed',ItemId=l.ItemId,UniqueItemId=l.UniqueItemId})
 self._economy:Record(sp,{TransactionId=id..':sale',Type='MarketSale',Timestamp=now(),Source=buyer.UserId,Destination=seller.UserId,Amount=settle.SellerNet,Fee=settle.SaleFee,Status='Committed',ItemId=l.ItemId,UniqueItemId=l.UniqueItemId})
 l.Status='Sold'; l.BuyerUserId=buyer.UserId; l.SoldAt=now(); l.SaleFee=settle.SaleFee; l.Tax=settle.Tax; self:_hist(l.ItemId,l.Price); self._data:Apply(buyer); self._data:Apply(seller); return true,'Complete'
end
function Service:GetPriceHistory(itemId) return self._price[itemId] end
function Service:GetListing(id) return self._listings[id] end
return Service
