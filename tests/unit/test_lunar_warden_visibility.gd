extends GutTest

## RED prepared after rendered inspection: exposed core is inside the torso.
## Tests actual rendered triangles, not the simplified physics capsule.
## Source stays frozen until root executes this RED. No fallback implementation.
const SOURCE: String = "res://gameplay/enemies/boss/lunar_warden.gd"


func _first_hit(start: Vector3, finish: Vector3, faces: PackedVector3Array) -> float:
	var nearest: float = INF
	for i: int in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start,finish,faces[i],faces[i+1],faces[i+2])
		if hit != null:
			nearest = minf(nearest,start.distance_to(hit as Vector3))
	return nearest


func _world_faces(mesh: MeshInstance3D) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for vertex: Vector3 in mesh.mesh.get_faces():
		result.append(mesh.global_transform*vertex)
	return result


func test_exposed_core_is_first_visible_surface_from_front() -> void:
	# Calibrate depth ordering independently of the boss geometry.
	var sample_start: Vector3 = Vector3(0,0,4)
	var sample_end: Vector3 = Vector3(0,0,-1)
	var front: PackedVector3Array = PackedVector3Array([Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(0,1,1)])
	var rear: PackedVector3Array = PackedVector3Array([Vector3(-1,-1,0),Vector3(1,-1,0),Vector3(0,1,0)])
	assert_lt(_first_hit(sample_start,sample_end,front),_first_hit(sample_start,sample_end,rear),"Calibration: torso in front occludes core behind")
	assert_true(ResourceLoader.exists(SOURCE),"Staged boss required")
	if not ResourceLoader.exists(SOURCE): return
	var boss: EnemyBase = (load(SOURCE) as Script).new() as EnemyBase
	assert_not_null(boss)
	if boss == null: return
	add_child_autoqfree(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	var elapsed: float = 0.0
	while StringName(boss.call(&"get_combat_state")) != &"EXPOSED" and elapsed < 12.0:
		boss.call(&"_physics_process",0.05)
		elapsed += 0.05
	assert_eq(StringName(boss.call(&"get_combat_state")),&"EXPOSED")
	var core: MeshInstance3D = boss.get_node_or_null("ExposedCore") as MeshInstance3D
	assert_not_null(core,"Actual core mesh must exist")
	if core == null: return
	var core_faces: PackedVector3Array = _world_faces(core)
	var blockers: PackedVector3Array = PackedVector3Array()
	for child: Node in boss.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh == core or not mesh.is_visible_in_tree(): continue
		# GroundWarning is attack UI geometry, not the boss body.
		if mesh is GroundWarning: continue
		blockers.append_array(_world_faces(mesh))
	assert_gt(blockers.size(),0,"Real torso/body faces are included")
	# Model face/eyes use local +Z as front. Center-height frontal view,
	# with three nearby sightlines to avoid accepting a single edge crack.
	var camera: Vector3 = boss.to_global(Vector3(0,1.5,4.0))
	for lateral: float in [-0.08,0.0,0.08]:
		var target: Vector3 = core.global_position + boss.global_basis.x*lateral
		var core_distance: float = _first_hit(camera,target,core_faces)
		var blocker_distance: float = _first_hit(camera,target,blockers)
		assert_true(is_finite(core_distance),"Frontal sightline intersects real core faces")
		assert_true(core_distance+0.0001 < blocker_distance,"EXPOSED: real torso must not occlude core; core="+str(core_distance)+" blocker="+str(blocker_distance)+" lateral="+str(lateral))
