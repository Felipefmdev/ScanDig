class_name Wheelbarrow
extends CharacterBody3D

## Carrinho de mão físico (#104).
## Transporta até MAX_CAPACITY (5) achados extra pelo mundo.
## Tomba em ladeiras íngremes (> 26°), colisões e explosões/empurrões,
## derramando toda a carga e rachando achados frágeis (#93).
## No coop: qualquer jogador pode empurrar; o host decide a física e o derrame.

signal cargo_changed(count: int, max_capacity: int)
signal tipped()
signal uprighted()

const GROUP: StringName = &"wheelbarrows"
const MAX_CAPACITY: int = 5
const MAX_SLOPE_DEG: float = 26.0
const TIP_IMPULSE_THRESHOLD: float = 6.0
const TIP_CRACK_DAMAGE: float = 0.40 # 40% de dano de impacto à integridade dos itens frágeis
const GRAVITY: float = 16.0

@export var start_tipped: bool = false

var cargo: Array[CarriedItem] = []
var is_tipped: bool = false
var pushing_player: Player = null
var pushing_peer_id: int = 0

var _mesh_root: Node3D = null
var _cargo_visual_root: Node3D = null
var _wheel_mesh: MeshInstance3D = null
var _wheel_rot: float = 0.0
var _tip_cooldown: float = 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(&"damageable")


func _ready() -> void:
	collision_layer = 1 | (1 << 2) # camada de mundo e objetos interativos
	collision_mask = 1 # colide com o chão/terreno (GROUND_MASK)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.name = "Collision"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.75, 0.65, 1.25)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 0.42, 0.0)
	add_child(col_shape)

	_build_visuals()
	_update_prompt()

	if start_tipped:
		tip_over()


func _physics_process(delta: float) -> void:
	if _tip_cooldown > 0.0:
		_tip_cooldown -= delta

	# Se tombado: apenas gravidade e amortecimento
	if is_tipped:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.x = lerpf(velocity.x, 0.0, 8.0 * delta)
			velocity.z = lerpf(velocity.z, 0.0, 8.0 * delta)
		move_and_slide()
		return

	# Se empurrado por um jogador:
	if pushing_player != null and is_instance_valid(pushing_player):
		if not pushing_player.is_alive() or pushing_player.is_downed:
			stop_pushing()
			return

		# Posiciona e guia o carrinho à frente do jogador
		var fwd: Vector3 = -pushing_player.global_transform.basis.z
		var target_pos: Vector3 = pushing_player.global_position + fwd * 1.55
		var dir: Vector3 = target_pos - global_position
		dir.y = 0.0 # controle horizontal suave

		velocity.x = dir.x * 12.0
		velocity.z = dir.z * 12.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		rotation.y = lerp_angle(rotation.y, pushing_player.rotation.y, 14.0 * delta)

		# Rotação visual da roda dianteira
		_wheel_rot += Vector2(velocity.x, velocity.z).length() * delta * 5.0
		if _wheel_mesh != null:
			_wheel_mesh.rotation.x = _wheel_rot

		move_and_slide()

		# Verificação de ladeira forte sob o carrinho
		if is_on_floor() and _tip_cooldown <= 0.0:
			var normal: Vector3 = get_floor_normal()
			var slope: float = rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
			if slope > MAX_SLOPE_DEG:
				var slide_dir: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
				tip_over(slide_dir * 4.0)
		return

	# Desengatado: gravidade e estabilidade no solo
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Em ladeiras muito íngremes, escorrega se solto
		var normal: Vector3 = get_floor_normal()
		var slope: float = rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
		if slope > MAX_SLOPE_DEG + 3.0:
			var slide_dir: Vector3 = Vector3(normal.x, 0.0, normal.z).normalized()
			velocity.x += slide_dir.x * 9.8 * delta
			velocity.z += slide_dir.z * 9.8 * delta
			if _tip_cooldown <= 0.0:
				tip_over(slide_dir * 5.0)
		else:
			velocity.x = lerpf(velocity.x, 0.0, 6.0 * delta)
			velocity.z = lerpf(velocity.z, 0.0, 6.0 * delta)

	move_and_slide()


func get_push_speed_factor() -> float:
	# Carga cheia pesa mais: 85% de velocidade vazia até ~70% totalmente carregada
	return clampf(0.85 - float(cargo.size()) * 0.03, 0.65, 0.85)


func can_add_item() -> bool:
	return not is_tipped and cargo.size() < MAX_CAPACITY


func add_item(item: CarriedItem) -> bool:
	if not can_add_item() or item == null:
		return false
	cargo.append(item)
	_update_cargo_visuals()
	_update_prompt()
	cargo_changed.emit(cargo.size(), MAX_CAPACITY)
	SFX.play_at(SFX.ITEM_IMPACT_STONE, global_position, -4.0, 0.1)
	return true


