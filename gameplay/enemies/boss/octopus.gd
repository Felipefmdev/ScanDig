class_name Octopus
extends EnemyBase

## Polvo do Naufrágio (#40): chefe escondido da Praia. Acorda pelo BossTrigger quando as 3
## conchas tocam pela ordem certa e sai da água junto ao navio. Não anda: vira-se para o
## jogador mais próximo e ataca com tentáculos que rebentam do chão onde o jogador está
## (círculo vermelho telegrafado, SLAM_RADIUS). Depois de cada golpe o tentáculo fica preso e a
## cabeça fica exposta (dano a dobrar). Fase 2 (vida < 50 %): golpes mais rápidos, dois de cada
## vez, e chama caranguejos ao chegar a 66 % e 33 %. Ao morrer larga o Olho do Polvo.
## Coop (#24): IA no host; o ponto do golpe (net_attack_point) e o estado vão para os clientes,
## que desenham o aviso e o tentáculo.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, IDLE, TELEGRAPH, SLAM, STUCK, DYING }

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const BOSS_ID: StringName = &"octopus"
const BOSS_NAME: String = "POLVO DO NAUFRÁGIO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "olho_do_polvo"
const SLAM_RADIUS: float = 1.9
const WEAK_POINT_MULTIPLIER: float = 2.0
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
const NET_STUN_CAP: float = 1.2

const SKIN: Color = Color(0.62, 0.22, 0.42)
const SKIN_DARK: Color = Color(0.44, 0.13, 0.32)
const SUCKER: Color = Color(0.96, 0.78, 0.74)
const EYE_WHITE: Color = Color(0.98, 0.97, 0.93)
const PUPIL: Color = Color(0.04, 0.04, 0.05)

@export var slam_damage: float = 18.0
@export var telegraph_time: float = 1.1
@export var stuck_time: float = 1.8
@export var idle_time: float = 1.4
@export var emerge_time: float = 2.2
@export var turn_speed: float = 2.0
## Distância máxima a que procura jogadores para atacar.
@export var attack_range: float = 14.0

var state: State = State.EMERGE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if not has_simulation_authority():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _surface_y: float = 0.0
var _reinforce_index: int = 0
var _attack_points: Array[Vector3] = []
var _hit_done: bool = false
var _body_root: Node3D = null
var _tentacles: Array[Node3D] = []
var _slam_tentacles: Array[Node3D] = []
var _warnings: Array[GroundWarning] = []
var _hud: CanvasLayer = null
var _health_bar: ProgressBar = null
var _anim_time: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 3.0
	death_color = SKIN
	_build_model()
	_build_hud()
	for i: int in 2:
		var w: GroundWarning = GroundWarning.new()
		add_child(w)
		_warnings.append(w)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.EMERGE:
			_process_emerge()
		State.IDLE:
			_face_target(delta)
			if _state_time >= idle_time * (0.6 if phase == 2 else 1.0):
				_start_attack()
		State.TELEGRAPH:
			_pulse_warnings(delta)
			if _state_time >= telegraph_time * (0.8 if phase == 2 else 1.0):
				_enter_state(State.SLAM)
		State.SLAM:
			if not _hit_done and _state_time >= 0.12:
				_hit_done = true
				_do_slam_damage()
			if _state_time >= 0.35:
				_enter_state(State.STUCK)
		State.STUCK:
			if _state_time >= stuck_time:
				_enter_state(State.IDLE)


func _process(delta: float) -> void:
	_anim_time += delta
	_animate(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying()
	elif not has_simulation_authority():
		_health_bar.value = health
		if state == State.TELEGRAPH:
			_pulse_warnings(delta)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.EMERGE:
			_surface_y = global_position.y
			global_position.y = _surface_y - 3.0
			SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
		State.TELEGRAPH:
			_show_warnings()
		State.SLAM:
			_hit_done = false
			_hide_warnings()
			SFX.play_at(SFX.EMERGE_SAND, net_attack_point, 4.0)
		State.IDLE:
			_hide_warnings()
	_refresh_slam_tentacles()


func _process_emerge() -> void:
	var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
	global_position.y = _surface_y - 3.0 * (1.0 - (1.0 - pow(1.0 - t, 3.0)))
	if t >= 1.0:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.IDLE)


