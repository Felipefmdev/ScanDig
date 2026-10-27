class_name AchievementsTab
extends VBoxContainer

## Aba "Conquistas" da Base (#141): uma linha por conquista de core/data/achievements.json, com
## ícone, nome, descrição e progresso; as bloqueadas ficam em cinza. Cada linha é um botão plano
## (sem ação) para a navegação por teclado/comando passar por todas e o ScrollContainer da Base
## acompanhar o foco. Lê o GameState local: no cliente, o que chegou pelo snapshot do host.

const TAB_NAME: String = "Conquistas"
const ICON_SIDE: int = 32
const LOCKED_TINT: Color = Color(0.55, 0.55, 0.55, 0.9)
const DONE_MARK: String = "✔"

var header_label: Label = null
var _list: VBoxContainer = null
## id -> botão da linha (testes e foco).
var _rows: Dictionary = {}
## Ícones em tons de cinza das bloqueadas (nome -> textura).
static var _gray_cache: Dictionary = {}


func _init() -> void:
	name = TAB_NAME


func _ready() -> void:
	add_theme_constant_override(&"separation", 8)
	header_label = Label.new()
	header_label.name = "AchievementsHeader"
	add_child(header_label)
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
	card.theme_type_variation = &"WornPanel"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
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
	right.add_child(bar)
	# O botão não é contêiner: a altura da linha acompanha a do cartão.
	card.minimum_size_changed.connect(func() -> void: row.custom_minimum_size.y = card.get_combined_minimum_size().y)
	return row


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
	var icon: TextureRect = row.find_child("Icon", true, false) as TextureRect
	icon.texture = UiIcons.get_icon(str(def["icon"]), ICON_SIDE * 2) if unlocked else _gray_icon(str(def["icon"]))
	(row.find_child("Card", true, false) as Control).modulate = Color.WHITE if unlocked else LOCKED_TINT
	row.tooltip_text = tr(str(def["desc"]))


static func _gray_icon(icon_name: String) -> Texture2D:
	if _gray_cache.has(icon_name):
		return _gray_cache[icon_name]
	var source: Texture2D = UiIcons.get_icon(icon_name, ICON_SIDE * 2)
	if source == null:
		return null
	var image: Image = source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			var v: float = c.get_luminance()
			image.set_pixel(x, y, Color(v, v, v, c.a))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_gray_cache[icon_name] = texture
	return texture
