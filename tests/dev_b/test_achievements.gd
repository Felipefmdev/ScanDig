extends GutTest

## Conquistas e estatísticas (#141): dados do JSON, desbloqueio por evento (no host), save com
## migração v5 -> v6, snapshot no cliente, toast, aba Conquistas navegável e a tela de vitória.
## Saves em user://test_saves/devb_achievements.

const DIR: String = "user://test_saves/devb_achievements"
const BASE_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const SCAN: GDScript = preload("res://tools/i18n/i18n_scan.gd")

var _orig_path: String = ""
var _unlocked: Array[String] = []


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(DIR + "/scandig_save.json")
	GameState.instance.reset_state()
	_unlocked.clear()
	GameState.instance.achievement_unlocked.connect(_on_unlocked)


func after_each() -> void:
	GameState.instance.achievement_unlocked.disconnect(_on_unlocked)
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	TranslationServer.set_locale("pt_BR")
	GameState.instance.reset_state()


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)


func _on_unlocked(id: String) -> void:
	_unlocked.append(id)


func _catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	for file_name: String in DirAccess.get_files_at("res://items/catalog"):
		var clean: String = file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			ids.append(clean.get_basename())
	ids.sort()
	return ids


func _write(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


# --- Dados -----------------------------------------------------------------------

func test_definitions_are_valid_and_translated() -> void:
	var defs: Array[Dictionary] = Achievements.definitions()
	assert_between(defs.size(), 18, 30, "~20 conquistas")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Achievements.DATA_PATH))
	assert_eq(defs.size(), (raw["achievements"] as Array).size(), "nenhuma entrada do JSON foi recusada")
	var rows: Dictionary = SCAN.csv_rows()
	for def: Dictionary in defs:
		assert_true(Achievements.is_valid_id(str(def["id"])), "id snake_case: %s" % def["id"])
		assert_true(UiIcons.has_icon(str(def["icon"])), "ícone existe: %s" % def["icon"])
		for key: String in ["name", "desc"]:
			var text: String = str(def[key])
			assert_true(rows.has(text), "CSV tem '%s'" % text)
	TranslationServer.set_locale("en")
	assert_eq(tr("Primeira peça"), "First find")
	assert_eq(tr("Vença o chefe final."), "Defeat the final boss.")


func test_final_boss_follows_constant() -> void:
	var def: Dictionary = Achievements.get_definition("final_boss")
	assert_eq(str(def["boss"]), Achievements.FINAL_BOSS, "o JSON não fixa o id do chefe final")
	assert_false(Achievements.is_met(def, {"defeated_bosses": ["king_crab"]}))
	assert_true(Achievements.is_met(def, {"defeated_bosses": [GameState.FINAL_BOSS_ID]}))


func test_bad_entries_are_rejected() -> void:
	var text: String = JSON.stringify({"achievements": [
		{"id": "ok_one", "icon": "coin", "type": "stat", "stat": "digs", "target": 3, "name": "A", "desc": "B"},
		{"id": "ok_one", "icon": "coin", "type": "stat", "stat": "digs", "target": 3, "name": "A", "desc": "B"},
		{"id": "Bad-Id", "icon": "coin", "type": "stat", "stat": "digs", "target": 3, "name": "A", "desc": "B"},
		{"id": "no_type", "icon": "coin", "type": "nope", "name": "A", "desc": "B"},
		{"id": "no_stat", "icon": "coin", "type": "stat", "stat": "nope", "target": 1, "name": "A", "desc": "B"},
		{"id": "no_boss", "icon": "coin", "type": "boss", "boss": "nope", "name": "A", "desc": "B"},
	]})
	var defs: Array[Dictionary] = Achievements.parse_definitions(text)
	assert_eq(defs.size(), 1, "só a primeira entrada válida fica")
	assert_eq(str(defs[0]["id"]), "ok_one")


# --- Desbloqueio por evento (host) ------------------------------------------------

