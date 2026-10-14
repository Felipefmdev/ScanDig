class_name BuriedSpot
extends Area3D

signal spot_dug(dirt_left: int, current_integrity: float)
signal item_revealed(item_data: ItemData, final_value: int, final_integrity: float)

@export var item: ItemData = null
@export var dirt_layers: int = 3
@export_range(0.0, 1.0) var integrity: float = 1.0

var _is_revealed: bool = false
var _dirt_mound: Node3D = null
var _revealed_mesh: Node3D = null
var _dirt_particles: CPUParticles3D = null
const MAX_DIRT_LAYERS: int = 3


func _ready() -> void:
	add_to_group("buried_spots")
	_create_visuals()
	_create_particles()


func _create_visuals() -> void:
	_dirt_mound = Node3D.new()
	_dirt_mound.name = "DirtMound"
	_dirt_mound.visible = false  # Começa totalmente invisível na areia!
	add_child(_dirt_mound)

	# Borda externa da escavação
	var mound_mesh: CSGCylinder3D = CSGCylinder3D.new()
	mound_mesh.radius = 0.45
	mound_mesh.height = 0.05
	mound_mesh.sides = 12
	var mat_dirt: StandardMaterial3D = StandardMaterial3D.new()
	mat_dirt.albedo_color = Color(0.42, 0.28, 0.15)
	mat_dirt.roughness = 0.9
	mound_mesh.material = mat_dirt
	mound_mesh.position.y = 0.02
	_dirt_mound.add_child(mound_mesh)

	# Fundo do buraco (terra mais escura e funda)
	var hole_mesh: CSGCylinder3D = CSGCylinder3D.new()
	hole_mesh.radius = 0.32
	hole_mesh.height = 0.07
	hole_mesh.sides = 12
	var mat_hole: StandardMaterial3D = StandardMaterial3D.new()
	mat_hole.albedo_color = Color(0.25, 0.16, 0.08)
	mat_hole.roughness = 1.0
	hole_mesh.material = mat_hole
	hole_mesh.position.y = 0.015
	_dirt_mound.add_child(hole_mesh)


func _create_particles() -> void:
	_dirt_particles = CPUParticles3D.new()
	_dirt_particles.name = "DirtParticles"
	_dirt_particles.emitting = false
	_dirt_particles.one_shot = true
	_dirt_particles.explosiveness = 0.9
	_dirt_particles.amount = 24
	_dirt_particles.lifetime = 0.55
	_dirt_particles.direction = Vector3(0, 1, 0)
	_dirt_particles.spread = 45.0
	_dirt_particles.initial_velocity_min = 2.2
	_dirt_particles.initial_velocity_max = 3.8
	_dirt_particles.gravity = Vector3(0, -9.8, 0)

	var particle_box: BoxMesh = BoxMesh.new()
	particle_box.size = Vector3(0.05, 0.05, 0.05)
	var mat_p: StandardMaterial3D = StandardMaterial3D.new()
	mat_p.albedo_color = Color(0.55, 0.38, 0.22)
	mat_p.roughness = 0.9
	particle_box.material = mat_p
	_dirt_particles.mesh = particle_box

	add_child(_dirt_particles)


