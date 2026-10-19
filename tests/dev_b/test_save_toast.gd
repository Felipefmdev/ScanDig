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
	_save().save_failed_with_reason.emit(SaveManager.FailReason.WRITE, "Falha ao salvar o arquivo: código 31")
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


## Q1 (#137): o aviso depende do motivo; uso fora de hora não vira aviso para o jogador.
func test_save_failed_text_by_reason() -> void:
	var ui: SessionUI = _ui()
	var expected: Dictionary = {
		SaveManager.FailReason.WRITE: SessionUI.SAVE_FAILED_TEXT,
		SaveManager.FailReason.READ: SessionUI.SAVE_FAILED_TEXT,
		SaveManager.FailReason.NEWER_VERSION: SessionUI.SAVE_NEWER_TEXT,
		SaveManager.FailReason.NOT_HOST: "",
		SaveManager.FailReason.NOT_APPLIED: "",
		SaveManager.FailReason.NO_STATE: "",
	}
	assert_eq(expected.size(), SaveManager.FailReason.size(), "todo motivo coberto")
	for reason: int in expected:
		ui.hide_save_toast()
		_save().save_failed_with_reason.emit(reason, "msg do dev")
		var text: String = expected[reason]
		var key: String = SaveManager.FailReason.keys()[reason]
		assert_eq(ui.save_toast_panel.visible, not text.is_empty(), "%s: toast visível?" % key)
		if not text.is_empty():
			assert_eq(ui.save_toast_label.text, text, "%s: texto" % key)
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate(SessionUI.SAVE_NEWER_TEXT), "This save is from a newer version; your progress will not be saved")


## O save_failed só com a String continua saindo (compatível) e não mostra aviso sozinho.
func test_plain_save_failed_still_emitted() -> void:
	var ui: SessionUI = _ui()
	watch_signals(_save())
	_save().save_failed.emit("só a String")
	assert_signal_emitted(_save(), "save_failed")
	assert_false(ui.save_toast_panel.visible, "o toast vem do sinal com motivo")


## O autoload (outros testes trocam o SaveManager.instance).
func _save() -> SaveManager:
	return get_node_or_null(^"/root/CoreSave") as SaveManager
