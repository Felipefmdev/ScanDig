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
	_check_fonts()
	_check_progress_bars()
	root.size = LOGICAL_SIZES[0]
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
	_check(menu.code_line_edit.get_theme_font("font") == _theme.get_font("font", "CodeLineEdit"), "menu: campo do código com a fonte do código")
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


# --- Fonte (Patrick Hand; código da sala em Kalam Bold) ----------------------------------

## Todos os caracteres não ASCII que a UI mostra, mais dígitos e o alfabeto do código da sala.
const UI_GLYPHS: String = "ãçéêíóôõúáàâÃÇÉÊÍÓÔÕÚÁÀÂ•—→★✔🔒 R$ 0123456789 23456789ABCDEFGHJKLMNPQRSTUVWXYZ-"


func _base_path(font: Font) -> String:
	var variation: FontVariation = font as FontVariation
	return variation.base_font.resource_path if variation != null and variation.base_font != null else font.resource_path


func _missing_glyphs(font: Font) -> String:
	var missing: String = ""
	for i in range(UI_GLYPHS.length()):
		var c: int = UI_GLYPHS.unicode_at(i)
		if c == 32 or font.has_char(c):
			continue
		var found: bool = false
		for fallback: Font in font.fallbacks:
			if fallback.has_char(c):
				found = true
				break
		if not found:
			missing += String.chr(c)
	return missing


func _check_fonts() -> void:
	var main: Font = _theme.default_font
	_check(main != null and _base_path(main).ends_with("PatrickHand-Regular.ttf"), "fonte principal Patrick Hand: %s" % (_base_path(main) if main != null else "nenhuma"))
	var code: Font = _theme.get_font("font", "CodeLabel")
	_check(_base_path(code).ends_with("Kalam-Bold.ttf") and _theme.get_font("font", "CodeLineEdit") == code, "código da sala em Kalam Bold")
	if main != null:
		_check(_missing_glyphs(main) == "", "glifos da UI na fonte principal ou no fallback (faltando: '%s')" % _missing_glyphs(main))
	_check(_missing_glyphs(code) == "", "glifos na fonte do código ou no fallback (faltando: '%s')" % _missing_glyphs(code))


func _check_progress_bars() -> void:
	_check(_theme.has_stylebox("background", "ProgressBar") and _theme.has_stylebox("fill", "ProgressBar"), "ProgressBar tem background e fill")
	var pb_bg: StyleBoxFlat = _theme.get_stylebox("background", "ProgressBar") as StyleBoxFlat
	var pb_fill: StyleBoxFlat = _theme.get_stylebox("fill", "ProgressBar") as StyleBoxFlat
	_check(pb_bg != null and pb_bg.bg_color.is_equal_approx(UiPalette.PAPER_DARK), "ProgressBar background em PAPER_DARK")
	_check(pb_fill != null and pb_fill.bg_color.is_equal_approx(UiPalette.RED_BURNT), "ProgressBar fill em RED_BURNT")
	_check(_theme.get_color("font_color", "ProgressBar").is_equal_approx(UiPalette.PAPER), "ProgressBar font_color em PAPER")
	_check(_theme.get_color("font_outline_color", "ProgressBar").is_equal_approx(UiPalette.INK), "ProgressBar font_outline_color em INK")
	_check(_theme.get_constant("outline_size", "ProgressBar") == 3, "ProgressBar outline_size == 3")

	var threat_fill: StyleBoxFlat = _theme.get_stylebox("fill", "ThreatBar") as StyleBoxFlat
	_check(_theme.get_type_variation_base("ThreatBar") == &"ProgressBar" and threat_fill != null and threat_fill.bg_color.is_equal_approx(UiPalette.ORANGE), "ThreatBar herda de ProgressBar com fill em ORANGE")

	var boss_bg: StyleBoxFlat = _theme.get_stylebox("background", "BossBar") as StyleBoxFlat
	var boss_fill: StyleBoxFlat = _theme.get_stylebox("fill", "BossBar") as StyleBoxFlat
	_check(_theme.get_type_variation_base("BossBar") == &"ProgressBar", "BossBar herda de ProgressBar")
	_check(boss_fill != null and boss_fill.bg_color.is_equal_approx(UiPalette.RED_BURNT) and boss_fill.border_width_top == 3, "BossBar fill em RED_BURNT com borda 3")
	_check(boss_bg != null and boss_bg.bg_color.is_equal_approx(UiPalette.PAPER_DARK) and boss_bg.shadow_size > 0, "BossBar background em PAPER_DARK com sombra")



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
	# Controles desativados: isentos pelo WCAG 1.4.3, mas legíveis (>= 3:1).
	var disabled_pairs: Array = [
		[UiPalette.WOOD, UiPalette.PAPER_DARK, "disabled: botão e aba desativados"],
	]
	for pair: Array in disabled_pairs:
		var ratio: float = contrast(pair[0] as Color, pair[1] as Color)
		_check(ratio >= 3.0, "contraste %s: %.2f (>= 3)" % [pair[2], ratio])
	for type: String in ["Button", "PrimaryButton", "DangerButton"]:
		var box: StyleBoxFlat = _theme.get_stylebox("disabled", type) as StyleBoxFlat
		_check(box != null and box.bg_color.is_equal_approx(UiPalette.PAPER_DARK) and box.border_color.is_equal_approx(UiPalette.METAL)
			and _theme.get_color("font_disabled_color", type).is_equal_approx(UiPalette.WOOD), "%s desativado em papel (PAPER_DARK, contorno METAL, texto WOOD)" % type)


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


