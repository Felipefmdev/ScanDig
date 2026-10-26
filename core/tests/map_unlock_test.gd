# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/map_unlock_test.gd
extends SceneTree

const STATUS_KEYS: Array[String] = [
	"map_id", "display_name", "unlocked", "has_scene", "playable", "unlock_cost",
	"required_boss_id", "required_boss_name", "boss_defeated", "can_unlock", "reason",
]

var _fails: int = 0
var _last_result: Dictionary = {}
var _progression_signals: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _on_map_unlock_result(map_id: String, success: bool, message: String) -> void:
	_last_result = {"map_id": map_id, "success": success, "message": message}

func _on_progression_changed(_unlocked_maps: Array, _defeated_bosses: Array) -> void:
	_progression_signals += 1

func _unlock(gs: GameState, map_id: String) -> Dictionary:
	_last_result = {}
	gs.request_unlock_map(map_id)
	await _wait(3)
	return _last_result

func _report_boss(gs: GameState, boss_id: String) -> void:
	gs.request_report_boss_defeated(boss_id)
	await _wait(3)

## Valores de balanceamento vêm dos .tres (#64): o teste confere regras, não preços.
func _map(map_id: String) -> MapData:
	return load("res://items/maps/%s.tres" % map_id) as MapData

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("map_unlock_test")
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	_check(gs != null and sm != null, "GameState e SessionManager presentes")
	gs.map_unlock_result.connect(_on_map_unlock_result)
	gs.progression_changed.connect(_on_progression_changed)
	var campo_data: MapData = _map("campo")
	# Saldo historico abaixo do preco antigo: abertura por chave nao pode cobrar.
	var short_money: int = campo_data.unlock_cost - 1
	gs.load_snapshot({"team_money": short_money, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})

	var ids: Array[String] = []
	for map_data: MapData in sm.get_available_maps():
		ids.append(map_data.id)
	_check(ids == ["praia", "campo", "ruinas", "geleira", "cratera"], "ordem dos mapas: %s" % str(ids))
	_check(gs.is_map_unlocked("praia"), "praia desbloqueada")
	_check(not gs.is_map_unlocked("campo"), "campo bloqueado")

	var praia: Dictionary = sm.get_map_status("praia")
	_check(praia["unlocked"] and praia["has_scene"] and praia["playable"] and praia["reason"] == "", "status praia jogável: %s" % str(praia))

	var campo: Dictionary = sm.get_map_status("campo")
	_check(not campo["unlocked"] and campo["has_scene"] and not campo["playable"], "status campo bloqueado, com cena: %s" % str(campo))
	_check(campo["required_boss_name"] == "Caranguejo-Rei" and not campo["boss_defeated"], "status campo exige Caranguejo-Rei")
	_check(campo["reason"] == "Vença o chefe Caranguejo-Rei (Praia) para liberar.", "status campo reason: %s" % str(campo["reason"]))

	# #45: Geleira entre Ruínas e Cratera; cada mapa pede o chefe do anterior.
	var geleira: Dictionary = sm.get_map_status("geleira")
	_check(not geleira["unlocked"] and not geleira["playable"] and geleira["unlock_cost"] == 0 and _map("geleira").unlock_cost > 0, "status geleira bloqueada: %s" % str(geleira))
	_check(geleira["required_boss_id"] == "ancient_guardian" and geleira["reason"] == "Vença o chefe Guardião Ancestral (Ruínas) para liberar.", "geleira exige Guardião Ancestral: %s" % str(geleira["reason"]))
	var cratera: Dictionary = sm.get_map_status("cratera")
	_check(cratera["required_boss_id"] == "frozen_mammoth" and cratera["required_boss_name"] == "Mamute Congelado" and cratera["unlock_cost"] == 0 and _map("cratera").unlock_cost > 0, "cratera exige Mamute Congelado: %s" % str(cratera))

	var unknown: Dictionary = sm.get_map_status("xyz")
	var has_all_keys: bool = true
	for key: String in STATUS_KEYS:
		has_all_keys = has_all_keys and unknown.has(key)
	_check(has_all_keys and unknown.size() == STATUS_KEYS.size(), "status xyz tem todas as chaves")
	_check(unknown["reason"] == "Mapa desconhecido.", "status xyz reason: %s" % str(unknown["reason"]))

	var result: Dictionary = await _unlock(gs, "campo")
	_check(result.get("success", true) == false and result.get("message", "") == "Vença o chefe Caranguejo-Rei (Praia) para liberar.", "desbloqueio sem chefe falha: %s" % str(result.get("message", "")))
	_check(gs.team_money == short_money, "dinheiro continua %d: %d" % [short_money, gs.team_money])

	await _report_boss(gs, "chefe_falso")
	_check(gs.defeated_bosses.is_empty(), "chefe falso ignorado")

	_progression_signals = 0
	await _report_boss(gs, "king_crab")
	_check(gs.is_boss_defeated("king_crab"), "king_crab vencido")
	_check(_progression_signals > 0, "progression_changed emitido: %d" % _progression_signals)
	await _report_boss(gs, "king_crab")
	_check(gs.defeated_bosses.size() == 1, "king_crab não duplica: %s" % str(gs.defeated_bosses))

	# Mesmo chefe + saldo suficiente nao autorizam o endpoint legado.
	gs.load_snapshot({"team_money": campo_data.unlock_cost + 500})
	var money_before: int = gs.team_money
	result = await _unlock(gs, "campo")
	_check(not bool(result.get("success", true)) and not gs.is_map_unlocked("campo"), "legado nao compra nem abre apos chefe")
	_check(gs.team_money == money_before, "legado negado nao cobra")
	gs.load_snapshot({"team_money": short_money})
	_check(gs.open_boss_passage("campo") == OK, "abertura host-local salva recibo sem exigir saldo antigo")
	_check(gs.team_money == short_money, "abertura nao cobra nem reembolsa")
	_check(gs.is_map_unlocked("campo"), "campo aberto por recibo")
	campo = sm.get_map_status("campo")
	_check(campo_data.unlock_cost > 0 and campo_data.required_detector_level > 1, "MapData historico preservado")
	_check(campo["unlocked"] and campo["playable"] and campo["reason"] == "", "recibo permite Campo com detector inicial")
	_check(campo["unlock_cost"] == 0 and not campo["can_unlock"], "menu consulta sem preco nem autorizacao de abertura")
	_check(gs.equipped_detector_level == 1 and sm.can_start_map("campo"), "detector Nv.1 nao bloqueia Campo")
	_check(gs.open_boss_passage("campo") == OK, "abertura repetida idempotente")
	_check(gs.team_money == short_money, "repeticao nao cobra")
	result = await _unlock(gs, "campo")
	_check(not bool(result.get("success", true)), "legado repetido continua negado")
	result = await _unlock(gs, "../catalog/alianca_ouro")
	_check(not bool(result.get("success", true)), "desbloqueio malicioso negado")
	_check(gs.open_boss_passage("../catalog/alianca_ouro") != OK, "abertura host-local maliciosa negada")
	_check(gs.team_money == short_money, "nenhuma via maliciosa altera dinheiro")

	SaveManager.instance.save_game()
	var saved: Dictionary = SaveManager.instance.load_from_file()
	_check(int(saved.get("version", 0)) == SaveManager.SAVE_VERSION, "save na versão atual: %s" % str(saved.get("version")))
	_check(saved.get("unlocked_maps", []) == ["campo"], "save unlocked_maps: %s" % str(saved.get("unlocked_maps")))
	_check(saved.get("defeated_bosses", []) == ["king_crab"], "save defeated_bosses: %s" % str(saved.get("defeated_bosses")))

	# Chefes fornecem credenciais; cada abertura salva recibo sem preco/detector gate.
	for route_id: String in ["ruinas", "geleira"]:
		var route: Dictionary = GameState.MAP_UNLOCK_BOSSES[route_id]
		await _report_boss(gs, str(route["boss_id"]))
		_check(not gs.is_map_unlocked(route_id), "derrota nao abre automaticamente: " + route_id)
		_check(gs.open_boss_passage(route_id) == OK, "abertura com save OK: " + route_id)
		var route_status: Dictionary = sm.get_map_status(route_id)
		_check(route_status["unlocked"] and route_status["has_scene"] and route_status["playable"], "rota com cena jogavel: " + route_id)
		_check(route_status["reason"] == "" and sm.can_start_map(route_id), "sem gate de equipamento: " + route_id)
		_check(_map(route_id).unlock_cost > 0 and _map(route_id).required_detector_level > 1, "dados historicos preservados: " + route_id)
		_check(gs.team_money == short_money, "rota nao cobra: " + route_id)

	gs.reset_state()
	gs.load_snapshot({"team_money": 300, "current_day": 4, "discovered_items": [], "upgrade_levels": {"detector": 1}})
	_check(gs.unlocked_maps.is_empty() and gs.defeated_bosses.is_empty(), "save v2 carrega listas vazias")
	_check(gs.is_map_unlocked("praia"), "praia continua desbloqueada")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
