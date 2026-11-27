class_name AchievementsTab
extends VBoxContainer

## Aba "Conquistas" da Base (#141): uma linha por conquista de core/data/achievements.json, com
## ícone, nome, descrição e progresso; as bloqueadas ficam em cinza. Cada linha é um botão plano
## (sem ação) para a navegação por teclado/comando passar por todas e o ScrollContainer da Base
## acompanhar o foco. Lê o GameState local: no cliente, o que chegou pelo snapshot do host.

const TAB_NAME: String = "Conquistas"
const ICON_SIDE: int = 32
const LOCKED_TINT: Color = Color(0.95, 0.93, 0.89, 1.0)
const DONE_MARK: String = "✔"

var header_label: Label = null
var header_bar: ProgressBar = null
var _list: VBoxContainer = null
## id -> botão da linha (testes e foco).
var _rows: Dictionary = {}
## Ícones em tons de cinza das bloqueadas (nome -> textura).
static var _gray_cache: Dictionary = {}


func _init() -> void:
	name = TAB_NAME


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	var header_card: PanelContainer = PanelContainer.new()
	header_card.name = "HeaderCard"
	header_card.theme_type_variation = &"SummaryTotalPanel"
	var header_row: HBoxContainer = HBoxContainer.new()
	header_row.add_theme_constant_override(&"separation", 8)
	header_card.add_child(header_row)
	var trophy_icon: TextureRect = TextureRect.new()
	trophy_icon.texture = UiIcons.get_icon("trophy", 24)
	trophy_icon.custom_minimum_size = Vector2(20, 20)
	trophy_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trophy_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trophy_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(trophy_icon)
	header_label = Label.new()
	header_label.name = "AchievementsHeader"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	header_bar = ProgressBar.new()
	header_bar.name = "HeaderBar"
	header_bar.show_percentage = false
	header_bar.custom_minimum_size = Vector2(124, 10)
	header_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_bar.focus_mode = Control.FOCUS_NONE
	var header_track: StyleBoxFlat = StyleBoxFlat.new()
	header_track.bg_color = UiPalette.PAPER_DARK
	header_track.border_color = UiPalette.INK
	header_track.set_border_width_all(2)
	header_track.set_corner_radius_all(3)
	header_bar.add_theme_stylebox_override(&"background", header_track)
	header_row.add_child(header_bar)
	add_child(header_card)
	_list = VBoxContainer.new()
	_list.name = "AchievementsList"
	_list.add_theme_constant_override(&"separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_list)
	var gs: GameState = GameState.instance
	if gs != null:
		gs.state_synced.connect(refresh)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


## Refaz as linhas com o estado atual (o foco fica na mesma conquista).
func refresh() -> void:
	if _list == null:
		return
	var focused_id: String = ""
	var focus: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for id: String in _rows:
		if _rows[id] == focus:
			focused_id = id
	var data: Dictionary = GameState.instance.get_snapshot() if GameState.instance != null else {}
	var unlocked: Array = data.get("achievements", [])
	var defs: Array[Dictionary] = Achievements.definitions()
	var done: int = 0
	for def: Dictionary in defs:
		if unlocked.has(def["id"]):
			done += 1
	header_label.text = tr("Conquistas: %d/%d") % [done, defs.size()]
	if header_bar != null:
		header_bar.max_value = maxi(defs.size(), 1)
		header_bar.value = done
		var header_fill: StyleBoxFlat = StyleBoxFlat.new()
		header_fill.bg_color = UiPalette.GREEN_BOTTLE if defs.size() > 0 and done >= defs.size() else UiPalette.ORANGE
		header_fill.border_color = UiPalette.INK
		header_fill.set_border_width_all(2)
		header_fill.set_corner_radius_all(3)
		header_bar.add_theme_stylebox_override(&"fill", header_fill)
	if _rows.size() != defs.size():
		_rebuild(defs)
	for def: Dictionary in defs:
		_fill_row(_rows[def["id"]], def, data, unlocked.has(def["id"]))
	if not focused_id.is_empty() and _rows.has(focused_id):
		(_rows[focused_id] as Control).grab_focus()


func get_row(id: String) -> Button:
	return _rows.get(id, null) as Button


func get_row_count() -> int:
	return _rows.size()


func is_row_unlocked(id: String) -> bool:
	var row: Button = get_row(id)
	return row != null and bool(row.get_meta(&"unlocked", false))


## "Nome\nDescrição\nprogresso" da linha (testes).
func get_row_text(id: String) -> String:
	var row: Button = get_row(id)
	if row == null:
		return ""
	return "%s\n%s\n%s" % [(row.find_child("Name", true, false) as Label).text,
		(row.find_child("Desc", true, false) as Label).text, (row.find_child("Progress", true, false) as Label).text]


func _rebuild(defs: Array[Dictionary]) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	for def: Dictionary in defs:
		var row: Button = _build_row(str(def["id"]))
		_list.add_child(row)
		_rows[def["id"]] = row


func _build_row(id: String) -> Button:
	var row: Button = Button.new()
	row.name = "Row_" + id
	row.flat = true
	row.focus_mode = Control.FOCUS_ALL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.theme_type_variation = &"InsetPanel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	card.add_child(margin)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override(&"separation", 10)
	margin.add_child(hbox)
	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(ICON_SIDE, ICON_SIDE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_theme_constant_override(&"separation", 0)
	hbox.add_child(texts)
	var title: Label = Label.new()
	title.name = "Name"
	title.add_theme_color_override(&"font_color", UiPalette.WOOD_DARK)
	texts.add_child(title)
	var desc: Label = Label.new()
	desc.name = "Desc"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override(&"font_size", 15)
	desc.add_theme_color_override(&"font_color", UiPalette.INK)
	texts.add_child(desc)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(120, 0)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right)
	var progress: Label = Label.new()
	progress.name = "Progress"
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.add_theme_font_size_override(&"font_size", 15)
	right.add_child(progress)
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "Bar"
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.focus_mode = Control.FOCUS_NONE
	var bar_track: StyleBoxFlat = StyleBoxFlat.new()
	bar_track.bg_color = UiPalette.PAPER_DARK
	bar_track.border_color = UiPalette.INK
	bar_track.set_border_width_all(1)
	bar_track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override(&"background", bar_track)
	right.add_child(bar)
	# O botão não é contêiner: a altura da linha acompanha a do cartão.
	card.minimum_size_changed.connect(func() -> void: row.custom_minimum_size.y = card.get_combined_minimum_size().y)
	var sync_card_hover: Callable = func() -> void: _sync_row_card_style(row)
	row.mouse_entered.connect(sync_card_hover)
	row.mouse_exited.connect(sync_card_hover)
	row.focus_entered.connect(sync_card_hover)
	row.focus_exited.connect(sync_card_hover)
	UiMotion.attach_button(row, 1.01, 0.988)
	return row


func _sync_row_card_style(row: Button) -> void:
	if not is_instance_valid(row):
		return
	var card: PanelContainer = row.find_child("Card", true, false) as PanelContainer
	if card == null:
		return
	var unlocked: bool = bool(row.get_meta(&"unlocked", false))
	var active: bool = row.is_hovered() or (row.has_focus() and not InputDevice.using_pointer())
	var base_bg: Color = UiPalette.PAPER_LIGHT if unlocked else UiPalette.PAPER
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = base_bg.lerp(UiPalette.ORANGE, 0.10) if active else base_bg
	card_style.border_color = UiPalette.GREEN_BOTTLE if unlocked else (UiPalette.WOOD_DARK if active else Color(UiPalette.WOOD, 0.65))
	card_style.set_border_width_all(2)
	if unlocked:
		card_style.border_width_left = 4
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left = 8.0
	card_style.content_margin_right = 8.0
	card_style.content_margin_top = 4.0
	card_style.content_margin_bottom = 4.0
	card.add_theme_stylebox_override(&"panel", card_style)


func _fill_row(row: Button, def: Dictionary, data: Dictionary, unlocked: bool) -> void:
	var p: Vector2i = Achievements.progress(def, data)
	if unlocked:
		p.x = p.y
	row.set_meta(&"unlocked", unlocked)
	var title: Label = row.find_child("Name", true, false) as Label
	title.text = ("%s %s" % [DONE_MARK, tr(str(def["name"]))]) if unlocked else tr(str(def["name"]))
	(row.find_child("Desc", true, false) as Label).text = tr(str(def["desc"]))
	var progress: Label = row.find_child("Progress", true, false) as Label
	if unlocked:
		progress.text = tr("Desbloqueada")
	elif p.y <= 1:
		progress.text = tr("Bloqueada")
	else:
		progress.text = "%s / %s" % [UiFormat.thousands(Achievements.shown_value(def, p.x)),
			UiFormat.thousands(Achievements.shown_value(def, p.y))]
	var bar: ProgressBar = row.find_child("Bar", true, false) as ProgressBar
	bar.max_value = p.y
	bar.value = p.x
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = UiPalette.GREEN_BOTTLE if unlocked else UiPalette.ORANGE
	fill.border_color = UiPalette.INK
	fill.set_border_width_all(2)
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override(&"fill", fill)
	progress.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE if unlocked else UiPalette.WOOD)
	var desc: Label = row.find_child("Desc", true, false) as Label
	desc.add_theme_color_override(&"font_color", UiPalette.INK if unlocked else UiPalette.WOOD)
	var card: PanelContainer = row.find_child("Card", true, false) as PanelContainer
	_sync_row_card_style(row)
	var icon: TextureRect = row.find_child("Icon", true, false) as TextureRect
	icon.texture = UiIcons.get_icon(str(def["icon"]), ICON_SIDE) if unlocked else _gray_icon(str(def["icon"]))
	card.modulate = Color.WHITE if unlocked else LOCKED_TINT
	row.tooltip_text = tr(str(def["desc"]))


static func _gray_icon(icon_name: String) -> Texture2D:
	if _gray_cache.has(icon_name):
		return _gray_cache[icon_name]
	var source: Texture2D = UiIcons.get_icon(icon_name, ICON_SIDE)
	if source == null:
		return null
	var image: Image = source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var v: float = c.get_luminance()
			# Sépia suave no tom da madeira/papel em vez de cinza frio.
			image.set_pixel(x, y, Color(clampf(v * 0.96 + 0.08, 0.0, 1.0), clampf(v * 0.84 + 0.05, 0.0, 1.0), clampf(v * 0.68 + 0.02, 0.0, 1.0), c.a * 0.88))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.set_size_override(Vector2i(ICON_SIDE, ICON_SIDE))
	_gray_cache[icon_name] = texture
	return texture
