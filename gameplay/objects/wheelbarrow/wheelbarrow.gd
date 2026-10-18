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
var _prompt_label: Label3D = null
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


func _build_visuals() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "ModelRoot"
	add_child(_mesh_root)

	var metal_mat: StandardMaterial3D = StandardMaterial3D.new()
	metal_mat.albedo_color = Color(0.32, 0.46, 0.44) # Verde/cinza azulado rústico
	metal_mat.metallic = 0.65
	metal_mat.roughness = 0.45

	var dark_metal: StandardMaterial3D = StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.18, 0.18, 0.20)
	dark_metal.metallic = 0.85
	dark_metal.roughness = 0.3

	var rubber_mat: StandardMaterial3D = StandardMaterial3D.new()
	rubber_mat.albedo_color = Color(0.12, 0.12, 0.14)
	rubber_mat.roughness = 0.9

	var wood_mat: StandardMaterial3D = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.58, 0.40, 0.24)
	wood_mat.roughness = 0.7

	# 1. Caçamba (Tub) - fundo e bordas
	var tub_bottom: MeshInstance3D = MeshInstance3D.new()
	var bottom_mesh: BoxMesh = BoxMesh.new()
	bottom_mesh.size = Vector3(0.68, 0.06, 0.88)
	tub_bottom.mesh = bottom_mesh
	tub_bottom.material_override = metal_mat
	tub_bottom.position = Vector3(0.0, 0.32, -0.05)
	_mesh_root.add_child(tub_bottom)

	# Laterais da caçamba
	var left_wall: MeshInstance3D = MeshInstance3D.new()
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(0.04, 0.30, 0.88)
	left_wall.mesh = wall_mesh
	left_wall.material_override = metal_mat
	left_wall.position = Vector3(-0.33, 0.47, -0.05)
	_mesh_root.add_child(left_wall)

	var right_wall: MeshInstance3D = MeshInstance3D.new()
	right_wall.mesh = wall_mesh
	right_wall.material_override = metal_mat
	right_wall.position = Vector3(0.33, 0.47, -0.05)
	_mesh_root.add_child(right_wall)

	var back_wall: MeshInstance3D = MeshInstance3D.new()
	var b_wall_mesh: BoxMesh = BoxMesh.new()
	b_wall_mesh.size = Vector3(0.66, 0.30, 0.04)
	back_wall.mesh = b_wall_mesh
	back_wall.material_override = metal_mat
	back_wall.position = Vector3(0.0, 0.47, 0.38)
	_mesh_root.add_child(back_wall)

	var front_wall: MeshInstance3D = MeshInstance3D.new()
	var f_wall_mesh: BoxMesh = BoxMesh.new()
	f_wall_mesh.size = Vector3(0.66, 0.26, 0.04)
	front_wall.mesh = f_wall_mesh
	front_wall.material_override = metal_mat
	front_wall.position = Vector3(0.0, 0.45, -0.48)
	_mesh_root.add_child(front_wall)

	# 2. Roda dianteira
	_wheel_mesh = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.20
	cyl.bottom_radius = 0.20
	cyl.height = 0.09
	_wheel_mesh.mesh = cyl
	_wheel_mesh.material_override = rubber_mat
	_wheel_mesh.position = Vector3(0.0, 0.20, -0.58)
	_wheel_mesh.rotation.z = deg_to_rad(90.0) # Roda alinhada no eixo lateral
	_mesh_root.add_child(_wheel_mesh)

	# Eixo da roda
	var axle: MeshInstance3D = MeshInstance3D.new()
	var axle_mesh: CylinderMesh = CylinderMesh.new()
	axle_mesh.top_radius = 0.03
	axle_mesh.bottom_radius = 0.03
	axle_mesh.height = 0.26
	axle.mesh = axle_mesh
	axle.material_override = dark_metal
	axle.position = Vector3(0.0, 0.20, -0.58)
	axle.rotation.z = deg_to_rad(90.0)
	_mesh_root.add_child(axle)

	# 3. Pés traseiros de apoio
	for x_pos: float in [-0.26, 0.26]:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var leg_mesh: CylinderMesh = CylinderMesh.new()
		leg_mesh.top_radius = 0.022
		leg_mesh.bottom_radius = 0.022
		leg_mesh.height = 0.30
		leg.mesh = leg_mesh
		leg.material_override = dark_metal
		leg.position = Vector3(x_pos, 0.15, 0.32)
		_mesh_root.add_child(leg)

	# 4. Braços e manoplas traseiras
	for x_pos: float in [-0.28, 0.28]:
		var handle: MeshInstance3D = MeshInstance3D.new()
		var handle_mesh: BoxMesh = BoxMesh.new()
		handle_mesh.size = Vector3(0.045, 0.045, 0.55)
		handle.mesh = handle_mesh
		handle.material_override = wood_mat
		handle.position = Vector3(x_pos, 0.50, 0.62)
		_mesh_root.add_child(handle)

		var grip: MeshInstance3D = MeshInstance3D.new()
		var grip_mesh: CylinderMesh = CylinderMesh.new()
		grip_mesh.top_radius = 0.028
		grip_mesh.bottom_radius = 0.028
		grip_mesh.height = 0.14
		grip.mesh = grip_mesh
		grip.material_override = rubber_mat
		grip.position = Vector3(x_pos, 0.50, 0.84)
		grip.rotation.x = deg_to_rad(90.0)
		_mesh_root.add_child(grip)

	# 5. Carga visual dentro da caçamba
	_cargo_visual_root = Node3D.new()
	_cargo_visual_root.name = "CargoVisuals"
	_cargo_visual_root.position = Vector3(0.0, 0.38, -0.05)
	_mesh_root.add_child(_cargo_visual_root)

	# 6. Rótulo de texto flutuante / prompt
	_prompt_label = Label3D.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.pixel_size = 0.005
	_prompt_label.font_size = 30
	_prompt_label.outline_size = 8
	_prompt_label.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	_prompt_label.position = Vector3(0.0, 1.05, 0.0)
	add_child(_prompt_label)


