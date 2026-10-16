# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/format_test.gd
# UiFormat (#51): "R$" colado no número (NBSP) e separador de milhar; nenhum "R$ %d" sobrando em ui/.
extends SceneTree

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_check(UiFormat.NBSP == String.chr(0xA0), "NBSP é U+00A0")
	_check(UiFormat.money(3200) == "R$" + String.chr(0xA0) + "3.200", "money(3200): '%s'" % UiFormat.money(3200))
	_check(UiFormat.money(0) == "R$\u00a00" and UiFormat.money(55000) == "R$\u00a055.000", "money(0) e money(55000)")
	_check(UiFormat.thousands(-1234567) == "-1.234.567", "thousands(-1234567): '%s'" % UiFormat.thousands(-1234567))
	_check(UiFormat.thousands(999) == "999" and UiFormat.thousands(1000) == "1.000", "thousands curtos")
	_check(MultiplayerMenu.format_money(3200) == UiFormat.thousands(3200), "format_money delega para thousands")
	_check(UiFormat.fix_money_spaces("Saldo insuficiente (R$ 300). Custo: R$ 1200") == "Saldo insuficiente (R$\u00a0300). Custo: R$\u00a01200", "fix_money_spaces")
	_check(UiFormat.fix_money_spaces("Sem valor.") == "Sem valor.", "fix_money_spaces sem R$")

	# Museu: item sem profundidade (não escavado) mostra "Achado especial".
	var special: ItemData = ItemData.new()
	special.display_name = "Anel do Poço"
	special.base_value = 600
	special.depth_cm = 0
	var special_line: String = BaseStationUI.museum_line(special, false)
	_check(special_line == "[ ? ] Anel do Poço (Valor: R$ 600 | Achado especial)" and not special_line.contains("Profundidade"), "museu especial: '%s'" % special_line)
	var dug: ItemData = ItemData.new()
	dug.display_name = "Aliança de Ouro"
	dug.base_value = 250
	dug.depth_cm = 18
	var dug_line: String = BaseStationUI.museum_line(dug, true)
	_check(dug_line == "[DESCOBERTO] Aliança de Ouro (Valor: R$ 250 | Profundidade: 18 cm)", "museu escavado: '%s'" % dug_line)

	# Nenhum "R$ %d"/"R$ %s" em ui/*.gd e nenhum "R$ " com espaço comum nas .tscn de ui/.
	var leftovers: Array[String] = []
	for file: String in DirAccess.get_files_at("res://ui"):
		var text: String = FileAccess.get_file_as_string("res://ui/" + file)
		if file.ends_with(".gd") and file != "ui_format.gd" and (text.contains("R$ %d") or text.contains("R$ %s")):
			leftovers.append(file)
		if file.ends_with(".tscn") and text.contains("R$ "):
			leftovers.append(file)
	_check(leftovers.is_empty(), "sem 'R$ %%d' nem 'R$ ' em ui/: %s" % [leftovers])
	print("RESULT fails=%d" % _fails)
	quit(_fails)
