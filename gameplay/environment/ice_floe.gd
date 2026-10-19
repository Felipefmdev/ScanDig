class_name IceFloe
extends StaticBody3D

## Placa de gelo no Lago Congelado da Geleira Eterna (#108).
## Trinca e quebra com:
##   - Peso parado (ficar sobre a placa acumula tensão progressiva);
##   - Corrida/passos pesados e carrinho de mão carregado;
##   - Explosões de dinamite (quebra imediata dentro do raio).
## Ao quebrar, afunda na água abrindo um buraco gélido.
## Volta a recongelar gradualmente após um tempo.

signal cracked(floe: Node3D, new_state: int)
signal shattered(floe: Node3D)
signal refrozen(floe: Node3D)

const GROUP: StringName = &"ice_floes"

const STATE_INTACT: int = 0
const STATE_CRACKED: int = 1
const STATE_SEVERELY_CRACKED: int = 2
const STATE_BROKEN: int = 3

const STANDING_STRESS_RATE: float = 0.30
const WALK_STRESS_RATE: float = 0.20
const SPRINT_STRESS_RATE: float = 0.45
const REFREEZE_DELAY: float = 16.0
const REFREEZE_SPEED: float = 0.20

@export var floe_id: int = 0
@export var floe_radius: float = 1.65
@export var ice_thickness: float = 0.22

var health: float = 1.0
var state: int = STATE_INTACT

var _time_broken: float = 0.0
var _steppers: Array[Node3D] = []
var _mesh_root: Node3D = null
var _ice_mesh: MeshInstance3D = null
var _crack_mesh: MeshInstance3D = null
var _col_shape: CollisionShape3D = null
var _stepper_area: Area3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(&"damageable")


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0

	_build_collision()
	_build_visuals()
	_build_stepper_area()
	_update_visual_state()


func _physics_process(delta: float) -> void:
	if state == STATE_BROKEN:
		_time_broken += delta
		if _time_broken >= REFREEZE_DELAY:
			_process_refreeze(delta)
		return

	if _steppers.is_empty():
		# Recupera integridade lentamente quando intocada
		if health < 1.0:
			health = clampf(health + 0.06 * delta, 0.0, 1.0)
			_evaluate_state_transition()
		return

	# Acumula estresse de jogadores, carrinhos e inimigos sobre a placa
	var total_stress: float = 0.0
	for body: Node3D in _steppers:
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		if body is CharacterBody3D:
			var cb: CharacterBody3D = body as CharacterBody3D
			var spd: float = Vector2(cb.velocity.x, cb.velocity.z).length()
			var rate: float = STANDING_STRESS_RATE
			if spd > 5.0:
				rate = SPRINT_STRESS_RATE
			elif spd > 0.5:
				rate = WALK_STRESS_RATE
			# Carrinho de mão adiciona sobrecarga proporcional à carga
			if cb.is_in_group(&"wheelbarrows") or "cargo" in cb or cb.has_method("get_push_speed_factor"):
				var cargo_arr: Array = cb.get("cargo") as Array if cb.get("cargo") is Array else []
				rate *= 1.2 + float(cargo_arr.size()) * 0.45
			total_stress += rate
		elif body is RigidBody3D and (body.is_in_group(&"wheelbarrows") or body.is_in_group(&"pickups")):
			total_stress += STANDING_STRESS_RATE

	if total_stress > 0.0:
		take_stress(total_stress * delta)


func take_stress(amount: float) -> void:
	if state == STATE_BROKEN:
		return
	health = clampf(health - amount, 0.0, 1.0)
	_evaluate_state_transition()


func shatter() -> void:
	if state == STATE_BROKEN:
		return
	health = 0.0
	_set_state(STATE_BROKEN)


func apply_blast_damage(epicenter: Vector3, radius: float) -> void:
	var dist: float = global_position.distance_to(epicenter)
	if dist <= radius + floe_radius * 0.5:
		shatter()


func repair(amount: float) -> void:
	health = clampf(health + amount, 0.0, 1.0)
	_evaluate_state_transition()


func is_broken() -> bool:
	return state == STATE_BROKEN


func _evaluate_state_transition() -> void:
	var target_state: int = STATE_INTACT
	if health <= 0.0:
		target_state = STATE_BROKEN
	elif health <= 0.33:
		target_state = STATE_SEVERELY_CRACKED
	elif health <= 0.66:
		target_state = STATE_CRACKED

	if target_state != state:
		_set_state(target_state)


func _set_state(new_state: int) -> void:
	var old_state: int = state
	state = new_state
	_update_visual_state()

	if state == STATE_BROKEN:
		_time_broken = 0.0
		_steppers.clear()
		if _col_shape != null:
			_col_shape.set_deferred("disabled", true)
		SFX.play_at(SFX.STONE_IMPACT, global_position, 1.0, 0.15)
		shattered.emit(self)
	else:
		if _col_shape != null and _col_shape.disabled:
			_col_shape.set_deferred("disabled", false)
		if old_state == STATE_BROKEN:
			refrozen.emit(self)
		elif old_state < new_state:
			SFX.play_at(SFX.FOOTSTEP_SNOW, global_position, -2.0, 0.2)
			cracked.emit(self, state)


func _process_refreeze(delta: float) -> void:
	health = clampf(health + REFREEZE_SPEED * delta, 0.0, 1.0)
	if health >= 0.35:
		_set_state(STATE_CRACKED)
	elif health > 0.0:
		# Gelo fino translúcido começando a fechar
		if _mesh_root != null:
			_mesh_root.visible = true
			_mesh_root.position.y = -(1.0 - health / 0.35) * 0.15


