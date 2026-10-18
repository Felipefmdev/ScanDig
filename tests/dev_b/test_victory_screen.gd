extends GutTest

## Tela "Jogo concluído" (#81): abre só na vitória ao vivo (GameState.game_victory), nunca ao
## carregar um save concluído; trava o player e o menu de pausa; "Continuar explorando" fecha.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")


func before_all() -> void:
	if SaveManager.instance != null:
		SaveManager.instance.use_test_save_dir("devb_victory")


func before_each() -> void:
	if GameState.instance != null:
		GameState.instance.reset_state()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func after_each() -> void:
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	if PauseMenu.instance != null:
		PauseMenu.instance.close()
	if GameState.instance != null:
		GameState.instance.reset_state()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _screen() -> VictoryScreen:
	assert_not_null(VictoryScreen.instance, "autoload CoreVictoryScreen presente")
	return VictoryScreen.instance


func test_autoload_layer_between_pause_and_session_ui() -> void:
	var screen: VictoryScreen = _screen()
	assert_eq(screen.layer, 46)
	assert_gt(screen.layer, PauseMenu.instance.layer, "acima do menu de pausa")
	assert_lt(screen.layer, SessionUI.instance.layer, "abaixo da SessionUI (carregamento cobre)")
	assert_false(VictoryScreen.is_open())
	assert_false(screen.root_control.visible)


func test_live_victory_opens_with_counts() -> void:
	var gs: GameState = GameState.instance
	var screen: VictoryScreen = _screen()
	var items: Array[String] = ["alianca_ouro", "moeda_antiga"]
	var secrets: Array[String] = [GameState.SECRETS[0]]
	var creatures: Array[String] = ["crab", "mole", "bat"]
	gs.discovered_items = items
	gs.found_secrets = secrets
	gs.seen_creatures = creatures
	watch_signals(gs)
	gs._host_report_boss_defeated("gold_colossus")
	assert_signal_emit_count(gs, "game_victory", 1)
	assert_signal_emitted_with_parameters(gs, "game_completed_changed", [true])
	assert_true(VictoryScreen.is_open(), "abre na vitória ao vivo")
	assert_true(screen.root_control.visible)
	assert_eq(screen.items_value.text, "2 / %d" % gs.get_total_catalog_items())
	assert_eq(screen.secrets_value.text, "1 / %d" % GameState.SECRETS.size())
	assert_eq(screen.creatures_value.text, "3 / %d" % GameState.CREATURES.size())
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "mouse livre")


func test_loading_completed_save_does_not_open() -> void:
	var gs: GameState = GameState.instance
	watch_signals(gs)
	var data: Dictionary = gs.get_snapshot()
	data["game_completed"] = true
	data["defeated_bosses"] = ["gold_colossus"]
	gs.load_snapshot(data)
	assert_signal_emitted_with_parameters(gs, "game_completed_changed", [true])
	assert_signal_not_emitted(gs, "game_victory")
	assert_false(VictoryScreen.is_open(), "save concluído: estado, não vitória")


func test_full_state_snapshot_does_not_open() -> void:
	var gs: GameState = GameState.instance
	var data: Dictionary = gs.get_snapshot()
	data["defeated_bosses"] = ["gold_colossus"]
	gs._receive_snapshot(data)
	assert_true(gs.is_game_completed())
	assert_false(VictoryScreen.is_open(), "entrar no meio (snapshot completo) não abre")


func test_defeating_again_does_not_reopen() -> void:
	var gs: GameState = GameState.instance
	gs._host_report_boss_defeated("gold_colossus")
	assert_true(VictoryScreen.is_open())
	_screen().continue_button.pressed.emit()
	assert_false(VictoryScreen.is_open())
	watch_signals(gs)
	gs._host_report_boss_defeated("gold_colossus")
	assert_signal_not_emitted(gs, "game_victory")
	assert_false(VictoryScreen.is_open(), "chefe já derrotado não reabre")


