# Gera ui/theme/scandig_theme.tres a partir de UiPalette (rodar de novo depois de mudar a paleta):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/theme/build_theme.gd
# Precisa de ui/theme/paper_worn.png e das fontes já importados (--editor --quit-after).
# Fonte: Patrick Hand (código da sala em Kalam Bold); "-- --font=none" gera com a fonte padrão.
# Comparação feita na #51: Kalam em tudo e Kalam só em títulos/botões estouravam a Loja (> 390 px).
extends SceneTree

const OUT_PATH: String = "res://ui/theme/scandig_theme.tres"
const WORN_TEXTURE: String = "res://ui/theme/paper_worn.png"
## Margem do 9-patch da textura (igual a gen_paper_worn.gd TEX_MARGIN).
const TEX_MARGIN: int = 14
const FONT_SIZE: int = 18
const FONT_VARIANT: String = "patrick_hand"
## Engrossar o traço do Patrick Hand (FontVariation.variation_embolden).
const BODY_EMBOLDEN: float = 0.35
const TITLE_EMBOLDEN: float = 0.8
const FONT_DIR: String = "res://ui/theme/fonts/"
const ICON_DIR: String = "res://ui/theme/icons/"
## Fallback dos glifos que as fontes não têm (→ ★ ✔ 🔒): fontes de símbolos/emoji do sistema.
const SYMBOL_FONTS: PackedStringArray = ["Segoe UI Symbol", "Noto Sans Symbols 2", "Noto Sans Symbols", "DejaVu Sans"]
const EMOJI_FONTS: PackedStringArray = ["Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji"]
const P = preload("res://ui/theme/ui_palette.gd")

var _theme: Theme = Theme.new()
var _font_variant: String = FONT_VARIANT
var _needs_import: Array[String] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--font="):
			_font_variant = arg.trim_prefix("--font=")
	_theme.default_font_size = FONT_SIZE
	_labels()
	_panels()
	_buttons()
	_inputs()
	_tabs()
	_lists()
	_popups()
	_scroll_and_separators()
	_progress_bars()
	_windows()
	_fonts()
	if not _needs_import.is_empty():
		printerr("Ícones novos/alterados %s: rode --editor --quit-after e o build de novo." % [_needs_import])
		quit(ERR_FILE_UNRECOGNIZED)
		return
	# Preserva o UID do .tres (e dos ext_resource) para o editor não reescrever a cada build.
	var uid: int = ResourceLoader.get_resource_uid(OUT_PATH)
	var err: Error = ResourceSaver.save(_theme, OUT_PATH)
	if err == OK:
		err = _stabilize_file(uid)
	print("theme: %s fonte %s (%d)" % [OUT_PATH, _font_variant, err])
	quit(err)


## Cabeçalho com o UID antigo, UID nos ext_resource e ids de sub_resource sequenciais
## (o build fica reprodutível: mesmo theme -> mesmo arquivo).
func _stabilize_file(uid: int) -> Error:
	var text: String = FileAccess.get_file_as_string(OUT_PATH)
	if text.is_empty():
		return ERR_FILE_CANT_READ
	var lines: PackedStringArray = text.split("\n")
	var ext_re: RegEx = RegEx.create_from_string('^\\[ext_resource type="([^"]+)" path="([^"]+)" id="([^"]+)"\\]$')
	for i in range(lines.size()):
		var line: String = lines[i]
		if i == 0 and uid != ResourceUID.INVALID_ID and not line.contains(" uid="):
			lines[i] = line.trim_suffix("]") + ' uid="%s"]' % ResourceUID.id_to_text(uid)
			continue
		var m: RegExMatch = ext_re.search(line)
		if m != null:
			var ext_uid: int = ResourceLoader.get_resource_uid(m.get_string(2))
			if ext_uid != ResourceUID.INVALID_ID:
				lines[i] = '[ext_resource type="%s" uid="%s" path="%s" id="%s"]' % [m.get_string(1), ResourceUID.id_to_text(ext_uid), m.get_string(2), m.get_string(3)]
	text = "\n".join(lines)
	var sub_re: RegEx = RegEx.create_from_string('\\[sub_resource type="([^"]+)" id="([^"]+)"\\]')
	var counters: Dictionary = {}
	for m: RegExMatch in sub_re.search_all(text):
		var type: String = m.get_string(1)
		counters[type] = int(counters.get(type, 0)) + 1
		var old_id: String = m.get_string(2)
		var new_id: String = "%s_%d" % [type, counters[type]]
		text = text.replace('id="%s"]' % old_id, 'id="%s"]' % new_id).replace('SubResource("%s")' % old_id, 'SubResource("%s")' % new_id)
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	return OK


