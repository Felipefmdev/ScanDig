extends StaticBody3D

## Draw the existing authored step colliders. Heights and route stay unchanged.
func _ready() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step_name: StringName in [&"Step1", &"Step2", &"Step3"]:
		var step: CollisionShape3D = get_node(NodePath(step_name)) as CollisionShape3D
		var box: BoxShape3D = step.shape as BoxShape3D
		var top: float = step.position.y + box.size.y * 0.5
		LowPolyMesh.box(st, Vector3(step.position.x, top * 0.5, step.position.z),
			Vector3(box.size.x, top, box.size.z), Basis.IDENTITY, RuinasProp.STONE)
	var model: MeshInstance3D = MeshInstance3D.new()
	model.name = &"StoneSteps"
	model.mesh = ToonKit.commit(st)
	model.material_override = RuinasProp._shared_material()
	add_child(model)
