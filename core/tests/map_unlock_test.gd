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
	# Saldo um real abaixo do Campo: primeiro trava o chefe, depois o saldo.
	var short_money: int = campo_data.unlock_cost - 1
	gs.load_snapshot({"team_money": short_money, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})

	var ids: Array[String] = []
	for map_data: MapData in sm.get_available_maps():
		ids.append(map_data.id)
	_check(ids == ["praia", "campo", "ruinas", "geleira", "cratera", "ilha_tesouro"], "ordem dos mapas: %s" % str(ids))
	# Ilha do Tesouro (#116): só com o Mapa do Tesouro completo, nunca por dinheiro.
	_check(not gs.is_map_unlocked("ilha_tesouro"), "ilha bloqueada sem fragmentos")
	_check(gs.get_map_unlock_block_reason("ilha_tesouro").contains("Mapa do Tesouro"), "ilha: motivo é o mapa: %s" % gs.get_map_unlock_block_reason("ilha_tesouro"))
	var island_snap: Dictionary = gs.get_snapshot()
	island_snap["map_fragments"] = Array(GameState.MAP_FRAGMENT_IDS)
	gs.apply_snapshot(island_snap)
	_check(gs.is_map_unlocked("ilha_tesouro"), "ilha aberta com o mapa completo")
	island_snap["map_fragments"] = []
	gs.apply_snapshot(island_snap)
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
	_check(not geleira["unlocked"] and not geleira["playable"] and geleira["unlock_cost"] == _map("geleira").unlock_cost, "status geleira bloqueada: %s" % str(geleira))
	_check(geleira["required_boss_id"] == "ancient_guardian" and geleira["reason"] == "Vença o chefe Guardião Ancestral (Ruínas) para liberar.", "geleira exige Guardião Ancestral: %s" % str(geleira["reason"]))
	var cratera: Dictionary = sm.get_map_status("cratera")
	_check(cratera["required_boss_id"] == "frozen_mammoth" and cratera["required_boss_name"] == "Mamute Congelado" and cratera["unlock_cost"] == _map("cratera").unlock_cost, "cratera exige Mamute Congelado: %s" % str(cratera))

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

	result = await _unlock(gs, "campo")
	_check(result.get("success", true) == false and result.get("message", "") == "Saldo insuficiente para desbloquear %s (%s)." % [campo_data.display_name, MoneyFormat.money(campo_data.unlock_cost)], "desbloqueio sem saldo falha: %s" % str(result.get("message", "")))

	gs.load_snapshot({"team_money": campo_data.unlock_cost + 500})
	result = await _unlock(gs, "campo")
	_check(result.get("success", false) == true and result.get("message", "") == "Campo Antigo desbloqueado!", "desbloqueio campo ok: %s" % str(result.get("message", "")))
	_check(gs.team_money == 500, "dinheiro 500: %d" % gs.team_money)
	_check(gs.is_map_unlocked("campo"), "campo desbloqueado")

	# O Campo pede o detector do campo.tres (#46: Nv.2, upgrade nível 1).
	campo = sm.get_map_status("campo")
	_check(campo_data.required_detector_level > 1, "campo exige detector acima do inicial: %d" % campo_data.required_detector_level)
	_check(campo["unlocked"] and not campo["playable"] and campo["reason"] == "Requer detector nível %d." % campo_data.required_detector_level, "status campo pede o detector: %s" % str(campo["reason"]))
	_check(not sm.can_start_map("campo"), "can_start_map campo false com detector Nv.1")
	gs.load_snapshot({"upgrade_levels": {"detector": campo_data.required_detector_level - 1}})
	campo = sm.get_map_status("campo")
	_check(campo["unlocked"] and campo["playable"] and campo["reason"] == "", "status campo jogável: %s" % str(campo["reason"]))
	_check(sm.can_start_map("campo"), "can_start_map campo true com o detector exigido")

	result = await _unlock(gs, "campo")
	_check(result.get("success", true) == false and result.get("message", "") == "Campo Antigo já está desbloqueado.", "desbloqueio repetido falha: %s" % str(result.get("message", "")))
	_check(gs.team_money == 500, "dinheiro continua 500: %d" % gs.team_money)

	result = await _unlock(gs, "../catalog/alianca_ouro")
	_check(result.get("success", true) == false, "desbloqueio malicioso falha: %s" % str(result.get("message", "")))
	_check(gs.team_money == 500, "dinheiro continua 500 após malicioso: %d" % gs.team_money)

	SaveManager.instance.save_game()
	var saved: Dictionary = SaveManager.instance.load_from_file()
	_check(int(saved.get("version", 0)) == 5, "save versão 5: %s" % str(saved.get("version")))
	_check(saved.get("unlocked_maps", []) == ["campo"], "save unlocked_maps: %s" % str(saved.get("unlocked_maps")))
	_check(saved.get("defeated_bosses", []) == ["king_crab"], "save defeated_bosses: %s" % str(saved.get("defeated_bosses")))

	# Ruínas têm cena (#42): desbloqueada, mas pede o detector do ruinas.tres.
	var ruinas_data: MapData = _map("ruinas")
	await _report_boss(gs, "giant_mole")
	gs.load_snapshot({"team_money": ruinas_data.unlock_cost})
	result = await _unlock(gs, "ruinas")
	_check(result.get("success", false) == true and result.get("message", "") == "Ruínas desbloqueado!", "desbloqueio ruinas ok: %s" % str(result.get("message", "")))
	var ruinas: Dictionary = sm.get_map_status("ruinas")
	_check(ruinas["unlocked"] and ruinas["has_scene"] and not ruinas["playable"], "status ruinas desbloqueada e com cena: %s" % str(ruinas))
	_check(ruinas["reason"] == "Requer detector nível %d." % ruinas_data.required_detector_level, "status ruinas pede o detector: %s" % str(ruinas["reason"]))
	_check(not sm.can_start_map("ruinas"), "can_start_map ruinas false sem o detector")

	# #49: Geleira paga com o detector exigido; com world/map_geleira.tscn (#45) fica jogável.
	var geleira_data: MapData = _map("geleira")
	await _report_boss(gs, "ancient_guardian")
	gs.load_snapshot({"team_money": geleira_data.unlock_cost, "upgrade_levels": {"detector": geleira_data.required_detector_level - 1}})
	result = await _unlock(gs, "geleira")
	_check(result.get("success", false) == true and result.get("message", "") == "Geleira Eterna desbloqueado!", "desbloqueio geleira ok: %s" % str(result.get("message", "")))
	geleira = sm.get_map_status("geleira")
	_check(geleira["unlocked"] and geleira["has_scene"] and geleira["playable"], "status geleira desbloqueada e jogável: %s" % str(geleira))
	_check(geleira["reason"] == "", "status geleira sem motivo: %s" % str(geleira["reason"]))
	_check(sm.can_start_map("geleira"), "can_start_map geleira true com o detector exigido")

	gs.reset_state()
	gs.load_snapshot({"team_money": 300, "current_day": 4, "discovered_items": [], "upgrade_levels": {"detector": 1}})
	_check(gs.unlocked_maps.is_empty() and gs.defeated_bosses.is_empty(), "save v2 carrega listas vazias")
	_check(gs.is_map_unlocked("praia"), "praia continua desbloqueada")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
