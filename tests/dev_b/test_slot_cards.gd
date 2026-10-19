extends GutTest

## Slots mais completos (#139): save v5 com tempo de jogo, último jogo e último mapa (migração de
## saves antigos), relógio que só corre jogando, miniatura ao lado do save (captura simulada),
## card do slot no título em pt e en, e formato de data/tempo do UiFormat.
## Saves em user://test_saves/devb_slot_cards.

const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")
const DIR: String = "user://test_saves/devb_slot_cards"
const BASE: String = DIR + "/scandig_save.json"


## Captura simulada: uma tela 640x400 (16:10) laranja, como se houvesse render.
class FakeCaptureSave extends SaveManager:
	var captures: int = 0

	func _capture_viewport_image() -> Image:
		captures += 1
		var image: Image = Image.create(640, 400, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.85, 0.47, 0.17))
		return image


var _orig_path: String = ""
var _orig_locale: String = ""


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path
	_orig_locale = TranslationServer.get_locale()


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(BASE)
	GameState.instance.reset_state()
	SessionManager.launch_mode = ""


func after_each() -> void:
	TranslationServer.set_locale(_orig_locale)
	get_tree().paused = false


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)
	GameState.instance.reset_state()


func _write(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary


func _v4_save() -> Dictionary:
	return {"version": 4, "saved_at": 1760000000, "team_money": 321, "current_day": 4,
		"discovered_items": ["alianca_ouro"], "defeated_bosses": ["king_crab"]}


func _title() -> TitleScreen:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	return title


# --- Migração ---------------------------------------------------------------------

func test_v4_save_gets_defaults_and_saves_as_v5() -> void:
	var save: SaveManager = SaveManager.instance
	assert_gte(SaveManager.SAVE_VERSION, 5)
	_write(save.slot_path(1), _v4_save())
	var summary: Dictionary = save.get_slot_summary(1)
	assert_true(summary["valid"], "v4 continua válido")
	assert_eq(summary["play_time_s"], 0, "save antigo: 0 de tempo")
	assert_eq(summary["last_map"], "", "save antigo: sem mapa (o card mostra —)")
	assert_eq(summary["last_played"], 1760000000, "last_played vem do saved_at")
	assert_eq(summary["bosses_defeated"], 1)
	assert_eq(summary["bosses_total"], GameState.all_boss_ids().size())
	assert_eq(summary["thumbnail"], "", "sem miniatura")
	assert_eq(save.select_slot(1), OK)
	assert_eq(save.continue_game(), OK)
	assert_eq(save.play_time_s, 0.0)
	assert_eq(save.last_map, "")
	assert_eq(GameState.instance.team_money, 321, "progresso intacto")
	assert_eq(save.save_game(), OK)
	var data: Dictionary = _read(save.slot_path(1))
	assert_eq(int(data["version"]), SaveManager.SAVE_VERSION)
	assert_eq(int(data["play_time_s"]), 0)
	assert_eq(str(data["last_map"]), "")
	assert_eq(int(data["last_played"]), int(data["saved_at"]))


func test_bad_play_meta_falls_back_without_invalidating() -> void:
	var data: Dictionary = _v4_save()
	data["version"] = 5
	data["play_time_s"] = "muito"
	data["last_map"] = 42
	data["last_played"] = null
	_write(SaveManager.instance.slot_path(2), data)
	var summary: Dictionary = SaveManager.instance.get_slot_summary(2)
	assert_true(summary["valid"], "tempo/mapa ruins não invalidam o progresso")
	assert_eq(summary["play_time_s"], 0)
	assert_eq(summary["last_map"], "")
	assert_eq(summary["last_played"], 1760000000)


# --- Relógio de jogo --------------------------------------------------------------

func test_play_time_accumulates_only_while_playing() -> void:
	var save: SaveManager = SaveManager.instance
	assert_eq(save.select_slot(1), OK)
	assert_eq(save.start_new_game(), OK)
	assert_eq(save.play_time_s, 0.0, "jogo novo: zero")
	save.advance_play_clock(2.5)
	assert_almost_eq(save.play_time_s, 2.5, 0.001, "jogando: soma")
	get_tree().paused = true
	assert_false(save.is_play_clock_running(), "solo pausado: parado")
	save.advance_play_clock(10.0)
	get_tree().paused = false
	assert_almost_eq(save.play_time_s, 2.5, 0.001, "pausado não soma")
	save._on_joined_as_client()
	save.advance_play_clock(10.0)
	assert_almost_eq(save.play_time_s, 2.5, 0.001, "cliente em sessão não soma no próprio save")
	assert_eq(save.continue_game(), OK)
	save.play_time_s = 7325.9
	save.last_map = "campo"
	assert_eq(save.save_game(), OK)
	var data: Dictionary = _read(save.slot_path(1))
	assert_eq(int(data["play_time_s"]), 7325)
	assert_eq(str(data["last_map"]), "campo")
	assert_eq(save.select_slot(2), OK)
	assert_eq(save.play_time_s, 0.0, "outro slot: o tempo não vaza")
	assert_eq(save.select_slot(1), OK)
	assert_eq(save.continue_game(), OK)
	assert_almost_eq(save.play_time_s, 7325.0, 0.001, "carregar devolve o tempo")
	assert_eq(save.last_map, "campo")
	assert_eq(save.start_new_game(), OK)
	assert_eq(save.play_time_s, 0.0, "jogo novo no slot zera o tempo")
	assert_eq(save.last_map, "")


# --- Miniatura --------------------------------------------------------------------

func test_thumbnail_created_with_capture_and_deleted_with_slot() -> void:
	var fake: FakeCaptureSave = autofree(FakeCaptureSave.new())
	fake.set_save_path(BASE)
	assert_eq(fake.select_slot(2), OK)
	assert_eq(fake.start_new_game(), OK)
	var png: String = DIR + "/scandig_save_2.png"
	assert_eq(fake.get_thumbnail_path(), png, "scandig_save_<n>.png ao lado do save")
	assert_true(FileAccess.file_exists(png), "salvar com render grava a miniatura")
	var image: Image = Image.load_from_file(png)
	assert_eq(image.get_size(), SaveManager.THUMBNAIL_SIZE, "256x144")
	assert_eq(fake.get_slot_summary(2)["thumbnail"], png)
	assert_eq(fake.delete_slot(2), OK)
	assert_false(FileAccess.file_exists(png), "apagar o slot apaga a miniatura")
	assert_eq(fake.get_slot_summary(2)["thumbnail"], "")


func test_no_render_no_thumbnail_and_no_error() -> void:
	var save: SaveManager = SaveManager.instance
	assert_null(save._capture_viewport_image(), "testes/headless: sem captura")
	assert_eq(save.select_slot(3), OK)
	assert_eq(save.start_new_game(), OK, "salvar sem render não falha")
	assert_false(FileAccess.file_exists(DIR + "/scandig_save_3.png"))
	assert_eq(save.get_slot_summary(3)["thumbnail"], "")


func test_new_game_drops_old_thumbnail() -> void:
	var fake: FakeCaptureSave = autofree(FakeCaptureSave.new())
	fake.set_save_path(BASE)
	_write(fake.slot_path(1), _v4_save())
	Image.create(8, 8, false, Image.FORMAT_RGB8).save_png(DIR + "/scandig_save_1.png")
	assert_eq(fake.select_slot(1), OK)
	assert_eq(fake.start_new_game(), OK)
	assert_eq(fake.captures, 1)
	assert_eq(Image.load_from_file(DIR + "/scandig_save_1.png").get_size(), SaveManager.THUMBNAIL_SIZE,
		"a miniatura antiga não fica no slot novo")


# --- Card do slot -----------------------------------------------------------------

func _fill_slots() -> int:
	var played_at: int = 1760100000
	var save: SaveManager = SaveManager.instance
	_write(save.slot_path(1), {"version": 5, "saved_at": played_at, "last_played": played_at, "team_money": 1234,
		"current_day": 9, "play_time_s": 7500, "last_map": "praia", "discovered_items": ["alianca_ouro", "moeda_antiga"],
		"defeated_bosses": ["king_crab", "octopus", "nao_e_chefe", GameState.FINAL_BOSS_ID]})
	_write(save.slot_path(2), _v4_save())
	Image.create(256, 144, false, Image.FORMAT_RGB8).save_png(DIR + "/scandig_save_1.png")
	return played_at


func test_card_shows_thumbnail_time_date_summary_and_star() -> void:
	var played_at: int = _fill_slots()
	var title: TitleScreen = _title()
	title.show_slots("load")
	var praia: String = UiFormat.map_display_name("praia", SessionManager.instance.get_available_maps())
	var bosses: int = GameState.all_boss_ids().size()
	assert_eq(title.slot_title_labels[0].text, "Slot 1  •  Dia 9  ★", "título com dia e ★ de concluído")
	assert_eq(title.slot_summary_labels[0].text, "%s  •  %s  •  Museu 2/%d  •  Chefes 3/%d" % [praia,
		UiFormat.money(1234), GameState.instance.get_total_catalog_items(), bosses], "mapa, dinheiro, museu e chefes")
	assert_eq(title.slot_meta_labels[0].text, "Tempo de jogo 2h 05min  •  " + UiFormat.date_time(played_at, "pt_BR"))
	assert_not_null(title.slot_thumbnails[0].texture, "miniatura")
	assert_false(title.slot_thumb_placeholders[0].visible)
	assert_eq(title.slot_title_labels[1].text, "Slot 2  •  Dia 4", "save antigo, sem ★")
	assert_string_starts_with(title.slot_summary_labels[1].text, "—", "save antigo: mapa —")
	assert_string_starts_with(title.slot_meta_labels[1].text, "Tempo de jogo < 1min")
	assert_null(title.slot_thumbnails[1].texture)
	assert_true(title.slot_thumb_placeholders[1].visible, "sem miniatura: o número do slot")
	assert_eq(title.slot_title_labels[2].text, "Slot 3")
	assert_eq(title.slot_summary_labels[2].text, "Vazio", "vazio continua Vazio")
	assert_false(title.slot_meta_labels[2].visible)
	assert_string_contains(title.continue_button.tooltip_text, "Tempo de jogo 2h 05min", "dica do Continuar")


func test_card_in_english() -> void:
	var played_at: int = _fill_slots()
	var title: TitleScreen = _title()
	TranslationServer.set_locale("en")
	title.show_slots("load")
	assert_eq(title.slot_title_labels[0].text, "Slot 1  •  Day 9  ★")
	assert_string_contains(title.slot_summary_labels[0].text, "Museum 2/")
	assert_string_contains(title.slot_summary_labels[0].text, "Bosses 3/")
	assert_eq(title.slot_meta_labels[0].text, "Play time 2h 05m  •  " + UiFormat.date_time(played_at, "en"))
	assert_eq(title.slot_summary_labels[2].text, "Empty")
	assert_eq(title.open_folder_button.text, "Abrir pasta de saves", "chave; o Button traduz sozinho")


func test_open_folder_button_state() -> void:
	var title: TitleScreen = _title()
	title.show_slots("load")
	var has_window: bool = DisplayServer.get_name() != "headless"
	assert_eq(title.open_folder_button.disabled, not has_window, "headless: desabilitado")
	title.save_folder_enabled = false
	title.refresh_slots()
	assert_true(title.open_folder_button.disabled)
	assert_eq(title.open_folder_button.focus_mode, Control.FOCUS_NONE, "desabilitado fica fora do foco")
	assert_eq(title.slot_buttons[SaveManager.SLOT_COUNT - 1].focus_neighbor_bottom, title.slots_back_button.get_path())
	title.save_folder_enabled = true
	title.refresh_slots()
	assert_false(title.open_folder_button.disabled)
	assert_eq(title.slot_buttons[SaveManager.SLOT_COUNT - 1].focus_neighbor_bottom, title.open_folder_button.get_path())
	assert_eq(title.open_folder_button.focus_neighbor_right, title.slots_back_button.get_path())
	assert_eq(title.slots_back_button.focus_neighbor_left, title.open_folder_button.get_path())


# --- UiFormat ---------------------------------------------------------------------

func test_date_time_follows_locale() -> void:
	# 2026-10-19 14:05 no fuso do sistema.
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 19, "hour": 14, "minute": 5, "second": 0})
	var unix_time: int = local - bias * 60
	assert_eq(UiFormat.date_time(unix_time, "pt_BR"), "19/10/2026 14:05")
	assert_eq(UiFormat.date_time(unix_time, "en"), "10/19/2026 2:05 PM")
	assert_eq(UiFormat.date_time(unix_time - 14 * 3600, "en"), "10/19/2026 12:05 AM", "meia-noite = 12 AM")


func test_play_time_text() -> void:
	assert_eq(UiFormat.play_time(0), "< 1min")
	assert_eq(UiFormat.play_time(59), "< 1min")
	assert_eq(UiFormat.play_time(720), "12min")
	assert_eq(UiFormat.play_time(7500), "2h 05min")
	TranslationServer.set_locale("en")
	assert_eq(UiFormat.play_time(7500), "2h 05m")
	assert_eq(UiFormat.play_time(720), "12m")
