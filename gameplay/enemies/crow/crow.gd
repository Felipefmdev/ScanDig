class_name Crow
extends Seagull

## Corvo do Campo (#41): voa em círculos como a gaivota e mergulha, mas não rouba: bica
## (peck_damage) e volta a subir. Quem leva uma chave da Dona Lurdes no bico (carries_key,
## replicado) não desiste nem foge: só a larga quando é abatido (DropOnDeath põe a chave onde
## caiu). Abate-se no mergulho com a pá, ou no ar com o estilingue.
## #57: em vez do kamikaze da gaivota, faz a ESPIRAL: círculo à volta do jogador e o corvo
## (todo o bando, se houver vários) voa em espiral cada vez mais apertada e baixa à volta dele
## e no fim bica e atira-o ao ar.

const BLACK: Color = Color(0.08, 0.08, 0.11)
const BLUE_BLACK: Color = Color(0.14, 0.17, 0.25)
const FEATHER_TIP: Color = Color(0.05, 0.05, 0.07)
const BEAK_GREY: Color = Color(0.28, 0.29, 0.32)
const EYE_WHITE: Color = Color(0.98, 0.98, 0.98)
const KEY_GOLD: Color = Color(1.0, 0.8, 0.2)
const LEGS_TAN: Color = Color(0.72, 0.58, 0.36)

## Replicado: leva uma chave no bico.
var carries_key: bool = false:
	set(value):
		carries_key = value
		if value:
			max_dives = 9999
			_leave_timer = -1.0
		if is_node_ready():
			_refresh_key()

var _key_visual: Node3D = null
var _spiral_angle: float = 0.0

const SPIRAL_TELEGRAPH_TIME: float = 0.8
const SPIRAL_TIME: float = 2.4
const SPIRAL_START_RADIUS: float = 3.6
const SPIRAL_END_RADIUS: float = 1.0
const SPIRAL_HIT_RADIUS: float = 1.5


const CROW_GROUND_STEAL_RADIUS: float = 32.0
const CROW_NEST_SCRIPT: Script = preload("res://gameplay/enemies/crow/crow_nest.gd")

var target_nest: Node3D = null
var _stolen_visual: Node3D = null


func _init() -> void:
	caw_sfx = SFX.CROW_CAW
	dive_sfx = SFX.CROW_CAW


func _ready() -> void:
	super._ready()
	_refresh_key()
	_refresh_stolen()
	if has_simulation_authority():
		_ensure_nest()


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:carries_key")


func _ensure_nest() -> void:
	if not is_inside_tree():
		return
	if CROW_NEST_SCRIPT.call("get_nearest_nest", get_tree(), global_position) == null:
		var parent_scene: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
		if parent_scene != null:
			CROW_NEST_SCRIPT.call("ensure_nest_in_scene", parent_scene, Vector3(8.5, 0.1, -14.0))


## Procura achados soltos no chão em raio amplo (#106).
func find_ground_loot(near: Vector3) -> ItemPickup:
	var best: ItemPickup = null
	var best_d: float = CROW_GROUND_STEAL_RADIUS
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or not is_instance_valid(p) or p.is_queued_for_deletion() or p.carried == null:
			continue
		if p.carried.is_tool():
			continue
		var d: float = p.global_position.distance_to(near)
		if d < best_d:
			best = p
			best_d = d
	return best


func _process_circle(delta: float) -> void:
	if has_simulation_authority() and _ground_target == null:
		var loose: ItemPickup = find_ground_loot(global_position)
		if loose != null and _circle_left <= 1.5:
			_ground_target = loose
			_circle_left = randf_range(circle_time_min, circle_time_max)
			SFX.play_at(caw_sfx, global_position, 1.5)
	super._process_circle(delta)


## Bica em vez de roubar quando ataca o jogador.
func _grab(target: Node3D) -> void:
	_on_loot_reply(null, target)


## Um mergulho em cada dois é a espiral (#57).
func _choose_dive(target: Node3D) -> State:
	if _dives % 2 == 1:
		return State.DIVE
	net_dive_point = _ground_point(target.global_position)
	var rel: Vector3 = global_position - target.global_position
	_spiral_angle = atan2(rel.z, rel.x)
	return State.SPIRAL_TELEGRAPH