func _update_visual_state() -> void:
	if _mesh_root == null or _ice_mesh == null or _crack_mesh == null:
		return

	match state:
		STATE_INTACT:
			_mesh_root.visible = true
			_mesh_root.position.y = 0.0
			_crack_mesh.visible = false
			var mat: StandardMaterial3D = _ice_mesh.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = Color(0.72, 0.88, 0.98, 0.88)
				mat.roughness = 0.1
		STATE_CRACKED:
			_mesh_root.visible = true
			_mesh_root.position.y = 0.0
			_crack_mesh.visible = true
			var crack_mat: StandardMaterial3D = _crack_mesh.material_override as StandardMaterial3D
			if crack_mat != null:
				crack_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.6)
		STATE_SEVERELY_CRACKED:
			_mesh_root.visible = true
			_mesh_root.position.y = -0.03
			_crack_mesh.visible = true
			var crack_mat: StandardMaterial3D = _crack_mesh.material_override as StandardMaterial3D
			if crack_mat != null:
				crack_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
		STATE_BROKEN:
			_mesh_root.visible = false
			_crack_mesh.visible = false


func _build_collision() -> void:
	_col_shape = CollisionShape3D.new()
	_col_shape.name = "FloeCollision"
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = floe_radius * 0.95
	cyl.height = ice_thickness
	_col_shape.shape = cyl
	_col_shape.position = Vector3(0.0, -ice_thickness * 0.5, 0.0)
	add_child(_col_shape)


func _build_visuals() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)

	# Placa de gelo poligonal facetada (Cylinder 7 lados com topo chanfrado)
	_ice_mesh = MeshInstance3D.new()
	_ice_mesh.name = "IceMesh"
	var cyl_mesh: CylinderMesh = CylinderMesh.new()
	cyl_mesh.top_radius = floe_radius * 0.92
	cyl_mesh.bottom_radius = floe_radius * 0.82
	cyl_mesh.height = ice_thickness
	cyl_mesh.radial_segments = 7
	cyl_mesh.rings = 1
	_ice_mesh.mesh = cyl_mesh
	_ice_mesh.position = Vector3(0.0, -ice_thickness * 0.5, 0.0)

	var ice_mat: StandardMaterial3D = StandardMaterial3D.new()
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.albedo_color = Color(0.72, 0.88, 0.98, 0.88)
	ice_mat.roughness = 0.12
	ice_mat.metallic = 0.05
	ice_mat.specular = 0.8
	_ice_mesh.material_override = ice_mat
	_mesh_root.add_child(_ice_mesh)

	# Linhas/fissuras de trinca no topo da placa
	_crack_mesh = MeshInstance3D.new()
	_crack_mesh.name = "CrackMesh"
	var im: ImmediateMesh = _generate_crack_mesh()
	_crack_mesh.mesh = im

	var crack_mat: StandardMaterial3D = StandardMaterial3D.new()
	crack_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crack_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crack_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_crack_mesh.material_override = crack_mat
	_crack_mesh.position = Vector3(0.0, 0.005, 0.0)
	_mesh_root.add_child(_crack_mesh)


func _generate_crack_mesh() -> ImmediateMesh:
	var im: ImmediateMesh = ImmediateMesh.new()
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = floe_id * 1337 + 42

	# 4 a 6 ramificações radiais de fissura a partir do centro
	var branches: int = 5
	for b: int in branches:
		var base_ang: float = (TAU / float(branches)) * float(b) + rng.randf_range(-0.3, 0.3)
		var p_start: Vector3 = Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15))
		var r_steps: int = 3
		var curr_p: Vector3 = p_start
		for s: int in r_steps:
			var step_r: float = (floe_radius * 0.85 / float(r_steps)) * float(s + 1)
			var cur_ang: float = base_ang + rng.randf_range(-0.35, 0.35)
			var next_p: Vector3 = Vector3(cos(cur_ang) * step_r, 0.0, sin(cur_ang) * step_r)
			im.surface_add_vertex(curr_p)
			im.surface_add_vertex(next_p)

			# Pequena bifurcação lateral
			if s == 1 and rng.randf() > 0.3:
				var side_ang: float = cur_ang + rng.randf_range(0.4, 0.8) * (1.0 if rng.randf() > 0.5 else -1.0)
				var side_p: Vector3 = next_p + Vector3(cos(side_ang) * 0.45, 0.0, sin(side_ang) * 0.45)
				im.surface_add_vertex(next_p)
				im.surface_add_vertex(side_p)

			curr_p = next_p

	im.surface_end()
	return im


func _build_stepper_area() -> void:
	_stepper_area = Area3D.new()
	_stepper_area.name = "StepperArea"
	_stepper_area.collision_layer = 0
	_stepper_area.collision_mask = 1 | (1 << 1) | (1 << 2) # mundo, jogadores e pickups/carrinhos
	_stepper_area.monitorable = false

	var shape: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = floe_radius * 0.90
	cyl.height = 0.40
	shape.shape = cyl
	shape.position = Vector3(0.0, 0.20, 0.0)
	_stepper_area.add_child(shape)

	_stepper_area.body_entered.connect(_on_stepper_entered)
	_stepper_area.body_exited.connect(_on_stepper_exited)
	add_child(_stepper_area)


func _on_stepper_entered(body: Node3D) -> void:
	if body == self:
		return
	if not _steppers.has(body):
		_steppers.append(body)


func _on_stepper_exited(body: Node3D) -> void:
	_steppers.erase(body)
