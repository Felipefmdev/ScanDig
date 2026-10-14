extends GutTest

const KING_SCENE: PackedScene = preload("res://gameplay/enemies/boss/king_crab.tscn")

var arena: Node3D
var king: KingCrab


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)
	king = KING_SCENE.instantiate() as KingCrab
	arena.add_child(king)
	king.wake_immediately()


func _crab_count() -> int:
	var n: int = 0
	for c: Node in arena.get_children():
		if c is Crab:
			n += 1
	return n


func test_stats() -> void:
	assert_eq(king.max_health, 600.0)
	assert_eq(king.health, 600.0)
	assert_true(king.is_in_group("enemies"))
	assert_true(king.is_in_group("bosses"))
	assert_eq(king.collision_layer, 8, "inimigos na layer 4 (valor 8)")


func test_invulnerable_while_emerging() -> void:
	var fresh: KingCrab = KING_SCENE.instantiate() as KingCrab
	arena.add_child(fresh)
	fresh.take_damage(50.0)
	assert_eq(fresh.health, 600.0)


func test_weak_point_doubles_damage() -> void:
	king.take_damage(10.0)
	assert_eq(king.health, 590.0, "fora do ponto fraco: dano normal")
	king.call("_enter_state", KingCrab.State.SLAM_STUCK)
	assert_true(king.is_weak_point_exposed())
	king.take_damage(10.0)
	assert_eq(king.health, 570.0, "pinça presa na areia: dano x2")


func test_reinforcements_at_66_and_33_percent() -> void:
	watch_signals(king)
	king.take_damage(190.0)  # 410/600 = 68%
	assert_eq(_crab_count(), 0, "ainda acima de 66%")
	king.take_damage(20.0)  # 390/600 = 65%
	var first: int = _crab_count()
	assert_between(first, 2, 3, "1.º reforço: 2-3 caranguejos")
	king.take_damage(10.0)
	assert_eq(_crab_count(), first, "não repete o mesmo limiar")
	king.take_damage(200.0)  # 180/600 = 30%
	assert_between(_crab_count() - first, 2, 3, "2.º reforço a 33%")
	assert_signal_emit_count(king, "reinforcements_called", 2)


func test_big_hit_crossing_both_thresholds_calls_both() -> void:
	king.take_damage(420.0)  # 30%
	assert_between(_crab_count(), 4, 6)


func test_phase_two_below_half() -> void:
	watch_signals(king)
	var speed_p1: float = king.get_move_speed()
	assert_eq(king.get_charge_repeats(), 1)
	king.take_damage(290.0)  # 51.7%
	assert_eq(king.phase, 1)
	king.take_damage(20.0)  # 48.3%
	assert_eq(king.phase, 2)
	assert_signal_emitted_with_parameters(king, "phase_changed", [2])
	assert_eq(king.get_charge_repeats(), 2, "investida repete 2x na fase 2")
	assert_gt(king.get_move_speed(), speed_p1, "mais rápido na fase 2")


func test_net_stun_is_capped_and_repellent_ignored() -> void:
	king.stun(5.0)
	assert_true(king.is_stunned())
	assert_almost_eq(king.get("_stun_left") as float, KingCrab.NET_STUN_CAP, 0.001)
	king.flee_from(Vector3.ZERO, 8.0)
	assert_false(king.is_fleeing(), "repelente não afeta o rei")


func test_death_emits_boss_defeated_and_drops_crown() -> void:
	watch_signals(king)
	king.take_damage(1000.0)
	assert_false(king.is_alive())
	assert_eq(king.state, KingCrab.State.DYING)
	# Avança a animação de queda até largar a coroa
	for i: int in range(130):
		king._process(1.0 / 60.0)
	assert_signal_emitted_with_parameters(king, "boss_defeated", [&"king_crab"])
	var crown: bool = false
	for c: Node in arena.get_children():
		if c is ItemPickup and (c as ItemPickup).carried != null \
				and (c as ItemPickup).carried.item.id == "coroa_caranguejo_rei":
			crown = true
	assert_true(crown, "larga a Coroa do Caranguejo-Rei")
