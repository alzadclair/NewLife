# NEW LIFE ROBLOX — STATUS

Data: 2026-09-29

## Fase atual

**FASE 13 — ECONOMY, TRADING, MARKETS & ITEM PROVENANCE: PASS PARCIAL / BLOQUEIO DE FERRAMENTA.**

A base autoritativa da economia, trade, marketplace, save e provenance foi implementada e os testes T-1300+ passaram. A tarefa não recebe PASS final porque as últimas edições de UI/localization e centralização dos reward paths, além do fluxo runtime adicional, foram bloqueadas pela revisão automática do ambiente.

## Implementado

- `GameConfig.Version = 1.4.0-economy`; `SchemaVersion = 13`.
- `EconomyConfig` server-owned com `MaxGold`, ledger cap, replay cap, trade timeout, listing duration, listing fee, sale fee, kingdom tax, price-history cap, item policies e Merchant Boran modifier.
- `EconomyService`: valida integer/negative/overflow, earn/spend, replay guard, ledger compacto, vendor buy/sell, item policies e settlement fee/tax.
- `PlayerDataService`: migração aditiva `Economy`, snapshot de Economy e primitivas seguras de inventário `GetItemCount`/`RemoveItem`; `AddItem` passou a rejeitar overflow de stack em vez de truncar silenciosamente.
- `TradeService`: invite → respond → session → offer gold/item/rare → confirm; qualquer mutação reseta confirmações; locks de rare item; cancel/timeout/disconnect; commit server-side.
- `MarketService`: list/cancel/browse/purchase online; item normal vai para escrow por remoção; rare item usa reservation lock; compra rejeita self-purchase e seller offline; fee/tax calculados no servidor; histórico agregado de venda.
- `RareContentService:TransferItem` aceita contexto de transação, preserva `FirstOwnerUserId`, atualiza owner/source/transaction/timestamp/history e bloqueia relic equipada.
- `RulerService:CreditTreasury` credita imposto na tesouraria canônica existente com histórico compacto.
- `NetProtocol`/`NetworkService`: Vendor, Trade e Market actions adicionadas; cliente envia somente intent.
- `RequestInitialState` inclui balance econômico e browse snapshot.
- Bootstrap inicia os três serviços da Fase 13 e registra `FASE 13 economy, trading and markets online`.
- Canon fixes das fases anteriores preservados: produção 24h real; aceleração somente Studio/Debug; Guiding Wind acionável/environment-ready; texto do vento apenas debug/fallback.

## Validação

- `Phase13Economy_Test`: **26/26 PASS**, 0 failed.
- IDs: T-1300–T-1325.
- Cobertura executada: Schema 13, valid/invalid amounts, negative, fractional, NaN, exact spend, insufficient funds atomicity, overflow, invalid balance, item policy, settlement conservation, fee/tax integer, listing fee, kingdom tax config, ledger compaction, network intents/rate limits, timeout/expiry/history config e presença dos serviços.
- Runtime iniciou com `[NewLife] FASE 13 economy, trading and markets online`.
- Console não mostrou erro Luau dos novos módulos. Houve um erro do comando antigo do runner (`attempt to call a table value`) e avisos externos `robloxstudio-mcp /ready ... ConnectFail`; ambos são da ferramenta/harness, não da lógica da Fase 13.
- Tentativa de integração direta earn → vendor buy/sell → market list/self-purchase foi bloqueada pela revisão automática antes de executar.
- `MULTIPLAYER REAL 2+ CLIENTS = NOT EXECUTED`.
- Studio confirmado em Edit ao final.

## Pendências para PASS final

- Criar/ligar UI mínima funcional de Vendor/Trade/Market no cliente.
- Preparar strings novas em pt-BR/en-US/es/ja/zh/ru.
- Centralizar os reward paths antigos de Quest/Enemy/Dungeon/WorldBoss em `EconomyService` sem regressão.
- Executar integração runtime de vendor/trade/market e teste concorrente de simultaneous purchase/double-spend.
- Validar 2+ clientes reais quando o ambiente permitir.
- Offline seller payout/receivable continua arquitetural; o fluxo implementado e testável nesta fase é o seller online.

## Gate

**FASE 13 = PASS PARCIAL / BLOQUEIO DE FERRAMENTA**

## Próxima fase

**FASE 14 — PVP, BOUNTIES, GUILD WARS & ANTI-GRIEF**
