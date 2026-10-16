extends Node
## Ponte de automação para agentes: executa um roteiro JSON (input, capturas,
## dumps de estado). Só ativa em builds de debug com o user arg --bot=<roteiro.json>;
## sem isso não faz nada (zero efeito no jogo normal).

const ACTIONS: PackedStringArray = [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "interact", "use_tool", "careful_dig", "attack",
]
const STEP_KEYS: PackedStringArray = [
	"press", "tap", "look", "screenshot", "dump", "teleport", "look_at", "goto_spot", "wait_until", "quit",
	"loop", "dig_spot", "pickup", "goto_sell", "sell", "set_state", "explore", "fight",
	"host", "join", "start_expedition", "sleep", "face_player", "goto_player",
	"interact", "call",
]
## Campos que set_state pode alterar (fundidos no snapshot do CoreGameState).
const SET_STATE_KEYS: PackedStringArray = ["team_money", "upgrade_levels", "unlocked_maps", "defeated_bosses"]
## Passos sem 't' obrigatório (dentro de um loop o tempo absoluto não faz sentido).
const UNTIMED_KINDS: PackedStringArray = ["wait_until", "loop", "sleep"]
const CONDITION_VARS: PackedStringArray = [
	"money", "inventory", "enemies", "spots", "time", "health",
	"nearest_spot", "free_slots", "deliverable", "sell_dist", "pickup_dist", "enemy_dist", "players",
	"wave_round", "wave_phase", "wave_left", "bosses",
]
## Variáveis com prefixo (#39): flag_<bandeira do WorldFlags> (1/0) e quest_<nome do NPC>
## (estado da missão 0..4: OFFER, ACTIVE, READY, EVENT, DONE).
const CONDITION_PREFIXES: PackedStringArray = ["flag_", "quest_"]
## Métodos que o passo "call" pode chamar (atalhos de debug para testar segredos e eventos).
const DEBUG_CALL_METHODS: PackedStringArray = ["force_low_tide", "wake_immediately", "start", "trigger"]
const DIG_MODES: PackedStringArray = ["fast", "careful", "smart"]
## Distância "infinita" usada pelas variáveis nearest_spot/sell_dist quando não há alvo.
const NO_TARGET_DISTANCE: float = 9999.0
## Caminhar: progresso mínimo em STUCK_SECONDS antes do teleport de recurso.
const STUCK_SECONDS: float = 5.0
const STUCK_MIN_PROGRESS: float = 1.0
const WALK_PITCH_DEG: float = -12.0
const SELL_POINT_GROUP: StringName = &"sell_points"
const PICKUP_GROUP: StringName = &"pickups"
const CONDITION_OPS: PackedStringArray = [">=", "<=", "==", "!=", ">", "<"]
const TAP_SECONDS: float = 0.1
const DEFAULT_WAIT_TIMEOUT: float = 60.0
## Só o jogador local (Player.LOCAL_GROUP); todos os jogadores estão em PLAYERS_GROUP.
const PLAYER_GROUP: StringName = &"player"
const PLAYERS_GROUP: StringName = &"players"
## Porta por omissão dos passos host/join (a do CoreNetwork é 7777).
const DEFAULT_NET_PORT: int = 7777
const ENEMY_GROUP: StringName = &"enemies"
const SPOT_GROUP: StringName = &"buried_spots"
## Distância a que goto_spot deixa o jogador do spot (dig_range do jogador = 1.8).
const GOTO_SPOT_DISTANCE: float = 1.0

var _run_dir: String = ""
var _log_file: FileAccess = null
var _start_msec: int = 0
var _executed: int = 0
var _errors: PackedStringArray = []
var _screenshots: PackedStringArray = []
var _dumps: PackedStringArray = []
var _waits: Array[Dictionary] = []
var _loops: Array[Dictionary] = []
var _dump_every: float = 0.0
var _screenshot_every: float = 0.0
var _next_dump: float = 0.0
var _next_screenshot: float = 0.0
var _monitoring: bool = false
## Métricas de jogo recolhidas por observação (nunca alteram o estado).
var _m: Dictionary = {
	"start_money": 0,
	"first_enemy_time": -1.0,
	"damage_taken": 0.0,
	"deaths": 0,
	"teleport_fallbacks": 0,
	"items_sold": 0,
	"sold_value": 0,
	"sell_trips": 0,
	"spots_dug": 0,
	"items_picked": 0,
	"step_failures": 0,
	"explore_steps": 0,
	"fight_swings": 0,
	"max_threat_level": 0,
	"threat_level_times": [],
}
var _last_health: float = -1.0
var _watched_player: Node = null


func _ready() -> void:
	var script_path: String = _bot_arg()
	if not OS.is_debug_build() or script_path.is_empty():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred(script_path)


## Lê --bot=<caminho> dos user args (depois de "--" na linha de comandos).
static func _bot_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bot="):
			return arg.substr(6)
	return ""


# --- Parser (estático, testado em tests/unit/test_debug_bridge.gd) -------------

## Valida um roteiro já descodificado. Devolve {ok, scene, steps, errors}.
static func parse_script(data: Variant) -> Dictionary:
	var errors: PackedStringArray = []
	var steps: Array[Dictionary] = []
	var scene_path: String = ""
	if not data is Dictionary:
		errors.append("roteiro deve ser um objeto JSON")
		return {"ok": false, "scene": "", "steps": steps, "errors": errors}
	var root: Dictionary = data
	if root.has("scene"):
		if root["scene"] is String and (root["scene"] as String).begins_with("res://"):
			scene_path = root["scene"]
		else:
			errors.append("'scene' deve ser um caminho res://")
	if not root.get("steps") is Array:
		errors.append("'steps' deve ser uma lista")
		return {"ok": false, "scene": scene_path, "steps": steps, "errors": errors}
	var raw_steps: Array = root["steps"]
	for i: int in raw_steps.size():
		var result: Variant = parse_step(raw_steps[i])
		if result is String:
			errors.append("passo %d: %s" % [i, result])
		else:
			steps.append(result)
	var periodic: Dictionary = {}
	for key: String in ["dump_every", "screenshot_every"]:
		if not root.has(key):
			continue
		if not _is_number(root[key]) or float(root[key]) <= 0.0:
			errors.append("'%s' deve ser > 0 (segundos)" % key)
		else:
			periodic[key] = float(root[key])
	return {"ok": errors.is_empty(), "scene": scene_path, "steps": steps, "errors": errors, "periodic": periodic}


