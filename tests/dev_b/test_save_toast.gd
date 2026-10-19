extends GutTest

## Aviso global de save (P1): o save_failed e o save_load_failed do CoreSave aparecem no toast da
## SessionUI em qualquer tela (fora da expedição também), por cima do carregamento e no idioma atual.


## Outros testes do save emitem save_failed no CoreSave: cada teste começa sem aviso.
func before_each() -> void:
	var ui: SessionUI = get_node_or_null(^"/root/CoreSessionUI") as SessionUI
	if ui != null:
		ui.hide_save_toast()


func after_each() -> void:
	TranslationServer.set_locale("pt_BR")
	var ui: SessionUI = get_node_or_null(^"/root/CoreSessionUI") as SessionUI
	if ui != null:
		ui.hide_save_toast()


func _ui() -> SessionUI:
	var ui: SessionUI = get_node_or_null(^"/root/CoreSessionUI") as SessionUI
	assert_not_null(ui, "autoload CoreSessionUI")
	assert_not_null(ui.save_toast_panel, "toast de save montado")
	return ui


func test_save_failed_shows_disk_warning() -> void:
	var ui: SessionUI = _ui()
	assert_not_null(_save(), "autoload CoreSave")
	assert_false(bool(ui._session_call(&"is_in_expedition", false)), "fora da expedição")
	_save().save_failed.emit("Falha ao salvar o arquivo: código 31")
	assert_true(ui.save_toast_panel.visible, "aparece fora da expedição")
	assert_eq(ui.save_toast_label.text, SessionUI.SAVE_FAILED_TEXT, "texto do jogador, não o do dev")
	assert_eq(ui.save_toast_panel.get_index(), ui.get_child_count() - 1, "por cima do carregamento")
	TranslationServer.set_locale("en")
	assert_eq(ui.save_toast_label.atr(ui.save_toast_label.text), "Could not save — check your free disk space")


func test_save_load_failed_shows_manager_message() -> void:
	var ui: SessionUI = _ui()
	_save().save_load_failed.emit(SaveManager.MSG_CORRUPT)
	assert_true(ui.save_toast_panel.visible)
	assert_eq(ui.save_toast_label.text, SaveManager.MSG_CORRUPT)
	_save().save_load_failed.emit(SaveManager.MSG_NEWER)
	assert_eq(ui.save_toast_label.text, SaveManager.MSG_NEWER, "aviso novo troca o texto")
	TranslationServer.set_locale("en")
	assert_eq(ui.save_toast_label.atr(ui.save_toast_label.text), "This save is from a newer version of the game. Update ScanDig to continue.")


## O autoload (outros testes trocam o SaveManager.instance).
func _save() -> SaveManager:
	return get_node_or_null(^"/root/CoreSave") as SaveManager
