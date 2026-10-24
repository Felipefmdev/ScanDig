extends Node3D

## #120 placement only: existing rocket asset, four terrain-bearing supports.
## Caller places this root at (-23,0,21); no terrain/scene/gameplay mutation.
const ROCKET: PackedScene = preload("res://assets/models/scandig_space/lunar_rocket.glb")
const TERRAIN: Script = preload("res://gameplay/environment/crater_terrain.gd")
const FOOT_RECTS: Array[Rect2] = [
	Rect2(-1.8,-.114,.2,.228), Rect2(1.6,-.114,.2,.228),
	Rect2(-.114,-1.8,.228,.2), Rect2(-.114,1.6,.228,.2),
]
const SUPPORT_COLOR: Color = Color("#68717d")
const GENERATED: StringName = &"lua120_crater_rocket_generated"

func _ready() -> void:
	build()

## CraterTerrain's CELL=1 grid uses triangles (00,10,01)/(10,11,01).
## Interpolate those vertices, not the nonlinear height function between them.
static func _ground_height(x: float, z: float) -> float:
	var x0: float = floor(x)
	var z0: float = floor(z)
	var u: float = x-x0
	var v: float = z-z0
	var a: float = TERRAIN.height_at(x0,z0)
	var b: float = TERRAIN.height_at(x0+1.0,z0)
	var c: float = TERRAIN.height_at(x0,z0+1.0)
	if u+v <= 1.0:
		return a+u*(b-a)+v*(c-a)
	var d: float = TERRAIN.height_at(x0+1.0,z0+1.0)
	return d+(1.0-u)*(c-d)+(1.0-v)*(b-d)

func _foot_corners(rect: Rect2) -> Array[Vector2]:
	return [rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)]

func build() -> Node3D:
	if not is_inside_tree():
		return null
	for child: Node in get_children():
		if child.owner == null and child.has_meta(GENERATED):
			remove_child(child)
			child.free()
	var top_world: float = -INF
	for rect: Rect2 in FOOT_RECTS:
		for at: Vector2 in _foot_corners(rect):
			var point: Vector3 = global_transform*Vector3(at.x,0,at.y)
			top_world = maxf(top_world,_ground_height(point.x,point.z))
	top_world += .04
	var rocket: Node3D = ROCKET.instantiate() as Node3D
	rocket.name = &"Rocket"
	rocket.scale = Vector3.ONE*2.0
	rocket.position.y = to_local(Vector3(global_position.x,top_world,global_position.z)).y
	rocket.set_meta(GENERATED,true)
	add_child(rocket)
	ToonKit.apply_to_imported(rocket)
	_add_rocket_collision(rocket)
	var supports: Node3D = Node3D.new()
	supports.name = &"Supports"
	supports.set_meta(GENERATED,true)
	add_child(supports)
	for i: int in FOOT_RECTS.size():
		_add_support(supports,FOOT_RECTS[i],top_world,i)
	return rocket

func _add_support(parent: Node3D, rect: Rect2, top_world: float, index: int) -> void:
	var lower: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for at: Vector2 in _foot_corners(rect):
		var point: Vector3 = global_transform*Vector3(at.x,0,at.y)
		lower.append(to_local(Vector3(point.x,_ground_height(point.x,point.z),point.z)))
		upper.append(to_local(Vector3(point.x,top_world,point.z)))
	var inside: Vector3 = (lower[0]+lower[2]+upper[0]+upper[2])*.25
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 4:
		var next: int = (i+1)%4
		LowPolyMesh.quad(st,lower[i],lower[next],upper[next],upper[i],inside,SUPPORT_COLOR)
	LowPolyMesh.quad(st,lower[3],lower[2],lower[1],lower[0],inside,SUPPORT_COLOR.darkened(.1))
	LowPolyMesh.quad(st,upper[0],upper[1],upper[2],upper[3],inside,SUPPORT_COLOR.lightened(.12))
	var mesh: ArrayMesh = ToonKit.commit(st)
	var support: Node3D = Node3D.new()
	support.name = "FootSupport%d" % index
	parent.add_child(support)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = &"Mesh"
	visual.mesh = mesh
	visual.material_override = ToonKit.vertex_material(false,true)
	support.add_child(visual)
	_add_mesh_collision(support,mesh.get_faces())

func _add_rocket_collision(rocket: Node3D) -> void:
	var faces: PackedVector3Array = PackedVector3Array()
	for child: Node in rocket.find_children("*","MeshInstance3D",true,false):
		var visual: MeshInstance3D = child as MeshInstance3D
		var transform: Transform3D = rocket.global_transform.affine_inverse()*visual.global_transform
		for vertex: Vector3 in visual.mesh.get_faces():
			faces.append(transform*vertex)
	_add_mesh_collision(rocket,faces)

func _add_mesh_collision(parent: Node3D, faces: PackedVector3Array) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = &"Body"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = &"Collision"
	collision.shape = shape
	body.add_child(collision)
