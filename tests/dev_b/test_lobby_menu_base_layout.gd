extends GutTest

## Lobby: com ui_scale 1.3 o MultiplayerMenu cruzaria a Base; fica recolhido num botão
## "Multiplayer" (acima da Base) e abre por cima dela ao clicar. Com ui 1.0 nada muda.

const LOBBY_SCENE: PackedScene = preload("res://world/lobby_base.tscn")

var _lobby: Node = null
var _menu: MultiplayerMenu = null
var _base: Control = null
var _old_size: Vector2i = Vector2i.ZERO


## Retângulo do que a Base desenha (a raiz tem altura 0; o painel é filho).
static func visual_rect(c: Control) -> Rect2:
	var out: Rect2 = c.get_global_rect()
	for child: Node in c.get_children():
		var cc: Control = child as Control
		if cc != null and cc.is_visible_in_tree() and not cc.top_level:
			out = out.merge(cc.get_global_rect())
	return out


func before_each() -> void:
	_old_size = get_tree().root.size
	get_tree().root.size = Vector2i(960, 540)
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	_lobby = LOBBY_SCENE.instantiate()
	add_child_autofree(_lobby)
	await wait_frames(3)
	_menu = _lobby.get_node(^"UILayer/MultiplayerMenu") as MultiplayerMenu
	_base = _lobby.get_node(^"UILayer/BaseStationUI") as Control


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	get_tree().root.size = _old_size
	SessionManager.launch_mode = ""


func _panel() -> Control:
	return _menu.get_node(^"PanelContainer") as Control


func _button() -> Button:
	return _menu.get_node(^"CollapseButton") as Button


func test_ui_100_menu_open_beside_base() -> void:
	get_tree().root.content_scale_factor = 1.0
	await wait_frames(3)
	assert_false(_menu.is_collapsed())
	assert_true(_panel().is_visible_in_tree())
	assert_false(_button().visible, "sem botão de recolher quando cabe")
	assert_false(_panel().get_global_rect().intersects(visual_rect(_base)), "menu ao lado da Base")


func test_ui_130_menu_collapsed_clear_of_base() -> void:
	get_tree().root.content_scale_factor = 1.3
	await wait_frames(3)
	assert_true(_menu.is_collapsed(), "recolhido em ui 1.3")
	assert_false(_panel().is_visible_in_tree())
	assert_true(_button().is_visible_in_tree())
	var view: Rect2 = get_tree().root.get_visible_rect()
	var b: Rect2 = _button().get_global_rect()
	assert_true(view.encloses(b), "botão na tela: %s em %s" % [b, view])
	assert_false(b.intersects(visual_rect(_base)), "botão %s não cobre a Base %s" % [b, visual_rect(_base)])


func test_ui_130_toggle_opens_over_base_and_back() -> void:
	get_tree().root.content_scale_factor = 1.3
	await wait_frames(3)
	_button().pressed.emit()
	await wait_frames(2)
	assert_false(_menu.is_collapsed())
	assert_true(_panel().is_visible_in_tree(), "aberto ao clicar")
	assert_eq(_menu.z_index, 1, "aberto por cima da Base")
	assert_false(_button().get_global_rect().intersects(_panel().get_global_rect()), "botão acima do painel")
	_button().pressed.emit()
	await wait_frames(2)
	assert_true(_menu.is_collapsed())
	assert_eq(_menu.z_index, 0)
	# Volta para ui 1.0: o menu reaparece inteiro, sem botão.
	get_tree().root.content_scale_factor = 1.0
	await wait_frames(3)
	assert_true(_panel().is_visible_in_tree())
	assert_false(_button().visible)
