extends GutTest

## #16: a mochila do jogador usa CoreGameState.get_backpack_capacity().

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _saved: Dictionary = {}


func before_each() -> void:
	_saved = GameState.instance.get_snapshot()


func after_each() -> void:
	GameState.instance.apply_snapshot(_saved)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _set_backpack(level: int) -> void:
	var snap: Dictionary = GameState.instance.get_snapshot()
	var levels: Dictionary = snap["upgrade_levels"]
	levels["backpack"] = level
	GameState.instance.apply_snapshot(snap)


func _spawn_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	return player


func test_capacity_matches_backpack_level_on_spawn() -> void:
	for level: int in [0, 1, 2, 3]:
		_set_backpack(level)
		var expected: int = GameState.instance.get_backpack_capacity()
		assert_eq(expected, 3 + level)
		var player: Player = _spawn_player()
		assert_eq(player.inventory.capacity, expected, "nivel %d" % level)
		assert_eq(player.inventory.slots.size(), expected)
		assert_eq(player.hotbar.get_child_count(), expected, "hotbar com %d slots" % expected)
		player.free()


func test_late_snapshot_grows_backpack() -> void:
	_set_backpack(0)
	var player: Player = _spawn_player()
	assert_eq(player.inventory.capacity, 3)
	_set_backpack(3)
	assert_eq(player.inventory.capacity, 6)


func test_late_snapshot_never_shrinks_mid_expedition() -> void:
	_set_backpack(2)
	var player: Player = _spawn_player()
	assert_eq(player.inventory.capacity, 5)
	_set_backpack(0)
	assert_eq(player.inventory.capacity, 5)