func remove_last_item() -> CarriedItem:
	if cargo.is_empty():
		return null
	var item: CarriedItem = cargo.pop_back()
	_update_cargo_visuals()
	_update_prompt()
	cargo_changed.emit(cargo.size(), MAX_CAPACITY)
	return item


func start_pushing(player: Player) -> bool:
	if is_tipped or player == null:
		return false
	pushing_player = player
	pushing_peer_id = player.multiplayer.get_unique_id() if player.multiplayer.has_multiplayer_peer() else 1
	add_collision_exception_with(pushing_player)
	pushing_player.add_collision_exception_with(self)
	_update_prompt()
	return true


func stop_pushing() -> void:
	if pushing_player != null:
		remove_collision_exception_with(pushing_player)
		pushing_player.remove_collision_exception_with(self)
		if pushing_player.has_method("on_wheelbarrow_released"):
			pushing_player.call("on_wheelbarrow_released", self)
		pushing_player = null
	pushing_peer_id = 0
	_update_prompt()


func tip_over(scatter_impulse: Vector3 = Vector3.ZERO) -> void:
	if is_tipped:
		return
	is_tipped = true
	_tip_cooldown = 1.2

	stop_pushing()
	_spill_cargo(scatter_impulse)

	if _mesh_root != null:
		var t: Tween = create_tween()
		var roll_side: float = 1.0 if randf() > 0.5 else -1.0
		t.tween_property(_mesh_root, "rotation:z", deg_to_rad(74.0 * roll_side), 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_mesh_root, "position:y", 0.12, 0.2)

	SFX.play_at(SFX.ITEM_IMPACT_STONE, global_position, 3.0, 0.15)
	_update_prompt()
	tipped.emit()


func upright_cart() -> void:
	if not is_tipped:
		return
	is_tipped = false
	_tip_cooldown = 0.5

	if _mesh_root != null:
		var t: Tween = create_tween()
		t.tween_property(_mesh_root, "rotation:z", 0.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_mesh_root, "position:y", 0.0, 0.2)

	SFX.play_at(SFX.STONE_IMPACT, global_position, -2.0, 0.1)
	_update_prompt()
	uprighted.emit()


func apply_impulse(imp: Vector3) -> void:
	velocity += imp
	if imp.length() >= TIP_IMPULSE_THRESHOLD:
		tip_over(imp)


func apply_knockback(imp: Vector3, _duration: float = 0.0) -> void:
	apply_impulse(imp)


func take_damage(_dmg: float, from_pos: Vector3 = Vector3.ZERO) -> void:
	var dir: Vector3 = (global_position - from_pos).normalized() if from_pos != Vector3.ZERO else Vector3.UP
	apply_impulse((dir + Vector3.UP * 0.6).normalized() * 8.5)


func deliver_cargo(sell_point: SellPoint) -> int:
	if cargo.is_empty() or sell_point == null:
		return 0
	var deliverable: Array[CarriedItem] = []
	var remaining: Array[CarriedItem] = []
	for c: CarriedItem in cargo:
		if SellPoint.can_deliver(c):
			deliverable.append(c)
		else:
			remaining.append(c)
	if deliverable.is_empty():
		return 0
	cargo = remaining
	_update_cargo_visuals()
	_update_prompt()
	cargo_changed.emit(cargo.size(), MAX_CAPACITY)
	return sell_point.deliver(deliverable)


func _spill_cargo(scatter_impulse: Vector3) -> void:
	if cargo.is_empty():
		return
	var parent: Node = get_parent() if get_parent() != null else self
	for item: CarriedItem in cargo:
		if item == null:
			continue
		# Achados frágeis racham (#93)
		if item.item != null and item.item.fragility > 0.0:
			item.damage_integrity(item.item.fragility * TIP_CRACK_DAMAGE)

		var spawn_pos: Vector3 = global_position + Vector3(randf_range(-0.35, 0.35), 0.45, randf_range(-0.35, 0.35))
		var scatter: Vector3 = Vector3(randf_range(-1.0, 1.0), 1.2, randf_range(-1.0, 1.0)).normalized() * 3.2
		if scatter_impulse.length_squared() > 0.1:
			scatter += scatter_impulse.normalized() * 3.0
		ItemPickup.spawn(parent, item, spawn_pos, scatter)

	cargo.clear()
	_update_cargo_visuals()
	cargo_changed.emit(0, MAX_CAPACITY)


const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")
const ITEM_MODELS_SCRIPT: Script = preload("res://items/item_models.gd")

