extends GutTest

class Patient extends CharacterBody3D:
	var health: float = 60.0
	var max_health: float = 100.0
	var is_downed: bool = false
	var local: bool = true
	func is_local() -> bool: return local
	func heal(amount: float) -> void: health = minf(health + amount, max_health)

func test_comfort_zone_heals_only_living_local_player_without_overlap_dependency() -> void:
	var fire: Node3D = load("res://gameplay/quests/geleira/cabin_fireplace.gd").new()
	add_child_autofree(fire)
	fire.set_process(false)
	var patient: Patient = Patient.new()
	add_child_autofree(patient)
	patient.add_to_group(&"player")
	patient.position = Vector3(1, 0, 0)
	fire.call(&"_apply_healing")
	assert_eq(patient.health, 65.0, "Comfort works even when Area overlap cache is empty")
	patient.position.x = 5
	fire.call(&"_apply_healing")
	assert_eq(patient.health, 65.0, "Outside radius is excluded")
	patient.position.x = 1
	patient.local = false
	fire.call(&"_apply_healing")
	assert_eq(patient.health, 65.0, "Never tick remote owner's health twice")
	patient.local = true
	patient.is_downed = true
	fire.call(&"_apply_healing")
	assert_eq(patient.health, 65.0, "Fire is not a revive")
	patient.is_downed = false
	patient.health = 0
	fire.call(&"_apply_healing")
	assert_eq(patient.health, 0.0)
