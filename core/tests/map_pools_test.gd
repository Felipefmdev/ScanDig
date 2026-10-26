## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/map_pools_test.gd
## Pools de itens dos mapas (#26): catalogo, medias alvo e dados historicos de equipamento.
extends SceneTree

const MAP_IDS: Array[String] = ["praia", "campo", "ruinas", "geleira", "cratera"]
const CATALOG_DIR: String = "res://items/catalog/"
## Itens de missão, relíquias e easter eggs da Praia (#39/#40, Dev A).
const PRAIA_SIDE_ITEMS: Array[String] = ["concha_dourada", "bussola_naufragio", "medalhao_sereia",
	"mapa_na_garrafa", "olho_do_polvo", "moeda_chocolate"]
## Recompensa da missão, relíquias e troféus do Campo Antigo (#45/#41): fora de pool também.
const CAMPO_SIDE_ITEMS: Array[String] = ["sino_bronze", "anel_do_poco", "moeda_celta",
	"fibula_romana", "pena_corvo_rei", "lanterna_espantalho"]
## Pool da Geleira Eterna (#49): tema gelo / expedição perdida.
const GELEIRA_ITEMS: Array[String] = ["crampon_enferrujado", "lanterna_expedicao",
	"cronometro_explorador", "medalha_polar", "bussola_congelada"]

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

## Arquivos .tres em CATALOG_DIR (.remap das builds exportadas conta como o .tres).
func _count_catalog_files() -> int:
	var count: int = 0
	for file_name: String in DirAccess.get_files_at(CATALOG_DIR):
		if file_name.trim_suffix(".remap").ends_with(".tres"):
			count += 1
	return count

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

	# Balanceamento historico (#64): valores MapData preservados, sem autorizar compra/acesso.
	# Media do pool sobe; preco antigo e nivel de eficiencia seguem monotonicidade.
	var previous: MapData = null
	for map_id: String in SessionManager.MAP_ORDER:
		var map_data: MapData = _load_map(map_id)
		if map_data == null:
			continue
		if previous != null:
			_check(_pool_average(previous) < _pool_average(map_data), "média %s < %s: %.1f < %.1f" % [previous.id, map_id, _pool_average(previous), _pool_average(map_data)])
			_check(previous.unlock_cost <= map_data.unlock_cost, "desbloqueio %s <= %s: %d <= %d" % [previous.id, map_id, previous.unlock_cost, map_data.unlock_cost])
			_check(previous.required_detector_level <= map_data.required_detector_level, "detector %s <= %s: %d <= %d" % [previous.id, map_id, previous.required_detector_level, map_data.required_detector_level])
			_check(map_data.unlock_cost > 0, "%s conserva preco historico positivo: %d" % [map_id, map_data.unlock_cost])
		previous = map_data
	var geleira: MapData = _load_map("geleira")
	_check(geleira != null and geleira.id == "geleira" and geleira.display_name == "Geleira Eterna", "geleira carregada")
	for item_id: String in GELEIRA_ITEMS:
		_check(ResourceLoader.exists(CATALOG_DIR + item_id + ".tres"), "%s no catálogo (#49)" % item_id)
	# Troféus de chefe ficam fora de qualquer item_pool.
	var trophy_in_pool: bool = false
	for map_id: String in MAP_IDS:
		var map_data: MapData = _load_map(map_id)
		for item: ItemData in (map_data.item_pool if map_data != null else []):
			trophy_in_pool = trophy_in_pool or (item != null and item.id in ["coroa_caranguejo_rei", "garra_toupeira", "olho_do_polvo", "pena_corvo_rei", "lanterna_espantalho"])
	_check(not trophy_in_pool, "troféus fora dos pools")
	_check(ResourceLoader.exists(CATALOG_DIR + "garra_toupeira.tres"), "garra_toupeira no catálogo")
	for item_id: String in PRAIA_SIDE_ITEMS:
		_check(ResourceLoader.exists(CATALOG_DIR + item_id + ".tres"), "%s no catálogo (#39/#40)" % item_id)
	for item_id: String in CAMPO_SIDE_ITEMS:
		_check(ResourceLoader.exists(CATALOG_DIR + item_id + ".tres"), "%s no catálogo (#45/#41)" % item_id)
	# Conta o catálogo aqui, sem o GameState, para não depender de um número fixo.
	var catalog_files: int = _count_catalog_files()
	_check(gs.get_total_catalog_items() == catalog_files, "catálogo: GameState %d, arquivos %d" % [gs.get_total_catalog_items(), catalog_files])
	_check(catalog_files >= 44, "catálogo com pelo menos 44 itens: %d" % catalog_files)

	# Recibos permanentes removem gate de detector, sem alterar os niveis no MapData.
	gs.load_snapshot({"team_money": 0, "current_day": 1, "discovered_items": [], "upgrade_levels": {"detector": 2}, "unlocked_maps": ["campo", "ruinas", "geleira"], "defeated_bosses": ["king_crab", "giant_mole", "ancient_guardian"]})
	await _wait(3)
	_check(gs.equipped_detector_level == 3, "radar Nv.3: %d" % gs.equipped_detector_level)
	for map_id: String in ["ruinas", "geleira"]:
		var map_data: MapData = _load_map(map_id)
		var map_status: Dictionary = sm.get_map_status(map_id)
		_check(map_data.required_detector_level > 3, "%s exige mais que o radar Nv.3: %d" % [map_id, map_data.required_detector_level])
		_check(map_status["unlocked"] and map_status["has_scene"], "%s desbloqueada e com cena: %s" % [map_id, str(map_status)])
		_check(map_status["reason"] == "" and map_status["playable"], "%s sem gate de detector: %s" % [map_id, str(map_status)])
		_check(sm.can_start_map(map_id), "can_start_map %s true com recibo e radar Nv.3" % map_id)

	# Todos os mapas reais já têm cena: o "Em breve." usa um mapa falso, gravado só durante o teste.
	await _check_coming_soon(gs, sm)

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)


