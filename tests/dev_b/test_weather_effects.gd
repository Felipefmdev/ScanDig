extends GutTest

## Efeitos do clima no jogo (#99): chuva acelera a pá e faz o visor tremer (sem barulho a mais),
## nevasca gasta mais fome, cinzas encurtam o detector. Tudo volta exatamente ao fim do evento.
## Usa o autoload CoreWeather com force_event (sem tempo real).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const DETECTOR_SCENE: PackedScene = preload("res://gameplay/detector/metal_detector.tscn")


func _weather() -> WeatherManager:
	assert_not_null(WeatherManager.instance, "autoload CoreWeather presente")
	return WeatherManager.instance


func after_each() -> void:
	if WeatherManager.instance != null:
		WeatherManager.instance.stop()


func _spawn_detector() -> MetalDetector:
	var cam: Camera3D = Camera3D.new()
	add_child_autofree(cam)
	cam.make_current()
	var det: MetalDetector = DETECTOR_SCENE.instantiate() as MetalDetector
	add_child_autofree(det)
	det.set_active(true)
	return det


func _spawn_spot(pos: Vector3) -> BuriedSpot:
	var item: ItemData = ItemData.new()
	item.id = "teste_clima"
	item.display_name = "Teste"
	item.base_value = 40
	item.depth_cm = 20
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = item
	spot.rare_decided = true
	add_child_autofree(spot)
	spot.global_position = pos
	return spot


func test_rain_speeds_up_digging() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	var base: float = player.get_dig_speed_factor()
	_weather().force_event(WeatherManager.KIND_RAIN, 30.0)
	assert_almost_eq(player.get_dig_speed_factor(), base * 1.3, 0.001, "chuva: × 1.3")
	_weather().stop()
	assert_eq(player.get_dig_speed_factor(), base, "fim: volta exato")


func test_blizzard_burns_more_hunger() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	player.set_hunger(50.0)
	player.tick_hunger(1.0)
	var normal_loss: float = 50.0 - player.hunger
	assert_almost_eq(normal_loss, player.hunger_decay_per_sec, 0.0001, "sem clima: gasto normal")
	_weather().force_event(WeatherManager.KIND_BLIZZARD, 30.0)
	player.set_hunger(50.0)
	player.tick_hunger(1.0)
	assert_almost_eq(50.0 - player.hunger, player.hunger_decay_per_sec * 1.6, 0.0001, "nevasca: × 1.6 em 1 s")
	_weather().stop()
	player.set_hunger(50.0)
	player.tick_hunger(1.0)
	assert_almost_eq(50.0 - player.hunger, normal_loss, 0.0001, "fim: volta exato")


func test_ashstorm_shrinks_detector_range_and_restores() -> void:
	var det: MetalDetector = _spawn_detector()
	var base: float = det.max_detection_distance
	var spot: BuriedSpot = _spawn_spot(Vector3(0, 0, -base * 0.8))
	det._update_target_detection()
	assert_eq(det.get_current_target(), spot, "sem cinzas: alvo a 80 % do alcance aparece")

	_weather().force_event(WeatherManager.KIND_ASHSTORM, 30.0)
	assert_almost_eq(det.get_effective_detection_distance(), base * 0.6, 0.001, "alcance efetivo × 0.6")
	assert_almost_eq(det.get_radar_view_distance(), base * 0.6, 0.001, "escala do radar combina")
	det._refresh_level_stats()
	det._refresh_level_stats()
	assert_eq(det.max_detection_distance, base, "o nível não guarda nem acumula o efeito")
	assert_almost_eq(det.get_effective_detection_distance(), base * 0.6, 0.001)
	det._update_target_detection()
	assert_null(det.get_current_target(), "cinzas: o alvo a 80 % fica fora")
	assert_string_contains(det.get_footer_lines()[0], "%dm" % int(round(base * 0.6)), "rodapé mostra o alcance curto")

	_weather().stop()
	assert_eq(det.get_effective_detection_distance(), base, "fim: alcance exato de volta")
	assert_eq(det.get_radar_view_distance(), base)
	det._update_target_detection()
	assert_eq(det.get_current_target(), spot, "fim: o alvo volta")


func test_rain_jitters_display_without_extra_noise() -> void:
	var det: MetalDetector = _spawn_detector()
	_spawn_spot(Vector3(0, 0, -3))
	det._update_target_detection()
	var real: float = det.get_signal_strength()
	assert_gt(real, 0.0)
	assert_eq(det.get_display_strength(), real, "sem chuva: visor = sinal real")

	_weather().force_event(WeatherManager.KIND_RAIN, 30.0)
	var noise: float = WeatherManager.now_detector_noise()
	var max_jitter: float = 0.0
	for i: int in 40:
		max_jitter = maxf(max_jitter, absf(det.get_display_strength() - real))
	assert_gt(max_jitter, 0.0, "chuva: o visor treme")
	assert_lte(max_jitter, noise * MetalDetector.WEATHER_SIGNAL_JITTER + 0.0001, "tremor pequeno (legível)")
	assert_eq(det.get_signal_strength(), real, "o sinal real não muda")

	var meter: DisturbanceMeter = DisturbanceMeter.instance
	var own_meter: bool = meter == null
	if own_meter:
		meter = DisturbanceMeter.new()
		add_child_autofree(meter)
	var noise_before: float = meter.current_noise
	var targets_before: int = det.get_target_count()
	for i: int in 10:
		var blip: MetalDetector.RadarBlip = det.add_weather_noise_blip()
		assert_true(blip.is_noise)
		assert_lte(blip.strength, 0.3, "blip falso fraco")
		assert_lte(det.world_to_radar(blip.world_pos).length(), det.get_effective_detection_distance() + 0.01, "dentro do alcance")
	assert_eq(meter.current_noise, noise_before, "blips falsos não fazem barulho para os inimigos")
	assert_eq(det.get_target_count(), targets_before, "blips falsos não contam como alvos")
	assert_not_null(det.get_current_target(), "o alvo real continua")
	var noise_blips: int = 0
	for blip: MetalDetector.RadarBlip in det.get_blips():
		if blip.is_noise:
			noise_blips += 1
	assert_eq(noise_blips, 10, "aparecem no radar (esmaecidos pelo DetectorRadar)")

	_weather().stop()
	assert_eq(det.get_display_strength(), real, "fim: visor estável")


func test_debug_bridge_finds_weather_autoload() -> void:
	var bridge: Node = get_tree().root.get_node_or_null(^"DebugBridge")
	assert_not_null(bridge, "autoload DebugBridge")
	assert_true((bridge.get(&"DEBUG_CALL_METHODS") as PackedStringArray).has("force_weather"))
	assert_eq(bridge.call(&"_find_named", "CoreWeather"), WeatherManager.instance, "o passo call acha o autoload")
