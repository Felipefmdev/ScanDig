extends GutTest

## #112 (épico #103): fragmentos do Mapa do Tesouro. O host dá-os quando a origem se cumpre
## (missão, chefe, segredo, escavação profunda rara); vão no snapshot e no save; a base mostra o
## pergaminho a montar-se e as dicas do que falta.

const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")

var gs: GameState
var _saved: Dictionary


func before_each() -> void:
	gs = GameState.instance
	_saved = gs.get_snapshot()
	gs.map_fragments.clear()
	gs.completed_quests.clear()
	gs.found_secrets.clear()


func after_each() -> void:
	gs.apply_snapshot(_saved)
	gs.map_fragments.assign(Array(_saved.get("map_fragments", [])))


func test_catalog_has_8_fragments_on_a_4x2_scroll() -> void:
	assert_eq(GameState.MAP_FRAGMENT_IDS.size(), 8)
	var cells: Dictionary = {}
	var maps: Dictionary = {}
	for id: String in GameState.MAP_FRAGMENT_IDS:
		var e: Dictionary = GameState.MAP_FRAGMENTS[id]
		cells[e["piece"]] = true
		maps[e["map"]] = int(maps.get(e["map"], 0)) + 1
		assert_false(str(e["hint"]).is_empty(), "%s tem dica" % id)
		var source: PackedStringArray = str(e["source"]).split(":")
		match source[0]:
			"quest":
				assert_true(GameState.QUESTS.has(source[1]), "%s: missão existe" % id)
			"secret":
				assert_true(GameState.SECRETS.has(source[1]), "%s: segredo existe" % id)
			"boss", "dig":
				pass
			_:
				fail_test("%s: origem desconhecida %s" % [id, e["source"]])
	assert_eq(cells.size(), 8, "Uma peça por célula do pergaminho")
	assert_eq(maps.size(), 5, "Os 5 sítios têm fragmentos")
	for m: String in maps:
		assert_between(int(maps[m]), 1, 2, "1-2 fragmentos em %s" % m)


func test_finishing_a_mission_awards_its_fragment_once() -> void:
	watch_signals(gs)
	gs._host_complete_quest("ze_anzol")
	assert_true(gs.has_map_fragment("praia_frag_1"))
	assert_signal_emitted_with_parameters(gs, "map_fragment_found", ["praia_frag_1"])
	assert_eq(gs.map_fragments.count("praia_frag_1"), 1)


func test_secret_awards_its_fragment() -> void:
	gs._host_report_secret("ruinas_reliquia_parede")
	assert_true(gs.has_map_fragment("ruinas_frag_2"))
	gs._host_report_secret("praia_ovo_pato")
	assert_eq(gs.map_fragments.size(), 1, "Outros segredos não dão fragmento")


func test_dig_fragment_only_by_request_and_only_dig_sources() -> void:
	gs.request_award_fragment("ruinas_frag_1")  # é de missão: não se pede por escavação
	assert_false(gs.has_map_fragment("ruinas_frag_1"))
	gs.request_award_fragment("nao_existe")
	gs.request_award_fragment("geleira_frag_2")
	assert_true(gs.has_map_fragment("geleira_frag_2"))
	assert_eq(gs.map_fragments.size(), 1)


func test_snapshot_and_save_carry_fragments() -> void:
	gs.request_award_fragment("geleira_frag_2")
	assert_eq(gs.get_snapshot()["map_fragments"], ["geleira_frag_2"])
	assert_true(SaveManager.LIST_FIELDS.has("map_fragments"), "Lista guardada no save")
	var data: Dictionary = gs.get_snapshot()
	data["map_fragments"] = ["geleira_frag_2", "lixo"]
	gs.apply_snapshot(data)
	assert_eq(Array(gs.map_fragments), ["geleira_frag_2"], "Ids desconhecidos são ignorados")


func test_old_save_gets_fragments_of_done_sources() -> void:
	var data: Dictionary = gs.get_snapshot()
	data.erase("map_fragments")
	data["completed_quests"] = ["ze_anzol", "vega_sinal"]
	data["defeated_bosses"] = ["king_crab", "giant_mole"]
	gs.load_snapshot(data)
	assert_true(gs.has_map_fragment("praia_frag_1"))
	assert_true(gs.has_map_fragment("cratera_frag_1"))
	assert_true(gs.has_map_fragment("campo_frag_1"))
	assert_false(gs.has_map_fragment("geleira_frag_2"))


func test_all_fragments_complete_the_map() -> void:
	assert_false(gs.has_all_map_fragments())
	var data: Dictionary = gs.get_snapshot()
	data["map_fragments"] = Array(GameState.MAP_FRAGMENT_IDS)
	gs.apply_snapshot(data)
	assert_true(gs.has_all_map_fragments())


func test_scroll_shows_found_pieces() -> void:
	var scroll: TreasureMapScroll = TreasureMapScroll.new()
	add_child_autofree(scroll)
	scroll.size = Vector2(400.0, 200.0)
	scroll.found = ["praia_frag_1"]
	assert_true(scroll.is_cell_found(GameState.MAP_FRAGMENTS["praia_frag_1"]["piece"]))
	assert_false(scroll.is_cell_found(GameState.MAP_FRAGMENTS["cratera_frag_2"]["piece"]))


func test_notice_text() -> void:
	assert_string_contains(FragmentNotice.message_for("ruinas_frag_1", 3, 8), "3/8")
	assert_string_contains(FragmentNotice.message_for("cratera_frag_2", 8, 8), "completo")


func test_base_has_treasure_map_tab_with_hints() -> void:
	var ui: BaseStationUI = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)
	var page: Node = ui.tab_container.get_node_or_null(BaseStationUI.TREASURE_TAB_TITLE)
	assert_not_null(page, "Aba Mapa do Tesouro")
	var count: Label = page.find_child("TreasureCountLabel", true, false) as Label
	var hints: Label = page.find_child("TreasureHintsLabel", true, false) as Label
	assert_string_contains(count.text, "0/8")
	assert_string_contains(hints.text, "Pescador Zé", "Dica do que falta")
	gs._host_complete_quest("ze_anzol")
	assert_string_contains(count.text, "1/8", "Atualiza quando chega um fragmento")
	assert_false(hints.text.contains("Pescador Zé"), "A dica do encontrado desaparece")
	assert_true((page.find_child("TreasureMapScroll", true, false) as TreasureMapScroll).found.has("praia_frag_1"))