const FAKE_MAP_ID: String = "teste_em_breve"
const FAKE_MAP_PATH: String = "res://items/maps/teste_em_breve.tres"


func _remove_fake_map() -> void:
	if FileAccess.file_exists(FAKE_MAP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FAKE_MAP_PATH))


## Adapter de consulta estritamente sintetico para manter a cobertura de cena ausente.
## O GameState real continua rejeitando recibo de ID fora da allowlist de rotas.
class MissingSceneState extends GameState:
	func is_map_unlocked(map_id: String) -> bool:
		return true if map_id == "teste_em_breve" else super.is_map_unlocked(map_id)


## Nao altera qualquer cena real; o recurso falso e removido ao terminar.
func _check_coming_soon(gs: GameState, sm: SessionManager) -> void:
	_remove_fake_map()
	var fake: MapData = MapData.new()
	fake.id = FAKE_MAP_ID
	fake.display_name = "Mapa de Teste"
	fake.unlock_cost = 100
	fake.required_detector_level = 9
	_check(ResourceSaver.save(fake, FAKE_MAP_PATH) == OK, "mapa falso gravado")
	_check(not ResourceLoader.exists(SessionManager.MAP_SCENE_FORMAT % FAKE_MAP_ID), "mapa falso sem cena")
	gs.load_snapshot({"team_money": 0, "unlocked_maps": [], "defeated_bosses": []})
	await _wait(2)
	var locked: Dictionary = sm.get_map_status(FAKE_MAP_ID)
	_check(not locked["unlocked"] and not locked["has_scene"] and not locked["playable"], "ID sintetico bloqueado e sem cena")
	gs.load_snapshot({"unlocked_maps": [FAKE_MAP_ID]})
	_check(not gs.is_map_unlocked(FAKE_MAP_ID), "recibo forjado fora das rotas nao abre mapa real")
	# Isola apenas a premissa unlocked da consulta; can_start_map/get_map_status
	# reais ainda devem verificar ausencia de cena, sem gate de detector.
	var query_state: MissingSceneState = MissingSceneState.new()
	GameState.instance = query_state
	var soon: Dictionary = sm.get_map_status(FAKE_MAP_ID)
	var playable: bool = sm.can_start_map(FAKE_MAP_ID)
	GameState.instance = gs
	query_state.free()
	_check(soon["unlocked"] and not soon["has_scene"] and not soon["playable"], "consulta sintetica desbloqueada e sem cena")
	_check(soon["reason"] == "Em breve.", "cena ausente mantem motivo Em breve")
	_check(not playable, "can_start_map sem cena permanece false")
	_remove_fake_map()
	_check(not FileAccess.file_exists(FAKE_MAP_PATH), "mapa falso apagado")
