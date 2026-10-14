## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/net_client.gd
extends SceneTree
var summary: Dictionary = {}
func _w(s: float) -> void:
	await create_timer(s).timeout
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _w(1.0)
	SessionManager.instance.expedition_ended.connect(func(s: Dictionary) -> void: summary = s)
	print("CLIENT join=", NetworkManager.instance.join_game("127.0.0.1", 7790))
	await _w(3.0)
	print("CLIENT scene_after_join=", current_scene.name, " in_exp=", SessionManager.instance.is_in_expedition())
	await _w(6.0)
	print("CLIENT scene_end=", current_scene.name, " day=", GameState.instance.current_day, " money=", GameState.instance.team_money, " museum=", GameState.instance.discovered_items)
	print("CLIENT summary_entries=", summary.get("entries", []))
	quit(0)
