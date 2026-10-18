extends GutTest

## Vitrine 3D do Museu (#111): uma peça por doação, atualiza ao doar, selo nas intactas,
## pedestal nas raras; o snapshot do host e o do cliente montam o mesmo; rare_items vai no
## snapshot e no save, e um save antigo sem o campo ainda carrega.

var museum: MuseumDisplay = null
var _old_save_path: String = ""


func before_all() -> void:
	_old_save_path = SaveManager.instance.save_path


func after_all() -> void:
	SaveManager.instance.set_save_path(_old_save_path)


func before_each() -> void:
	GameState.instance.reset_state()


func after_each() -> void:
	GameState.instance.reset_state()


func _build() -> MuseumDisplay:
	museum = MuseumDisplay.new()
	add_child_autofree(museum)
	return museum


func _all_ids(display: MuseumDisplay) -> Array[String]:
	var ids: Array[String] = []
	for site_id: String in display.get_site_items():
		for id: String in display.get_site_items()[site_id]:
			ids.append(id)
	return ids


func test_every_catalog_item_has_a_site() -> void:
	_build()
	var ids: Array[String] = _all_ids(museum)
	assert_eq(ids.size(), GameState.instance.get_total_catalog_items(), "uma vaga por item do catálogo")
	assert_eq(museum.get_site_items().size(), MuseumDisplay.SITES.size(), "uma seção por sítio")
	assert_eq(museum.get_site_of("lata_enferrujada"), "praia")
	assert_eq(museum.get_site_of("garra_toupeira"), "campo")
	assert_eq(museum.get_site_of(MuseumDisplay.HIGHLIGHT_ID), "ilha_tesouro", "ídolo de ouro é o tesouro da Ilha")
	assert_eq(museum.get_piece_count(), 0, "museu vazio, nenhuma peça")


func test_piece_count_matches_discovered() -> void:
	GameState.instance.load_snapshot({"discovered_items": ["lata_enferrujada", "moeda_antiga", "sino_bronze"]})
	_build()
	assert_eq(museum.get_piece_count(), GameState.instance.discovered_items.size())
	assert_true(museum.has_piece("sino_bronze"))
	assert_false(museum.has_piece("ferradura_velha"))
	assert_eq(museum.get_plaque_text("praia").ends_with("2/%d" % (museum.get_site_items()["praia"] as Array).size()), true, museum.get_plaque_text("praia"))


func test_updates_on_donate_rebuilding_only_the_new_slot() -> void:
	GameState.instance.load_snapshot({"discovered_items": ["lata_enferrujada"]})
	_build()
	var old_piece: Node = museum.get_slot("lata_enferrujada").get_node("Piece")
	GameState.instance.request_report_discovery("chave_enferrujada", 10)
	await wait_frames(2)
	assert_true(museum.has_piece("chave_enferrujada"), "doação aparece na estante")
	assert_eq(museum.get_piece_count(), 2)
	assert_same(museum.get_slot("lata_enferrujada").get_node("Piece"), old_piece, "peça que não mudou fica")
	assert_eq(museum.refresh(), 0, "nada mais a refazer")


func test_seal_on_intact_and_pedestal_on_rare() -> void:
	GameState.instance.load_snapshot({"discovered_items": ["moeda_antiga", "concha_dourada", "idolo_ouro"],
		"intact_items": ["moeda_antiga"], "rare_items": ["concha_dourada", "idolo_ouro"]})
	_build()
	assert_true(museum.has_seal("moeda_antiga"))
	assert_false(museum.has_pedestal("moeda_antiga"))
	assert_true(museum.has_pedestal("concha_dourada"))
	assert_false(museum.has_seal("concha_dourada"))
	assert_true(museum.has_piece(MuseumDisplay.HIGHLIGHT_ID), "ídolo no pedestal próprio")
	# Intacta depois: o selo entra no estado seguinte.
	GameState.instance.request_report_intact("concha_dourada")
	await wait_frames(2)
	assert_true(museum.has_seal("concha_dourada"))


func test_load_snapshot_builds_everything() -> void:
	_build()
	var ids: Array[String] = _all_ids(museum)
	GameState.instance.load_snapshot({"discovered_items": ids, "intact_items": ids, "rare_items": ids})
	await wait_frames(2)
	assert_eq(museum.get_piece_count(), ids.size())
	for id: String in ids:
		assert_true(museum.has_seal(id), "selo em %s" % id)


