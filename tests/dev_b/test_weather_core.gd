extends GutTest

## CoreWeather (#99): agendamento no host, fases, modificadores neutros fora do "active" e
## cliente que nunca agenda. Determinístico: instâncias fora da árvore, seed fixa e tick().


## Cliente: nunca decide o clima (o HostSync diria que não é o host).
class ClientWeather extends WeatherManager:
	func _is_host() -> bool:
		return false


var _wm: WeatherManager = null


func before_each() -> void:
	_wm = WeatherManager.new()
	_wm.set_seed(99)


func after_each() -> void:
	_wm.free()
	if WeatherManager.instance != null:
		WeatherManager.instance.stop()


func _assert_neutral(wm: WeatherManager, where: String) -> void:
	assert_eq(wm.dig_speed_mult(), 1.0, "%s: cavar neutro" % where)
	assert_eq(wm.detector_noise(), 0.0, "%s: sem ruído" % where)
	assert_eq(wm.radar_scale(), 1.0, "%s: radar neutro" % where)
	assert_eq(wm.hunger_mult(), 1.0, "%s: fome neutra" % where)


func test_neutral_without_event() -> void:
	assert_eq(_wm.phase(), WeatherManager.PHASE_NONE)
	assert_eq(_wm.current_kind(), "")
	assert_false(_wm.is_active())
	_assert_neutral(_wm, "sem evento")


func test_host_cycle_warning_active_none() -> void:
	watch_signals(_wm)
	var cfg: Dictionary = WeatherManager.config_for("praia")
	_wm.start_cycle("praia")
	assert_eq(_wm.phase(), WeatherManager.PHASE_NONE)
	assert_between(_wm.time_left(), float(cfg["interval_min"]), float(cfg["interval_max"]), "primeiro intervalo dentro de min/max")

	_wm.tick(_wm.time_left())
	assert_eq(_wm.phase(), WeatherManager.PHASE_WARNING)
	assert_eq(_wm.current_kind(), WeatherManager.KIND_RAIN)
	assert_almost_eq(_wm.time_left(), float(cfg["warning_s"]), 0.001)
	_assert_neutral(_wm, "aviso")
	assert_signal_emitted_with_parameters(_wm, "weather_changed", [WeatherManager.KIND_RAIN, WeatherManager.PHASE_WARNING])

	_wm.tick(_wm.time_left())
	assert_true(_wm.is_active())
	assert_between(_wm.time_left(), float(cfg["duration_min"]), float(cfg["duration_max"]), "duração dentro de min/max")
	assert_between(_wm.intensity(), WeatherManager.INTENSITY_JITTER.x, WeatherManager.INTENSITY_JITTER.y)
	assert_gt(_wm.dig_speed_mult(), 1.0, "chuva: cava mais rápido")
	assert_gt(_wm.detector_noise(), 0.0, "chuva: ruído no visor")
	assert_eq(_wm.radar_scale(), 1.0, "chuva não mexe no alcance")
	assert_eq(_wm.hunger_mult(), 1.0, "chuva não mexe na fome")

	_wm.tick(_wm.time_left())
	assert_eq(_wm.phase(), WeatherManager.PHASE_NONE)
	assert_eq(_wm.current_kind(), "")
	assert_signal_emitted_with_parameters(_wm, "weather_changed", [WeatherManager.KIND_RAIN, WeatherManager.PHASE_NONE])
	assert_signal_emit_count(_wm, "weather_changed", 3)
	assert_between(_wm.time_left(), float(cfg["interval_min"]), float(cfg["interval_max"]), "próximo intervalo dentro de min/max")
	_assert_neutral(_wm, "depois do evento")


func test_intervals_and_durations_stay_in_range() -> void:
	for map_id: String in WeatherManager.WEATHER_BY_MAP.keys():
		var cfg: Dictionary = WeatherManager.config_for(map_id)
		_wm.start_cycle(map_id)
		for i: int in 6:
			assert_between(_wm.time_left(), float(cfg["interval_min"]), float(cfg["interval_max"]), "%s intervalo" % map_id)
			_wm.tick(_wm.time_left())
			assert_eq(_wm.current_kind(), str(cfg["kind"]), "%s tipo" % map_id)
			_wm.tick(_wm.time_left())
			assert_between(_wm.time_left(), float(cfg["duration_min"]), float(cfg["duration_max"]), "%s duração" % map_id)
			_wm.tick(_wm.time_left())


