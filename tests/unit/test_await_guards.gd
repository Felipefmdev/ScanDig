extends GutTest

## #66: Testes unitários para guardas de awaits com is_inside_tree e get_tree null após troca de cena.

var _root: Node3D


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)


func test_shop_offer_freed_during_try_buy_await() -> void:
	var offer: ShopOffer = ShopOffer.new()
	_root.add_child(offer)

	var inv: Inventory = Inventory.new()
	inv.capacity = 4
	_root.add_child(inv)

	# Inicia o try_buy em background
	var buy_coroutine: Signal = offer.purchased
	# Remove da árvore e liberta logo a seguir
	offer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	pass_test("ShopOffer libertado durante await termina sem SCRIPT ERROR")


func test_session_ui_freed_during_loading_await() -> void:
	var session_ui: SessionUI = preload("res://ui/session_ui.tscn").instantiate() as SessionUI
	_root.add_child(session_ui)

	# Simula carregamento de expedição que inicia os awaits de loading
	session_ui._on_expedition_loading("res://world/map_praia.tscn")
	# Imediatamente liberta o SessionUI (simulando troca abrupta de cena / saída)
	session_ui.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

	pass_test("SessionUI libertado durante loading timer/frame termina sem SCRIPT ERROR")


func test_session_ui_freed_during_toast_await() -> void:
	var session_ui: SessionUI = preload("res://ui/session_ui.tscn").instantiate() as SessionUI
	_root.add_child(session_ui)

	# Enfileira e mostra um toast
	session_ui.show_toast("Mensagem de teste")
	# Liberta imediatamente o SessionUI
	session_ui.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

	pass_test("SessionUI libertado durante toast timer termina sem SCRIPT ERROR")


func test_noray_client_freed_during_connect_await() -> void:
	var noray: NorayClient = NorayClient.new()
	_root.add_child(noray)

	# Chama connect_to_server para um IP não roteável com timeout
	# Sem await: a corrotina segue sozinha enquanto o nó é liberado.
	noray.connect_to_server.call("192.0.2.1", 12345)
	# Remove da árvore imediatamente
	noray.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	pass_test("NorayClient libertado durante connect_to_server process_frame termina sem SCRIPT ERROR")


func test_noray_client_freed_during_handshake_enet() -> void:
	var noray: NorayClient = NorayClient.new()
	_root.add_child(noray)

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	noray.handshake_enet(peer, "127.0.0.1", 9999)
	# Liberta imediatamente
	noray.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

	pass_test("NorayClient libertado durante handshake_enet timer termina sem SCRIPT ERROR")


func test_debug_bridge_sleep_and_wait_freed_cleanly() -> void:
	var bridge: DebugBridge = DebugBridge.new()
	_root.add_child(bridge)

	bridge._sleep(1.0)
	bridge._wait_until_time(10.0)
	bridge.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.05).timeout

	pass_test("DebugBridge libertado durante timer/frame awaits termina sem SCRIPT ERROR")


func test_session_manager_scene_change_await_guard() -> void:
	var sm: SessionManager = SessionManager.new()
	_root.add_child(sm)

	# Define pending scene e liberta o nó antes/durante o frame
	sm.set("_pending_scene_path", "res://world/lobby_base.tscn")
	sm.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	pass_test("SessionManager libertado durante transição de cena não gera SCRIPT ERROR")
