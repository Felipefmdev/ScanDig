extends GutTest

## Aba Acessibilidade (#140): [accessibility] com sanitize e padrões neutros; paleta do daltonismo
## (radar, barras, marcadores do coop) pelo A11y.color; tremor de tela multiplicado; flashes
## reduzidos; alternar × segurar; legendas emitidas, limitadas e sem spam. Nada é gravado
## (set_section com persist = false).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const MARKER_FLAG: Script = preload("res://gameplay/player/coop_marker_flag.gd")
const MODES: Array[String] = ["protanopia", "deuteranopia", "tritanopia"]

var _shown: Array[String] = []


func before_each() -> void:
	_shown.clear()
	A11y.reset_holds()
	A11y.instance.reset_captions()
	if not A11y.instance.caption_shown.is_connected(_on_caption):
		A11y.instance.caption_shown.connect(_on_caption)


func after_each() -> void:
	SettingsManager.instance.restore_defaults(SettingsManager.ACCESSIBILITY, false)
	A11y.reset_holds()
	A11y.instance.reset_captions()
	if A11y.instance.caption_shown.is_connected(_on_caption):
		A11y.instance.caption_shown.disconnect(_on_caption)
	CaptionsHud.instance.clear()
	for action: StringName in [&"drop", &"interact", &"use_tool"]:
		Input.action_release(action)


func _on_caption(text: String) -> void:
	_shown.append(text)


func _set_a11y(values: Dictionary) -> void:
	SettingsManager.instance.set_section(SettingsManager.ACCESSIBILITY, values, false)


func _player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


# --- Configuração --------------------------------------------------------------------

func test_defaults_are_neutral_and_sanitized() -> void:
	var d: Dictionary = SettingsManager.DEFAULTS[SettingsManager.ACCESSIBILITY]
	assert_eq(d, {"colorblind_mode": "off", "screen_shake": 1.0, "reduce_flashes": false, "hold_mode": "hold", "captions": false})
	var bad: Dictionary = SettingsManager.sanitize(SettingsManager.ACCESSIBILITY,
		{"colorblind_mode": "verde", "screen_shake": 7, "reduce_flashes": "sim", "hold_mode": 1, "captions": 0})
	assert_eq(bad["colorblind_mode"], "off", "modo desconhecido volta ao padrão")
	assert_eq(bad["screen_shake"], 1.0, "tremor limitado a 0–100 %")
	assert_false(bad["reduce_flashes"])
	assert_eq(bad["hold_mode"], "hold")
	assert_false(bad["captions"])
	assert_eq(SettingsManager.sanitize(SettingsManager.ACCESSIBILITY, {"screen_shake": -1.0})["screen_shake"], 0.0)
	var ok: Dictionary = SettingsManager.sanitize(SettingsManager.ACCESSIBILITY,
		{"colorblind_mode": "tritanopia", "screen_shake": 0.35, "reduce_flashes": true, "hold_mode": "toggle", "captions": true})
	assert_eq(ok, {"colorblind_mode": "tritanopia", "screen_shake": 0.35, "reduce_flashes": true, "hold_mode": "toggle", "captions": true})


func test_settings_tab_applies_and_restores() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	assert_eq(menu.tabs.get_tab_count(), 5)
	assert_eq(menu.tabs.get_tab_title(SettingsMenu.TAB_ACCESSIBILITY), "Acessibilidade")
	assert_eq(menu.colorblind_option.item_count, SettingsManager.COLORBLIND_MODES.size())
	assert_eq(menu.shake_slider.value, 100.0)
	menu.colorblind_option.select(SettingsManager.COLORBLIND_MODES.find("deuteranopia"))
	menu.shake_slider.value = 40.0
	menu.reduce_flashes_check.button_pressed = true
	menu.hold_mode_option.select(SettingsManager.HOLD_MODES.find("toggle"))
	menu.captions_check.button_pressed = true
	assert_true(menu.has_pending_changes(), "pendente até Aplicar")
	assert_eq(A11y.colorblind_mode(), "off", "antes de Aplicar nada muda")
	menu._on_apply_pressed()
	assert_eq(A11y.colorblind_mode(), "deuteranopia")
	assert_almost_eq(A11y.shake_scale(), 0.4, 0.001)
	assert_eq(A11y.flash_scale(), A11y.REDUCED_FLASH)
	assert_true(A11y.is_toggle_hold())
	assert_true(A11y.captions_enabled())
	assert_false(menu.has_pending_changes())
	menu.tabs.current_tab = SettingsMenu.TAB_ACCESSIBILITY
	menu._on_defaults_pressed()
	assert_eq(SettingsManager.instance.get_section(SettingsManager.ACCESSIBILITY), SettingsManager.DEFAULTS[SettingsManager.ACCESSIBILITY], "Restaurar padrão da aba")
	assert_eq(menu.shake_slider.value, 100.0)