## Espiral à volta do jogador (o centro segue-o): raio e altura descem até bicar.
func _process_spiral(delta: float) -> void:
	var target: Node3D = _target if is_instance_valid(_target) else null
	if target == null:
		_after_failed_dive()
		return
	net_dive_point = _ground_point(target.global_position)
	var t: float = 0.0 if state == State.SPIRAL_TELEGRAPH else clampf(_state_time / SPIRAL_TIME, 0.0, 1.0)
	var radius: float = lerpf(SPIRAL_START_RADIUS, SPIRAL_END_RADIUS, t * t)
	var height: float = lerpf(2.6, 1.1, t)
	_spiral_angle += _orbit_dir * delta * lerpf(2.5, 6.0, t)
	var goal: Vector3 = net_dive_point + Vector3(cos(_spiral_angle) * radius, height, sin(_spiral_angle) * radius)
	_fly_towards(goal, fly_speed * 2.2, delta, 8.0)
	_dive_warning.show_circle(net_dive_point, SPIRAL_START_RADIUS * 0.6)
	_dive_warning.pulse(delta)
	if state == State.SPIRAL_TELEGRAPH:
		if _state_time >= SPIRAL_TELEGRAPH_TIME:
			SFX.play_at(caw_sfx, global_position, 2.0)
			_enter_state(State.SPIRAL)
		return
	if _state_time >= SPIRAL_TIME:
		for p: Node3D in _players_within(global_position, SPIRAL_HIT_RADIUS + 0.5):
			_deal_damage(p, peck_damage)
			var swirl: Vector3 = (p.global_position - net_dive_point).cross(Vector3.UP).normalized() * _orbit_dir
			_knockback(p, swirl * 5.0 + Vector3.UP * 7.0, 0.05)
		velocity = Vector3.UP * 5.0
		_after_failed_dive()


func _warning_for_state() -> void:
	if state == State.SPIRAL_TELEGRAPH or state == State.SPIRAL:
		_dive_warning.show_circle(net_dive_point, SPIRAL_START_RADIUS * 0.6)
	else:
		_dive_warning.hide_warning()


## Início de fuga: com achado roubado, foge em direção ao ninho (#106).
func _start_escape(away_from: Vector3) -> void:
	if carries_key:
		_dives = 0
		_circle_left = randf_range(circle_time_min, circle_time_max)
		_enter_state(State.CIRCLE)
		return
	if stolen != null:
		target_nest = CROW_NEST_SCRIPT.call("get_nearest_nest", get_tree(), global_position) as Node3D
		if target_nest == null:
			var parent_scene: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
			if parent_scene != null:
				target_nest = CROW_NEST_SCRIPT.call("ensure_nest_in_scene", parent_scene, global_position + Vector3(8.0, 0.0, -8.0)) as Node3D
		_dives = 0
		_leave_timer = despawn_after * 2.0
		_refresh_stolen()
		_enter_state(State.ESCAPE)
		return
	super._start_escape(away_from)


## Fuga: voa baixo em direção ao ninho (#106), permitindo que jogadores o persigam ou atinjam com estilingue.
func _process_escape(delta: float) -> void:
	if target_nest != null and is_instance_valid(target_nest) and stolen != null:
		var perch: Vector3 = target_nest.call("get_perch_point")
		var target_height: float = clampf(perch.y + 1.2, 1.8, 3.8)
		var dest: Vector3 = Vector3(perch.x, target_height, perch.z)
		_fly_towards(dest, escape_speed * 0.85, delta, 4.0)

		if global_position.distance_to(perch) <= 1.4:
			target_nest.call("store_item", stolen)
			stolen = null
			has_stolen = false
			target_nest = null
			_refresh_stolen()
			SFX.play_at(caw_sfx, global_position, 2.5)
			_circle_left = randf_range(circle_time_min, circle_time_max)
			_enter_state(State.CIRCLE)
			return
		return
	super._process_escape(delta)


## Ao sofrer dano (estilingue, pá, etc.), larga o achado imediatamente no chão (#106).
func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	if has_simulation_authority() and stolen != null:
		_drop_stolen_item()
	super.take_damage(amount, from)


func _drop_stolen_item() -> void:
	if stolen == null:
		return
	var item_to_drop: CarriedItem = stolen
	stolen = null
	has_stolen = false
	target_nest = null
	_refresh_stolen()
	var p: Node = get_parent() if get_parent() != null else self
	var drop_pos: Vector3 = global_position + Vector3.DOWN * 0.35
	var impulse: Vector3 = Vector3(velocity.x * 0.15, 2.2, velocity.z * 0.15)
	ItemPickup.spawn(p, item_to_drop, drop_pos, impulse)
	SFX.play_at(SFX.ITEM_IMPACT_STONE, drop_pos, -2.0)
	SFX.play_at(caw_sfx, global_position, 4.0)
	_leave_timer = despawn_after
	_escape_dir = (Vector3.UP * 0.7 + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))).normalized()
	_enter_state(State.ESCAPE)


