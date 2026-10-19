class_name GameState
extends Node

## Estado global da equipe, economia e museu do ScanDig.
## Autoridade: o host (peer 1) é o único que altera o estado. Clientes enviam
## pedidos via request_*() e recebem o estado completo por snapshot.

signal money_changed(new_amount: int)
signal collection_updated(total_found: int, max_items: int)
signal item_sold(item_name: String, value: int)
signal item_donated(item_name: String, reward: int)
signal upgrades_changed(upgrade_levels: Dictionary)
signal purchase_result(upgrade_id: String, success: bool, message: String)
signal state_synced()
## Só o peer que comprou recebe. item_id = ToolData.id.
signal item_purchase_result(item_id: String, success: bool, message: String)
signal progression_changed(unlocked_maps: Array, defeated_bosses: Array)
## Só o peer que pediu recebe.
signal map_unlock_result(map_id: String, success: bool, message: String)
## Em todos os peers, uma vez por entrada nova em completed_quests (reward vem de QUESTS).
signal quest_completed(quest_id: String, reward: int)
## Em todos os peers, uma vez por entrada nova em found_secrets.
signal secret_found(secret_id: String)
## Em todos os peers, uma vez por criatura nova no Diário de campo (seen_creatures).
signal creature_discovered(kind: String)
## Em todos os peers, quando o jogo é concluído (derrota do FINAL_BOSS_ID, o colosso da ilha).
signal game_completed_changed(completed: bool)
## Vitória ao vivo: só quando o FINAL_BOSS_ID é derrotado nesta sessão (em todos os peers presentes).
## Carregar save, entrar no meio ou reconectar não emite: isso é estado (game_completed_changed).
signal game_victory()
## Em todos os peers, uma vez por fragmento novo do Mapa do Tesouro (#112).
signal map_fragment_found(fragment_id: String)
## Em todos os peers, quando um atalho de tirolesa ou ponte de corda é construído com o arpão (#105).
signal shortcut_built(shortcut_id: String)

const HOST_PEER_ID: int = 1
## Fração do valor paga como recompensa ao doar um item inédito ao museu.
const MUSEUM_REWARD_RATIO: float = 0.5
## Espaços da mochila sem nenhum upgrade.
const BASE_BACKPACK_CAPACITY: int = 3
## Catálogo de ferramentas compráveis (ToolData); o nome do arquivo é o id.
const TOOLS_DIR: String = "res://items/tools"
## Definições de mapa (MapData); arquivo <id>.tres, id == nome do arquivo.
const MAPS_DIR: String = "res://items/maps"
## Chefe que precisa ser vencido antes de pagar o desbloqueio de cada mapa.
const MAP_UNLOCK_BOSSES: Dictionary = {
	"campo": {"boss_id": "king_crab", "boss_name": "Caranguejo-Rei"},
	"ruinas": {"boss_id": "giant_mole", "boss_name": "Toupeira Gigante"},
	"geleira": {"boss_id": "ancient_guardian", "boss_name": "Guardião Ancestral"},
	"cratera": {"boss_id": "frozen_mammoth", "boss_name": "Mamute Congelado"},
}

## Definição da loja: custo de cada nível, mapa que precisa estar desbloqueado para
## comprar cada nível ("" = sem trava) e nível máximo. Tabela aprovada na #25;
## o nível 3 do detector (700, sem trava) veio da #46.
## Missões de NPC (#45): recompensa em dinheiro paga uma só vez por save.
const QUESTS: Dictionary = {
	"ze_anzol": {"name": "O anzol de ouro", "reward": 600},
	"lurdes_chaves": {"name": "Os corvos levaram as chaves", "reward": 1800},
	# Como Zé (~12 min) e Lurdes (~14 min): ~13 min da renda de bot do mapa (docs/PACING.md, #82).
	"ines_camara": {"name": "A câmara selada", "reward": 25000},
	"bjorn_expedicao": {"name": "A expedição perdida", "reward": 41000},
	"vega_sinal": {"name": "Sinal no fundo", "reward": 40000},
}
## Relíquias escondidas e easter eggs (#45): só ficam registrados no save.
const SECRETS: Array[String] = ["praia_reliquia_navio", "praia_reliquia_pedra", "praia_reliquia_mare",
	"praia_polvo", "praia_ovo_pato", "praia_ovo_castelo",
	"campo_reliquia_poco", "campo_reliquia_fardo", "campo_reliquia_muro",
	"campo_espantalho", "campo_ovo_circulo", "campo_ovo_ovelha",
	"ruinas_mumia", "ruinas_ovo_esqueleto", "ruinas_ovo_pintura", "ruinas_reliquia_altar", "ruinas_reliquia_nicho", "ruinas_reliquia_parede",
	"geleira_morsa_ancia", "geleira_ovo_boneco", "geleira_ovo_pinguim", "geleira_reliquia_iglu", "geleira_reliquia_lago", "geleira_reliquia_mamute", "geleira_yeti",
	"cratera_o_eco", "cratera_ovo_disco", "cratera_ovo_sonda", "cratera_reliquia_engrenagem", "cratera_reliquia_geodo", "cratera_reliquia_orbe"]