# --- Daltonismo ------------------------------------------------------------------------

func test_every_palette_is_complete_and_differs() -> void:
	for mode: String in MODES:
		var palette: Dictionary = A11y.PALETTES[mode]
		for role: StringName in A11y.DEFAULT_PALETTE.keys():
			assert_true(palette.has(role), "%s define %s" % [mode, role])
		for role: StringName in [&"radar_enemy", &"material_ouro", &"bar_health", &"threat_0", &"marker_signal", &"marker_danger"]:
			assert_ne(A11y.color_for(role, mode), A11y.color_for(role, "off"), "%s troca %s" % [mode, role])
		# Inimigo × ouro e perigo × sinal continuam bem diferentes (o par que mais confunde).
		assert_gt(_distance(A11y.color_for(&"radar_enemy", mode), A11y.color_for(&"material_ouro", mode)), 0.3, mode)
		assert_gt(_distance(A11y.color_for(&"marker_danger", mode), A11y.color_for(&"marker_signal", mode)), 0.3, mode)


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_radar_and_markers_follow_the_mode() -> void:
	assert_eq(DetectorRadar.get_material_color(ItemData.MaterialType.OURO), Color(1.0, 0.8, 0.15), "desligado: a cor de sempre")
	var flag: Node3D = MARKER_FLAG.new() as Node3D
	autofree(flag)
	flag.set("marker_type", 1)  # MarkerType.DANGER
	assert_eq(flag.call("get_type_config")["color"], Color(0.95, 0.25, 0.2))
	for mode: String in MODES:
		_set_a11y({"colorblind_mode": mode})
		assert_eq(DetectorRadar.get_material_color(ItemData.MaterialType.OURO), A11y.PALETTES[mode][&"material_ouro"], mode)
		assert_eq(DetectorRadar.get_material_color(ItemData.MaterialType.ALUMINIO), A11y.PALETTES[mode][&"material_aluminio"], mode)
		assert_eq(flag.call("get_type_config")["color"], A11y.PALETTES[mode][&"marker_danger"], mode)
	assert_eq(MARKER_FLAG.get("TYPE_CONFIG")[1]["color"], Color(0.95, 0.25, 0.2), "o TYPE_CONFIG não é alterado")


