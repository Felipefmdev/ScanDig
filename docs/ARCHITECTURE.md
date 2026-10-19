# ScanDig: arquitetura (para quem chega)

Mapa do projeto em uma página. O detalhe fica nos outros documentos; aqui só o "onde está" e o "por quê":

| Documento | O que tem |
| :--- | :--- |
| [`AGENT_ONBOARDING.md`](AGENT_ONBOARDING.md) | ordem de leitura, regras da casa, como montar equipe no canvas |
| [`CORE_AND_NETWORK.md`](CORE_AND_NETWORK.md) | autoridade do host, RPCs, snapshot, sessão, save (contrato completo), testes de rede |
| [`BUILD.md`](BUILD.md) | export do Windows, versão, CI de build e release |
| [`QA_REPORT.md`](QA_REPORT.md) | bots de QA, navegação, resistência e o que ficou em aberto |
| [`GAME_DESIGN.md`](GAME_DESIGN.md), [`PACING.md`](PACING.md), [`TOOLS.md`](TOOLS.md) | jogo, economia, ferramentas e assets |

Se este arquivo divergir do código, o código vence: corrija o arquivo.

## Quem é dono do quê

- **Dev A** (Felipe): `gameplay/`, `world/map_*.tscn`, `world/test_sandbox.tscn`, `tests/unit/` e as pontes de `items/`.
- **Dev B**: `core/` (estado, rede, save, sessão, ajustes), `ui/`, `world/lobby_base.tscn`, `items/catalog/`, `items/maps/`, `project.godot`, `tests/dev_b/`.
- Regras completas em `CONTEXT.md` §2. A ponte entre os dois lados é o `GameState` (`request_*`) e os sinais do `SessionManager`.

## 1. Autoloads (ordem e papel)

Ordem de `project.godot` `[autoload]`. Os `_ready` rodam nessa ordem, então um autoload só pode usar no `_ready` os que vêm **antes** dele. O nome tem prefixo `Core*` para não colidir com o `class_name`; acesse por `Classe.instance` (ver "Armadilhas" em `CORE_AND_NETWORK.md` §1).

| # | Autoload | Script | Papel |
| :-- | :--- | :--- | :--- |
| 1 | `CoreGameState` | `core/game_state.gd` | estado do time (dinheiro, dia, museu, upgrades, mapas, chefes, missões, segredos, estatísticas, conquistas); o host decide |
| 2 | `CoreNetwork` | `core/network_manager.gd` | ENet/noray, host/join, nomes, códigos de sala, queda |
| 3 | `CoreSave` | `core/save_manager.gd` | slots, carregar/gravar, migrações, miniatura, tempo de jogo |
| 4 | `CoreSession` | `core/session_manager.gd` | lobby ↔ expedição, troca de cena sincronizada, `launch_mode`, noite |
| 5 | `CoreAchievements` | `core/achievements.gd` | conquistas por dados (`core/data/achievements.json`); depois do `CoreSession` porque escuta os sinais dele |
| 6 | `CoreSettings` | `core/settings_manager.gd` | `scandig_settings.cfg`: vídeo, áudio, controles (teclado e comando), gameplay, idioma, acessibilidade |
| 7 | `CoreInputDevice` | `core/input_device.gd` | último dispositivo usado (teclado/mouse × comando), rótulos de ação, olhar pelo analógico |
| 8 | `CoreWeather` | `core/weather_manager.gd` | clima por mapa, agendado pelo host |
| 9 | `CoreSessionUI` | `ui/session_ui.tscn` | carregamento, barra da expedição, avisos (toasts), resumo do dia, queda do host |
| 10 | `CorePauseMenu` | `ui/pause_menu.tscn` | pausa (camada 45) |
| 11 | `CoreVictoryScreen` | `ui/victory_screen.tscn` | vitória e "Campanha" (camada 46) |
| 12 | `CoreWeatherFx` | `ui/weather_fx.gd` | partículas e `Environment` do clima, só local |
| 13 | `CoreNightFx` | `ui/night_fx.gd` | visual da noite, só local |
| 14 | `CoreWeatherUI` | `ui/weather_hud.gd` | aviso e chip do clima |
| 15 | `CoreUISounds` | `ui/ui_sounds.gd` | hover/clique em todo `BaseButton` |
| 16 | `CoreAmbience` | `core/ambience_manager.gd` | loop de ambiente por mapa e de clima |
| 17 | `CoreA11y` | `core/a11y.gd` | cores de daltonismo, tremor, flashes, alternar × segurar, legendas |
| 18 | `CoreCaptionsUI` | `ui/captions_hud.gd` | mostra as legendas que o `A11y` decide |
| 19 | `DebugBridge` | `gameplay/debug/debug_bridge.gd` | (Dev A) roteiro de bot `--bot=`; sem o argumento não faz nada |

