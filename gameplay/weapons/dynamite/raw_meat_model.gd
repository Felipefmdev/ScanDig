@tool
extends Node3D

## Carne Crua low-poly: naco vermelho facetado com gordura clara por cima e um osso a sair dos
## dois lados (estilo desenho animado). Origem no centro da base. ~0,2 × 0,08 × 0,12 m.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const MEAT: Color = Color(0.72, 0.2, 0.2)
const MEAT_DARK: Color = Color(0.55, 0.13, 0.14)
const FAT: Color = Color(0.95, 0.85, 0.78)
const BONE: Color = Color(0.94, 0.9, 0.8)


func _ready() -> void:
	ToolMesh.clear(self)
	var meat: SurfaceTool = ToolMesh.begin()
	# Naco: prisma achatado de 7 lados, mais largo em baixo; a "pele" de gordura por cima.
	ToolMesh.y_prism(meat, Vector3.ZERO, 0.0, 0.055, 0.075, 0.062, 7, 0.3, MEAT_DARK)
	ToolMesh.y_prism(meat, Vector3(0.006, 0, -0.004), 0.055, 0.07, 0.062, 0.05, 7, 0.3, MEAT)
	ToolMesh.y_prism(meat, Vector3(-0.01, 0, 0.012), 0.07, 0.078, 0.035, 0.02, 6, 0.0, ToolMesh.clean(FAT))
	var bone: SurfaceTool = ToolMesh.begin()
	LowPolyMesh.prism(bone, Vector3(-0.1, 0.035, 0.0), Vector3(0.1, 0.035, 0.0), 0.012, 0.012, 6, ToolMesh.clean(BONE))
	for x: float in [-0.1, 0.1]:
		for z: float in [-0.012, 0.012]:
			LowPolyMesh.prism(bone, Vector3(x, 0.035, z), Vector3(x + signf(x) * 0.018, 0.035, z), 0.014, 0.01, 5, ToolMesh.clean(BONE))
	ToolMesh.part(self, "Meat", meat, ToonKit.vertex_material())
	ToolMesh.part(self, "Bone", bone, ToonKit.vertex_material())
