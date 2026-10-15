## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/money_format_test.gd
## MoneyFormat: milhar com ponto e NBSP depois de "R$". Só funções puras.
extends SceneTree

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	var cases: Dictionary = {0: "0", 999: "999", 1000: "1.000", 3200: "3.200", 1234567: "1.234.567", -1234567: "-1.234.567", -999: "-999"}
	for amount: int in cases:
		var got: String = MoneyFormat.thousands(amount)
		_check(got == String(cases[amount]), "thousands(%d) = %s" % [amount, got])
	var nbsp: String = String.chr(0x00A0)
	_check(MoneyFormat.NBSP == nbsp, "NBSP é U+00A0")
	_check(MoneyFormat.money(3200) == "R$" + nbsp + "3.200", "money(3200) = %s" % MoneyFormat.money(3200))
	_check(MoneyFormat.money(0) == "R$" + nbsp + "0", "money(0) = %s" % MoneyFormat.money(0))
	_check(MoneyFormat.money(-1234567) == "R$" + nbsp + "-1.234.567", "money(-1234567) = %s" % MoneyFormat.money(-1234567))
	_check(not MoneyFormat.money(1200).contains(" "), "sem espaço comum: %s" % MoneyFormat.money(1200).c_escape())
	print("RESULT fails=%d" % _fails)
	quit(_fails)
