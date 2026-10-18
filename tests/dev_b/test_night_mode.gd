extends GutTest

## Expedição noturna (#109): opção "Noite" na mesa (aba Expedições), modo levado no RPC de
## entrada e no sync de quem entra no meio, ambiente noturno aplicado numa cópia e restaurado
## (o MESMO Environment volta), multiplicador de raro, noite + clima sem estourar a névoa e o chip
## "Noite" no HUD.

const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const PRAIA_ENV: Environment = preload("res://world/environment_praia.tres")
const GELEIRA_ENV: Environment = preload("res://world/environment_geleira.tres")
const PRAIA: MapData = preload("res://items/maps/praia.tres")
const GELEIRA: MapData = preload("res://items/maps/geleira.tres")

var sm: SessionManager = null
var night: NightFx = null
var weather_fx: WeatherFx = null
var _old_save_path: String = ""


func before_all() -> void:
	_old_save_path = SaveManager.instance.save_path
	SaveManager.instance.use_test_save_dir("night_mode_test")


func after_all() -> void:
	SaveManager.instance.set_save_path(_old_save_path)


func before_each() -> void:
	GameState.instance.reset_state()
	sm = SessionManager.instance
	sm.scene_change_enabled = false
	night = NightFx.instance
	weather_fx = WeatherFx.instance


func after_each() -> void:
	weather_fx.finish(true)
	weather_fx.environment_root = null
	night.restore()
	night.environment_root = null
	WeatherManager.instance.stop()
	sm._current_map = null
	sm._night = false
	sm._pending_summary = {}
	sm.scene_change_enabled = true
	# O _rpc_return_to_lobby abre o resumo do dia e o scene_changing a tela de carregamento
	# (CoreSessionUI, que travam a pausa): fecha os dois para os próximos testes.
	var session_ui: SessionUI = SessionUI.instance
	if session_ui != null:
		session_ui._loading_token += 1
		session_ui.loading_screen.visible = false
		session_ui._on_summary_close_pressed()
		session_ui._refresh_expedition_bar()
	GameState.instance.reset_state()


## Cena mínima de mapa: WorldEnvironment com o Environment do mapa e uma DirectionalLight3D.
func _scene(env: Environment) -> Node3D:
	var scene: Node3D = Node3D.new()
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_energy = 1.2
	scene.add_child(sun)
	add_child_autofree(scene)
	night.environment_root = scene
	weather_fx.environment_root = scene
	return scene


func _set_night(map: MapData) -> void:
	sm._current_map = map
	sm._night = true


# --- Mesa ----------------------------------------------------------------------------------

func _select_map(ui: BaseStationUI, map_id: String) -> void:
	for i: int in ui._maps.size():
		if ui._maps[i].id == map_id:
			ui.map_list.select(i)
			ui.map_list.item_selected.emit(i)
			return
	fail_test("mapa %s não está na lista" % map_id)


func test_table_has_night_option_per_unlocked_map() -> void:
	var ui: BaseStationUI = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)
	await wait_frames(2)
	assert_not_null(ui.night_check, "opção Noite na aba Expedições")
	_select_map(ui, "praia")
	assert_true(ui.night_check.visible, "Praia desbloqueada: Noite disponível")
	assert_false(ui.night_check.disabled)
	assert_false(ui.night_check.button_pressed, "começa de dia")
	ui.night_check.button_pressed = true
	assert_true(ui.is_night_selected())
	assert_string_contains(ui.depart_btn.text, "noite")
	_select_map(ui, "campo")
	assert_false(ui.night_check.visible, "Campo ainda bloqueado: sem opção")
	_select_map(ui, "ilha_tesouro")
	assert_false(ui.night_check.visible, "Ilha não tem noite")
	_select_map(ui, "praia")
	assert_true(ui.night_check.button_pressed, "a escolha fica por mapa")
	GameState.instance.load_snapshot({"unlocked_maps": ["praia", "campo"]})
	_select_map(ui, "campo")
	assert_true(ui.night_check.visible, "Campo desbloqueado: Noite disponível")
	assert_false(ui.night_check.button_pressed, "Campo tem a sua escolha")


