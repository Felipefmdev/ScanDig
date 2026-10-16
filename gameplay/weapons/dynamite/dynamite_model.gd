@tool
extends Node3D

## Dinamite low-poly: três bananas vermelhas atadas com fita gasta e um pavio torto a sair
## da de cima. Origem no centro da base; bananas deitadas ao longo de X. ~0,24 × 0,1 × 0,1 m.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const STICK_R: float = 0.024
const STICK_HALF: float = 0.11
const RED: Color = Color(0.86, 0.86, 0.86)
const PAPER_END: Color = Color(0.93, 0.86, 0.7)
const TAPE: Color = Color(0.78, 0.72, 0.58)
const FUSE: Color = Color(0.2, 0.17, 0.13)
const STICKS: Array[Vector3] = [Vector3(0.0, STICK_R, -0.026), Vector3(0.0, STICK_R, 0.026), Vector3(0.0, STICK_R + 0.044, 0.0)]


func _ready() -> void:
	ToolMesh.clear(self)
	var sticks: SurfaceTool = ToolMesh.begin()
	var ends: SurfaceTool = ToolMesh.begin()
	for c: Vector3 in STICKS:
		LowPolyMesh.prism(sticks, c + Vector3(-STICK_HALF, 0, 0), c + Vector3(STICK_HALF, 0, 0), STICK_R, STICK_R, 7, RED)
		for s: float in [-1.0, 1.0]:
			LowPolyMesh.prism(ends, c + Vector3(s * STICK_HALF, 0, 0), c + Vector3(s * (STICK_HALF + 0.006), 0, 0),
				STICK_R * 0.95, STICK_R * 0.8, 7, ToolMesh.clean(PAPER_END))
	var deco: SurfaceTool = ToolMesh.begin()
	for x: float in [-0.055, 0.055]:
		LowPolyMesh.prism(deco, Vector3(x - 0.012, 0.045, 0.0), Vector3(x + 0.012, 0.045, 0.0), 0.062, 0.062, 8, ToolMesh.clean(TAPE))
	var fuse: Array[Vector3] = [Vector3(STICK_HALF, 0.068, 0.0), Vector3(STICK_HALF + 0.03, 0.085, 0.01),
		Vector3(STICK_HALF + 0.045, 0.11, -0.005), Vector3(STICK_HALF + 0.05, 0.135, 0.008)]
	for i: int in fuse.size() - 1:
		LowPolyMesh.prism(deco, fuse[i], fuse[i + 1], 0.004, 0.004, 4, ToolMesh.clean(FUSE))
	ToolMesh.part(self, "Sticks", sticks, ToolMesh.prop_material(&"paint_red"))
	ToolMesh.part(self, "Ends", ends, ToonKit.vertex_material())
	ToolMesh.part(self, "Deco", deco, ToonKit.vertex_material())