func _update_cargo_visuals() -> void:
	if _cargo_visual_root == null:
		return
	for child: Node in _cargo_visual_root.get_children():
		child.queue_free()

	# Gera pequenas caixas / pacotes de carga representativos
	var offsets: Array[Vector3] = [
		Vector3(-0.16, 0.06, -0.22),
		Vector3(0.16, 0.06, -0.22),
		Vector3(0.0, 0.06, 0.0),
		Vector3(-0.16, 0.06, 0.20),
		Vector3(0.16, 0.06, 0.20),
	]

	var parcel_mat: StandardMaterial3D = StandardMaterial3D.new()
	parcel_mat.albedo_color = Color(0.78, 0.62, 0.38) # Marrom pergaminho / embrulho
	parcel_mat.roughness = 0.8

	for i: int in cargo.size():
		if i >= offsets.size():
			break
		var item: CarriedItem = cargo[i]
		var p: MeshInstance3D = MeshInstance3D.new()
		var b: BoxMesh = BoxMesh.new()
		b.size = Vector3(0.24, 0.16, 0.26)
		p.mesh = b
		p.material_override = parcel_mat
		p.position = offsets[i]
		p.rotation.y = float(i) * 0.4
		_cargo_visual_root.add_child(p)


func _update_prompt() -> void:
	if _prompt_label == null:
		return
	if is_tipped:
		_prompt_label.text = "⚠️ Carrinho tombado! [E] Desvirar"
		_prompt_label.modulate = Color(1.0, 0.35, 0.3)
	elif pushing_player != null:
		_prompt_label.text = "🛒 Carrinho de mão (%d/%d)" % [cargo.size(), MAX_CAPACITY]
		_prompt_label.modulate = UiPalette.GOLD
	else:
		_prompt_label.text = "🛒 Carrinho de mão (%d/%d)\n[E] Empurrar" % [cargo.size(), MAX_CAPACITY]
		_prompt_label.modulate = Color(1.0, 0.95, 0.8)