Existem em todas as cenas (título, lobby, mapas, sandbox); nunca instancie um deles dentro de uma cena. Utilitários sem nó (só `class_name` e funções estáticas): `I18n`, `MoneyFormat`, `RoomCode`, `BuildInfo`, `NightMode` (core) e `UiFormat`, `UiFocus`, `UiIcons`, `UiPalette`, `ItemIcons`, `PlayerHudStyle`, `UiNavAudit` (ui).

## 2. Fluxo de sessão e expedição

```
title_screen.tscn ──(Solo/Coop: select_slot + continue/new)──▶ lobby_base.tscn (Base)
      ▲                                                            │ request_start_expedition(map_id)
      │ return_to_title()                                           ▼
      └──────────── pausa ◀── map_<id>.tscn ──request_end_expedition()──▶ advance_day + save ──▶ Base + resumo
```

- A cena inicial é `world/title_screen.tscn`. Com `--script`/`-s` (GUT, testes, capturas) ou `--bot=`, o título é pulado e o lobby abre direto no save de teste.
- Só o host começa e termina a expedição. A troca de cena vai por RPC para todos; quem entra no meio recebe a cena atual. Ordem dos sinais (`scene_changing`, `expedition_started`, `scene_loaded`, `peer_scene_ready`, `expedition_ending`, `expedition_ended`, `host_lost`): "Ciclo do `SessionManager`" em `CORE_AND_NETWORK.md` §2.
- Noite: o host escolhe na aba Expedições; `SessionManager.is_night()` vai no mesmo RPC do mapa. A config por mapa fica toda em `core/night_mode.gd`.

## 3. Estado e snapshot (o host decide)

- Todo pedido de mudança passa por `GameState.request_*` (vender, doar, comprar, desbloquear, missão, segredo…). No host roda direto; no cliente vira RPC `any_peer` para o host, que valida.
- Depois de mudar, o host chama `_broadcast_snapshot()`: `get_snapshot()` → `Achievements.award()` → `apply_snapshot()` local → RPC `_receive_snapshot` para todos. O cliente nunca escreve estado, só aplica o snapshot inteiro (`apply_snapshot` confere tipos e limita níveis).
- Quem entra recebe o snapshot ao conectar (e pode pedir de novo com `_request_full_state`). Carregar save é `load_snapshot` (só no host; conquistas já cumpridas entram sem aviso).
- Formato do snapshot e regras de RPC: `CORE_AND_NETWORK.md` §2. Sistemas do Dev A que precisam mandar estado a quem entra usam `gameplay/net/host_sync.gd` (`HostSync.broadcast`/`on_peer_ready`), como o `CoreWeather`.
- Sem RPC novo para coisas derivadas: estatísticas e conquistas viajam no snapshot.

## 4. Save: formato, versões e migrações