## Normaliza um passo. Devolve o Dictionary normalizado ou uma String de erro.
## `nested` = dentro de um loop: 't' é opcional.
static func parse_step(raw: Variant, nested: bool = false) -> Variant:
	if not raw is Dictionary:
		return "passo deve ser um objeto"
	var d: Dictionary = raw
	var kinds: Array[String] = []
	for key: String in STEP_KEYS:
		if d.has(key):
			kinds.append(key)
	if kinds.size() != 1:
		return "precisa de exatamente uma acao (%s)" % ", ".join(STEP_KEYS)
	var kind: String = kinds[0]
	var t: float = 0.0
	if d.has("t"):
		if not _is_number(d["t"]) or float(d["t"]) < 0.0:
			return "'t' deve ser um numero >= 0"
		t = float(d["t"])
	elif not nested and not UNTIMED_KINDS.has(kind):
		return "falta 't'"
	var step: Dictionary = {"kind": kind, "t": t}
	if d.has("if"):
		var conds: Variant = parse_conditions(d["if"])
		if conds == null:
			return "'if' invalido '%s'" % str(d["if"])
		step["if"] = conds
	var timeout_default: float = DEFAULT_WAIT_TIMEOUT
	if kind in ["dig_spot", "pickup", "goto_sell", "goto_spot", "explore", "fight", "interact"]:
		timeout_default = 30.0
	if d.has("timeout"):
		if not _is_number(d["timeout"]) or float(d["timeout"]) <= 0.0:
			return "'timeout' deve ser > 0"
	var timeout: float = float(d.get("timeout", timeout_default))
	var value: Variant = d[kind]
	match kind:
		"press", "tap":
			if not value is String or not ACTIONS.has(value):
				return "acao desconhecida '%s'" % str(value)
			step["action"] = value
			var hold: float = TAP_SECONDS
			if kind == "press":
				if not _is_number(d.get("for")) or float(d["for"]) <= 0.0:
					return "'press' precisa de 'for' > 0"
				hold = float(d["for"])
			step["for"] = hold
		"look":
			var v: Variant = _number_array(value, 2)
			if v == null:
				return "'look' deve ser [dx, dy]"
			step["delta"] = Vector2(v[0], v[1])
		"teleport":
			var v: Variant = _number_array(value, 3)
			if v == null:
				return "'teleport' deve ser [x, y, z]"
			step["position"] = Vector3(v[0], v[1], v[2])
		"screenshot", "dump":
			if not value is String or not (value as String).is_valid_filename() or (value as String).is_empty():
				return "'%s' precisa de um nome de ficheiro valido" % kind
			step["label"] = value
		"wait_until":
			if not value is String:
				return "'wait_until' deve ser uma string"
			var cond: Variant = parse_condition(value)
			if cond == null:
				return "condicao invalida '%s'" % value
			step["condition"] = cond
			step["timeout"] = timeout
		"look_at":
			var v: Variant = _number_array(value, 3)
			if v == null:
				return "'look_at' deve ser [x, y, z]"
			step["target"] = Vector3(v[0], v[1], v[2])
		"goto_spot":
			if value != "nearest":
				return "'goto_spot' so aceita \"nearest\""
			step["walk"] = d.get("walk", false) == true
			# radius: só considera spots a esta distância (ex.: alcance do radar); 0 = todos.
			var sense: Variant = d.get("radius", 0.0)
			if not _is_number(sense) or float(sense) < 0.0:
				return "'radius' deve ser >= 0"
			step["radius"] = float(sense)
			step["timeout"] = timeout
		"fight":
			if not _is_number(value) or float(value) <= 0.0:
				return "'fight' deve ser a duracao (s) > 0"
			step["for"] = float(value)
			var fr: Variant = d.get("radius", 12.0)
			if not _is_number(fr) or float(fr) <= 0.0:
				return "'radius' deve ser > 0"
			step["radius"] = float(fr)
		"explore":
			if not _is_number(value) or float(value) <= 0.0:
				return "'explore' deve ser a distancia (m) > 0"
			step["distance"] = float(value)
			step["bounds"] = Rect2()
			if d.has("bounds"):
				var b: Variant = _number_array(d["bounds"], 4)
				if b == null or b[2] <= b[0] or b[3] <= b[1]:
					return "'bounds' deve ser [min_x, min_z, max_x, max_z]"
				step["bounds"] = Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
			var stop_near: Variant = d.get("stop_near_spot", 0.0)
			if not _is_number(stop_near) or float(stop_near) < 0.0:
				return "'stop_near_spot' deve ser >= 0"
			step["stop_near_spot"] = float(stop_near)
			step["timeout"] = timeout
		"loop":
			if not value is Array or (value as Array).is_empty():
				return "'loop' deve ser uma lista de passos nao vazia"
			var body: Array[Dictionary] = []
			for i: int in (value as Array).size():
				var sub: Variant = parse_step((value as Array)[i], true)
				if sub is String:
					return "loop[%d]: %s" % [i, sub]
				if (sub as Dictionary)["kind"] in ["loop", "quit"]:
					return "loop[%d]: '%s' nao e permitido dentro de um loop" % [i, (sub as Dictionary)["kind"]]
				body.append(sub)
			step["body"] = body
			if not d.has("until"):
				return "'loop' precisa de 'until'"
			var until: Variant = parse_condition(str(d["until"]))
			if until == null:
				return "condicao invalida '%s'" % str(d["until"])
			step["until"] = until
			if not d.has("timeout"):
				return "'loop' precisa de 'timeout'"
			step["timeout"] = timeout
		"dig_spot":
			if value != true:
				return "'dig_spot' deve ser true"
			var mode: Variant = d.get("mode", "fast")
			if not mode is String or not DIG_MODES.has(mode):
				return "'mode' deve ser um de %s" % ", ".join(DIG_MODES)
			step["mode"] = mode
			step["timeout"] = timeout
		"pickup":
			if value != true:
				return "'pickup' deve ser true"
			var radius: Variant = d.get("radius", 6.0)
			if not _is_number(radius) or float(radius) <= 0.0:
				return "'radius' deve ser > 0"
			step["radius"] = float(radius)
			step["timeout"] = timeout
		"goto_sell", "sell", "quit":
			if value != true:
				return "'%s' deve ser true" % kind
			step["timeout"] = timeout
		"set_state":
			if not value is Dictionary or (value as Dictionary).is_empty():
				return "'set_state' deve ser um objeto nao vazio"
			for key: Variant in value:
				if not SET_STATE_KEYS.has(str(key)):
					return "'set_state' nao aceita '%s' (%s)" % [key, ", ".join(SET_STATE_KEYS)]
			var st: Dictionary = value
			if st.has("team_money") and not _is_number(st["team_money"]):
				return "'team_money' deve ser um numero"
			if st.has("upgrade_levels") and not st["upgrade_levels"] is Dictionary:
				return "'upgrade_levels' deve ser um objeto"
			for key: String in ["unlocked_maps", "defeated_bosses"]:
				if st.has(key) and not st[key] is Array:
					return "'%s' deve ser uma lista" % key
			step["state"] = st
		"host":
			var port: Variant = DEFAULT_NET_PORT if value is bool and value == true else value
			if not port is int and not (port is float and is_equal_approx(port, roundf(port))):
				return "'host' deve ser true ou uma porta"
			if int(port) < 1024 or int(port) > 65535:
				return "porta invalida %s" % str(port)
			step["port"] = int(port)
		"join":
			if not value is String or (value as String).is_empty():
				return "'join' deve ser o IP do host"
			var jport: Variant = d.get("port", DEFAULT_NET_PORT)
			if not _is_number(jport) or int(jport) < 1024 or int(jport) > 65535:
				return "'port' invalida"
			step["ip"] = value
			step["port"] = int(jport)
			step["timeout"] = timeout
		"start_expedition":
			if not value is String or not (value as String).is_valid_filename() or (value as String).is_empty():
				return "'start_expedition' deve ser o id do mapa"
			step["map_id"] = value
			step["timeout"] = timeout
		"sleep":
			if not _is_number(value) or float(value) < 0.0:
				return "'sleep' deve ser um numero >= 0"
			step["seconds"] = float(value)
		"face_player", "goto_player":
			if not value is String or value != "remote":
				return "'%s' so aceita \"remote\"" % kind
		"interact":
			if not value is String or (value as String).is_empty():
				return "'interact' deve ser o nome do no Interactable"
			step["target"] = value
			step["walk"] = d.get("walk", false) == true
			step["timeout"] = timeout
		"call":
			if not value is String or (value as String).is_empty():
				return "'call' deve ser o nome do no"
			var method: Variant = d.get("method", "")
			if not method is String or not DEBUG_CALL_METHODS.has(method):
				return "'method' deve ser um de %s" % ", ".join(DEBUG_CALL_METHODS)
			step["target"] = value
			step["method"] = method
	return step


