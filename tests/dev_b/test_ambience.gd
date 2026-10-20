extends GutTest

## Ambiente por mapa (#123): todo mapa tem loop que existe e é loop, o fade entra até o volume do
## mapa e sai até o silêncio (parando o player), noite troca o loop onde há variante e o clima
## (#99) soma o seu loop: baixo no aviso, cheio no active, fora no fim.

var _am: AmbienceManager = null


func before_each() -> void:
	_am = AmbienceManager.new()
	_am.fade_in_s = 0.05
	_am.fade_out_s = 0.05
	_am.weather_fade_s = 0.05
	add_child_autofree(_am)


func _map_ids() -> Array[String]:
	var ids: Array[String] = []
	for f: String in DirAccess.get_files_at("res://items/maps/"):
		if f.ends_with(".tres"):
			var m: MapData = load("res://items/maps/" + f) as MapData
			if m != null:
				ids.append(m.id)
	return ids


func _assert_loop(path: String) -> void:
	assert_true(ResourceLoader.exists(path), "existe: %s" % path)
	var s: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
	assert_not_null(s, "ogg: %s" % path)
	if s != null:
		assert_true(s.loop, "loop=true no import: %s" % path)
		assert_gt(s.get_length(), 10.0, "loop longo o bastante: %s" % path)


func test_every_map_has_a_looping_ambience() -> void:
	var ids: Array[String] = _map_ids()
	assert_gte(ids.size(), 5, "os cinco mapas")
	for id: String in ids:
		assert_true(AmbienceManager.AMBIENT_BY_MAP.has(id), "ambiente de %s" % id)
		_assert_loop(AmbienceManager.ambient_path(id, false))
		_assert_loop(AmbienceManager.ambient_path(id, true))
	_assert_loop(AmbienceManager.ambient_path(AmbienceManager.BASE_ID, false))
	for kind: String in AmbienceManager.WEATHER_LOOPS:
		_assert_loop(str((AmbienceManager.WEATHER_LOOPS[kind] as Dictionary)["path"]))
	for kind: String in [WeatherManager.KIND_RAIN, WeatherManager.KIND_BLIZZARD, WeatherManager.KIND_ASHSTORM]:
		assert_true(AmbienceManager.WEATHER_LOOPS.has(kind), "clima %s tem loop" % kind)


func test_night_variant_and_scene_parsing() -> void:
	assert_ne(AmbienceManager.ambient_path("campo", true), AmbienceManager.ambient_path("campo", false), "grilos à noite")
	assert_eq(AmbienceManager.ambient_path("ruinas", true), AmbienceManager.ambient_path("ruinas", false), "sem variante: o de dia")
	assert_eq(AmbienceManager.map_id_from_scene("res://world/map_cratera.tscn"), "cratera")
	assert_eq(AmbienceManager.map_id_from_scene("res://world/lobby_base.tscn"), "")


func test_bus_is_ambient_under_sfx() -> void:
	var i: int = AudioServer.get_bus_index(AmbienceManager.BUS)
	assert_gte(i, 0, "bus Ambient existe")
	assert_eq(AudioServer.get_bus_send(i), SFX.BUS, "Ambient manda para o SFX")
	assert_eq(_am.map_player().bus, AmbienceManager.BUS)


func test_fade_in_reaches_map_volume_and_fade_out_stops() -> void:
	_am.play_map("praia", false)
	var p: AudioStreamPlayer = _am.map_player()
	assert_true(p.playing, "toca ao entrar")
	assert_eq(p.volume_db, AmbienceManager.SILENT_DB, "começa calado")
	await wait_seconds(0.2)
	var target: float = float((AmbienceManager.AMBIENT_BY_MAP["praia"] as Dictionary)["db"])
	assert_almost_eq(p.volume_db, target, 0.1, "fade-in termina no volume do mapa")
	_am.stop_all()
	await wait_seconds(0.2)
	assert_lte(p.volume_db, AmbienceManager.SILENT_DB + 0.1, "fade-out termina no silêncio")
	assert_false(p.playing, "e para")


func test_weather_loop_fades_with_phase() -> void:
	_am.play_map("campo", false)
	var w: AudioStreamPlayer = _am.weather_player()
	var full: float = float((AmbienceManager.WEATHER_LOOPS["rain"] as Dictionary)["db"])
	_am.set_weather(WeatherManager.KIND_RAIN, WeatherManager.PHASE_WARNING)
	await wait_seconds(0.2)
	assert_true(w.playing)
	assert_almost_eq(w.volume_db, full + AmbienceManager.WARNING_DB_OFFSET, 0.1, "aviso: chuva ao longe")
	_am.set_weather(WeatherManager.KIND_RAIN, WeatherManager.PHASE_ACTIVE)
	await wait_seconds(0.2)
	assert_almost_eq(w.volume_db, full, 0.1, "active: chuva cheia")
	_am.set_weather(WeatherManager.KIND_RAIN, WeatherManager.PHASE_NONE)
	await wait_seconds(0.2)
	assert_false(w.playing, "fim do evento: sai")


## Teste de ouvido: o fundo e o clima nunca cobrem os passos (-16 dB + offset da superfície).
func test_ambience_and_weather_stay_below_footsteps() -> void:
	var player: Player = Player.new()
	var step_db: float = player.footsteps_volume_db
	player.free()
	for id: String in AmbienceManager.AMBIENT_BY_MAP:
		assert_lte(float((AmbienceManager.AMBIENT_BY_MAP[id] as Dictionary)["db"]), step_db + 1.0, "fundo de %s" % id)
	var ground: Dictionary = {"rain": [&"sand", &"grass"], "blizzard": [&"snow"], "ashstorm": [&"crystal"]}
	for kind: String in AmbienceManager.WEATHER_LOOPS:
		var db: float = float((AmbienceManager.WEATHER_LOOPS[kind] as Dictionary)["db"])
		for surface: StringName in ground[kind]:
			assert_lte(db, step_db + SFX.footstep_volume_offset(surface), "%s abaixo do passo em %s" % [kind, surface])


## N2: a Base tem o seu loop (brisa e madeira da tenda) com fade, sem clima por cima; o título fica
## em silêncio.
func test_base_has_its_own_loop_and_title_is_silent() -> void:
	_am.play_map("geleira", false)
	_am._on_scene_loaded("res://world/lobby_base.tscn")
	await wait_seconds(0.2)
	var p: AudioStreamPlayer = _am.map_player()
	assert_true(_am.is_map_playing(), "a Base toca o seu ambiente")
	assert_eq(p.stream.resource_path, AmbienceManager.ambient_path(AmbienceManager.BASE_ID, false))
	var target: float = float((AmbienceManager.AMBIENT_BY_MAP[AmbienceManager.BASE_ID] as Dictionary)["db"])
	assert_almost_eq(p.volume_db, target, 0.1, "fade-in até o volume da Base")
	_am.set_weather(WeatherManager.KIND_RAIN, WeatherManager.PHASE_ACTIVE)
	await wait_seconds(0.2)
	assert_false(_am.weather_player().playing, "sem clima na Base")
	_am._on_scene_loaded("res://world/title_screen.tscn")
	await wait_seconds(0.2)
	assert_false(_am.is_map_playing(), "título sem ambiente")
	assert_false(p.playing)
