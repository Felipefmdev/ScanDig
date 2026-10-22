extends GutTest

class RequestedFloe extends IceFloe:
	var requested: bool = false
	func apply_blast_damage(epicenter: Vector3, radius: float) -> void:
		requested = true
		super.apply_blast_damage(epicenter, radius)

func test_replica_updates_state_health_and_physical_support_without_local_simulation() -> void:
	var floe: Node3D = load("res://gameplay/environment/ice_floe.gd").new()
	add_child_autofree(floe)
	floe.set_physics_process(false)
	assert_true(floe.has_method(&"apply_network_state"), "Replica contract exists")
	if not floe.has_method(&"apply_network_state"): return
	floe.call(&"apply_network_state", 3, 0.0, 5.0)
	await get_tree().physics_frame
	assert_eq(floe.get("state"), 3)
	assert_true((floe.get("_col_shape") as CollisionShape3D).disabled)
	floe.call(&"apply_network_state", 1, 0.4, 0.0)
	await get_tree().physics_frame
	assert_eq(floe.get("state"), 1)
	assert_almost_eq(float(floe.get("health")), 0.4, 0.0001)
	assert_false((floe.get("_col_shape") as CollisionShape3D).disabled)

func test_lake_floes_opt_into_host_authority() -> void:
	var lake: Node3D = load("res://gameplay/environment/frozen_lake.gd").new()
	add_child_autofree(lake)
	lake.set_physics_process(false)
	for floe: Node in lake.get("floes"):
		assert_eq(floe.get("host_authoritative"), true, "Map ice must have a single authority")

func test_lake_blast_api_uses_the_same_authoritative_request_as_dynamite() -> void:
	var lake: FrozenLake = FrozenLake.new()
	add_child_autofree(lake)
	lake.set_physics_process(false)
	var floe: RequestedFloe = RequestedFloe.new()
	add_child_autofree(floe)
	lake.floes.append(floe)
	lake.apply_blast_damage(Vector3.ZERO, 1.0)
	assert_true(floe.requested, "Public lake API must not bypass the floe's network path")