func _start_attack() -> void:
	var target: Node3D = _update_target(0.0)
	if target == null or target.global_position.distance_to(global_position) > attack_range:
		_state_time = 0.0
		return
	_attack_points.clear()
	_attack_points.append(_ground_point(target.global_position))
	if phase == 2:
		# Segundo golpe a cortar a fuga: um pouco à frente do jogador, para o lado.
		var side: Vector3 = (target.global_position - global_position).cross(Vector3.UP).normalized()
		_attack_points.append(_ground_point(target.global_position + side * 2.4))
	net_attack_point = _attack_points[0]
	_enter_state(State.TELEGRAPH)


func _do_slam_damage() -> void:
	for p: Vector3 in _attack_points:
		spawn_particles(p + Vector3.UP * 0.1, Color(0.85, 0.74, 0.5), 18, 3.0)
		# "players" = todos (coop); sem ele (testes antigos), o jogador local em "player".
		var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
		if players.is_empty():
			players = get_tree().get_nodes_in_group(&"player")
		for n: Node in players:
			var pl: Node3D = n as Node3D
			if pl == null:
				continue
			var d: Vector3 = pl.global_position - p
			d.y = 0.0
			if d.length() <= SLAM_RADIUS:
				_deal_damage(pl, slam_damage)


func _process_dying() -> void:
	var t: float = clampf(_state_time / 2.5, 0.0, 1.0)
	global_position.y = _surface_y - 3.0 * t * t
	if _state_time >= 1.0 and _state_time - get_process_delta_time() < 1.0:
		_drop_trophy()
	if _state_time >= 2.6:
		spawn_particles(global_position + Vector3.UP * 1.5, death_color, 40, 4.0)
		queue_free()


# ---------------------------------------------------------------------------
# Regras de combate
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func is_weak_point_exposed() -> bool:
	return state == State.STUCK


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return state != State.EMERGE and state != State.DYING


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


func stun(seconds: float) -> void:
	super.stun(minf(seconds, NET_STUN_CAP))


## O repelente não afeta o polvo.
func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_health_bar.value = health
	health_changed.emit(health, max_health)
	var ratio: float = health / max_health
	while _reinforce_index < REINFORCE_THRESHOLDS.size() and ratio <= REINFORCE_THRESHOLDS[_reinforce_index]:
		_reinforce_index += 1
		_call_reinforcements()
	if phase == 1 and is_phase_two():
		phase = 2


## Começa já acordado (testes / debug).
func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.IDLE)


func _call_reinforcements() -> void:
	for i: int in 2:
		var ang: float = randf() * TAU
		var pos: Vector3 = Vector3(global_position.x, _surface_y, global_position.z) + Vector3(cos(ang), 0.0, sin(ang)) * 4.0
		pos = _ground_point(pos)
		if _spawn_minion(&"crab", pos) == null:
			var scene: PackedScene = EnemySpawner.scene_for_kind(&"crab")
			if scene != null and get_parent() != null:
				var crab: Node3D = scene.instantiate() as Node3D
				get_parent().add_child(crab)
				crab.global_position = pos


func _on_died() -> void:
	_health_bar.value = 0.0
	_set_stun_fx(false)
	_enter_state(State.DYING)
	set_physics_process(false)


func _drop_trophy() -> void:
	_hud.visible = false
	if has_simulation_authority():
		QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, Vector3(global_position.x, _surface_y + 1.5, global_position.z),
			Vector3(randf_range(-0.6, 0.6), 3.0, randf_range(-0.6, 0.6)) - global_transform.basis.z * 2.0)
	boss_defeated.emit(BOSS_ID)


## O core aceita "octopus" (EXTRA_BOSSES, #45); só o host reporta.
func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _face_target(delta: float) -> void:
	var t: Node3D = _update_target(delta)
	if t == null:
		return
	var to: Vector3 = t.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_turn_towards(to.normalized(), 0.0, turn_speed, delta)


