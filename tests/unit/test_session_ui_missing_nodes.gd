extends GutTest

## #73: SessionUI não crasha se um nó único (%Nome) faltar na cena.

const SCENE: PackedScene = preload("res://ui/session_ui.tscn")

var _saved_instance: SessionUI = null


func before_each() -> void:
	# A cópia de teste sobrescreve SessionUI.instance; o autoload volta no after_each.
	_saved_instance = SessionUI.instance


func after_each() -> void:
	SessionUI.instance = _saved_instance


func test_full_scene_binds_all_nodes() -> void:
	var ui: SessionUI = SCENE.instantiate() as SessionUI
	add_child_autofree(ui)
	assert_not_null(ui.toast_label, "toast_label resolvido")
	assert_not_null(ui.loading_screen, "loading_screen resolvido")
	assert_false(ui.loading_screen.visible, "tela de carregamento começa oculta")
	assert_true(ui.is_processing(), "overlay ativo com cena completa")


func test_missing_unique_node_disables_overlay() -> void:
	var ui: SessionUI = SCENE.instantiate() as SessionUI
	var label: Node = ui.find_child("ToastLabel", true, false)
	assert_not_null(label, "cena tem ToastLabel")
	label.get_parent().remove_child(label)
	label.free()
	add_child_autofree(ui)
	assert_null(ui.toast_label, "nó ausente fica null")
	assert_false(ui.is_processing(), "overlay desativado sem crashar")
