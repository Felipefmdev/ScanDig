# Relatório de QA por bot (#126)

Rodada de 2026-10-19 sobre `main` 940bf0b + correções deste lote. Máquina: RTX 4060, Godot 4.3
(build de debug do editor), janela 1920x1080, vsync desligado e sem limite de FPS (configuração
salva do jogador). Os números vêm de `tools/bot/qa_report.py`.

## Como repetir

```bash
G=/c/Godot/Godot_v4.3-stable_win64_console.exe
python tools/bot/qa_gen.py              # gera tools/bot/qa_*.json
bash tools/bot/run_qa.sh "$G"           # todos (≈ 10 min); guarda e repõe o user://
bash tools/bot/run_qa.sh "$G" tools/bot/qa_geleira.json   # só um
```

Saída: `.bot_runs/qa_logs/<roteiro>.log` (log do Godot), `.bot_runs/qa_<roteiro>_<data>/` (dumps e
capturas) e `.bot_runs/qa_logs/report.md` (tabela).

Cada `qa_<mapa>.json` parte da Base com tudo liberado, vai ao mapa de dia (~20 s andando com o
`explore`, um dump de FPS a cada ~2 s), força o clima do mapa (onde houver) e anda mais ~10 s, volta
à Base, repete à noite (onde houver) e faz uma 3.ª ida curta. Os órfãos
(`Performance.OBJECT_ORPHAN_NODE_COUNT`) são lidos antes, no fim de cada cena e de volta à Base.

## Mapas

