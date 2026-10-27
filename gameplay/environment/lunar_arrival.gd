@tool
extends Node3D

## Composição de chegada lunar (#120/#175), exportada no Blender a partir do Space Kit CC0.
const TERRAIN: Script = preload("res://gameplay/environment/lunar_terrain.gd")
const ROCKET: PackedScene = preload("res://assets/models/scandig_space/lunar_rocket.glb")
const GENERATOR: PackedScene = preload("res://assets/models/scandig_space/lunar_generator.glb")
const SUPPLIES: PackedScene = preload("res://assets/models/scandig_space/lunar_supplies.glb")


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		if child.has_meta(&"lunar_arrival_generated"):
			remove_child(child)
			child.free()
	var rocket: Node3D = _place(ROCKET, &"Rocket", Vector2(7,18),0.0)
	var faces: PackedVector3Array = PackedVector3Array()
	for child: Node in rocket.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		var local: Transform3D = rocket.global_transform.affine_inverse() * mesh.global_transform
		for vertex: Vector3 in mesh.mesh.get_faces():
			faces.append(local * vertex)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = &"Body"
	rocket.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = &"Collision"
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	_place(GENERATOR, &"Generator", Vector2(5.8,22.8),0.0)
	_place(SUPPLIES, &"Supplies", Vector2(9,20.5),deg_to_rad(20.0))


func _place(scene: PackedScene, label: StringName, at: Vector2, yaw: float) -> Node3D:
	var group: Node3D = scene.instantiate() as Node3D
	group.name = label
	group.scale = Vector3.ONE * 2.0
	group.rotation.y = yaw
	group.position = Vector3(at.x,0.0,at.y)
	group.set_meta(&"lunar_arrival_generated",true)
	add_child(group)
	var ground_y: float = -INF
	for child: Node in group.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		var bounds: AABB = mesh.get_aabb()
		for i: int in 8:
			var corner: Vector3 = bounds.get_endpoint(i)
			if absf(corner.y-bounds.position.y) > 0.001: continue
			var point: Vector3 = mesh.global_transform * corner
			ground_y = maxf(ground_y,float(TERRAIN.height_at(point.x,point.z))-point.y)
	group.position.y = ground_y
	ToonKit.apply_to_imported(group)
	return group
