class_name FrozenLake
extends Node3D

## Lago Congelado da Geleira Eterna (#108).
## Superfície de gelo fino composta por placas poligonais (IceFloe) sobre água gélida.
## No fundo repousam itens afundados (bússola polar, medalha, cronômetro, etc.),
## visíveis sob o gelo translúcido ou quando as placas quebram, alcançáveis com o arpão.
## Cair na água gélida causa hipotermia (drena fome e vida).

signal floe_cracked(floe: Node3D, new_state: int)
signal floe_shattered(floe: Node3D)
signal floe_refrozen(floe: Node3D)

const GROUP: StringName = &"frozen_lakes"
const GlacierTerrain = preload("res://gameplay/environment/glacier_terrain.gd")
const ICE_FLOE_SCRIPT: Script = preload("res://gameplay/environment/ice_floe.gd")
const IceFloe = preload("res://gameplay/environment/ice_floe.gd")

const CENTER_OFFSET: Vector2 = Vector2(14.0, -8.0)
const RADIUS: float = 8.5
const WATER_Y: float = -0.48
const ICE_SURFACE_Y: float = -0.42

const HYPOTHERMIA_HUNGER_DRAIN: float = 9.0
const HYPOTHERMIA_TICK_INTERVAL: float = 1.5
const HYPOTHERMIA_DAMAGE: float = 5.0

const SUNKEN_ITEM_PATHS: Array[String] = [
	"res://items/catalog/bussola_congelada.tres",
	"res://items/catalog/medalha_polar.tres",
	"res://items/catalog/cronometro_explorador.tres",
	"res://items/catalog/lanterna_expedicao.tres",
	"res://items/catalog/crampon_enferrujado.tres",
]

const SUNKEN_OFFSETS: Array[Vector2] = [
	Vector2(1.8, -1.6),
	Vector2(-2.8, 2.2),
	Vector2(1.5, 3.8),
	Vector2(-3.2, -2.4),
	Vector2(4.2, 1.2),
]

var floes: Array[IceFloe] = []
var sunken_pickups: Array[ItemPickup] = []

var _water_mesh: MeshInstance3D = null
var _water_area: Area3D = null
var _swimming_players: Array[Node3D] = []
var _player_hypothermia_timers: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_build_water_surface()
	_build_water_hazard_area()
	_generate_ice_floes()
	_spawn_sunken_items.call_deferred()


func _physics_process(delta: float) -> void:
	if _swimming_players.is_empty():
		return

	for player: Node3D in _swimming_players:
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue

		# Se o jogador estiver sobre uma placa intacta, não está na água
		var current_floe: IceFloe = get_floe_at(player.global_position)
		if current_floe != null and not current_floe.is_broken() and player.global_position.y >= current_floe.global_position.y - 0.05:
			continue

		# Aplica dreno contínuo de fome pela água gélida
		if "hunger" in player and player.has_method("set_hunger"):
			var cur_h: float = float(player.get("hunger"))
			player.call("set_hunger", cur_h - HYPOTHERMIA_HUNGER_DRAIN * delta)

		# Tick periódico de dano de frio
		var pid: int = player.get_instance_id()
		var timer: float = float(_player_hypothermia_timers.get(pid, 0.0)) + delta
		if timer >= HYPOTHERMIA_TICK_INTERVAL:
			timer = 0.0
			if player.has_method("take_damage"):
				player.call("take_damage", HYPOTHERMIA_DAMAGE)
			if player.has_method("_show_temporary_message"):
				player.call("_show_temporary_message", "❄️ Água gélida! Risco de hipotermia!", Color(0.45, 0.85, 1.0), 1.2)
			SFX.play_at(SFX.PLAYER_HURT, player.global_position, -2.0, 0.1)
		_player_hypothermia_timers[pid] = timer


## Quebra placas de gelo na área de impacto de explosões de dinamite (#108).
func apply_blast_damage(epicenter: Vector3, radius: float) -> int:
	var shattered_count: int = 0
	for floe: IceFloe in floes:
		if is_instance_valid(floe) and not floe.is_broken():
			if floe.global_position.distance_to(epicenter) <= radius + floe.floe_radius * 0.5:
				floe.apply_blast_damage(epicenter, radius)
				# A client only requests the blast; do not report a confirmed break yet.
				if floe.is_broken():
					shattered_count += 1
	return shattered_count


func get_floe_at(world_pos: Vector3) -> IceFloe:
	for floe: IceFloe in floes:
		if is_instance_valid(floe):
			var dist: float = Vector2(world_pos.x - floe.global_position.x, world_pos.z - floe.global_position.z).length()
			if dist <= floe.floe_radius:
				return floe
	return null


