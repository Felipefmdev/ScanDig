# ScanDig — Core, Rede e Save (frente do Dev B)

Documentação técnica de `res://core/` e `res://ui/`. Se algo aqui divergir do código, o código vence: atualizem este ficheiro.

## 1. Autoloads

| Autoload | Script | `class_name` | Acesso |
| :--- | :--- | :--- | :--- |
| `CoreGameState` | `res://core/game_state.gd` | `GameState` | `GameState.instance` |
| `CoreNetwork` | `res://core/network_manager.gd` | `NetworkManager` | `NetworkManager.instance` |
| `CoreSave` | `res://core/save_manager.gd` | `SaveManager` | `SaveManager.instance` |
| `CoreSession` | `res://core/session_manager.gd` | `SessionManager` | `SessionManager.instance` ou `/root/CoreSession` |
| `CoreSessionUI` | `res://ui/session_ui.tscn` | `SessionUI` | `/root/CoreSessionUI` |

Existem em **todas** as cenas (lobby, mapas, sandbox). Nunca os instanciem como nós dentro de uma cena.

### Armadilhas da Godot

| Problema | Sintoma | Solução |
| :--- | :--- | :--- |
| Editor aberto com versão antiga em memória grava por cima do `project.godot` | A secção `[autoload]` desaparece; aba Expedições mostra "Sistema de expedições indisponível" | `git restore project.godot world/lobby_base.tscn`, fechar o editor **sem guardar** e reabrir. Depois de cada pull/commit que mexa em `project.godot` ou cenas, reabrir o editor |
| Nome do autoload igual ao `class_name` | Erro "Class X hides an autoload singleton" | Prefixo `Core*` no autoload; aceder por `X.instance` |
| Godot gera UIDs (`uid="uid://..."`) em `.tres`/`.tscn` | Ficheiros aparecem modificados sem mudança de lógica | Commit separado `chore(editor): update Godot resource uids`; nunca commitar UIDs de ficheiros do Dev A |
| Cache de classes desatualizado após pull | `Could not find type "X"` no headless | `--headless --path . --editor --quit-after 600` antes dos testes |
| `multiplayer_peer = null` | `No multiplayer peer is assigned` em `is_server()` | Usar sempre `OfflineMultiplayerPeer.new()` |

## 2. Estado e rede

### Autoridade no host
Só o host (peer 1) altera o estado. Qualquer peer chama `request_*`; `_send_to_host` executa direto no host ou faz `rpc_id(1, ...)` no cliente. As funções `_host_*` revalidam tudo (item existe, valor limitado a `get_max_item_value()` = `base_value × RARE_VALUE_MULTIPLIER × PERFECT_BONUS_MULTIPLIER`, arredondado para cima, saldo, nível máximo).

| Pedido (qualquer peer) | Execução no host |
| :--- | :--- |
| `request_report_discovery(item_id, final_value)` | `_host_report_discovery` |
| `request_sell_item(item_id, final_value)` | `_host_sell_item` |
| `request_donate_item(item_id)` | `_host_donate_item` |
| `request_buy_upgrade(upgrade_id)` | `_host_buy_upgrade` → `purchase_result` só para quem comprou |
| `request_purchase_item(item_id)` | `_host_purchase_item` → `item_purchase_result` só para quem comprou |
| `request_unlock_map(map_id)` | `_host_unlock_map` → `map_unlock_result` só para quem pediu |
| `request_report_boss_defeated(boss_id)` | `_host_report_boss_defeated` |

Só no host: `advance_day()`, `reset_state()`, `load_snapshot(data)`.

### Sinais do `GameState`
`money_changed(new_amount)`, `collection_updated(total_found, max_items)`, `item_sold(item_name, value)`, `item_donated(item_name, reward)`, `upgrades_changed(upgrade_levels)`, `purchase_result(upgrade_id, success, message)`, `item_purchase_result(item_id, success, message)`, `progression_changed(unlocked_maps, defeated_bosses)`, `map_unlock_result(map_id, success, message)`, `state_synced()`.

