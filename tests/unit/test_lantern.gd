extends GutTest

## #42: Lanterna de Magnésio (LanternFlash.fire): cone, alcance e fuga dos morcegos.

const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")

var world: Node3D
var shooter: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)
	shooter = Node3D.new()
	world.add_child(shooter)


func _crab(pos: Vector3) -> Crab:
	var c: Crab = CRAB_SCENE.instantiate() as Crab
	world.add_child(c)
	c.global_position = pos
	c.call(&"_enter_state", Crab.State.CHASE)
	return c


func test_cone_and_range() -> void:
	var front: Crab = _crab(Vector3(0.0, 0.0, -4.0))
	var behind: Crab = _crab(Vector3(0.0, 0.0, 4.0))
	var far: Crab = _crab(Vector3(0.0, 0.0, -20.0))
	var hits: int = LanternFlash.fire(Vector3(0.0, 0.5, 0.0), Vector3.FORWARD, shooter)
	assert_eq(hits, 1)
	assert_true(front.is_stunned())
	assert_false(behind.is_stunned())
	assert_false(far.is_stunned())


func test_light_shy_enemies_flee() -> void:
	var bat: Crab = _crab(Vector3(1.0, 0.0, -3.0))
	bat.add_to_group(LanternFlash.GROUP_FLEES)
	LanternFlash.fire(Vector3(0.0, 0.5, 0.0), Vector3.FORWARD, shooter)
	assert_true(bat.is_fleeing())