const RUST_METAL: Color = Color(0.36, 0.38, 0.40)
const RUST_DARK: Color = Color(0.24, 0.24, 0.26)
const WOOD_PLANK: Color = Color(0.50, 0.34, 0.20)
const WOOD_DARK: Color = Color(0.35, 0.22, 0.12)
const TIRE_RUBBER: Color = Color(0.14, 0.14, 0.16)

var _wheel_root: Node3D = null


func _build_visuals() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "ModelRoot"
	add_child(_mesh_root)

	var mat_metal: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", RUST_METAL)
	mat_metal.set_shader_parameter(&"rust_amount", 0.55)
	mat_metal.set_shader_parameter(&"rust_color", Color(0.48, 0.22, 0.10))

	var mat_wood: ShaderMaterial = ToolMesh.prop_material(&"wood", WOOD_PLANK)
	mat_wood.set_shader_parameter(&"grain_scale", 16.0)

	var mat_dark: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", RUST_DARK)
	mat_dark.set_shader_parameter(&"rust_amount", 0.35)

	var st_wood: SurfaceTool = ToolMesh.begin()
	var st_metal: SurfaceTool = ToolMesh.begin()

	# 1. Fundo da caçamba: tábuas de madeira rústica com vigas
	for k: int in 3:
		var x_off: float = (float(k) - 1.0) * 0.22
		LowPolyMesh.box(st_wood, Vector3(x_off, 0.32, -0.05), Vector3(0.20, 0.045, 0.86), Basis.IDENTITY, WOOD_PLANK)
	LowPolyMesh.box(st_wood, Vector3(0.0, 0.28, -0.32), Vector3(0.66, 0.04, 0.06), Basis.IDENTITY, WOOD_DARK)
	LowPolyMesh.box(st_wood, Vector3(0.0, 0.28, 0.22), Vector3(0.66, 0.04, 0.06), Basis.IDENTITY, WOOD_DARK)

	# 2. Laterais da caçamba de madeira com reforços de ferro enferrujado
	for side: float in [-1.0, 1.0]:
		var wall_b: Basis = Basis(Vector3.FORWARD, deg_to_rad(-8.0 * side))
		LowPolyMesh.box(st_wood, Vector3(side * 0.33, 0.47, -0.05), Vector3(0.04, 0.28, 0.86), wall_b, WOOD_PLANK)
		for z_pos: float in [-0.40, 0.0, 0.35]:
			LowPolyMesh.box(st_metal, Vector3(side * 0.355, 0.47, z_pos), Vector3(0.015, 0.29, 0.04), wall_b, RUST_METAL)
			LowPolyMesh.box(st_metal, Vector3(side * 0.365, 0.54, z_pos), Vector3(0.012, 0.02, 0.02), wall_b, RUST_DARK)
			LowPolyMesh.box(st_metal, Vector3(side * 0.365, 0.40, z_pos), Vector3(0.012, 0.02, 0.02), wall_b, RUST_DARK)

	# Parede traseira
	var b_wall_b: Basis = Basis(Vector3.RIGHT, deg_to_rad(6.0))
	LowPolyMesh.box(st_wood, Vector3(0.0, 0.47, 0.38), Vector3(0.66, 0.28, 0.04), b_wall_b, WOOD_PLANK)

	# Parede dianteira
	var f_wall_b: Basis = Basis(Vector3.RIGHT, deg_to_rad(-16.0))
	LowPolyMesh.box(st_wood, Vector3(0.0, 0.45, -0.47), Vector3(0.66, 0.26, 0.04), f_wall_b, WOOD_PLANK)

	# Borda superior de metal com cantoneiras de ferro enferrujado
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st_metal, Vector3(side * 0.34, 0.61, -0.05), Vector3(0.03, 0.02, 0.88), Basis.IDENTITY, RUST_METAL)
	LowPolyMesh.box(st_metal, Vector3(0.0, 0.61, 0.39), Vector3(0.68, 0.02, 0.03), Basis.IDENTITY, RUST_METAL)
	LowPolyMesh.box(st_metal, Vector3(0.0, 0.58, -0.52), Vector3(0.68, 0.02, 0.03), Basis.IDENTITY, RUST_METAL)

	# 3. Braços / varais de madeira que vão até as manoplas
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st_wood, Vector3(side * 0.28, 0.48, 0.35), Vector3(0.055, 0.055, 0.90), Basis(Vector3.RIGHT, deg_to_rad(-5.0)), WOOD_DARK)
		LowPolyMesh.prism(st_wood, Vector3(side * 0.28, 0.52, 0.72), Vector3(side * 0.28, 0.54, 0.92), 0.022, 0.02, 6, WOOD_PLANK)

	# 4. Pés traseiros de apoio em ferro forjado
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st_metal, Vector3(side * 0.26, 0.30, 0.28), Vector3(side * 0.26, 0.06, 0.30), 0.022, 0.022, 4, RUST_DARK)
		LowPolyMesh.box(st_metal, Vector3(side * 0.26, 0.05, 0.30), Vector3(0.06, 0.015, 0.08), Basis.IDENTITY, RUST_DARK)
		LowPolyMesh.prism(st_metal, Vector3(side * 0.26, 0.06, 0.30), Vector3(side * 0.26, 0.30, 0.05), 0.016, 0.016, 4, RUST_METAL)

	# Garfo dianteiro de suporte da roda
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st_metal, Vector3(side * 0.18, 0.30, -0.38), Vector3(side * 0.09, 0.20, -0.58), 0.022, 0.018, 4, RUST_DARK)

	ToolMesh.part(_mesh_root, "Wood", st_wood, mat_wood)
	ToolMesh.part(_mesh_root, "MetalRust", st_metal, mat_metal)

	# 5. Roda giratória dianteira (com pneu, aro e raios)
	_wheel_root = Node3D.new()
	_wheel_root.name = "WheelRoot"
	_wheel_root.position = Vector3(0.0, 0.20, -0.58)
	_mesh_root.add_child(_wheel_root)

	var st_wheel_rubber: SurfaceTool = ToolMesh.begin()
	var st_wheel_metal: SurfaceTool = ToolMesh.begin()

	ToolMesh.y_prism(st_wheel_rubber, Vector3.ZERO, -0.045, 0.045, 0.21, 0.21, 14, 0.0, TIRE_RUBBER)
	ToolMesh.y_prism(st_wheel_metal, Vector3.ZERO, -0.04, 0.04, 0.16, 0.16, 12, 0.0, RUST_METAL)
	ToolMesh.y_prism(st_wheel_metal, Vector3.ZERO, -0.07, 0.07, 0.05, 0.05, 8, 0.0, RUST_DARK)
	for i: int in 4:
		var ang: float = float(i) * (PI * 0.25)
		LowPolyMesh.box(st_wheel_metal, Vector3.ZERO, Vector3(0.018, 0.30, 0.018), Basis(Vector3.FORWARD, ang), RUST_DARK)

	var mat_rubber: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", TIRE_RUBBER)
	mat_rubber.set_shader_parameter(&"rust_amount", 0.1)

	var w_metal_inst: MeshInstance3D = ToolMesh.part(_wheel_root, "WheelMetal", st_wheel_metal, mat_dark)
	w_metal_inst.rotation.z = deg_to_rad(90.0)

	var w_rubber_inst: MeshInstance3D = ToolMesh.part(_wheel_root, "WheelRubber", st_wheel_rubber, mat_rubber)
	w_rubber_inst.rotation.z = deg_to_rad(90.0)

	# 6. Carga visual dentro da caçamba
	_cargo_visual_root = Node3D.new()
	_cargo_visual_root.name = "CargoVisuals"
	_cargo_visual_root.position = Vector3(0.0, 0.36, -0.05)
	_mesh_root.add_child(_cargo_visual_root)


