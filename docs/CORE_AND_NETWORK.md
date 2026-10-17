# ScanDig — Core, Rede e Save (frente do Dev B)

Documentação técnica de `res://core/` e `res://ui/`. Se algo aqui divergir do código, o código vence: atualizem este ficheiro.

## 1. Autoloads

| Autoload | Script | `class_name` | Acesso |
| :--- | :--- | :--- | :--- |
| `CoreGameState` | `res://core/game_state.gd` | `GameState` | `GameState.instance` |
| `CoreNetwork` | `res://core/network_manager.gd` | `NetworkManager` | `NetworkManager.instance` |
| `CoreSave` | `res://core/save_manager.gd` | `SaveManager` | `SaveManager.instance` |
| `CoreSession` | `res://core/session_manager.gd` | `SessionManager` | `SessionManager.instance` ou `/root/CoreSession` |
| `CoreSettings` | `res://core/settings_manager.gd` | `SettingsManager` | `SettingsManager.instance` |
| `CoreWeather` | `res://core/weather_manager.gd` | `WeatherManager` | `WeatherManager.instance`; no gameplay, `WeatherManager.now_*()` (neutros sem o autoload) |
| `CoreWeatherFx` | `res://ui/weather_fx.gd` | `WeatherFx` | `WeatherFx.instance` (partículas e névoa do clima, só local) |
| `CoreWeatherUI` | `res://ui/weather_hud.gd` | `WeatherHud` | `WeatherHud.instance` (aviso e ícone do clima, camada 6) |
| `CoreSessionUI` | `res://ui/session_ui.tscn` | `SessionUI` | `/root/CoreSessionUI` |
| `CorePauseMenu` | `res://ui/pause_menu.tscn` | `PauseMenu` | `PauseMenu.instance`, `PauseMenu.is_open()` (camada 45) |
| `CoreVictoryScreen` | `res://ui/victory_screen.tscn` | `VictoryScreen` | `VictoryScreen.instance`, `VictoryScreen.is_open()` (camada 46; a SessionUI, 50, cobre) |

Existem em **todas** as cenas (lobby, mapas, sandbox). Nunca os instanciem como nós dentro de uma cena.

### Armadilhas da Godot

| Problema | Sintoma | Solução |
| :--- | :--- | :--- |
| Editor aberto com versão antiga em memória grava por cima do `project.godot` | A secção `[autoload]` desaparece; aba Expedições mostra "Sistema de expedições indisponível" | `git restore project.godot world/lobby_base.tscn`, fechar o editor **sem guardar** e reabrir. Depois de cada pull/commit que mexa em `project.godot` ou cenas, reabrir o editor |
| Nome do autoload igual ao `class_name` | Erro "Class X hides an autoload singleton" | Prefixo `Core*` no autoload; aceder por `X.instance` |
| Godot gera UIDs (`uid="uid://..."`) em `.tres`/`.tscn` | Ficheiros aparecem modificados sem mudança de lógica | Commit separado `chore(editor): update Godot resource uids`; nunca commitar UIDs de ficheiros do Dev A |
| Cache de classes desatualizado após pull | `Could not find type "X"` no headless | `--headless --path . --editor --quit-after 600` antes dos testes |
| `multiplayer_peer = null` | `No multiplayer peer is assigned` em `is_server()` | Usar sempre `OfflineMultiplayerPeer.new()` |
| `class_name` que começa com `_` (ex.: `_Noray` do addon netfox.noray) | A 4.3 não põe a classe no cache: `Could not find type "_X"` | Não usar `_` no início de `class_name`; para script de terceiros, `const X: GDScript = preload(...)` |

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
| `request_complete_quest(quest_id)` | `_host_complete_quest` (**só do host**) → `quest_completed` em todos |
| `request_report_secret(secret_id)` | `_host_report_secret` (**só do host**) → `secret_found` em todos |

Só no host: `advance_day()`, `reset_state()`, `load_snapshot(data)`.

