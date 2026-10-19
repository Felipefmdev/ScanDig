class_name RollingBoulder
extends RigidBody3D

## Rocha Instável e Pedra que Rola na Cratera (#110).
## Empoleirada nos cumes e encostas da Cratera, pronta para desabar.
## Pode ser desestabilizada por:
##   - Interação direta [E] (empurrão físico);
##   - Pancadas de pá, tiro de estilingue ou puxão de arpão;
##   - Explosões de dinamite nas proximidades;
##   - Passos ou carrinhos pesados encostando nela.
##
## Ao rolar ladeira abaixo:
##   - Esmaga e atordoa inimigos no caminho (alto dano de impacto);
##   - Derruba e afasta jogadores incautos;
##   - Tomba carrinhos de mão derramando a carga;
##   - Desenterra/racha pontos enterrados que atropelar;
##   - Em impactos violentos contra paredões, despedaça-se revelando fragmentos de meteorito.

signal dislodged(boulder: RollingBoulder, initial_dir: Vector3)
signal shattered(boulder: RollingBoulder, at_pos: Vector3)
signal crushed_target(target: Node3D, damage: float)

const GROUP: StringName = &"rolling_boulders"
const Interactable = preload("res://gameplay/quests/interactable.gd")
const ToonKit = preload("res://gameplay/art/toon_kit.gd")
const LowPolyMesh = preload("res://gameplay/enemies/lowpoly_mesh.gd")
const CrabModel = preload("res://gameplay/enemies/crab/crab_model.gd")

const STATE_STABLE: int = 0
const STATE_TEETERING: int = 1
const STATE_ROLLING: int = 2
const STATE_SHATTERED: int = 3

const CRUSH_DAMAGE_ENEMY: float = 85.0
const CRUSH_DAMAGE_PLAYER: float = 30.0
const MIN_ROLL_SPEED: float = 1.8
const SHATTER_SPEED_THRESHOLD: float = 10.5

const BASALT_DARK: Color = Color(0.18, 0.15, 0.22)
const BASALT_PURPLE: Color = Color(0.30, 0.20, 0.36)
const METEOR_RUST: Color = Color(0.55, 0.28, 0.16)
const FISSURE_VIOLET: Color = Color(0.75, 0.30, 0.95)

@export var boulder_radius: float = 1.35
@export var boulder_mass: float = 450.0
@export var roll_direction: Vector3 = Vector3.ZERO
@export var drops_loot_on_shatter: bool = true

var state: int = STATE_STABLE

var _teeter_time: float = 0.0
var _mesh_root: Node3D = null
var _col_shape: CollisionShape3D = null
var _recent_crushed_ids: Dictionary = {}
var _interactable_comp: Interactable = null


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(&"damageable")


func _ready() -> void:
	mass = boulder_mass
	collision_layer = 1
	collision_mask = 1 | (1 << 1) | (1 << 2) # Mundo, jogadores, pickups/carrinhos

	# Começa estável/travada na encosta até ser disparada
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC

	_build_collision()
	_build_visuals()
	_build_interaction()

	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_contact)


func _physics_process(delta: float) -> void:
	# Limpa alvos esmagados recentemente após cooldown
	if not _recent_crushed_ids.is_empty():
		var to_remove: Array = []
		for id: int in _recent_crushed_ids:
			_recent_crushed_ids[id] -= delta
			if _recent_crushed_ids[id] <= 0.0:
				to_remove.append(id)
		for id: int in to_remove:
			_recent_crushed_ids.erase(id)

	match state:
		STATE_TEETERING:
			_teeter_time += delta
			# Balanço visual antes de rolar
			if _mesh_root != null:
				_mesh_root.rotation.z = sin(_teeter_time * 18.0) * 0.08
				_mesh_root.rotation.x = cos(_teeter_time * 16.0) * 0.06
			if _teeter_time >= 0.45:
				_launch_roll()

		STATE_ROLLING:
			var speed: float = linear_velocity.length()
			if speed >= MIN_ROLL_SPEED:
				_check_crush_overlap()


func dislodge(impulse_dir: Vector3 = Vector3.ZERO) -> void:
	if state != STATE_STABLE:
		return

	if impulse_dir != Vector3.ZERO:
		roll_direction = Vector3(impulse_dir.x, 0.0, impulse_dir.z).normalized()
	elif roll_direction == Vector3.ZERO:
		# Se não tem direção definida, aponta para o centro da cratera (0, 0)
		roll_direction = Vector3(-global_position.x, 0.0, -global_position.z).normalized()

	state = STATE_TEETERING
	_teeter_time = 0.0
	SFX.play_at(SFX.STONE_IMPACT, global_position, 1.0, 0.1)