func dig(is_careful: bool) -> Dictionary:
	if _is_revealed or dirt_layers <= 0:
		return {
			"revealed": true,
			"dirt_layers": 0,
			"max_layers": MAX_DIRT_LAYERS,
			"integrity": integrity,
			"damaged": false,
			"item": item,
			"final_value": 0
		}

	# Primeira pazada torna a escavação visível no terreno
	if _dirt_mound != null and not _dirt_mound.visible:
		_dirt_mound.visible = true

	# Emite partículas de areia e terra voando
	if _dirt_particles != null:
		_dirt_particles.restart()

	dirt_layers -= 1

	# Ajusta o buraco conforme as camadas são removidas
	if _dirt_mound != null:
		var layer_progress: float = float(MAX_DIRT_LAYERS - dirt_layers) / float(MAX_DIRT_LAYERS)
		# O buraco afunda ligeiramente e alarga a cada camada
		_dirt_mound.position.y = -0.04 * layer_progress
		_dirt_mound.scale = Vector3(1.0 + layer_progress * 0.15, 1.0, 1.0 + layer_progress * 0.15)

	var damaged_this_hit: bool = false
	var damage_amount: float = 0.0

	if not is_careful:
		# Se dirt_layers <= 1, aplica dano à integridade baseado na fragilidade do item
		if dirt_layers <= 1 and item != null:
			damage_amount = clampf(item.fragility * 0.45, 0.08, 0.90)
			integrity = clampf(integrity - damage_amount, 0.05, 1.0)
			damaged_this_hit = true
			print("[BuriedSpot] CRACK! Pazada agressiva causou dano! Integridade: %d%%" % int(integrity * 100.0))
		else:
			print("[BuriedSpot] Pazada rápida removeu camada de terra. Restam %d" % dirt_layers)
	else:
		print("[BuriedSpot] Escavação cuidadosa! Camadas restantes: %d (Integridade 100%% preservada)" % dirt_layers)

	var revealed: bool = (dirt_layers <= 0)
	var final_val: int = 0

	if revealed:
		_is_revealed = true
		remove_from_group("buried_spots")

		if item != null:
			final_val = item.calculate_value(integrity)
			print("========================================")
			print("★ ITEM ENCONTRADO: %s" % item.display_name)
			print("  Integridade: %d%%" % int(integrity * 100.0))
			print("  Valor de Venda: R$ %d" % final_val)
			print("  Profundidade Real: %d cm" % item.depth_cm)
			print("========================================")
			_spawn_revealed_item_mesh()
		else:
			print("[BuriedSpot] Ponto escavado sem ItemData configurado.")

		item_revealed.emit(item, final_val, integrity)
		DiscoveryBridge.report_item_found(item, final_val)
		if is_inside_tree() and get_tree() != null:
			get_tree().create_timer(4.0).timeout.connect(queue_free)
		else:
			queue_free()

	spot_dug.emit(dirt_layers, integrity)

	return {
		"revealed": revealed,
		"dirt_layers": dirt_layers,
		"max_layers": MAX_DIRT_LAYERS,
		"integrity": integrity,
		"damaged": damaged_this_hit,
		"damage_amount": damage_amount,
		"item": item,
		"final_value": final_val
	}


func _spawn_revealed_item_mesh() -> void:
	_revealed_mesh = Node3D.new()
	_revealed_mesh.name = "RevealedItem"
	add_child(_revealed_mesh)

	var cube: CSGBox3D = CSGBox3D.new()
	cube.size = Vector3(0.26, 0.26, 0.26)
	cube.position.y = 0.05

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if item != null:
		match item.material_type:
			ItemData.MaterialType.FERRO:
				mat.albedo_color = Color(0.35, 0.35, 0.35)
				mat.metallic = 0.8
				mat.roughness = 0.4
			ItemData.MaterialType.ALUMINIO:
				mat.albedo_color = Color(0.75, 0.78, 0.82)
				mat.metallic = 0.7
				mat.roughness = 0.3
			ItemData.MaterialType.PRATA:
				mat.albedo_color = Color(0.92, 0.93, 0.96)
				mat.metallic = 0.95
				mat.roughness = 0.15
			ItemData.MaterialType.OURO:
				mat.albedo_color = Color(1.0, 0.82, 0.12)
				mat.metallic = 0.95
				mat.roughness = 0.1
			ItemData.MaterialType.DESCONHECIDO:
				mat.albedo_color = Color(0.2, 0.95, 0.85)
				mat.emission_enabled = true
				mat.emission = Color(0.2, 0.95, 0.85)
				mat.emission_energy_multiplier = 2.5
	cube.material = mat
	_revealed_mesh.add_child(cube)

	# Animação procedural: o objeto salta para fora do buraco e roda
	if is_inside_tree():
		var tween: Tween = create_tween()
		# Arco de salto: sobe até 0.65m e quica em 0.30m
		tween.tween_property(cube, "position:y", 0.65, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cube, "position:y", 0.30, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		var rot_tween: Tween = create_tween()
		rot_tween.tween_property(cube, "rotation:y", TAU * 1.5, 0.70).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