func test_dig_reveal_counts_and_unlocks_first_find() -> void:
	var spot: BuriedSpot = BuriedSpot.new()
	spot.item = load("res://items/catalog/%s.tres" % _catalog_ids()[0]) as ItemData
	spot.free_on_reveal = false
	add_child_autofree(spot)
	await wait_frames(1)
	var layers: int = spot.dirt_layers
	for i: int in layers:
		spot.dig(true)
	var gs: GameState = GameState.instance
	assert_eq(gs.get_stat("digs"), layers, "uma pazada por camada")
	assert_eq(gs.get_stat("items_found"), 1)
	assert_eq(gs.get_stat("dig_depth_cm"), spot.item.depth_cm)
	assert_true(gs.achievements.has("first_find"))
	assert_eq(_unlocked, ["first_find"] as Array[String], "um sinal por conquista nova")


func test_sell_donate_and_quest_stats() -> void:
	var gs: GameState = GameState.instance
	var item_id: String = _catalog_ids()[0]
	gs.request_donate_item(item_id)
	var reward: int = gs.team_money - 100
	gs.request_sell_item(item_id, 10)
	gs.request_complete_quest("ze_anzol")
	assert_eq(gs.get_stat("items_donated"), 1)
	assert_eq(gs.get_stat("items_sold"), 1)
	assert_eq(gs.get_stat("money_earned"), reward + 10 + int(GameState.QUESTS["ze_anzol"]["reward"]))


func test_creature_kills_count_every_kill() -> void:
	var gs: GameState = GameState.instance
	for i: int in 3:
		gs.report_creature("crab")
	assert_eq(gs.get_stat("creatures_defeated"), 3)
	assert_eq(gs.seen_creatures, ["crab"] as Array[String])


func test_bosses_unlock_by_event() -> void:
	var gs: GameState = GameState.instance
	gs.request_report_boss_defeated("king_crab")
	assert_true(gs.achievements.has("boss_king_crab"))
	assert_false(gs.achievements.has("final_boss"))
	gs.request_report_boss_defeated(GameState.FINAL_BOSS_ID)
	assert_true(gs.achievements.has("final_boss"), "chefe final = FINAL_BOSS_ID")
	assert_false(gs.achievements.has("all_bosses"))
	for boss_id: String in GameState.all_boss_ids():
		gs.request_report_boss_defeated(boss_id)
	assert_true(gs.achievements.has("all_bosses"))


func test_museum_percent() -> void:
	var gs: GameState = GameState.instance
	var ids: Array[String] = _catalog_ids()
	var quarter: int = ceili(ids.size() * 0.25)
	for i: int in quarter - 1:
		gs.request_donate_item(ids[i])
	assert_false(gs.achievements.has("museum_25"))
	gs.request_donate_item(ids[quarter - 1])
	assert_true(gs.achievements.has("museum_25"))
	assert_false(gs.achievements.has("museum_50"))
	var p: Vector2i = Achievements.progress(Achievements.get_definition("museum_50"), gs.get_snapshot())
	assert_eq(p, Vector2i(quarter, ceili(ids.size() * 0.5)))


func test_expedition_end_stats() -> void:
	var tracker: Achievements = Achievements.instance
	tracker._on_expedition_started("praia")
	tracker._on_item_revealed(load("res://items/catalog/%s.tres" % _catalog_ids()[0]) as ItemData, 10, 1.0)
	tracker.record_expedition_end(true)
	var gs: GameState = GameState.instance
	assert_eq(gs.get_stat("expeditions"), 1)
	assert_eq(gs.get_stat("night_expeditions"), 1)
	assert_eq(gs.get_stat("flawless_expeditions"), 1)
	assert_true(gs.achievements.has("first_night"))
	assert_true(gs.achievements.has("flawless_expedition"))
	# Com dano no host, ou sem peça nenhuma, não é "sem um arranhão".
	tracker._on_expedition_started("praia")
	tracker._on_item_revealed(load("res://items/catalog/%s.tres" % _catalog_ids()[0]) as ItemData, 10, 1.0)
	tracker._expedition_hurt = true
	tracker.record_expedition_end(false)
	tracker._on_expedition_started("praia")
	tracker.record_expedition_end(false)
	assert_eq(gs.get_stat("expeditions"), 3)
	assert_eq(gs.get_stat("night_expeditions"), 1)
	assert_eq(gs.get_stat("flawless_expeditions"), 1)


