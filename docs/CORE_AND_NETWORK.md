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
Só o host (peer 1) altera o estado. Qualquer peer chama `request_*`; `_send_to_host` executa direto no host ou faz `rpc_id(1, ...)` no cliente. As funções `_host_*` revalidam tudo (item existe, valor ≤ `base_value`, saldo, nível máximo).

| Pedido (qualquer peer) | Execução no host |
| :--- | :--- |
| `request_report_discovery(item_id, final_value)` | `_host_report_discovery` |
| `request_sell_item(item_id, final_value)` | `_host_sell_item` |
| `request_donate_item(item_id)` | `_host_donate_item` |
| `request_buy_upgrade(upgrade_id)` | `_host_buy_upgrade` → `purchase_result` só para quem comprou |

Só no host: `advance_day()`, `reset_state()`, `load_snapshot(data)`.

### Sinais do `GameState`
`money_changed(new_amount)`, `collection_updated(total_found, max_items)`, `item_sold(item_name, value)`, `item_donated(item_name, reward)`, `upgrades_changed(upgrade_levels)`, `purchase_result(upgrade_id, success, message)`, `state_synced()`.

### Snapshot
Após cada mudança o host envia a todos `_receive_snapshot` com:

```
{ "team_money": int, "current_day": int, "discovered_items": Array[String], "upgrade_levels": { "detector": int, "pinpointer": int, "shovel": int } }
```

Quem entra recebe o snapshot em `peer_connected` (e o cliente pede de novo com `_request_full_state`). `apply_snapshot` valida tipos e limita níveis.

### Loja (`GameState.UPGRADES`)
`detector` 3 níveis (300 / 600 / 1200) · `pinpointer` 1 nível (500) · `shovel` 1 nível (800). `get_next_upgrade_cost` devolve -1 no máximo. `equipped_detector_level = 1 + nível do detector` (lido pelo `MetalDetector`).

### Vender vs. doar (DiscoveryBridge)
`BuriedSpot` → `ItemPickup` → mochila (`CarriedItem`) → `SellPoint.deliver()` → `DiscoveryBridge.report_item_found(item, final_value)` → `GameState.request_report_discovery`. O host decide:
- **Item inédito:** doado ao museu, a equipe recebe `MUSEUM_REWARD_RATIO` (50%) do valor.
- **Item repetido:** vendido por `final_value` (limitado a `base_value`).

### Ciclo do `SessionManager`
1. Host: `request_start_expedition(map_id)` (exige `can_start_map`: nível do detector e cena `res://world/map_<id>.tscn`).
2. RPC `_rpc_enter_map` → todos trocam de cena (`scene_changing`, `expedition_started`). Quem entra no meio recebe `_rpc_sync_scene`.
3. Durante a expedição o host junta `item_sold`/`item_donated` no resumo.
4. Host: `request_end_expedition()` → `advance_day()` → `SaveManager.save_game()` → `_rpc_return_to_lobby(summary)` → `expedition_ended(summary)` em todos.
5. Queda do host: cliente volta ao lobby e recebe `host_lost`.

Resumo: `{day, map_id, map_name, money_start, money_end, money_earned, entries: [{name, action: "sold"|"donated", value}]}`.

Rede: ENet, porta `7777`, máx. 4 jogadores (`NetworkManager.host_game` / `join_game` / `disconnect_game`).

## 3. Save (`user://scandig_save.json`, versão 2)

```json
{ "version": 2, "team_money": 100, "current_day": 1, "discovered_items": ["moeda_antiga"], "upgrade_levels": { "detector": 0, "pinpointer": 0, "shovel": 0 } }
```

Só o host grava e carrega. Saves v1 (`equipped_detector_level`) são convertidos ao carregar. No Windows: `%APPDATA%\Godot\app_userdata\ScanDig\scandig_save.json`.

## 4. Testes headless (Git Bash)

```bash
cd "/c/Projeto jogo/ScanDig"
G=/c/Godot/Godot_v4.3-stable_win64_console.exe
SAVE="$APPDATA/Godot/app_userdata/ScanDig/scandig_save.json"

[ -f "$SAVE" ] && cp "$SAVE" "$SAVE.bak"                          # backup (os testes gravam o save)
timeout 300 $G --headless --path . --editor --quit-after 600 >/dev/null 2>&1   # cache de classes

timeout 240 $G --headless --path . -s addons/gut/gut_cmdln.gd       # GUT: "All tests passed!"
$G --headless --path . --script res://core/tests/flow_test.gd       # offline: "RESULT fails=0"

(timeout 60 $G --headless --path . --script res://core/tests/net_host.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client.gd   # cliente entra a meio: estado igual ao host

(timeout 60 $G --headless --path . --script res://core/tests/net_host_drop.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client_drop.gd   # "host_lost=true scene=LobbyBase"

[ -f "$SAVE.bak" ] && mv "$SAVE.bak" "$SAVE"                       # restaura o save
```

No headless, `Parameter "m" is null` (mesh) e `ObjectDB instances leaked` são esperados (sem GPU). Qualquer `SCRIPT ERROR` é falha.
