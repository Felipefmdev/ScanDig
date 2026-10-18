extends GutTest

## #122 (E2): a barra da expedição não tem mais "Voltar à base". O host volta pela pausa
## (PauseMenu → SessionUI.request_return_to_base) e o cliente online sai pela pausa
## ("Sair da sessão" abre a confirmação do SessionUI). O SessionUI fala com um dublê da
## sessão, para não trocar de cena dentro do GUT; a pausa lê o CoreSession real.

class FakeSession:
	extends Node
	var end_calls: int = 0

	func is_in_expedition() -> bool:
		return true

	func get_current_map() -> MapData:
		return load("res://items/maps/praia.tres") as MapData

	func request_end_expedition() -> void:
		end_calls += 1


var _ui: SessionUI = null
var _menu: PauseMenu = null
var _real_session: Node = null
var _core_session: Node = null
var _fake: FakeSession = null


func before_each() -> void:
	_ui = SessionUI.instance
	_menu = PauseMenu.instance
	_real_session = _ui._session
	_fake = FakeSession.new()
	add_child_autofree(_fake)
	_ui._session = _fake
	_core_session = get_tree().root.get_node(^"CoreSession")
	_core_session.set("_current_map", _fake.get_current_map())


func after_each() -> void:
	_menu.close()
	_core_session.set("_current_map", null)
	_ui._session = _real_session
	_ui.leave_confirm_panel.visible = false
	_ui._refresh_expedition_bar()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func test_bar_has_only_the_label_and_leave() -> void:
	assert_null(_ui.get_node_or_null("%ReturnButton"), "barra sem Voltar à base")
	assert_false("ReturnButton" in SessionUI.REQUIRED_NODES)
	_ui._refresh_expedition_bar()
	assert_eq(_ui.expedition_info_label.text, "Praia  •  Dia %d" % GameState.instance.current_day)
	assert_false(_ui.leave_button.visible, "solo: sem sair da sessão na barra")


func test_pause_returns_host_to_base() -> void:
	assert_true(_menu.open(), "pausa abre")
	assert_true(_menu.return_button.visible, "host em expedição: Voltar à base na pausa")
	_menu.return_button.pressed.emit()
	assert_false(PauseMenu.is_open(), "a pausa fecha")
	assert_eq(_fake.end_calls, 1, "pediu o fim da expedição")


func test_online_client_leaves_through_pause() -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(peer.create_client("127.0.0.1", 7899), OK)
	multiplayer.multiplayer_peer = peer
	assert_false(GameState.instance.is_authority(), "cliente")
	assert_false(_ui.request_return_to_base(), "cliente não encerra a expedição")
	assert_true(_menu.open(), "pausa abre")
	assert_false(_menu.return_button.visible, "cliente: sem Voltar à base")
	assert_true(_menu.leave_button.visible, "cliente: Sair da sessão na pausa")
	_menu.leave_button.pressed.emit()
	assert_true(_ui.leave_confirm_panel.visible, "abre a confirmação de sair")
	assert_eq(_ui.leave_confirm_label.text, SessionUI.LEAVE_CLIENT_TEXT)
	assert_eq(_fake.end_calls, 0)
	peer.close()
