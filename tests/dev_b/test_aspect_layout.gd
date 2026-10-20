extends GutTest

## Proporções de tela (#146): em 4:3 (1024x768) e 21:9 (2560x1080), com ui_scale 1.0 e 1.3, as
## telas principais passam na checagem por retângulos do layout_audit.gd (nada fora da tela, painéis
## sem sobreposição, texto sem corte): título, slots e Configurações (5 abas, pelo título), as 6
## abas da Base e a vitória com os créditos. O título e a vitória encolhem para caber
## (FitCenterContainer) e o card do Diário reduz a fonte antes das reticências.

const Audit: GDScript = preload("res://tests/dev_b/layout_audit.gd")
const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")
const BASE_STATION_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const LOBBY_SCENE: PackedScene = preload("res://world/lobby_base.tscn")
const COMBOS: Array[Dictionary] = [
	{"size": Vector2i(1024, 768), "ui": 1.0}, {"size": Vector2i(1024, 768), "ui": 1.3},
	{"size": Vector2i(2560, 1080), "ui": 1.0}, {"size": Vector2i(2560, 1080), "ui": 1.3},
]
const DIR: String = "user://test_saves/devb_aspect"

var _orig_size: Vector2i = Vector2i.ZERO
var _orig_path: String = ""


func before_all() -> void:
	_orig_size = get_tree().root.size
	_orig_path = SaveManager.instance.save_path
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveManager.instance.set_save_path(DIR + "/scandig_save.json")


func before_each() -> void:
	GameState.instance.reset_state()


func after_each() -> void:
	get_tree().root.content_scale_factor = 1.0
	get_tree().root.size = _orig_size
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	GameState.instance.reset_state()


func after_all() -> void:
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(_orig_path)


## Passa por todas as combinações; `prepare` roda depois de cada redimensionamento.
func _check_all(scope: Node, screen: String, prepare: Callable = Callable(), floating: Array[Control] = []) -> void:
	for combo: Dictionary in COMBOS:
		var root: Window = get_tree().root
		root.size = combo["size"]
		root.content_scale_factor = combo["ui"]
		if prepare.is_valid():
			prepare.call()
		await wait_frames(4)
		var no_ignore: Array[NodePath] = []
		var issues: Array[Dictionary] = Audit.audit(root, no_ignore, scope, floating)
		assert_eq(issues.size(), 0, "%s em %s ui %.1f (vista %s):\n%s" % [screen, combo["size"], combo["ui"],
			root.get_visible_rect().size, Audit.describe(issues)])


func _title() -> TitleScreen:
	var file: FileAccess = FileAccess.open(SaveManager.instance.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveManager.SAVE_VERSION, "saved_at": 100, "team_money": 48250,
		"current_day": 23, "play_time_s": 7500, "last_map": "praia", "discovered_items": ["alianca_ouro"]}))
	file.close()
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	await wait_frames(3)
	return title


func test_title_and_slots_fit() -> void:
	var title: TitleScreen = await _title()
	await _check_all(title.root_control, "título")
	title.show_slots("load")
	await _check_all(title.root_control, "slots")


func test_settings_tabs_fit() -> void:
	var title: TitleScreen = await _title()
	title.show_settings()
	var tabs: TabContainer = title.settings_menu.tabs
	assert_eq(tabs.get_tab_count(), 5, "cinco abas")
	for i: int in tabs.get_tab_count():
		await _check_all(title.root_control, "Configurações aba %d" % i, func() -> void: tabs.current_tab = i)


func test_base_tabs_fit() -> void:
	GameState.instance.load_snapshot({"team_money": 48250, "defeated_bosses": ["king_crab"],
		"discovered_items": ["alianca_ouro", "moeda_antiga"]})
	var ui: BaseStationUI = BASE_STATION_SCENE.instantiate() as BaseStationUI
	add_child_autofree(ui)
	await wait_frames(3)
	for i: int in ui.tab_container.get_tab_count():
		await _check_all(ui, "Base aba %d" % i, func() -> void: ui.tab_container.current_tab = i)


func test_victory_and_credits_fit() -> void:
	var screen: VictoryScreen = VictoryScreen.instance
	assert_not_null(screen)
	screen.open()
	await _check_all(screen.root_control, "vitória")
	screen.show_credits()
	await _check_all(screen.root_control, "créditos")


## Na Base o toast de conquista sobe para o topo, entre os chips e o menu Multiplayer, sem cobrir
## o título da Base (antes ficava em y=132, por cima dele, em todas as resoluções).
func test_base_toast_clear_of_panels() -> void:
	var lobby: Node = LOBBY_SCENE.instantiate()
	add_child_autofree(lobby)
	await wait_frames(4)
	var ui: SessionUI = SessionUI.instance
	ui.set(&"_synced_once", true)
	var floating: Array[Control] = [ui.toast_panel]
	await _check_all(lobby, "toast na Base", func() -> void:
		ui._clear_toasts()
		ui._on_achievement_unlocked("digs_1000"), floating)
	assert_true(ui.toast_panel.visible, "o toast apareceu")
	assert_almost_eq(ui.toast_panel.offset_top, SessionUI.TOAST_BASE_TOP, 0.5, "no topo")
	ui._clear_toasts()


func test_fit_scale_only_shrinks() -> void:
	assert_eq(FitCenterContainer.fit_scale(Vector2(400, 300), Vector2(1152, 648)), 1.0, "cabe: escala 1")
	assert_almost_eq(FitCenterContainer.fit_scale(Vector2(400, 636), Vector2(886, 498), 8.0), 482.0 / 636.0, 0.001)
	assert_eq(FitCenterContainer.fit_scale(Vector2(400, 4000), Vector2(886, 498)), 0.5, "não passa do mínimo")