## "if": uma condição ou lista de condições (todas têm de ser verdadeiras).
static func parse_conditions(v: Variant) -> Variant:
	var texts: Array = []
	if v is String:
		texts.append(v)
	elif v is Array:
		texts = v
	if texts.is_empty():
		return null
	var out: Array[Dictionary] = []
	for text: Variant in texts:
		if not text is String:
			return null
		var c: Variant = parse_condition(text)
		if c == null:
			return null
		out.append(c)
	return out


## "money>=300" -> {var, op, value}; null se inválida.
static func parse_condition(text: String) -> Variant:
	var s: String = text.replace(" ", "")
	for op: String in CONDITION_OPS:
		var idx: int = s.find(op)
		if idx <= 0:
			continue
		var var_name: String = s.substr(0, idx)
		var rhs: String = s.substr(idx + op.length())
		if not (CONDITION_VARS.has(var_name) or _has_condition_prefix(var_name)) or not rhs.is_valid_float():
			return null
		return {"var": var_name, "op": op, "value": rhs.to_float()}
	return null


static func _has_condition_prefix(var_name: String) -> bool:
	for prefix: String in CONDITION_PREFIXES:
		if var_name.begins_with(prefix) and var_name.length() > prefix.length():
			return true
	return false


static func compare(lhs: float, op: String, rhs: float) -> bool:
	match op:
		">=": return lhs >= rhs
		"<=": return lhs <= rhs
		"==": return is_equal_approx(lhs, rhs)
		"!=": return not is_equal_approx(lhs, rhs)
		">": return lhs > rhs
		"<": return lhs < rhs
	return false


static func _is_number(v: Variant) -> bool:
	return v is int or v is float


static func _number_array(v: Variant, count: int) -> Variant:
	if not v is Array or (v as Array).size() != count:
		return null
	var out: Array[float] = []
	for x: Variant in v:
		if not _is_number(x):
			return null
		out.append(float(x))
	return out


# --- Execução ------------------------------------------------------------------

func _run(script_path: String) -> void:
	var text: String = FileAccess.get_file_as_string(script_path)
	var parsed: Dictionary = parse_script(JSON.parse_string(text) if not text.is_empty() else null)
	_open_run_dir(script_path)
	_log("roteiro: %s" % script_path)
	if not parsed["ok"]:
		for e: String in parsed["errors"]:
			_error(e)
		_finish(1)
		return
	var scene_path: String = parsed["scene"]
	var current: Node = get_tree().current_scene
	if not scene_path.is_empty() and (current == null or current.scene_file_path != scene_path):
		_log("a carregar cena %s" % scene_path)
		if get_tree().change_scene_to_file(scene_path) != OK:
			_error("nao foi possivel carregar %s" % scene_path)
			_finish(1)
			return
		await get_tree().process_frame
		await get_tree().process_frame
	_start_msec = Time.get_ticks_msec()
	var periodic: Dictionary = parsed["periodic"]
	_dump_every = periodic.get("dump_every", 0.0)
	_screenshot_every = periodic.get("screenshot_every", 0.0)
	_next_dump = _dump_every
	_next_screenshot = _screenshot_every
	_start_monitoring()
	for step: Dictionary in parsed["steps"]:
		await _wait_until_time(step["t"])
		if not _conditions_met(step.get("if", [])):
			continue
		await _execute(step)
		_executed += 1
		if step["kind"] == "quit":
			break
	_finish(0)


# --- Monitorização (só observa) ------------------------------------------------

func _start_monitoring() -> void:
	_monitoring = true
	_m["start_money"] = int(_condition_value("money"))
	for n: Node in get_tree().get_nodes_in_group(SELL_POINT_GROUP):
		if n is SellPoint:
			(n as SellPoint).items_delivered.connect(_on_items_delivered)


func _process(_delta: float) -> void:
	if not _monitoring:
		return
	var now: float = _elapsed()
	var player: Node = _player()
	if player != _watched_player and player != null:
		_watched_player = player
		if player.has_signal(&"died"):
			player.connect(&"died", _on_player_died)
		_last_health = float(player.get("health")) if "health" in player else -1.0
	if player != null and "health" in player:
		var hp: float = float(player.get("health"))
		if _last_health >= 0.0 and hp < _last_health:
			_m["damage_taken"] = float(_m["damage_taken"]) + (_last_health - hp)
		_last_health = hp
	var meter: DisturbanceMeter = DisturbanceMeter.instance
	if meter != null and meter.current_level > int(_m["max_threat_level"]):
		_m["max_threat_level"] = meter.current_level
		(_m["threat_level_times"] as Array).append(snappedf(now, 0.1))
		_log("t=%.1f ameaca do subsolo chegou ao nivel %d" % [now, meter.current_level])
	if float(_m["first_enemy_time"]) < 0.0 and _alive_enemy_count() > 0:
		_m["first_enemy_time"] = now
		_log("t=%.1f primeiro inimigo apareceu" % now)
	if _dump_every > 0.0 and now >= _next_dump:
		_dump("periodic_%04ds" % int(_next_dump))
		_next_dump += _dump_every
	if _screenshot_every > 0.0 and now >= _next_screenshot:
		_screenshot("periodic_%04ds" % int(_next_screenshot))
		_next_screenshot += _screenshot_every


func _on_player_died() -> void:
	_m["deaths"] = int(_m["deaths"]) + 1
	# A morte repõe a vida: não contar o "dano" do respawn ao contrário.
	_last_health = -1.0
	_log("t=%.1f jogador morreu (mortes: %d)" % [_elapsed(), _m["deaths"]])


func _on_items_delivered(count: int, total_value: int) -> void:
	_m["items_sold"] = int(_m["items_sold"]) + count
	_m["sold_value"] = int(_m["sold_value"]) + total_value
	_m["sell_trips"] = int(_m["sell_trips"]) + 1
	_log("t=%.1f entregue: %d itens, %s" % [_elapsed(), count, MoneyFormat.money(total_value)])


func _alive_enemy_count() -> int:
	var n: int = 0
	for e: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if not is_instance_valid(e):
			continue
		if e is EnemyBase and not (e as EnemyBase).is_alive():
			continue
		n += 1
	return n


func _conditions_met(conds: Array) -> bool:
	for c: Dictionary in conds:
		if not compare(_condition_value(c["var"]), c["op"], c["value"]):
			return false
	return true


