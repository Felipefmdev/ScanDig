# Auditoria de UI — estado atual e correções priorizadas

Âmbito: tema, HUD e ecrãs de `ui/` a 23/10/2026. Método: leitura do código + contraste
medido por `tools/ui_contrast_audit.py`. **Não inclui capturas** (essa validação exige
Godot com janela/MCP e fica para o passo de implementação).

## 1. Inventário

| Ecrã | Ficheiro | Nota |
|---|---|---|
| Título | `world/title_screen.tscn`, `ui/title_screen.gd` | primeira impressão |
| HUD | `ui/hud.tscn`, `ui/hud.gd` | 4 chips + prompts |
| Base | `ui/base_station_ui.tscn/.gd` | loja, missões, mapa |
| Pausa | `ui/pause_menu.tscn/.gd` | opções rápidas |
| Definições | `ui/settings_menu.gd` | input, áudio, vídeo |
| Multijogador | `ui/multiplayer_menu.tscn/.gd` | criar/entrar |
| Sessão | `ui/session_ui.tscn/.gd` | lobby/estado |
| Vitória | `ui/victory_screen.tscn/.gd` | fim de campanha |
| Créditos | `ui/credits_view.gd` | — |
| Conquistas | `ui/achievements_tab.gd` | aba |
| Legendas | `ui/captions_hud.gd` | acessibilidade |
| Clima | `ui/weather_hud.gd` | indicador |

O tema é construído em código (`ui/theme/build_theme.gd`, 22 KB) com paleta semântica
(`ui_palette.gd`), textura de papel 9-slice e duas fontes OFL. Isto é uma base boa:
testável, consistente e localizável.

## 2. Contraste medido (WCAG)

Comando: `python tools/ui_contrast_audit.py`. Resultado em 13 pares:

| Par | Uso | Rácio | Mínimo | Estado |
|---|---|---|---|---|
| INK/PAPER | texto de painel | 11,57 | 4,5 | ok |
| INK/PAPER_LIGHT | botão comum | 13,14 | 4,5 | ok |
| INK/PAPER_DARK | aba inativa | 8,73 | 4,5 | ok |
| WOOD/PAPER | dica | 5,76 | 4,5 | ok |
| WOOD/PAPER_LIGHT | placeholder | 6,54 | 4,5 | ok |
| WOOD/PAPER_DARK | texto desativado | **4,34** | 4,5 | falha |
| RED_BURNT/PAPER | aviso | 4,95 | 4,5 | ok |
| INK/ORANGE | botão primário | 4,97 | 4,5 | ok |
| PAPER/RED_BURNT | botão de perigo | 4,95 | 4,5 | ok |
| PAPER/GREEN_BOTTLE | toast | **4,64** | 4,5 | ok (limite) |
| GOLD/INK | código da sala | 7,36 | 4,5 | ok |
| ORANGE/PAPER_LIGHT | **borda de foco** | **2,65** | 3,0 | falha |
| METAL/PAPER_DARK | borda desativada | 3,42 | 3,0 | ok |

## 3. Achados

### F1 — Foco abaixo de 3:1 (P1)

`build_theme.gd:333` pinta a borda de foco com `ORANGE` sobre `PAPER_LIGHT`: **2,65:1**.
Como o foco é o único sinal de navegação por comando, isto é um problema de
acessibilidade, não de gosto.

**Correção sugerida:** borda exterior `INK` de 2 px + interior `ORANGE` de 1 px (o
contraste passa a vir da tinta), ou `ORANGE.darkened(0.25)` até medir ≥ 3:1.
**Aceite:** `ui_contrast_audit.py` verde para o par de foco; captura com foco visível a
720p.

### F2 — Hierarquia fraca nos títulos (P1)

`FONT_SIZE = 18` e `TitleLabel = 21` (`build_theme.gd:12,212`): rácio 1,17. A regra de
`UI_UX.md` pede 1,25–1,5. O título não domina o corpo.

