# Teste headless (quando reserva de engine for concedida):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/player_hud_style_test.gd
extends SceneTree

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _build_mock_hud() -> CanvasLayer:
	var hud: CanvasLayer = CanvasLayer.new()
	hud.name = "HUD"

	var top_chips: HBoxContainer = HBoxContainer.new()
	top_chips.name = "TopChips"
	var bag_chip: UiChip = UiChip.new()
	bag_chip.name = "BagChip"
	bag_chip.icon_name = "backpack"
	top_chips.add_child(bag_chip)
	var money_chip: UiChip = UiChip.new()
	money_chip.name = "MoneyChip"
	money_chip.icon_name = "coin"
	top_chips.add_child(money_chip)
	hud.add_child(top_chips)

	var threat_panel: VBoxContainer = VBoxContainer.new()
	threat_panel.name = "ThreatPanel"
	threat_panel.visible = false
	var threat_title: Label = Label.new()
	threat_title.name = "ThreatTitle"
	threat_title.text = "Ameaça do Subsolo"
	threat_panel.add_child(threat_title)
	var threat_bar: ProgressBar = ProgressBar.new()
	threat_bar.name = "ThreatBar"
	threat_bar.min_value = 0.0
	threat_bar.max_value = 100.0
	threat_bar.value = 0.0
	var threat_fill: StyleBoxFlat = StyleBoxFlat.new()
	threat_fill.bg_color = UiPalette.ORANGE
	threat_bar.add_theme_stylebox_override(&"fill", threat_fill)
	threat_panel.add_child(threat_bar)
	hud.add_child(threat_panel)

	var health_panel: VBoxContainer = VBoxContainer.new()
	health_panel.name = "HealthPanel"
	var health_label: Label = Label.new()
	health_label.name = "HealthLabel"
	health_label.text = "Vida  100/100"
	health_panel.add_child(health_label)
	var health_bar: ProgressBar = ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 80.0
	var hp_fill: StyleBoxFlat = StyleBoxFlat.new()
	hp_fill.bg_color = UiPalette.RED_BURNT
	health_bar.add_theme_stylebox_override(&"fill", hp_fill)
	health_panel.add_child(health_bar)

	var hunger_label: Label = Label.new()
	hunger_label.name = "HungerLabel"
	hunger_label.text = "Fome   75/100"
	health_panel.add_child(hunger_label)
	var hunger_bar: ProgressBar = ProgressBar.new()
	hunger_bar.name = "HungerBar"
	hunger_bar.min_value = 0.0
	hunger_bar.max_value = 100.0
	hunger_bar.value = 75.0
	var food_fill: StyleBoxFlat = StyleBoxFlat.new()
	food_fill.bg_color = UiPalette.ORANGE
	hunger_bar.add_theme_stylebox_override(&"fill", food_fill)
	health_panel.add_child(hunger_bar)
	hud.add_child(health_panel)

	A11y.tint_bar(health_bar, &"bar_health")
	A11y.tint_bar(hunger_bar, &"bar_hunger")
	return hud


