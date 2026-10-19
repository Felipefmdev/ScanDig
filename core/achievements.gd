class_name Achievements
extends Node

## Conquistas e estatísticas da campanha (#141), orientadas a dados: a lista fica em DATA_PATH
## (JSON versionado; o _doc dele explica cada campo) e muda sem mexer em código. Os ids são
## snake_case estáveis, para mapear nas conquistas da Steam depois.
## Quem decide é o host: o GameState chama award(data) no snapshot antes de aplicar/propagar, e as
## conquistas e estatísticas (GameState.achievements/stats) chegam aos clientes pelo snapshot de
## sempre (sem RPC novo). As funções de consulta são estáticas (UI e testes).
## A instância (autoload CoreAchievements) conta, no host, o que nasce fora do GameState: pazadas e
## peças desenterradas (sinais do BuriedSpot), dano no jogador do host e o fim de cada expedição.

const DATA_PATH: String = "res://core/data/achievements.json"
## Chefe "final" nos dados = GameState.FINAL_BOSS_ID (não depende de qual mapa tem o chefe final).
const FINAL_BOSS: String = "final"
const TYPES: Array[String] = ["stat", "museum", "count", "all", "boss"]
## Estatísticas acumuladas (GameState.stats), na ordem da tela de vitória.
const STAT_KEYS: Array[String] = ["expeditions", "night_expeditions", "flawless_expeditions", "items_found",
	"items_sold", "items_donated", "money_earned", "creatures_defeated", "digs", "dig_depth_cm"]
## Listas do GameState aceitas em "count"/"all".
const LISTS: Array[String] = ["discovered_items", "unlocked_maps", "defeated_bosses", "completed_quests",
	"found_secrets", "seen_creatures", "intact_items", "rare_items", "map_fragments", "built_shortcuts"]

static var instance: Achievements = null
static var _defs: Array[Dictionary] = []
static var _loaded: bool = false

## Expedição em andamento (host): o jogador do host levou dano / peças desenterradas nela.
var _expedition_hurt: bool = false
var _expedition_finds: int = 0
## Última vida vista de cada jogador local (id do nó -> vida), para saber se o sinal foi dano.
var _last_health: Dictionary = {}


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	var session: SessionManager = get_node_or_null(^"/root/CoreSession") as SessionManager
	if session != null:
		session.expedition_started.connect(_on_expedition_started)


# --- Dados ------------------------------------------------------------------------

## Conquistas válidas de DATA_PATH, na ordem do arquivo (cache; entradas inválidas ficam de fora
## com push_error).
static func definitions() -> Array[Dictionary]:
	if not _loaded:
		_defs = parse_definitions(FileAccess.get_file_as_string(DATA_PATH))
		_loaded = true
	return _defs


## Lê o JSON de conquistas. Só testes passam texto próprio.
static func parse_definitions(text: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("achievements") is Array):
		push_error("CoreAchievements: %s inválido (falta a lista 'achievements')." % DATA_PATH)
		return out
	var seen: Array[String] = []
	for entry: Variant in parsed["achievements"]:
		var problem: String = _check_entry(entry, seen)
		if not problem.is_empty():
			push_error(problem)
			continue
		var def: Dictionary = entry
		seen.append(str(def["id"]))
		out.append(def)
	return out