**Correção sugerida:** corpo 18, subtítulo 21, título 26 (1,44×). `CodeLabel` e
`LoadingLabel` (30) já estão acima; não mexer.
**Aceite:** três tamanhos por ecrã; teste dos 5 s identifica a ação primária.

### F3 — Toast no limite e dependente da textura (P2)

`PAPER` sobre `GREEN_BOTTLE` = 4,64, mas o fundo é uma textura de papel com variação; em
zonas escuras o rácio efetivo cai. `CodeLabel` já usa contorno; o toast não.

**Correção:** texto `PAPER_LIGHT`, contorno `INK` de 2 px, ou escurecer o verde do toast.
**Aceite:** contraste ≥ 4,5 sobre a textura, não só sobre a cor média.

### F4 — Desativado abaixo do mínimo (P3)

`WOOD/PAPER_DARK` = 4,34 (`build_theme.gd:309`). Texto desativado é isento de WCAG, mas o
jogo usa-o para informação (“mapa bloqueado”, requisitos). Se a informação for
necessária, não é “desativado”.

**Correção:** para requisitos, usar `INK` com opacidade 0,7 sobre `PAPER_DARK`; reservar
`WOOD` para decoração.
**Aceite:** requisitos de desbloqueio legíveis a 720p.

### F5 — Sem evidência a 720p (P2)

O tema foi pensado a 1080p (18 px). Com `stretch/mode=canvas_items` e `aspect=expand`
(`project.godot`), o tamanho efetivo depende da resolução base; não há captura registada
a 1280×720 nem a ultrawide.

**Correção:** capturas de todos os ecrãs a 1280×720, 1920×1080 e 2560×1080; se o texto
ficar < 16 px efetivos, subir o corpo.
**Aceite:** nenhum texto essencial abaixo de 16 px efetivos.

### F6 — Hierarquia dentro do HUD não está medida (P2)

`hud.tscn` tem 4 chips (`MoneyChip`, `DetectorChip`, `MuseumChip`, e o grupo
`toast_avoid`) mas não há teste de prioridade visual entre eles. Em ecrãs pequenos, todos
competem.

**Correção:** definir um primário (dinheiro ou detetor, conforme o mapa) e reduzir os
outros a ícone + número; medir com o teste dos 5 s.
**Aceite:** em 5 s, o jogador diz o saldo e o estado do detetor sem procurar.

## 4. Forças a preservar

- Paleta semântica e documentada; contraste de texto base excelente (11–13:1).
- 9-slice com margem 14 px e textura própria; não trocar por `StyleBoxFlat` só por moda.
- `UiNavAudit` já cobre teclado/comando, armadilhas de foco e controlos sem borda — usa-o
  como teste de regressão.
- Fontes OFL com acentos; manter.

## 5. Protocolo de teste (5 s + percurso)

1. Abre o ecrã a 1280×720 e 1920×1080, rato e comando.
2. Mostra 5 s, esconde, pergunta: “o que podes fazer aqui?” e “o que é mais importante?”.
3. Regista a primeira ação clicada (first-click) e o tempo até ela.
4. Percorre todos os controlos só com direcional + A/B; regista becos sem saída.
5. Repete com texto em inglês (+30%).
6. Guarda capturas com o mesmo nome do ecrã e resolução.

## 6. Backlog proposto (Dev B)

| P | Item | Ficheiro | Esforço |
|---|---|---|---|
| P1 | Borda de foco com contraste ≥ 3:1 | `build_theme.gd:333` | B |
| P1 | Escala tipográfica 18/21/26 | `build_theme.gd:12,212` | B |
| P2 | Toast com contorno e texto claro | `build_theme.gd:288-292` | B |
| P2 | Chip primário do HUD | `hud.tscn`, `hud.gd` | M |
| P2 | Capturas 720p/1080p/ultrawide | QA | B |
| P3 | Requisitos de desbloqueio legíveis | `base_station_ui.gd` | B |

Cada item entra numa issue própria; esta auditoria não altera o tema.