## Mapa do Tesouro (#103/#112): a premissa do jogo. Fragmentos de um mapa antigo enterrados nos 5
## sítios; com todos, a equipa navega até à Ilha do Tesouro. Cada um sai de uma origem no mundo
## do host: "quest:<id>" (fim de missão), "boss:<id>", "secret:<id>" ou "dig:<mapa>" (escavação
## profunda rara, pedida pelo gameplay com request_award_fragment). `piece` é a posição da peça
## no pergaminho (coluna, linha numa grelha de 4 x 2) e `hint` a dica do painel na base.
const MAP_FRAGMENTS: Dictionary = {
	"praia_frag_1": {"map": "praia", "source": "quest:ze_anzol", "piece": Vector2i(0, 1),
		"hint": "O Pescador Zé guarda um pedaço de papel velho no barco: ajude o pescador."},
	"campo_frag_1": {"map": "campo", "source": "boss:giant_mole", "piece": Vector2i(1, 1),
		"hint": "Algo grande cava túneis debaixo do círculo de pedras do Campo."},
	"ruinas_frag_1": {"map": "ruinas", "source": "quest:ines_camara", "piece": Vector2i(1, 0),
		"hint": "A arqueóloga Inês procura a câmara selada das Ruínas."},
	"ruinas_frag_2": {"map": "ruinas", "source": "secret:ruinas_reliquia_parede", "piece": Vector2i(0, 0),
		"hint": "Nas Ruínas, uma parede soa a oco."},
	"geleira_frag_1": {"map": "geleira", "source": "quest:bjorn_expedicao", "piece": Vector2i(2, 0),
		"hint": "O Velho Björn ainda espera notícias da expedição perdida."},
	"geleira_frag_2": {"map": "geleira", "source": "dig:geleira", "piece": Vector2i(2, 1),
		"hint": "Bem fundo no gelo da Geleira: um achado raro pode trazer mais do que parece."},
	"cratera_frag_1": {"map": "cratera", "source": "quest:vega_sinal", "piece": Vector2i(3, 1),
		"hint": "A Dra. Vega capta um sinal estranho no fundo da Cratera."},
	"cratera_frag_2": {"map": "cratera", "source": "boss:the_sleeper", "piece": Vector2i(3, 0),
		"hint": "O que dorme no altar da Cratera guarda a última peça."},
}
const MAP_FRAGMENT_IDS: Array[String] = ["praia_frag_1", "campo_frag_1", "ruinas_frag_1", "ruinas_frag_2",
	"geleira_frag_1", "geleira_frag_2", "cratera_frag_1", "cratera_frag_2"]
## Diário de campo (estudo How to Fish: o diário de peixes). Kind do EnemySpawner -> nome.
## Chefes ficam em defeated_bosses; aqui só as criaturas comuns.
const CREATURES: Dictionary = {
	"crab": "Caranguejo", "hermit_crab": "Ermitão", "seagull": "Gaivota",
	"snake": "Cobra", "mole": "Toupeira", "crow": "Corvo",
	"stone_guardian": "Guardião de Pedra", "bat": "Morcego",
	"ice_wolf": "Lobo do Gelo", "penguin": "Pinguim-ladrão", "walrus": "Morsa",
	"crawler": "Rastejante", "floater": "Flutuante",
}
## Final do jogo (#103/#115): o Colosso do Tesouro, o chefe disfarçado na Ilha do Tesouro. O
## the_sleeper (Cratera) é um chefe como os outros (dá o cratera_frag_2).
const FINAL_BOSS_ID: String = "gold_colossus"
## Chefes escondidos/de missão: entram em defeated_bosses sem desbloquear nada.
## Praia: octopus. Campo: crow_king (missão da Lurdes) e scarecrow (escondido).
## Mapas 3-5: idol_mummy, cave_yeti, ancient_walrus, the_sleeper, the_echo (#75).
const EXTRA_BOSSES: Array[String] = [
	"octopus", "crow_king", "scarecrow",
	"idol_mummy", "cave_yeti", "ancient_walrus", "the_sleeper", "the_echo",
	"gold_colossus",
]

const UPGRADES: Dictionary = {
	"detector": {"name": "Detector", "costs": [300, 600, 700, 2000, 40000, 150000],
		"required_maps": ["", "", "", "ruinas", "geleira", "cratera"], "max_level": 6},
	"pinpointer": {"name": "Pinpointer de Precisão", "costs": [500, 100000],
		"required_maps": ["", "cratera"], "max_level": 2},
	"shovel": {"name": "Pá de Fibra", "costs": [800, 1200, 70000],
		"required_maps": ["", "ruinas", "cratera"], "max_level": 3},
	"backpack": {"name": "Mochila Reforçada", "costs": [400, 800, 1600, 1800, 6000],
		"required_maps": ["", "", "campo", "ruinas", "geleira"], "max_level": 5},
}

static var instance: GameState = null

@export var team_money: int = 100
@export var current_day: int = 1
@export var discovered_items: Array[String] = []
## Mantido por compatibilidade: espelha 1 + upgrade_levels["detector"].
@export var equipped_detector_level: int = 1
@export var max_museum_items: int = 0

## upgrade_id -> nível comprado (0 = não comprado).
var upgrade_levels: Dictionary = {}
## Mapas pagos; mapas com unlock_cost <= 0 (a Praia) não precisam estar aqui.
var unlocked_maps: Array[String] = []
var defeated_bosses: Array[String] = []
var completed_quests: Array[String] = []
var found_secrets: Array[String] = []
var seen_creatures: Array[String] = []
## Coleção de peças entregues intactas (#93): uma entrada por item do catálogo.
var intact_items: Array[String] = []
## Peças doadas ao museu na variante rara (#111): vitrine em pedestal. Só a primeira doação conta.
var rare_items: Array[String] = []
## Fragmentos do Mapa do Tesouro já encontrados (#112), ids de MAP_FRAGMENT_IDS.
var map_fragments: Array[String] = []
## Atalhos construídos com o arpão (#105): ids dos atalhos completados.
var built_shortcuts: Array[String] = []
var game_completed: bool = false


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	_ensure_upgrade_keys()
	_validate_upgrades()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