static func _check_entry(entry: Variant, seen: Array[String]) -> String:
	if not (entry is Dictionary):
		return "CoreAchievements: entrada que não é objeto: %s" % str(entry)
	var def: Dictionary = entry
	var id: String = str(def.get("id", ""))
	if not is_valid_id(id):
		return "CoreAchievements: id '%s' não é snake_case." % id
	if seen.has(id):
		return "CoreAchievements: id '%s' repetido." % id
	for key: String in ["name", "desc", "icon"]:
		if not (def.get(key) is String) or str(def[key]).is_empty():
			return "CoreAchievements: '%s' sem '%s'." % [id, key]
	var type: String = str(def.get("type", ""))
	if not TYPES.has(type):
		return "CoreAchievements: '%s' com type desconhecido '%s'." % [id, type]
	match type:
		"stat":
			if not STAT_KEYS.has(str(def.get("stat", ""))):
				return "CoreAchievements: '%s' com stat desconhecida '%s'." % [id, def.get("stat", "")]
		"count", "all":
			if not LISTS.has(str(def.get("list", ""))):
				return "CoreAchievements: '%s' com list desconhecida '%s'." % [id, def.get("list", "")]
		"boss":
			var boss: String = str(def.get("boss", ""))
			if boss != FINAL_BOSS and not GameState.all_boss_ids().has(boss):
				return "CoreAchievements: '%s' com chefe desconhecido '%s'." % [id, boss]
	if type in ["stat", "museum", "count"] and not (def.get("target") is float and float(def["target"]) >= 1.0):
		return "CoreAchievements: '%s' sem target >= 1." % id
	return ""


## snake_case: minúsculas, dígitos e "_", começando por letra.
static func is_valid_id(id: String) -> bool:
	var regex: RegEx = RegEx.create_from_string("^[a-z][a-z0-9_]*$")
	return regex.search(id) != null


static func ids() -> Array[String]:
	var out: Array[String] = []
	for def: Dictionary in definitions():
		out.append(str(def["id"]))
	return out


static func get_definition(id: String) -> Dictionary:
	for def: Dictionary in definitions():
		if def["id"] == id:
			return def
	return {}


# --- Avaliação (dados no formato do GameState.get_snapshot) -----------------------

## (atual, alvo) para a barra de progresso; atual já limitado ao alvo.
static func progress(def: Dictionary, data: Dictionary) -> Vector2i:
	var current: int = 0
	var target: int = 1
	match str(def.get("type", "")):
		"stat":
			current = stat_of(data, str(def["stat"]))
			target = int(def["target"])
		"museum":
			var total: int = _catalog_total()
			target = maxi(ceili(float(total) * float(def["target"]) / 100.0), 1)
			current = _list(data, "discovered_items").size()
		"count":
			current = _list(data, str(def["list"])).size()
			target = int(def["target"])
		"all":
			var all_ids: Array[String] = all_ids_of(str(def["list"]))
			var have: Array = _list(data, str(def["list"]))
			target = maxi(all_ids.size(), 1)
			for id: String in all_ids:
				if have.has(id):
					current += 1
		"boss":
			var boss: String = str(def["boss"])
			if boss == FINAL_BOSS:
				boss = GameState.FINAL_BOSS_ID
			current = 1 if _list(data, "defeated_bosses").has(boss) else 0
	return Vector2i(mini(current, target), target)


static func is_met(def: Dictionary, data: Dictionary) -> bool:
	var p: Vector2i = progress(def, data)
	return p.x >= p.y


## Ids que `data` já cumpre mas ainda não estão em data["achievements"], na ordem do arquivo.
static func newly_met(data: Dictionary) -> Array[String]:
	var have: Array = _list(data, "achievements")
	var out: Array[String] = []
	for def: Dictionary in definitions():
		if not have.has(def["id"]) and is_met(def, data):
			out.append(str(def["id"]))
	return out


## Host: junta a data["achievements"] as conquistas cumpridas. Devolve as novas.
static func award(data: Dictionary) -> Array[String]:
	var added: Array[String] = newly_met(data)
	if not added.is_empty():
		var list: Array = Array(_list(data, "achievements")).duplicate()
		list.append_array(added)
		data["achievements"] = list
	return added