func test_bars_are_recolored_live() -> void:
	var player: Player = _player()
	var health_fill: StyleBoxFlat = player.health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	assert_true(health_fill.bg_color.is_equal_approx(UiPalette.RED_BURNT), "desligado: a vida de sempre")
	assert_false(player.health_bar.has_theme_stylebox_override(&"fill"), "desligado: o fill do tema, sem override")
	_set_a11y({"colorblind_mode": "tritanopia"})
	health_fill = player.health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	assert_eq(health_fill.bg_color, A11y.PALETTES["tritanopia"][&"bar_health"], "a barra muda na hora")
	var hunger: ProgressBar = player.find_child("HungerBar", true, false) as ProgressBar
	assert_eq((hunger.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color, A11y.PALETTES["tritanopia"][&"bar_hunger"])
	A11y.tint_bar(player.threat_bar, A11y.threat_role(3))
	assert_eq((player.threat_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color, A11y.PALETTES["tritanopia"][&"threat_3"])
	_set_a11y({"colorblind_mode": "off"})
	assert_true((player.health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color.is_equal_approx(UiPalette.RED_BURNT), "volta ao desligar")
	assert_false(player.health_bar.has_theme_stylebox_override(&"fill"), "e o override sai")


# --- Tremor e flashes ---------------------------------------------------------------

func test_screen_shake_is_multiplied() -> void:
	var player: Player = _player()
	_set_a11y({"screen_shake": 0.0})
	player._shake_camera(0.1, 0.3)
	assert_null(player._shake_tween, "0 %: nenhum tremor")
	_set_a11y({"screen_shake": 0.5})
	seed(7)
	var biggest: float = 0.0
	for i: int in 20:
		player._shake_camera(0.1, 0.3)
		player._shake_tween.custom_step(0.04)
		biggest = maxf(biggest, maxf(absf(player.camera.h_offset), absf(player.camera.v_offset)))
	assert_gt(biggest, 0.0, "50 %: ainda treme")
	assert_lte(biggest, 0.05 + 0.0001, "50 %: no máximo metade da força")


func test_reduced_flashes_on_explosion_and_damage() -> void:
	var player: Player = _player()
	assert_eq(_explosion_energy(player), 8.0, "padrão: flash cheio")
	_set_a11y({"reduce_flashes": true})
	assert_almost_eq(_explosion_energy(player), 8.0 * A11y.REDUCED_FLASH, 0.001, "reduzido")

	var enemy: EnemyBase = EnemyBase.new()
	add_child_autofree(enemy)
	var shader: ShaderMaterial = LowPolyMesh.make_material()
	var std: StandardMaterial3D = StandardMaterial3D.new()
	std.albedo_color = Color.WHITE
	enemy._register_flash_material(shader)
	enemy._register_flash_material(std)
	enemy._flash(Color.RED)
	assert_almost_eq(float(shader.get_shader_parameter(&"flash_amount")), A11y.REDUCED_FLASH, 0.001, "flash de dano mais fraco")
	assert_eq(std.albedo_color, Color.WHITE.lerp(Color.RED, A11y.REDUCED_FLASH), "cor só em parte")


func _explosion_energy(player: Player) -> float:
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else player
	var before: Array[Node] = parent.get_children()
	player.show_explosion(Vector3(0, -50, 0))
	var energy: float = -1.0
	for child: Node in parent.get_children():
		if child is OmniLight3D and not before.has(child):
			energy = (child as OmniLight3D).light_energy
			child.queue_free()
	return energy


# --- Alternar × segurar ---------------------------------------------------------------

func test_hold_mode_reads_the_button() -> void:
	Input.action_press(&"drop")
	assert_true(A11y.just_pressed(&"drop"))
	assert_true(A11y.holding(&"drop"))
	assert_true(A11y.latched(&"drop"))
	Input.action_release(&"drop")
	assert_false(A11y.holding(&"drop"), "segurar: soltou, parou")


func test_toggle_mode_hold_ends_on_next_press() -> void:
	_set_a11y({"hold_mode": "toggle"})
	Input.action_press(&"drop")
	assert_true(A11y.just_pressed(&"drop"), "o toque começa")
	Input.action_release(&"drop")
	await get_tree().process_frame
	assert_true(A11y.holding(&"drop"), "solto, continua")
	await get_tree().process_frame
	assert_true(A11y.holding(&"drop"), "continua sem segurar")
	await get_tree().process_frame
	Input.action_press(&"drop")
	assert_false(A11y.just_pressed(&"drop"), "o toque que para não começa outra")
	assert_false(A11y.holding(&"drop"), "outro toque para")
	assert_false(A11y.just_pressed(&"drop"), "nem depois, no mesmo frame")
	Input.action_release(&"drop")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_press(&"drop")
	assert_true(A11y.just_pressed(&"drop"), "parada: o próximo toque começa de novo")


func test_toggle_mode_latch_and_careful_tap() -> void:
	_set_a11y({"hold_mode": "toggle"})
	assert_false(A11y.latched(&"interact"))
	await get_tree().process_frame
	Input.action_press(&"interact")
	assert_true(A11y.latched(&"interact"), "toque liga")
	Input.action_release(&"interact")
	for i: int in 3:
		await get_tree().process_frame
		assert_true(A11y.latched(&"interact"), "fica ligado sem segurar")
	await get_tree().process_frame
	Input.action_press(&"interact")
	assert_false(A11y.latched(&"interact"), "outro toque desliga")
	Input.action_release(&"interact")

	var notices: Array[String] = []
	var on_notice: Callable = func(text: String) -> void: notices.append(text)
	A11y.instance.notice_shown.connect(on_notice)
	A11y.instance.on_careful_tap(500)
	assert_false(A11y.careful_held(), "segurar o Shift (correr) não trava o cuidado")
	A11y.instance.on_careful_tap(120)
	assert_true(A11y.careful_held(), "toque curto trava o cuidado")
	A11y.instance.on_careful_tap(120)
	assert_false(A11y.careful_held(), "outro toque destrava")
	A11y.instance.notice_shown.disconnect(on_notice)
	assert_eq(notices, [A11y.CAREFUL_ON_TEXT, A11y.CAREFUL_OFF_TEXT] as Array[String], "aviso na tela a cada troca")
	_set_a11y({"hold_mode": "hold"})
	A11y.instance.on_careful_tap(120)
	assert_false(A11y.careful_held(), "modo segurar: só com o Shift apertado")


func test_player_eating_in_toggle_mode() -> void:
	var player: Player = _player()
	# O _physics_process do player é chamado à mão, no mesmo frame do Input.action_press.
	player.set_physics_process(false)
	_set_a11y({"hold_mode": "toggle"})
	var food: CarriedItem = CarriedItem.create_from_tool_data(load("res://items/tools/batata_esquecida.tres") as ToolData)
	player.inventory.add_item(food)
	player.inventory.select(player.inventory.slots.find(food))
	player.health = 50.0
	Input.action_press(&"use_tool")
	player._physics_process(0.016)
	Input.action_release(&"use_tool")
	assert_true(player.is_eating(), "um clique começa a comer")
	for i: int in 3:
		await get_tree().process_frame
		player._physics_process(0.1)
	assert_true(player.is_eating(), "continua sem segurar o botão")
	await get_tree().process_frame
	Input.action_press(&"use_tool")
	player._physics_process(0.016)
	Input.action_release(&"use_tool")
	assert_false(player.is_eating(), "outro clique para (e não começa de novo)")
	assert_eq(player.health, 50.0, "parou antes de terminar")
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_press(&"use_tool")
	player._physics_process(0.016)
	Input.action_release(&"use_tool")
	for i: int in 4:
		await get_tree().process_frame
		player._physics_process(0.3)
	assert_gt(player.health, 50.0, "sem outro clique, come até o fim")


# --- Legendas ---------------------------------------------------------------------------

func test_captions_off_by_default() -> void:
	assert_false(A11y.caption(A11y.CAPTION_BOSS))
	assert_eq(_shown, [] as Array[String])


func test_caption_cooldown_and_limit() -> void:
	_set_a11y({"captions": true})
	var a11y: A11y = A11y.instance
	assert_true(a11y.request_caption(A11y.CAPTION_BOSS, 1000))
	assert_false(a11y.request_caption(A11y.CAPTION_BOSS, 2000), "a mesma, logo depois: sem spam")
	assert_true(a11y.request_caption(A11y.CAPTION_WEATHER, 2000))
	assert_true(a11y.request_caption(A11y.CAPTION_EXPLOSION, 2100))
	assert_false(a11y.request_caption(A11y.CAPTION_CREATURE, 2200), "no máximo %d na tela" % A11y.CAPTION_MAX)
	assert_true(a11y.request_caption(A11y.CAPTION_CREATURE, 4500), "a primeira sumiu: cabe outra")
	assert_true(a11y.request_caption(A11y.CAPTION_BOSS, 1000 + int(A11y.CAPTION_COOLDOWN * 1000.0) + 1), "depois do intervalo volta")
	assert_eq(_shown, [A11y.CAPTION_BOSS, A11y.CAPTION_WEATHER, A11y.CAPTION_EXPLOSION, A11y.CAPTION_CREATURE, A11y.CAPTION_BOSS] as Array[String])


func test_captions_are_shown_on_screen_and_capped() -> void:
	var hud: CaptionsHud = CaptionsHud.instance
	assert_not_null(hud, "autoload CoreCaptionsUI")
	_set_a11y({"captions": true})
	A11y.caption(A11y.CAPTION_WEATHER)
	assert_eq(hud.lines(), PackedStringArray([A11y.CAPTION_WEATHER]))
	for text: String in ["a", "b", "c", "d"]:
		hud.show_line(text)
	assert_eq(hud.lines().size(), A11y.CAPTION_MAX, "a mais velha sai")


func test_sources_emit_captions() -> void:
	_set_a11y({"captions": true})
	var player: Player = _player()
	player.global_position = Vector3.ZERO
	assert_true(player.is_in_group(Player.LOCAL_GROUP), "player local do teste")
	# Clima (WeatherManager): aviso vira legenda.
	WeatherManager.instance.weather_changed.emit(WeatherManager.KIND_RAIN, WeatherManager.PHASE_WARNING)
	# Bicho perto (SFX), longe não.
	SFX.play_at(SFX.WOLF_GROWL, Vector3(100, 0, 0))
	assert_false(_shown.has(A11y.CAPTION_CREATURE), "longe não legenda")
	SFX.play_at(SFX.WOLF_GROWL, Vector3(3, 0, 0))
	# Explosão perto.
	player.show_explosion(Vector3(2, -50, 0))
	player.show_explosion(Vector3(2, 0, 0))
	# Chefe entrando (EnemySpawner): grupo "bosses".
	A11y.instance.reset_captions()
	var boss: EnemyBase = EnemyBase.new()
	boss.add_to_group(A11y.BOSS_GROUP)
	add_child_autofree(boss)
	await get_tree().process_frame
	assert_eq(_shown, [A11y.CAPTION_WEATHER, A11y.CAPTION_CREATURE, A11y.CAPTION_EXPLOSION, A11y.CAPTION_BOSS] as Array[String])
