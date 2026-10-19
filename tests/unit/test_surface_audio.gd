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


## Velocidade de queda ao aterrar de um pulo no plano, quadro a quadro como no _physics_process
## (gravidade x fall_gravity_multiplier na descida).
func _flat_jump_fall_speed(player: Player) -> float:
	var g: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var vy: float = player.jump_velocity
	var y: float = vy * dt
	while y > 0.0:
		vy -= g * (player.fall_gravity_multiplier if vy < 0.0 else 1.0) * dt
		y += vy * dt
	return -vy


func test_normal_jump_lands_with_step_only() -> void:
	var player: Player = (load("res://gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	var fall: float = _flat_jump_fall_speed(player)
	gut.p("pulo no plano aterra a %.2f m/s" % fall)
	assert_gt(fall, Player.LAND_SOUND_SPEED, "o pulo aterra com o passo")
	assert_lt(fall, Player.LAND_IMPACT_SPEED, "sem baque num pulo normal")
	for surface: StringName in [&"sand", &"grass", &"snow", &"water"]:
		var sounds: Array[Dictionary] = Player.land_sounds(surface, fall, -16.0)
		assert_eq(sounds.size(), 1, "%s: só o passo" % surface)
		assert_eq(sounds[0]["sound"], SFX.footstep_sound_for_surface(surface))
		assert_almost_eq(float(sounds[0]["db"]), -16.0 + SFX.footstep_volume_offset(surface) + Player.LAND_STEP_DB, 0.01)
	assert_eq(Player.land_sounds(&"sand", 3.0, -16.0).size(), 0, "degrau pequeno: nada além dos passos")


func test_high_fall_adds_quiet_impact() -> void:
	var sounds: Array[Dictionary] = Player.land_sounds(&"sand", 12.0, -16.0)
	assert_eq(sounds.size(), 2, "queda alta: passo + baque")
	assert_eq(sounds[1]["sound"], SFX.LAND)
	assert_lt(float(sounds[1]["db"]), float(sounds[0]["db"]) - 10.0, "baque bem abaixo do passo")


## A "bolha" na areia (#123): na Praia só é água abaixo do mar (-0.15). Areia seca do spawn ao
## fim da praia (x < 26) nunca é água; depois da linha da maré, sim.
func test_praia_dry_sand_is_not_water() -> void:
	var sea_y: float = Player.SEA_FALLBACK_Y
	var x: float = -30.0
	while x < 26.0:
		for z: float in [-20.0, 0.0, 2.0, 15.0]:
			assert_false(Player.is_in_sea(BeachTerrain.height_at(x, z), sea_y), "areia em (%.0f, %.0f)" % [x, z])
		x += 0.5
	assert_true(Player.is_in_sea(BeachTerrain.height_at(29.0, 2.0), sea_y), "x=29: dentro do mar")