## Todos os ids possíveis de uma lista "all" (chefes, segredos, criaturas, missões, fragmentos,
## mapas pagos). Lista sem "todos" definidos devolve [].
static func all_ids_of(list_name: String) -> Array[String]:
	var out: Array[String] = []
	match list_name:
		"defeated_bosses":
			out = GameState.all_boss_ids()
		"found_secrets":
			out = GameState.SECRETS.duplicate()
		"seen_creatures":
			for kind: String in GameState.CREATURES.keys():
				out.append(kind)
		"completed_quests":
			for quest: String in GameState.QUESTS.keys():
				out.append(quest)
		"map_fragments":
			out = GameState.MAP_FRAGMENT_IDS.duplicate()
		"unlocked_maps":
			out = paid_map_ids()
	return out


## Mapas que se compram (unlock_cost > 0, sem os que abrem pelo Mapa do Tesouro), na ordem do jogo.
static func paid_map_ids() -> Array[String]:
	var out: Array[String] = []
	for map_id: String in SessionManager.MAP_ORDER:
		var path: String = "%s/%s.tres" % [GameState.MAPS_DIR, map_id]
		if not ResourceLoader.exists(path):
			continue
		var map_data: MapData = load(path) as MapData
		if map_data != null and map_data.unlock_cost > 0 and not map_data.requires_map_fragments:
			out.append(map_id)
	return out


static func stat_of(data: Dictionary, key: String) -> int:
	var stats: Variant = data.get("stats", {})
	return int((stats as Dictionary).get(key, 0)) if stats is Dictionary else 0


## Número do progresso como o jogador vê ("scale" do JSON, ex.: cm -> m).
static func shown_value(def: Dictionary, value: int) -> int:
	return int(floor(float(value) * float(def.get("scale", 1.0)) + 0.0001))


static func _list(data: Dictionary, key: String) -> Array:
	var value: Variant = data.get(key, [])
	return value as Array if value is Array else []


static func _catalog_total() -> int:
	return GameState.instance.get_total_catalog_items() if GameState.instance != null else 0


# --- Contadores do host -----------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is BuriedSpot:
		var spot: BuriedSpot = node
		if not spot.spot_dug.is_connected(_on_spot_dug):
			spot.spot_dug.connect(_on_spot_dug)
			spot.item_revealed.connect(_on_item_revealed)
	elif node is Player:
		var player: Player = node
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed.bind(player))


func _is_host() -> bool:
	return GameState.instance != null and GameState.instance.is_authority()


## Uma pazada (o dig() corre no host para os buracos em rede; offline, sempre).
func _on_spot_dug(_dirt_left: int, _integrity: float) -> void:
	if _is_host():
		GameState.instance.add_stats({"digs": 1})


func _on_item_revealed(item: ItemData, _final_value: int, _integrity: float) -> void:
	if item == null or not _is_host():
		return
	_expedition_finds += 1
	GameState.instance.add_stats({"items_found": 1, "dig_depth_cm": maxi(item.depth_cm, 0)})


## Só a vida do jogador do host: a de um convidado fica no peer dele (sem RPC novo para isso).
func _on_player_health_changed(current: float, _max_value: float, player: Player) -> void:
	if not is_instance_valid(player) or not player.is_local() or not _is_host():
		return
	var key: int = player.get_instance_id()
	if current < float(_last_health.get(key, current)):
		_expedition_hurt = true
	_last_health[key] = current


func _on_expedition_started(_map_id: String) -> void:
	_expedition_hurt = false
	_expedition_finds = 0
	_last_health.clear()


## Host, no fim da expedição (SessionManager.request_end_expedition, antes de avançar o dia e de
## gravar): conta a expedição, a noturna e a sem dano (com pelo menos uma peça).
func record_expedition_end(night: bool) -> void:
	if not _is_host():
		return
	var delta: Dictionary = {"expeditions": 1}
	if night:
		delta["night_expeditions"] = 1
	if not _expedition_hurt and _expedition_finds > 0:
		delta["flawless_expeditions"] = 1
	GameState.instance.add_stats(delta)
	_expedition_hurt = false
	_expedition_finds = 0