func _fail(msg: String) -> void:
	_m["step_failures"] = int(_m["step_failures"]) + 1
	_log("  aviso: " + msg)


func _elapsed() -> float:
	return (Time.get_ticks_msec() - _start_msec) / 1000.0


func _wait_until_time(t: float) -> void:
	while _elapsed() < t:
		await get_tree().process_frame


func _execute(step: Dictionary) -> void:
	var kind: String = step["kind"]
	_log("t=%.2f %s %s" % [_elapsed(), kind, _describe(step)])
	match kind:
		"press", "tap":
			_hold_action(step["action"], step["for"])
		"look":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			var ev: InputEventMouseMotion = InputEventMouseMotion.new()
			ev.relative = step["delta"]
			Input.parse_input_event(ev)
		"teleport":
			var player: Node3D = _player()
			if player == null:
				_error("teleport: jogador nao encontrado")
			else:
				player.global_position = step["position"]
				if player is CharacterBody3D:
					(player as CharacterBody3D).velocity = Vector3.ZERO
		"look_at":
			_look_at(step["target"])
		"goto_spot":
			if step["walk"]:
				await _walk_to_nearest_spot(step["timeout"], step["radius"])
			else:
				_goto_nearest_spot()
		"loop":
			await _run_loop(step)
		"dig_spot":
			await _dig_spot(step["mode"], step["timeout"])
		"pickup":
			await _pickup(step["radius"], step["timeout"])
		"goto_sell":
			var sp: Node3D = _nearest_sell_point()
			if sp == null:
				_fail("goto_sell: nenhum ponto de entrega")
			else:
				await _walk_to(sp.global_position, 1.2, step["timeout"], 0.5)
		"sell":
			await _sell(step["timeout"])
		"fight":
			await _fight(step["for"], step["radius"])
		"explore":
			await _explore(step["distance"], step["bounds"], step["stop_near_spot"], step["timeout"])
		"set_state":
			_set_state(step["state"])
		"host":
			_host(step["port"])
		"join":
			await _join(step["ip"], step["port"], step["timeout"])
		"start_expedition":
			await _start_expedition(step["map_id"], step["timeout"])
		"sleep":
			await _sleep(step["seconds"])
		"face_player":
			_face_remote_player()
		"goto_player":
			_goto_remote_player()
		"screenshot":
			await _screenshot(step["label"])
		"dump":
			_dump(step["label"])
		"wait_until":
			await _wait_condition(step["condition"], step["timeout"])
		"interact":
			await _interact_with(step["target"], step["walk"], step["timeout"])
		"call":
			_debug_call(step["target"], step["method"])
		"quit":
			pass


## Não bloqueia: os passos seguintes podem correr enquanto a ação está premida.
func _hold_action(action: String, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds, true, false, true).timeout
	Input.action_release(action)


## Vira o jogador (yaw) e a cabeça (pitch) para um ponto do mundo.
func _look_at(target: Vector3) -> void:
	var player: Node3D = _player()
	if player == null:
		_error("look_at: jogador nao encontrado")
		return
	var head: Node3D = player.get_node_or_null(^"Head") as Node3D
	var eye: Vector3 = head.global_position if head != null else player.global_position
	var dir: Vector3 = target - eye
	var flat: float = Vector2(dir.x, dir.z).length()
	if flat < 0.01:
		return
	player.rotation.y = atan2(-dir.x, -dir.z)
	if head != null:
		head.rotation.x = atan2(dir.y, flat)


## Atalho de debug: põe o jogador a GOTO_SPOT_DISTANCE do spot mais próximo, a olhar para ele.
func _goto_nearest_spot() -> void:
	var player: Node3D = _player()
	if player == null:
		_error("goto_spot: jogador nao encontrado")
		return
	var best: Node3D = null
	var best_dist: float = INF
	for n: Node in get_tree().get_nodes_in_group(SPOT_GROUP):
		if not is_instance_valid(n) or not n is Node3D or _is_altar(n):
			continue
		var dist: float = (n as Node3D).global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = n
	if best == null:
		_error("goto_spot: nenhum spot ativo")
		return
	var target: Vector3 = best.global_position
	var away: Vector3 = player.global_position - target
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.BACK
	var pos: Vector3 = target + away.normalized() * GOTO_SPOT_DISTANCE
	pos.y = target.y + 0.3
	player.global_position = pos
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.look_at(Vector3(target.x, pos.y, target.z), Vector3.UP)
	_log("  spot em %s (estava a %.1f m)" % [_vec(target), best_dist])


## Repete o corpo até `until` ou timeout. As condições são verificadas entre passos.
func _run_loop(step: Dictionary) -> void:
	var until: Dictionary = step["until"]
	var timeout: float = step["timeout"]
	var t0: float = _elapsed()
	var iterations: int = 0
	var ok: bool = false
	while true:
		if _conditions_met([until]):
			ok = true
			break
		if _elapsed() - t0 >= timeout:
			break
		for sub: Dictionary in step["body"]:
			if _conditions_met([until]) or _elapsed() - t0 >= timeout:
				break
			if not _conditions_met(sub.get("if", [])):
				continue
			await _execute(sub)
			_executed += 1
		iterations += 1
		await get_tree().process_frame
	var cond_text: String = "%s%s%s" % [until["var"], until["op"], until["value"]]
	var took: float = _elapsed() - t0
	_loops.append({"until": cond_text, "ok": ok, "seconds": took, "ended_at": _elapsed(), "iterations": iterations})
	_log("  loop %s: %s em %.1fs (%d iteracoes)" % [cond_text, "cumprido" if ok else "TIMEOUT", took, iterations])


func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _tap(action: String) -> void:
	Input.action_press(action)
	await _sleep(TAP_SECONDS)
	Input.action_release(action)


## Shift físico (o Player lê Input.is_physical_key_pressed(KEY_SHIFT) para a escavação cuidadosa).
func _set_shift(pressed: bool) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Vira o jogador para o alvo (só yaw) com a cabeça ligeiramente para baixo, como a andar.
func _face_flat(player: Node3D, target: Vector3) -> void:
	var dir: Vector3 = target - player.global_position
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	player.rotation.y = atan2(-dir.x, -dir.z)
	var head: Node3D = player.get_node_or_null(^"Head") as Node3D
	if head != null:
		head.rotation.x = deg_to_rad(WALK_PITCH_DEG)


