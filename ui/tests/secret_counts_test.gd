# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/secret_counts_test.gd
# Segredos contados por mapa (UiFormat): prefixo do id, contagem, nome do mapa e grupo "Outros".
extends SceneTree

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	# 1. Prefixo até o primeiro "_".
	_check(UiFormat.secret_map_id("praia_reliquia_navio") == "praia", "prefixo praia")
	_check(UiFormat.secret_map_id("campo_ovo_ovelha") == "campo", "prefixo campo")
	_check(UiFormat.secret_map_id("semprefixo") == UiFormat.OTHER_SECRET_GROUP and UiFormat.secret_map_id("_x") == UiFormat.OTHER_SECRET_GROUP, "sem prefixo -> outros")

	# 2. Contagem com os dois mapas misturados, na ordem de GameState.SECRETS.
	var praia: Array[String] = []
	var campo: Array[String] = []
	for id: String in GameState.SECRETS:
		if id.begins_with("praia_"):
			praia.append(id)
		elif id.begins_with("campo_"):
			campo.append(id)
	var found: Array = [praia[0], campo[1], praia[2], "segredo_que_nao_existe"]
	var counts: Dictionary = UiFormat.secret_counts_by_map(found)
	_check(counts.keys() == ["praia", "campo"], "mapas na ordem de SECRETS: %s" % [counts.keys()])
	_check(counts["praia"] == {"found": 2, "total": praia.size()}, "praia: %s" % [counts["praia"]])
	_check(counts["campo"] == {"found": 1, "total": campo.size()}, "campo: %s" % [counts["campo"]])

	# 3. Mapa sem nenhum encontrado.
	var only_praia: Dictionary = UiFormat.secret_counts_by_map([praia[0]])
	_check(int(only_praia["campo"]["found"]) == 0 and int(only_praia["campo"]["total"]) == 6, "campo 0/6: %s" % [only_praia["campo"]])
	_check(UiFormat.secret_counts_by_map([]).size() == 2, "nada encontrado: os 2 mapas aparecem")

	# 4. Id sem prefixo conhecido: entra em "Outros" sem quebrar; id encontrado fora da lista é ignorado.
	var custom: Dictionary = UiFormat.secret_counts_by_map(["avulso"], ["praia_a", "avulso", "praia_b"])
	_check(custom.keys() == ["praia", "outros"] and custom["outros"] == {"found": 1, "total": 1}, "grupo Outros: %s" % [custom])
	_check(UiFormat.secret_count_text("outros", custom["outros"], []) == "Outros\u00a01/1", "texto Outros")

	# 5. A soma dos totais por mapa é SECRETS.size().
	var total: int = 0
	for map_id: String in counts:
		total += int(counts[map_id]["total"])
	_check(total == GameState.SECRETS.size(), "soma dos totais %d == %d" % [total, GameState.SECRETS.size()])

	# 6. Nome do mapa: MapData.display_name, ou o id com maiúscula sem o mapa.
	var map: MapData = MapData.new()
	map.id = "campo"
	map.display_name = "Campo Antigo"
	_check(UiFormat.map_display_name("campo", [map]) == "Campo Antigo", "nome pelo MapData")
	_check(UiFormat.map_display_name("praia", [map]) == "Praia", "sem MapData: 'Praia'")
	_check(UiFormat.secret_count_text("campo", {"found": 3, "total": 6}, [map]) == "Campo\u00a0Antigo\u00a03/6", "texto sem quebra dentro do mapa")

	print("RESULT fails=%d" % _fails)
	quit(_fails)
