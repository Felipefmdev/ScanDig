extends EnemyBase

## #120 lunar guardian: host combat, replica presentation and deferred progress report.
## Rock/amethyst grammar from o_que_dorme.jpg, without the Sleeper AI.
signal boss_defeated(boss_id: StringName)

enum State { TELEGRAPH, STRIKE, EXPOSED, COOLDOWN, DYING }

const BOSS_ID: StringName = &"lunar_warden"
const TELEGRAPH_TIME: float = 1.6
const STRIKE_TIME: float = 0.3
const EXPOSED_TIME: float = 5.2
const COOLDOWN_TIME: float = 2.2
const LANE_LENGTH: float = 6.0
const LANE_HALF_WIDTH: float = 1.0
const STRIKE_DAMAGE: float = 20.0
const STONE: Color = Color("#4a4440")
const DARK: Color = Color("#2e2a28")
const AMETHYST: Color = Color("#9a3ae8")

var state: State = State.TELEGRAPH
var net_attack_origin: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_origin = value
		_refresh_visuals()
var net_attack_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_attack_dir = value
		_refresh_visuals()
var net_phase_elapsed: float = 0.0:
	set(value):
		net_phase_elapsed = value
		_refresh_visuals()

var _body: Node3D = null
var _core: MeshInstance3D = null
var _warning: GroundWarning = null
var _hud: BossHud = null
var _attack_locked: bool = false
var _strike_done: bool = false
var _reported: bool = false
var _defeat_reporter: Callable = Callable()
var _warning_state: int = -1
var _warning_origin: Vector3 = Vector3.INF
var _warning_direction: Vector3 = Vector3.INF


func _ready() -> void:
	max_health = 600.0
	super._ready()
	add_to_group(&"bosses")
	collision_layer = 8
	collision_mask = 1
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_hud = BossHud.create(tr("GUARDIÃO DO SINAL"),max_health,AMETHYST)
	add_child(_hud)
	_hud.visible = true
	if has_simulation_authority():
		net_attack_origin = global_position
	_refresh_visuals()


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_origin")
	_add_synced_property(".:net_attack_dir")
	_add_synced_property(".:net_phase_elapsed",true)


func get_combat_state() -> StringName:
	match state:
		State.TELEGRAPH: return &"TELEGRAPH"
		State.STRIKE: return &"STRIKE"
		State.EXPOSED: return &"EXPOSED"
		State.COOLDOWN: return &"COOLDOWN"
	return &"DYING"


func get_weak_point_position() -> Vector3:
	return _core.global_position if is_instance_valid(_core) else global_position + Vector3.UP*1.15


## Integration seam, not an RPC. The default reports through the existing core.
func set_defeat_reporter(callback: Callable) -> void:
	_defeat_reporter = callback


func _enemy_physics(delta: float) -> void:
	if not has_simulation_authority() or not is_alive():
		return
	if state == State.TELEGRAPH and not _attack_locked:
		_lock_attack()
	net_phase_elapsed += maxf(0.0,delta)
	match state:
		State.TELEGRAPH:
			if net_phase_elapsed >= TELEGRAPH_TIME:
				_enter_state(State.STRIKE)
		State.STRIKE:
			if net_phase_elapsed >= STRIKE_TIME:
				_enter_state(State.EXPOSED)
		State.EXPOSED:
			if net_phase_elapsed >= EXPOSED_TIME:
				_enter_state(State.COOLDOWN)
		State.COOLDOWN:
			if net_phase_elapsed >= COOLDOWN_TIME:
				_enter_state(State.TELEGRAPH)


func _lock_attack() -> void:
	net_attack_origin = global_position
	var nearest: float = INF
	var direction: Vector3 = Vector3.FORWARD
	for target: Node3D in _all_players():
		var offset: Vector3 = target.global_position-global_position
		offset.y = 0.0
		if offset.length_squared() > 0.001 and offset.length_squared() < nearest:
			nearest = offset.length_squared()
			direction = offset.normalized()
	net_attack_dir = direction
	_attack_locked = true


func _enter_state(next: State) -> void:
	state = next
	net_phase_elapsed = 0.0
	if next == State.TELEGRAPH:
		_attack_locked = false
		_strike_done = false
		_lock_attack()
	elif next == State.STRIKE:
		_apply_strike()
	_refresh_visuals()