# --- StyleBoxes ---------------------------------------------------------------------------

func _flat(bg: Color, border: int = 2, radius: int = 3, margin_h: int = 8, margin_v: int = 4) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = P.INK
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 2
	sb.anti_aliasing = false
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


## Painel: papel, contorno INK de 3 px, cantos de 3 px e sombra dura deslocada.
func _panel_flat(bg: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = _flat(bg, 3, 3, 3, 3)
	sb.shadow_color = P.SHADOW
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(3, 3)
	return sb


## Botão em degrau: borda de baixo mais grossa; o pressed passa a borda grossa para cima
## e o texto desce 2 px, sem mudar o tamanho mínimo.
func _button_box(bg: Color, pressed: bool = false) -> StyleBoxFlat:
	var sb: StyleBoxFlat = _flat(bg, 2, 3, 10, 3)
	if pressed:
		sb.border_width_top = 4
		sb.content_margin_top = 5
		sb.content_margin_bottom = 3
	else:
		sb.border_width_bottom = 4
		sb.content_margin_top = 3
		sb.content_margin_bottom = 5
	return sb


func _empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


func _focus_box() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = P.WOOD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_expand_margin_all(2)
	sb.anti_aliasing = false
	return sb


# --- Ícones (desenhados em INK; os padrão da Godot são claros e somem no papel) -----------

## Grava o ícone em ui/theme/icons/<nome>.png (determinístico) e devolve a textura importada.
## Ícones como ext_resource: Image embutida no .tres ganha id novo cada vez que o editor salva (#50).
## PNG novo ou alterado precisa de import (--editor --quit-after) e de outro build.
func _icon(icon_name: String, size: Vector2i, painter: Callable) -> Texture2D:
	var img: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	painter.call(img)
	var path: String = ICON_DIR + icon_name + ".png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	var previous: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var png: PackedByteArray = img.save_png_to_buffer()
	if previous != png:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(png)
		f.close()
		_needs_import.append(path)
	if not ResourceLoader.exists(path):
		_needs_import.append(path)
		# Provisório (o build falha no fim pedindo o import).
		return ImageTexture.create_from_image(img)
	return load(path) as Texture2D


func _paint_arrow(img: Image) -> void:
	# Triângulo para baixo, 12x8, com 1 px de folga.
	for y in range(6):
		for x in range(1 + y, 11 - y):
			img.set_pixel(x, y + 1, P.INK)


func _paint_radio_checked(img: Image) -> void:
	_paint_radio_unchecked(img)
	for y in range(4, 10):
		for x in range(4, 10):
			if Vector2(x + 0.5, y + 0.5).distance_to(Vector2(7, 7)) <= 3.0:
				img.set_pixel(x, y, P.INK)


func _paint_radio_unchecked(img: Image) -> void:
	for y in range(14):
		for x in range(14):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(Vector2(7, 7))
			if d <= 6.5 and d >= 4.8:
				img.set_pixel(x, y, P.INK)


# --- Tipos ---------------------------------------------------------------------------------

func _set_font_colors(type: String, names: Array[String], color: Color) -> void:
	for n: String in names:
		_theme.set_color(n, type, color)


func _labels() -> void:
	_theme.set_color("font_color", "Label", P.INK)
	_theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	_theme.set_color("font_outline_color", "Label", P.INK)
	_theme.set_stylebox("normal", "Label", _empty())

	_variation("TitleLabel", "Label")
	_theme.set_font_size("font_size", "TitleLabel", 21)

	_variation("HintLabel", "Label")
	_theme.set_font_size("font_size", "HintLabel", 15)
	_theme.set_color("font_color", "HintLabel", P.WOOD)

	_variation("WarningLabel", "Label")
	_theme.set_font_size("font_size", "WarningLabel", 15)
	_theme.set_color("font_color", "WarningLabel", P.RED_BURNT)

	# Código da sala: letras GOLD com contorno INK numa plaquinha INK.
	_variation("CodeLabel", "Label")
	_theme.set_font_size("font_size", "CodeLabel", 30)
	_theme.set_color("font_color", "CodeLabel", P.GOLD)
	_theme.set_color("font_outline_color", "CodeLabel", P.INK)
	_theme.set_constant("outline_size", "CodeLabel", 4)
	var plaque: StyleBoxFlat = _flat(P.INK, 2, 3, 8, 0)
	plaque.border_color = P.WOOD_DARK
	_theme.set_stylebox("normal", "CodeLabel", plaque)

	_variation("LoadingLabel", "Label")
	_theme.set_font_size("font_size", "LoadingLabel", 30)
	_theme.set_color("font_color", "LoadingLabel", P.PAPER)

	_variation("ToastLabel", "Label")
	_theme.set_font_size("font_size", "ToastLabel", 20)
	_theme.set_color("font_color", "ToastLabel", P.PAPER)

	_theme.set_color("font_color", "TooltipLabel", P.INK)
	_theme.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))


