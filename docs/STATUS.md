# NEW LIFE ROBLOX — STATUS

Data: 2026-09-29

## Fase atual

**FASE 12 — LOST CLASSES, LEGENDARY BOOKS & RELICS: PASS COM RESSALVA.**

Ressalva obrigatória: **MULTIPLAYER REAL 2+ CLIENTS = NOT EXECUTED**. O runtime disponível teve `PlayerCount = 1`.

Fases 0–6 permanecem congeladas com PASS; Fases 7–11 não foram revalidadas nesta tarefa.

## Implementado

- Extinct Classes: exatamente 5 IDs técnicos `ExtinctClass_01` a `ExtinctClass_05`, todos com chaves de display/localização substituíveis e sem lore definitivo inventado.
- Extinct Class Book: ownership e elegibilidade server-side, uma Extinct Class por personagem, seleção aleatória no servidor, consumo atômico e permanente, sem escolha manual.
- Level Reset: ao consumir o livro, Level = 1 e XP = 0; inicia progressão da nova classe em Mastery 0 / Level 1.
- Permanent Progress: preserva FateSeed/Birth, raça e RaceProgress, Titles, Legacy, PlayerChronicle, NPCMemory, Guild/Social/Kingdom, Bosses/Dungeons, cosméticos/históricos existentes, RareContent/proveniência e desbloqueios permanentes apropriados.
- Announcement canônico: `a Predestined was born.` emitido somente quando a transformação rara realmente ocorre.
- Legendary Skill: `LegendarySkill_01` provisória e funcional, integrada ao SkillService/Build.Unlocked.
- Legendary Magic: `LegendaryMagic_01` provisória e funcional, reutilizando validação de ownership, mastery, cooldown, mana, alcance e dano do MagicService.
- Monthly Opportunities: `ExtinctClassBook`, `LegendarySkillBook` e `LegendaryMagicBook`; decisão mensal server-authoritative, mês zero-opportunity possível e no máximo um claim aceito por tipo/estado persistido.
- Persistência mensal: produção usa `UpdateAsync` no mesmo registro mensal para decidir e marcar `Claimed`, `ClaimedBy`, `ClaimedAt` e `ItemUniqueId` de forma atômica. O item só é concedido ao vencedor da transação.
- Ownership/Provenance: `UniqueItemId`, `ItemType`, `CreatedAt`, `CreatedServerId`, `FirstOwnerUserId`, `CurrentOwnerUserId`, `OwnershipHistory`, `AcquisitionSource`, `WorldEventId`, `Version` e `ConsumedAt`.
- Trade foundation: `TransferItem` server-side valida ownership, item consumido, duplicação e atualização de unicidade antes de mover o item. Nenhum remote público de trade foi aberto nesta fase.
- Relics: 9 categorias técnicas (`Weapon`, `Armor`, `Helm`, `Gloves`, `Boots`, `Amulet`, `Ring`, `Focus`, `Cloak`) × 5 linhagens canônicas (`Void`, `FallenKing`, `CrimsonMoon`, `EternalStorm`, `FirstHero`) = 45 configs.
- Cada relic config contém categoria, linhagem, rarity, stats, passive, active opcional, equip rules, level/rank requirements, proveniência, set metadata, localization keys e `UniquenessPolicy`.
- Set Synergy: bônus data-driven por linhagem em 2 peças e 3 peças.
- Uniqueness: `Normal`, `Rare`, `ServerLimited`, `WorldUnique`; policies limitadas usam registry server-side e produção persiste a claim via DataStore.
- Open World: `LostArchiveCache` em Mossfall Ruins, longe do spawn, com `RareContentHook=true` e validação server-side de distância antes de qualquer tentativa de claim.
- Dungeon: DungeonService recebe RareContentService no Bootstrap e, ao concluir dungeon, só tenta item raro através do gate mensal; farm normal não ignora a oportunidade global.
- Chronicles: aquisição/consumo raro real grava Player Chronicle e/ou World Chronicle; anúncios globais ficam restritos aos fatos raros relevantes.
- Networking: cliente envia apenas intenção para `RareUseItem`, `RareEquipRelic`, `RareUnequipRelic` e `RareOpenWorldClaim`; decisão, ownership, range, consumo e efeitos permanecem no servidor.
- Security: proteção contra IDs falsos, ownership falso, replay/double-consume, duplicate item IDs, races de claim mensal, spoof de open-world range e conflitos de unicidade.
- Save: versão `1.3.0-rare-content`, Schema 12. `RareContent` é aditivo ao perfil e separa dados duráveis do jogador do world-state mensal/unicidade.
- Localization Prep: `pt-BR`, `en-US`, `es`, `ja`, `zh`, `ru`.
- Canon Fixes preservados: produção = ciclo de 24 horas reais pelo relógio do servidor; aceleração apenas Studio/Debug; Guiding Wind acionável/environment-ready; HUD textual apenas debug/fallback.

## Correções finais desta fase

- Claim mensal em produção deixou de ser cache-only e passou a usar `UpdateAsync` atômico no registro mensal.
- `TryAcquireOpenWorld` agora exige HumanoidRootPart dentro de `InteractDistance`; requests remotos fora do alcance retornam sem prêmio.
- Unicidade de relics `ServerLimited`/`WorldUnique` ganhou registry persistente e validação em grant/equip/transfer.
- `WorldFoundationService` deixou de escrever `StreamingEnabled` em runtime; `StreamingEnabled=true` foi mantido no estado do Place em Edit, eliminando o erro de capability no boot.

## Validação Fase 12

- T-1200–T-1243 / `Phase12RareContent_Test`: **44/44 PASS**, **0 failed**.
- Cobertura inclui 5 classes, reset=1, one-per-character, preservação permanente, oportunidade determinística/zero-month, skill/magic, 45 relic configs, sinergia, anúncio, localização, distância e unicidade.
- Play limpo: `[NewLife] FASE 12 lost classes, legendary books and relics online`; nenhum erro New Life no boot final.
- `RequestInitialState` real retornou `FoundationVersion = 1.3.0-rare-content`, `SchemaVersion = 12` e `RareContent` presente.
- Requests reais com `FAKE-RARE-ID`, `FAKE-RELIC-ID` e `RareOpenWorldClaim` fora do alcance não alteraram inventário raro, equipamentos ou Extinct Class.
- `LostArchiveCache` confirmado em `Workspace.NewLife.World.OpenWorldFoundation`, posição `(220,4,40)`, com distância de interação 14.
- `PlayerCount = 1`; **MULTIPLAYER REAL 2+ CLIENTS = NOT EXECUTED**.
- Studio confirmado em `Edit` ao final.

## Gate

**FASE 12 = PASS COM RESSALVA — MULTIPLAYER REAL 2+ CLIENTS: NOT EXECUTED**

## Próxima fase

**FASE 13 — ECONOMY, TRADING, MARKETS & ITEM PROVENANCE**