func _show_loot() -> void:
	_refresh_stolen()


const ITEM_MODELS_SCRIPT: Script = preload("res://items/item_models.gd")


func _refresh_stolen() -> void:
	if _stolen_visual != null:
		_stolen_visual.queue_free()
		_stolen_visual = null
	if not has_stolen and stolen == null:
		return
	var model: Node3D = null
	if stolen != null and stolen.item != null and not stolen.item.id.is_empty():
		model = ITEM_MODELS_SCRIPT.call("build", stolen.item.id, stolen.is_rare_variant) as Node3D
	if model != null:
		model.position = Vector3(0.0, -0.06, -0.42)
		model.scale = Vector3(0.65, 0.65, 0.65)
		_stolen_visual = model
		add_child(_stolen_visual)
	else:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var g: Color = Color(1.0, 0.82, 0.22)
		LowPolyMesh.box(st, Vector3(0.0, -0.06, -0.42), Vector3(0.09, 0.09, 0.09), Basis.IDENTITY, g)
		_stolen_visual = LowPolyMesh.commit(st, "StolenLoot", ToonKit.vertex_material(true, true))
		add_child(_stolen_visual)


func _refresh_key() -> void:
	if _key_visual != null:
		_key_visual.visible = carries_key
		return
	if not carries_key:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g: Color = Color(KEY_GOLD.r, KEY_GOLD.g, KEY_GOLD.b, 0.0)
	LowPolyMesh.prism(st, Vector3(0.0, -0.05, -0.47), Vector3(0.0, -0.2, -0.47), 0.012, 0.012, 4, g)
	LowPolyMesh.box(st, Vector3(0.025, -0.18, -0.47), Vector3(0.04, 0.015, 0.012), Basis.IDENTITY, g)
	LowPolyMesh.prism(st, Vector3(0.0, -0.02, -0.47), Vector3(0.0, -0.06, -0.47), 0.035, 0.035, 6, g)
	_key_visual = LowPolyMesh.commit(st, "Key", ToonKit.vertex_material(true, true))
	add_child(_key_visual)