func _update_cargo_visuals() -> void:
	if _cargo_visual_root == null:
		return
	for child: Node in _cargo_visual_root.get_children():
		child.queue_free()

	var offsets: Array[Vector3] = [
		Vector3(-0.16, 0.04, -0.20),
		Vector3(0.16, 0.04, -0.20),
		Vector3(0.0, 0.05, 0.02),
		Vector3(-0.16, 0.04, 0.22),
		Vector3(0.16, 0.04, 0.22),
	]

	for i: int in cargo.size():
		if i >= offsets.size():
			break
		var item: CarriedItem = cargo[i]
		if item == null:
			continue
		var model: Node3D = null
		if item.item != null and not item.item.id.is_empty():
			model = ITEM_MODELS_SCRIPT.call("build", item.item.id, item.is_rare_variant) as Node3D
		if model != null:
			model.position = offsets[i]
			model.rotation.y = float(i) * 0.7
			model.scale = Vector3(1.1, 1.1, 1.1)
			_cargo_visual_root.add_child(model)
		else:
			var p: MeshInstance3D = MeshInstance3D.new()
			var b: BoxMesh = BoxMesh.new()
			b.size = Vector3(0.22, 0.14, 0.24)
			p.mesh = b
			var parcel_mat: StandardMaterial3D = StandardMaterial3D.new()
			parcel_mat.albedo_color = Color(0.72, 0.58, 0.36)
			p.material_override = parcel_mat
			p.position = offsets[i]
			p.rotation.y = float(i) * 0.4
			_cargo_visual_root.add_child(p)


func _update_prompt() -> void:
	pass
