extends GutTest

func test_lunar_boss_is_visible_to_existing_projectile_enemy_mask() -> void:
	var path: String = "res://gameplay/enemies/boss/lunar_warden.gd"
	var boss: EnemyBase = (load(path) as Script).new() as EnemyBase
	add_child_autofree(boss)
	boss.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var projectile: Script = load("res://gameplay/weapons/slingshot/slingshot_projectile.gd")
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(boss.global_position+Vector3(0,1.2,3),boss.global_position+Vector3(0,1.2,0),int(projectile.ENEMY_LAYER_MASK))
	var hit: Dictionary = boss.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(),"Existing optional projectiles must detect the boss collider")
	if not hit.is_empty(): assert_same(hit.get("collider"),boss)
