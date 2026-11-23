extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui: SessionUI = root.get_node(^"CoreSessionUI") as SessionUI
	TranslationServer.set_locale("en")
	ui.call(&"_show_summary", {
		"day": 2, "map_name": "Praia",
		"money_start": 1000, "money_end": 800, "money_earned": -200,
		"entries": [
			{"name": "Item A", "action": "sold", "value": 100},
			{"name": "Item B", "action": "sold", "value": 50},
			{"name": "Item C", "action": "donated", "value": 30},
		],
	})
	var totals: String = ui.summary_total_label.text
	_check(totals.contains("Sold") and totals.contains(UiFormat.money(150)), "sale proceeds")
	_check(totals.contains("Donated to the museum") and totals.contains(UiFormat.money(30)), "donation rewards")
	_check(totals.contains("Team balance") and totals.contains(UiFormat.money(800)), "closing balance")
	_check(not totals.contains("Total earned"), "net spending is not labeled as earnings")
	_check(ui.summary_list.item_count == 3, "all transactions remain visible")
	_check(ui.summary_close_button.has_focus(), "close receives initial focus")

	TranslationServer.set_locale("pt_BR")
	ui.call(&"_show_summary", {"entries": [], "money_end": 800})
	_check(ui.summary_list.get_item_text(0) == "Nenhum item vendido ou doado nesta expedição.", "empty state in Portuguese")
	_check(ui.summary_total_label.text.contains("Saldo da equipe"), "balance in Portuguese")
	ui.summary_close_button.pressed.emit()
	_check(not ui.summary_panel.visible, "close hides the summary")
	print("RESULT fails=%d" % _failures)
	quit(_failures)


func _check(passed: bool, description: String) -> void:
	print(("PASS " if passed else "FAIL ") + description)
	if not passed:
		_failures += 1
