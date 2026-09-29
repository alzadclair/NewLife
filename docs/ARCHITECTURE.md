# NEW LIFE ROBLOX — ARCHITECTURE

## Princípio central

O servidor é autoritativo. O cliente pode solicitar ações, mas não informa dano, cooldown, distância, valores de atributos, resultado de save ou estado crítico como verdadeiro.

## DataModel

```text
ReplicatedStorage
└─ NewLife
   ├─ Remotes
   │  ├─ ActionRequest : RemoteEvent
   │  ├─ SystemMessage : RemoteEvent
   │  └─ RequestInitialState : RemoteFunction
   └─ Shared
      ├─ Config
      │  ├─ GameConfig
      │  ├─ AttributeConfig
      │  ├─ ContentDefinitions
      │  └─ LocalizationConfig
      └─ Modules
         ├─ StateDefinitions
         └─ NetProtocol

ServerScriptService
└─ NewLifeServer
   ├─ Bootstrap
   └─ Services
      ├─ PlayerDataService
      ├─ StateService
      ├─ CharacterService
      ├─ CombatService
      └─ NetworkService

ServerStorage
└─ NewLife
   ├─ Runtime
   └─ Templates

StarterPlayer
└─ StarterPlayerScripts
   └─ NewLifeClient
      ├─ Bootstrap
      └─ Controllers
         ├─ InputController
         └─ HUDController

StarterGui
└─ NewLifeHUD
   └─ Root
      ├─ Title
      ├─ HealthBar
      ├─ ManaBar
      ├─ StaminaBar
      ├─ Stats
      └─ Status

Workspace
└─ NewLife
   ├─ Runtime
   ├─ World
   └─ NPCs
```

## Fluxo de inicialização

1. `Bootstrap` do servidor inicia PlayerDataService.
2. CharacterService conecta ciclo de personagem e regeneração.
3. CombatService recebe StateService.
4. NetworkService conecta os Remotes e valida todas as entradas.
5. No cliente, HUDController e InputController são iniciados.
6. O cliente solicita `RequestInitialState`, que devolve somente snapshot sanitizado.

## Networking

### ActionRequest

Único canal de intenção de gameplay da Fase 0. Ações permitidas: `LightAttack`, `Block`, `Sprint`.

Validações no servidor:

- action precisa ser string conhecida;
- rate limit por jogador/ação;
- payload tem tipo esperado;
- estados Dead/Stunned bloqueiam ações incompatíveis;
- alvo de ataque deve ser Instance/Model válido com Humanoid;
- alvo deve estar no Workspace;
- distância máxima é validada no servidor;
- linha de visão usa raycast do servidor;
- dano é calculado e aplicado pelo servidor.

### RequestInitialState

Retorna apenas informações necessárias ao cliente: snapshot do perfil, horário do servidor e versão da fundação.

## Persistência

`PlayerDataService` prepara `DataStoreService` com schema versionado e `UpdateAsync` em ambiente publicado. Durante Studio, usa modo `StudioMemory` para que Play Solo não dependa de API Services.

## Estado e tags

Estados reconhecidos: Alive, Attacking, Blocking, Sprinting, Stunned e Dead. `StateService` espelha estado em Attributes e em tags `NL_State_<Estado>` via `CollectionService`.

## Segurança

O cliente nunca calcula ou define diretamente dano, valores persistentes, Legacy, Race/Class, cooldown válido ou resultado de combate. Attributes replicados são apresentação de estado; a autoridade continua no servidor.
