# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/theme_test.gd
# Theme ScanDig (#51): cenas com o theme, sem overrides de cor/fonte, contraste da paleta e layout a 960x540.
extends SceneTree

const THEME_PATH: String = "res://ui/theme/scandig_theme.tres"
const SCENES: Array[String] = ["res://ui/hud.tscn", "res://ui/multiplayer_menu.tscn", "res://ui/base_station_ui.tscn", "res://ui/session_ui.tscn"]

var _fails: int = 0
var _theme: Theme = null


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_theme = load(THEME_PATH) as Theme
	_check(_theme != null, "theme carregado")
	_check_overrides()
	_check_contrast()
	root.size = Vector2i(960, 540)
	change_scene_to_file("res://world/lobby_base.tscn")
	# Save isolado: nada deste teste toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("theme_test")
	await _wait(10)
	var base: BaseStationUI = current_scene.get_node_or_null("UILayer/BaseStationUI") as BaseStationUI
	var menu: MultiplayerMenu = current_scene.get_node_or_null("UILayer/MultiplayerMenu") as MultiplayerMenu
	var hud: Node = current_scene.find_child("HUD", true, false)
	var ui: SessionUI = SessionUI.instance
	_check(base != null and menu != null and hud != null and ui != null, "Base, menu, HUD e SessionUI presentes")
	if base == null or menu == null or hud == null or ui == null or _theme == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	_check_scenes(base, menu, hud, ui)
	await _check_layout(base, menu, hud)
	print("RESULT fails=%d" % _fails)
	quit(_fails)


# --- 1. As cenas usam o theme --------------------------------------------------------------

func _same_box(c: Control, item: String, type: String) -> bool:
	return c.get_theme_stylebox(item) == _theme.get_stylebox(item, type)


func _same_color(c: Control, item: String, type: String) -> bool:
	return c.get_theme_color(item) == _theme.get_color(item, type)


func _check_scenes(base: BaseStationUI, menu: MultiplayerMenu, hud: Node, ui: SessionUI) -> void:
	var hud_panel: PanelContainer = hud.get_node("MarginContainer/PanelContainer") as PanelContainer
	var hud_label: Label = hud.get_node("%MoneyLabel") as Label
	_check(_same_box(hud_panel, "panel", "WornPanel"), "HUD: painel WornPanel do theme")
	_check(_same_color(hud_label, "font_color", "Label"), "HUD: cor do Label do theme")

	var menu_panel: PanelContainer = menu.get_node("PanelContainer") as PanelContainer
	_check(_same_box(menu_panel, "panel", "WornPanel"), "menu: painel WornPanel do theme")
	_check(_same_box(menu.copy_code_button, "normal", "Button"), "menu: Button normal do theme")
	_check(_same_box(menu.host_online_button, "normal", "PrimaryButton"), "menu: PrimaryButton do theme")
	_check(_same_box(menu.new_game_button, "normal", "DangerButton"), "menu: DangerButton do theme")
	_check(_same_color(menu.status_label, "font_color", "Label"), "menu: cor do Label do theme")
	_check(_same_color(menu.progress_warning_label, "font_color", "WarningLabel") and menu.progress_warning_label.get_theme_color("font_color").is_equal_approx(UiPalette.RED_BURNT), "menu: WarningLabel em RED_BURNT")
	_check(_same_color(menu.room_code_label, "font_color", "CodeLabel") and menu.room_code_label.get_theme_color("font_color").is_equal_approx(UiPalette.GOLD), "menu: CodeLabel em GOLD")
	_check(_same_box(menu.code_line_edit, "normal", "LineEdit"), "menu: LineEdit do theme")
	_check(_same_box(menu.mode_tabs, "panel", "TabContainer"), "menu: TabContainer do theme")
	# O ConfirmationDialog (Window) herda o theme da raiz do menu.
	var dialog: ConfirmationDialog = menu.new_game_dialog
	_check(dialog.get_theme_stylebox("panel") == _theme.get_stylebox("panel", "AcceptDialog"), "diálogo: painel do theme")
	_check(dialog.get_theme_stylebox("embedded_border") == _theme.get_stylebox("embedded_border", "Window"), "diálogo: borda da janela do theme")
	_check(_same_box(dialog.get_ok_button(), "normal", "DangerButton"), "diálogo: OK como DangerButton")
	_check(_same_box(dialog.get_cancel_button(), "normal", "Button"), "diálogo: Cancelar como Button")

	var base_panel: PanelContainer = base.get_node("PanelContainer") as PanelContainer
	_check(_same_box(base_panel, "panel", "WornPanel"), "Base: painel WornPanel do theme")
	_check(_same_box(base.buy_detector_btn, "normal", "Button"), "Base: Button do theme")
	_check(_same_color(base.secrets_label, "font_color", "Label"), "Base: cor do Label do theme")
	_check(_same_box(base.map_list, "panel", "ItemList") and _same_box(base.map_list, "selected", "ItemList"), "Base: ItemList do theme")
	_check(_same_box(base.item_select_box, "normal", "OptionButton"), "Base: OptionButton do theme")
	_check(BaseStationUI.MAP_LOCKED_COLOR.is_equal_approx(UiPalette.METAL), "Base: mapa bloqueado em METAL")

	_check(_same_box(ui.expedition_bar as PanelContainer, "panel", "PanelContainer"), "SessionUI: ExpeditionBar do theme")
	_check(_same_box(ui.return_button, "normal", "Button"), "SessionUI: Button do theme")
	_check(_same_box(ui.leave_button, "normal", "DangerButton"), "SessionUI: sair como DangerButton")
	_check(_same_box(ui.toast_panel, "panel", "ToastPanel"), "SessionUI: aviso com ToastPanel")
	_check(_same_color(ui.toast_label, "font_color", "ToastLabel"), "SessionUI: texto do aviso do theme")
	_check(_same_box(ui.summary_panel, "panel", "WornPanel"), "SessionUI: resumo WornPanel")
	_check(_same_color(ui.summary_total_label, "font_color", "Label"), "SessionUI: cor do Label do theme")
	_check((ui.loading_screen as ColorRect).color.is_equal_approx(UiPalette.WOOD_DARK), "SessionUI: carregamento em WOOD_DARK")
	_check(ui.loading_label.get_theme_color("font_color").is_equal_approx(UiPalette.PAPER), "SessionUI: texto do carregamento em PAPER")
	_check(_same_box(ui.leave_confirm_button, "normal", "DangerButton"), "SessionUI: confirmar saída como DangerButton")