### Snapshot
Após cada mudança o host envia a todos `_receive_snapshot` com:

```
{ "team_money": int, "current_day": int, "discovered_items": Array[String], "upgrade_levels": { "detector": int, "pinpointer": int, "shovel": int, "backpack": int }, "unlocked_maps": Array[String], "defeated_bosses": Array[String] }
```

Quem entra recebe o snapshot em `peer_connected` (e o cliente pede de novo com `_request_full_state`). `apply_snapshot` valida tipos e limita níveis.

### Loja (`GameState.UPGRADES`)
| Upgrade | Nome | Custos | Nível máx. |
| :--- | :--- | :--- | :--- |
| `detector` | Detector | 300 / 600 / 1200 | 3 |
| `pinpointer` | Pinpointer de Precisão | 500 | 1 |
| `shovel` | Pá de Fibra | 800 | 1 |
| `backpack` | Mochila Reforçada | 400 / 800 / 1600 | 3 |

`get_next_upgrade_cost` devolve -1 no máximo. `equipped_detector_level = 1 + nível do detector` (lido pelo `MetalDetector`).

Consultas de equipamento (só leitura, qualquer peer; clientes leem o valor do snapshot):
- `get_backpack_capacity()` → `BASE_BACKPACK_CAPACITY` (3) + nível de `backpack` (3 a 6).
- `get_shovel_level()` → 1 + nível de `shovel` (escala do `player.shovel_level`; 1 = pá básica).
- `has_pinpointer()` → nível de `pinpointer` > 0.
- `get_tool_data(item_id)` → `ToolData` de `TOOLS_DIR/<id>.tres` (`res://items/tools`), ou `null` se o id for inválido (vazio, com `/`, `\` ou `..`), não existir ou não bater com `ToolData.id`.
- `get_max_item_value(item_data)` → teto anti-trapaça de venda/doação: `ceil(base_value × BuriedSpot.RARE_VALUE_MULTIPLIER × BuriedSpot.PERFECT_BONUS_MULTIPLIER)` (ex.: base 250 → 938).

### Ferramentas da Praia (`request_purchase_item`)
A banca da Praia (`ShopOffer`) deve comprar só por esta API, nunca debitando `team_money` no cliente. `request_purchase_item(String(tool_data.id))` → o host valida id, `price > 0` e saldo, debita e envia o snapshot. Só o comprador recebe `item_purchase_result(item_id, success, message)`; com `success == true` o gameplay dele cria o `CarriedItem` (`CarriedItem.create_from_tool_data`). O core não sabe de mochila: o espaço deve ser checado antes do pedido. Ferramentas compradas não entram no snapshot nem no save.

Mensagens: `"Comprado: <nome>"`, `"Saldo insuficiente para <nome> (R$ <preço>)."`, `"Produto indisponível."`.

### Progressão de mapas
Regras em `docs/PACING.md` §1. Ordem: `praia` → `campo` → `ruinas` → `cratera` (`SessionManager.MAP_ORDER`; ids fora da lista vão para o fim, em ordem alfabética). `MapData` em `GameState.MAPS_DIR` (`res://items/maps/<id>.tres`, `id` == nome do arquivo).

| Mapa | Nome | `unlock_cost` | Chefe exigido (`MAP_UNLOCK_BOSSES`) |
| :--- | :--- | :--- | :--- |
| `praia` | Praia | 0 (sempre desbloqueada) | — |
| `campo` | Campo Antigo | 2.000 | `king_crab` (Caranguejo-Rei) |
| `ruinas` | Ruínas | 8.000 | `giant_mole` (Toupeira Gigante) |
| `cratera` | Cratera | 25.000 | `ancient_guardian` (Guardião Ancestral) |

Desbloquear é uma compra única, só depois de vencer o chefe exigido. Um mapa desbloqueado só é jogável se `res://world/map_<id>.tscn` existir (senão a UI mostra "Em breve").

`GameState`:
- `unlocked_maps: Array[String]` (só mapas pagos) e `defeated_bosses: Array[String]`.
- `is_map_unlocked(map_id)` → `unlock_cost <= 0` ou está em `unlocked_maps`.
- `is_boss_defeated(boss_id)`.
- `get_map_unlock_block_reason(map_id)` → `""` se pode desbloquear agora; senão o motivo pronto para a UI.
- `request_unlock_map(map_id)` → o host revalida com `get_map_unlock_block_reason`, debita `unlock_cost`, adiciona a `unlocked_maps` e sincroniza. Resposta em `map_unlock_result` só para quem pediu.
- `request_report_boss_defeated(boss_id)` → o host aceita só os `boss_id` de `MAP_UNLOCK_BOSSES`, sem duplicar e sem dar dinheiro. O gameplay liga o `boss_defeated` de cada chefe a isso.
- `map_id` vazio, com `/`, `\` ou `..`, inválido como nome de arquivo ou com `MapData.id` diferente é tratado como mapa desconhecido.

Mensagens (texto exato): `"Mapa desconhecido."`, `"<nome> já está desbloqueado."`, `"Vença o chefe <chefe> primeiro."`, `"Saldo insuficiente para desbloquear <nome> (R$ <custo>)."`, sucesso `"<nome> desbloqueado!"`.

`SessionManager`:
- `get_available_maps()` ordenado por `MAP_ORDER`.
- `can_start_map(map_id)` exige `MapData`, mapa desbloqueado, cena e nível do detector.
- `get_map_status(map_id)` → Dictionary com as chaves sempre presentes: `map_id`, `display_name`, `unlocked`, `has_scene`, `playable` (== `can_start_map`), `unlock_cost`, `required_boss_id`, `required_boss_name` (`""` sem chefe), `boss_defeated` (true sem chefe), `can_unlock` (`get_map_unlock_block_reason == ""`), `reason`.
- Ordem do `reason`: `"Mapa desconhecido."` → se bloqueado, `get_map_unlock_block_reason` ou `"Desbloqueie por R$ <custo>."` → `"Em breve."` sem cena → `"Requer detector nível <n>."` → `""` (jogável). Id desconhecido devolve todas as chaves vazias/false/0.

### Vender vs. doar (DiscoveryBridge)
`BuriedSpot` → `ItemPickup` → mochila (`CarriedItem`) → `SellPoint.deliver()` → `DiscoveryBridge.report_item_found(item, final_value)` → `GameState.request_report_discovery`. O host decide:
- **Item inédito:** doado ao museu, a equipe recebe `MUSEUM_REWARD_RATIO` (50%) do valor.
- **Item repetido:** vendido por `final_value` (limitado a `get_max_item_value()` = `base_value × RARE_VALUE_MULTIPLIER × PERFECT_BONUS_MULTIPLIER`, arredondado para cima).

### Ciclo do `SessionManager`
1. Host: `request_start_expedition(map_id)` (exige `can_start_map`: mapa desbloqueado, nível do detector e cena `res://world/map_<id>.tscn`).
2. RPC `_rpc_enter_map` → todos trocam de cena (`scene_changing`, `expedition_started`). Quem entra no meio recebe `_rpc_sync_scene`.
3. Durante a expedição o host junta `item_sold`/`item_donated` no resumo.
4. Host: `request_end_expedition()` → `advance_day()` → `SaveManager.save_game()` → `_rpc_return_to_lobby(summary)` → `expedition_ended(summary)` em todos.
5. Queda do host: cliente volta ao lobby e recebe `host_lost`.

### Mapa carregado por peer (`peer_scene_ready`)
A Godot 4.3 não avisa quando `change_scene_to_file` termina. O `SessionManager` guarda a cena pedida em `_change_scene`, compara com `current_scene.scene_file_path` no `_process` e espera mais um frame (para os `_ready` da cena rodarem) antes de avisar. Se outra troca começar nesse frame, o aviso é descartado.
- `signal peer_scene_ready(peer_id: int, map_id: String)`: só no host. Um peer, inclusive o próprio host (id 1), terminou de carregar o mapa atual. No solo/offline é emitido para o peer 1. O lobby não gera aviso.
- `get_ready_peers() -> Array[int]` (ordenado) e `is_peer_scene_ready(peer_id) -> bool`: só fazem sentido no host; nos clientes devolvem `[]`/`false`.
- O cliente avisa o host por `_rpc_report_scene_ready(map_id)` (`any_peer`). O host ignora aviso sem expedição ou de outro mapa (atrasado).
- A lista é limpa em toda troca de cena (entrar no mapa e voltar ao lobby) e na queda do host; um peer que desconecta sai dela.
- Os ids de cliente no ENet são aleatórios (ex.: `[1, 480135759]`), não 2, 3, 4.

Spawners/Synchronizers do mapa devem usar `public_visibility = false` e liberar cada peer em `peer_scene_ready` (`set_visibility_for(peer_id, true)`).

Resumo: `{day, map_id, map_name, money_start, money_end, money_earned, entries: [{name, action: "sold"|"donated", value}]}`.

Rede: ENet, porta `7777`, máx. 4 jogadores (`NetworkManager.host_game` / `join_game` / `disconnect_game`).

## 3. Save (`user://scandig_save.json`, versão 3)

```json
{ "version": 3, "team_money": 100, "current_day": 1, "discovered_items": ["moeda_antiga"], "upgrade_levels": { "detector": 0, "pinpointer": 0, "shovel": 0, "backpack": 0 }, "unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"] }
```

Só o host grava e carrega. Saves v1 (`equipped_detector_level`) são convertidos ao carregar. Saves v2 antigos sem `backpack` carregam com nível 0. Saves v1/v2 sem `unlocked_maps`/`defeated_bosses` carregam com as duas listas vazias. No Windows: `%APPDATA%\Godot\app_userdata\ScanDig\scandig_save.json`.

## 4. Testes headless (Git Bash)

```bash
cd "/c/Projeto jogo/ScanDig"
G=/c/Godot/Godot_v4.3-stable_win64_console.exe
SAVE="$APPDATA/Godot/app_userdata/ScanDig/scandig_save.json"

[ -f "$SAVE" ] && cp "$SAVE" "$SAVE.bak"                          # backup (os testes gravam o save)
timeout 300 $G --headless --path . --editor --quit-after 600 >/dev/null 2>&1   # cache de classes

timeout 240 $G --headless --path . -s addons/gut/gut_cmdln.gd       # GUT: "All tests passed!"
$G --headless --path . --script res://core/tests/flow_test.gd       # offline: "RESULT fails=0"
$G --headless --path . --script res://core/tests/upgrade_test.gd    # loja/mochila: "RESULT fails=0"
$G --headless --path . --script res://core/tests/value_cap_test.gd  # teto de venda/doação: "RESULT fails=0"
$G --headless --path . --script res://core/tests/purchase_item_test.gd  # ferramentas da Praia: "RESULT fails=0"
$G --headless --path . --script res://core/tests/map_unlock_test.gd    # progressão de mapas (grava o save): "RESULT fails=0"
$G --headless --path . --script res://core/tests/scene_ready_test.gd   # peer_scene_ready no solo: "RESULT fails=0"

(timeout 60 $G --headless --path . --script res://core/tests/net_host.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client.gd   # cliente entra a meio: estado igual ao host, "CLIENT RESULT fails=0"
grep HOST /tmp/h.log   # "HOST scene_ready=[1, <id do cliente>] ... ok=true" e "HOST ready_after_end=[]"

(timeout 60 $G --headless --path . --script res://core/tests/net_host_drop.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client_drop.gd   # "host_lost=true scene=LobbyBase"

[ -f "$SAVE.bak" ] && mv "$SAVE.bak" "$SAVE"                       # restaura o save
```

No headless, `Parameter "m" is null` (mesh) e `ObjectDB instances leaked` são esperados (sem GPU). Qualquer `SCRIPT ERROR` é falha.