- Arquivos: `user://scandig_save_<1..3>.json` (3 slots) + `.png` da miniatura. No Windows, `%APPDATA%\Godot\app_userdata\ScanDig\`. Tabela de todos os arquivos (`.backup`, `.tmp`, `.old`, `.corrupt-*`, `.legacy`) em `CORE_AND_NETWORK.md` §3.
- `SaveManager.SAVE_VERSION = 6`. O JSON é o snapshot do `GameState` mais os metadados (`version`, `saved_at`, `last_played`, `play_time_s`, `last_map`).
- Só o host/offline grava; o cliente volta ao próprio save quando sai.
- Toda migração está em `SaveManager._upgrade_save_data`, aplicada ao ler qualquer versão até a atual. Ela só **acrescenta** o padrão do campo que falta e descarta valor de tipo errado; nunca reescreve o arquivo sozinha:

  | Versão | O que entrou |
  | :-- | :--- |
  | v1 → v2 | `upgrade_levels` (o antigo `equipped_detector_level` vira nível do detector); `backpack` |
  | v3 | `unlocked_maps`, `defeated_bosses` |
  | v4 | `completed_quests`, `found_secrets`; `saved_at` (opcional) |
  | v5 (#139) | `play_time_s`, `last_map`, `last_played`, miniatura |
  | v6 (#141) | `stats`, `achievements` |

  Campos sem número de versão próprio (`seen_creatures`, `intact_items`, `rare_items`, `map_fragments`) também começam vazios. `game_completed` é sempre recalculado pelos chefes vencidos.
- Save mais novo que o jogo: não aplica e bloqueia a gravação. Save corrompido: vai para `.corrupt-<unix>.json` e começa jogo novo. Regras e testes em `CORE_AND_NETWORK.md` §3 e `tests/dev_b/test_save_robustness.gd`.
- **Ao mudar o formato:** suba `SAVE_VERSION`, acrescente o caso em `_upgrade_save_data`, um teste que carrega o save da versão anterior e atualize a tabela acima.

## 5. i18n

- `translations/scandig.csv`: a **chave é o próprio texto em PT-BR** (coluna `pt_BR` igual à chave, coluna `en` com a tradução). Sem tradução, aparece o texto PT-BR.
- Em nós: `tr()`/`tr_n()`, e o `auto_translate` dos `Control`s e `Label3D`s para texto fixo. Texto montado (com números) é refeito em `NOTIFICATION_TRANSLATION_CHANGED`, para trocar de idioma ao vivo.
- Fora de nós (estáticos, `Resource`): `I18n.t(texto)`, `I18n.tn(sing, plural, n)`. Texto que vai a outro peer por RPC: `I18n.fmt(template, args)` (quem mostra traduz).
- Idioma: `[general] language` do `CoreSettings`.
- Guardas: `tests/dev_b/test_i18n_keys.gd` (todo texto visível tem chave; o que não é visível vai em `translations/i18n_ignore.txt`), `test_i18n_live.gd`, `test_label3d_live_i18n.gd`, `test_ptbr_texts.gd` (ortografia PT-BR), `test_no_mojibake.gd` (encoding). Para listar chaves faltando: `bash tools/i18n/missing.sh "$G" [pasta]`.

## 6. Áudio, ambiente, clima e noite

- Buses (`default_bus_layout.tres`): `Master` → `SFX` (com `Ambient` como filho, então o volume de efeitos também baixa o ambiente) e `Music`. Volumes em `[audio]` do `CoreSettings`.
- `CoreAmbience`: loop por mapa com fade no `scene_loaded`/`scene_changing`; à noite, Praia e Campo trocam de loop; o loop do clima entra por cima. Só local.
- `CoreUISounds`: hover/clique de menu; um botão fica mudo com `set_meta(UISounds.MUTE_META, true)` ou o grupo `no_ui_sound`.
- Clima (`CoreWeather`): o host agenda e sincroniza; os modificadores de jogo (`WeatherManager.dig_speed_mult()` etc.) são lidos pelo gameplay. O visual (`CoreWeatherFx`) e o aviso (`CoreWeatherUI`) são só locais. Detalhe em `CORE_AND_NETWORK.md` §2 "Clima por mapa".
- Noite: `core/night_mode.gd` (config por mapa) + `ui/night_fx.gd` (visual). `WeatherFx` e `NightFx` trabalham numa **cópia** do `Environment` e devolvem o recurso original na troca de cena; nunca gravam `.tres`. Os dois só processam com efeito ativo.
- Sons gerados/cortados: `tools/gen_audio.py` (fontes CC0 em `CREDITS.md`).

## 7. UI

- **Tema:** `ui/theme/scandig_theme.tres`, gerado por `ui/theme/build_theme.gd` a partir de `UiPalette` (papel bege, contorno de tinta; contraste WCAG ≥ 4,5 conferido em `ui/tests/theme_test.gd`). Mude a paleta ou o gerador, não o `.tres` à mão. Ícones: `UiIcons` (UI) e `ItemIcons` (itens renderizados).
- **Chips:** `UiChip` (ícone + texto em papel claro) no HUD e na Base; o HUD do jogador sem cartão usa `PlayerHudStyle`.
- **Toasts:** `CoreSessionUI` enfileira os avisos (missão, segredo, conquista, save). O aviso de falha de save depende do motivo (`SaveManager.FailReason` → `SessionUI.save_failed_text`) e não cobre o aviso do menu. Legendas de som ficam no `CoreCaptionsUI`.
- **Foco e dispositivo:** `UiFocus` (primeiro foco, cima/baixo encadeado, LB/RB troca aba; `follow_pointer` mostra a borda de foco só com teclado/comando) e `InputDevice` (`using_gamepad()`, `using_pointer()`, `action_label()`). Toda tela tem de ser navegável sem mouse: `UiNavAudit` + `tests/dev_b/test_nav_audit.gd`.
- Escala da UI: `[video] ui_scale`. A janela de 960x540 vira 1152x648 lógicos (stretch `canvas_items`).

## 8. Testes, bots e CI

Variável usada nos exemplos: `G=/c/Godot/Godot_v4.3-stable_win64_console.exe`.

| O quê | Onde | Como rodar |
| :--- | :--- | :--- |
| GUT (Dev A e Dev B) | `tests/` (`tests/unit/` do Dev A, `tests/dev_b/` do Dev B; `.gutconfig.json`, prefixo `test_`) | `bash tools/run_tests.sh "$G"` |
| Headless do Dev B | `core/tests/*_test.gd`, `ui/tests/*_test.gd` (imprimem `RESULT fails=N`) e pares de rede local `net_*` | `bash tools/run_headless_tests.sh "$G"` |
| Rede online (noray) | `core/tests/net_room_*` | `bash tools/test_online.sh "$G"` (sobe o noray local) |
| Capturas de tela | `ui/tests/theme_snapshots.gd`, `tests/dev_b/*_snapshots.gd` (com janela; saída em `.bot_runs/`) | comando no cabeçalho de cada arquivo |
| Bots | roteiros `tools/bot/*.json` executados pelo `DebugBridge` | `bash tools/run_bot.sh "$G" <roteiro>`; QA: `tools/bot/run_qa.sh`; resistência: `tools/bot/run_soak.sh` (ver `QA_REPORT.md`) |

- **Guardas que já pegam erro comum:** textos e i18n (§5), `test_user_files_isolated.gd` (teste nunca grava no `user://` real: sob GUT/`--script` o save vai para `user://test_saves/`), `test_build_version.gd` (versão do `project.godot` = export).
- Antes de **cada** push: GUT + headless verdes, de novo depois de qualquer rebase. Se o Felipe criou `class_name` novo, atualize o cache antes (`$G --headless --path . --editor --quit-after 200`), senão tudo falha com `Could not find type`.
- Warnings do GDScript ficam em zero em `core/`, `ui/` e `tests/dev_b/` com os níveis padrão da Godot (nenhum desligado no projeto). O `--check-only` só mostra erro; para ver os warnings, use o editor (ou o LSP dele em headless).
- **CI** (`.github/workflows/ci.yml`): job `tests` (import, carga das cenas, GUT e headless; qualquer `SCRIPT ERROR`/`Parse Error` no log derruba) e, em push no `main`, `export-windows` (`build-windows.yml`). Release em draft: `release.yml`. Passo a passo em `BUILD.md`.

## 9. Convenções

- Godot 4.3, GDScript 2.0 com **tipagem estática** em variável, parâmetro e retorno; nada de sintaxe da 3.x (`CONTEXT.md` §1 e §5). Sinais tipados, conexão por `Callable`.
- Textos de jogo, comentários e commits em **PT-BR**. Arquivos em UTF-8 sem BOM, fim de linha LF.
- Nome de arquivo em `snake_case`, classe em `PascalCase`, autoload `Core*`.
- Commits pequenos e convencionais (`feat(ui): …`, `fix(save): …`, `docs: …`) com `Refs #N`/`Closes #N`. `git add` só dos arquivos tocados (nunca `.`, `-A`, `-a`). Mudança de UID gerada pelo editor vai em commit separado.
- Arquivo do outro time: só edição mínima, combinada e citada no commit. Trabalho novo para o Dev A vira issue com label `dev-a`.