FPS: média / mínimo das amostras de 1 s (`Engine.get_frames_per_second()`), sem a 1.ª amostra
(carregamento). "à saída" = avisos do Godot ao fechar (vazamentos de RID/ObjectDB, todos causados
pelos órfãos de #128).

| mapa | fase | SCRIPT ERROR | erros | warnings | órfãos lobby → fim da cena → lobby | FPS méd / mín |
|---|---|---|---|---|---|---|
| Praia | dia | 0 | 54 (#127) | 0 (+36 à saída) | 0 → 4 → 4 | 579 / 554 |
| Praia | dia + chuva | 〃 | 〃 | 〃 | (mesma ida) | 568 / 548 |
| Praia | noite | 〃 | 〃 | 〃 | 4 → 8 → 8 | 568 / 542 |
| Praia | 3.ª ida | | | | 12 → 12 | |
| Campo | dia | 0 | 72 (#127) | 0 (+42 à saída) | 0 → 5 → 5 | 533 / 511 |
| Campo | dia + chuva | 〃 | 〃 | 〃 | (mesma ida) | 522 / 504 |
| Campo | noite | 〃 | 〃 | 〃 | 5 → 10 → 10 | 528 / 516 |
| Campo | 3.ª ida | | | | 15 → 15 | |
| Ruínas | dia (sem clima) | 0 | 42 (#127) | 0 (+54 à saída) | 0 → 7 → 7 | 579 / 568 |
| Ruínas | noite | 〃 | 〃 | 〃 | 7 → 14 → 14 | 574 / 546 |
| Ruínas | 3.ª ida | | | | 21 → 21 | |
| Geleira | dia | 0 | 45 (#127) | 75 (#129) (+60 à saída) | 0 → 8 → 8 | 594 / 564 |
| Geleira | dia + nevasca | 〃 | 〃 | 〃 | (mesma ida) | 598 / 573 |
| Geleira | noite | 〃 | 〃 | 〃 | 8 → 16 → 16 | 604 / 575 |
| Geleira | 3.ª ida | | | | 24 → 24 | |
| Cratera | dia | 0 | 63 (#127) | 0 (+66 à saída) | 0 → 9 → 9 | 596 / 573 |
| Cratera | dia + cinzas | 〃 | 〃 | 〃 | (mesma ida) | 585 / 579 |
| Cratera | noite | 〃 | 〃 | 〃 | 9 → 18 → 18 | 601 / 585 |
| Cratera | 3.ª ida | | | | 27 → 27 | |
| Ilha do Tesouro | dia (sem noite/clima) | 0 | 2 (#127) | 0 (+48 à saída) | 0 → 9 → 9 | 664 / 648 |
| Ilha do Tesouro | 2.ª ida | | | | 18 → 18 | |

Leitura:
- **Nenhum SCRIPT ERROR** em nenhum mapa, fase ou tela.
- **Pior FPS:** Campo com chuva, 504 mín (522 méd). Nada perto de 60 nesta máquina.
- **Vazamento:** os órfãos sobem um degrau fixo por mapa carregado (Praia 4, Campo 5, Ruínas 7,
  Geleira 8, Cratera 9, Ilha 9) e nunca descem. São as caixas de `ShopOffer` (#128). Fora isso a
  contagem fica estável (não há crescimento dentro da cena, nem com clima ou noite).
- **Erros:** todos são `Lambda capture at index 0 was freed` (#127). Crescem a cada ida (18 na 2.ª,
  36 na 3.ª na Praia).

## Telas

| tela | roteiro | resultado |
|---|---|---|
| Lobby / Base: Loja, Museu, Expedições, Diário, Mapa do Tesouro + Ver museu e volta à tenda | `qa_base.json` | OK: 0 erros, 0 warnings, 0 órfãos |
| Pausa: no lobby (Configurações → Voltar → Continuar) e na Praia (abrir/fechar, Voltar à base, resumo) | `qa_pause.json` | OK: 0 erros; 4 órfãos = a ida à Praia (#128) |
| Título + slots: Novo jogo → Slot 1, Sair para o menu → Continuar, Carregar → Slot 1, Apagar → Confirmar | `qa_title_slots.json` | OK: 0 erros, 0 órfãos; slot apagado volta a "Vazio" |
| Vitória: abrir, Créditos, fechar | `qa_victory.json` | OK: 0 erros, 0 órfãos |

## Issues dev-a abertas

- #127: `HostSync.on_peer_ready` (`gameplay/net/host_sync.gd`) nunca desliga a lambda do
  `peer_scene_ready` → `ERROR: Lambda capture at index 0 was freed`, acumulando a cada ida.
- #128: `ShopOffer` (`items/shop_offer.gd`) cria a caixa mesmo quando usa o `world_scene` → 1 nó
  órfão por oferta, a cada mapa carregado (+ vazamentos de RID à saída).
- #129: Geleira usa `specular` (nome do Godot 3) em `frozen_lake.gd` e `ice_floe.gd` → 75 warnings
  por run e o brilho do gelo não se aplica (no Godot 4 é `metallic_specular`).

## Correções Dev B

- `fix(core)`: `--resolution` da linha de comando volta a valer sobre a janela salva.
  `OS.get_cmdline_args()` não traz os argumentos do motor, então a tela cheia salva era aplicada por
  cima do `--resolution` dos bots e capturas (a 1.ª rodada deste QA saiu em 2560x1440).
- `feat(tools)`: o bot pode testar a tela inicial (`--bot-keep-title`) e escolher a janela
  (`BOT_RESOLUTION`).
- `feat(tools)`: roteiros `qa_*`, `run_qa.sh` e `qa_report.py`. Edição mínima no
  `debug_bridge.gd` (Dev A): dumps com `orphans`/`nodes` e `call` com `toggle`/`open`/`close`.

## Limites desta rodada

- A vitória foi aberta pelo `CoreVictoryScreen.open` (não derrotando o Colosso); o fluxo do chefe final
  já tem os testes `core/tests/net_victory_*`.
- O FPS é da build de debug numa RTX 4060 sem limite; serve para comparar mapas, não como mínimo
  de hardware.
- A coluna "erros/warnings" é por run do mapa (dia + noite + 3.ª ida juntos).

## N4: otimizações Dev B (#132)

O N1 não achou órfão nem vazamento em `core/` ou `ui/` (telas: 0 órfãos; os degraus por mapa são o
`ShopOffer`, #128, e os erros são o `HostSync`, #127, ambos Dev A). Do lado Dev B sobrou só custo
por frame à toa:

- `NightFx` processava todo frame, mesmo de dia, e à noite varria o grupo do jogador local a cada
  frame; `WeatherFx` processava todo frame mesmo sem clima. Agora só processam ativas, e a
  `NightFx` guarda o jogador. Microbenchmark (GUT headless, 20 000 chamadas): busca do jogador
  0,62 → 0,26 µs/frame; `_process` noturno inteiro 1,59 → 1,53 µs/frame; de dia e sem clima, 2
  chamadas de script a menos por frame.

Antes → depois no jogo, `qa_campo.json` (pior FPS do N1), duas rodadas de cada, alternadas,
mesma máquina e configuração do N1. FPS méd / mín:

| fase | antes (1) | antes (2) | depois (1) | depois (2) | órfãos (todas) |
|---|---|---|---|---|---|
| dia | 528 / 518 | 530 / 507 | 523 / 498 | 527 / 500 | 0 → 5 → 5 |
| dia + chuva | 531 / 520 | 518 / 506 | 531 / 526 | 525 / 512 | (mesma ida) |
| noite | 533 / 502 | 534 / 497 | 544 / 513 | 537 / 501 | 5 → 10 → 10 |
| 3.ª ida | | | | | 15 → 15 |

Leitura: a diferença fica dentro do ruído entre rodadas (±10 FPS). A cena é limitada pela
renderização, não pelos scripts do Dev B, e os órfãos/erros seguem iguais até #127/#128. Não há
mais nada do Dev B a cortar sem mudar o visual (as partículas de clima são `CPUParticles3D` com
400 gotas; passar para GPU fica para quando houver queda real de FPS em máquina fraca).
