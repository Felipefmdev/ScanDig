extends GutTest

var _old_map: MapData = null

func before_each() -> void:
	_old_map = SessionManager.instance.get_current_map()
	SessionManager.instance._current_map = load("res://items/maps/praia.tres") as MapData
	SessionUI.instance._clear_toasts()
	SessionUI.instance.hide_save_toast()

func after_each() -> void:
	SessionManager.instance._current_map = _old_map
	SessionUI.instance._clear_toasts()
	SessionUI.instance.hide_save_toast()
	SessionUI.instance.loading_screen.hide()

func test_live_key_notification_identifies_item_and_passage_without_claiming_a_save() -> void:
	GameState.instance.emit_signal("boss_key_available", "campo")
	assert_true(SessionUI.instance.toast_panel.visible)
	assert_eq(SessionUI.instance.toast_label.text, "Chave disponível: Coroa do Caranguejo-Rei. Use na passagem para Campo Antigo.")
	assert_false(SessionUI.instance.toast_label.text.to_lower().contains("salv"))

func test_scene_failure_hides_loading_and_shows_actionable_recovery_message() -> void:
	SessionUI.instance.loading_screen.show()
	SessionManager.instance.passage_travel_failed.emit("O destino não terminou de carregar. Tente novamente pela base.")
	assert_false(SessionUI.instance.loading_screen.visible)
	assert_true(SessionUI.instance.save_toast_panel.visible)
	assert_eq(SessionUI.instance.save_toast_label.text, "O destino não terminou de carregar. Tente novamente pela base.")
