class_name WaveEvent
extends Node3D

## Evento de rondas (#39, ex.: Maré Vermelha na Praia): N rondas de inimigos que surgem à
## volta de um ponto, com pausa entre rondas. Opcionalmente há um alvo a defender (o barco do
## Zé): cada inimigo vivo perto dele tira-lhe vida; se chegar a 0 o evento falha.
## Corre no host (contrato #5): os inimigos nascem por EnemySpawner.spawn_from_data (já
## replicados) e o estado (fase, ronda, inimigos, vida do alvo) vai para todos os peers, que
## mostram o HUD de ronda (CanvasLayer criado aqui, não em ui/). Funciona em solo.
##
## Rondas: uma String por ronda, "kind:quantidade" separados por vírgula, ex.
## "crab:3,hermit_crab:1". Com scale_with_players, a quantidade cresce 50 % por jogador extra.

signal started()
signal round_started(round_number: int)
signal finished(success: bool)

enum Phase { IDLE, BREAK, FIGHT, WON, LOST }

const GROUP: StringName = &"wave_events"
const HUD_LINGER: float = 4.0

@export var event_id: StringName = &"evento"
@export var event_name: String = "EVENTO"
@export var rounds: Array[String] = ["crab:3", "crab:4,hermit_crab:1", "crab:5,hermit_crab:2"]
## Centro dos spawns (vazio = este nó).
@export var spawn_center_path: NodePath = NodePath("")
@export var spawn_radius_min: float = 5.0
@export var spawn_radius_max: float = 9.0
## Intervalo entre inimigos da mesma ronda.
@export var spawn_stagger: float = 0.6
@export var break_time: float = 4.0
@export var scale_with_players: bool = true

@export_group("Alvo a defender")
## Nó a defender (vazio = sem alvo).
@export var defend_path: NodePath = NodePath("")
@export var defend_name: String = "Barco"
@export var defend_radius: float = 3.0
@export var defend_max_hp: float = 100.0
## Vida perdida por segundo por cada inimigo dentro de defend_radius.
@export var defend_damage_per_enemy: float = 1.5
## Os inimigos vão ao alvo, mas viram-se para um jogador que chegue a esta distância.
@export var aggro_radius: float = 5.0

@export_group("Chão")
@export_flags_3d_physics var ground_mask: int = 1

var phase: Phase = Phase.IDLE
## 1..rounds.size() (0 antes de começar).
var round_number: int = 0
var enemies_left: int = 0
var defend_hp: float = 100.0

## Vida máxima do alvo nesta corrida (cresce com o nº de jogadores, como os inimigos).
var defend_hp_max: float = 100.0
var _alive: Array[Node3D] = []
var _to_spawn: Array[StringName] = []
var _spawn_timer: float = 0.0
var _phase_timer: float = 0.0
var _hud_dirty: bool = false
var _hud_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _hud: CanvasLayer = null
var _hud_title: Label = null
var _hud_round: Label = null
var _hud_defend: ProgressBar = null
var _hud_hide_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	defend_hp_max = defend_max_hp
	defend_hp = defend_max_hp
	_rng.randomize()
	_build_hud()
	if HostSync.is_host(self):
		HostSync.on_peer_ready(self, _send_hud_to)


## Host: começa o evento (falso se já estiver a correr).
func start() -> bool:
	if not HostSync.is_host(self) or is_running():
		return false
	round_number = 0
	defend_hp_max = defend_max_hp * _player_scale()
	defend_hp = defend_hp_max
	_alive.clear()
	_to_spawn.clear()
	_set_phase(Phase.BREAK)
	_phase_timer = minf(break_time, 2.0)
	started.emit()
	return true


func is_running() -> bool:
	return phase == Phase.BREAK or phase == Phase.FIGHT


func get_status() -> Dictionary:
	return {
		"id": String(event_id), "phase": Phase.keys()[phase], "round": round_number,
		"rounds": rounds.size(), "enemies_left": enemies_left,
		"defend_hp": snappedf(defend_hp, 0.1),
	}