## Caminha (move_forward + rumo) até ficar a `arrive` m (no plano) do alvo. Salta se
## encravar; se em STUCK_SECONDS avançar menos de STUCK_MIN_PROGRESS (ou no timeout),
## faz teleport de recurso e conta-o em teleport_fallbacks. Devolve true se chegou a andar.
func _walk_to(target: Vector3, arrive: float, timeout: float, y_offset: float, stop_near_spot: float = 0.0) -> bool:
	var player: Node3D = _player()
	if player == null:
		_fail("walk: jogador nao encontrado")
		return false
	var t0: float = _elapsed()
	var check_t: float = t0
	var check_pos: Vector3 = player.global_position
	var jump_t: float = t0
	var jump_pos: Vector3 = player.global_position
	var walked: bool = false
	Input.action_press("move_forward")
	while is_instance_valid(player):
		var to: Vector3 = target - player.global_position
		to.y = 0.0
		if to.length() <= arrive:
			walked = true
			break
		if stop_near_spot > 0.0:
			var near: BuriedSpot = _nearest_spot(player.global_position)
			if near != null and near.global_position.distance_to(player.global_position) <= stop_near_spot:
				walked = true
				break
		_face_flat(player, target)
		var now: float = _elapsed()
		if now - jump_t >= 1.0:
			if player.global_position.distance_to(jump_pos) < 0.4:
				_hold_action("jump", TAP_SECONDS)
			jump_t = now
			jump_pos = player.global_position
		var timed_out: bool = now - t0 >= timeout
		if timed_out or now - check_t >= STUCK_SECONDS:
			if not timed_out and player.global_position.distance_to(check_pos) >= STUCK_MIN_PROGRESS:
				check_t = now
				check_pos = player.global_position
			else:
				var dir: Vector3 = to.normalized() if to.length() > 0.01 else Vector3.BACK
				var pos: Vector3 = target - dir * arrive * 0.8
				pos.y = target.y + y_offset
				player.global_position = pos
				if player is CharacterBody3D:
					(player as CharacterBody3D).velocity = Vector3.ZERO
				_m["teleport_fallbacks"] = int(_m["teleport_fallbacks"]) + 1
				_log("  teleport de recurso #%d (%s) para %s" % [
					_m["teleport_fallbacks"], "timeout" if timed_out else "preso", _vec(pos)])
				break
		await get_tree().physics_frame
	Input.action_release("move_forward")
	return walked


## Luta como o jogador: aproxima-se do inimigo vivo mais próximo (a ≤ radius), olha para
## ele e carrega "attack" (golpe de pá, F). Termina ao fim de `seconds` ou se ficar 2 s sem
## inimigos ao alcance.
func _fight(seconds: float, radius: float) -> void:
	var player: Node3D = _player()
	if player == null:
		_fail("fight: jogador nao encontrado")
		return
	var reach: float = float(player.get("attack_range")) * 0.75 if "attack_range" in player else 1.6
	var t0: float = _elapsed()
	var idle_since: float = t0
	var swings: int = 0
	var check_t: float = t0
	var check_pos: Vector3 = player.global_position
	while _elapsed() - t0 < seconds and is_instance_valid(player):
		var target: EnemyBase = null
		var best: float = radius
		for n: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
			var e: EnemyBase = n as EnemyBase
			if e == null or not is_instance_valid(e) or not e.is_alive():
				continue
			var d3: Vector3 = e.global_position - player.global_position
			var dist: float = Vector2(d3.x, d3.z).length()
			if dist < best:
				best = dist
				target = e
		if target == null:
			Input.action_release("move_forward")
			if _elapsed() - idle_since > 2.0:
				break
			await get_tree().physics_frame
			continue
		idle_since = _elapsed()
		_look_at(target.global_position + Vector3.UP * 0.4)
		if best > reach:
			Input.action_press("move_forward")
			# Encravado (pedra, árvore): salta e contorna para o lado durante meio segundo.
			if _elapsed() - check_t >= 1.0:
				if player.global_position.distance_to(check_pos) < 0.3:
					_hold_action("jump", TAP_SECONDS)
					_hold_action("move_left" if randf() < 0.5 else "move_right", 0.5)
				check_t = _elapsed()
				check_pos = player.global_position
		else:
			Input.action_release("move_forward")
			await _tap("attack")
			swings += 1
		await get_tree().physics_frame
	Input.action_release("move_forward")
	_m["fight_swings"] = int(_m["fight_swings"]) + swings
	_log("  fight: %d golpes em %.1fs" % [swings, _elapsed() - t0])


## Procura como um jogador com radar: caminha `distance` m numa direção aleatória (dentro de
## bounds, se dados) e pára mais cedo se um spot ficar a menos de stop_near_spot m.
func _explore(distance: float, bounds: Rect2, stop_near_spot: float, timeout: float) -> void:
	var player: Node3D = _player()
	if player == null:
		_fail("explore: jogador nao encontrado")
		return
	var from: Vector3 = player.global_position
	var target: Vector3 = from
	for attempt: int in 12:
		var angle: float = randf() * TAU
		target = from + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if not bounds.has_area() or bounds.has_point(Vector2(target.x, target.z)):
			break
		if attempt == 11:
			# Sem sorte: aponta para o centro dos limites.
			var c: Vector2 = bounds.get_center()
			target = from + (Vector3(c.x, from.y, c.y) - from).normalized() * distance
	_m["explore_steps"] = int(_m["explore_steps"]) + 1
	await _walk_to(target, 0.5, timeout, 0.3, stop_near_spot)


func _nearest_spot(from: Vector3) -> BuriedSpot:
	var best: BuriedSpot = null
	var best_dist: float = INF
	for n: Node in get_tree().get_nodes_in_group(SPOT_GROUP):
		if not is_instance_valid(n) or not n is BuriedSpot or _is_altar(n):
			continue
		var dist: float = (n as Node3D).global_position.distance_to(from)
		if dist < best_dist:
			best_dist = dist
			best = n
	return best


func _nearest_sell_point() -> SellPoint:
	var player: Node3D = _player()
	var best: SellPoint = null
	var best_dist: float = INF
	for n: Node in get_tree().get_nodes_in_group(SELL_POINT_GROUP):
		if not n is SellPoint:
			continue
		var dist: float = 0.0 if player == null else (n as Node3D).global_position.distance_to(player.global_position)
		if dist < best_dist:
			best_dist = dist
			best = n
	return best


func _walk_to_nearest_spot(timeout: float, radius: float = 0.0) -> void:
	var player: Node3D = _player()
	if player == null:
		_fail("goto_spot: jogador nao encontrado")
		return
	var spot: BuriedSpot = _nearest_spot(player.global_position)
	if spot == null:
		_fail("goto_spot: nenhum spot ativo")
		return
	if radius > 0.0 and spot.global_position.distance_to(player.global_position) > radius:
		_fail("goto_spot: nenhum spot a menos de %.1f m" % radius)
		return
	var target: Vector3 = spot.global_position
	_log("  a caminhar para spot em %s (%.1f m)" % [_vec(target), target.distance_to(player.global_position)])
	await _walk_to(target, GOTO_SPOT_DISTANCE, timeout, 0.3)
	if is_instance_valid(spot):
		_look_at(spot.global_position)


