extends GutTest

## #65 Fase 3 noise: barulho de cliente cavando reportado pelo próprio cliente (Refs #5 G).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const SPOT_SCENE: PackedScene = preload("res://items/buried_spot.tscn")
const MOEDA: ItemData = preload("res://items/catalog/moeda_antiga.tres")

var _root: Node3D
var _meter: DisturbanceMeter
var _player: Player


func before_each() -> void:
	_root = Node3D.new()
	add_child_autofree(_root)

	_meter = DisturbanceMeter.new()
	_meter.set_process(false)
	_root.add_child(_meter)

	_player = PLAYER_SCENE.instantiate() as Player
	_player.name = "1"
	_root.add_child(_player)


func test_client_remote_dig_result_fast_reports_noise() -> void:
	var initial_noise: float = _meter.current_noise
	var res: Dictionary = {
		"dug": true,
		"revealed": false,
		"revealed_now": false,
		"dirt_layers": 2,
		"max_layers": 3,
		"integrity": 1.0,
		"damaged": false,
		"item": MOEDA,
		"final_value": 0,
		"is_rare_variant": false,
		"is_perfect": false
	}
	_player._on_remote_dig_result(res, false, Vector3(2, 0, 2))
	assert_almost_eq(_meter.current_noise - initial_noise, DisturbanceMeter.NOISE_FAST_DIG, 0.01,
		"pazada rapida remota gera NOISE_FAST_DIG")


func test_client_remote_dig_result_careful_reports_half_noise() -> void:
	var initial_noise: float = _meter.current_noise
	var res: Dictionary = {
		"dug": true,
		"revealed": false,
		"revealed_now": false,
		"dirt_layers": 2,
		"max_layers": 3,
		"integrity": 1.0,
		"damaged": false,
		"item": MOEDA,
		"final_value": 0,
		"is_rare_variant": false,
		"is_perfect": false
	}
	_player._on_remote_dig_result(res, true, Vector3(2, 0, 2))
	assert_almost_eq(_meter.current_noise - initial_noise, DisturbanceMeter.NOISE_CAREFUL_DIG, 0.01,
		"pazada cuidadosa remota gera NOISE_CAREFUL_DIG")


func test_client_remote_dig_result_revealed_reports_reveal_noise() -> void:
	var initial_noise: float = _meter.current_noise
	var res: Dictionary = {
		"dug": true,
		"revealed": true,
		"revealed_now": true,
		"dirt_layers": 0,
		"max_layers": 3,
		"integrity": 1.0,
		"damaged": false,
		"item": MOEDA,
		"final_value": 150,
		"is_rare_variant": false,
		"is_perfect": true
	}
	_player._on_remote_dig_result(res, false, Vector3(2, 0, 2))
	var expected: float = DisturbanceMeter.NOISE_FAST_DIG + DisturbanceMeter.NOISE_REVEAL
	assert_almost_eq(_meter.current_noise - initial_noise, expected, 0.01,
		"revelacao remota gera NOISE_FAST_DIG + NOISE_REVEAL")


func test_client_remote_dig_result_already_revealed_reports_no_noise() -> void:
	var initial_noise: float = _meter.current_noise
	var res: Dictionary = {
		"dug": false,
		"revealed": true,
		"revealed_now": false,
		"dirt_layers": 0,
		"max_layers": 3,
		"integrity": 1.0,
		"damaged": false,
		"item": MOEDA,
		"final_value": 0,
		"is_rare_variant": false,
		"is_perfect": false
	}
	_player._on_remote_dig_result(res, false, Vector3(2, 0, 2))
	assert_eq(_meter.current_noise, initial_noise,
		"spot ja revelado antes nao gera barulho adicional")


func test_client_remote_dig_result_empty_dictionary_reports_no_noise() -> void:
	var initial_noise: float = _meter.current_noise
	_player._on_remote_dig_result({}, false, Vector3(2, 0, 2))
	assert_eq(_meter.current_noise, initial_noise,
		"resposta vazia (rejeitada pelo host) nao gera barulho")


func test_client_remote_dig_result_outside_tree_does_not_crash() -> void:
	var detached_player: Player = PLAYER_SCENE.instantiate() as Player
	# Não adicionado à árvore
	assert_false(detached_player.is_inside_tree())
	detached_player._on_remote_dig_result({"dug": true, "revealed": false}, false, Vector3.ZERO)
	pass_test("chamada fora da arvore nao causa erro de script")
	detached_player.free()


func test_buried_spot_dig_without_report_noise_does_not_add_to_meter() -> void:
	var initial_noise: float = _meter.current_noise
	var spot: BuriedSpot = SPOT_SCENE.instantiate() as BuriedSpot
	spot.item = MOEDA
	_root.add_child(spot)

	var res: Dictionary = spot.dig(false, 1.0, false)
	assert_true(res.get("dug", false))
	assert_eq(_meter.current_noise, initial_noise,
		"host cavando para cliente com report_noise=false nao acumula barulho localmente")
