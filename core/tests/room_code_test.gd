## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/room_code_test.gd
## RoomCode (#30): só funções puras, não precisa do noray.
extends SceneTree

var _fails: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _initialize() -> void:
	_check(RoomCode.CHARSET.length() == 32, "CHARSET com 32 caracteres: %d" % RoomCode.CHARSET.length())
	for confusing: String in ["0", "O", "1", "I"]:
		_check(not RoomCode.CHARSET.contains(confusing), "CHARSET sem '%s'" % confusing)

	# normalize
	var cases: Dictionary = {
		"k7q-3mx ": "K7Q3MX",
		"K7Q-3MX": "K7Q3MX",
		"K7Q 3MX": "K7Q3MX",
		" k7q3mx\n": "K7Q3MX",
		"k-7-q-3-m-x": "K7Q3MX",
		"": "",
	}
	for raw: String in cases.keys():
		_check(RoomCode.normalize(raw) == cases[raw], "normalize(%s) = %s: %s" % [JSON.stringify(raw), cases[raw], RoomCode.normalize(raw)])

	# is_valid
	for good: String in ["K7Q3MX", "k7q-3mx", "K7Q 3MX", "234567", "ZZZZZZ", "L7Q3MX"]:
		_check(RoomCode.is_valid(good), "válido: %s" % good)
	var bad: Array[String] = [
		"", "K7Q3M", "K7Q3MXA", "K7Q-3M",  # tamanho errado e vazio
		"O7Q3MX", "07Q3MX", "I7Q3MX", "17Q3MX",  # caracteres confusos
		"K7Q3M!", "K7Q_3MX", "K7Q3MÉ",  # fora do CHARSET
	]
	for code: String in bad:
		_check(not RoomCode.is_valid(code), "inválido: %s" % JSON.stringify(code))

	# format_for_display
	_check(RoomCode.format_for_display("K7Q3MX") == "K7Q-3MX", "format K7Q3MX: %s" % RoomCode.format_for_display("K7Q3MX"))
	_check(RoomCode.format_for_display("k7q 3mx") == "K7Q-3MX", "format k7q 3mx: %s" % RoomCode.format_for_display("k7q 3mx"))
	_check(RoomCode.format_for_display("ABC") == "ABC", "format fora do padrão fica sem hífen: %s" % RoomCode.format_for_display("ABC"))
	_check(RoomCode.is_valid(RoomCode.format_for_display("K7Q3MX")), "o código exibido volta válido")

	print("RESULT fails=%d" % _fails)
	quit(_fails)
