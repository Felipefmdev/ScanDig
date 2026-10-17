class_name TestSurfaceAudio
extends GutTest

## Testes unitários para o sistema de áudio por superfície (How to Fish SurfaceManager)
## e impacto de itens por material.

func test_footstep_sounds_defined_and_loadable() -> void:
	var surfaces: Array[StringName] = [
		&"sand", &"snow", &"grass", &"stone", &"crystal", &"water", &"wood"
	]
	for s: StringName in surfaces:
		var sounds: Array[String] = SFX.footstep_sound_for_surface(s)
		assert_gt(sounds.size(), 0, "Superfície %s deve ter ao menos 1 som definido" % s)
		for path: String in sounds:
			assert_true(ResourceLoader.exists(path), "Arquivo de áudio deve existir: %s" % path)
			var stream: AudioStream = ResourceLoader.load(path) as AudioStream
			assert_not_null(stream, "Arquivo de áudio deve carregar AudioStream válido: %s" % path)

	var water_sounds: Array[String] = SFX.footstep_sound_for_surface(&"water")
	assert_eq(water_sounds.size(), 3, "FOOTSTEP_WATER deve ter 3 variantes dedicadas")
	for path: String in water_sounds:
		assert_true(path.contains("water_step_"), "FOOTSTEP_WATER deve usar water_step_*.wav: %s" % path)
		var stream: AudioStream = ResourceLoader.load(path) as AudioStream
		assert_not_null(stream, "water_step deve carregar como AudioStream válido: %s" % path)


func test_footstep_volume_offsets() -> void:
	assert_eq(SFX.footstep_volume_offset(&"sand"), 0.0)
	assert_lt(SFX.footstep_volume_offset(&"stone"), 0.0, "Passos de pedra devem ser atenuados para conforto")
	assert_lt(SFX.footstep_volume_offset(&"crystal"), 0.0, "Passos de cristal devem ser atenuados para conforto")
	assert_lt(SFX.footstep_volume_offset(&"water"), 0.0)
	assert_lt(SFX.footstep_volume_offset(&"grass"), 0.0)


func test_item_impact_sounds_defined_and_loadable() -> void:
	var materials: Array[int] = [
		ItemData.MaterialType.FERRO,
		ItemData.MaterialType.ALUMINIO,
		ItemData.MaterialType.PRATA,
		ItemData.MaterialType.OURO,
		ItemData.MaterialType.DESCONHECIDO
	]
	for m: int in materials:
		var sounds: Array[String] = SFX.item_impact_sound(m)
		assert_gt(sounds.size(), 0, "Material %d deve ter ao menos 1 som de impacto" % m)
		for path: String in sounds:
			assert_true(ResourceLoader.exists(path), "Arquivo de impacto deve existir: %s" % path)


func test_player_surface_type_from_node_detection() -> void:
	var player_scene: PackedScene = load("res://gameplay/player/player.tscn")
	var player: Player = player_scene.instantiate() as Player
	add_child_autofree(player)

	var stone_node: StaticBody3D = StaticBody3D.new()
	stone_node.name = "StoneSlab_01"
	assert_eq(player._surface_type_from_node(stone_node), &"stone")
	stone_node.free()

	var wood_node: StaticBody3D = StaticBody3D.new()
	wood_node.name = "WoodPier_02"
	assert_eq(player._surface_type_from_node(wood_node), &"wood")
	wood_node.free()

	var snow_node: Node3D = Node3D.new()
	snow_node.name = "SnowDrift"
	assert_eq(player._surface_type_from_node(snow_node), &"snow")
	snow_node.free()

	var grass_node: Node3D = Node3D.new()
	grass_node.name = "GrassPatch"
	assert_eq(player._surface_type_from_node(grass_node), &"grass")
	grass_node.free()

	var water_node: Area3D = Area3D.new()
	water_node.name = "WaterPuddle"
	assert_eq(player._surface_type_from_node(water_node), &"water")
	water_node.free()

	var crystal_node: Node3D = Node3D.new()
	crystal_node.name = "CrystalRidge"
	assert_eq(player._surface_type_from_node(crystal_node), &"crystal")
	crystal_node.free()


func test_item_pickup_contact_monitoring() -> void:
	var item: ItemData = ItemData.new()
	item.id = "moeda_ferro"
	item.material_type = ItemData.MaterialType.FERRO
	var carried: CarriedItem = CarriedItem.create(item, 50, 1.0, false, true)

	var pickup: ItemPickup = ItemPickup.create(carried)
	add_child_autofree(pickup)
	assert_true(pickup.contact_monitor, "ItemPickup deve ter contact_monitor ativado para tocar som de aterragem")
	assert_gt(pickup.max_contacts_reported, 0, "ItemPickup deve reportar contatos")
