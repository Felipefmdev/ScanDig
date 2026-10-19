extends GutTest

## N2: corvo, morcego e lobo com voz própria (não a da gaivota), todas na categoria creature; a
## pazada de outro jogador soa no ponto cavado, e a do próprio jogador não toca duas vezes.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")


func test_crow_and_bat_have_their_own_cries() -> void:
	var gull: Seagull = Seagull.new()
	var crow: Crow = Crow.new()
	var bat: Bat = Bat.new()
	assert_eq(gull.caw_sfx, SFX.SEAGULL_CAW, "a gaivota continua com o seu grito")
	assert_eq(crow.caw_sfx, SFX.CROW_CAW, "corvo grasna")
	assert_eq(crow.dive_sfx, SFX.CROW_CAW)
	assert_eq(bat.caw_sfx, SFX.BAT_SCREECH, "morcego guincha")
	assert_eq(bat.dive_sfx, SFX.BAT_SCREECH)
	gull.free()
	crow.free()
	bat.free()


func test_new_voices_are_creatures_and_load() -> void:
	for list: Array[String] in [SFX.CROW_CAW, SFX.BAT_SCREECH, SFX.WOLF_GROWL, SFX.WOLF_HOWL]:
		assert_gt(list.size(), 0)
		for path: String in list:
			assert_eq(SFX.category_of(path), &"creature", "categoria creature: %s" % path)
			assert_not_null(load(path) as AudioStream, "carrega: %s" % path)
			assert_false(SFX.SEAGULL_CAW.has(path), "não é a gaivota: %s" % path)


func _spawn_player(peer_id: int, pos: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate() as Player
	p.name = str(peer_id)
	p.set_multiplayer_authority(peer_id)
	add_child_autofree(p)
	p.global_position = pos
	return p


func test_remote_dig_plays_at_spot_only_for_other_players() -> void:
	var local: Player = _spawn_player(1, Vector3(20.0, 0.0, 0.0))
	var remote: Player = _spawn_player(2, Vector3.ZERO)
	assert_true(local.is_local())
	assert_false(remote.is_local())
	var at: Vector3 = Vector3(1.0, 0.0, 0.0)
	var sfx: AudioStreamPlayer3D = Player.play_remote_dig(get_tree(), at)
	assert_not_null(sfx, "pazada do outro jogador soa aqui")
	if sfx != null:
		assert_almost_eq(sfx.global_position.distance_to(at), 0.0, 0.01, "no ponto cavado")
		assert_eq(SFX.category_of(str(sfx.stream.resource_path)), &"dig")
		sfx.queue_free()
	assert_null(Player.play_remote_dig(get_tree(), Vector3(20.5, 0.0, 0.0)),
		"a pazada do próprio jogador já tocou no impacto da pá")
	assert_null(Player.play_remote_dig(get_tree(), Vector3(10.0, 0.0, 0.0)), "longe de todos: nada")
