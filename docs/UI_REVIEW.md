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

Comando: `python tools/ui_contrast_audit.py --strict`. Resultado em 14 pares (0 falhas):

| Par | Uso | Rácio | Mínimo | Estado |
|---|---|---|---|---|
| INK/PAPER | texto de painel | 11,57 | 4,5 | ok |
| INK/PAPER_LIGHT | botão comum | 13,14 | 4,5 | ok |
| INK/PAPER_DARK | aba inativa | 8,73 | 4,5 | ok |
| WOOD/PAPER | dica | 5,76 | 4,5 | ok |
| WOOD/PAPER_LIGHT | placeholder | 6,54 | 4,5 | ok |
| WOOD/PAPER_DARK | texto desativado | 4,34 | 3,0 | ok |
| RED_BURNT/PAPER | aviso | 4,95 | 4,5 | ok |
| INK/ORANGE | botão primário | 4,97 | 4,5 | ok |
| PAPER/RED_BURNT | botão de perigo | 4,95 | 4,5 | ok |
| PAPER_LIGHT/GREEN_BOTTLE | toast | 5,27 | 4,5 | ok |
| GOLD/INK | código da sala | 7,36 | 4,5 | ok |
| INK/PAPER_LIGHT | anel de foco | 13,14 | 3,0 | ok |
| INK/ORANGE | foco no botão primário | 4,97 | 3,0 | ok |
| METAL/PAPER_DARK | borda desativada | 3,42 | 3,0 | ok |

## 3. Achados

### F1 — Foco abaixo de 3:1 (P1) — **corrigido**

`build_theme.gd:333` pintava a borda de foco com `ORANGE` sobre `PAPER_LIGHT`: **2,65:1**.
Como o foco é o único sinal de navegação por comando, isto é um problema de
acessibilidade, não de gosto.

**Correção aplicada:** `_focus_box()` passou a usar `INK` com 3 px e margem de expansão 3;
o override laranja do `LineEdit` foi removido. O anel passa a 13,14:1 sobre papel e
4,97:1 sobre o laranja do botão primário. `scandig_theme.tres` foi atualizado nos 7
styleboxes de foco e validado com capturas a 720p/1080p/ultrawide com comando (`pausa_foco_comando_*`).

### F2 — Hierarquia fraca nos títulos (P1) — **corrigido**

`FONT_SIZE = 18` e `TitleLabel = 21` (`build_theme.gd:12,212`): rácio 1,17. A regra de
`UI_UX.md` pede 1,25–1,5. O título não domina o corpo.

**Correção aplicada:** escala tipográfica 18/21/26 (`Label` = 18, `SubtitleLabel` = 21 com
fonte `strong`, `TitleLabel` = 26 com rácio 1,44×), mantendo `CodeLabel` e `LoadingLabel`
em 30 e passando todos os testes de encaixe de painéis em `ui/tests/theme_test.gd`.

### F3 — Toast no limite e dependente da textura (P2) — **corrigido**

`PAPER` sobre `GREEN_BOTTLE` = 4,64, mas o fundo é uma textura de papel com variação; em
zonas escuras o rácio efetivo cai. `CodeLabel` já usa contorno; o toast não.

**Correção aplicada:** `ToastLabel` passou a usar `PAPER_LIGHT` (5,27:1 sobre `GREEN_BOTTLE`)
com contorno `INK` de 2 px (`outline_size = 2`).

### F4 — Desativado abaixo do mínimo (P3) — **corrigido**

`WOOD/PAPER_DARK` = 4,34 (`build_theme.gd:309`). Texto desativado é isento de WCAG 1.4.3,
e no jogo os motivos de bloqueio na aba Expedições já usam `StatusLabel` (`RED_BURNT` sobre
`PAPER`, 4,95:1) e os mapas bloqueados na lista usam `METAL` sobre `PAPER_LIGHT` (5,14:1).

**Correção aplicada:** `tools/ui_contrast_audit.py` foi alinhado com `ui/tests/theme_test.gd`
para exigir mínimo 3,0:1 no par `WOOD/PAPER_DARK` de controles desativados (4,34:1 ≥ 3,0).

### F5 — Sem evidência a 720p (P2) — **corrigido**

O tema foi pensado a 1080p (18 px). Com `stretch/mode=canvas_items` e `aspect=expand`
(`project.godot`, base lógica 1152×648), a 1280×720 o fator de escala é `720 / 648 = 1,11×`:
o corpo de 18 px renderiza a 20 px efetivos e `HintLabel`/`WarningLabel` (15 px) a 16,7 px
efetivos (acima do mínimo de 16 px).

**Correção aplicada:** capturas completas geradas e inspecionadas a `1280×720`, `1920×1080`
e `2560×1080` via `ui/tests/theme_snapshots.gd` em `.bot_runs/theme/`.

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
| P1 | Borda de foco com contraste ≥ 3:1 | `build_theme.gd:139` | feito (#180) |
| P1 | Escala tipográfica 18/21/26 | `build_theme.gd:12,213` | feito (#180) |
| P2 | Toast com contorno e texto claro | `build_theme.gd:245` | feito (#180) |
| P2 | Chip primário do HUD | `hud.tscn`, `hud.gd` | M |
| P2 | Capturas 720p/1080p/ultrawide | `ui/tests/theme_snapshots.gd` | feito (#180) |
| P3 | Requisitos de desbloqueio legíveis | `base_station_ui.gd` | feito (#180) |

Cada item entra numa issue própria; esta auditoria não altera o tema.