func _build_water_surface() -> void:
	_water_mesh = MeshInstance3D.new()
	_water_mesh.name = "WaterSurface"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = RADIUS * 1.02
	cyl.bottom_radius = RADIUS * 0.95
	cyl.height = 0.04
	cyl.radial_segments = 32
	_water_mesh.mesh = cyl
	_water_mesh.position = Vector3(CENTER_OFFSET.x, WATER_Y, CENTER_OFFSET.y)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Azul-petróleo escuro e semi-transparente (#108): contraste nítido com o gelo e fundo visível
	mat.albedo_color = Color(0.02, 0.16, 0.25, 0.75)
	mat.roughness = 0.08
	mat.metallic = 0.05
	mat.metallic_specular = 0.95
	_water_mesh.material_override = mat
	add_child(_water_mesh)


func _build_water_hazard_area() -> void:
	_water_area = Area3D.new()
	_water_area.name = "WaterHazardArea"
	_water_area.collision_layer = 0
	_water_area.collision_mask = 1 | (1 << 1) # mundo e jogadores
	_water_area.monitorable = false

	var shape: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = RADIUS * 0.98
	cyl.height = 0.35
	shape.shape = cyl
	shape.position = Vector3(CENTER_OFFSET.x, -0.66, CENTER_OFFSET.y)
	_water_area.add_child(shape)

	_water_area.body_entered.connect(_on_water_body_entered)
	_water_area.body_exited.connect(_on_water_body_exited)
	add_child(_water_area)


func _on_water_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player") or body.is_in_group(&"players") or body is CharacterBody3D:
		if not _swimming_players.has(body):
			_swimming_players.append(body)
			_player_hypothermia_timers[body.get_instance_id()] = 0.0
			SFX.play_at(SFX.FOOTSTEP_WATER, body.global_position, 0.0, 0.1)


func _on_water_body_exited(body: Node3D) -> void:
	_swimming_players.erase(body)
	_player_hypothermia_timers.erase(body.get_instance_id())


func _generate_ice_floes() -> void:
	floes.clear()
	var floe_id_counter: int = 1

	# Centro do lago
	_spawn_floe(Vector2(0.0, 0.0), floe_id_counter, 1.85)
	floe_id_counter += 1

	# Anel 1: 6 placas em raio 2.9m
	var ring1_count: int = 6
	var r1: float = 2.9
	for i: int in ring1_count:
		var ang: float = (TAU / float(ring1_count)) * float(i)
		var offset: Vector2 = Vector2(cos(ang) * r1, sin(ang) * r1)
		_spawn_floe(offset, floe_id_counter, 1.70)
		floe_id_counter += 1

	# Anel 2: 12 placas em raio 5.8m
	var ring2_count: int = 12
	var r2: float = 5.8
	for i: int in ring2_count:
		var ang: float = (TAU / float(ring2_count)) * float(i) + 0.25
		var offset: Vector2 = Vector2(cos(ang) * r2, sin(ang) * r2)
		_spawn_floe(offset, floe_id_counter, 1.65)
		floe_id_counter += 1


func _spawn_floe(local_offset: Vector2, id: int, radius: float) -> IceFloe:
	var floe: IceFloe = ICE_FLOE_SCRIPT.new() as IceFloe
	floe.host_authoritative = true
	floe.floe_id = id
	floe.floe_radius = radius
	var world_x: float = CENTER_OFFSET.x + local_offset.x
	var world_z: float = CENTER_OFFSET.y + local_offset.y
	floe.position = Vector3(world_x, ICE_SURFACE_Y, world_z)
	floe.name = "IceFloe_%d" % id

	floe.cracked.connect(func(f: IceFloe, s: int) -> void: floe_cracked.emit(f, s))
	floe.shattered.connect(func(f: IceFloe) -> void: floe_shattered.emit(f))
	floe.refrozen.connect(func(f: IceFloe) -> void: floe_refrozen.emit(f))

	add_child(floe)
	floes.append(floe)
	return floe


func _spawn_sunken_items() -> void:
	if not HostSync.is_host(self):
		return
	sunken_pickups.clear()

	for i: int in mini(SUNKEN_ITEM_PATHS.size(), SUNKEN_OFFSETS.size()):
		var path: String = SUNKEN_ITEM_PATHS[i]
		if not ResourceLoader.exists(path):
			continue
		var data: ItemData = load(path) as ItemData
		if data == null:
			continue

		var carried: CarriedItem = CarriedItem.create(data, data.base_value, 1.0, false, false)
		var item_x: float = CENTER_OFFSET.x + SUNKEN_OFFSETS[i].x
		var item_z: float = CENTER_OFFSET.y + SUNKEN_OFFSETS[i].y
		var bed_y: float = GlacierTerrain.height_at(item_x, item_z)
		var spawn_pos: Vector3 = Vector3(item_x, bed_y + 0.12, item_z)

		var pickup: ItemPickup = ItemPickup.spawn(self, carried, spawn_pos)
		if pickup != null:
			pickup.freeze = true
			pickup.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			_add_sunken_item_glow(pickup)
			sunken_pickups.append(pickup)


func _add_sunken_item_glow(pickup: ItemPickup) -> void:
	# Luz subaquática difusa no item afundado (#108)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "SunkenGlowLight"
	light.light_color = Color(0.40, 0.88, 1.0)
	light.light_energy = 0.75
	light.omni_range = 1.9
	light.shadow_enabled = false
	pickup.add_child(light)

	# Bloco de gelo translúcido envolvendo o modelo do item (#108)
	var ice_block: MeshInstance3D = MeshInstance3D.new()
	ice_block.name = "SunkenIceBlock"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.28, 0.24, 0.28)
	ice_block.mesh = box
	ice_block.position = Vector3(0.0, 0.08, 0.0)

	var ice_mat: StandardMaterial3D = StandardMaterial3D.new()
	ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_mat.albedo_color = Color(0.70, 0.92, 1.0, 0.30)
	ice_mat.roughness = 0.08
	ice_mat.metallic = 0.05
	ice_mat.metallic_specular = 0.95
	ice_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ice_block.material_override = ice_mat
	pickup.add_child(ice_block)

	# Borda facetada de geada no topo do bloco de gelo
	var frost: MeshInstance3D = MeshInstance3D.new()
	frost.name = "FrostRim"
	var frost_box: BoxMesh = BoxMesh.new()
	frost_box.size = Vector3(0.29, 0.03, 0.29)
	frost.mesh = frost_box
	frost.position = Vector3(0.0, 0.20, 0.0)
	var frost_mat: StandardMaterial3D = StandardMaterial3D.new()
	frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frost_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.50)
	frost_mat.roughness = 0.35
	frost.material_override = frost_mat
	pickup.add_child(frost)
