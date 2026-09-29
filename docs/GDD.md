# NEW LIFE ROBLOX — GDD

## Visão

NEW LIFE é um RPG de progressão e consequência construído sobre quatro pilares:

- **SKILL** — domínio adquirido por prática, escolhas de build e execução do jogador.
- **FATE** — condições iniciais e acontecimentos que o jogador não controla totalmente.
- **CHOICE** — decisões mecânicas e narrativas que mudam o caminho do personagem.
- **LEGACY** — consequências persistentes do que o jogador fez no mundo.

> "Você nasce com um destino.  
> Você decide o que fazer com ele.  
> E o mundo se lembra do que você fez."

## Escopo da Fase 0

A Fase 0 entrega somente a fundação técnica: arquitetura modular, estado do personagem, atributos, input, networking seguro, combate base, persistência preparada, localization, HUD de teste e documentação.

Não fazem parte desta fase as 30 raças, 15 classes, classes extintas, guildas, reinos, dungeons finais, bosses finais ou monetização.

## Atributos base

| Atributo | Valor inicial | Papel |
|---|---:|---|
| Health | 100 | vida base / MaxHealth do Humanoid |
| Mana | 100 | recurso para sistemas mágicos futuros |
| Stamina | 100 | recurso para sprint e ações físicas |
| Strength | 10 | componente físico de dano |
| Defense | 5 | mitigação de dano |
| Power | 10 | componente de poder/skill de dano |

## Combate da fundação

O ataque leve existe apenas para validar a arquitetura. O cliente envia intenção e um alvo opcional. O servidor valida estado, cooldown, tipo do alvo, distância e linha de visão; o servidor calcula e aplica o dano.

## Conteúdo data-driven

`ContentDefinitions` contém apenas placeholders de schema: `Human` e `Adventurer`. Skills e Items permanecem vazios para a expansão futura.

## Experiência nesta fase

O jogador deve entrar, receber perfil e atributos, spawnar com estado válido, visualizar Health/Mana/Stamina e stats no HUD, usar ataque/bloqueio/sprint e manter toda decisão crítica no servidor.