## Cava o spot ao alcance (dig_range do jogador) com o botão direito real até revelar.
## mode: fast (sem Shift), careful (Shift), smart (rápido e Shift nas últimas camadas,
## onde a pazada rápida estraga o item).
func _dig_spot(mode: String, timeout: float) -> void:
	var player: Node3D = _player()
	if player == null:
		_fail("dig_spot: jogador nao encontrado")
		return
	var dig_range: float = float(player.get("dig_range")) if "dig_range" in player else 1.8
	var spot: BuriedSpot = _nearest_spot(player.global_position)
	if spot == null or spot.global_position.distance_to(player.global_position) > dig_range:
		_fail("dig_spot: nenhum spot ao alcance")
		return
	var t0: float = _elapsed()
	var taps: int = 0
	while is_instance_valid(spot) and spot.is_in_group(SPOT_GROUP):
		if _elapsed() - t0 >= timeout:
			_fail("dig_spot: timeout (%d pazadas, faltam %d camadas)" % [taps, spot.dirt_layers])
			break
		if spot.global_position.distance_to(player.global_position) > dig_range:
			_fail("dig_spot: jogador saiu do alcance (morte/empurrao?)")
			break
		_look_at(spot.global_position)
		_set_shift(mode == "careful" or (mode == "smart" and spot.dirt_layers <= 2))
		await _tap("careful_dig")
		taps += 1
		await _sleep(0.15)
	_set_shift(false)
	if not is_instance_valid(spot) or not spot.is_in_group(SPOT_GROUP):
		_m["spots_dug"] = int(_m["spots_dug"]) + 1
		_log("  spot revelado em %.1fs (%d pazadas)" % [_elapsed() - t0, taps])


## Apanha o pickup mais próximo (raio) como o jogador: aproxima-se, olha e carrega E.
func _pickup(radius: float, timeout: float) -> void:
	var player: Node3D = _player()
	var inv: Inventory = player.get_node_or_null(^"Inventory") as Inventory if player != null else null
	if inv == null:
		_fail("pickup: jogador/mochila nao encontrados")
		return
	if inv.is_full():
		_fail("pickup: mochila cheia")
		return
	await _sleep(0.9) # deixa o item saltar e assentar
	var t0: float = _elapsed()
	# Em coop o item chega pelo host (request_pickup → _grant_item) depois do tap: conta
	# a partir da mochila inicial e não só logo a seguir a cada tap.
	var start_count: int = inv.get_count()
	while _elapsed() - t0 < timeout:
		if inv.get_count() > start_count:
			_m["items_picked"] = int(_m["items_picked"]) + 1
			return
		var target: ItemPickup = null
		var best: float = radius
		for n: Node in get_tree().get_nodes_in_group(PICKUP_GROUP):
			var p: ItemPickup = n as ItemPickup
			if p == null or not is_instance_valid(p) or p.carried == null:
				continue
			var dist: float = p.global_position.distance_to(player.global_position)
			if dist < best:
				best = dist
				target = p
		if target == null:
			if _elapsed() - t0 > 1.5 and inv.get_count() <= start_count:
				_fail("pickup: nenhum item a menos de %.1f m" % radius)
				return
			await get_tree().process_frame
			continue
		if best > 1.6:
			await _walk_to(target.global_position, 1.0, 5.0, 0.3)
			if not is_instance_valid(target):
				continue
		_look_at(target.global_position)
		await get_tree().process_frame
		var before: int = inv.get_count()
		await _tap("interact")
		await _sleep(0.2)
		if inv.get_count() > before:
			_m["items_picked"] = int(_m["items_picked"]) + 1
			return
	_fail("pickup: timeout")


## Entrega a mochila pelo mesmo caminho do jogador real (E dentro do raio do SellPoint).
func _sell(timeout: float) -> void:
	var player: Node3D = _player()
	var sp: SellPoint = _nearest_sell_point()
	if player == null or sp == null or not sp.is_in_range(player.global_position):
		_fail("sell: fora do raio de entrega")
		return
	if _deliverable_count() == 0:
		_log("  sell: nada para entregar")
		return
	var t0: float = _elapsed()
	while _deliverable_count() > 0:
		if _elapsed() - t0 >= timeout:
			_fail("sell: timeout")
			return
		await _tap("interact")
		await _sleep(0.3)


func _player_inventory() -> Inventory:
	var player: Node3D = _player()
	return player.get_node_or_null(^"Inventory") as Inventory if player != null else null


func _deliverable_count() -> int:
	var inv: Inventory = _player_inventory()
	if inv == null:
		return 0
	var n: int = 0
	for c: CarriedItem in inv.slots:
		if SellPoint.can_deliver(c):
			n += 1
	return n


## Atalho de debug: funde campos no snapshot do CoreGameState e reaplica-o
## (emite money_changed/upgrades_changed/progression_changed como um sync normal).
func _set_state(changes: Dictionary) -> void:
	var gs: Node = get_node_or_null(^"/root/CoreGameState")
	if gs == null or not gs.has_method("get_snapshot") or not gs.has_method("apply_snapshot"):
		_error("set_state: CoreGameState indisponivel")
		return
	var snap: Dictionary = gs.call("get_snapshot")
	for key: String in changes:
		if key == "upgrade_levels":
			var levels: Dictionary = snap.get("upgrade_levels", {})
			levels.merge(changes[key], true)
			snap[key] = levels
		else:
			snap[key] = changes[key]
	gs.call("apply_snapshot", snap)


func _screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		_error("screenshot '%s' ignorado: renderer headless" % label)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _run_dir.path_join(label + ".png")
	if img == null or img.save_png(path) != OK:
		_error("falhou ao gravar %s" % path)
		return
	_screenshots.append(label + ".png")


func _dump(label: String) -> void:
	var path: String = _run_dir.path_join(label + ".json")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_error("falhou ao gravar %s" % path)
		return
	f.store_string(JSON.stringify(collect_state(), "\t"))
	_dumps.append(label + ".json")


func _wait_condition(cond: Dictionary, timeout: float) -> void:
	var t0: float = _elapsed()
	while true:
		var lhs: float = _condition_value(cond["var"])
		if compare(lhs, cond["op"], cond["value"]):
			var took: float = _elapsed() - t0
			_log("  condicao cumprida em %.2fs (%s=%s)" % [took, cond["var"], lhs])
			_waits.append({"condition": "%s%s%s" % [cond["var"], cond["op"], cond["value"]], "ok": true, "seconds": took})
			return
		if _elapsed() - t0 >= timeout:
			_error("timeout (%.0fs) a espera de %s%s%s (atual %s)" % [timeout, cond["var"], cond["op"], cond["value"], lhs])
			_waits.append({"condition": "%s%s%s" % [cond["var"], cond["op"], cond["value"]], "ok": false, "seconds": timeout})
			return
		await get_tree().process_frame