func test_client_apply_snapshot_builds_the_same() -> void:
	var data: Dictionary = {"discovered_items": ["alianca_ouro", "fossil_gelo", "cristal_eco"],
		"intact_items": ["fossil_gelo"], "rare_items": ["cristal_eco"]}
	GameState.instance.load_snapshot(data)
	var host_view: MuseumDisplay = _build()
	var host: Array = [host_view.get_piece_count(), host_view.has_seal("fossil_gelo"), host_view.has_pedestal("cristal_eco")]
	GameState.instance.reset_state()
	_build()
	# Caminho do cliente: o snapshot chega pela RPC e cai no apply_snapshot (state_synced).
	var full: Dictionary = GameState.instance.get_snapshot()
	full.merge(data, true)
	GameState.instance.apply_snapshot(full)
	await wait_frames(2)
	assert_eq([museum.get_piece_count(), museum.has_seal("fossil_gelo"), museum.has_pedestal("cristal_eco")], host)


func test_rare_registered_only_on_donation() -> void:
	var gs: GameState = GameState.instance
	gs.request_report_discovery("moeda_antiga", 10, true)
	assert_true(gs.rare_items.has("moeda_antiga"), "rara doada fica registrada")
	gs.request_report_discovery("chave_enferrujada", 10)
	gs.request_report_discovery("chave_enferrujada", 10, true)
	assert_false(gs.rare_items.has("chave_enferrujada"), "rara vendida (repetida) não conta")
	assert_eq(gs.get_snapshot()["rare_items"], ["moeda_antiga"])


func test_rare_items_saved_and_old_save_loads() -> void:
	var gs: GameState = GameState.instance
	var save: SaveManager = SaveManager.instance
	save.use_test_save_dir("museum_display")
	gs.load_snapshot({"discovered_items": ["moeda_antiga"], "rare_items": ["moeda_antiga"]})
	assert_eq(save.save_game(), OK)
	assert_eq(save.load_from_file().get("rare_items"), ["moeda_antiga"], "rare_items no arquivo")
	gs.reset_state()
	assert_eq(save.load_game(), OK)
	assert_eq(gs.rare_items, ["moeda_antiga"] as Array[String])

	save.use_test_save_dir("museum_display")
	assert_eq(save.save_to_file({"version": 4, "team_money": 450, "current_day": 2, "discovered_items": ["lata_enferrujada"]}), OK)
	gs.load_snapshot({"rare_items": ["sino_bronze"]})
	assert_eq(save.load_game(), OK, "save antigo sem rare_items carrega")
	assert_eq(gs.discovered_items, ["lata_enferrujada"] as Array[String])
	assert_true(gs.rare_items.is_empty(), "sem o campo, nenhuma rara")


## Polimento (#119): plaquinha de madeira com face de latão e texto de tinta; fundo de madeira
## média (não quase preto).
func test_plaques_are_brass_with_dark_text_and_back_is_lighter() -> void:
	_build()
	var section: Node3D = museum.get_node("Site_praia") as Node3D
	var plate: MeshInstance3D = section.get_node("PlaquePlate") as MeshInstance3D
	var frame: MeshInstance3D = section.get_node("PlaqueFrame") as MeshInstance3D
	var label: Label3D = section.get_node("Plaque") as Label3D
	assert_eq((plate.material_override as StandardMaterial3D).albedo_color, MuseumDisplay.BRASS, "face de latão")
	assert_eq((frame.material_override as StandardMaterial3D).albedo_color, MuseumDisplay.WOOD_DARK, "moldura de madeira")
	assert_eq(label.modulate, MuseumDisplay.PLAQUE_INK, "texto escuro")
	assert_eq(label.outline_size, 0)
	assert_lt((plate.mesh as BoxMesh).size.x, MuseumDisplay.SECTION_WIDTH * 0.5, "plaquinha menor que meia seção")
	var back: MeshInstance3D = museum.get_node("Back") as MeshInstance3D
	var back_mat: StandardMaterial3D = back.material_override as StandardMaterial3D
	assert_gt(back_mat.albedo_color.get_luminance(), 0.3, "fundo menos preto")
	assert_true(back_mat.emission_enabled, "brilho próprio contra a sombra da prateleira")
	assert_not_null(museum.get_node("Highlight/PlaquePlate"), "pedestal do ídolo com a mesma plaquinha")