# --- Sessão ---------------------------------------------------------------------------------

func test_start_carries_night_and_lobby_clears_it() -> void:
	sm.request_start_expedition("praia", true)
	assert_true(SessionManager.is_night(), "host: noite")
	assert_eq(sm.get_current_map().id, "praia")
	assert_true(bool(sm._pending_summary.get("night", false)), "resumo do dia sabe que foi à noite")
	assert_eq(sm.get_sync_scene_args(), ["praia", true], "sync de quem entra no meio leva a noite")
	sm._rpc_return_to_lobby({})
	assert_false(SessionManager.is_night(), "lobby: dia de novo")
	assert_eq(sm.get_sync_scene_args(), ["", false])


func test_night_ignored_for_map_without_night() -> void:
	GameState.instance.load_snapshot({"unlocked_maps": ["praia", "ilha_tesouro"]})
	sm._rpc_enter_map("ilha_tesouro", true)
	assert_false(SessionManager.is_night(), "Ilha não tem noite")


func test_late_client_sync_receives_night() -> void:
	sm._rpc_sync_scene("praia", true)
	assert_true(SessionManager.is_night(), "cliente atrasado entra de noite")
	assert_eq(sm.get_current_map().id, "praia")
	sm._rpc_sync_scene("", false)
	assert_false(SessionManager.is_night())
	sm._rpc_enter_map("praia", false)
	assert_false(SessionManager.is_night(), "de dia")


# --- Raro -------------------------------------------------------------------------------------

func test_rare_multiplier() -> void:
	assert_almost_eq(NightMode.rare_chance(PRAIA.rare_variant_chance), PRAIA.rare_variant_chance, 0.0001, "de dia: a base")
	_set_night(PRAIA)
	var mult: float = float(NightMode.config("praia")["rare_mult"])
	assert_gt(mult, 1.0)
	assert_almost_eq(NightMode.rare_chance(PRAIA.rare_variant_chance), PRAIA.rare_variant_chance * mult, 0.0001, "à noite: × rare_mult")
	assert_eq(NightMode.rare_chance(0.0), 0.0, "chance 0 (chefe, gatilho) continua 0")
	assert_eq(NightMode.rare_chance(0.9), 1.0, "limitada a 1")


func test_spawner_gets_night_creatures() -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	add_child_autofree(spawner)
	var interval: float = spawner.ambient_interval_max
	NightMode.apply_to_spawner(spawner, "praia")
	assert_true(spawner.ambient_kinds.has(&"bat"), "morcegos na Praia à noite")
	assert_true(spawner.ambient_kinds.has(spawner.primary_kind), "os de dia continuam")
	assert_lt(spawner.ambient_interval_max, interval, "mais ativos")


# --- Ambiente ---------------------------------------------------------------------------------

func test_night_environment_applied_and_restored() -> void:
	var scene: Node3D = _scene(PRAIA_ENV)
	var we: WorldEnvironment = scene.get_child(0) as WorldEnvironment
	var sun: DirectionalLight3D = scene.get_child(1) as DirectionalLight3D
	var day_fog: float = PRAIA_ENV.fog_density
	var day_top: Color = (PRAIA_ENV.sky.sky_material as ShaderMaterial).get_shader_parameter("top_color")
	_set_night(PRAIA)
	night.start("praia", true)
	assert_true(night.is_active())
	assert_ne(we.environment, PRAIA_ENV, "cópia durante a noite")
	var copy: Environment = we.environment
	assert_gt(copy.fog_density, day_fog, "névoa noturna somada")
	assert_lt(sun.light_energy, 1.2 * 0.5, "luz do mapa reduzida")
	assert_gt(sun.light_color.b, sun.light_color.r, "e azulada")
	var night_top: Color = (copy.sky.sky_material as ShaderMaterial).get_shader_parameter("top_color")
	assert_lt(night_top.v, day_top.v * 0.5, "céu escuro")
	assert_eq(PRAIA_ENV.fog_density, day_fog, "o .tres não muda")
	assert_eq((PRAIA_ENV.sky.sky_material as ShaderMaterial).get_shader_parameter("top_color"), day_top, "o céu do .tres não muda")
	night.restore()
	assert_same(we.environment, PRAIA_ENV, "o MESMO Environment volta")
	assert_almost_eq(sun.light_energy, 1.2, 0.001, "luz de volta")
	assert_false(night.is_active())


