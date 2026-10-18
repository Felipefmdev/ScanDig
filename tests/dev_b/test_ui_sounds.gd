extends GutTest

## Sons de UI (#123): o UISounds liga todo BaseButton que entra na árvore; clique toca o
## UI_CLICK, hover do mouse toca o UI_HOVER (com intervalo mínimo), foco sem tecla de navegação
## e botões mudos ou desabilitados ficam quietos.

var _ui: UISounds = null
var _auto: UISounds = null


## O autoload também liga os botões: sai da frente durante o teste.
func before_all() -> void:
	_auto = get_tree().root.get_node_or_null(^"CoreUISounds") as UISounds
	if _auto != null:
		get_tree().node_added.disconnect(_auto._on_node_added)


func after_all() -> void:
	if _auto != null:
		get_tree().node_added.connect(_auto._on_node_added)


func before_each() -> void:
	_ui = UISounds.new()
	add_child_autofree(_ui)


func _button(parent: Node = self) -> Button:
	var b: Button = Button.new()
	b.text = "Teste"
	parent.add_child(b)
	autofree(b)
	return b


func test_buttons_added_later_and_nested_are_hooked() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	add_child_autofree(box)
	var b: Button = _button(box)
	var c: CheckBox = CheckBox.new()
	box.add_child(c)
	assert_true(b.has_meta(UISounds._HOOKED_META), "Button ligado")
	assert_true(c.has_meta(UISounds._HOOKED_META), "CheckBox (BaseButton) ligado")
	assert_eq(b.pressed.get_connections().size(), 1, "uma ligação só, sem duplicar")


func test_click_plays_click_sound() -> void:
	var b: Button = _button()
	b.pressed.emit()
	assert_eq(_ui.last_played, &"click")
	assert_eq(_ui.played_count, 1)


func test_mouse_hover_plays_once_per_interval() -> void:
	var a: Button = _button()
	var b: Button = _button()
	a.mouse_entered.emit()
	b.mouse_entered.emit()
	assert_eq(_ui.last_played, &"hover")
	assert_eq(_ui.played_count, 1, "dois hovers seguidos: um som só")


func test_focus_without_navigation_is_silent() -> void:
	var b: Button = _button()
	b.focus_entered.emit()
	assert_eq(_ui.played_count, 0, "grab_focus ao abrir um menu não toca")


func test_muted_and_disabled_buttons_are_silent() -> void:
	var m: Button = _button()
	m.set_meta(UISounds.MUTE_META, true)
	m.pressed.emit()
	var g: Button = _button()
	g.add_to_group(UISounds.MUTE_GROUP)
	g.pressed.emit()
	var d: Button = _button()
	d.disabled = true
	d.mouse_entered.emit()
	assert_eq(_ui.played_count, 0)


func test_autoload_registered() -> void:
	assert_eq(ProjectSettings.get_setting("autoload/CoreUISounds", ""), "*res://ui/ui_sounds.gd")
