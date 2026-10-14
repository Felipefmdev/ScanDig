extends Node
## Ponte de automação para agentes: executa um roteiro JSON (input, capturas,
## dumps de estado). Só ativa em builds de debug com o user arg --bot=<roteiro.json>;
## sem isso não faz nada (zero efeito no jogo normal).

const ACTIONS: PackedStringArray = [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "interact", "use_tool", "careful_dig",
]
const STEP_KEYS: PackedStringArray = [
	"press", "tap", "look", "screenshot", "dump", "teleport", "look_at", "goto_spot", "wait_until", "quit",
]
const CONDITION_VARS: PackedStringArray = ["money", "inventory", "enemies", "spots", "time", "health"]
const CONDITION_OPS: PackedStringArray = [">=", "<=", "==", "!=", ">", "<"]
const TAP_SECONDS: float = 0.1
const DEFAULT_WAIT_TIMEOUT: float = 60.0
const PLAYER_GROUP: StringName = &"player"
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
	return {"ok": errors.is_empty(), "scene": scene_path, "steps": steps, "errors": errors}


## Normaliza um passo. Devolve o Dictionary normalizado ou uma String de erro.
static func parse_step(raw: Variant) -> Variant:
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
	elif kind != "wait_until":
		return "falta 't'"
	var step: Dictionary = {"kind": kind, "t": t}
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
			var timeout: float = DEFAULT_WAIT_TIMEOUT
			if d.has("timeout"):
				if not _is_number(d["timeout"]) or float(d["timeout"]) <= 0.0:
					return "'timeout' deve ser > 0"
				timeout = float(d["timeout"])
			step["timeout"] = timeout
		"look_at":
			var v: Variant = _number_array(value, 3)
			if v == null:
				return "'look_at' deve ser [x, y, z]"
			step["target"] = Vector3(v[0], v[1], v[2])
		"goto_spot":
			if value != "nearest":
				return "'goto_spot' so aceita \"nearest\""
		"quit":
			if value != true:
				return "'quit' deve ser true"
	return step


## "money>=300" -> {var, op, value}; null se inválida.
static func parse_condition(text: String) -> Variant:
	var s: String = text.replace(" ", "")
	for op: String in CONDITION_OPS:
		var idx: int = s.find(op)
		if idx <= 0:
			continue
		var var_name: String = s.substr(0, idx)
		var rhs: String = s.substr(idx + op.length())
		if not CONDITION_VARS.has(var_name) or not rhs.is_valid_float():
			return null
		return {"var": var_name, "op": op, "value": rhs.to_float()}
	return null


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
	for step: Dictionary in parsed["steps"]:
		await _wait_until_time(step["t"])
		await _execute(step)
		_executed += 1
		if step["kind"] == "quit":
			break
	_finish(0)


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
			_goto_nearest_spot()
		"screenshot":
			await _screenshot(step["label"])
		"dump":
			_dump(step["label"])
		"wait_until":
			await _wait_condition(step["condition"], step["timeout"])
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
	return state


## O BossAltar também é um BuriedSpot; goto_spot ignora-o.
static func _is_altar(n: Node) -> bool:
	var scr: Script = n.get_script() as Script
	return scr != null and scr.resource_path.ends_with("boss_altar.gd")


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


func _describe(step: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k: String in step:
		if k != "kind" and k != "t":
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
		"errors": _errors,
	}
	var f: FileAccess = FileAccess.open(_run_dir.path_join("summary.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
	_log("fim: %d passos, %d erros" % [_executed, _errors.size()])
	for action: String in ACTIONS:
		Input.action_release(action)
	get_tree().quit(summary["exit_code"])