func test_scene_change_restores() -> void:
	var scene: Node3D = _scene(PRAIA_ENV)
	_set_night(PRAIA)
	night.start("praia", true)
	sm.scene_changing.emit(SessionManager.LOBBY_SCENE)
	assert_same((scene.get_child(0) as WorldEnvironment).environment, PRAIA_ENV)
	assert_false(night.is_active())


func test_night_plus_weather_fog_is_capped() -> void:
	var scene: Node3D = _scene(GELEIRA_ENV)
	var we: WorldEnvironment = scene.get_child(0) as WorldEnvironment
	_set_night(GELEIRA)
	night.start("geleira", true)
	var night_env: Environment = we.environment
	weather_fx.start(WeatherManager.KIND_BLIZZARD)
	weather_fx.set_env_amount_now(1.0)
	var both: Environment = we.environment
	assert_ne(both, night_env, "o clima duplica a cópia noturna")
	assert_lte(both.fog_density, NightMode.MAX_FOG_DENSITY + 0.00001, "névoa somada com teto")
	assert_gt(both.fog_density, night_env.fog_density, "o clima ainda soma")
	assert_lt(both.adjustment_brightness, 1.0, "continua escuro")
	weather_fx.finish(true)
	assert_same(we.environment, night_env, "fim do clima: volta a noite")
	night.restore()
	assert_same(we.environment, GELEIRA_ENV, "fim da noite: volta o original")


func test_day_weather_fog_unchanged_by_cap() -> void:
	var scene: Node3D = _scene(GELEIRA_ENV)
	weather_fx.start(WeatherManager.KIND_BLIZZARD)
	weather_fx.set_env_amount_now(1.0)
	var t: Dictionary = WeatherFx.ENV_TARGETS[WeatherManager.KIND_BLIZZARD]
	var copy: Environment = (scene.get_child(0) as WorldEnvironment).environment
	assert_almost_eq(copy.fog_density, GELEIRA_ENV.fog_density + float(t["fog_add"]), 0.0001, "de dia o teto não corta a nevasca")


# --- HUD ------------------------------------------------------------------------------------

func test_hud_night_chip() -> void:
	var player: Player = (load("res://gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	add_child_autofree(player)
	await wait_frames(2)
	var chips: Node = player.get_node("HUD/TopChips")
	_scene(PRAIA_ENV)
	_set_night(PRAIA)
	night.start("praia", true)
	var chip: UiChip = chips.get_node_or_null("NightChip") as UiChip
	assert_not_null(chip, "chip Noite no topo")
	assert_eq(chip.label.text, "Noite")
	assert_eq(chip.icon_name, "moon")
	assert_not_null(chip.icon_rect.texture, "ícone da lua")
	assert_eq(chips.get_children().filter(func(c: Node) -> bool: return c.name == "NightChip").size(), 1, "um só chip")
	assert_not_null(night.detector_glow, "visor do detector ilumina à noite")
	night.restore()
	await wait_frames(2)
	assert_null(chips.get_node_or_null("NightChip"), "de dia some")


func test_teardown_leaves_pause_usable() -> void:
	sm.scene_changing.emit(SessionManager.LOBBY_SCENE)
	sm._rpc_enter_map("praia", true)
	sm._rpc_return_to_lobby({})
	after_each()
	assert_true(PauseMenu.instance.can_open(), "sem carregamento nem resumo abertos depois do teste")
