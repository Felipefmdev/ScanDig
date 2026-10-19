## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_host_drop.gd
extends SceneTree
func _w(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("net_host_drop")
	print("HOST host_game=", NetworkManager.instance.host_game(7790))
	SessionManager.instance.request_start_expedition("praia")
	await _w(1.0)
	print("HOST scene=", current_scene.name)
	var t: float = 0.0
	while NetworkManager.instance.connected_players.size() < 2 and t < 15.0:
		await _w(0.5); t += 0.5
	print("HOST players=", NetworkManager.instance.connected_players.size())
	quit(0)
