--!strict
-- Phase 13 contract tests. IDs intentionally begin at T-1300.
return function(t)
    local RS=game:GetService('ReplicatedStorage')
    local SSS=game:GetService('ServerScriptService')
    local GameConfig=require(RS.NewLife.Shared.Config.GameConfig)
    local EconomyConfig=require(RS.NewLife.Shared.Config.EconomyConfig)
    local NetProtocol=require(RS.NewLife.Shared.Modules.NetProtocol)
    local Economy=require(SSS.NewLifeServer.Services.EconomyService)
    local expect=t.expect
    local function profile(gold)
        return {Progression={Gold=gold or 0},Economy={Ledger={},ProcessedTransactions={},Receivables={},Market={}},Inventory={}}
    end

    -- T-1300: schema advances additively for durable economy metadata.
    t.test('T-1300 schema is 13',function() expect.equal(GameConfig.SchemaVersion,13) end)
    -- T-1301: positive integer amounts are accepted.
    t.test('T-1301 accepts positive integer amount',function() expect.truthy(Economy.IsValidAmount(25)) end)
    -- T-1302: zero cannot be minted or spent.
    t.test('T-1302 rejects zero amount',function() expect.falsy(Economy.IsValidAmount(0)) end)
    -- T-1303: negative values cannot become transactions.
    t.test('T-1303 rejects negative amount',function() expect.falsy(Economy.IsValidAmount(-5)) end)
    -- T-1304: fractional money is rejected.
    t.test('T-1304 rejects fractional amount',function() expect.falsy(Economy.IsValidAmount(1.5)) end)
    -- T-1305: NaN is rejected.
    t.test('T-1305 rejects nan',function() expect.falsy(Economy.IsValidAmount(0/0)) end)
    -- T-1306: balances can increase within the cap.
    t.test('T-1306 applies earn delta',function() local p=profile(10); local ok,n=Economy.ApplyDelta(p,15); expect.truthy(ok); expect.equal(n,25); expect.equal(p.Progression.Gold,25) end)
    -- T-1307: spend rejects insufficient funds atomically.
    t.test('T-1307 rejects insufficient funds',function() local p=profile(10); local ok,r=Economy.ApplyDelta(p,-11); expect.falsy(ok); expect.equal(r,'InsufficientFunds'); expect.equal(p.Progression.Gold,10) end)
    -- T-1308: exact-balance spend succeeds.
    t.test('T-1308 permits exact spend',function() local p=profile(10); local ok,n=Economy.ApplyDelta(p,-10); expect.truthy(ok); expect.equal(n,0) end)
    -- T-1309: overflow is rejected without mutation.
    t.test('T-1309 rejects overflow',function() local p=profile(EconomyConfig.MaxGold); local ok,r=Economy.ApplyDelta(p,1); expect.falsy(ok); expect.equal(r,'Overflow'); expect.equal(p.Progression.Gold,EconomyConfig.MaxGold) end)
    -- T-1310: invalid starting balance cannot be laundered.
    t.test('T-1310 rejects invalid balance',function() local p=profile(-1); local ok,r=Economy.ApplyDelta(p,1); expect.falsy(ok); expect.equal(r,'InvalidBalance') end)
    -- T-1311: default item policy is transferable and marketable.
    t.test('T-1311 default item policy',function() local p=Economy:GetItemPolicy('__unknown__'); expect.equal(p.Transferability,'Tradeable'); expect.truthy(p.Tradeable); expect.truthy(p.Marketable) end)
    -- T-1312: vendor item policy keeps configured base value.
    t.test('T-1312 slime policy',function() local p=Economy:GetItemPolicy('SlimeGel'); expect.equal(p.BaseValue,5); expect.equal(p.SellValue,2) end)
    -- T-1313: settlement conserves price across seller net, fee and tax.
    t.test('T-1313 settlement conserves price',function() local s=Economy:ComputeSettlement(100); expect.equal(s.SellerNet+s.SaleFee+s.Tax,100) end)
    -- T-1314: fees are nonnegative integers.
    t.test('T-1314 settlement fee integer',function() local s=Economy:ComputeSettlement(101); expect.truthy(s.SaleFee>=0 and math.floor(s.SaleFee)==s.SaleFee); expect.truthy(s.Tax>=0 and math.floor(s.Tax)==s.Tax) end)
    -- T-1315: listing fees are configured server-side.
    t.test('T-1315 listing fee configured',function() expect.truthy(type(EconomyConfig.ListingFee)=='number'); expect.truthy(EconomyConfig.ListingFee>=0) end)
    -- T-1316: kingdom tax rate is fixed configuration for this phase.
    t.test('T-1316 kingdom tax configured',function() expect.truthy(EconomyConfig.KingdomTaxRate>=0); expect.truthy(EconomyConfig.KingdomTaxRate<1) end)
    -- T-1317: transaction ledger is capped.
    t.test('T-1317 ledger compacts',function() local p=profile(0); for i=1,EconomyConfig.LedgerCap+5 do Economy.Record(p,{TransactionId=tostring(i)}) end; expect.equal(#p.Economy.Ledger,EconomyConfig.LedgerCap); expect.equal(p.Economy.Ledger[1].TransactionId,'6') end)
    -- T-1318: vendor request is a defined authoritative network intent.
    t.test('T-1318 vendor actions exist',function() expect.equal(NetProtocol.Actions.VendorBuy,'VendorBuy'); expect.equal(NetProtocol.Actions.VendorSell,'VendorSell') end)
    -- T-1319: player trade intents are present.
    t.test('T-1319 trade actions exist',function() expect.equal(NetProtocol.Actions.TradeInvite,'TradeInvite'); expect.equal(NetProtocol.Actions.TradeConfirm,'TradeConfirm'); expect.equal(NetProtocol.Actions.TradeCancel,'TradeCancel') end)
    -- T-1320: market intents are present.
    t.test('T-1320 market actions exist',function() expect.equal(NetProtocol.Actions.MarketList,'MarketList'); expect.equal(NetProtocol.Actions.MarketPurchase,'MarketPurchase'); expect.equal(NetProtocol.Actions.MarketCancel,'MarketCancel') end)
    -- T-1321: all economy rate limits are server-owned positive numbers.
    t.test('T-1321 economy rate limits configured',function() for _,a in ipairs({'VendorBuy','VendorSell','TradeInvite','TradeConfirm','MarketList','MarketPurchase'}) do expect.truthy(type(GameConfig.Network.RateLimits[a])=='number' and GameConfig.Network.RateLimits[a]>0) end end)
    -- T-1322: trade timeout is bounded and positive.
    t.test('T-1322 trade timeout configured',function() expect.truthy(EconomyConfig.TradeTimeout>0 and EconomyConfig.TradeTimeout<=600) end)
    -- T-1323: market listings expire.
    t.test('T-1323 listing expiry configured',function() expect.truthy(EconomyConfig.ListingDuration>0) end)
    -- T-1324: price history retains compact aggregate storage.
    t.test('T-1324 price history cap configured',function() expect.truthy(EconomyConfig.PriceHistoryCap>0 and EconomyConfig.PriceHistoryCap<=100) end)
    -- T-1325: the Phase 13 services exist in the canonical server folder.
    t.test('T-1325 services exist',function() local f=SSS.NewLifeServer.Services; expect.truthy(f:FindFirstChild('EconomyService')); expect.truthy(f:FindFirstChild('TradeService')); expect.truthy(f:FindFirstChild('MarketService')) end)
end