func _condition_value(var_name: String) -> float:
	match var_name:
		"nearest_spot":
			var p: Node3D = _player()
			var s: BuriedSpot = _nearest_spot(p.global_position) if p != null else null
			return s.global_position.distance_to(p.global_position) if s != null else NO_TARGET_DISTANCE
		"free_slots":
			var inv: Inventory = _player_inventory()
			return float(inv.capacity - inv.get_count()) if inv != null else 0.0
		"deliverable":
			return float(_deliverable_count())
		"enemy_dist":
			var pe: Node3D = _player()
			var nearest: float = NO_TARGET_DISTANCE
			if pe != null:
				for n: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
					var en: EnemyBase = n as EnemyBase
					if en != null and is_instance_valid(en) and en.is_alive():
						var de: Vector3 = en.global_position - pe.global_position
						nearest = minf(nearest, Vector2(de.x, de.z).length())
			return nearest
		"pickup_dist":
			var pl: Node3D = _player()
			var best: float = NO_TARGET_DISTANCE
			if pl != null:
				for n: Node in get_tree().get_nodes_in_group(PICKUP_GROUP):
					var pk: ItemPickup = n as ItemPickup
					if pk != null and is_instance_valid(pk) and pk.carried != null:
						best = minf(best, pk.global_position.distance_to(pl.global_position))
			return best
		"sell_dist":
			var p: Node3D = _player()
			var sp: SellPoint = _nearest_sell_point()
			if p == null or sp == null:
				return NO_TARGET_DISTANCE
			var d: Vector3 = sp.global_position - p.global_position
			return Vector2(d.x, d.z).length()
		"players":
			return float(get_tree().get_nodes_in_group(PLAYERS_GROUP).size())
		"wave_round", "wave_phase", "wave_left":
			var wave: WaveEvent = _active_wave()
			if wave == null:
				return 0.0
			if var_name == "wave_round":
				return float(wave.round_number)
			return float(wave.phase) if var_name == "wave_phase" else float(wave.enemies_left)
		"bosses":
			var alive: int = 0
			for n: Node in get_tree().get_nodes_in_group(&"bosses"):
				if n is EnemyBase and (n as EnemyBase).is_alive():
					alive += 1
			return float(alive)
	if var_name.begins_with("flag_"):
		var flags: WorldFlags = WorldFlags.find(get_tree())
		return 1.0 if flags != null and flags.has_flag(StringName(var_name.substr(5))) else 0.0
	if var_name.begins_with("quest_"):
		var npc: Node = _find_named(var_name.substr(6))
		return float(npc.get("state")) if npc is QuestNpc else -1.0
	var state: Dictionary = collect_state()
	match var_name:
		"money": return float(state["game_state"].get("team_money", 0))
		"inventory": return float((state["inventory"] as Array).size())
		"enemies": return float((state["enemies"] as Array).size())
		"spots": return float((state["spots"] as Array).size())
		"time": return _elapsed()
		"health": return float(state["player"].get("health", 0.0))
	return 0.0


# --- Estado (só leitura) -------------------------------------------------------

