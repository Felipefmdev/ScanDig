## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_client_drop.gd
extends SceneTree
var lost: bool = false
func _w(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	SessionManager.instance.host_lost.connect(func() -> void: lost = true)
	NetworkManager.instance.join_game("127.0.0.1", 7790)
	await _w(8.0)
	print("CLIENT host_lost=", lost, " scene=", current_scene.name, " in_exp=", SessionManager.instance.is_in_expedition())
	quit(0)