func _ground_point(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground_height(p, _surface_y), p.z)


## Cliente: estado chegou pelo synchronizer.
func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	if new_state != State.EMERGE:
		_hud.visible = new_state != State.DYING
	_refresh_remote_visuals()


func _refresh_remote_visuals() -> void:
	_attack_points = [net_attack_point]
	if state == State.TELEGRAPH:
		_show_warnings()
	else:
		_hide_warnings()
	_refresh_slam_tentacles()


# ---------------------------------------------------------------------------
# Avisos e tentáculos de golpe
# ---------------------------------------------------------------------------

func _show_warnings() -> void:
	for i: int in _warnings.size():
		if i < _attack_points.size():
			_warnings[i].show_circle(_attack_points[i], SLAM_RADIUS)
		else:
			_warnings[i].hide_warning()


func _hide_warnings() -> void:
	for w: GroundWarning in _warnings:
		w.hide_warning()


func _pulse_warnings(delta: float) -> void:
	for w: GroundWarning in _warnings:
		if w.visible:
			w.pulse(delta)


## O tentáculo do golpe sai do chão no ponto atacado (SLAM: cai; STUCK: fica preso).
func _refresh_slam_tentacles() -> void:
	for i: int in _slam_tentacles.size():
		var t: Node3D = _slam_tentacles[i]
		var on: bool = (state == State.SLAM or state == State.STUCK) and i < _attack_points.size()
		t.visible = on
		if on:
			var p: Vector3 = _attack_points[i]
			var away: Vector3 = p - global_position
			away.y = 0.0
			var yaw: float = atan2(away.x, away.z) if away.length_squared() > 0.01 else 0.0
			t.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
			t.scale = Vector3.ONE * 0.2 if state == State.SLAM else Vector3.ONE


func _animate(delta: float) -> void:
	if _body_root == null:
		return
	# Respira e abana os tentáculos à volta da cabeça
	var breathe: float = 1.0 + sin(_anim_time * 2.0) * 0.03
	_body_root.scale = Vector3(breathe, 1.0 / breathe, breathe)
	for i: int in _tentacles.size():
		var tt: Node3D = _tentacles[i]
		tt.rotation.x = -0.35 + sin(_anim_time * 2.2 + float(i) * 1.1) * 0.25
	for t: Node3D in _slam_tentacles:
		if t.visible and t.scale.x < 1.0:
			t.scale = t.scale.lerp(Vector3.ONE, minf(delta * 18.0, 1.0))