func collect_state() -> Dictionary:
	var state: Dictionary = {
		"time": _elapsed(),
		"fps": Engine.get_frames_per_second(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"player": {},
		"game_state": {},
		"inventory": [],
		"enemies": [],
		"spots": [],
		"threat": {},
		"net": {},
		"players": [],
	}
	state["net"] = {
		"peer_id": multiplayer.get_unique_id(),
		"is_server": multiplayer.is_server(),
		"peers": Array(multiplayer.get_peers()),
	}
	var players: Array = []
	for n: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var pl: Node3D = n as Node3D
		if pl == null or not is_instance_valid(pl):
			continue
		players.append({
			"name": String(pl.name),
			"authority": pl.get_multiplayer_authority(),
			"local": pl.is_multiplayer_authority(),
			"position": _vec(pl.global_position),
			"yaw_deg": snappedf(rad_to_deg(pl.global_rotation.y), 0.1),
			"held_tool": String(pl.get("held_tool_id")) if "held_tool_id" in pl else "",
		})
	state["players"] = players
	if DisturbanceMeter.instance != null:
		state["threat"] = {
			"noise": snappedf(DisturbanceMeter.instance.current_noise, 0.1),
			"level": DisturbanceMeter.instance.current_level,
		}
	var gs: Node = get_node_or_null(^"/root/CoreGameState")
	if gs != null and gs.has_method("get_snapshot"):
		state["game_state"] = gs.call("get_snapshot")
	var player: Node3D = _player()
	if player != null:
		var p: Dictionary = {
			"position": _vec(player.global_position),
			"yaw_deg": rad_to_deg(player.global_rotation.y),
		}
		var head: Node3D = player.get_node_or_null(^"Head") as Node3D
		if head != null:
			p["pitch_deg"] = rad_to_deg(head.rotation.x)
		for prop: String in ["health", "session_money", "session_items_count"]:
			if prop in player:
				p[prop] = player.get(prop)
		state["player"] = p
		var inv: Inventory = player.get_node_or_null(^"Inventory") as Inventory
		if inv != null:
			var items: Array = []
			for i: int in inv.slots.size():
				var c: CarriedItem = inv.slots[i]
				if c == null:
					continue
				items.append({
					"slot": i,
					"item": c.item.id if c.item != null else "",
					"tool": String(c.tool_id),
					"value": c.final_value,
					"integrity": c.integrity,
					"rare": c.is_rare_variant,
				})
			state["inventory"] = items
	var enemies: Array = []
	for n: Node in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if not is_instance_valid(n) or not n is Node3D:
			continue
		var e: Dictionary = {"name": String(n.name), "position": _vec((n as Node3D).global_position)}
		if n is EnemyBase:
			e["health"] = (n as EnemyBase).health
			e["alive"] = (n as EnemyBase).is_alive()
		enemies.append(e)
	state["enemies"] = enemies
	var spots: Array = []
	for n: Node in get_tree().get_nodes_in_group(SPOT_GROUP):
		if not is_instance_valid(n) or not n is BuriedSpot:
			continue
		var s: BuriedSpot = n
		spots.append({
			"position": _vec(s.global_position),
			"item": s.item.id if s.item != null else "",
			"dirt_layers": s.dirt_layers,
			"boss_altar": _is_altar(s),
		})
	state["spots"] = spots
	# Missões e eventos (#39)
	var flags: WorldFlags = WorldFlags.find(get_tree())
	state["flags"] = flags.get_all() if flags != null else {}
	var quests: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		if n is QuestNpc:
			quests[String(n.name)] = QuestNpc.QuestState.keys()[(n as QuestNpc).state]
	state["quests"] = quests
	var waves: Array = []
	for n: Node in get_tree().get_nodes_in_group(WaveEvent.GROUP):
		waves.append((n as WaveEvent).get_status())
	state["waves"] = waves
	return state


# --- Missões e eventos (#39) ----------------------------------------------------

## Vai até ao Interactable `target_name` (a pé com walk, senão teleporte), olha para ele e
## carrega [E] como o jogador (o foco do Interactable trata o resto).
func _interact_with(target_name: String, walk: bool, timeout: float) -> void:
	var it: Interactable = _find_named(target_name) as Interactable
	var player: Node3D = _player()
	if it == null or player == null:
		_fail("interact: '%s' nao encontrado" % target_name)
		return
	var focus: Vector3 = it.get_focus_point()
	var arrive: float = clampf(it.interact_range - 1.0, 1.0, 2.0)
	var flat: Vector3 = Vector3(player.global_position.x - focus.x, 0.0, player.global_position.z - focus.z)
	if flat.length() > arrive:
		if walk:
			await _walk_to(focus, arrive, timeout, 0.6)
		else:
			var dir: Vector3 = flat.normalized() if flat.length() > 0.01 else Vector3.BACK
			player.global_position = Vector3(focus.x, player.global_position.y, focus.z) + dir * arrive
			if player is CharacterBody3D:
				(player as CharacterBody3D).velocity = Vector3.ZERO
	_look_at(focus)
	for i: int in 3:
		await get_tree().process_frame
	if Interactable.get_focused() != it:
		_fail("interact: '%s' sem foco (alvo do proprio jogador ou fora do cone)" % target_name)
	await _hold_action("interact", TAP_SECONDS)
	await get_tree().process_frame


func _debug_call(target_name: String, method: String) -> void:
	var n: Node = _find_named(target_name)
	if n == null or not n.has_method(method):
		_fail("call: '%s.%s' nao existe" % [target_name, method])
		return
	n.call(method)


## Primeiro nó da cena atual com este nome (procura recursiva).
func _find_named(node_name: String) -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	if String(scene.name) == node_name:
		return scene
	return scene.find_child(node_name, true, false)


func _active_wave() -> WaveEvent:
	var first: WaveEvent = null
	for n: Node in get_tree().get_nodes_in_group(WaveEvent.GROUP):
		var w: WaveEvent = n as WaveEvent
		if w == null:
			continue
		if w.phase != WaveEvent.Phase.IDLE:
			return w
		if first == null:
			first = w
	return first


# --- Coop (CoreNetwork / CoreSession) ------------------------------------------

func _host(port: int) -> void:
	if NetworkManager.instance == null:
		_error("host: CoreNetwork indisponivel")
		return
	var err: Error = NetworkManager.instance.host_game(port)
	if err != OK:
		_error("host: host_game(%d) = %s" % [port, error_string(err)])
	else:
		_log("  a hospedar na porta %d" % port)


## Liga-se ao host e espera pela ligação (o SessionManager leva o cliente para o mapa).
func _join(ip: String, port: int, timeout: float) -> void:
	if NetworkManager.instance == null:
		_error("join: CoreNetwork indisponivel")
		return
	var err: Error = NetworkManager.instance.join_game(ip, port)
	if err != OK:
		_error("join: join_game(%s:%d) = %s" % [ip, port, error_string(err)])
		return
	var t0: float = _elapsed()
	while multiplayer.multiplayer_peer == null 			or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		if _elapsed() - t0 > timeout:
			_error("join: sem ligacao a %s:%d em %.0fs" % [ip, port, timeout])
			return
		await get_tree().process_frame
	_log("  ligado como peer %d" % multiplayer.get_unique_id())


## Host: inicia a expedição pelo fluxo normal e espera que o mapa carregue.
func _start_expedition(map_id: String, timeout: float) -> void:
	var sm: SessionManager = SessionManager.instance
	if sm == null:
		_error("start_expedition: CoreSession indisponivel")
		return
	if not sm.can_start_map(map_id):
		_error("start_expedition: '%s' indisponivel (bloqueado ou sem cena)" % map_id)
		return
	sm.request_start_expedition(map_id)
	var t0: float = _elapsed()
	while not sm.is_peer_scene_ready(multiplayer.get_unique_id()):
		if _elapsed() - t0 > timeout:
			_error("start_expedition: mapa '%s' nao carregou em %.0fs" % [map_id, timeout])
			return
		await get_tree().process_frame
	_log("  expedicao em %s" % get_tree().current_scene.scene_file_path)


## Vira o jogador local para o jogador remoto mais próximo (para capturas em coop).
func _face_remote_player() -> void:
	var me: Node3D = _player()
	if me == null:
		_fail("face_player: jogador local nao encontrado")
		return
	var best: Node3D = _nearest_remote_player(me)
	if best == null:
		_fail("face_player: nenhum jogador remoto")
		return
	_look_at(best.global_position + Vector3.UP * 1.2)
	_log("  a olhar para o jogador %s (%.1f m)" % [best.name, best.global_position.distance_to(me.global_position)])


## Atalho de debug: põe o jogador local 1.5 m ao lado do remoto mais próximo, virado para ele.
func _goto_remote_player() -> void:
	var me: Node3D = _player()
	var other: Node3D = _nearest_remote_player(me) if me != null else null
	if other == null:
		_fail("goto_player: nenhum jogador remoto")
		return
	var side: Vector3 = other.global_basis.x
	side.y = 0.0
	me.global_position = other.global_position + side.normalized() * 1.5 + Vector3.UP * 0.3
	if me is CharacterBody3D:
		(me as CharacterBody3D).velocity = Vector3.ZERO
	_look_at(other.global_position + Vector3.UP * 1.2)
	_log("  ao lado do jogador %s" % other.name)


func _nearest_remote_player(me: Node3D) -> Node3D:
	var best: Node3D = null
	var best_dist: float = INF
	for n: Node in get_tree().get_nodes_in_group(PLAYERS_GROUP):
		var pl: Node3D = n as Node3D
		if pl == null or pl == me or pl.is_multiplayer_authority():
			continue
		var dist: float = pl.global_position.distance_to(me.global_position)
		if dist < best_dist:
			best_dist = dist
			best = pl
	return best


## Os altares de chefe (BossAltar e subclasses) também são BuriedSpot; goto_spot ignora-os.
static func _is_altar(n: Node) -> bool:
	return n is BossAltar


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D


static func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


# --- Saída ---------------------------------------------------------------------

func _open_run_dir(script_path: String) -> void:
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base: String = ProjectSettings.globalize_path("res://").path_join(".bot_runs")
	_run_dir = base.path_join("%s_%s" % [script_path.get_file().get_basename(), stamp])
	DirAccess.make_dir_recursive_absolute(_run_dir)
	_log_file = FileAccess.open(_run_dir.path_join("log.txt"), FileAccess.WRITE)
	print("[DebugBridge] saida em %s" % _run_dir)


func _build_metrics() -> Dictionary:
	var m: Dictionary = _m.duplicate()
	var elapsed: float = _elapsed()
	var money: int = int(_condition_value("money"))
	m["final_money"] = money
	m["money_earned"] = money - int(_m["start_money"])
	m["elapsed"] = elapsed
	m["money_per_min"] = snappedf(float(m["money_earned"]) / maxf(elapsed / 60.0, 0.001), 0.1)
	# Tempo até à meta: o primeiro loop cumprido (tempo absoluto desde o início).
	m["time_to_goal"] = -1.0
	for l: Dictionary in _loops:
		if l["ok"]:
			m["time_to_goal"] = l["ended_at"]
			m["goal"] = l["until"]
			break
	return m


func _describe(step: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in step:
		if k != "kind" and k != "t" and k != "body":
			parts.append("%s=%s" % [k, step[k]])
	return " ".join(parts)


func _log(msg: String) -> void:
	print("[DebugBridge] " + msg)
	if _log_file != null:
		_log_file.store_line(msg)
		_log_file.flush()


func _error(msg: String) -> void:
	_errors.append(msg)
	push_warning("[DebugBridge] " + msg)
	_log("ERRO: " + msg)


func _finish(code: int) -> void:
	var summary: Dictionary = {
		"exit_code": code if _errors.is_empty() else maxi(code, 1),
		"steps_executed": _executed,
		"elapsed": _elapsed() if _start_msec > 0 else 0.0,
		"screenshots": _screenshots,
		"dumps": _dumps,
		"waits": _waits,
		"loops": _loops,
		"errors": _errors,
	}
	if _monitoring:
		summary["metrics"] = _build_metrics()
	var f: FileAccess = FileAccess.open(_run_dir.path_join("summary.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
	_log("fim: %d passos, %d erros" % [_executed, _errors.size()])
	for action: String in ACTIONS:
		Input.action_release(action)
	get_tree().quit(summary["exit_code"])