func test_stats_without_unlock_wait_for_next_snapshot() -> void:
	var gs: GameState = GameState.instance
	var synced: Array[int] = [0]
	var count: Callable = func() -> void: synced[0] += 1
	gs.state_synced.connect(count)
	gs.add_stats({"digs": 1})
	assert_eq(synced[0], 0, "pazada sem conquista nova não manda snapshot")
	gs.add_stats({"items_found": 1})
	assert_eq(synced[0], 1, "conquista nova: snapshot na hora")
	gs.state_synced.disconnect(count)
	assert_eq(int(gs.get_snapshot()["stats"]["digs"]), 1, "o número segue no snapshot")


# --- Save -------------------------------------------------------------------------

func test_save_and_load_keep_stats_and_achievements_silently() -> void:
	var gs: GameState = GameState.instance
	var save: SaveManager = SaveManager.instance
	gs.add_stats({"items_found": 1, "digs": 7})
	assert_eq(save.save_game(), OK)
	var data: Dictionary = _read(save.save_path)
	assert_eq(int(data["version"]), 6)
	assert_eq(int(data["stats"]["digs"]), 7)
	assert_eq(data["achievements"], ["first_find"])
	gs.reset_state()
	_unlocked.clear()
	assert_eq(save.load_game(), OK)
	assert_eq(gs.get_stat("digs"), 7)
	assert_eq(gs.achievements, ["first_find"] as Array[String])
	assert_eq(_unlocked, [] as Array[String], "carregar não vira aviso")


func test_v5_save_migrates_and_awards_silently() -> void:
	var ids: Array[String] = _catalog_ids()
	var donated: Array = ids.slice(0, ceili(ids.size() * 0.25))
	_write(SaveManager.instance.save_path, {"version": 5, "saved_at": 1760000000, "team_money": 500,
		"current_day": 4, "discovered_items": donated, "defeated_bosses": ["king_crab"]})
	assert_eq(SaveManager.instance.load_game(), OK)
	var gs: GameState = GameState.instance
	assert_eq(gs.stats, {}, "v5 começa sem estatísticas")
	assert_true(gs.achievements.has("museum_25"), "o progresso do save já conta")
	assert_true(gs.achievements.has("boss_king_crab"))
	assert_eq(_unlocked, [] as Array[String], "sem aviso para o que veio do save")


func test_bad_stats_are_dropped_not_fatal() -> void:
	var upgraded: Dictionary = SaveManager.instance._upgrade_save_data({"version": 6, "team_money": 1,
		"stats": {"digs": 5.0, "items_found": "x", "money_earned": -3, "creatures_defeated": null}, "achievements": ["first_find", 3]})
	assert_eq(upgraded["stats"], {"digs": 5, "money_earned": 0})
	assert_eq(upgraded["achievements"], ["first_find"])
	var broken: Dictionary = SaveManager.instance._upgrade_save_data({"version": 6, "team_money": 1, "stats": "lixo"})
	assert_eq(broken["stats"], {})
	assert_eq(broken["achievements"], [])


# --- Cliente ----------------------------------------------------------------------