## Tamanhos lógicos com o stretch canvas_items/expand (base 1152x648): o pior caso de altura,
## 21:9 e 4:3. Telas menores só encolhem a UI inteira.
const LOGICAL_SIZES: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1536, 648), Vector2i(1152, 864)]


func _check_layout(base: BaseStationUI, menu: MultiplayerMenu, hud: Node) -> void:
	var tabs: TabContainer = base.get_node("%TabContainer") as TabContainer
	var base_panel: Control = base.get_node("PanelContainer") as Control
	var menu_panel: Control = menu.get_node("PanelContainer") as Control
	var hud_panel: Control = hud.get_node("MarginContainer/PanelContainer") as Control
	_check(tabs.use_hidden_tabs_for_min_size, "abas da Base com altura da maior aba")
	for logical: Vector2i in LOGICAL_SIZES:
		root.size = logical
		await _wait(10)
		var screen: Rect2 = Rect2(Vector2.ZERO, root.get_visible_rect().size)
		var where: String = "%dx%d" % [logical.x, logical.y]
		_check(screen.size.is_equal_approx(Vector2(logical)), "%s: área lógica %s" % [where, screen.size])
		var heights: Array[float] = []
		for i in range(tabs.get_tab_count()):
			tabs.current_tab = i
			await _wait(5)
			var r: Rect2 = base_panel.get_global_rect()
			heights.append(r.size.y)
			_check(is_equal_approx(r.position.x, 16) and is_equal_approx(r.end.x, 592) and screen.encloses(r),
				"%s Base aba %s: %s dentro da tela" % [where, tabs.get_tab_title(i), r])
			_check(r.size.y <= base_panel.get_combined_minimum_size().y + 0.5, "%s Base aba %s: altura do conteúdo (%.0f), sem esticar" % [where, tabs.get_tab_title(i), r.size.y])
			_buttons_fit(base_panel, "%s Base aba %s" % [where, tabs.get_tab_title(i)])
		_check(heights.max() - heights.min() < 0.5, "%s: Base não muda de altura entre abas %s" % [where, heights])
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
			_check(is_equal_approx(m.end.x, screen.size.x - 16) and screen.encloses(m), "%s menu aba %d: %s" % [where, tab, m])
			_check(not m.intersects(base_panel.get_global_rect()) and not m.intersects(hud_panel.get_global_rect()), "%s: menu não sobrepõe a Base nem o HUD" % where)
			_buttons_fit(menu_panel, "%s menu aba %d" % [where, tab])
		menu._hide_room_code()
		menu._progress_message = ""
		menu.progress_warning_label.visible = false
		menu.mode_tabs.current_tab = 0

		var h: Rect2 = hud_panel.get_global_rect()
		_check(screen.encloses(h) and h.end.y <= base_panel.get_global_rect().position.y,
			"%s: HUD %s acima da Base (y %.0f)" % [where, h, base_panel.get_global_rect().position.y])
