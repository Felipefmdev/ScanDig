@tool
extends StaticBody3D

## Terreno lunar independente (#120), sem alterar gameplay, RNG global ou owner.
## A consulta de apoio interpola os mesmos triângulos de build_mesh.
const HALF: float = 70.0
const CELL: float = 2.0
const ARRIVAL: Vector2 = Vector2(0, 18)
const ARENA: Vector2 = Vector2(0, -15)
const ROUTE: Array[Vector2] = [Vector2(0,18),Vector2(-4,10),Vector2(3,3),Vector2(-4,-5),Vector2(0,-15)]
const ROUTE_HEIGHTS: Array[float] = [0.0,-0.1,-0.15,-0.4,-0.8]
const DUST: Color = Color("#aaa9b1")
const SHADOW: Color = Color("#797985")
const RIDGE: Color = Color("#c8c7cc")
## Unequal, overlapping ridge groups rather than one concentric perimeter wall.
## x/z, spread, prominence. All centers remain outside the playable bounds.
const OUTER_RIDGES: Array[Vector4] = [
	Vector4(-46,-61,16,10), Vector4(-58,-45,12,6),
	Vector4(19,-54,20,5), Vector4(43,-65,11,12),
	Vector4(59,-26,17,8), Vector4(51,34,13,11),
	Vector4(32,61,19,6), Vector4(-17,57,12,10),
	Vector4(-42,48,18,7), Vector4(-62,12,14,9),
]

func _ready() -> void:
	rebuild()

static func _vertex_height(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x,z)
	var height: float = 0.25*sin(x*0.13)*cos(z*0.11)+0.15*sin((x+z)*0.09)
	# Depressões rasas com bordas desgastadas, fora do percurso principal.
	for crater: Vector4 in [Vector4(-18,9,5,0.9),Vector4(14,10,4,0.6),Vector4(-15,-17,5,1.1),Vector4(18,-12,6,1.0)]:
		var distance: float = p.distance_to(Vector2(crater.x,crater.y))
		height -= crater.w*(1.0-smoothstep(0.0,crater.z*0.8,distance))
		height += 0.22*exp(-pow((distance-crater.z)/1.2,2.0))
	var nearest: float = INF
	var route_height: float = 0.0
	for i: int in ROUTE.size()-1:
		var segment: Vector2 = ROUTE[i+1]-ROUTE[i]
		var weight: float = clampf((p-ROUTE[i]).dot(segment)/segment.length_squared(),0.0,1.0)
		var distance: float = p.distance_to(ROUTE[i]+segment*weight)
		if distance < nearest:
			nearest = distance
			route_height = lerpf(ROUTE_HEIGHTS[i],ROUTE_HEIGHTS[i+1],weight)
	# A margem extra da rota absorve a interpolação da grade.
	height = lerpf(route_height,height,smoothstep(3.4,6.4,nearest))
	# One cell diagonal of padding keeps whole triangles flat inside R5/R9,
	# including cells whose other vertices lie beyond the playable flat disk.
	height = lerpf(0.0,height,smoothstep(7.9,10.9,p.distance_to(ARRIVAL)))
	height = lerpf(-0.8,height,smoothstep(11.9,15.9,p.distance_to(ARENA)))
	# Only the guard is square, matching the play bounds. The relief itself has no
	# shared ring radius/height: offset groups and low saddles vary the skyline.
	height += _outer_relief(x,z)
	return height

static func _outer_relief(x: float, z: float) -> float:
	var guard: float = smoothstep(30.0,42.0,maxf(absf(x),absf(z)))
	if guard <= 0.0:
		return 0.0
	var distance: float = Vector2(x+6.0,z-4.0).length()
	var relief: float = 4.6+0.025*maxf(0.0,distance-35.0)
	relief += 0.65*(1.0+sin(x*0.067+z*0.031))
	for ridge: Vector4 in OUTER_RIDGES:
		var dx: float = (x-ridge.x)/ridge.z
		var dz: float = (z-ridge.y)/(ridge.z*0.72)
		relief += ridge.w*exp(-(dx*dx+dz*dz)*1.6)
	return guard*relief

static func height_at(x: float, z: float) -> float:
	# Fora do domínio gerado, a consulta limita-se à borda existente.
	var px: float = clampf(x,-HALF,HALF)
	var pz: float = clampf(z,-HALF,HALF)
	var x0: float = minf(HALF-CELL,-HALF+floor((px+HALF)/CELL)*CELL)
	var z0: float = minf(HALF-CELL,-HALF+floor((pz+HALF)/CELL)*CELL)
	var u: float = (px-x0)/CELL
	var v: float = (pz-z0)/CELL
	var h00: float = _vertex_height(x0,z0)
	var h10: float = _vertex_height(x0+CELL,z0)
	var h01: float = _vertex_height(x0,z0+CELL)
	if u+v <= 1.0:
		return h00+u*(h10-h00)+v*(h01-h00)
	var h11: float = _vertex_height(x0+CELL,z0+CELL)
	return h11+(1.0-u)*(h01-h11)+(1.0-v)*(h10-h11)

static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var center: Vector3 = (a+b+c)/3.0
	var patch: float = clampf(0.5+0.25*sin(center.x*0.17)+0.18*cos(center.z*0.21),0.0,1.0)
	var color: Color = SHADOW.lerp(DUST,patch)
	color = color.lerp(RIDGE,clampf(center.y/12.0,0.0,0.5))
	LowPolyMesh.tri(st,a,b,c,center+Vector3.DOWN,color)

static func build_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells: int = int(2.0*HALF/CELL)
	for ix: int in cells:
		var x0: float = -HALF+float(ix)*CELL
		for iz: int in cells:
			var z0: float = -HALF+float(iz)*CELL
			var a: Vector3 = Vector3(x0,_vertex_height(x0,z0),z0)
			var b: Vector3 = Vector3(x0+CELL,_vertex_height(x0+CELL,z0),z0)
			var c: Vector3 = Vector3(x0,_vertex_height(x0,z0+CELL),z0+CELL)
			var d: Vector3 = Vector3(x0+CELL,_vertex_height(x0+CELL,z0+CELL),z0+CELL)
			_face(st,a,b,c)
			_face(st,b,d,c)
	return ToonKit.commit(st)

func rebuild() -> void:
	# Substitui somente os nós gerados, preservando filhos autorados e owner.
	for child: Node in get_children():
		if child.owner == null and child.has_meta(&"lunar_terrain_generated"):
			remove_child(child)
			child.free()
	collision_layer = 1
	collision_mask = 0
	var mesh: ArrayMesh = build_mesh()
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = &"Mesh"
	visual.set_meta(&"lunar_terrain_generated",true)
	visual.mesh = mesh
	visual.material_override = ToonKit.vertex_material(false,true)
	add_child(visual)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = &"Collision"
	collider.set_meta(&"lunar_terrain_generated",true)
	collider.shape = mesh.create_trimesh_shape()
	add_child(collider)