func _variation(name: String, base: String) -> void:
	_theme.add_type(name)
	_theme.set_type_variation(name, base)


func _panels() -> void:
	_theme.set_stylebox("panel", "Panel", _panel_flat(P.PAPER))
	var container: StyleBoxFlat = _panel_flat(P.PAPER)
	container.content_margin_left = 8
	container.content_margin_right = 8
	container.content_margin_top = 4
	container.content_margin_bottom = 4
	_theme.set_stylebox("panel", "PanelContainer", container)

	# Painéis grandes (Base, menu, resumo do dia, HUD): papel gasto em 9-patch.
	var worn: StyleBoxTexture = StyleBoxTexture.new()
	worn.texture = load(WORN_TEXTURE) as Texture2D
	worn.set_texture_margin_all(TEX_MARGIN)
	worn.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	worn.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	# A textura tem 3 px de sombra à direita/embaixo: o conteúdo fica dentro do papel.
	worn.content_margin_left = 3
	worn.content_margin_top = 3
	worn.content_margin_right = 6
	worn.content_margin_bottom = 6
	_variation("WornPanel", "PanelContainer")
	_theme.set_stylebox("panel", "WornPanel", worn)

	var toast: StyleBoxFlat = _panel_flat(P.GREEN_BOTTLE)
	toast.content_margin_left = 12
	toast.content_margin_right = 12
	_variation("ToastPanel", "PanelContainer")
	_theme.set_stylebox("panel", "ToastPanel", toast)

	var tooltip: StyleBoxFlat = _flat(P.PAPER_LIGHT, 2, 2, 6, 4)
	_theme.set_stylebox("panel", "TooltipPanel", tooltip)