func _run() -> void:
	SaveManager.instance.use_test_save_dir("player_hud_style_test")
	var hud: CanvasLayer = _build_mock_hud()
	root.add_child(hud)
	await process_frame

	PlayerHudStyle.apply(hud)
	PlayerHudStyle.apply(hud)  # Idempotência

	var top_chips: HBoxContainer = hud.get_node(^"TopChips") as HBoxContainer
	var money_label: Label = hud.get_node(^"TopChips/MoneyChip/Box/Label") as Label
	var health_panel: VBoxContainer = hud.get_node(^"HealthPanel") as VBoxContainer
	var health_bar: ProgressBar = hud.get_node(^"HealthPanel/HealthBar") as ProgressBar
	var hunger_label: Label = hud.get_node(^"HealthPanel/HungerLabel") as Label
	var hunger_bar: ProgressBar = hud.get_node(^"HealthPanel/HungerBar") as ProgressBar
	var threat_panel: VBoxContainer = hud.get_node(^"ThreatPanel") as VBoxContainer
	var threat_bar: ProgressBar = hud.get_node(^"ThreatPanel/ThreatBar") as ProgressBar
	var arcs: PlayerHudStyle.VitalsArcs = hud.get_node_or_null(^"HealthPanel/VitalsArcs") as PlayerHudStyle.VitalsArcs
	var threat_sync: PlayerHudStyle.ThreatContextSync = hud.get_node_or_null(^"ThreatPanel/ThreatContextSync") as PlayerHudStyle.ThreatContextSync

	_check(arcs != null, "VitalsArcs criado em HealthPanel")
	_check(threat_sync != null, "ThreatContextSync criado em ThreatPanel")
	_check(health_panel.get_child_count() == 5, "apply idempotente sem duplicar filhos em HealthPanel")
	_check(is_equal_approx(arcs.health_ratio(), 0.8) and is_equal_approx(arcs.hunger_ratio(), 0.75), "VitalsArcs inicializa com valores atuais")

	# (1) e (3) Margem segura responsiva de 5% e TopChips no canto inferior esquerdo acima de HealthPanel:
	_check(is_equal_approx(health_panel.anchor_left, 0.05) and is_equal_approx(health_panel.anchor_bottom, 0.95), "HealthPanel na margem segura 5% inferior esquerda")
	_check(is_equal_approx(top_chips.anchor_left, 0.05) and is_equal_approx(top_chips.anchor_bottom, 0.95), "TopChips na margem segura 5% inferior esquerda")
	_check(top_chips.offset_bottom < health_panel.offset_top, "TopChips posicionado acima de HealthPanel no canto inferior esquerdo (%.1f < %.1f)" % [top_chips.offset_bottom, health_panel.offset_top])
	_check(is_equal_approx(threat_panel.anchor_right, 0.95) and is_equal_approx(threat_panel.anchor_top, 0.05), "ThreatPanel na margem segura 5% superior direita")

	# (2) Escala de texto do HUD (SettingsManager.apply_hud_text_scale e _settings_base_font_size):
	var hp_lbl: Label = arcs.hp_value_label()
	var food_lbl: Label = arcs.food_value_label()
	var base_hp_font: int = hp_lbl.get_theme_font_size(&"font_size")
	var base_min_h: float = arcs.custom_minimum_size.y
	SettingsManager.apply_hud_text_scale(hud, 1.5)
	arcs._sync(false)
	_check(hp_lbl.has_meta(&"_settings_base_font_size") and int(hp_lbl.get_meta(&"_settings_base_font_size")) == PlayerHudStyle.DIAL_BASE_FONT_SIZE, "HpValueLabel registra meta _settings_base_font_size")
	_check(hp_lbl.get_theme_font_size(&"font_size") == roundi(float(base_hp_font) * 1.5) and food_lbl.get_theme_font_size(&"font_size") == roundi(float(base_hp_font) * 1.5), "hud_text_scale 1.5x escala numeros visiveis de vida e fome")
	_check(arcs.custom_minimum_size.y > base_min_h and top_chips.offset_bottom < health_panel.offset_top, "VitalsArcs expande layout e mantem TopChips acima em 1.5x")
	# Reaplicar apply() com escala 1.5x ativa não deve sobrescrever a escala capturada em _settings_base_font_size:
	PlayerHudStyle.apply(hud)
	_check(money_label.get_theme_font_size(&"font_size") == roundi(float(PlayerHudStyle.CHIP_FONT_SIZE) * 1.5), "apply() preserva escala ativa de _settings_base_font_size")
	SettingsManager.apply_hud_text_scale(hud, 1.0)
	arcs._sync(false)
	_check(hp_lbl.get_theme_font_size(&"font_size") == base_hp_font, "hud_text_scale 1.0x restaura tamanho base")

	# Mudança de max_value/min_value além de value_changed:
	health_bar.max_value = 160.0
	health_bar.value = 40.0
	_check(is_equal_approx(arcs.health_ratio(), 0.25) and hp_lbl.text == "!40/160", "VitalsArcs acompanha max_value, value e prefixo de baixo valor: %s" % hp_lbl.text)

	# Alertas de fome baixa e peso/sobrecarga vindos de HungerLabel:
	hunger_bar.value = 20.0
	hunger_label.text = "Fome   20/100  (com fome!)   🎒 pesado"
	arcs._sync(false)
	_check(arcs.status_text().contains("(com fome!)") and arcs.status_text().contains("🎒 pesado"), "preserva feedback de fome baixa e sobrecarga: %s" % arcs.status_text())

	# Preserva ThreatPanel oculto sem DisturbanceMeter, e contextual quando autorizado:
	_check(not threat_panel.visible, "ThreatPanel oculto sem DisturbanceMeter")
	threat_panel.set_meta(&"allow_contextual_threat_without_meter", true)
	threat_bar.value = 55.0
	A11y.tint_bar(threat_bar, A11y.threat_role(3))
	await process_frame
	_check(threat_panel.visible, "ThreatPanel visível quando ruído > 0")
	_check(threat_sync.current_fill_color().is_equal_approx(A11y.color(&"threat_3")), "ThreatContextSync lê cor atualizada após A11y.tint_bar")
	threat_bar.value = 0.0
	_check(not threat_panel.visible, "ThreatPanel volta a ocultar quando ruído zera")

	# SessionUI ExpeditionBar compacta no canto inferior direito com margem segura 5%:
	var ui: SessionUI = SessionUI.instance
	if ui != null:
		_check(ui.expedition_info_label.get_theme_font_size(&"font_size") == PlayerHudStyle.EXPEDITION_FONT_SIZE, "ExpeditionBar com fonte compacta")
		_check(is_equal_approx(ui.expedition_bar.anchor_right, 0.95) and is_equal_approx(ui.expedition_bar.anchor_bottom, 0.95), "ExpeditionBar na margem segura 5% no canto inferior direito")

	hud.queue_free()
	await process_frame
	print("RESULT fails=%d" % _fails)
	quit(_fails)
