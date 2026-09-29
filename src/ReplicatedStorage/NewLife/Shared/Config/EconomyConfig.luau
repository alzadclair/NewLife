--!strict
return {
 Version='phase13-v1', MaxGold=2000000000, LedgerCap=80, ProcessedTransactionCap=120,
 TradeTimeout=120, ListingDuration=86400, ListingFee=2, SaleFeeRate=0.05, KingdomTaxRate=0.02,
 PriceHistoryCap=30,
 Transferability={Tradeable='Tradeable',AccountBound='AccountBound',CharacterBound='CharacterBound',NonTransferable='NonTransferable'},
 DefaultPolicy={BaseValue=1,SellValue=1,Tradeable=true,Marketable=true,Transferability='Tradeable',Rarity='Common'},
 ItemPolicies={
  SlimeGel={BaseValue=5,SellValue=2,Tradeable=true,Marketable=true,Transferability='Tradeable',Rarity='Common'},
  BruteCore={BaseValue=25,SellValue=12,Tradeable=true,Marketable=true,Transferability='Tradeable',Rarity='Uncommon'},
 },
 MerchantBoran={NpcId='MerchantBoran',MinModifier=0.80,MaxModifier=1.15,ReputationStep=0.0025},
}
