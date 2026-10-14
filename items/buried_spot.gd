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


func _ready() -> void:
	add_to_group("buried_spots")
	_create_visuals()


func _create_visuals() -> void:
	_dirt_mound = Node3D.new()
	_dirt_mound.name = "DirtMound"
	add_child(_dirt_mound)

	var mound_mesh: CSGCylinder3D = CSGCylinder3D.new()
	mound_mesh.radius = 0.45
	mound_mesh.height = 0.05
	mound_mesh.sides = 12
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.28, 0.15)
	mound_mesh.material = mat
	mound_mesh.position.y = 0.025
	_dirt_mound.add_child(mound_mesh)


func dig(is_careful: bool) -> Dictionary:
	if _is_revealed or dirt_layers <= 0:
		return {
			"revealed": true,
			"dirt_layers": 0,
			"integrity": integrity,
			"item": item,
			"final_value": 0
		}

	dirt_layers -= 1

	if not is_careful:
		if dirt_layers <= 1 and item != null:
			var damage: float = clampf(item.fragility * 0.45, 0.05, 0.95)
			integrity = clampf(integrity - damage, 0.0, 1.0)
			print("[BuriedSpot] Pazada agressiva! Dano causado ao item. Integridade: %d%%" % int(integrity * 100.0))
		else:
			print("[BuriedSpot] Pazada rápida removeu camada. Camadas restantes: %d" % dirt_layers)
	else:
		print("[BuriedSpot] Escavação cuidadosa! Camadas restantes: %d (Integridade 100%% preservada)" % dirt_layers)

	var revealed: bool = (dirt_layers <= 0)
	var final_val: int = 0

	if revealed:
		_is_revealed = true
		remove_from_group("buried_spots")
		if _dirt_mound != null:
			_dirt_mound.visible = false

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
		if is_inside_tree() and get_tree() != null:
			get_tree().create_timer(2.5).timeout.connect(queue_free)
		else:
			queue_free()

	spot_dug.emit(dirt_layers, integrity)

	return {
		"revealed": revealed,
		"dirt_layers": dirt_layers,
		"integrity": integrity,
		"item": item,
		"final_value": final_val
	}


func _spawn_revealed_item_mesh() -> void:
	_revealed_mesh = Node3D.new()
	_revealed_mesh.name = "RevealedItem"
	add_child(_revealed_mesh)

	var cube: CSGBox3D = CSGBox3D.new()
	cube.size = Vector3(0.28, 0.28, 0.28)
	cube.position.y = 0.18

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
				mat.emission_energy_multiplier = 2.0
	cube.material = mat
	_revealed_mesh.add_child(cube)