# ---------------------------------------------------------------------------
# Modelo low-poly toon e HUD
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"spots_amount", 0.7)
	mat.set_shader_parameter(&"spots_color", Color(0.86, 0.48, 0.62))
	mat.set_shader_parameter(&"spots_scale", 4.0)
	mat.set_shader_parameter(&"spots_size", 0.2)
	_register_flash_material(mat)
	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	add_child(_body_root)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cabeça em forma de bolbo (anéis facetados), um pouco inclinada para trás
	var head_basis: Basis = Basis(Vector3.RIGHT, 0.25)
	CrabModel.gem(st, Transform3D.IDENTITY, Vector3(0.0, 2.2, 0.35), head_basis, [
		Vector3(-0.9, 1.0, 0.95), Vector3(-0.2, 1.25, 1.2), Vector3(0.6, 1.15, 1.1), Vector3(1.3, 0.75, 0.8),
	], 8, -1.2, 1.75, SKIN, 0.05, 71)
	# Olhos enormes (sem pintas: alfa 0) com pupila em fenda horizontal
	for side: float in [-1.0, 1.0]:
		var c: Vector3 = Vector3(0.55 * side, 2.15, -0.75)
		CrabModel.gem(st, Transform3D.IDENTITY, c, Basis.IDENTITY, [
			Vector3(-0.22, 0.24, 0.24), Vector3(0.0, 0.33, 0.33), Vector3(0.22, 0.24, 0.24),
		], 8, -0.33, 0.33, Color(EYE_WHITE.r, EYE_WHITE.g, EYE_WHITE.b, 0.0), 0.0, 72)
		LowPolyMesh.box(st, c + Vector3(0.0, 0.0, -0.3), Vector3(0.3, 0.1, 0.06), Basis.IDENTITY,
			Color(PUPIL.r, PUPIL.g, PUPIL.b, 0.0))
	# Boca/sifão
	LowPolyMesh.prism(st, Vector3(0.0, 1.55, -0.85), Vector3(0.0, 1.5, -1.25), 0.22, 0.16, 6, SKIN_DARK)
	_body_root.add_child(_commit(st, "Head", mat))

	# 8 tentáculos à volta (cada um um nó para abanar)
	for i: int in 8:
		var ang: float = TAU * float(i) / 8.0 + 0.2
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(cos(ang) * 0.9, 1.0, sin(ang) * 0.9)
		pivot.rotation.y = -ang + PI * 0.5
		_body_root.add_child(pivot)
		pivot.add_child(_commit(_tentacle_mesh(2.4, 0.32), "Mesh", mat))
		_tentacles.append(pivot)

	# Tentáculos de golpe (saem do chão no ponto atacado)
	for i: int in 2:
		var slam: Node3D = Node3D.new()
		slam.name = "SlamTentacle%d" % i
		slam.top_level = true
		slam.visible = false
		add_child(slam)
		var m: MeshInstance3D = _commit(_tentacle_mesh(2.6, 0.38, true), "Mesh", mat)
		slam.add_child(m)
		_slam_tentacles.append(slam)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.6, 3.2, 2.6)
	shape.shape = box
	shape.position = Vector3(0.0, 1.8, 0.0)
	add_child(shape)


## Tentáculo: cadeia de troncos de cone que curva para fora e para baixo, com ventosas claras.
## upright = sai do chão e enrola-se no topo (golpe).
func _tentacle_mesh(length: float, radius: float, upright: bool = false) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 6
	var prev: Vector3 = Vector3.ZERO
	for s: int in segs:
		var t: float = float(s + 1) / float(segs)
		var p: Vector3
		if upright:
			p = Vector3(0.0, length * t, -sin(t * PI * 0.9) * 0.6 * t)
		else:
			p = Vector3(0.0, -length * 0.35 * t * t, length * t)
		var r0: float = radius * (1.0 - float(s) / float(segs) * 0.85)
		var r1: float = radius * (1.0 - t * 0.85)
		LowPolyMesh.prism(st, prev, p, r0, r1 if s < segs - 1 else 0.0, 6, SKIN if s % 2 == 0 else SKIN_DARK)
		# Ventosa por baixo (sem pintas)
		var mid: Vector3 = (prev + p) * 0.5
		var under: Vector3 = Vector3(0.0, 0.0, r0 * 0.9) if upright else Vector3(0.0, -r0 * 0.9, 0.0)
		LowPolyMesh.prism(st, mid + under * 0.6, mid + under * 1.1, r0 * 0.45, r0 * 0.35, 6,
			Color(SUCKER.r, SUCKER.g, SUCKER.b, 0.0))
		prev = p
	return st


func _commit(st: SurfaceTool, part_name: String, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	return mi


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "BossHud"
	_hud.layer = 2
	_hud.visible = false
	var panel: VBoxContainer = VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-260.0, 70.0)
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)
	var name_label: Label = Label.new()
	name_label.text = "🐙 " + BOSS_NAME
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(&"font_color", Color(1.0, 0.82, 0.25))
	name_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override(&"outline_size", 6)
	name_label.add_theme_font_size_override(&"font_size", 22)
	panel.add_child(name_label)
	_health_bar = ProgressBar.new()
	_health_bar.custom_minimum_size = Vector2(0.0, 18.0)
	_health_bar.show_percentage = false
	_health_bar.max_value = max_health
	_health_bar.value = health
	_health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.22, 0.48)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.06, 0.08, 0.85)
	_health_bar.add_theme_stylebox_override(&"fill", fill)
	_health_bar.add_theme_stylebox_override(&"background", bg)
	panel.add_child(_health_bar)
	add_child(_hud)