# --- Consulta (seguro em qualquer peer) ---------------------------------------

func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func get_upgrade_max_level(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return 0
	return int(UPGRADES[upgrade_id]["max_level"])


## Custo do próximo nível, ou -1 se já está no máximo / não existe.
func get_next_upgrade_cost(upgrade_id: String) -> int:
	if not UPGRADES.has(upgrade_id):
		return -1
	var level: int = get_upgrade_level(upgrade_id)
	var costs: Array = UPGRADES[upgrade_id]["costs"]
	if level >= costs.size() or level >= get_upgrade_max_level(upgrade_id):
		return -1
	return int(costs[level])


## Id do mapa exigido para o PRÓXIMO nível; "" se não há trava, se está no máximo ou se o upgrade não existe.
func get_next_upgrade_required_map(upgrade_id: String) -> String:
	if get_next_upgrade_cost(upgrade_id) < 0:
		return ""
	var required_maps: Array = UPGRADES[upgrade_id]["required_maps"]
	var level: int = get_upgrade_level(upgrade_id)
	return str(required_maps[level]) if level < required_maps.size() else ""


## "" se dá para comprar o próximo nível agora; senão o motivo, pronto para a UI (no idioma
## atual, #131: cada peer calcula o seu).
func get_upgrade_block_reason(upgrade_id: String) -> String:
	if not UPGRADES.has(upgrade_id):
		return I18n.t("Upgrade desconhecido.")
	var upgrade_name: String = I18n.t(str(UPGRADES[upgrade_id]["name"]))
	var cost: int = get_next_upgrade_cost(upgrade_id)
	if cost < 0:
		return I18n.t("%s já está no nível máximo.") % upgrade_name
	var required_map: String = get_next_upgrade_required_map(upgrade_id)
	if not required_map.is_empty() and not is_map_unlocked(required_map):
		var map_data: MapData = _load_map(required_map)
		if map_data == null:
			push_warning("GameState: mapa '%s' exigido por '%s' não existe em %s." % [required_map, upgrade_id, MAPS_DIR])
			return I18n.t("Desbloqueie %s primeiro.") % required_map
		return I18n.t("Desbloqueie %s primeiro.") % I18n.t(map_data.display_name)
	if team_money < cost:
		return I18n.t("Saldo insuficiente para %s (Custo: %s).") % [upgrade_name, MoneyFormat.money(cost)]
	return ""


## Espaços da mochila: 3 (sem upgrade) a 8.
func get_backpack_capacity() -> int:
	return BASE_BACKPACK_CAPACITY + get_upgrade_level("backpack")


## Teto anti-trapaça para o valor de um item: base × rara × perfeita.
func get_max_item_value(item_data: ItemData) -> int:
	if item_data == null:
		return 0
	return int(ceil(float(item_data.base_value) * BuriedSpot.RARE_VALUE_MULTIPLIER * BuriedSpot.PERFECT_BONUS_MULTIPLIER))


## Nível da pá na escala do player.shovel_level: 1 = pá básica.
func get_shovel_level() -> int:
	return 1 + get_upgrade_level("shovel")


func has_pinpointer() -> bool:
	return get_upgrade_level("pinpointer") > 0


## 0 a 2.
func get_pinpointer_level() -> int:
	return get_upgrade_level("pinpointer")


func is_authority() -> bool:
	return multiplayer.is_server()


func get_total_catalog_items() -> int:
	if max_museum_items <= 0:
		max_museum_items = _count_catalog_items()
	return max_museum_items


## Consulta para UI e gameplay. Devolve null se o id for inválido ou não existir.
func get_tool_data(item_id: String) -> ToolData:
	if not _is_safe_resource_id(item_id):
		return null
	var tool_path: String = "%s/%s.tres" % [TOOLS_DIR, item_id]
	if not ResourceLoader.exists(tool_path):
		return null
	var tool: ToolData = load(tool_path) as ToolData
	if tool == null or String(tool.id) != item_id:
		return null
	return tool


func is_map_unlocked(map_id: String) -> bool:
	var map_data: MapData = _load_map(map_id)
	if map_data == null:
		return false
	# Ilha do Tesouro (#113/#116): abre só com o Mapa do Tesouro completo, não se compra.
	if map_data.requires_map_fragments:
		return has_all_map_fragments()
	return map_data.unlock_cost <= 0 or unlocked_maps.has(map_id)


func is_boss_defeated(boss_id: String) -> bool:
	return defeated_bosses.has(boss_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)


func is_secret_found(secret_id: String) -> bool:
	return found_secrets.has(secret_id)


func has_map_fragment(fragment_id: String) -> bool:
	return map_fragments.has(fragment_id)


## A equipa tem o Mapa do Tesouro completo (desbloqueia a Ilha do Tesouro, #113).
func has_all_map_fragments() -> bool:
	for id: String in MAP_FRAGMENT_IDS:
		if not map_fragments.has(id):
			return false
	return true


func is_game_completed() -> bool:
	return game_completed


## "" se pode desbloquear agora; senão o motivo, no idioma atual, pronto para a UI.
func get_map_unlock_block_reason(map_id: String) -> String:
	var map_data: MapData = _load_map(map_id)
	if map_data == null:
		return I18n.t("Mapa desconhecido.")
	if is_map_unlocked(map_id):
		return I18n.t("%s já está desbloqueado.") % I18n.t(map_data.display_name)
	if map_data.requires_map_fragments:
		return I18n.t("Complete o Mapa do Tesouro (%d/%d fragmentos) para navegar até %s no barco da Praia.") % [
			map_fragments.size(), MAP_FRAGMENT_IDS.size(), I18n.t(map_data.display_name)]
	if MAP_UNLOCK_BOSSES.has(map_id):
		var boss: Dictionary = MAP_UNLOCK_BOSSES[map_id]
		if not is_boss_defeated(str(boss["boss_id"])):
			return _boss_block_reason(map_id, str(boss["boss_name"]))
	if team_money < map_data.unlock_cost:
		return I18n.t("Saldo insuficiente para desbloquear %s (%s).") % [I18n.t(map_data.display_name), MoneyFormat.money(map_data.unlock_cost)]
	return ""


## "Vença o chefe <chefe> (<mapa anterior>) para liberar.": o chefe fica no mapa anterior de
## SessionManager.MAP_ORDER. Nome do mapa entre parênteses: "na/no/nas" mudaria a cada mapa.
func _boss_block_reason(map_id: String, boss_name: String) -> String:
	var index: int = SessionManager.MAP_ORDER.find(map_id)
	var previous: MapData = _load_map(SessionManager.MAP_ORDER[index - 1]) if index > 0 else null
	if previous == null:
		return I18n.t("Vença o chefe %s para liberar.") % I18n.t(boss_name)
	return I18n.t("Vença o chefe %s (%s) para liberar.") % [I18n.t(boss_name), I18n.t(previous.display_name)]


func get_item_display_name(item_id: String) -> String:
	var item_data: ItemData = _load_item(item_id)
	if item_data != null and not item_data.display_name.is_empty():
		return item_data.display_name
	return item_id


# --- Pedidos (chamar de qualquer peer; o host decide) -------------------------

## Regra "vender vs. doar": item inédito vai para o museu (recompensa de
## MUSEUM_REWARD_RATIO do valor); item repetido é vendido pelo valor final.
## `is_rare`: o achado é a variante rara (CarriedItem.is_rare_variant); vale só se for doado.
func request_report_discovery(item_id: String, final_value: int, is_rare: bool = false) -> void:
	_send_to_host(&"_host_report_discovery", [item_id, final_value, is_rare])


func request_sell_item(item_id: String, final_value: int) -> void:
	_send_to_host(&"_host_sell_item", [item_id, final_value])


func request_donate_item(item_id: String) -> void:
	_send_to_host(&"_host_donate_item", [item_id, -1, false])


func request_buy_upgrade(upgrade_id: String) -> void:
	_send_to_host(&"_host_buy_upgrade", [upgrade_id])


## Desbloqueio pago de mapa. A resposta chega por map_unlock_result.
func request_unlock_map(map_id: String) -> void:
	_send_to_host(&"_host_unlock_map", [map_id])


## Chamado pelo gameplay quando um chefe morre.
func request_report_boss_defeated(boss_id: String) -> void:
	_send_to_host(&"_host_report_boss_defeated", [boss_id])


## Chamado pelo gameplay (no host) quando uma missão termina; paga QUESTS[id].reward uma vez.
func request_complete_quest(quest_id: String) -> void:
	_send_to_host(&"_host_complete_quest", [quest_id])


## Chamado pelo gameplay (no host) quando um segredo de SECRETS é encontrado.
func request_report_secret(secret_id: String) -> void:
	_send_to_host(&"_host_report_secret", [secret_id])


## Gameplay (no host): um fragmento com origem "dig:<mapa>" foi desenterrado (#112).
func request_award_fragment(fragment_id: String) -> void:
	_send_to_host(&"_host_award_fragment", [fragment_id])


## Compra de ferramenta (ToolData). A resposta chega por item_purchase_result.
func request_purchase_item(item_id: String) -> void:
	_send_to_host(&"_host_purchase_item", [item_id])


func _send_to_host(method: StringName, args: Array) -> void:
	if is_authority():
		callv(method, args)
	else:
		var call_args: Array = [HOST_PEER_ID, method]
		call_args.append_array(args)
		callv(&"rpc_id", call_args)


# --- Execução no host ---------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _host_report_discovery(item_id: String, final_value: int, is_rare: bool = false) -> void:
	if not is_authority() or _load_item(item_id) == null:
		return
	if discovered_items.has(item_id):
		_host_sell_item(item_id, final_value)
	else:
		_host_donate_item(item_id, final_value, is_rare)


@rpc("any_peer", "call_remote", "reliable")
func _host_sell_item(item_id: String, final_value: int) -> void:
	if not is_authority():
		return
	var item_data: ItemData = _load_item(item_id)
	if item_data == null:
		return
	# Itens inéditos devem ir para o museu; impede cliente de pular a regra.
	if not discovered_items.has(item_id):
		_host_donate_item(item_id, final_value)
		return
	var value: int = clampi(final_value, 0, get_max_item_value(item_data))
	team_money += value
	_broadcast_snapshot()
	_notify_sold(item_id, value)


@rpc("any_peer", "call_remote", "reliable")
func _host_donate_item(item_id: String, final_value: int, is_rare: bool = false) -> void:
	if not is_authority():
		return
	var item_data: ItemData = _load_item(item_id)
	if item_data == null or discovered_items.has(item_id):
		return
	var base: int = item_data.base_value if final_value < 0 else clampi(final_value, 0, get_max_item_value(item_data))
	var reward: int = int(round(float(base) * MUSEUM_REWARD_RATIO))
	discovered_items.append(item_id)
	if is_rare and not rare_items.has(item_id):
		rare_items.append(item_id)
	team_money += reward
	_broadcast_snapshot()
	_notify_donated(item_id, reward)


@rpc("any_peer", "call_remote", "reliable")
func _host_buy_upgrade(upgrade_id: String) -> void:
	if not is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()

	var success: bool = false
	var message: String = get_upgrade_block_reason(upgrade_id)
	if message.is_empty():
		team_money -= get_next_upgrade_cost(upgrade_id)
		upgrade_levels[upgrade_id] = get_upgrade_level(upgrade_id) + 1
		success = true
		message = I18n.t("Compra realizada: %s (nível %d)!") % [I18n.t(UPGRADES[upgrade_id]["name"]), get_upgrade_level(upgrade_id)]
		_broadcast_snapshot()

	if sender == multiplayer.get_unique_id():
		purchase_result.emit(upgrade_id, success, message)
	else:
		_receive_purchase_result.rpc_id(sender, upgrade_id, success, message)


@rpc("any_peer", "call_remote", "reliable")
func _host_purchase_item(item_id: String) -> void:
	if not is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()

	var success: bool = false
	var message: String = ""
	var tool: ToolData = get_tool_data(item_id)
	if tool == null or tool.price <= 0:
		message = I18n.t("Produto indisponível.")
	elif team_money < tool.price:
		message = I18n.t("Saldo insuficiente para %s (%s).") % [I18n.t(tool.display_name), MoneyFormat.money(tool.price)]
	else:
		team_money -= tool.price
		success = true
		message = I18n.t("Comprado: %s") % I18n.t(tool.display_name)
		_broadcast_snapshot()

	if sender == multiplayer.get_unique_id():
		item_purchase_result.emit(item_id, success, message)
	else:
		_receive_item_purchase_result.rpc_id(sender, item_id, success, message)


@rpc("any_peer", "call_remote", "reliable")
func _host_unlock_map(map_id: String) -> void:
	if not is_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()

	var success: bool = false
	var message: String = get_map_unlock_block_reason(map_id)
	if message.is_empty():
		var map_data: MapData = _load_map(map_id)
		team_money -= map_data.unlock_cost
		unlocked_maps.append(map_id)
		success = true
		message = I18n.t("%s desbloqueado!") % I18n.t(map_data.display_name)
		_broadcast_snapshot()

	if sender == multiplayer.get_unique_id():
		map_unlock_result.emit(map_id, success, message)
	else:
		_receive_map_unlock_result.rpc_id(sender, map_id, success, message)


@rpc("any_peer", "call_remote", "reliable")
func _host_report_boss_defeated(boss_id: String) -> void:
	if not is_authority() or not _is_host_sender("chefe", boss_id):
		return
	if defeated_bosses.has(boss_id):
		return
	var known: bool = EXTRA_BOSSES.has(boss_id)
	for entry: Dictionary in MAP_UNLOCK_BOSSES.values():
		known = known or str(entry["boss_id"]) == boss_id
	if known:
		defeated_bosses.append(boss_id)
		var data: Dictionary = get_snapshot()
		if boss_id == FINAL_BOSS_ID:
			data["game_completed"] = true
		_add_earned_fragments(data)
		apply_snapshot(data)
		if _is_online():
			_receive_snapshot.rpc(data)
		if boss_id == FINAL_BOSS_ID:
			# Depois do snapshot: RPCs reliable do mesmo nó chegam em ordem (contagens já novas).
			_receive_game_victory()
			if _is_online():
				_receive_game_victory.rpc()
		if boss_id == FINAL_BOSS_ID and SaveManager.instance != null and SaveManager.instance.is_progress_applied():
			SaveManager.instance.save_game()


@rpc("any_peer", "call_remote", "reliable")
func _host_complete_quest(quest_id: String) -> void:
	if not is_authority() or not _is_host_sender("missão", quest_id):
		return
	if not QUESTS.has(quest_id) or completed_quests.has(quest_id):
		return
	# Aplica pelo snapshot para o host também emitir quest_completed (diff em apply_snapshot).
	var data: Dictionary = get_snapshot()
	# Cópia: Array(typed) do snapshot divide a lista com o estado e anularia a comparação.
	var quests: Array = Array(completed_quests).duplicate()
	quests.append(quest_id)
	data["completed_quests"] = quests
	_add_earned_fragments(data)
	data["team_money"] = team_money + int(QUESTS[quest_id]["reward"])
	apply_snapshot(data)
	_broadcast_snapshot()


@rpc("any_peer", "call_remote", "reliable")
func _host_award_fragment(fragment_id: String) -> void:
	if not is_authority() or not _is_host_sender("fragmento", fragment_id):
		return
	var entry: Dictionary = MAP_FRAGMENTS.get(fragment_id, {})
	if entry.is_empty() or not str(entry["source"]).begins_with("dig:") or map_fragments.has(fragment_id):
		return
	var data: Dictionary = get_snapshot()
	var frags: Array = Array(map_fragments).duplicate()
	frags.append(fragment_id)
	data["map_fragments"] = frags
	apply_snapshot(data)
	_broadcast_snapshot()


## Host: junta a `data` os fragmentos cuja origem (missão, chefe, segredo) já está cumprida em
## `data`. Chamado onde essas origens se validam e ao carregar um save (saves antigos).
func _add_earned_fragments(data: Dictionary) -> void:
	var frags: Array = Array(data.get("map_fragments", map_fragments)).duplicate()
	var quests: Array = data.get("completed_quests", completed_quests)
	var bosses: Array = data.get("defeated_bosses", defeated_bosses)
	var secrets: Array = data.get("found_secrets", found_secrets)
	for id: String in MAP_FRAGMENT_IDS:
		if frags.has(id):
			continue
		var source: PackedStringArray = str(MAP_FRAGMENTS[id]["source"]).split(":")
		var earned: bool = false
		match source[0]:
			"quest":
				earned = quests.has(source[1])
			"boss":
				earned = bosses.has(source[1])
			"secret":
				earned = secrets.has(source[1])
		if earned:
			frags.append(id)
	data["map_fragments"] = frags


@rpc("any_peer", "call_remote", "reliable")
func _host_report_secret(secret_id: String) -> void:
	if not is_authority() or not _is_host_sender("segredo", secret_id):
		return
	if not SECRETS.has(secret_id) or found_secrets.has(secret_id):
		return
	var data: Dictionary = get_snapshot()
	var secrets: Array = Array(found_secrets).duplicate()
	secrets.append(secret_id)
	data["found_secrets"] = secrets
	_add_earned_fragments(data)
	apply_snapshot(data)
	_broadcast_snapshot()


## Um achado chegou intacto à base (#93). Primeira vez de cada peça entra na coleção.
func request_report_intact(item_id: String) -> void:
	_send_to_host(&"_host_report_intact", [item_id])


@rpc("any_peer", "call_remote", "reliable")
func _host_report_intact(item_id: String) -> void:
	if not is_authority() or intact_items.has(item_id) or _load_item(item_id) == null:
		return
	var data: Dictionary = get_snapshot()
	var intact: Array = Array(intact_items).duplicate()
	intact.append(item_id)
	data["intact_items"] = intact
	apply_snapshot(data)
	_broadcast_snapshot()


## Uma criatura morreu (no host). Primeira vez de cada tipo entra no diário.
## Golpe de um convidado (EnemyBase._rpc_request_hit → _die): ainda estamos dentro da RPC dele,
## get_remote_sender_id() é o convidado e o _is_host_sender recusaria. Adiado, roda fora da RPC
## (sender 0), como o QuestRewards faz com missões e segredos (#83). Fora de RPC segue síncrono.
func report_creature(kind: String) -> void:
	if not is_authority():
		return
	if _inside_remote_rpc(multiplayer.get_remote_sender_id()):
		_host_report_creature.call_deferred(kind)
	else:
		_host_report_creature(kind)


## Dentro de uma RPC vinda de outro peer (nem chamada local nem do host).
static func _inside_remote_rpc(sender_id: int) -> bool:
	return sender_id != 0 and sender_id != HOST_PEER_ID


@rpc("any_peer", "call_remote", "reliable")
func _host_report_creature(kind: String) -> void:
	if not is_authority() or not _is_host_sender("criatura", kind):
		return
	if not CREATURES.has(kind) or seen_creatures.has(kind):
		return
	var data: Dictionary = get_snapshot()
	var seen: Array = Array(seen_creatures).duplicate()
	seen.append(kind)
	data["seen_creatures"] = seen
	apply_snapshot(data)
	_broadcast_snapshot()


## Atalhos construídos com o arpão (#105): tirolesa e ponte de corda.
func is_shortcut_built(shortcut_id: String) -> bool:
	return built_shortcuts.has(shortcut_id)


func build_shortcut(shortcut_id: String) -> void:
	if shortcut_id.is_empty():
		return
	if not is_authority():
		_send_to_host(&"_host_build_shortcut", [shortcut_id])
		return
	_host_build_shortcut(shortcut_id)


@rpc("any_peer", "call_remote", "reliable")
func _host_build_shortcut(shortcut_id: String) -> void:
	if not is_authority() or built_shortcuts.has(shortcut_id):
		return
	var data: Dictionary = get_snapshot()
	var shortcuts: Array = Array(built_shortcuts).duplicate()
	shortcuts.append(shortcut_id)
	data["built_shortcuts"] = shortcuts
	apply_snapshot(data)
	_broadcast_snapshot()
	if SaveManager.instance != null:
		SaveManager.instance.save_game(self)


## Chefes, missões e segredos acontecem só no mundo do host: aceita a chamada local
## (sender 0) ou do próprio host. Compras, entregas e desbloqueios aceitam qualquer peer.
func _is_host_sender(kind: String, id: String) -> bool:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != HOST_PEER_ID:
		push_warning("GameState: %s '%s' reportado pelo peer %d ignorado (só o host)." % [kind, id, sender])
		return false
	return true


# --- Sincronização -------------------------------------------------------------

func get_snapshot() -> Dictionary:
	return {
		"team_money": team_money,
		"current_day": current_day,
		# Array/Dictionary sem tipo: serializam de forma previsível via RPC e JSON.
		"discovered_items": Array(discovered_items),
		"upgrade_levels": upgrade_levels.duplicate(),
		"unlocked_maps": Array(unlocked_maps),
		"defeated_bosses": Array(defeated_bosses),
		"completed_quests": Array(completed_quests),
		"found_secrets": Array(found_secrets),
		"seen_creatures": Array(seen_creatures),
		"intact_items": Array(intact_items),
		"rare_items": Array(rare_items),
		"map_fragments": Array(map_fragments),
		"built_shortcuts": Array(built_shortcuts).duplicate(),
		"game_completed": game_completed,
	}


## Aplica um snapshot localmente e emite todos os sinais de atualização.
## No host, prefira load_snapshot() para que os clientes também recebam.
func apply_snapshot(data: Dictionary) -> void:
	team_money = int(data.get("team_money", team_money))
	current_day = int(data.get("current_day", current_day))
	if data.get("discovered_items") is Array:
		discovered_items = _to_id_list(data["discovered_items"])
	if data.get("unlocked_maps") is Array:
		unlocked_maps = _to_id_list(data["unlocked_maps"])
	if data.get("defeated_bosses") is Array:
		defeated_bosses = _to_id_list(data["defeated_bosses"])
	# Compara com a lista anterior: cada entrada nova vira um sinal, em qualquer peer.
	var new_quests: Array[String] = []
	if data.get("completed_quests") is Array:
		var quests: Array[String] = _to_id_list(data["completed_quests"])
		new_quests = _new_ids(completed_quests, quests)
		completed_quests = quests
	var new_secrets: Array[String] = []
	if data.get("found_secrets") is Array:
		var secrets: Array[String] = _to_id_list(data["found_secrets"])
		new_secrets = _new_ids(found_secrets, secrets)
		found_secrets = secrets
	var new_creatures: Array[String] = []
	if data.get("seen_creatures") is Array:
		var seen: Array[String] = _to_id_list(data["seen_creatures"])
		new_creatures = _new_ids(seen_creatures, seen)
		seen_creatures = seen
	var old_completed: bool = game_completed
	# Derivado dos chefes vencidos (#115): o bool gravado não conta. Um save antigo "concluído"
	# pelo the_sleeper deixa de estar concluído até o colosso cair.
	game_completed = defeated_bosses.has(FINAL_BOSS_ID)
	if data.get("intact_items") is Array:
		intact_items = _to_id_list(data["intact_items"])
	if data.get("rare_items") is Array:
		rare_items = _to_id_list(data["rare_items"])
	var new_fragments: Array[String] = []
	if data.get("map_fragments") is Array:
		var frags: Array[String] = []
		for id: String in _to_id_list(data["map_fragments"]):
			if MAP_FRAGMENTS.has(id):
				frags.append(id)
		new_fragments = _new_ids(map_fragments, frags)
		map_fragments = frags
	var new_shortcuts: Array[String] = []
	if data.get("built_shortcuts") is Array:
		var scs: Array[String] = _to_id_list(data["built_shortcuts"])
		new_shortcuts = _new_ids(built_shortcuts, scs)
		built_shortcuts = scs
	if data.get("upgrade_levels") is Dictionary:
		# JSON devolve números como float e pode conter chaves obsoletas.
		var source: Dictionary = data["upgrade_levels"]
		var levels: Dictionary = {}
		for key: String in UPGRADES.keys():
			levels[key] = clampi(int(source.get(key, 0)), 0, get_upgrade_max_level(key))
		upgrade_levels = levels
	_ensure_upgrade_keys()
	equipped_detector_level = 1 + get_upgrade_level("detector")
	money_changed.emit(team_money)
	collection_updated.emit(discovered_items.size(), get_total_catalog_items())
	upgrades_changed.emit(upgrade_levels.duplicate())
	progression_changed.emit(Array(unlocked_maps), Array(defeated_bosses))
	for quest_id: String in new_quests:
		var quest: Dictionary = QUESTS.get(quest_id, {})
		quest_completed.emit(quest_id, int(quest.get("reward", 0)))
	for secret_id: String in new_secrets:
		secret_found.emit(secret_id)
	for kind: String in new_creatures:
		creature_discovered.emit(kind)
	for fragment_id: String in new_fragments:
		map_fragment_found.emit(fragment_id)
	for shortcut_id: String in new_shortcuts:
		shortcut_built.emit(shortcut_id)
	if game_completed != old_completed:
		game_completed_changed.emit(game_completed)
	state_synced.emit()


## Host: substitui o estado (ex.: carregar save) e propaga para todos.
func load_snapshot(data: Dictionary) -> void:
	if not is_authority():
		push_warning("GameState: load_snapshot ignorado em cliente.")
		return
	# Saves de antes do Mapa do Tesouro: dá os fragmentos de origens já cumpridas.
	data = data.duplicate()
	_add_earned_fragments(data)
	apply_snapshot(data)
	_broadcast_snapshot()


func _broadcast_snapshot() -> void:
	var snapshot: Dictionary = get_snapshot()
	apply_snapshot(snapshot)
	if _is_online():
		_receive_snapshot.rpc(snapshot)


@rpc("authority", "call_remote", "reliable")
func _receive_snapshot(data: Dictionary) -> void:
	apply_snapshot(data)


@rpc("any_peer", "call_remote", "reliable")
func _request_full_state() -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if is_authority() and sender != 0 and sender != multiplayer.get_unique_id():
		_receive_snapshot.rpc_id(sender, get_snapshot())


func _notify_sold(item_id: String, value: int) -> void:
	_receive_sold(item_id, value)
	if _is_online():
		_receive_sold.rpc(item_id, value)


func _notify_donated(item_id: String, reward: int) -> void:
	_receive_donated(item_id, reward)
	if _is_online():
		_receive_donated.rpc(item_id, reward)


@rpc("authority", "call_remote", "reliable")
func _receive_sold(item_id: String, value: int) -> void:
	item_sold.emit(get_item_display_name(item_id), value)


@rpc("authority", "call_remote", "reliable")
func _receive_game_victory() -> void:
	game_victory.emit()


@rpc("authority", "call_remote", "reliable")
func _receive_donated(item_id: String, reward: int) -> void:
	item_donated.emit(get_item_display_name(item_id), reward)


@rpc("authority", "call_remote", "reliable")
func _receive_purchase_result(upgrade_id: String, success: bool, message: String) -> void:
	purchase_result.emit(upgrade_id, success, message)


@rpc("authority", "call_remote", "reliable")
func _receive_item_purchase_result(item_id: String, success: bool, message: String) -> void:
	item_purchase_result.emit(item_id, success, message)


@rpc("authority", "call_remote", "reliable")
func _receive_map_unlock_result(map_id: String, success: bool, message: String) -> void:
	map_unlock_result.emit(map_id, success, message)


func _on_peer_connected(peer_id: int) -> void:
	# Sincronização completa para quem entra.
	if is_authority() and _is_online():
		_receive_snapshot.rpc_id(peer_id, get_snapshot())


func _on_connected_to_server() -> void:
	# Redundância caso o snapshot do host chegue antes de o nó estar pronto.
	if not is_authority():
		_request_full_state.rpc_id(HOST_PEER_ID)


# --- Utilitários ----------------------------------------------------------------

## Host: avança para o próximo dia e propaga o snapshot para todos.
func advance_day() -> void:
	if not is_authority():
		push_warning("GameState: advance_day ignorado em cliente.")
		return
	current_day += 1
	_broadcast_snapshot()


func reset_state() -> void:
	if not is_authority():
		return
	team_money = 100
	current_day = 1
	discovered_items.clear()
	upgrade_levels.clear()
	unlocked_maps.clear()
	defeated_bosses.clear()
	completed_quests.clear()
	found_secrets.clear()
	seen_creatures.clear()
	intact_items.clear()
	rare_items.clear()
	map_fragments.clear()
	built_shortcuts.clear()
	game_completed = false
	_broadcast_snapshot()


func _is_online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _ensure_upgrade_keys() -> void:
	for key: String in UPGRADES.keys():
		if not upgrade_levels.has(key):
			upgrade_levels[key] = 0


## Só aceita nomes simples: impede que um cliente carregue arquivos fora das pastas do catálogo.
func _is_safe_resource_id(resource_id: String) -> bool:
	if resource_id.is_empty() or not resource_id.is_valid_filename():
		return false
	return not (resource_id.contains("/") or resource_id.contains("\\") or resource_id.contains(".."))


## Confere a tabela UPGRADES: um custo e um mapa exigido por nível, e mapas existentes.
func _validate_upgrades() -> void:
	for upgrade_id: String in UPGRADES.keys():
		var entry: Dictionary = UPGRADES[upgrade_id]
		var costs: Array = entry["costs"]
		var required_maps: Array = entry["required_maps"]
		var max_level: int = int(entry["max_level"])
		if costs.size() != max_level or required_maps.size() != max_level:
			push_error("GameState: UPGRADES['%s'] tem %d custos, %d required_maps e max_level %d." % [upgrade_id, costs.size(), required_maps.size(), max_level])
		for map_id: Variant in required_maps:
			if not str(map_id).is_empty() and _load_map(str(map_id)) == null:
				push_error("GameState: UPGRADES['%s'] exige o mapa '%s', que não existe em %s." % [upgrade_id, map_id, MAPS_DIR])


func _load_map(map_id: String) -> MapData:
	if not _is_safe_resource_id(map_id):
		return null
	var map_path: String = "%s/%s.tres" % [MAPS_DIR, map_id]
	if not ResourceLoader.exists(map_path):
		return null
	var map_data: MapData = load(map_path) as MapData
	if map_data == null or map_data.id != map_id:
		return null
	return map_data


## Converte uma lista do snapshot/JSON em ids únicos e não vazios.
func _to_id_list(source: Array) -> Array[String]:
	var ids: Array[String] = []
	for value: Variant in source:
		var id: String = str(value)
		if not id.is_empty() and not ids.has(id):
			ids.append(id)
	return ids


## Ids de `current` que não estavam em `previous`, na ordem de `current`.
func _new_ids(previous: Array[String], current: Array[String]) -> Array[String]:
	var added: Array[String] = []
	for id: String in current:
		if not previous.has(id):
			added.append(id)
	return added


func _load_item(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null
	var catalog_path: String = "res://items/catalog/%s.tres" % item_id
	if not ResourceLoader.exists(catalog_path):
		return null
	return ResourceLoader.load(catalog_path) as ItemData


func _count_catalog_items() -> int:
	var dir: DirAccess = DirAccess.open("res://items/catalog")
	if dir == null:
		return 0

	var count: int = 0
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir():
			var clean_name: String = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres"):
				count += 1
		file_name = dir.get_next()
	return count