# ---------------------------------------------------------------------------
# Modelo: corvo preto-azulado, olhos grandes, bico cinzento
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	_register_flash_material(mat)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Corpo rechonchudo azul-escuro / preto (corvo.jpg)
	LowPolyMesh.prism(st, Vector3(0.0, -0.06, 0.18), Vector3(0.0, 0.04, -0.14), 0.16, 0.18, 7, BLACK)
	LowPolyMesh.box(st, Vector3(0.0, 0.02, 0.02), Vector3(0.26, 0.22, 0.30), Basis(Vector3.RIGHT, 0.15), BLUE_BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, -0.10, 0.14), Vector3(0.0, -0.04, -0.10), 0.13, 0.15, 6, FEATHER_TIP)

	# Cauda em leque escalonada com penas recortadas (corvo.jpg)
	for k: int in 4:
		var a: float = (float(k) - 1.5) * 0.18
		LowPolyMesh.box(st, Vector3(sin(a) * 0.10, 0.04, 0.36), Vector3(0.065, 0.02, 0.24), Basis(Vector3.UP, a), FEATHER_TIP)

	# Pescoço e Cabeça com penacho rebelde (corvo.jpg)
	LowPolyMesh.box(st, Vector3(0.0, 0.10, -0.15), Vector3(0.18, 0.14, 0.16), Basis(Vector3.RIGHT, -0.2), BLUE_BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.14, -0.20), Vector3(0.0, 0.30, -0.20), 0.14, 0.11, 7, BLUE_BLACK)
	LowPolyMesh.box(st, Vector3(0.0, 0.20, -0.22), Vector3(0.20, 0.18, 0.18), Basis.IDENTITY, BLACK)

	# Penacho punk espetado no topo e nuca (corvo.jpg)
	LowPolyMesh.prism(st, Vector3(0.0, 0.26, -0.18), Vector3(0.0, 0.40, -0.12), 0.045, 0.005, 4, BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.27, -0.24), Vector3(0.0, 0.38, -0.22), 0.035, 0.005, 4, BLUE_BLACK)
	LowPolyMesh.prism(st, Vector3(-0.06, 0.25, -0.16), Vector3(-0.08, 0.37, -0.10), 0.035, 0.005, 4, BLACK)
	LowPolyMesh.prism(st, Vector3(0.06, 0.25, -0.16), Vector3(0.08, 0.37, -0.10), 0.035, 0.005, 4, BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.18, -0.10), Vector3(0.0, 0.29, -0.04), 0.045, 0.01, 4, FEATHER_TIP)

	# Olhos arregalados cómicos (corvo.jpg)
	for s: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.09 * s, 0.27, -0.22), Vector3(0.065, 0.075, 0.075), Basis.IDENTITY, EYE_WHITE)
		LowPolyMesh.box(st, Vector3(0.12 * s, 0.27, -0.24), Vector3(0.025, 0.035, 0.035), Basis.IDENTITY, EYE_BLACK)
		LowPolyMesh.box(st, Vector3(0.09 * s, 0.32, -0.22), Vector3(0.05, 0.015, 0.06), Basis(Vector3.FORWARD, 0.3 * s), BLACK)

	# Bico de corvo robusto e curvo/adunco cinza escuro (corvo.jpg)
	LowPolyMesh.box(st, Vector3(0.0, 0.18, -0.32), Vector3(0.12, 0.09, 0.12), Basis(Vector3.RIGHT, -0.1), BEAK_GREY)
	LowPolyMesh.prism(st, Vector3(0.0, 0.17, -0.32), Vector3(0.0, 0.12, -0.48), 0.06, 0.02, 5, BEAK_GREY)
	LowPolyMesh.prism(st, Vector3(0.0, 0.12, -0.46), Vector3(0.0, 0.04, -0.52), 0.035, 0.0, 4, Color(0.20, 0.19, 0.20)) # gancho para baixo
	# Mandíbula inferior (ligeiramente aberta)
	LowPolyMesh.box(st, Vector3(0.0, 0.11, -0.33), Vector3(0.09, 0.04, 0.10), Basis(Vector3.RIGHT, 0.08), BEAK_GREY)
	LowPolyMesh.prism(st, Vector3(0.0, 0.11, -0.34), Vector3(0.0, 0.08, -0.44), 0.04, 0.01, 4, Color(0.20, 0.19, 0.20))

	# Patas acastanhadas com garras finas (corvo.jpg)
	for s: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.06 * s, -0.12, 0.08), Vector3(0.022, 0.10, 0.022), Basis(Vector3.RIGHT, 0.2), LEGS_TAN)
		LowPolyMesh.box(st, Vector3(0.06 * s, -0.17, 0.06), Vector3(0.07, 0.016, 0.09), Basis(Vector3.UP, -0.2 * s), LEGS_TAN)
		LowPolyMesh.prism(st, Vector3(0.06 * s, -0.17, 0.06), Vector3(0.06 * s, -0.18, -0.02), 0.035, 0.0, 3, Color(0.25, 0.22, 0.18))

	add_child(LowPolyMesh.commit(st, "Body", mat))
	_wing_left = _build_crow_wing(-1.0, mat)
	_wing_right = _build_crow_wing(1.0, mat)


func _build_crow_wing(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "WingLeft" if side < 0.0 else "WingRight"
	pivot.position = Vector3(0.11 * side, 0.06, -0.02)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Base da asa
	LowPolyMesh.box(st, Vector3(0.12 * side, 0.01, 0.0), Vector3(0.24, 0.035, 0.22), Basis.IDENTITY, BLACK)
	LowPolyMesh.box(st, Vector3(0.32 * side, 0.02, 0.02), Vector3(0.30, 0.028, 0.20), Basis(Vector3.UP, 0.12 * side), BLUE_BLACK)
	LowPolyMesh.box(st, Vector3(0.54 * side, 0.03, 0.06), Vector3(0.26, 0.022, 0.16), Basis(Vector3.UP, 0.25 * side), BLUE_BLACK)

	# Penas de vôo pontiagudas e recortadas (corvo.jpg)
	for k: int in 4:
		LowPolyMesh.box(st, Vector3((0.64 + 0.035 * k) * side, 0.02, 0.02 + 0.045 * k), Vector3(0.16 - 0.015 * k, 0.018, 0.045),
			Basis(Vector3.UP, (0.32 + 0.12 * k) * side), FEATHER_TIP)

	pivot.add_child(LowPolyMesh.commit(st, "Mesh", mat))
	add_child(pivot)
	return pivot