func _apply_strike() -> void:
	if _strike_done or not has_simulation_authority():
		return
	_strike_done = true
	var direction: Vector3 = net_attack_dir.normalized()
	var side: Vector3 = Vector3(-direction.z,0.0,direction.x)
	for target: Node3D in _all_players():
		var offset: Vector3 = target.global_position-net_attack_origin
		var along: float = offset.dot(direction)
		if along < 0.0 or along > LANE_LENGTH:
			continue
		if absf(offset.dot(side)) > LANE_HALF_WIDTH or absf(offset.y) > 2.0:
			continue
		_deal_damage(target,STRIKE_DAMAGE)


func _can_take_damage() -> bool:
	return state == State.EXPOSED


func _can_be_stunned() -> bool:
	return false


func flee_from(_origin: Vector3, _seconds: float) -> void:
	# Optional tools can deal damage, but cannot bypass or freeze this cycle.
	pass


func _on_died() -> void:
	state = State.DYING
	_refresh_visuals()
	if has_simulation_authority() and not _reported:
		_reported = true
		boss_defeated.emit(BOSS_ID)
		if _defeat_reporter.is_valid():
			_defeat_reporter.call(String(BOSS_ID))
		elif GameState.instance != null:
			# Avoid retaining a guest RPC sender context in the core host request.
			GameState.instance.request_report_boss_defeated.call_deferred(String(BOSS_ID))
	queue_free()


func _on_remote_state(_new_state: int) -> void:
	_refresh_visuals()


func _process(_delta: float) -> void:
	# Replicas display host fields; they never advance the combat clock.
	_refresh_visuals()


func _refresh_visuals() -> void:
	if not is_node_ready() or _body == null:
		return
	var exposed: bool = state == State.EXPOSED
	# Project the exposed crystal through the front (+Z) of the rock torso.
	_core.position = Vector3(0.0,1.15 if exposed else 2.05,1.1 if exposed else 0.0)
	_core.scale = Vector3.ONE*(1.25 if exposed else 0.65)
	_body.rotation.x = 0.16 if exposed else 0.0
	if _hud != null:
		_hud.set_health(health)
		_hud.visible = state != State.DYING
	if _warning != null:
		if state == State.TELEGRAPH or state == State.STRIKE:
			if _warning_state != int(state) or _warning_origin != net_attack_origin or _warning_direction != net_attack_dir:
				_warning.show_line(net_attack_origin,net_attack_dir,LANE_LENGTH,LANE_HALF_WIDTH*2.0)
				_warning_origin = net_attack_origin
				_warning_direction = net_attack_dir
		else:
			_warning.hide_warning()
		_warning_state = int(state)


func _build_model() -> void:
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = &"BodyCollision"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.65
	capsule.height = 2.4
	shape.shape = capsule
	shape.position.y = 1.2
	add_child(shape)
	_body = Node3D.new()
	_body.name = &"RockBody"
	add_child(_body)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st,Vector3(0,0.1,0),Vector3(0,1.7,0),0.8,1.0,7,STONE)
	LowPolyMesh.prism(st,Vector3(0,1.7,0),Vector3(0,2.8,0),1.0,0.55,6,DARK)
	for side: float in [-1.0,1.0]:
		LowPolyMesh.prism(st,Vector3(side*0.8,1.8,0),Vector3(side*1.25,0.4,-0.15),0.32,0.18,5,STONE)
		for eye: int in 2:
			LowPolyMesh.box(st,Vector3(side*(0.18+0.18*eye),2.4-0.18*eye,0.62),Vector3(0.14,0.12,0.08),Basis.IDENTITY,AMETHYST)
	var rock_material: ShaderMaterial = ToonKit.vertex_material(true,true)
	_body.add_child(LowPolyMesh.commit(st,"FacetedStone",rock_material))
	_register_flash_material(rock_material)
	var crystals: SurfaceTool = SurfaceTool.new()
	crystals.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 5:
		var angle: float = TAU*float(i)/5.0
		var base: Vector3 = Vector3(cos(angle)*0.7,2.1,sin(angle)*0.6)
		LowPolyMesh.prism(crystals,base,base+Vector3(cos(angle)*0.3,0.8+0.12*(i%2),sin(angle)*0.3),0.18,0.0,5,AMETHYST)
	_body.add_child(LowPolyMesh.commit(crystals,"AmethystCrown",ToonKit.vertex_material(true,true)))
	var core: SurfaceTool = SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(core,Vector3(0,-0.25,0),Vector3(0,0.25,0),0.35,0.12,6,AMETHYST)
	_core = LowPolyMesh.commit(core,"ExposedCore",ToonKit.vertex_material(true,true))
	add_child(_core)