func test_the_sleeper_is_a_normal_boss_now() -> void:
	var gs: GameState = GameState.instance
	watch_signals(gs)
	gs._host_report_boss_defeated("the_sleeper")
	assert_true(gs.defeated_bosses.has("the_sleeper"), "entra nos chefes vencidos")
	assert_true(gs.map_fragments.has("cratera_frag_2"), "e dá o fragmento da Cratera")
	assert_false(gs.is_game_completed(), "não é mais o final (#115)")
	assert_signal_not_emitted(gs, "game_victory")
	assert_false(VictoryScreen.is_open())


func test_other_boss_does_not_open() -> void:
	var gs: GameState = GameState.instance
	watch_signals(gs)
	gs._host_report_boss_defeated("king_crab")
	assert_signal_not_emitted(gs, "game_victory")
	assert_false(VictoryScreen.is_open())


func test_continue_closes_and_restores_mouse() -> void:
	var screen: VictoryScreen = _screen()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Headless pode não guardar o modo: compara com o que o Input devolve de fato.
	var before: Input.MouseMode = Input.mouse_mode
	GameState.instance._host_report_boss_defeated("gold_colossus")
	assert_true(VictoryScreen.is_open())
	assert_eq(screen._previous_mouse_mode, before, "guardou o modo do mouse")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)
	screen.continue_button.pressed.emit()
	assert_false(VictoryScreen.is_open(), "Continuar explorando fecha")
	assert_false(screen.root_control.visible)
	assert_eq(Input.mouse_mode, before, "mouse restaurado")


func test_blocks_pause_menu_and_player_input() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_false(player.is_settings_open())
	GameState.instance._host_report_boss_defeated("gold_colossus")
	assert_true(player.is_settings_open(), "player parado com a tela aberta")
	assert_false(PauseMenu.instance.can_open(), "pausa não abre por cima")
	assert_false(PauseMenu.instance.open())
	assert_false(PauseMenu.is_open())
	_screen().close()
	assert_false(player.is_settings_open())
	assert_true(PauseMenu.instance.can_open())


func test_victory_closes_open_pause_menu() -> void:
	assert_true(PauseMenu.instance.open())
	GameState.instance._host_report_boss_defeated("gold_colossus")
	assert_false(PauseMenu.is_open(), "a pausa aberta (coop) fecha na vitória")
	assert_true(VictoryScreen.is_open())


func test_closes_on_scene_change_and_reset() -> void:
	GameState.instance._host_report_boss_defeated("gold_colossus")
	assert_true(VictoryScreen.is_open())
	SessionManager.instance.scene_changing.emit("res://world/lobby_base.tscn")
	assert_false(VictoryScreen.is_open(), "fecha na troca de cena")
	GameState.instance.reset_state()
	GameState.instance._host_report_boss_defeated("gold_colossus")
	assert_true(VictoryScreen.is_open())
	GameState.instance.reset_state()
	assert_false(VictoryScreen.is_open(), "jogo zerado: fecha")


func test_pause_action_closes() -> void:
	GameState.instance._host_report_boss_defeated("gold_colossus")
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	_screen()._unhandled_input(ev)
	assert_false(VictoryScreen.is_open(), "Esc fecha a tela")


# --- Créditos (#81) ------------------------------------------------------------

func test_credits_button_swaps_card_view() -> void:
	var screen: VictoryScreen = _screen()
	GameState.instance._host_report_boss_defeated("gold_colossus")
	assert_true(screen.summary_view.visible, "abre nas contagens")
	assert_false(screen.credits_view.visible)
	screen.credits_button.pressed.emit()
	assert_true(screen.credits_view.is_visible_in_tree(), "Créditos mostra os créditos")
	assert_false(screen.summary_view.visible, "e esconde as contagens")
	assert_string_contains(screen.credits_label.text, VictoryScreen.CREDITS_TEXT)
	assert_true(VictoryScreen.is_open(), "Créditos não fecha a tela")
	screen.credits_back_button.pressed.emit()
	assert_true(screen.summary_view.is_visible_in_tree(), "Voltar mostra as contagens")
	assert_false(screen.credits_view.visible)
	assert_true(VictoryScreen.is_open())