func _button_type(type: String, bg: Color, hover: Color, pressed: Color, text: Color) -> void:
	_theme.set_stylebox("normal", type, _button_box(bg))
	_theme.set_stylebox("hover", type, _button_box(hover))
	_theme.set_stylebox("pressed", type, _button_box(pressed, true))
	_theme.set_stylebox("hover_pressed", type, _button_box(pressed, true))
	# Desativado em papel (contorno METAL, texto WOOD) para a Loja sem saldo não virar um bloco morto.
	var disabled: StyleBoxFlat = _button_box(P.PAPER_DARK)
	disabled.border_color = P.METAL
	_theme.set_stylebox("disabled", type, disabled)
	_theme.set_stylebox("focus", type, _focus_box())
	_set_font_colors(type, ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"], text)
	_theme.set_color("font_disabled_color", type, P.WOOD)
	_theme.set_color("font_outline_color", type, P.INK)
	_theme.set_color("icon_normal_color", type, Color.WHITE)


func _buttons() -> void:
	_button_type("Button", P.PAPER_LIGHT, P.PAPER_LIGHT.lerp(P.ORANGE, 0.18), P.PAPER_DARK, P.INK)
	_theme.set_constant("h_separation", "Button", 6)

	_variation("PrimaryButton", "Button")
	_button_type("PrimaryButton", P.ORANGE, P.ORANGE.lerp(P.GOLD, 0.25), P.ORANGE, P.INK)

	_variation("DangerButton", "Button")
	_button_type("DangerButton", P.RED_BURNT, P.RED_BURNT.lightened(0.08), P.RED_BURNT.darkened(0.15), P.PAPER)

	_button_type("OptionButton", P.PAPER_LIGHT, P.PAPER_LIGHT.lerp(P.ORANGE, 0.18), P.PAPER_DARK, P.INK)
	_theme.set_icon("arrow", "OptionButton", _icon("arrow_down", Vector2i(12, 8), _paint_arrow))
	_theme.set_constant("arrow_margin", "OptionButton", 6)


func _inputs() -> void:
	var normal: StyleBoxFlat = _flat(P.PAPER_LIGHT, 2, 2, 6, 4)
	var read_only: StyleBoxFlat = _flat(P.PAPER_DARK, 2, 2, 6, 4)
	var focus: StyleBoxFlat = _focus_box()
	focus.border_color = P.ORANGE
	focus.set_expand_margin_all(0)
	_theme.set_stylebox("normal", "LineEdit", normal)
	_theme.set_stylebox("read_only", "LineEdit", read_only)
	_theme.set_stylebox("focus", "LineEdit", focus)
	_theme.set_color("font_color", "LineEdit", P.INK)
	_theme.set_color("font_uneditable_color", "LineEdit", P.WOOD)
	_theme.set_color("font_placeholder_color", "LineEdit", P.WOOD)
	_theme.set_color("font_selected_color", "LineEdit", P.INK)
	_theme.set_color("caret_color", "LineEdit", P.INK)
	_theme.set_color("selection_color", "LineEdit", Color(P.ORANGE, 0.45))
	_theme.set_color("clear_button_color", "LineEdit", P.INK)


func _tab_box(bg: Color, selected: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = _flat(bg, 2, 3, 10, 4)
	sb.border_width_bottom = 0
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	if not selected:
		# Aba de trás: mais baixa (degrau) e encostada na linha do painel.
		sb.expand_margin_top = -2
	return sb


func _tabs() -> void:
	var panel: StyleBoxFlat = _flat(P.PAPER, 2, 3, 6, 4)
	panel.corner_radius_top_left = 0
	for type: String in ["TabContainer", "TabBar"]:
		_theme.set_stylebox("tab_selected", type, _tab_box(P.PAPER, true))
		_theme.set_stylebox("tab_unselected", type, _tab_box(P.PAPER_DARK, false))
		_theme.set_stylebox("tab_hovered", type, _tab_box(P.PAPER_DARK.lerp(P.PAPER, 0.5), false))
		var tab_disabled: StyleBoxFlat = _tab_box(P.PAPER_DARK, false)
		tab_disabled.border_color = P.METAL
		_theme.set_stylebox("tab_disabled", type, tab_disabled)
		_theme.set_stylebox("tab_focus", type, _focus_box())
		_set_font_colors(type, ["font_selected_color", "font_unselected_color", "font_hovered_color"], P.INK)
		_theme.set_color("font_disabled_color", type, P.WOOD)
		_theme.set_color("font_outline_color", type, P.INK)
	_theme.set_stylebox("panel", "TabContainer", panel)
	_theme.set_stylebox("tabbar_background", "TabContainer", _empty())
	_theme.set_constant("side_margin", "TabContainer", 0)


func _lists() -> void:
	_theme.set_stylebox("panel", "ItemList", _flat(P.PAPER_LIGHT, 2, 2, 4, 4))
	_theme.set_stylebox("focus", "ItemList", _empty())
	var selected: StyleBoxFlat = _flat(P.ORANGE, 0, 2, 2, 2)
	_theme.set_stylebox("selected", "ItemList", selected)
	_theme.set_stylebox("selected_focus", "ItemList", selected)
	_theme.set_stylebox("hovered", "ItemList", _flat(P.PAPER_DARK, 0, 2, 2, 2))
	_theme.set_stylebox("cursor", "ItemList", _empty())
	_theme.set_stylebox("cursor_unfocused", "ItemList", _empty())
	_set_font_colors("ItemList", ["font_color", "font_hovered_color", "font_selected_color"], P.INK)
	_theme.set_color("font_outline_color", "ItemList", P.INK)
	_theme.set_color("guide_color", "ItemList", Color(P.INK, 0.12))


func _popups() -> void:
	_theme.set_stylebox("panel", "PopupMenu", _flat(P.PAPER_LIGHT, 2, 2, 4, 4))
	_theme.set_stylebox("hover", "PopupMenu", _flat(P.ORANGE, 0, 2, 4, 2))
	var sep: StyleBoxLine = StyleBoxLine.new()
	sep.color = P.WOOD
	sep.thickness = 2
	_theme.set_stylebox("separator", "PopupMenu", sep)
	_set_font_colors("PopupMenu", ["font_color", "font_hover_color", "font_accelerator_color", "font_separator_color"], P.INK)
	_theme.set_color("font_disabled_color", "PopupMenu", P.METAL)
	_theme.set_color("font_outline_color", "PopupMenu", P.INK)
	_theme.set_icon("radio_checked", "PopupMenu", _icon("radio_checked", Vector2i(14, 14), _paint_radio_checked))
	_theme.set_icon("radio_unchecked", "PopupMenu", _icon("radio_unchecked", Vector2i(14, 14), _paint_radio_unchecked))


func _scroll_and_separators() -> void:
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = P.WOOD
	line.thickness = 2
	_theme.set_stylebox("separator", "HSeparator", line)
	_theme.set_constant("separation", "HSeparator", 6)
	var vline: StyleBoxLine = StyleBoxLine.new()
	vline.color = P.WOOD
	vline.thickness = 2
	vline.vertical = true
	_theme.set_stylebox("separator", "VSeparator", vline)

	for type: String in ["VScrollBar", "HScrollBar"]:
		_theme.set_stylebox("scroll", type, _flat(P.PAPER_DARK, 0, 2, 5, 5))
		_theme.set_stylebox("scroll_focus", type, _flat(P.PAPER_DARK, 0, 2, 5, 5))
		_theme.set_stylebox("grabber", type, _flat(P.WOOD, 1, 2, 0, 0))
		_theme.set_stylebox("grabber_highlight", type, _flat(P.ORANGE, 1, 2, 0, 0))
		_theme.set_stylebox("grabber_pressed", type, _flat(P.ORANGE.darkened(0.12), 1, 2, 0, 0))


## Barras de progresso (HP padrão em RED_BURNT, ThreatBar em ORANGE e BossBar com painel/sombra).
func _progress_bars() -> void:
	_theme.set_stylebox("background", "ProgressBar", _flat(P.PAPER_DARK, 2, 3, 2, 2))
	_theme.set_stylebox("fill", "ProgressBar", _flat(P.RED_BURNT, 2, 3, 0, 0))
	_theme.set_color("font_color", "ProgressBar", P.PAPER)
	_theme.set_color("font_outline_color", "ProgressBar", P.INK)
	_theme.set_constant("outline_size", "ProgressBar", 3)

	_variation("ThreatBar", "ProgressBar")
	_theme.set_stylebox("fill", "ThreatBar", _flat(P.ORANGE, 2, 3, 0, 0))

	_variation("BossBar", "ProgressBar")
	_theme.set_stylebox("background", "BossBar", _panel_flat(P.PAPER_DARK))
	_theme.set_stylebox("fill", "BossBar", _flat(P.RED_BURNT, 3, 3, 0, 0))



func _windows() -> void:
	# Janela embutida (AcceptDialog/ConfirmationDialog): barra de título em madeira escura.
	var border: StyleBoxFlat = _flat(P.WOOD_DARK, 3, 3, 0, 0)
	border.expand_margin_left = 6
	border.expand_margin_right = 6
	border.expand_margin_top = 32
	border.expand_margin_bottom = 6
	border.shadow_color = P.SHADOW
	border.shadow_size = 1
	border.shadow_offset = Vector2(3, 3)
	_theme.set_stylebox("embedded_border", "Window", border)
	_theme.set_stylebox("embedded_unfocused_border", "Window", border)
	_theme.set_color("title_color", "Window", P.PAPER)
	_theme.set_color("title_outline_modulate", "Window", P.INK)
	_theme.set_constant("title_height", "Window", 30)
	_theme.set_font_size("title_font_size", "Window", FONT_SIZE)

	var dialog_panel: StyleBoxFlat = _flat(P.PAPER, 0, 0, 10, 8)
	_theme.set_stylebox("panel", "AcceptDialog", dialog_panel)
	_theme.set_constant("buttons_separation", "AcceptDialog", 10)


# --- Fonte desenhada à mão (#51) ---------------------------------------------------------

func _hand_font(file: String, embolden: float = 0.0) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = load(FONT_DIR + file) as FontFile
	font.variation_embolden = embolden
	var symbols: SystemFont = SystemFont.new()
	symbols.font_names = SYMBOL_FONTS
	var emoji: SystemFont = SystemFont.new()
	emoji.font_names = EMOJI_FONTS
	font.fallbacks = [symbols, emoji]
	return font


func _fonts() -> void:
	if _font_variant == "none":
		return
	# Patrick Hand no texto todo: traço de caneta e dígitos claros. O traço original fica fino
	# em telas grandes; o embolden engrossa sem mudar as métricas. Kalam Bold em títulos e
	# botões foi testada e recusada: o "1" dela parece "l" nos preços e níveis.
	_theme.default_font = _hand_font("PatrickHand-Regular.ttf", BODY_EMBOLDEN)
	var strong: FontVariation = _hand_font("PatrickHand-Regular.ttf", TITLE_EMBOLDEN)
	_theme.set_font("font", "TitleLabel", strong)
	_theme.set_font("title_font", "Window", strong)
	# Código da sala: no Patrick Hand o "M" parece "H" (os dois estão no alfabeto do código);
	# Kalam Bold separa bem os caracteres do alfabeto (sem 0/O/1/I).
	var code: FontVariation = _hand_font("Kalam-Bold.ttf")
	_theme.set_font("font", "CodeLabel", code)
	_variation("CodeLineEdit", "LineEdit")
	_theme.set_font("font", "CodeLineEdit", code)