func test_ruinas_never_schedules() -> void:
	watch_signals(_wm)
	_wm.start_cycle("ruinas")
	_wm.tick(100000.0)
	assert_eq(_wm.phase(), WeatherManager.PHASE_NONE)
	assert_signal_not_emitted(_wm, "weather_changed")
	_wm.force_weather()
	assert_eq(_wm.phase(), WeatherManager.PHASE_NONE, "Ruínas: force_weather também não dispara")


func test_client_never_schedules_and_applies_sync() -> void:
	var client: ClientWeather = ClientWeather.new()
	watch_signals(client)
	client.start_cycle("praia")
	client.tick(100000.0)
	client.force_weather()
	client.force_event(WeatherManager.KIND_RAIN, 30.0)
	assert_eq(client.phase(), WeatherManager.PHASE_NONE, "cliente não agenda nem força")
	assert_signal_not_emitted(client, "weather_changed")
	client._rpc_sync({"kind": WeatherManager.KIND_BLIZZARD, "phase": WeatherManager.PHASE_ACTIVE, "time_left": 40.0, "intensity": 1.0, "map_id": "geleira"})
	assert_true(client.is_active(), "aplica o estado do host")
	assert_almost_eq(client.hunger_mult(), 1.6, 0.001)
	client.tick(100.0)
	assert_true(client.is_active(), "o fim também vem do host")
	client._rpc_sync({"kind": WeatherManager.KIND_BLIZZARD, "phase": WeatherManager.PHASE_NONE, "time_left": 200.0, "intensity": 1.0, "map_id": "geleira"})
	assert_eq(client.phase(), WeatherManager.PHASE_NONE)
	assert_eq(client.current_kind(), "")
	assert_signal_emitted_with_parameters(client, "weather_changed", [WeatherManager.KIND_BLIZZARD, WeatherManager.PHASE_NONE])
	client.free()


func test_force_event_and_stop() -> void:
	_wm.force_event(WeatherManager.KIND_BLIZZARD, 30.0)
	assert_true(_wm.is_active())
	assert_almost_eq(_wm.hunger_mult(), 1.6, 0.001)
	assert_eq(_wm.dig_speed_mult(), 1.0)
	_wm.force_event(WeatherManager.KIND_ASHSTORM, 30.0)
	assert_almost_eq(_wm.radar_scale(), 0.6, 0.001)
	_wm.stop()
	_assert_neutral(_wm, "stop")
	assert_eq(_wm.phase(), WeatherManager.PHASE_NONE)


func test_force_weather_uses_map_with_short_warning() -> void:
	_wm.start_cycle("geleira")
	_wm.force_weather()
	assert_eq(_wm.phase(), WeatherManager.PHASE_WARNING)
	assert_eq(_wm.current_kind(), WeatherManager.KIND_BLIZZARD)
	assert_almost_eq(_wm.time_left(), WeatherManager.FORCE_WARNING_S, 0.001)
	_wm.tick(WeatherManager.FORCE_WARNING_S)
	assert_true(_wm.is_active())


func test_static_shortcuts_follow_autoload() -> void:
	var core: WeatherManager = WeatherManager.instance
	assert_not_null(core, "autoload CoreWeather presente")
	assert_eq(WeatherManager.now_dig_speed_mult(), 1.0)
	core.force_event(WeatherManager.KIND_RAIN, 10.0)
	assert_almost_eq(WeatherManager.now_dig_speed_mult(), 1.3, 0.001)
	assert_almost_eq(WeatherManager.now_detector_noise(), 0.35, 0.001)
	core.stop()
	assert_eq(WeatherManager.now_detector_noise(), 0.0)


func test_scene_change_stops_weather() -> void:
	var core: WeatherManager = WeatherManager.instance
	core.force_event(WeatherManager.KIND_RAIN, 10.0)
	SessionManager.instance.scene_changing.emit("res://world/lobby_base.tscn")
	assert_eq(core.phase(), WeatherManager.PHASE_NONE, "troca de cena volta ao neutro")
	core.force_event(WeatherManager.KIND_RAIN, 10.0)
	SessionManager.instance.expedition_ending.emit("praia")
	assert_eq(core.phase(), WeatherManager.PHASE_NONE, "fim da expedição volta ao neutro")