func test_reopen_starts_on_summary() -> void:
	var screen: VictoryScreen = _screen()
	GameState.instance._host_report_boss_defeated("gold_colossus")
	screen.credits_button.pressed.emit()
	screen.close()
	screen.open()
	assert_true(VictoryScreen.is_open())
	assert_true(screen.summary_view.visible, "reabre nas contagens")
	assert_false(screen.credits_view.visible)


func test_pause_action_in_credits_goes_back() -> void:
	var screen: VictoryScreen = _screen()
	GameState.instance._host_report_boss_defeated("gold_colossus")
	screen.credits_button.pressed.emit()
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	screen._unhandled_input(ev)
	assert_true(VictoryScreen.is_open(), "Esc nos créditos não fecha")
	assert_true(screen.summary_view.visible, "volta às contagens")
	screen._unhandled_input(ev)
	assert_false(VictoryScreen.is_open(), "Esc nas contagens fecha")


# --- Peças intactas (#93) --------------------------------------------------------

func test_intact_items_row() -> void:
	var gs: GameState = GameState.instance
	var screen: VictoryScreen = _screen()
	var before: Array[String] = gs.intact_items.duplicate()
	var intact: Array[String] = ["alianca_ouro", "moeda_antiga", "bussola"]
	gs.intact_items = intact
	gs._host_report_boss_defeated("gold_colossus")
	assert_true(VictoryScreen.is_open())
	assert_eq(screen.intact_value.text, "3 / %d" % gs.get_total_catalog_items(), "linha Peças intactas")
	var grid: GridContainer = screen.intact_value.get_parent() as GridContainer
	assert_eq(screen.intact_value.get_index(), screen.items_value.get_index() + 2, "logo depois de Peças do museu")
	assert_eq(grid.get_child(screen.intact_value.get_index() - 1).get("text"), "Peças intactas")
	gs.intact_items = before


# --- Final da ilha (#115) --------------------------------------------------------

func test_subtitle_tells_the_island_ending() -> void:
	var text: String = VictoryScreen.SUBTITLE_TEXT
	assert_string_contains(text, "Colosso do Tesouro")
	assert_string_contains(text, "Ídolo de Ouro")
	assert_string_contains(text, "Museu")
	assert_string_contains(text, "mapa do tesouro está completo")
	assert_false(text.contains("Dorme"), "o the_sleeper não é mais o final")


func test_map_fragments_row() -> void:
	var gs: GameState = GameState.instance
	var screen: VictoryScreen = _screen()
	var frags: Array[String] = [GameState.MAP_FRAGMENT_IDS[0], GameState.MAP_FRAGMENT_IDS[1], GameState.MAP_FRAGMENT_IDS[2]]
	gs.map_fragments = frags
	gs._host_report_boss_defeated("gold_colossus")
	assert_true(VictoryScreen.is_open())
	assert_eq(screen.fragments_value.text, "3 / %d" % GameState.MAP_FRAGMENT_IDS.size(), "linha Fragmentos do mapa")
	assert_eq(GameState.MAP_FRAGMENT_IDS.size(), 8)
	var grid: GridContainer = screen.fragments_value.get_parent() as GridContainer
	assert_eq(grid.get_child(screen.fragments_value.get_index() - 1).get("text"), "Fragmentos do mapa")
	assert_eq(screen.fragments_value.get_index(), screen.intact_value.get_index() + 2, "depois de Peças intactas")
	var all_frags: Array[String] = GameState.MAP_FRAGMENT_IDS.duplicate()
	gs.map_fragments = all_frags
	screen.refresh()
	assert_eq(screen.fragments_value.text, "8 / 8")