func _physics_process(delta: float) -> void:
	if _hud_hide_left > 0.0:
		_hud_hide_left -= delta
		if _hud_hide_left <= 0.0 and not is_running():
			_hud.visible = false
	if not HostSync.is_host(self) or not is_running():
		return
	match phase:
		Phase.BREAK:
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_begin_round()
		Phase.FIGHT:
			_process_fight(delta)
	_hud_timer -= delta
	if _hud_dirty and _hud_timer <= 0.0:
		_hud_timer = 0.25
		_hud_dirty = false
		_push_hud()


func _begin_round() -> void:
	round_number += 1
	_to_spawn = _parse_round(rounds[round_number - 1])
	_spawn_timer = 0.0
	_set_phase(Phase.FIGHT)
	round_started.emit(round_number)


func _process_fight(delta: float) -> void:
	_spawn_timer -= delta
	if not _to_spawn.is_empty() and _spawn_timer <= 0.0:
		_spawn_timer = spawn_stagger
		var kind: StringName = _to_spawn.pop_front()
		var enemy: Node3D = _spawn(kind)
		if enemy != null:
			_alive.append(enemy)
			var goal: Node3D = _defend_target()
			if goal != null and enemy is EnemyBase:
				(enemy as EnemyBase).objective_target = goal
				(enemy as EnemyBase).objective_aggro_radius = aggro_radius
	_prune_alive()
	var left: int = _alive.size() + _to_spawn.size()
	if left != enemies_left:
		enemies_left = left
		_hud_dirty = true

	var target: Node3D = _defend_target()
	if target != null:
		var near: int = 0
		for e: Node3D in _alive:
			var d: Vector3 = e.global_position - target.global_position
			d.y = 0.0
			if d.length() <= defend_radius:
				near += 1
		if near > 0:
			defend_hp = maxf(defend_hp - defend_damage_per_enemy * float(near) * delta, 0.0)
			_hud_dirty = true
			if defend_hp <= 0.0:
				_finish(false)
				return

	if enemies_left == 0:
		if round_number >= rounds.size():
			_finish(true)
		else:
			_set_phase(Phase.BREAK)
			_phase_timer = break_time


func _finish(success: bool) -> void:
	for e: Node3D in _alive:
		if is_instance_valid(e):
			e.queue_free()
	_alive.clear()
	_to_spawn.clear()
	enemies_left = 0
	_set_phase(Phase.WON if success else Phase.LOST)
	finished.emit(success)


func _set_phase(p: Phase) -> void:
	phase = p
	_hud_dirty = false
	_push_hud()


func _prune_alive() -> void:
	var keep: Array[Node3D] = []
	for i: int in _alive.size():
		var e: Node3D = _alive[i]
		if not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		if e.has_method(&"is_alive") and not bool(e.call(&"is_alive")):
			continue
		keep.append(e)
	_alive = keep


## "crab:3,hermit_crab:1" -> [crab, crab, crab, hermit_crab] (escalado pelo nº de jogadores).
func _parse_round(spec: String) -> Array[StringName]:
	var out: Array[StringName] = []
	for part: String in spec.split(",", false):
		var kv: PackedStringArray = part.strip_edges().split(":")
		var count: int = int(ceil(float(int(kv[1]) if kv.size() > 1 else 1) * _player_scale()))
		for i: int in count:
			out.append(StringName(kv[0].strip_edges()))
	return out


## 1 em solo; +50 % por jogador extra (com scale_with_players).
func _player_scale() -> float:
	if not scale_with_players or not is_inside_tree():
		return 1.0
	var players: int = maxi(get_tree().get_nodes_in_group(&"players").size(), 1)
	return 1.0 + 0.5 * float(players - 1)


func _spawn(kind: StringName) -> Node3D:
	var center: Vector3 = _center()
	var pos: Vector3 = _pick_ground(center)
	var to_center: Vector3 = center - pos
	var data: Dictionary = {"kind": String(kind), "pos": pos, "level": 0, "rot_y": atan2(-to_center.x, -to_center.z)}
	var spawner: EnemySpawner = EnemySpawner.find(get_tree()) if is_inside_tree() else null
	if spawner != null:
		return spawner.spawn_from_data(data)
	# Sem spawner (testes): só local, como filho deste nó.
	var scene: PackedScene = EnemySpawner.scene_for_kind(kind)
	if scene == null:
		return null
	var enemy: Node3D = scene.instantiate() as Node3D
	enemy.position = global_transform.affine_inverse() * pos if is_inside_tree() else pos
	add_child(enemy)
	return enemy