# --- 2. Nenhum override de cor ou tamanho de fonte -----------------------------------------

func _check_overrides() -> void:
	for path: String in SCENES:
		var text: String = FileAccess.get_file_as_string(path)
		_check(not text.is_empty(), "%s lido" % path)
		var found: int = text.count("theme_override_colors") + text.count("theme_override_font_sizes")
		_check(found == 0, "%s: %d overrides de cor/fonte" % [path, found])
		_check(text.contains("res://ui/theme/scandig_theme.tres"), "%s: usa o theme" % path)


# --- 3. Contraste WCAG ----------------------------------------------------------------------

static func _channel(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func luminance(c: Color) -> float:
	return 0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b)


static func contrast(a: Color, b: Color) -> float:
	var la: float = luminance(a)
	var lb: float = luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _check_contrast() -> void:
	# [texto, fundo, onde]
	var pairs: Array = [
		[UiPalette.INK, UiPalette.PAPER, "texto em painel"],
		[UiPalette.INK, UiPalette.PAPER_LIGHT, "botão/campo/lista"],
		[UiPalette.INK, UiPalette.PAPER_DARK, "aba de trás / botão pressionado"],
		[UiPalette.INK, UiPalette.PAPER_LIGHT.lerp(UiPalette.ORANGE, 0.18), "botão hover"],
		[UiPalette.INK, UiPalette.ORANGE, "PrimaryButton / seleção da lista"],
		[UiPalette.INK, UiPalette.ORANGE.lerp(UiPalette.GOLD, 0.25), "PrimaryButton hover"],
		
		[UiPalette.PAPER, UiPalette.RED_BURNT, "DangerButton"],
		[UiPalette.PAPER, UiPalette.RED_BURNT.darkened(0.15), "DangerButton pressionado"],
		[UiPalette.PAPER, UiPalette.METAL, "botão desativado"],
		[UiPalette.RED_BURNT, UiPalette.PAPER, "WarningLabel"],
		[UiPalette.WOOD, UiPalette.PAPER, "HintLabel"],
		[UiPalette.WOOD, UiPalette.PAPER_LIGHT, "placeholder do LineEdit"],
		[UiPalette.METAL, UiPalette.PAPER_LIGHT, "mapa bloqueado na lista"],
		[UiPalette.GOLD, UiPalette.INK, "CodeLabel"],
		[UiPalette.PAPER, UiPalette.GREEN_BOTTLE, "aviso (ToastPanel)"],
		[UiPalette.PAPER, UiPalette.WOOD_DARK, "carregamento / título da janela"],
	]
	for pair: Array in pairs:
		var ratio: float = contrast(pair[0] as Color, pair[1] as Color)
		_check(ratio >= 4.5, "contraste %s: %.2f" % [pair[2], ratio])


