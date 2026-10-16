extends GutTest

## #27: detector até ao Nv.7, pá ligada ao upgrade, pinpointer e mochila até 8.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const DETECTOR_SCENE: PackedScene = preload("res://gameplay/detector/metal_detector.tscn")

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = GameState.instance.get_snapshot()


func after_each() -> void:
	GameState.instance.apply_snapshot(_saved)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_upgrades(levels: Dictionary, discovered: Array = []) -> void:
	var snap: Dictionary = GameState.instance.get_snapshot()
	var current: Dictionary = snap["upgrade_levels"]
	current.merge(levels, true)
	snap["discovered_items"] = discovered
	GameState.instance.apply_snapshot(snap)


func _item(base_value: int, fragility: float) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = "teste_27"
	item.display_name = "Teste"
	item.base_value = base_value
	item.fragility = fragility
	item.depth_cm = 20
	item.material_type = ItemData.MaterialType.OURO
	return item


## Câmara na origem a olhar para -Z (frente do radar) e um detetor ativo.
func _spawn_detector() -> MetalDetector:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	cam.make_current()
	var det: MetalDetector = DETECTOR_SCENE.instantiate() as MetalDetector
	add_child_autofree(det)
	det.set_active(true)
	return det


func _spawn_spot(pos: Vector3, rare: bool = false) -> BuriedSpot:
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = _item(40, 0.5)
	spot.rare_decided = true
	spot.is_rare_variant = rare
	add_child_autofree(spot)
	spot.global_position = pos
	return spot


# --- Detector -------------------------------------------------------------------

func test_detector_reaches_level_7_with_23m() -> void:
	assert_eq(MetalDetector.MAX_LEVEL, 7)
	var det: MetalDetector = _spawn_detector()
	for upgrade: int in [0, 3, 6]:
		_set_upgrades({"detector": upgrade})
		det._refresh_level_stats()
		assert_eq(det.get_detector_level(), upgrade + 1)
		assert_almost_eq(det.max_detection_distance, 8.0 + 2.5 * float(upgrade), 0.001)
	assert_almost_eq(det.max_detection_distance, 23.0, 0.001, "Nv.7 = 23 m")


func test_enemies_seen_farther_from_level_6() -> void:
	var det: MetalDetector = _spawn_detector()
	_set_upgrades({"detector": 4})
	det._refresh_level_stats()
	assert_almost_eq(det.get_enemy_detection_distance(), det.max_detection_distance, 0.001, "Nv.5 = alcance")
	_set_upgrades({"detector": 5})
	det._refresh_level_stats()
	assert_almost_eq(det.get_enemy_detection_distance(), 20.5 * 1.5, 0.001, "Nv.6 = 1.5x")


func test_value_range_worst_to_perfect() -> void:
	var item: ItemData = _item(40, 0.5)
	# Duas pazadas rápidas: 1 - 2 * 0.225 = 55% de 40 = 22; perfeita = 40 * 1.25 = 50.
	assert_eq(MetalDetector.get_value_range(item, false), Vector2i(22, 50))
	assert_eq(MetalDetector.get_value_range(item, true), Vector2i(66, 150))
	assert_eq(MetalDetector.get_value_range(null, false), Vector2i.ZERO)


func test_rare_revealed_at_any_distance_from_level_5() -> void:
	var det: MetalDetector = _spawn_detector()
	var spot: BuriedSpot = _spawn_spot(Vector3(0, 0, -6), true)
	_set_upgrades({"detector": 3})
	assert_false(det.is_rare_revealed(spot, 0.2), "Nv.4: sinal fraco não revela")
	assert_true(det.is_rare_revealed(spot, 0.8), "Nv.4: sinal forte revela")
	_set_upgrades({"detector": 4})
	assert_true(det.is_rare_revealed(spot, 0.2), "Nv.5: revela longe")
	spot.is_rare_variant = false
	assert_false(det.is_rare_revealed(spot, 1.0))


func test_footer_lines_per_level() -> void:
	var det: MetalDetector = _spawn_detector()
	_spawn_spot(Vector3(0, 0, -4))
	_set_upgrades({"detector": 2})
	det._refresh_level_stats()
	det._update_target_detection()
	var lines: PackedStringArray = det.get_footer_lines()
	assert_eq(lines.size(), 4, "Nv.3: 4 linhas")
	assert_eq(lines[2], "Mat: Ouro")
	_set_upgrades({"detector": 3})
	lines = det.get_footer_lines()
	assert_eq(lines.size(), 5, "Nv.4: + valor")
	assert_eq(lines[4], "Val: %s–%s" % [MoneyFormat.money(22), MoneyFormat.thousands(50)])
	_set_upgrades({"detector": 6}, [])
	lines = det.get_footer_lines()
	assert_eq(lines[2], "Novo: Teste", "Nv.7 identifica e avisa que falta no museu")
	_set_upgrades({"detector": 6}, ["teste_27"])
	assert_eq(det.get_footer_lines()[2], "Teste")