func _defend_target() -> Node3D:
	return get_node_or_null(defend_path) as Node3D if not defend_path.is_empty() else null


func _center() -> Vector3:
	var n: Node3D = get_node_or_null(spawn_center_path) as Node3D if not spawn_center_path.is_empty() else null
	return n.global_position if n != null else global_position


## Ponto no chão no anel à volta de `center` (raio para baixo); sem chão, fica à altura do centro.
func _pick_ground(center: Vector3) -> Vector3:
	for attempt: int in 8:
		var ang: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(spawn_radius_min, spawn_radius_max)
		var p: Vector3 = center + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if not is_inside_tree():
			return p
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 10.0, p + Vector3.DOWN * 20.0, ground_mask)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and absf((hit["position"] as Vector3).y - center.y) < 2.0:
			return hit["position"]
	return center + Vector3(spawn_radius_min, 0.0, 0.0)


# ---------------------------------------------------------------------------
# HUD de ronda (todos os peers)
# ---------------------------------------------------------------------------

func _push_hud() -> void:
	var ratio: float = defend_hp / maxf(defend_hp_max, 0.001)
	_apply_hud(int(phase), round_number, enemies_left, ratio)
	HostSync.broadcast(self, &"_rpc_hud", [int(phase), round_number, enemies_left, ratio])


func _send_hud_to(peer_id: int) -> void:
	HostSync.send_to(self, peer_id, &"_rpc_hud", [int(phase), round_number, enemies_left, defend_hp / maxf(defend_hp_max, 0.001)])


@rpc("authority", "call_remote", "reliable")
func _rpc_hud(p: int, rnd: int, left: int, ratio: float) -> void:
	phase = p as Phase
	round_number = rnd
	enemies_left = left
	defend_hp = ratio * defend_hp_max
	_apply_hud(p, rnd, left, ratio)


func _apply_hud(p: int, rnd: int, left: int, ratio: float) -> void:
	if _hud == null:
		return
	_hud_defend.visible = not defend_path.is_empty()
	_hud_defend.value = ratio * 100.0
	match p as Phase:
		Phase.IDLE:
			_hud.visible = false
			return
		Phase.BREAK:
			_hud_round.text = "Prepara-te... ronda %d/%d" % [rnd + 1, rounds.size()]
		Phase.FIGHT:
			_hud_round.text = "Ronda %d/%d  —  inimigos: %d" % [rnd, rounds.size(), left]
		Phase.WON:
			_hud_round.text = "Vitória!"
			_hud_hide_left = HUD_LINGER
		Phase.LOST:
			_hud_round.text = "%s perdido... fala outra vez para tentar de novo" % defend_name
			_hud_hide_left = HUD_LINGER
	_hud.visible = true


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "WaveHud"
	_hud.layer = 3
	_hud.visible = false
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-220.0, 118.0)
	box.custom_minimum_size = Vector2(440.0, 0.0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_hud.add_child(box)
	_hud_title = _hud_label(event_name, 30, Color(1.0, 0.45, 0.32))
	box.add_child(_hud_title)
	_hud_round = _hud_label("", 22, Color(1.0, 0.95, 0.85))
	box.add_child(_hud_round)
	_hud_defend = ProgressBar.new()
	_hud_defend.custom_minimum_size = Vector2(440.0, 14.0)
	_hud_defend.show_percentage = false
	_hud_defend.value = 100.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.36, 0.72, 0.35)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.06, 0.8)
	_hud_defend.add_theme_stylebox_override(&"fill", fill)
	_hud_defend.add_theme_stylebox_override(&"background", bg)
	box.add_child(_hud_defend)
	add_child(_hud)


static func _hud_label(text: String, size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override(&"outline_size", 8)
	return l
