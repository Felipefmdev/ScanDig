extends SceneTree
## Falha controlada no carregador de cenas com Base e overlays reais.

const PRAIA_SCENE: String = "res://world/map_praia.tscn"

class FailFirstDeparture extends SessionManager:
	var attempts: int = 0

	func _perform_scene_change(scene_path: String) -> Error:
		if scene_path == PRAIA_SCENE:
			attempts += 1
			if attempts == 1:
				SaveManager.instance.advance_play_clock(0.0)
				return ERR_CANT_OPEN
		return super._perform_scene_change(scene_path)


var _fails: int = 0
var _starts: Array[String] = []
var _scene_events: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if not condition:
		_fails += 1
		print("FAIL " + description)


func _frames(count: int = 6) -> void:
	for frame: int in count:
		await process_frame


func _capture() -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = "user://expedition233-%dx%d.png" % [root.size.x, root.size.y]
		_check(root.get_texture().get_image().save_png(path) == OK, "captura da Base após a falha")


func _run() -> void:
	var original: SessionManager = SessionManager.instance
	root.remove_child(original)
	original.free()
	var session: FailFirstDeparture = FailFirstDeparture.new()
	session.name = "CoreSession"
	root.add_child(session)
	session.scene_changing.connect(func(path: String) -> void:
		if path == PRAIA_SCENE:
			_scene_events.append("changing"))
	session.expedition_started.connect(func(map_id: String) -> void:
		_starts.append(map_id)
		_scene_events.append("started")
		_check(session.get_current_map() != null and session.get_current_map().id == map_id, "mapa já definido no sinal de início")
		_check(SessionManager.is_night() and current_scene == null, "noite definida antes de entrar na cena"))
	session.scene_loaded.connect(func(path: String) -> void:
		if path == PRAIA_SCENE:
			_scene_events.append("loaded"))
	var session_ui: SessionUI = SessionUI.instance
	session_ui._connect_session()
	session.expedition_start_failed.connect(func(_message: String) -> void:
		_scene_events.append("failed")
		_check(not session_ui.loading_screen.visible, "o sinal de falha fecha o carregamento sem aguardar o timer"))
	var save: SaveManager = SaveManager.instance
	save.use_test_save_dir("expedition233")
	SessionManager.launch_mode = SessionManager.LAUNCH_SOLO
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await _frames(15)
	TranslationServer.set_locale("pt_BR")
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 2
	await _frames()
	var state: GameState = GameState.instance
	state.load_snapshot({"team_money": 775, "current_day": 3})
	save.last_map = "campo"
	_check(save.save_game() == OK, "save isolado gravado")
	var save_hash: String = FileAccess.get_sha256(save.save_path)
	var progress: Dictionary = state.get_snapshot()
	var prior_summary: Dictionary = {"day": 2, "map_id": "campo"}
	session._last_summary = prior_summary.duplicate(true)
	_check(not base.depart_btn.disabled, "Praia disponível na Base")
	base.night_check.button_pressed = true
	_check(base.is_night_selected(), "expedição noturna selecionada")
	base.depart_btn.grab_focus()
	base.depart_btn.pressed.emit()
	_check(base.depart_btn.disabled, "Partir continua bloqueado enquanto o pedido está pendente")
	_check(session.request_start_expedition("praia") == ERR_BUSY, "o host recusa segunda partida enquanto a troca está pendente")
	await _frames(12)

	_check(session.attempts == 1 and current_scene.scene_file_path == SessionManager.LOBBY_SCENE, "a primeira troca falha e mantém a Base")
	_check(not session.is_in_expedition() and session.get_current_map() == null and _starts.is_empty(), "falha não inicia uma expedição")
	_check(not SessionManager.is_night() and session._pending_summary.is_empty() and session.get_last_summary() == prior_summary, "falha descarta somente o resumo pendente")
	_check(state.get_snapshot() == progress and FileAccess.get_sha256(save.save_path) == save_hash and save.last_map == "campo", "dia, progresso, último mapa e save ficam preservados")
	_check(not session_ui.loading_screen.visible and not session_ui.expedition_bar.visible and not session_ui.summary_panel.visible, "overlay de carregamento fecha sem resumo")
	_check(base.expedition_feedback_label.is_visible_in_tree() and base.expedition_feedback_label.text.contains("Tente novamente"), "a Base explica a falha e a nova tentativa")
	_check(not base.depart_btn.disabled, "Partir fica disponível para tentar novamente")
	await _capture()

	if not base.depart_btn.disabled:
		base.depart_btn.pressed.emit()
	await _frames(30)
	_check(session.attempts == 2 and current_scene.scene_file_path == PRAIA_SCENE and _starts == ["praia"], "segunda tentativa carrega a Praia e inicia uma expedição")
	_check(SessionManager.is_night(), "segunda tentativa mantém a opção noturna")
	_check(state.current_day == 3 and state.team_money == 775 and FileAccess.get_sha256(save.save_path) == save_hash, "a nova partida não grava nem avança o dia")
	_check(_scene_events == ["changing", "failed", "changing", "started", "loaded"], "sinais seguem a ordem de transição em falha e sucesso")

	# Volta à Base e enfileira duas partidas para o mesmo mapa com um cancelamento entre elas.
	session.request_end_expedition()
	await _frames(20)
	_check(current_scene.scene_file_path == SessionManager.LOBBY_SCENE, "Base carregada para o teste de cancelamento")
	_starts.clear()
	_check(session.request_start_expedition("praia", false) == OK, "primeiro pedido é enfileirado")
	session.return_to_title()
	_check(session.request_start_expedition("praia", true) == OK, "novo pedido substitui o cancelado")
	await _frames(30)
	_check(session.attempts == 3 and _starts == ["praia"] and SessionManager.is_night(), "apenas o pedido mais recente chega ao carregador")
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