# --- Pinpointer -----------------------------------------------------------------

func test_direction_arrows_and_tick_interval() -> void:
	assert_eq(MetalDetector.get_direction_arrow(Vector2(0, 1)), "↑")
	assert_eq(MetalDetector.get_direction_arrow(Vector2(1, 0)), "→")
	assert_eq(MetalDetector.get_direction_arrow(Vector2(0, -1)), "↓")
	assert_eq(MetalDetector.get_direction_arrow(Vector2(-1, 1)), "↖")
	var far: float = MetalDetector.get_pinpoint_tick_interval(MetalDetector.PINPOINT_RANGE)
	var near: float = MetalDetector.get_pinpoint_tick_interval(0.3)
	assert_almost_eq(far, MetalDetector.PINPOINT_TICK_FAR, 0.001)
	assert_lt(near, far, "bip acelera perto do alvo")


func test_pinpointer_level_1_guides_last_meters() -> void:
	var det: MetalDetector = _spawn_detector()
	var spot: BuriedSpot = _spawn_spot(Vector3(0, 0, -1.8))
	_set_upgrades({"pinpointer": 0})
	det._update_target_detection()
	assert_false(det.is_pinpointing(), "sem upgrade não guia")
	assert_true(det.get_footer_lines()[1].begins_with("Sinal"))

	_set_upgrades({"pinpointer": 1})
	assert_true(det.is_pinpointing())
	assert_eq(det.get_pinpoint_text(), "PIN ↑ 1.8m")
	assert_almost_eq(det.get_radar_view_distance(), MetalDetector.PINPOINT_VIEW_DISTANCE, 0.001, "zoom")
	assert_eq(det.get_footer_lines()[1], "PIN ↑ 1.8m")

	spot.global_position = Vector3(1.0, 0, 0)
	det._update_target_detection()
	assert_eq(det.get_pinpoint_text(), "PIN ✔ CAVE")

	spot.global_position = Vector3(0, 0, -5)
	det._update_target_detection()
	assert_false(det.is_pinpointing(), "longe demais")
	assert_almost_eq(det.get_radar_view_distance(), det.max_detection_distance, 0.001)


func test_pinpointer_ticks_at_target() -> void:
	var det: MetalDetector = _spawn_detector()
	var spot: BuriedSpot = _spawn_spot(Vector3(0.5, 0, -1.0))
	_set_upgrades({"pinpointer": 1})
	det._update_target_detection()
	det._update_pinpointer(0.016)
	var audio: AudioStreamPlayer3D = det.get_node("PinpointerAudio") as AudioStreamPlayer3D
	assert_not_null(audio)
	assert_almost_eq(audio.global_position.distance_to(spot.global_position), 0.0, 0.001, "bip vem do ponto")
	assert_gt(det._pin_tick_timer, 0.0)


func test_pinpointer_level_2_rare_compass() -> void:
	var det: MetalDetector = _spawn_detector()
	_spawn_spot(Vector3(0, 0, -3))
	_spawn_spot(Vector3(30, 0, 0), true)
	_set_upgrades({"pinpointer": 1})
	assert_eq(det.get_rare_compass(), Vector2.ZERO, "Nv.1 sem bússola")
	_set_upgrades({"pinpointer": 2})
	var compass: Vector2 = det.get_rare_compass()
	assert_almost_eq(compass.x, 30.0, 0.01, "raro à direita, fora do alcance")
	assert_string_contains(det.get_footer_lines()[0], "★30m")


# --- Pá e mochila ---------------------------------------------------------------

func test_shovel_level_follows_upgrade() -> void:
	_set_upgrades({"shovel": 0})
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_eq(player.shovel_level, 1)
	_set_upgrades({"shovel": 3})
	assert_eq(player.shovel_level, 4, "snapshot tardio")
	assert_almost_eq(player.get_dig_cooldown(), Player.BASE_DIG_COOLDOWN / 1.75, 0.0001)
	assert_almost_eq(player.get_dig_damage_multiplier(), 0.55, 0.0001)
	player.free()
	var fresh: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(fresh)
	assert_eq(fresh.shovel_level, 4, "no _ready")


func test_backpack_8_slots_with_keys() -> void:
	_set_upgrades({"backpack": 5})
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_eq(player.inventory.capacity, 8)
	assert_eq(player.hotbar.get_child_count(), 8)
	for i: int in range(1, 9):
		assert_true(InputMap.has_action("slot_%d" % i), "tecla do slot %d" % i)


## Coop: o DetectorSpawn larga um detetor por jogador; ninguém leva dois.
func test_cannot_carry_two_detectors() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var det: CarriedItem = CarriedItem.create_tool(&"detector", "Detetor de Metais")
	assert_false(player._already_has_unique_tool(det))
	player.inventory.add_item(CarriedItem.create_tool(&"detector", "Detetor de Metais"))
	assert_true(player._already_has_unique_tool(det))
	assert_false(player._already_has_unique_tool(CarriedItem.create_tool(&"repelente", "Repelente")), "só o detetor é único")
