# Final na Lua: impacto no Dev B (#120, #121)

Levantamento de 2026-10-19 sobre o `origin/main` 263bd45 (#136). **Nada foi implementado**: as
duas issues estão como NÃO INICIAR. Para cada ponto: o que muda, uma sugestão (a decisão é do
Felipe) e se é **bloqueante**.

**Bloqueante** = quebra o jogo ou o CI no momento em que a Ilha/Colosso saírem (#121), então tem
de entrar no mesmo lote que a remoção. O resto (textos, docs, bots) pode vir logo a seguir.

Fora do impacto (conferido): `project.godot`, `world/lobby_base.tscn`, HUD, SessionUI e menu
multiplayer não citam a Ilha nem o Colosso. Os itens da Ilha (`relogio_ouro`, `idolo_jade`,
`mascara_ouro`, `calice_prata`, `adaga_cerimonial`, `escaravelho_jade`, `idolo_ouro`) continuam
nas Ruínas (`items/maps/ruinas.tres` e missões/segredos de lá), então o total do Museu não muda.

## Decisões pendentes do Felipe

1. **Ids** do mapa (sugestão: `lua`) e do chefe lunar (vira o `GameState.FINAL_BOSS_ID`).
2. **Fragmentos do Mapa do Tesouro (#112):** (a) continuam e passam a ser o requisito da Lua
   (o `lua.tres` com `requires_map_fragments = true`, como a Ilha hoje); (b) viram peças do
   foguete da Dra. Vega; (c) saem do jogo. Muda o GameState, o pergaminho, a aba da Base, a linha
   da VictoryScreen e ~10 testes.
3. **Troféu do chefe lunar:** é o novo destaque do Museu (pedestal da frente), no lugar do
   `idolo_ouro`?
4. **Noite e clima na Lua:** sugestão sem noite e sem clima (como a Ilha: luta final legível).
5. **Saves que já venceram o Colosso:** sugestão manter a regra do #115 (concluído = venceu o
   chefe final atual), perdem o ★ até vencerem a Lua. Alternativa: contar `gold_colossus` como
   concluído legado.
6. **Ordem:** se a #121 entrar antes da #120, o jogo fica sem final. Sugestão: as duas no mesmo
   lote, ou manter o Colosso até o chefe lunar existir.

## A. Estado, save e sessão (`core/`): 8 itens, 3 bloqueantes

| # | Onde | O que muda | Sugestão | Bloq. |
|---|---|---|---|---|
| A1 | `core/game_state.gd:107-109` | `FINAL_BOSS_ID = "gold_colossus"` | Trocar pelo id do chefe lunar. Tudo o que deriva segue sozinho: vitória e save no host (`:545-556`), `game_completed` no `apply_snapshot` (`:768-771`), `SaveManager._summary_from`/`get_save_summary` (`core/save_manager.gd:113`), `_upgrade_save_data`/`_beat_final_boss` (`:670-680`), ★ do título (`ui/title_screen.gd:228`) | **Sim** |
| A2 | `core/game_state.gd:113-117` | `EXTRA_BOSSES` tem `gold_colossus` | Trocar pelo chefe lunar: chefe fora da lista é ignorado pelo host (`:539`), sem vitória | **Sim** |
| A3 | `core/save_manager.gd:30, 670-673`; `core/game_state.gd:747-750` | Saves antigos têm `ilha_tesouro` em `unlocked_maps` e `gold_colossus` em `defeated_bosses` | Ids desconhecidos ficam no save sem efeito; não precisa de `SAVE_VERSION` novo. Só a decisão 5 | Não |
| A4 | `core/game_state.gd:31, 73-97, 151` | `MAP_FRAGMENTS`/`MAP_FRAGMENT_IDS` (8 peças; o texto fala em navegar até a Ilha) | Conforme a decisão 2; se ficarem, trocar o comentário e o destino | Não |
| A5 | `core/game_state.gd:283-285, 305-310, 322-326` | Desbloqueio por fragmentos e o motivo "navegar até %s no barco da Praia" | Se a Lua usar os fragmentos: só o texto (foguete na Cratera). Se for missão do foguete: novo motivo e nova regra | Não |
| A6 | `core/session_manager.gd:33` (usado em `:424`) | `MAP_ORDER` termina em `ilha_tesouro` | Tirar `ilha_tesouro` junto com o `.tres`; pôr `lua` no fim com a #120 | **Sim** |
| A7 | `core/night_mode.gd:9-10, 17-27`; `core/weather_manager.gd:26-35` | A Ilha não tem entrada em `NIGHT_BY_MAP` nem em `WEATHER_BY_MAP`; só o comentário cita a Ilha | Lua sem entrada = sem noite e sem clima (decisão 4); trocar o comentário | Não |
| A8 | `core/ambience_manager.gd:26` | Ambiente `ilha_tesouro` (`amb_ilha.ogg`) | Remover a entrada; gerar `amb_lua` em `tools/gen_audio.py` (sem mar). O `amb_ilha.ogg` sai com `assets/audio/CREDITS.md:20` e `tools/gen_audio.py:20, 515` | Não |

## B. Telas (`ui/`): 7 itens

| # | Onde | O que muda | Sugestão | Bloq. |
|---|---|---|---|---|
| B1 | `ui/victory_screen.gd:4-7, 17` | `SUBTITLE_TEXT`: "O Colosso do Tesouro foi vencido... Leve o Ídolo de Ouro..." | Texto do final lunar (chefe e troféu novos) + EN no CSV | Não |
| B2 | `ui/victory_screen.gd:230` | Linha "Fragmentos do mapa" | Manter, renomear ou tirar (decisão 2) | Não |
| B3 | `ui/victory_screen.gd:19-20` | `CREDITS_TEXT` | Rever se o final lunar acrescenta alguém | Não |
| B4 | `ui/base_station_ui.gd:73-74, 1142-1190` | Aba "Mapa do Tesouro"; `:1174` "a Ilha do Tesouro espera pela equipe" | Trocar o destino no texto, ou tirar a aba (decisão 2) | Não |
| B5 | `ui/base_station_ui.gd:1216-1220, 1235` | Diário: `BOSS_ORDER` e `BOSS_FIELD_META` com `gold_colossus` ("Ilha do Tesouro") | Trocar pelo chefe lunar (nome, região "Lua", cor); sem isso o Diário fica com um chefe impossível | Não |
| B6 | `ui/treasure_map_parchment.gd:4-16, 31-32, 153, 166-172, 184, 206, 293-302` | Ilha e X na peça `ISLAND_CELL` (3, 0) = `cratera_frag_2`, rótulo "Ilha", mar da Ilha, `_build_island` | Se os fragmentos ficarem: a peça (3, 0) mostra o destino lunar (Lua/foguete, rótulo "Lua"); senão o pergaminho sai | Não |
| B7 | `ui/base_station_ui.gd:1050-1053, 1081`; `ui/title_screen.gd:228` | Selo "Jogo concluído" no Museu e ★ no título | Derivados de `game_completed`: nada a mudar | Não |

## C. Museu 3D (`world/museum_display.gd`): 2 itens, 2 bloqueantes

| # | Onde | O que muda | Sugestão | Bloq. |
|---|---|---|---|---|
| C1 | `world/museum_display.gd:16-23` (layout em `:219, 234-241`) | `SITES` tem a prateleira `ilha_tesouro` "Ilha"; o `load()` de `:184` falha sem o `.tres` | Trocar por `{"id": "lua", "name": "Lua"}` (mantém 6 prateleiras, 3 x 2) ou ficar com 5 (3 + 2) | **Sim** |
| C2 | `world/museum_display.gd:7, 37-39, 191-195, 280-285` | `HIGHLIGHT_ID = "idolo_ouro"`, `HIGHLIGHT_SITE = "ilha_tesouro"`, placa "Tesouro da Ilha". `HIGHLIGHT_SITE` também é o sítio padrão (`:195`): fora de `SITES` dá erro ao montar a estante | Destaque = troféu do chefe lunar com `HIGHLIGHT_SITE = "lua"` (decisão 3); o `idolo_ouro` volta à prateleira das Ruínas | **Sim** |

## D. Bots e QA (`tools/bot/`, fora do CI): 3 itens

| # | Onde | O que muda | Sugestão | Bloq. |
|---|---|---|---|---|
| D1 | `pacing_ilha_tesouro.json`, `coop_ilha_host.json`, `coop_ilha_client.json`, `qa_ilha_tesouro.json` | Abrem `map_ilha_tesouro.tscn` / `ilha_tesouro` | Apagar com a #121 (estão na lista do Felipe; o Dev B apaga se ele preferir) e criar os da Lua depois | Não |
| D2 | `tools/bot/qa_gen.py:14, 22, 31-33, 73, 96, 252` | `ALL_MAPS`, config da Ilha, fragmentos, aba "Mapa do Tesouro" | Tirar a Ilha / pôr a Lua e regerar os `qa_*.json` (`ilha_tesouro` em `unlocked_maps` na linha 13 de `qa_base`, `qa_campo`, `qa_cratera`, `qa_geleira`, `qa_praia`, `qa_pause`, `qa_ruinas`, `qa_victory` e na 137 de `qa_nav_keyboard`/`qa_nav_pad`) | Não |
| D3 | `tools/bot/qa_report.py:25, 104`; `tools/bot/run_pacing.sh:4, 17` | `MAP_ORDER` e a lista de mapas do pacing | Igual ao `SessionManager.MAP_ORDER` | Não |

## E. i18n (`translations/scandig.csv`): 1 item, ~15 chaves

Chaves da Ilha/Colosso: `:199, 208, 222, 223, 379-381, 465, 849, 851, 855, 856, 864` (Dev B) e as
falas do gameplay `:555` (Vega), `:620` (barco), `:846-847` (Colosso), que saem com o código do
Felipe. Sugestão: tirar as mortas, pôr as da Lua com EN e regerar os `.translation`
(`godot --headless --path . --import`). Não bloqueante.

## F. Testes do Dev B: 7 itens, 5 bloqueantes

| # | Onde | O que muda | Sugestão | Bloq. |
|---|---|---|---|---|
| F1 | `core/tests/map_unlock_test.gd:63-72` | Ordem com `ilha_tesouro`; Ilha fechada/aberta pelos fragmentos | Ordem nova; a regra dos fragmentos vai para a Lua ou sai | **Sim** |
| F2 | `ui/tests/expedition_tab_test.gd:57-59` | "6 mapas na lista", item 5 = Ilha 🔒 | 5 mapas (6 com a Lua); item 5 = Lua | **Sim** |
| F3 | `tests/dev_b/test_night_mode.gd:103-104, 127-129` | "Ilha não tem noite" | Mesmo teste com a Lua (se a decisão 4 for sem noite) | **Sim** |
| F4 | `tests/dev_b/test_museum_display.gd:45, 48, 74-75` | Seções = `SITES`; ídolo de ouro na Ilha | Destaque novo e sítio `lua` | **Sim** |
| F5 | `tests/dev_b/test_victory_screen.gd` (~20 linhas com `"gold_colossus"`, `:236-238` subtítulo, `:253` 8 fragmentos), `tests/dev_b/test_final_save_migration.gd:3, 50-97`, `tests/dev_b/test_gamepad_menus.gd:138`, `tests/dev_b/test_nav_audit.gd:190`, `ui/tests/theme_snapshots.gd:229-231`, `core/tests/net_victory_host.gd:38-40` | Literal `"gold_colossus"` | Usar `GameState.FINAL_BOSS_ID` (como já fazem `test_title_screen.gd:47` e `theme_snapshots.gd:328`): aí só o subtítulo e a migração mudam | **Sim** |
| F6 | `tests/dev_b/test_treasure_parchment.gd:5, 86-115`, `ui/tests/theme_snapshots.gd:79-89`, `tests/dev_b/test_npc_map_hint.gd:49`, `tests/dev_b/test_base_tabs_fit.gd:8` | Ilha/X na peça (3, 0), rótulo "Ilha", capturas do pergaminho, aba "Mapa do Tesouro" | Conforme a decisão 2 | Não |
| F7 | `tests/dev_b/test_ambience.gd:54`; `core/tests/map_pools_test.gd:87`, `core/tests/upgrade_lock_test.gd:100` | `map_id_from_scene` da Ilha (função pura, passa sem a cena); os dois percorrem `MAP_ORDER` | Trocar para a Lua; o `lua.tres` vai ter de cumprir as regras de pool e de upgrade desses dois | Não |

## G. Docs: 4 itens

- `docs/GAME_DESIGN.md:9-17, 57-59, 116, 119-125`: premissa, tabela (6.º mapa) e a secção da Ilha.
- `docs/PACING.md:15, 18-20, 293-300`: tabela, soma das horas e a medição da Ilha.
- `docs/CORE_AND_NETWORK.md:68-70`: "concluído = venceu o chefe final" (só o nome do chefe).
- `docs/QA_REPORT.md:51-52, 58, 93, 159`: histórico; uma nota "Ilha removida (#121)" basta.

Do Felipe, só para referência: `items/map_data.gd:21-22` (doc do `requires_map_fragments`).