func _launch_roll() -> void:
	state = STATE_ROLLING
	freeze = false

	# Impulso inicial forte morro abaixo
	var kick: Vector3 = (roll_direction * 7.5) + Vector3.DOWN * 2.0
	linear_velocity = kick
	apply_central_impulse(kick)

	# Adiciona rotação/torque coerente com a direção
	var roll_axis: Vector3 = roll_direction.cross(Vector3.UP).normalized()
	apply_torque_impulse(roll_axis * 40.0)

	SFX.play_at(SFX.STONE_IMPACT, global_position, 2.0, 0.15)
	dislodged.emit(self, roll_direction)


func take_damage(amount: float, from_pos: Vector3 = Vector3.INF) -> void:
	if state == STATE_STABLE:
		var push_dir: Vector3 = Vector3.ZERO
		if from_pos != Vector3.INF:
			push_dir = (global_position - from_pos).normalized()
		dislodge(push_dir)
	elif state == STATE_ROLLING and amount > 50.0:
		shatter_boulder()


func apply_blast_damage(epicenter: Vector3, radius: float) -> void:
	var dist: float = global_position.distance_to(epicenter)
	if dist <= radius + boulder_radius:
		var blast_dir: Vector3 = (global_position - epicenter).normalized()
		if state == STATE_STABLE:
			dislodge(blast_dir)
		else:
			apply_central_impulse(blast_dir * 18.0)


func shatter_boulder() -> void:
	if state == STATE_SHATTERED:
		return
	state = STATE_SHATTERED

	var pos: Vector3 = global_position
	SFX.play_at(SFX.STONE_IMPACT, pos, 3.0, 0.2)
	shattered.emit(self, pos)

	# Se configurado para soltar recompensa mineral
	if drops_loot_on_shatter and is_inside_tree():
		_spawn_shatter_loot.call_deferred(pos)

	queue_free()


func _spawn_shatter_loot(at_pos: Vector3) -> void:
	var item_path: String = "res://items/catalog/fragmento_meteorito.tres"
	if not ResourceLoader.exists(item_path):
		return
	var data: ItemData = load(item_path) as ItemData
	if data == null:
		return

	var carried: CarriedItem = CarriedItem.create(data, data.base_value, 1.0, false, false)
	ItemPickup.spawn(get_parent() if get_parent() != null else self, carried, at_pos + Vector3.UP * 0.4, roll_direction * 3.0 + Vector3.UP * 4.0)


func _on_contact(body: Node) -> void:
	if state != STATE_ROLLING:
		return

	var speed: float = linear_velocity.length()

	# Impacto violento contra paredes ou obstáculos estáticos maciços despedaça a rocha
	if speed >= SHATTER_SPEED_THRESHOLD and body is StaticBody3D:
		shatter_boulder()
		return

	_handle_hit_target(body as Node3D)


func _check_crush_overlap() -> void:
	# Varre corpos próximos para esmagamento dinâmico
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = boulder_radius * 1.15
	shape_query.shape = sphere
	shape_query.transform = global_transform
	shape_query.collision_mask = 1 | (1 << 1) | (1 << 2)
	shape_query.exclude = [get_rid()]

	var hits: Array[Dictionary] = space.intersect_shape(shape_query, 8)
	for h: Dictionary in hits:
		var col: Object = h.get("collider", null)
		if col is Node3D:
			_handle_hit_target(col as Node3D)


func _handle_hit_target(target: Node3D) -> void:
	if target == null or not is_instance_valid(target) or target == self:
		return

	var id: int = target.get_instance_id()
	if _recent_crushed_ids.has(id):
		return
	_recent_crushed_ids[id] = 0.65 # Cooldown por alvo

	var roll_speed: float = linear_velocity.length()
	var push_impulse: Vector3 = (linear_velocity.normalized() * 14.0) + Vector3.UP * 3.0

	# 1. Inimigos: dano massivo, repulsão e atordoamento
	if target.is_in_group(&"enemies"):
		if target.has_method("take_damage"):
			target.call("take_damage", CRUSH_DAMAGE_ENEMY, global_position)
		if target.has_method("stun"):
			target.call("stun", 1.4)
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", push_impulse, 0.12)
		elif target is CharacterBody3D:
			(target as CharacterBody3D).velocity += push_impulse
		SFX.play_at(SFX.STONE_IMPACT, target.global_position, 2.0, 0.1)
		crushed_target.emit(target, CRUSH_DAMAGE_ENEMY)

	# 2. Jogadores: dano moderado, arremesso e mensagem de alerta
	elif target.is_in_group(&"player") or target.is_in_group(&"players") or target is Player:
		if target.has_method("take_damage"):
			target.call("take_damage", CRUSH_DAMAGE_PLAYER)
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", push_impulse, 0.15)
		if target.has_method("_show_temporary_message"):
			target.call("_show_temporary_message", "⚠️ Atropelado por uma pedra rolando!", UiPalette.RED_BURNT, 1.5)
		SFX.play_at(SFX.PLAYER_HURT, target.global_position, 1.0, 0.1)
		crushed_target.emit(target, CRUSH_DAMAGE_PLAYER)

	# 3. Carrinho de mão: tomba e derrama carga
	elif target.is_in_group(&"wheelbarrows") or target is Wheelbarrow:
		if target.has_method("apply_impulse"):
			target.call("apply_impulse", push_impulse * 1.4)
		elif target.has_method("tip"):
			target.call("tip")
		SFX.play_at(SFX.ITEM_IMPACT_WOOD, target.global_position, 2.0, 0.1)
		crushed_target.emit(target, 0.0)

	# 4. Buracos enterrados no caminho: desenterra/explode
	elif target.is_in_group(&"buried_spots") and target is BuriedSpot:
		var spot: BuriedSpot = target as BuriedSpot
		spot.dig(false, 1.0, false, null)


