class_name CaptionsHud
extends CanvasLayer

## Legendas de sons importantes (#140): "[Criatura se aproximando]", "[Chefe]", "[Clima chegando]",
## "[Explosão]". Quem decide se, quando e quantas é o A11y (core/a11y.gd); aqui só aparece: uma
## linha por legenda, centrada acima da hotbar, some em A11y.CAPTION_SECONDS. Também mostra os
## avisos do modo alternar (cuidado ligado/desligado). Estilo do tema: ToastPanel / ToastLabel.
## Autoload CoreCaptionsUI.

const THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
## Distância da base da tela até a última linha (acima da hotbar e das barras).
const BOTTOM_MARGIN: float = 196.0
const LINE_GAP: int = 6
const FADE_SECONDS: float = 0.4

static var instance: CaptionsHud = null

var root_control: Control = null
var stack: VBoxContainer = null


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 6
	_build()
	var a11y: A11y = A11y.instance
	if a11y != null:
		a11y.caption_shown.connect(show_line)
		a11y.notice_shown.connect(show_line)


func _build() -> void:
	root_control = Control.new()
	root_control.name = "Root"
	root_control.theme = THEME
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_to_group(SettingsManager.HUD_TEXT_GROUP)
	add_child(root_control)

	stack = VBoxContainer.new()
	stack.name = "CaptionStack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.add_theme_constant_override("separation", LINE_GAP)
	stack.anchor_left = 0.5
	stack.anchor_right = 0.5
	stack.anchor_top = 1.0
	stack.anchor_bottom = 1.0
	stack.offset_bottom = -BOTTOM_MARGIN
	stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stack.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root_control.add_child(stack)


## Uma linha nova embaixo; as mais velhas sobem e somem sozinhas.
func show_line(text: String) -> PanelContainer:
	if text.is_empty():
		return null
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Caption"
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "CaptionRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 6)
	panel.add_child(row)
	var icon_name: String = _icon_for_caption(text)
	if not icon_name.is_empty():
		var icon: TextureRect = TextureRect.new()
		icon.name = "CaptionIcon"
		icon.custom_minimum_size = Vector2(18, 18)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = UiIcons.get_icon(icon_name, 36)
		row.add_child(icon)
	var label: Label = Label.new()
	label.name = "CaptionLabel"
	label.theme_type_variation = &"ToastLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = text
	row.add_child(label)
	stack.add_child(panel)
	# Nunca mais linhas que o A11y deixa: a mais velha sai (avisos não passam pelo limite).
	while stack.get_child_count() > A11y.CAPTION_MAX:
		var oldest: Node = stack.get_child(0)
		stack.remove_child(oldest)
		oldest.queue_free()
	if is_inside_tree():
		_expire(panel)
	return panel


static func _icon_for_caption(text: String) -> String:
	var low: String = text.to_lower()
	if low.contains("chefe") or low.contains("boss") or low.contains("criatura") or low.contains("creature"):
		return "skull"
	if low.contains("clima") or low.contains("weather"):
		return "rain"
	if low.contains("explos") or low.contains("perigo"):
		return "warning"
	if low.contains("cuidado") or low.contains("careful"):
		return "check"
	return ""


func lines() -> PackedStringArray:
	var out: PackedStringArray = []
	for child: Node in stack.get_children():
		if not child.is_queued_for_deletion():
			var lbl: Label = child.find_child("CaptionLabel", true, false) as Label
			if lbl != null:
				out.append(lbl.text)
	return out


func clear() -> void:
	for child: Node in stack.get_children():
		stack.remove_child(child)
		child.queue_free()


func _expire(panel: PanelContainer) -> void:
	await get_tree().create_timer(A11y.CAPTION_SECONDS - FADE_SECONDS, false).timeout
	if not is_instance_valid(panel):
		return
	var tween: Tween = panel.create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
	if is_instance_valid(panel):
		panel.queue_free()
