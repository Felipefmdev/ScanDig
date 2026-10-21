extends GutTest

var _locale: String = ""

func before_each() -> void:
	_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")

func after_each() -> void:
	TranslationServer.set_locale(_locale)

class ReadoutDetector extends MetalDetector:
	var test_target: BuriedSpot = null
	var test_distance: float = INF
	var test_pin: bool = false
	var test_pin_level: int = 0
	var test_footer: PackedStringArray = PackedStringArray()
	var test_level: int = 1
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func get_current_target() -> BuriedSpot:
		return test_target if is_instance_valid(test_target) else null
	func get_target_distance() -> float:
		return test_distance
	func is_pinpointing() -> bool:
		return test_pin
	func get_pinpointer_level() -> int:
		return test_pin_level
	func get_footer_lines() -> PackedStringArray:
		return test_footer
	func get_detector_level() -> int:
		return test_level


func _radar(det: MetalDetector) -> Control:
	var path: String = "res://gameplay/detector/detector_radar.gd"
	var radar: Control = (load(path) as Script).new()
	autofree(radar)
	radar.set("detector", det)
	return radar


func test_action_never_gives_dig_precision_without_pinpointer() -> void:
	var det: ReadoutDetector = ReadoutDetector.new()
	autofree(det)
	var radar: Control = _radar(det)
	assert_true(radar.has_method("get_primary_action"), "Visor deve comunicar a próxima ação pelo estado real")
	if not radar.has_method("get_primary_action"):
		return
	assert_eq(radar.call("get_primary_action"), "PROCURAR")
	var spot: BuriedSpot = BuriedSpot.new()
	autofree(spot)
	det.test_target = spot
	det.test_distance = 0.3
	assert_eq(radar.call("get_primary_action"), "APROXIMAR", "Distância próxima sem upgrade não revela precisão")
	det.test_pin = true
	assert_ne(radar.call("get_primary_action"), "CAVAR", "Estado inconsistente não concede upgrade")
	det.test_pin_level = 1
	det.test_distance = MetalDetector.PINPOINT_DIG_DISTANCE + 0.01
	assert_eq(radar.call("get_primary_action"), "APROXIMAR")
	det.test_distance = MetalDetector.PINPOINT_DIG_DISTANCE
	assert_eq(radar.call("get_primary_action"), "CAVAR", "Mesma fronteira do PIN CAVE")
	det.test_pin = false
	assert_ne(radar.call("get_primary_action"), "CAVAR")
	det.test_target = null
	det.test_pin = true
	assert_eq(radar.call("get_primary_action"), "PROCURAR", "Pinpointer sem alvo não promete escavar")


func test_no_target_keeps_custom_a11y_footer_but_removes_unavailable_rows() -> void:
	var det: ReadoutDetector = ReadoutDetector.new()
	autofree(det)
	var radar: Control = _radar(det)
	assert_true(radar.has_method("get_secondary_lines"), "Rodapé compacto sem linhas indisponíveis")
	if not radar.has_method("get_secondary_lines"):
		return
	det.test_footer = PackedStringArray(["Nv.1 8m", "Sinal ░░░", "Mat: ---", "Prof: ---", "Val: ---", ""])
	assert_eq(radar.call("get_secondary_lines"), PackedStringArray(["Nv.1 8m", "Sinal ░░░"]))
	det.test_footer = PackedStringArray(["A11y custom", "Ouro e prata", "PIN custom", "Interferência custom"])
	assert_eq(radar.call("get_secondary_lines"), det.test_footer, "Stub a11y sem alvo mantém seus dados")
	det.test_footer = PackedStringArray()
	assert_eq(radar.call("get_primary_action"), "PROCURAR")
	assert_eq(radar.call("get_secondary_lines"), PackedStringArray())


func test_upgrade_readouts_pass_through_without_revealing_new_data() -> void:
	var det: ReadoutDetector = ReadoutDetector.new()
	autofree(det)
	var radar: Control = _radar(det)
	assert_true(radar.has_method("get_secondary_lines"))
	if not radar.has_method("get_secondary_lines"):
		return
	for footer: PackedStringArray in [PackedStringArray(["Nv.1 8m", "Sinal ▒░░"]), PackedStringArray(["Nv.3 13m", "Sinal ▓▓░", "Mat: Ouro", "Prof: 20–30 cm"]), PackedStringArray(["Nv.7 23m ⚠2 ★30m", "PIN ↑ 1.8m", "Novo: Ídolo", "Prof: 30 cm", "Val: R$100–300 ★x3"])]:
		det.test_footer = footer
		assert_eq(radar.call("get_secondary_lines"), footer, "Capacidades/valores do provedor preservados integralmente")
		assert_eq(det.get_footer_lines(), footer, "Apresentação não reescreve o contrato MetalDetector")


func test_item_enemy_and_interference_have_distinct_shape_semantics() -> void:
	var det: ReadoutDetector = ReadoutDetector.new()
	autofree(det)
	var radar: Control = _radar(det)
	assert_true(radar.has_method("get_blip_shape"), "Identificação não deve depender apenas da cor")
	if not radar.has_method("get_blip_shape"):
		return
	var item: MetalDetector.RadarBlip = MetalDetector.RadarBlip.new()
	var enemy: MetalDetector.RadarBlip = MetalDetector.RadarBlip.new()
	enemy.is_enemy = true
	var noise: MetalDetector.RadarBlip = MetalDetector.RadarBlip.new()
	noise.is_noise = true
	assert_ne(radar.call("get_blip_shape", item), radar.call("get_blip_shape", enemy))
	assert_ne(radar.call("get_blip_shape", noise), radar.call("get_blip_shape", item))
	assert_ne(radar.call("get_blip_shape", noise), radar.call("get_blip_shape", enemy))


func test_acquiring_target_does_not_move_or_resize_radar() -> void:
	var det: ReadoutDetector = ReadoutDetector.new()
	autofree(det)
	var radar: Control = _radar(det)
	assert_true(radar.has_method("get_radar_bounds"))
	if not radar.has_method("get_radar_bounds"):
		return
	for level: int in [1, 3, 7]:
		det.test_level = level
		det.test_footer = PackedStringArray(["Nv", "Sinal", "Mat: ---", "Prof: ---", "Val: ---"])
		var empty: Rect2 = radar.call("get_radar_bounds", Vector2(160, 230))
		det.test_footer = PackedStringArray(["Nv", "Sinal", "Mat: Ouro", "Prof: 20 cm", "Val: R$300"])
		assert_eq(radar.call("get_radar_bounds", Vector2(160, 230)), empty, "Escala espacial não salta ao revelar dados")


func test_long_readout_is_bounded_and_short_text_remains_intact() -> void:
	var det: ReadoutDetector = ReadoutDetector.new()
	autofree(det)
	var radar: Control = _radar(det)
	assert_true(radar.has_method("fit_readout_line"))
	if not radar.has_method("fit_readout_line"):
		return
	var font: Font = ThemeDB.fallback_font
	var text: String = "New: An extraordinarily lengthy archaeological discovery from the glacier"
	var fitted: String = radar.call("fit_readout_line", font, text, 156.0, 9)
	assert_true(fitted.ends_with("…"))
	assert_lte(font.get_string_size(fitted, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x, 156.0)
	assert_eq(radar.call("fit_readout_line", font, "Gold", 156.0, 12), "Gold")