# --- 4. Layout a 960x540 --------------------------------------------------------------------

func _inside_screen(r: Rect2, screen: Rect2) -> bool:
	return screen.encloses(r)


func _buttons_fit(node: Node, where: String) -> void:
	var cut: Array[String] = []
	for b: Node in node.find_children("*", "Button", true, false):
		var button: Button = b as Button
		if not button.is_visible_in_tree() or button is OptionButton or button.text.is_empty():
			continue
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var box: StyleBox = button.get_theme_stylebox("normal")
		var width: float = 0.0
		for line: String in button.text.split("\n"):
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		if width + box.get_minimum_size().x > button.size.x + 0.5:
			cut.append("%s (%.0f > %.0f)" % [button.name, width + box.get_minimum_size().x, button.size.x])
	_check(cut.is_empty(), "%s: textos de botão inteiros %s" % [where, cut])


func _check_layout(base: BaseStationUI, menu: MultiplayerMenu, hud: Node) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size))
	_check(root.size == Vector2i(960, 540), "janela 960x540: %s" % root.size)
	var tabs: TabContainer = base.get_node("%TabContainer") as TabContainer
	var base_panel: Control = base.get_node("PanelContainer") as Control
	var menu_panel: Control = menu.get_node("PanelContainer") as Control
	var hud_panel: Control = hud.get_node("MarginContainer/PanelContainer") as Control
	for i in range(tabs.get_tab_count()):
		tabs.current_tab = i
		await _wait(3)
		var r: Rect2 = base_panel.get_global_rect()
		var min_h: float = base_panel.get_combined_minimum_size().y
		var limit: float = 390.0 if i == 0 else r.size.y
		_check(is_equal_approx(r.position.x, 16) and is_equal_approx(r.end.x, 592) and min_h <= limit and _inside_screen(r, screen),
			"Base aba %s: %s, altura mínima %.0f (<= %.0f)" % [tabs.get_tab_title(i), r, min_h, limit])
		_buttons_fit(base_panel, "Base aba %s" % tabs.get_tab_title(i))
	tabs.current_tab = 0
	await _wait(2)

	# Menu no pior caso: progresso com aviso + código da sala.
	menu._progress_message = "Save de uma versão mais nova do jogo (v9)."
	menu.progress_box.visible = true
	menu.progress_warning_label.text = menu._progress_message
	menu.progress_warning_label.visible = true
	NetworkManager.instance.room_code_ready.emit("K7Q3MX")
	for tab in range(2):
		menu.mode_tabs.current_tab = tab
		await _wait(3)
		var m: Rect2 = menu_panel.get_global_rect()
		_check(is_equal_approx(m.position.x, 620) and is_equal_approx(m.end.x, 944) and _inside_screen(m, screen), "menu aba %d: %s" % [tab, m])
		_check(not m.intersects(base_panel.get_global_rect()), "menu não sobrepõe a Base")
		_buttons_fit(menu_panel, "menu aba %d" % tab)
	menu._hide_room_code()
	menu._progress_message = ""
	menu.progress_warning_label.visible = false
	menu.mode_tabs.current_tab = 0

	var h: Rect2 = hud_panel.get_global_rect()
	_check(_inside_screen(h, screen) and h.end.y <= base_panel.get_global_rect().position.y and not h.intersects(menu_panel.get_global_rect()),
		"HUD %s acima da Base e longe do menu" % h)
