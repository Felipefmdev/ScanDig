## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/map_pools_test.gd
## Pools de itens dos mapas (#26): itens válidos no catálogo, médias alvo e detector mínimo.
extends SceneTree

const MAP_IDS: Array[String] = ["praia", "campo", "ruinas", "cratera"]
const CATALOG_DIR: String = "res://items/catalog/"

var _fails: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _load_map(map_id: String) -> MapData:
	return load("res://items/maps/%s.tres" % map_id) as MapData

func _pool_average(map_data: MapData) -> float:
	if map_data.item_pool.is_empty():
		return 0.0
	var total: int = 0
	for item: ItemData in map_data.item_pool:
		total += item.base_value if item != null else 0
	return float(total) / map_data.item_pool.size()

func _check_pool(map_id: String) -> void:
	var map_data: MapData = _load_map(map_id)
	_check(map_data != null, "%s carregado" % map_id)
	if map_data == null:
		return
	_check(not map_data.item_pool.is_empty(), "%s pool não vazio: %d" % [map_id, map_data.item_pool.size()])
	var all_valid: bool = true
	var has_orbe: bool = false
	for item: ItemData in map_data.item_pool:
		if item == null:
			all_valid = false
			continue
		var in_catalog: bool = item.resource_path == CATALOG_DIR + item.id + ".tres"
		if not in_catalog or item.base_value <= 0:
			all_valid = false
			print("  item inválido em %s: %s (%s, R$ %d)" % [map_id, item.id, item.resource_path, item.base_value])
		has_orbe = has_orbe or item.id == "orbe_vibrante"
	_check(all_valid, "%s: todos os itens existem no catálogo com base_value > 0" % map_id)
	_check(not has_orbe, "%s sem orbe_vibrante (prêmio do chefe final)" % map_id)

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	_check(gs != null and sm != null, "GameState e SessionManager presentes")
	if gs == null or sm == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return

	for map_id: String in MAP_IDS:
		_check_pool(map_id)

	var ruinas: MapData = _load_map("ruinas")
	var cratera: MapData = _load_map("cratera")
	var ruinas_avg: float = _pool_average(ruinas)
	var cratera_avg: float = _pool_average(cratera)
	_check(ruinas_avg >= 400.0 and ruinas_avg <= 520.0, "média ruinas 400–520: %.1f" % ruinas_avg)
	_check(cratera_avg >= 1100.0 and cratera_avg <= 1400.0, "média cratera 1100–1400: %.1f" % cratera_avg)
	_check(ruinas.required_detector_level == 4, "ruinas exige detector Nv.4: %d" % ruinas.required_detector_level)
	_check(cratera.required_detector_level == 5, "cratera exige detector Nv.5: %d" % cratera.required_detector_level)
	_check(gs.get_total_catalog_items() == 20, "catálogo com 20 itens: %d" % gs.get_total_catalog_items())

	# Ordem dos motivos em get_map_status: bloqueado → "Em breve." (sem cena) → detector.
	# Com radar Nv.3 (< 4) e Ruínas desbloqueadas, falta a cena, então o motivo é "Em breve.".
	gs.load_snapshot({"team_money": 0, "current_day": 1, "discovered_items": [], "upgrade_levels": {"detector": 2}, "unlocked_maps": ["campo", "ruinas"], "defeated_bosses": ["king_crab", "giant_mole"]})
	await _wait(3)
	_check(gs.equipped_detector_level == 3, "radar Nv.3: %d" % gs.equipped_detector_level)
	var status: Dictionary = sm.get_map_status("ruinas")
	_check(status["unlocked"] and not status["has_scene"], "ruinas desbloqueada e sem cena: %s" % str(status))
	_check(status["reason"] == "Em breve.", "ruinas reason Em breve antes do detector: %s" % str(status["reason"]))
	_check(not sm.can_start_map("ruinas"), "can_start_map ruinas false")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