**Chefe, missão e segredo só vêm do host (Fase 4, #5; #45).** Chefes, NPCs e interativos rodam na simulação do host, e o `_process_dying` do chefe chama `request_report_boss_defeated` fora de qualquer RPC. Por isso `_host_report_boss_defeated`, `_host_complete_quest` e `_host_report_secret` só aceitam `multiplayer.get_remote_sender_id()` igual a `0` (chamada local) ou `1` (`_is_host_sender`); o pedido de qualquer outro peer é ignorado com `push_warning`, sem mexer no estado. O gameplay deve chamar esses `request_*` no host, nunca a partir de um RPC de cliente. Compras, entregas (`_host_report_discovery`/`_sell`/`_donate`) e desbloqueio de mapa continuam aceitos de qualquer peer. Teste: `core/tests/boss_authority_test.gd`.

### Missões e segredos (#45)
- `QUESTS: Dictionary` → `ze_anzol` (`"O anzol de ouro"`, 600) e `lurdes_chaves` (`"Os corvos levaram as chaves"`, 1.800, Campo). `request_complete_quest(id)` paga `reward` **uma vez por save** e acrescenta o id a `completed_quests`; id desconhecido ou repetido é ignorado. O item de recompensa (ex.: `concha_dourada`) o gameplay larga no chão e vai ao museu pelo caminho normal.
- `SECRETS: Array[String]` → `praia_reliquia_navio`, `praia_reliquia_pedra`, `praia_reliquia_mare`, `praia_polvo`, `praia_ovo_pato`, `praia_ovo_castelo`; Campo: `campo_reliquia_poco`, `campo_reliquia_fardo`, `campo_reliquia_muro`, `campo_espantalho`, `campo_ovo_circulo`, `campo_ovo_ovelha`. `request_report_secret(id)` só registra em `found_secrets` (sem dinheiro).
- `EXTRA_BOSSES: Array[String]` → `octopus` (Praia), `crow_king` (Corvo-Rei, chefe da missão da Lurdes) e `scarecrow` (Espantalho Desperto, escondido). `request_report_boss_defeated` aceita estes ids e os de `MAP_UNLOCK_BOSSES`; os extras só entram em `defeated_bosses`, sem desbloquear nada.
- Consulta: `is_quest_completed(id)`, `is_secret_found(id)`, `completed_quests`, `found_secrets`.
- Sinais: `quest_completed(quest_id, reward)` e `secret_found(secret_id)`, emitidos pelo `apply_snapshot` em **todos os peers** para cada id que não estava na lista anterior. Atenção: carregar um save ou entrar numa sessão também traz ids "novos" para aquele peer e dispara os sinais; quem mostra aviso na tela deve ignorar o que chega junto com `game_loaded` ou com a primeira sincronização.
- Itens do Campo em `items/catalog/`, fora de qualquer `item_pool` (o gameplay larga no chão; vão ao museu pelo caminho normal): `sino_bronze` 700 (recompensa da Lurdes), `anel_do_poco` 600, `moeda_celta` 480, `fibula_romana` 520 (relíquias), `pena_corvo_rei` 650 e `lanterna_espantalho` 900 (troféus). Catálogo: 33 itens.
- Novos ids entram nessas constantes, no core (pedir ao Dev B).

### Sinais do `GameState`
`money_changed(new_amount)`, `collection_updated(total_found, max_items)`, `item_sold(item_name, value)`, `item_donated(item_name, reward)`, `upgrades_changed(upgrade_levels)`, `purchase_result(upgrade_id, success, message)`, `item_purchase_result(item_id, success, message)`, `progression_changed(unlocked_maps, defeated_bosses)`, `map_unlock_result(map_id, success, message)`, `quest_completed(quest_id, reward)`, `secret_found(secret_id)`, `creature_discovered(kind)`, `game_completed_changed(completed)`, `game_victory()`, `state_synced()`.

**Estado x evento (#81).** `game_completed_changed` é estado: vem de qualquer `apply_snapshot` em que `game_completed` muda, inclusive ao carregar o save, ao entrar no meio da sessão (`_request_full_state`) e ao reconectar. `game_victory` é evento: só sai quando `the_sleeper` é derrotado **nesta sessão**, uma vez, em todos os peers presentes. O host chama `_receive_game_victory()` localmente e por RPC (`authority`, `call_remote`, `reliable`), **depois** de `_receive_snapshot.rpc`. Como os RPCs reliable do mesmo nó chegam em ordem, o cliente já tem as contagens novas. Quem entra depois recebe só o estado. A tela "Jogo concluído" (`CoreVictoryScreen`) escuta `game_victory`: trava o player (`Player.is_settings_open()`) e o menu de pausa (`PauseMenu.can_open()`), e fecha em "Continuar explorando", no Esc, em `SessionManager.scene_changing` e quando o jogo deixa de estar concluído (reset ou outro save).

### Snapshot
Após cada mudança o host envia a todos `_receive_snapshot` com:

```
{ "team_money": int, "current_day": int, "discovered_items": Array[String], "upgrade_levels": { "detector": int, "pinpointer": int, "shovel": int, "backpack": int }, "unlocked_maps": Array[String], "defeated_bosses": Array[String], "completed_quests": Array[String], "found_secrets": Array[String] }
```

Quem entra recebe o snapshot em `peer_connected` (e o cliente pede de novo com `_request_full_state`). `apply_snapshot` valida tipos e limita níveis.

**Valores nas mensagens:** as mensagens do core com valor (`R$ <custo>`/`R$ <preço>` abaixo) usam `MoneyFormat.money` (`core/money_format.gd`: milhar com ponto e NBSP depois de "R$", como o `UiFormat`), então a UI pode exibi-las direto: `"Saldo insuficiente para desbloquear Campo Antigo (R$ 1.200)."`.

### Loja (`GameState.UPGRADES`)
Tabela aprovada na #25; travas da Geleira na #49 (valores provisórios até a medição por bot, #46). Cada nível tem um custo e um mapa que precisa estar desbloqueado (`required_maps`, `—` = sem trava).

| Upgrade | Nome | Nível comprado: custo (mapa exigido) | Nível máx. |
| :--- | :--- | :--- | :--- |
| `detector` | Detector | 1: 300 · 2: 600 · 3: 700 · 4: 2.000 (`ruinas`) · 5: 12.000 (`geleira`) · 6: 25.000 (`cratera`) | 6 (equipado Nv.7) |
| `pinpointer` | Pinpointer de Precisão | 1: 500 · 2: 18.000 (`cratera`) | 2 |
| `shovel` | Pá de Fibra | 1: 800 · 2: 1.200 (`ruinas`) · 3: 12.000 (`cratera`) | 3 (pá Nv.4) |
| `backpack` | Mochila Reforçada | 1: 400 · 2: 800 · 3: 1.600 (`campo`) · 4: 1.800 (`ruinas`) · 5: 6.000 (`geleira`) | 5 (8 espaços) |

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
- Armas em `res://items/tools/` (preços provisórios, #45): `estilingue` 250, `forcado` 600, `lanterna_magnesio` 2.500, `arpao_corda` 6.000, `pulso_magnetico` 15.000. A banca de cada mapa (cena) escolhe quais vende.
- `get_tool_data(item_id)` → `ToolData` de `TOOLS_DIR/<id>.tres` (`res://items/tools`), ou `null` se o id for inválido (vazio, com `/`, `\` ou `..`), não existir ou não bater com `ToolData.id`.
- `get_max_item_value(item_data)` → teto anti-trapaça de venda/doação: `ceil(base_value × BuriedSpot.RARE_VALUE_MULTIPLIER × BuriedSpot.PERFECT_BONUS_MULTIPLIER)` (ex.: base 250 → 938).

### Ferramentas da Praia (`request_purchase_item`)
A banca da Praia (`ShopOffer`) deve comprar só por esta API, nunca debitando `team_money` no cliente. `request_purchase_item(String(tool_data.id))` → o host valida id, `price > 0` e saldo, debita e envia o snapshot. Só o comprador recebe `item_purchase_result(item_id, success, message)`; com `success == true` o gameplay dele cria o `CarriedItem` (`CarriedItem.create_from_tool_data`). O core não sabe de mochila: o espaço deve ser checado antes do pedido. Ferramentas compradas não entram no snapshot nem no save.

Mensagens: `"Comprado: <nome>"`, `"Saldo insuficiente para <nome> (R$ <preço>)."`, `"Produto indisponível."`.

### Progressão de mapas
Regras em `docs/PACING.md` §1. Ordem: `praia` → `campo` → `ruinas` → `geleira` → `cratera` (`SessionManager.MAP_ORDER`; ids fora da lista vão para o fim, em ordem alfabética). `MapData` em `GameState.MAPS_DIR` (`res://items/maps/<id>.tres`, `id` == nome do arquivo).

Ordem e chefes do `docs/GAME_DESIGN.md` §3 (#45): cada mapa pede o chefe principal do anterior.

| Mapa | Nome | `unlock_cost` | Detector mínimo | Chefe exigido (`MAP_UNLOCK_BOSSES`) | Chefe principal do mapa |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `praia` | Praia | 0 (sempre desbloqueada) | Nv.1 | — | `king_crab` |
| `campo` | Campo Antigo | 1.200 | Nv.2 | `king_crab` (Caranguejo-Rei) | `giant_mole` |
| `ruinas` | Ruínas | 8.000 | Nv.4 | `giant_mole` (Toupeira Gigante) | `ancient_guardian` |
| `geleira` | Geleira Eterna | 20.000 | Nv.5 | `ancient_guardian` (Guardião Ancestral) | `frozen_mammoth` |
| `cratera` | Cratera | 55.000 | Nv.6 | `frozen_mammoth` (Mamute Congelado) | (chefe final) |

O `item_pool` da Geleira é preenchido na #49 (Dev_UI_Economy); a cena `world/map_geleira.tscn` ainda não existe (Dev A, #45): a Geleira aparece na lista, travada pelo chefe, e depois de paga mostra "Em breve.". Na #49 a Geleira passa a vender o detector nível 5 (equipado Nv.6, que a Cratera exige) e a mochila nível 5 (8 espaços); valores provisórios até a medição por bot (#46).

Troféus de chefe ficam no catálogo, fora de qualquer `item_pool`: `coroa_caranguejo_rei` (Caranguejo-Rei) e `garra_toupeira` (Toupeira Gigante, R$ 900).

Desbloquear é uma compra única, só depois de vencer o chefe exigido. Um mapa desbloqueado só é jogável se `res://world/map_<id>.tscn` existir (senão a UI mostra "Em breve").

`GameState`:
- `unlocked_maps: Array[String]` (só mapas pagos) e `defeated_bosses: Array[String]`.
- `is_map_unlocked(map_id)` → `unlock_cost <= 0` ou está em `unlocked_maps`.
- `is_boss_defeated(boss_id)`.
- `get_map_unlock_block_reason(map_id)` → `""` se pode desbloquear agora; senão o motivo pronto para a UI.
- `request_unlock_map(map_id)` → o host revalida com `get_map_unlock_block_reason`, debita `unlock_cost`, adiciona a `unlocked_maps` e sincroniza. Resposta em `map_unlock_result` só para quem pediu.
- `request_report_boss_defeated(boss_id)` → o host aceita só os `boss_id` de `MAP_UNLOCK_BOSSES` e `EXTRA_BOSSES`, só da própria simulação (nunca de um cliente), sem duplicar e sem dar dinheiro. O gameplay liga o `boss_defeated` de cada chefe a isso.
- `map_id` vazio, com `/`, `\` ou `..`, inválido como nome de arquivo ou com `MapData.id` diferente é tratado como mapa desconhecido.

Mensagens (texto exato): `"Mapa desconhecido."`, `"<nome> já está desbloqueado."`, `"Vença o chefe <chefe> (<mapa anterior em MAP_ORDER>) para liberar."`, `"Saldo insuficiente para desbloquear <nome> (R$ <custo>)."`, sucesso `"<nome> desbloqueado!"`.

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

### Salas online (noray, #30)
Código de sala de 6 caracteres para jogar pela internet sem abrir porta. O jogo continua no **ENet**: o servidor [noray](https://github.com/foxssake/noray) (MIT) só apresenta os dois lados, faz o *hole punch* e, se ele falhar, repassa o tráfego (*relay*). Cliente próprio em `core/noray_client.gd` (`NorayClient`, sem addon). LAN e IP direto (`host_game`/`join_game`) e UPnP continuam iguais.

**Contrato (a UI programa contra ele)**
```gdscript
# core/room_code.gd (RoomCode): utilitário puro
const LENGTH: int = 6
const CHARSET: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"   # 32 caracteres, sem 0/O nem 1/I
static func normalize(text: String) -> String           # "k7q-3mx " -> "K7Q3MX" (tira espaços e hífens, maiúsculas)
static func is_valid(code: String) -> bool              # depois de normalize: 6 caracteres do CHARSET
static func format_for_display(code: String) -> String  # "K7Q3MX" -> "K7Q-3MX"

# core/network_manager.gd
signal room_code_ready(code: String)          # host: código normalizado (sem hífen)
signal online_join_progress(stage: String)    # "registrando" | "punch" | "relay" | "conectado"
func host_online(port: int = DEFAULT_PORT) -> Error
func join_code(code: String) -> Error
func is_online_room() -> bool                 # sessão atual criada por código (host com sala ou cliente conectado)
func get_room_code() -> String                # "" se não houver
```
- `host_online(port)` e `join_code(code)` voltam na hora (`OK`, ou `ERR_INVALID_PARAMETER` com código inválido). O resto chega por sinais: `room_code_ready` no host, `connection_succeeded` no cliente e `connection_error(message)` nos dois. Não precisa de `await`.
- **Host:** "registrando" → registra no noray com a porta UDP `port` (é nela que o ENet abre, então o UPnP da mesma porta continua valendo) → `host_game(port)` → `room_code_ready(código)`. Mostre com `RoomCode.format_for_display`. O host mantém o TCP com o noray aberto para receber os pedidos de entrada e abrir o caminho (handshake) até cada cliente.
- **Cliente:** aceita `k7q3mx`, `K7Q-3MX` ou `K7Q 3MX`. As etapas são "registrando" → "punch" → (se falhar) "relay" → "conectado". **Sucesso ou erro em até 15 s** (`ONLINE_JOIN_DEADLINE_SEC`).
- `disconnect_game()` também fecha o noray. A queda do host (`server_disconnected`) também.
- Erros (`connection_error`, texto exato):
  - `"Código de sala inválido."`: na hora, sem rede;
  - `"Servidor de salas fora do ar."`: ~5 s com o noray desligado;
  - `"Servidor de salas mal configurado: código com <n> caracteres (esperado 6)."`: só no host, quando o noray está no ar mas devolve um código fora do formato (sem `NORAY_OID_LENGTH`/`NORAY_OID_CHARSET`); o ENet não chega a abrir;
  - `"Sala não encontrada."`: o noray não conhece o código;
  - `"Não foi possível conectar ao amigo."`: punch e relay falharam, ou o prazo de 15 s estourou;
  - `"Não foi possível hospedar: a porta <porta> já está em uso."`;
  - `"Servidor de salas caiu: novos jogadores não conseguem entrar."`: só no host, com a sala já criada. Quem já está jogando pelo punch **continua**; quem está pelo relay cai pelo caminho normal de "host perdido".
- No cliente, `connection_failed` acompanha os erros de `join_code` (menos o código inválido).
- Timeouts (constantes nomeadas):
  - `NorayClient`: `CONNECT_TIMEOUT_SEC` 5, `REPLY_TIMEOUT_SEC` 5, `REGISTRAR_TIMEOUT_SEC` 3 e `HOST_HANDSHAKE_SEC` 5;
  - `NetworkManager`: `PUNCH_TIMEOUT_SEC` 4, `RELAY_TIMEOUT_SEC` 4, `ONLINE_ENET_TIMEOUT_SEC` 3 e `ONLINE_JOIN_DEADLINE_SEC` 15.

**Endereço do servidor**: padrão `127.0.0.1`, TCP `8890` e registrador UDP `8809`.
- No jogo: `user://scandig_settings.cfg`, seção `[online]`, com `noray_address`, `noray_port` e `noray_registrar_port`.
- Nos testes: `-- --noray=host:porta` e `-- --force-relay` (pula o punch).
- A VPS pública ainda não existe; quando existir, basta trocar o `noray_address`.

**Protocolo** (noray 1.5.x): TCP de texto, uma linha `comando dados` por mensagem.
1. `register-host` → `set-oid <código>` + `set-pid <pid>`.
2. O PID vai por UDP ao registrador, que responde `OK`: a porta de origem vira a porta pública do peer.
3. `connect <código>` (punch) ou `connect-relay <código>`. **Os dois lados** recebem `connect ip:porta` ou `connect-relay porta` (no IP do noray). Sala inexistente volta sem dados.
4. Handshake UDP de 3 estados (`$rwx`, como o addon netfox.noray) e depois o ENet na porta registrada.

**Servidor**
- Versão testada: **noray 1.5.2, commit `38a27e7`, em Node v24**. As versões mais novas (1.5.5+) exigem **Bun**; para a VPS, use a imagem Docker oficial ou fixe o commit.
- Variáveis obrigatórias para o código de 6 caracteres:
  ```
  NORAY_OID_LENGTH=6
  NORAY_OID_CHARSET=23456789ABCDEFGHJKLMNPQRSTUVWXYZ
  ```
  Com outro formato, o host recusa o código: `push_error` e "Servidor de salas mal configurado: código com <n> caracteres (esperado 6).".
- **O noray 1.5.2 lê o `.env` da pasta onde é iniciado** (`dotenv`). Sem o `.env` (ou sem as duas variáveis no ambiente), ele volta ao padrão de 21 caracteres, e o jogo mostra "mal configurado" no host, não "fora do ar".
- São 32⁶ ≈ 1,07 bilhão de códigos, e o noray não checa colisão. Com poucas salas abertas ao mesmo tempo, o risco é desprezível.
- Portas: TCP 8890, UDP 8809 (registrador), HTTP 8891 (métricas) e a faixa UDP de relay (`NORAY_UDP_RELAY_PORTS`).
- **Limites padrão do relay, ainda a medir com 4 jogadores:** 128 KiB/s por relay (`NORAY_UDP_RELAY_MAX_INDIVIDUAL_TRAFFIC`) e vida máxima de **4 h** ou 4 GB por relay (`NORAY_UDP_RELAY_MAX_LIFETIME_*`). No spike, 2 jogadores na Praia passaram ~300 pacotes/s pelo relay.
- **Pendente:** testar em rede real (CGNAT ou hotspot do celular) quando houver VPS. Em localhost o punch sempre funciona, então a passagem do punch para o relay só foi coberta forçando o relay.

**Noray local para os testes** (fora do repositório; Node v24, sem Docker):
```bash
git clone https://github.com/foxssake/noray.git noray-node && cd noray-node && git checkout 38a27e7
npm install --ignore-scripts --omit=dev
# .env opcional: NORAY_SOCKET_HOST=127.0.0.1, NORAY_UDP_RELAY_PORTS=49152-49200 (sobe mais rápido)
NORAY_OID_LENGTH=6 NORAY_OID_CHARSET=23456789ABCDEFGHJKLMNPQRSTUVWXYZ node bin/noray.mjs
```

**Atalhos** (noray em `../_ext/noray`, ou `NORAY_DIR`):
- `tools/run_headless_tests.sh [godot]` (Git Bash e CI): roda todo `*_test.gd` de `core/tests` e `ui/tests` e os pares de rede local (`net_host`/`net_client`, `_drop`, `_multi`, `net_names_*`, `net_save_*`). Falha com `SCRIPT ERROR`, `Parse Error` ou `RESULT fails` > 0; termina em `HEADLESS OK`. Fora: `theme_snapshots` (janela) e `net_room_*` (noray). Copia e restaura o save do jogador. Rode antes do push sempre que mexer em `core/` ou `ui/`.
- `tools/test_online.sh [godot]` (Git Bash): roda `room_code_test`, `net_room_errors_test` e o par `net_room_host`/`net_room_client`. Usa o noray que já estiver na 8890 (e não o desliga); senão sobe um com o código de 6 caracteres e desliga no fim. Sem noray: `SKIP` e código 0. Termina em `ONLINE OK` (0) ou `ONLINE FALHOU: <testes>` (1); os logs ficam num diretório temporário.
- `tools/play_online.bat [janelas]` (duplo clique, teste manual): se a 8890 estiver livre, sobe o noray numa janela "noray" e abre 2 janelas do jogo (até 4). Na primeira: "Online (código)" → "Criar sala online"; nas outras, digite o código e clique em "Entrar". Fechar a janela "noray" desliga o servidor.

### Sair da sessão (`NetworkManager.session_left`)
- `signal session_left(was_host: bool)`: o próprio peer saiu por `disconnect_game()`. `was_host` é capturado antes da limpeza (depois dela o peer é offline e `is_server()` dá true sempre). Não emite em queda de conexão nem no `_exit_tree`; `disconnect_game()` offline não emite nada.
- O `SessionManager` ouve o sinal e volta ao lobby, limpando expedição, resumo pendente e `ready_peers`. **Não** emite `host_lost` nem `expedition_ended`; no lobby não troca de cena.
- Host que sai no meio da expedição chama `SaveManager.save_game()` antes de limpar: dinheiro e museu ganhos até ali ficam salvos, mas o dia **não** avança e não há resumo.
- Os outros peers não mudam: se um cliente sai, o host recebe `peer_disconnected`; se o host sai, os clientes recebem `server_disconnected` → `host_lost`.
- O botão "Sair da sessão" da UI deve chamar `disconnect_game()`.

### Clima por mapa (`CoreWeather`, #99)
- Eventos por mapa em `WeatherManager.WEATHER_BY_MAP`: chuva (`rain`) na Praia e no Campo, nevasca (`blizzard`) na Geleira e tempestade de cinzas (`ashstorm`) na Cratera. Ruínas não tem evento. Cada mapa define `warning_s`, `duration_min/max`, `interval_min/max` e `intensity`. Os efeitos no auge ficam em `EFFECTS_BY_KIND`. **Tempos e intensidades se ajustam só nessas duas constantes.**
- Fases: `none` → `warning` (aviso, ainda neutro) → `active` (modificadores valem) → `none`. `signal weather_changed(kind, phase)`; no fim do evento sai com o tipo que acabou e `phase == "none"`.
- Autoridade: o host agenda (RNG próprio) a partir do `expedition_started` e para em `expedition_ending`/`scene_changing`. A cada fase aplica localmente e faz `HostSync.broadcast(self, &"_rpc_sync", [get_state()])`. Quem entra no meio recebe o estado pelo `HostSync.on_peer_ready` → `send_to`. Os clientes só aplicam (`_rpc_sync`), nunca agendam; cada peer volta sozinho ao neutro na troca de cena.
- API (neutra sem evento ativo): `dig_speed_mult()`, `detector_noise()` (0..1), `radar_scale()`, `hunger_mult()`, `current_kind()`, `phase()`, `is_active()`. Testes e bots usam `force_weather()` (host, evento do mapa atual com aviso de 3 s), `force_event(kind, duration)`, `tick(delta)` e `set_seed(n)`. No bot: `{"call": "CoreWeather", "method": "force_weather"}`.
- Visual (`CoreWeatherFx`, `ui/weather_fx.gd`) e aviso/ícone (`CoreWeatherUI`, `ui/weather_hud.gd`): só para o jogador local. As partículas (CPUParticles3D, até 400) seguem a câmera ativa. O `Environment` do mapa é trocado por uma cópia durante o evento (tween de 3 s, valores somados aos do mapa em `WeatherFx.ENV_TARGETS`), e o MESMO recurso original volta no fim; nada é gravado nos `.tres`. A opção `[video] strong_weather_fx` (aba Vídeo) só reduz partículas (metade) e névoa (35 %); os modificadores de jogo não mudam.
- Bots: `tools/run_bot.sh "<godot>" tools/bot/weather_praia.json` (também `weather_geleira.json` e `weather_cratera.json`) pega o detector, força o evento e captura antes, aviso e ativo.

## 3. Save (`user://scandig_save.json`, versão 4)

```json
{ "version": 4, "saved_at": 1792080000, "team_money": 100, "current_day": 1, "discovered_items": ["moeda_antiga"], "upgrade_levels": { "detector": 0, "pinpointer": 0, "shovel": 0, "backpack": 0 }, "unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"], "completed_quests": ["ze_anzol"], "found_secrets": ["praia_polvo"] }
```

Só o host grava e carrega. Saves v1 (`equipped_detector_level`) são convertidos ao carregar. Saves v2 antigos sem `backpack` carregam com nível 0. Saves v1/v2 sem `unlocked_maps`/`defeated_bosses` carregam com as duas listas vazias. Saves v1–v3 sem `completed_quests`/`found_secrets` carregam com as duas listas vazias. Um `ancient_guardian` em `defeated_bosses` de um save v3 continua valendo e agora libera a Geleira (antes liberava a Cratera). No Windows: `%APPDATA%\Godot\app_userdata\ScanDig\scandig_save.json`.

### Contrato do `SaveManager` (a UI programa contra ele)
```gdscript
const SAVE_VERSION: int = 4
signal save_load_failed(message: String)   # corrompido/versão nova; texto pronto para a UI
signal new_game_started()
signal save_state_changed()                # depois de load/new/save/delete: a UI recalcula

## Lê o arquivo SEM aplicar. Nunca dá erro.
## {exists: bool, valid: bool, version: int, day: int, money: int,
##  museum_found: int, museum_total: int, saved_at: int (unix, 0 se não houver), error: String}
func get_save_summary() -> Dictionary
func is_progress_applied() -> bool          # true depois de continue_game/start_new_game (ou sem save)
func continue_game() -> Error               # host/offline, fora de expedição; aplica o save (idempotente)
func start_new_game() -> Error              # host/offline, fora de expedição; backup, apaga, reset_state, grava já
```
- Continuam existindo: `save_game`, `load_game` (carga crua, para testes), `delete_save_file`, `save_to_file`, `load_from_file` e os sinais `game_saved`, `game_loaded` e `save_failed`.
- `continue_game`/`start_new_game` devolvem `ERR_UNAUTHORIZED` em cliente online e `ERR_BUSY` durante a expedição.
- `continue_game` em save corrompido devolve `ERR_FILE_CORRUPT`; em versão nova, `ERR_FILE_UNRECOGNIZED`. Nos dois casos o jogo segue do zero e emite `save_load_failed`.
- `ensure_progress_applied()` é do core: aplica o save se ninguém escolheu. A UI usa `continue_game()`.
- O `GameState` continua emitindo os sinais dele pelo `load_snapshot` (`money_changed` etc.); `quest_completed`/`secret_found` de um save carregado são filtrados pela UI fora da expedição.

### Regras
1. **Carregamento automático, sem perder nada.** Se ninguém escolheu "Continuar" ou "Novo jogo", o save é aplicado sozinho (como `continue_game()`):
   - (a) ao abrir a sessão como host: `host_game` (IP) ou `host_online` (código), no `player_connected(1)`, antes de qualquer cliente receber o snapshot;
   - (b) ao começar a primeira expedição: `request_start_expedition`, no solo ou no host, antes do `can_start_map` e do resumo.

   Defesa extra: `save_game` devolve `ERR_UNAVAILABLE` (e `save_failed`) se existe um save no disco que ainda não foi aplicado (válido **ou** corrompido). Assim, nunca grava por cima de um progresso que não foi lido.
2. **Cliente.**
   - Ao entrar (`connection_succeeded`), `is_progress_applied()` vira `false`: o estado agora é do host.
   - O cliente nunca grava. Os dois pontos de gravação do `SessionManager` (fim da expedição e saída do host no meio dela) só rodam no host/offline.
   - Ao sair (`session_left(false)`) ou perder o host (`server_disconnected`), o cliente volta ao **próprio** save (`continue_game`) ou, sem save, ao `reset_state`.
3. **Novo jogo** (`start_new_game`):
   - copia o save atual para `user://scandig_save.backup.json` (sobrescreve o backup anterior);
   - apaga o save, chama `GameState.reset_state()` (que já faz broadcast) e grava logo o estado novo;
   - emite `new_game_started` e `save_state_changed`;
   - libera a gravação se ela estava bloqueada por versão nova (o save novo guarda o antigo no backup).
   - **A confirmação com o jogador fica na UI.**
4. **Save corrompido.** Conta como corrompido: JSON inválido, raiz que não é objeto, `version` ou `team_money` que não são número, ou campos com tipo que o `apply_snapshot` rejeitaria (listas que não são `Array`, `upgrade_levels` que não é `Dictionary`, `current_day`/`saved_at` que não são número). Nesse caso:
   - o arquivo é renomeado para `user://scandig_save.corrupt-<unix>.json`;
   - emite `save_load_failed("O save estava corrompido e foi guardado como backup. Começando um jogo novo.")`;
   - segue com o jogo novo e `is_progress_applied() = true`.
   - `get_save_summary()` dá `valid=false` e o motivo em `error`.
5. **Versão mais nova que 4.**
   - Não aplica, e a gravação fica bloqueada nesta sessão (`save_game` → `ERR_UNAUTHORIZED`); o arquivo fica intacto.
   - Emite `save_load_failed("Este save é de uma versão mais nova do jogo. Atualize o ScanDig para continuar.")`.
   - `get_save_summary()` dá `valid=false` e a versão lida. As versões 1 a 3 continuam sendo convertidas.
6. **Gravação atômica.** Grava em `scandig_save.json.tmp` e renomeia por cima do `scandig_save.json` (`DirAccess.rename_absolute`; se o sistema não renomear por cima, apaga o antigo e renomeia). Grava também `"saved_at"` (unix, opcional); a versão continua 4.

### Slots (#100)
- `SaveManager.SLOT_COUNT = 3`. `slot_path(n)` fica na pasta do caminho base (`user://` no jogo; a pasta de `use_test_save_dir`/`set_save_path` nos testes), então os testes isolam os slots sozinhos.
- API: `get_slot_summary(n)` (mesmo formato do `get_save_summary` + `slot`), `select_slot(n)` (só host/offline e fora de expedição: `ERR_UNAUTHORIZED`/`ERR_BUSY`; não aplica, depois vem `continue_game`/`start_new_game`; slot vazio zera o `GameState`), `current_slot()` (0 = sem slot), `delete_slot(n)` (apaga o slot e o backup dele), `last_used_slot()` (maior `saved_at` entre os válidos; -1 sem nenhum) e `migrate_legacy_save()`.
- No jogo de verdade, o `_ready` migra o save antigo (`scandig_save.json` → slot 1, com o backup; o antigo vira `scandig_save.legacy.json`; nada é apagado e não mexe se o slot 1 já existe) e ativa o último slot usado (ou o 1).
- Com `--script`/`-s` (GUT, testes headless, capturas) ou `--bot=`, nada disso roda: o save fica no caminho base, como antes, e os testes/bots trocam com `use_test_save_dir`/`set_save_path`.
- `scandig_settings.cfg` e `scandig_hints.cfg` continuam globais (não são por slot).

### Arquivos em `user://`
| Arquivo | Quando |
| :--- | :--- |
| `scandig_save_1.json` .. `_3.json` | os 3 slots do jogo (#100), cada um com o seu `.backup.json` e `.tmp` |
| `scandig_save.legacy.json` | o save de antes dos slots, depois de copiado para o slot 1 (nunca apagado) |
| `scandig_save.json` | save de antes dos slots (migrado uma vez para o slot 1); também o caminho base de testes/bots |
| `scandig_save.json.tmp` | só durante a gravação |
| `scandig_save.backup.json` | save anterior, a cada `start_new_game()` |
| `scandig_save.corrupt-<unix>.json` | save ilegível, guardado ao tentar carregar |
| `test_saves/<teste>/` | saves isolados dos testes (`use_test_save_dir`), nunca o do jogador |

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
$G --headless --path . --script res://core/tests/quest_secret_test.gd   # missões, segredos, octopus e save v3/v4 (grava o save): "RESULT fails=0"
$G --headless --path . --script res://core/tests/boss_authority_test.gd # chefe, missão e segredo só do host; abre o próprio cliente (porta 7798, grava o save): "RESULT fails=0"
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
# Save: política completa (isolado em user://test_saves/) e o par de rede na porta 7789.
$G --headless --path . --script res://core/tests/save_flow_test.gd     # "RESULT fails=0"
(timeout 90 $G --headless --path . --script res://core/tests/net_save_host.gd > /tmp/sh.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_save_client.gd  # host com save dia 5/R$ 3200; cliente volta ao próprio save: "CLIENT RESULT fails=0"

(timeout 60 $G --headless --path . --script res://core/tests/net_host_drop.gd > /tmp/h.log 2>&1 &); sleep 3
timeout 60 $G --headless --path . --script res://core/tests/net_client_drop.gd   # "host_lost=true scene=LobbyBase"
# Salas online (#30). room_code_test sempre roda; os outros pedem o noray local (sem ele: "SKIP noray offline" + fails=0).
$G --headless --path . --script res://core/tests/room_code_test.gd        # "RESULT fails=0"
(timeout 90 $G --headless --path . --script res://core/tests/net_room_host.gd > /tmp/rh.log 2>&1 &); sleep 4
timeout 90 $G --headless --path . --script res://core/tests/net_room_client.gd   # punch: "CLIENT RESULT fails=0"; repita com "-- --force-relay"
$G --headless --path . --script res://core/tests/net_room_errors_test.gd  # código inválido, noray fora (porta 8899) e sala inexistente: "RESULT fails=0"

# Vitória ao vivo (#81, porta 7811): o cliente presente recebe game_victory 1x; o que entra depois, 0x
(timeout 90 $G --headless --path . --script res://core/tests/net_victory_host.gd > /tmp/vh.log 2>&1 &); sleep 3
(timeout 60 $G --headless --path . --script res://core/tests/net_victory_client.gd > /tmp/vc.log 2>&1 &)
until grep -q victory_sent /tmp/vh.log; do sleep 1; done; sleep 1
timeout 60 $G --headless --path . --script res://core/tests/net_victory_client.gd -- --late; sleep 6
grep RESULT /tmp/vh.log /tmp/vc.log                                  # "fails=0" nos três

# Clima (#99, porta 7813): cliente na Praia recebe aviso → ativo; o que entra no meio recebe o ativo
(timeout 100 $G --headless --path . --script res://core/tests/weather_net_host.gd > /tmp/wh.log 2>&1 &); sleep 3
(timeout 80 $G --headless --path . --script res://core/tests/weather_net_client.gd > /tmp/wc.log 2>&1 &)
until grep -q weather_active /tmp/wh.log; do sleep 1; done; sleep 1
timeout 80 $G --headless --path . --script res://core/tests/weather_net_client.gd -- --late; sleep 8
grep RESULT /tmp/wh.log /tmp/wc.log                                  # "fails=0" nos três

[ -f "$SAVE.bak" ] && mv "$SAVE.bak" "$SAVE"                       # restaura o save
```

No headless, `Parameter "m" is null` (mesh) e `ObjectDB instances leaked` são esperados (sem GPU). Qualquer `SCRIPT ERROR` é falha.
