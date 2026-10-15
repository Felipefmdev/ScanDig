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
| `request_report_boss_defeated(boss_id)` | `_host_report_boss_defeated` (**só do host**, ver abaixo) |

Só no host: `advance_day()`, `reset_state()`, `load_snapshot(data)`.

**Chefe vencido só vem do host (Fase 4, #5).** O chefe só morre na simulação do host, e o `_process_dying` dele chama `request_report_boss_defeated` fora de qualquer RPC. Por isso `_host_report_boss_defeated` só aceita `multiplayer.get_remote_sender_id()` igual a `0` (chamada local) ou `1`; o pedido de qualquer outro peer é ignorado com `push_warning`, sem mexer em `defeated_bosses`. Compras, entregas (`_host_report_discovery`/`_sell`/`_donate`) e desbloqueio de mapa continuam aceitos de qualquer peer. Teste: `core/tests/boss_authority_test.gd`.

### Sinais do `GameState`
`money_changed(new_amount)`, `collection_updated(total_found, max_items)`, `item_sold(item_name, value)`, `item_donated(item_name, reward)`, `upgrades_changed(upgrade_levels)`, `purchase_result(upgrade_id, success, message)`, `item_purchase_result(item_id, success, message)`, `progression_changed(unlocked_maps, defeated_bosses)`, `map_unlock_result(map_id, success, message)`, `state_synced()`.

### Snapshot
Após cada mudança o host envia a todos `_receive_snapshot` com:

```
{ "team_money": int, "current_day": int, "discovered_items": Array[String], "upgrade_levels": { "detector": int, "pinpointer": int, "shovel": int, "backpack": int }, "unlocked_maps": Array[String], "defeated_bosses": Array[String] }
```

Quem entra recebe o snapshot em `peer_connected` (e o cliente pede de novo com `_request_full_state`). `apply_snapshot` valida tipos e limita níveis.

### Loja (`GameState.UPGRADES`)
Tabela aprovada na #25. Cada nível tem um custo e um mapa que precisa estar desbloqueado (`required_maps`, `—` = sem trava).

| Upgrade | Nome | Nível comprado: custo (mapa exigido) | Nível máx. |
| :--- | :--- | :--- | :--- |
| `detector` | Detector | 1: 300 · 2: 600 · 3: 700 · 4: 2.000 (`ruinas`) · 5: 15.000 (`cratera`) · 6: 25.000 (`cratera`) | 6 (equipado Nv.7) |
| `pinpointer` | Pinpointer de Precisão | 1: 500 · 2: 18.000 (`cratera`) | 2 |
| `shovel` | Pá de Fibra | 1: 800 · 2: 1.200 (`ruinas`) · 3: 12.000 (`cratera`) | 3 (pá Nv.4) |
| `backpack` | Mochila Reforçada | 1: 400 · 2: 800 · 3: 1.600 (`campo`) · 4: 1.800 (`ruinas`) · 5: 10.000 (`cratera`) | 5 (8 espaços) |

`get_next_upgrade_cost` devolve -1 no máximo. `equipped_detector_level = 1 + nível do detector` (1 a 7, lido pelo `MetalDetector`; o gameplay limita em 3 até a #27).

Trava de mapa:
- `get_next_upgrade_required_map(upgrade_id)` → id do mapa exigido para o **próximo** nível; `""` sem trava, no máximo ou upgrade desconhecido.
- `get_upgrade_block_reason(upgrade_id)` → `""` se dá para comprar agora; senão o motivo, na ordem: `"Upgrade desconhecido."` → `"<nome> já está no nível máximo."` → `"Desbloqueie <nome do mapa> primeiro."` (quando `not is_map_unlocked(required)`) → `"Saldo insuficiente para <nome> (Custo: R$ <custo>)."`.
- `_host_buy_upgrade` usa `get_upgrade_block_reason`: com motivo, falha com essa mensagem em `purchase_result`, sem mexer em saldo, nível nem snapshot.
- A trava vale só para comprar: um nível já comprado antes dela continua valendo. Snapshot e save não mudaram de formato; `apply_snapshot` limita o nível ao `max_level`.
- `_ready` confere a tabela (`costs`, `required_maps` e `max_level` do mesmo tamanho; mapas exigidos existem em `MAPS_DIR`) com `push_error`.

Consultas de equipamento (só leitura, qualquer peer; clientes leem o valor do snapshot):
- `get_backpack_capacity()` → `BASE_BACKPACK_CAPACITY` (3) + nível de `backpack` (3 a 8).
- `get_shovel_level()` → 1 + nível de `shovel` (escala do `player.shovel_level`; 1 = pá básica).
- `has_pinpointer()` → nível de `pinpointer` > 0. `get_pinpointer_level()` → 0 a 2.
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
| `campo` | Campo Antigo | 1.200 | `king_crab` (Caranguejo-Rei) |
| `ruinas` | Ruínas | 8.000 | `giant_mole` (Toupeira Gigante) |
| `cratera` | Cratera | 25.000 | `ancient_guardian` (Guardião Ancestral) |

Desbloquear é uma compra única, só depois de vencer o chefe exigido. Um mapa desbloqueado só é jogável se `res://world/map_<id>.tscn` existir (senão a UI mostra "Em breve").

`GameState`:
- `unlocked_maps: Array[String]` (só mapas pagos) e `defeated_bosses: Array[String]`.
- `is_map_unlocked(map_id)` → `unlock_cost <= 0` ou está em `unlocked_maps`.
- `is_boss_defeated(boss_id)`.
- `get_map_unlock_block_reason(map_id)` → `""` se pode desbloquear agora; senão o motivo pronto para a UI.
- `request_unlock_map(map_id)` → o host revalida com `get_map_unlock_block_reason`, debita `unlock_cost`, adiciona a `unlocked_maps` e sincroniza. Resposta em `map_unlock_result` só para quem pediu.
- `request_report_boss_defeated(boss_id)` → o host aceita só os `boss_id` de `MAP_UNLOCK_BOSSES`, só da própria simulação (nunca de um cliente), sem duplicar e sem dar dinheiro. O gameplay liga o `boss_defeated` de cada chefe a isso.
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
4. Host: `request_end_expedition()` → `advance_day()` → `SaveManager.save_game()` → `expedition_ending(map_id)` (só no host) → `_rpc_return_to_lobby(summary)` → `scene_changing(lobby)` e `expedition_ended(summary)` em todos.
5. Queda do host: cliente volta ao lobby e recebe `host_lost`.
6. Saída voluntária (`disconnect_game()`): o próprio peer volta ao lobby sem `host_lost` (ver "Sair da sessão").

### Fim da expedição no host (`expedition_ending`)
- `signal expedition_ending(map_id: String)`: só no host (inclusive solo/offline), dentro de `request_end_expedition()`, **depois** de `advance_day()` + `save_game()` e **antes** do `_rpc_return_to_lobby` (que, online, roda no próprio host na mesma chamada por ser `call_local`).
- No momento do sinal: `is_in_expedition() == true`, `get_current_map().id == map_id`, a cena atual ainda é o mapa, o dia já avançou e o save já foi gravado.
- Não é emitido nos clientes, na queda do host nem no `session_left`.
- Uso previsto: nós replicados por `MultiplayerSpawner` devem sair da árvore aqui (`remove_child` + `queue_free`, de forma síncrona; só `queue_free` chega tarde), para os despawns irem antes do RPC de volta ao lobby (#22). Sem isso, o cliente já trocou de cena quando o despawn chega e loga `recv_nodes.has(net_id) ... ERR_UNAUTHORIZED`.
- Protegido contra reentrada: chamar `request_end_expedition()` de dentro do handler não faz nada.

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

### Nomes, erros de conexão e UPnP (`NetworkManager`, #28)
Sinais: `players_changed()` (a lista mudou: entrada, saída ou nome; em todos os peers), `connection_error(message)` (texto pronto para a UI) e `upnp_finished(success, public_ip, message)` (só no host, depois de `start_upnp`).

**Nomes**
- `local_player_name` vem de `user://scandig_settings.cfg` (`ConfigFile`, seção `player`, chave `name`), carregado no `_ready`. Fica fora do save do mundo (que é só do host). `set_local_player_name(name, persist = true)` sanitiza, grava (`persist=false` nos testes) e, se online, propaga.
- `sanitize_player_name(raw)` (static): tira caracteres de controle, `strip_edges` e corta em `NAME_MAX_LENGTH` (16). Pode devolver `""`.
- O host é a fonte da verdade. Ele registra o próprio nome no `host_game()`; o cliente manda `_rpc_register_name(local_player_name)` ao conectar; o host sanitiza e faz broadcast de `_rpc_sync_players(connected_players)` em toda entrada, saída e troca de nome. Nos clientes a lista é **substituída** pela do host (só aceita do peer 1, chaves `int` e `name` `String`, sanitizado de novo).
- `connected_players` continua `{peer_id: {"peer_id", "name"}}` e `size()` conta todos os peers. `get_player_name(peer_id)` → nome registrado, ou `"Host"` (peer 1), ou `"Jogador N"` (N = posição 1-based na lista ordenada de ids).
- `get_local_addresses()` → IPv4 privados (10.x, 172.16–31.x, 192.168.x) para jogar na mesma rede.

**Erros (`connection_error`)**, texto exato:
- `host_game` sem conseguir abrir a porta: `"Não foi possível hospedar: a porta <porta> já está em uso."`
- `join_game` com IP inválido: `"Endereço inválido: <ip>"`, devolve `ERR_INVALID_PARAMETER` sem criar peer (vazio continua virando `127.0.0.1`).
- Sem resposta em `JOIN_TIMEOUT_SEC` (10 s): limpa o peer, emite `connection_failed` e `"O host não respondeu em 10 s. Confira o IP e se a porta está aberta."` (`Timer` filho, cancelado ao conectar, ao falhar e no `_cleanup_peer`).
- `connection_failed` do ENet: `"Não foi possível conectar (host offline, porta fechada ou sala cheia)."`

**UPnP** (`start_upnp(port = DEFAULT_PORT)`):
- **Só pela UI, depois de hospedar; nunca dentro do `host_game()`.** Abre a porta UDP no roteador do jogador, que é uma ação real na rede dele. Offline ou como cliente só dá `push_warning`.
- Roda numa `Thread` (`UPNP.discover`, `get_gateway`/`is_valid_gateway`, `add_port_mapping(port, port, "ScanDig", "UDP")`, `query_external_address`); nunca chama `UPNP` na thread principal. O resultado volta com `call_deferred` e preenche `public_ip`.
- Mensagens: sucesso `"Porta <porta> aberta no roteador. Passe o IP <ip> aos amigos."`; sem gateway `"UPnP indisponível: abra a porta <porta> (UDP) no roteador ou jogue na mesma rede."`; recusa `"O roteador recusou abrir a porta <porta> (UPnP). Abra manualmente (UDP)."`
- Ao sair da sessão (`_cleanup_peer`), a thread remove o mapeamento e termina com `wait_to_finish`; a saída espera no máximo 3 s (se o roteador demorar mais, a thread é juntada no `_exit_tree`). Sair no meio da descoberta não emite `upnp_finished`.
- `_upnp_factory` (Callable) é um ponto de injeção só para testes: troca o `UPNP` real por um falso.

### Sair da sessão (`NetworkManager.session_left`)
- `signal session_left(was_host: bool)`: o próprio peer saiu por `disconnect_game()`. `was_host` é capturado antes da limpeza (depois dela o peer é offline e `is_server()` dá true sempre). Não emite em queda de conexão nem no `_exit_tree`; `disconnect_game()` offline não emite nada.
- O `SessionManager` ouve o sinal e volta ao lobby, limpando expedição, resumo pendente e `ready_peers`. **Não** emite `host_lost` nem `expedition_ended`; no lobby não troca de cena.
- Host que sai no meio da expedição chama `SaveManager.save_game()` antes de limpar: dinheiro e museu ganhos até ali ficam salvos, mas o dia **não** avança e não há resumo.
- Os outros peers não mudam: se um cliente sai, o host recebe `peer_disconnected`; se o host sai, os clientes recebem `server_disconnected` → `host_lost`.
- O botão "Sair da sessão" da UI deve chamar `disconnect_game()`.

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
$G --headless --path . --script res://core/tests/upgrade_lock_test.gd  # trava de mapa da loja: "RESULT fails=0"
$G --headless --path . --script res://core/tests/value_cap_test.gd  # teto de venda/doação: "RESULT fails=0"
$G --headless --path . --script res://core/tests/purchase_item_test.gd  # ferramentas da Praia: "RESULT fails=0"
$G --headless --path . --script res://core/tests/map_unlock_test.gd    # progressão de mapas (grava o save): "RESULT fails=0"
$G --headless --path . --script res://core/tests/scene_ready_test.gd   # peer_scene_ready no solo: "RESULT fails=0"
$G --headless --path . --script res://core/tests/expedition_ending_test.gd  # ordem do expedition_ending e reentrada (grava o save): "RESULT fails=0"
$G --headless --path . --script res://core/tests/leave_session_test.gd # sair da sessão (porta 7792, grava o save): "RESULT fails=0"
$G --headless --path . --script res://core/tests/boss_authority_test.gd # chefe só do host; abre o próprio cliente (porta 7798, grava o save): "RESULT fails=0"
$G --headless --path . --script res://core/tests/net_errors_test.gd    # sanitize, IP inválido, porta em uso, timeout e thread do UPnP com UPnP falso: "UPNP skipped" + "RESULT fails=0"
# Só com autorização do dono da rede: "-- upnp" abre de verdade a porta 7797 (UDP) no roteador e fecha logo depois.
# $G --headless --path . --script res://core/tests/net_errors_test.gd -- upnp

(timeout 60 $G --headless --path . --script res://core/tests/net_host.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client.gd   # cliente entra a meio: estado igual ao host, "CLIENT RESULT fails=0"
grep HOST /tmp/h.log   # "HOST scene_ready=[1, <id do cliente>] ... ok=true" e "HOST ready_after_end=[]"

# Nomes (porta 7794; backup de scandig_settings.cfg, embora os testes usem persist=false): "RESULT fails=0" nos três
(timeout 90 $G --headless --path . --script res://core/tests/net_names_host.gd > /tmp/nh.log 2>&1 &); sleep 3
(timeout 90 $G --headless --path . --script res://core/tests/net_names_client.gd -- A > /tmp/na.log 2>&1 &); sleep 2
timeout 90 $G --headless --path . --script res://core/tests/net_names_client.gd -- B; sleep 6; grep HOST /tmp/nh.log

(timeout 60 $G --headless --path . --script res://core/tests/net_host_drop.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client_drop.gd   # "host_lost=true scene=LobbyBase"

[ -f "$SAVE.bak" ] && mv "$SAVE.bak" "$SAVE"                       # restaura o save
```

No headless, `Parameter "m" is null` (mesh) e `ObjectDB instances leaked` são esperados (sem GPU). Qualquer `SCRIPT ERROR` é falha.
