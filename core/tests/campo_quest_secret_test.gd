# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/campo_quest_secret_test.gd
# Campo Antigo (#45/#41): missão da Lurdes, 6 segredos, chefes extras e os 6 itens de museu.
# Save isolado em user://test_saves/campo_quest_secret_test. Pedido de cliente: boss_authority_test.
extends SceneTree

const CAMPO_SECRETS: Array[String] = ["campo_reliquia_poco", "campo_reliquia_fardo", "campo_reliquia_muro",
	"campo_espantalho", "campo_ovo_circulo", "campo_ovo_ovelha"]
## id -> base_value do catálogo.
const CAMPO_ITEMS: Dictionary = {"sino_bronze": 700, "anel_do_poco": 600, "moeda_celta": 480,
	"fibula_romana": 520, "pena_corvo_rei": 650, "lanterna_espantalho": 900}
const CATALOG_DIR: String = "res://items/catalog/"
## Piso do catálogo (#42: +6 das Ruínas). O total exato vem dos arquivos, para não quebrar a cada item novo.
const CATALOG_MIN: int = 44

var _fails: int = 0
var _quest_signals: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

## Arquivos .tres em CATALOG_DIR (.remap das builds exportadas conta como o .tres).
func _count_catalog_files() -> int:
	var count: int = 0
	for file_name: String in DirAccess.get_files_at(CATALOG_DIR):
		if file_name.trim_suffix(".remap").ends_with(".tres"):
			count += 1
	return count

func _on_quest_completed(quest_id: String, reward: int) -> void:
	_quest_signals.append("%s:%d" % [quest_id, reward])

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	SaveManager.instance.use_test_save_dir("campo_quest_secret_test")
	var gs: GameState = GameState.instance
	var save: SaveManager = SaveManager.instance
	_check(gs != null and save != null, "GameState e SaveManager presentes")
	if gs == null or save == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	gs.quest_completed.connect(_on_quest_completed)
	gs.load_snapshot({"team_money": 1000, "current_day": 3, "discovered_items": [], "upgrade_levels": {},
		"unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"], "completed_quests": [], "found_secrets": []})
	_quest_signals.clear()

	# Missão da Lurdes: 1.800 uma vez só.
	_check(str(GameState.QUESTS.get("lurdes_chaves", {}).get("name", "")) == "Os corvos levaram as chaves", "nome da missão")
	gs.request_complete_quest("lurdes_chaves")
	_check(gs.is_quest_completed("lurdes_chaves") and gs.team_money == 2800, "lurdes_chaves pagou 1800: %d" % gs.team_money)
	_check(_quest_signals == ["lurdes_chaves:1800"], "quest_completed com 1800: %s" % str(_quest_signals))
	gs.request_complete_quest("lurdes_chaves")
	_check(gs.team_money == 2800 and _quest_signals.size() == 1, "segunda tentativa não paga: %d" % gs.team_money)
	gs.request_complete_quest("lurdes_chave")
	_check(gs.completed_quests == ["lurdes_chaves"], "missão desconhecida recusada: %s" % str(gs.completed_quests))

	# Segredos do Campo: registram, sem dinheiro.
	for secret_id: String in CAMPO_SECRETS:
		gs.request_report_secret(secret_id)
	gs.request_report_secret("campo_reliquia_poco")
	gs.request_report_secret("campo_segredo_falso")
	_check(gs.found_secrets == CAMPO_SECRETS, "6 segredos do Campo registrados: %s" % str(gs.found_secrets))
	_check(gs.team_money == 2800, "segredos não pagam: %d" % gs.team_money)

	# Chefes extras: registrados sem desbloquear mapa.
	gs.request_report_boss_defeated("crow_king")
	gs.request_report_boss_defeated("scarecrow")
	gs.request_report_boss_defeated("corvo_falso")
	_check(gs.defeated_bosses == ["king_crab", "crow_king", "scarecrow"], "crow_king e scarecrow registrados: %s" % str(gs.defeated_bosses))
	_check(gs.unlocked_maps == ["campo"], "chefes extras não desbloqueiam mapa: %s" % str(gs.unlocked_maps))
	_check(gs.get_map_unlock_block_reason("ruinas") == "Vença o chefe Toupeira Gigante (Campo Antigo) para liberar.", "ruínas continua pedindo a Toupeira: %s" % gs.get_map_unlock_block_reason("ruinas"))

	# Museu: os 6 itens viram descoberta com 50% do valor base; o total do catálogo é o número de arquivos.
	var catalog_files: int = _count_catalog_files()
	_check(gs.get_total_catalog_items() == catalog_files, "max_items = arquivos do catálogo: %d / %d" % [gs.get_total_catalog_items(), catalog_files])
	_check(catalog_files >= CATALOG_MIN, "catálogo com pelo menos %d itens: %d" % [CATALOG_MIN, catalog_files])
	var money_before: int = gs.team_money
	var expected_rewards: int = 0
	for item_id: String in CAMPO_ITEMS:
		gs.request_donate_item(item_id)
		expected_rewards += int(round(float(int(CAMPO_ITEMS[item_id])) * GameState.MUSEUM_REWARD_RATIO))
	for item_id: String in CAMPO_ITEMS:
		_check(gs.discovered_items.has(item_id), "%s no museu" % item_id)
	_check(gs.team_money == money_before + expected_rewards, "recompensas de 50%%: +%d (esperado +%d)" % [gs.team_money - money_before, expected_rewards])
	gs.request_donate_item("sino_bronze")
	_check(gs.team_money == money_before + expected_rewards, "doação repetida não paga")

	# Save -> load mantém tudo.
	var money_saved: int = gs.team_money
	_check(save.save_game() == OK, "save_game OK")
	_check(int(save.load_from_file().get("version", 0)) == SaveManager.SAVE_VERSION, "save continua na versão atual")
	gs.reset_state()
	_check(gs.completed_quests.is_empty() and gs.found_secrets.is_empty(), "reset limpa")
	_check(save.load_game() == OK, "load_game OK")
	_check(gs.is_quest_completed("lurdes_chaves") and gs.found_secrets == CAMPO_SECRETS, "missão e segredos voltam: %s / %s" % [str(gs.completed_quests), str(gs.found_secrets)])
	_check(gs.is_boss_defeated("crow_king") and gs.is_boss_defeated("scarecrow"), "chefes extras voltam: %s" % str(gs.defeated_bosses))
	var all_items: bool = true
	for item_id: String in CAMPO_ITEMS:
		all_items = all_items and gs.discovered_items.has(item_id)
	_check(all_items and gs.team_money == money_saved, "museu e dinheiro voltam: %s / %d" % [str(gs.discovered_items), gs.team_money])
	gs.request_complete_quest("lurdes_chaves")
	_check(gs.team_money == money_saved, "missão do save não paga de novo: %d" % gs.team_money)

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
