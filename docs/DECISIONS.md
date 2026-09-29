# NEW LIFE ROBLOX — DECISIONS

## ADR-001 — Servidor autoritativo

Toda lógica crítica de combate, estado, atributos persistentes e save pertence ao servidor. O cliente envia intenção.

## ADR-002 — Namespace único

Todo sistema novo da fundação usa `NewLife` como raiz nos serviços principais para evitar colisões e facilitar expansão.

## ADR-003 — Conteúdo data-driven

Raças, classes, skills e itens serão definidos por dados/registries. A Fase 0 fornece schema e placeholders mínimos, sem produzir os catálogos finais.

## ADR-004 — Attributes para estado replicado

Attributes são usados para estado simples observável no HUD e debug. Estados também recebem tags via CollectionService. Estado crítico continua sendo escrito pelo servidor.

## ADR-005 — Save versionado

Perfis carregam `SchemaVersion`. Persistência usa `UpdateAsync`. Em Studio, o serviço usa memória para não depender de API Services durante desenvolvimento.

## ADR-006 — Remotes pequenos e explícitos

A Fase 0 usa `ActionRequest`, `SystemMessage` e `RequestInitialState`. O protocolo fica centralizado em `NetProtocol` para evitar strings espalhadas.

## ADR-007 — Arte temporária

O HUD é funcional e propositalmente simples. Arte final, identidade visual avançada e animações de produção ficam fora da Fase 0.