## O cliente só aplica o snapshot do host (o _receive_snapshot de sempre): sem RPC novo.
func test_client_sees_host_snapshot() -> void:
	var host: GameState = GameState.instance
	host.add_stats({"items_found": 1, "digs": 12})
	var client: GameState = GameState.new()
	add_child_autofree(client)
	var got: Array[String] = []
	client.achievement_unlocked.connect(func(id: String) -> void: got.append(id))
	client._receive_snapshot(host.get_snapshot())
	assert_eq(client.get_stat("digs"), 12)
	assert_eq(client.achievements, ["first_find"] as Array[String])
	assert_eq(got, ["first_find"] as Array[String], "o cliente também avisa")
	# Nenhuma função nova de conquistas/estatísticas é @rpc.
	var lines: PackedStringArray = (GameState as Script).source_code.split("
")
	for i: int in lines.size() - 1:
		if lines[i].begins_with("@rpc"):
			var next: String = lines[i + 1]
			assert_false(next.contains("achievement") or next.contains("stats"), "não é RPC: %s" % next)


# --- Telas ------------------------------------------------------------------------

func test_toast_on_unlock() -> void:
	var ui: SessionUI = SessionUI.instance
	ui._clear_toasts()
	GameState.instance.add_stats({"items_found": 1})
	assert_true(ui.toast_panel.visible, "toast também fora da expedição")
	assert_eq(ui.toast_label.text, "🏆 Conquista desbloqueada: Primeira peça")
	ui._clear_toasts()


func test_tab_lists_all_with_locked_gray_and_navigates() -> void:
	GameState.instance.add_stats({"items_found": 1, "digs": 250})
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await wait_frames(3)
	var tab: AchievementsTab = base.achievements_tab
	assert_not_null(tab)
	assert_eq(tab.get_row_count(), Achievements.definitions().size())
	assert_eq(tab.header_label.text, "Conquistas: 1/%d" % Achievements.definitions().size())
	assert_true(tab.is_row_unlocked("first_find"))
	assert_false(tab.is_row_unlocked("digs_1000"))
	assert_string_contains(tab.get_row_text("first_find"), "✔ Primeira peça")
	assert_string_contains(tab.get_row_text("digs_1000"), "250 / 1.000")
	assert_eq((tab.get_row("first_find").find_child("Card", true, false) as Control).modulate, Color.WHITE)
	assert_ne((tab.get_row("digs_1000").find_child("Card", true, false) as Control).modulate, Color.WHITE, "bloqueada em cinza")
	base.tab_container.current_tab = tab.get_parent().get_index()
	await wait_frames(2)
	for device: String in [UiNavAudit.KEYBOARD, UiNavAudit.PAD]:
		tab.get_row("first_find").grab_focus()
		var result: Dictionary = await UiNavAudit.audit(tab, device, true)
		assert_eq((result["missing"] as Array), [], "%s alcança todas as linhas" % device)
		assert_eq((result["no_focus_style"] as Array), [], "%s: borda de foco" % device)
	# Estado novo do host chega e a aba se refaz; em inglês também.
	GameState.instance.add_stats({"digs": 750})
	assert_true(tab.is_row_unlocked("digs_1000"))
	TranslationServer.set_locale("en")
	await wait_frames(2)
	assert_string_contains(tab.get_row_text("digs_1000"), "Iron arm")


func test_victory_shows_campaign_stats() -> void:
	var gs: GameState = GameState.instance
	gs.add_stats({"expeditions": 4, "items_found": 9, "money_earned": 12345, "dig_depth_cm": 2550})
	var screen: VictoryScreen = VictoryScreen.instance
	screen.refresh()
	assert_eq((screen.campaign_values["expeditions"] as Label).text, "4")
	assert_eq((screen.campaign_values["items_found"] as Label).text, "9")
	assert_eq((screen.campaign_values["money_earned"] as Label).text, UiFormat.money(12345))
	assert_eq((screen.campaign_values["dig_depth_cm"] as Label).text, "25 m")
	assert_eq((screen.campaign_values["achievements"] as Label).text, "1 / %d" % Achievements.ids().size())