func _on_player_interacted(peer_id: int) -> void:
	if state == STATE_STABLE:
		var push_dir: Vector3 = Vector3.ZERO
		var p: Node = get_tree().get_first_node_in_group(&"player")
		if p != null and p is Node3D:
			push_dir = (global_position - (p as Node3D).global_position).normalized()
			push_dir.y = 0.0
			push_dir = push_dir.normalized()
			if p.has_method("_show_temporary_message"):
				p.call("_show_temporary_message", "🪨 Rocha instável desabando morro abaixo!", UiPalette.ORANGE, 1.5)
		dislodge(push_dir)


func _build_collision() -> void:
	_col_shape = CollisionShape3D.new()
	_col_shape.name = "Collision"
	var sph: SphereShape3D = SphereShape3D.new()
	sph.radius = boulder_radius
	_col_shape.shape = sph
	add_child(_col_shape)


func _build_visuals() -> void:
	_mesh_root = Node3D.new()
	_mesh_root.name = "MeshRoot"
	add_child(_mesh_root)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var r: float = boulder_radius

	# 1. Corpo principal: rocha facetada convexa com facetas angulares e relevo de meteorito
	var rings: Array = [
		Vector3(-r * 0.45, r * 0.75, r * 0.72),
		Vector3(0.0, r * 0.98, r * 0.95),
		Vector3(r * 0.45, r * 0.78, r * 0.75),
	]
	CrabModel.gem(st, Transform3D.IDENTITY, Vector3.ZERO, Basis.IDENTITY, rings, 8, -r * 0.95, r * 0.95, BASALT_DARK, r * 0.12, 42)

	# 2. Placas de crosta basáltica violeta e ferrugem cósmica da Cratera incrustadas na superfície
	for i: int in 6:
		var ang: float = float(i) * (TAU / 6.0) + 0.35
		var pitch: float = (float(i % 3) - 1.0) * 0.6
		var n_dir: Vector3 = Vector3(cos(ang) * cos(pitch), sin(pitch), sin(ang) * cos(pitch)).normalized()
		var patch_pos: Vector3 = n_dir * (r * 0.78)
		var patch_size: Vector3 = Vector3(r * 0.55, r * 0.22, r * 0.55)
		var p_basis: Basis = Basis.looking_at(n_dir, Vector3.UP if absf(n_dir.y) < 0.9 else Vector3.RIGHT)
		var patch_col: Color = METEOR_RUST if (i % 2 == 0) else BASALT_PURPLE
		CrabModel.gem(st, Transform3D.IDENTITY, patch_pos, p_basis, [Vector3(0.0, patch_size.x * 0.5, patch_size.z * 0.5)], 6, -patch_size.y * 0.5, patch_size.y * 0.5, patch_col, r * 0.05, 100 + i)

	# 3. Fissuras e rachaduras violeta/cósmicas cortando as facetas da rocha
	for k: int in 4:
		var a1: float = float(k) * (TAU / 4.0) + 0.2
		var a2: float = a1 + 1.2
		var p_start: Vector3 = Vector3(cos(a1) * r * 0.92, (float(k % 2) * 2.0 - 1.0) * r * 0.45, sin(a1) * r * 0.92)
		var p_mid: Vector3 = Vector3(cos((a1 + a2) * 0.5) * r * 0.96, float(k % 3 - 1) * r * 0.35, sin((a1 + a2) * 0.5) * r * 0.96)
		var p_end: Vector3 = Vector3(cos(a2) * r * 0.90, -(float(k % 2) * 2.0 - 1.0) * r * 0.40, sin(a2) * r * 0.90)
		LowPolyMesh.prism(st, p_start, p_mid, r * 0.045, r * 0.035, 4, FISSURE_VIOLET)
		LowPolyMesh.prism(st, p_mid, p_end, r * 0.035, r * 0.025, 4, FISSURE_VIOLET)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "BoulderMesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	_mesh_root.add_child(mi)


func _build_interaction() -> void:
	_interactable_comp = Interactable.new()
	_interactable_comp.name = "Interactable"
	_interactable_comp.prompt = "[E] Empurrar rocha instável"
	_interactable_comp.interact_range = boulder_radius * 2.2
	_interactable_comp.focus_offset = Vector3(0.0, boulder_radius * 0.5, 0.0)
	_interactable_comp.once = true
	_interactable_comp.interacted.connect(_on_player_interacted)
	add_child(_interactable_comp)
