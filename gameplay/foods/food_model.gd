@tool
extends Node3D

## Modelos low-poly das comidas escavadas (docs/art/PROMPTS.md, "Comidas escavadas").
## Cada comida assenta em y = 0 e tem ~0.15-0.25 m de dimensão máxima.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

@export var food_id: String = ""

const SOIL: Color = Color(0.32, 0.22, 0.15)
const STONE: Color = Color(0.48, 0.48, 0.50)
const ICE: Color = Color(0.82, 0.92, 0.98)


func _ready() -> void:
	ToolMesh.clear(self)
	var st: SurfaceTool = ToolMesh.begin()
	var glow: SurfaceTool = ToolMesh.begin()
	var glow_color: Color = Color.BLACK

	match food_id:
		"minhoca":
			# Minhoca gorda em forma de S com anel mais claro
			var pink: Color = Color(0.86, 0.50, 0.54)
			var band: Color = Color(0.93, 0.68, 0.70)
			ToolMesh.y_prism(st, Vector3(-0.06, 0.0, -0.03), 0.0, 0.02, 0.022, 0.022, 6, 0.0, pink)
			ToolMesh.y_prism(st, Vector3(-0.03, 0.0, 0.01), 0.0, 0.024, 0.026, 0.026, 6, 0.3, band)
			ToolMesh.y_prism(st, Vector3(0.01, 0.0, 0.03), 0.0, 0.022, 0.024, 0.024, 6, -0.2, pink)
			ToolMesh.y_prism(st, Vector3(0.05, 0.0, 0.00), 0.0, 0.020, 0.022, 0.022, 6, 0.2, pink)
			ToolMesh.y_prism(st, Vector3(0.08, 0.0, -0.02), 0.0, 0.016, 0.018, 0.010, 5, 0.0, pink)
			# Salpicos de terra
			LowPolyMesh.box(st, Vector3(-0.01, 0.022, 0.02), Vector3(0.008, 0.008, 0.008), Basis.IDENTITY, SOIL)
			LowPolyMesh.box(st, Vector3(0.03, 0.020, -0.01), Vector3(0.007, 0.007, 0.007), Basis.IDENTITY, SOIL)

		"tatuira":
			# Tatuíra da praia (caranguejo-da-areia oval com carapaça bege e patas recolhidas)
			var shell: Color = Color(0.88, 0.80, 0.68)
			var shell_dark: Color = Color(0.72, 0.64, 0.52)
			var belly: Color = Color(0.92, 0.88, 0.78)
			ToolMesh.y_prism(st, Vector3.ZERO, 0.0, 0.025, 0.055, 0.048, 7, 0.0, shell_dark)
			ToolMesh.y_prism(st, Vector3(0.0, 0.0, 0.005), 0.025, 0.055, 0.050, 0.035, 7, 0.0, shell)
			# Patas dobradas por baixo
			for side: float in [-1.0, 1.0]:
				for k: int in 3:
					var z: float = -0.02 + 0.02 * float(k)
					LowPolyMesh.prism(st, Vector3(0.045 * side, 0.01, z), Vector3(0.065 * side, 0.005, z + 0.008), 0.006, 0.003, 4, belly)

		"marisco":
			# Concha escura roxo-azulada com rebordo nacarado e alga
			var mussel_dark: Color = Color(0.24, 0.22, 0.35)
			var mussel_rim: Color = Color(0.68, 0.72, 0.82)
			var algae: Color = Color(0.38, 0.58, 0.25)
			LowPolyMesh.prism(st, Vector3(0.0, 0.015, -0.05), Vector3(0.0, 0.035, 0.04), 0.025, 0.045, 6, mussel_dark)
			LowPolyMesh.box(st, Vector3(0.0, 0.036, 0.035), Vector3(0.012, 0.006, 0.025), Basis.IDENTITY, mussel_rim)
			LowPolyMesh.prism(st, Vector3(0.02, 0.02, 0.01), Vector3(0.035, 0.035, -0.02), 0.008, 0.003, 4, algae)

		"batata_esquecida":
			# Batata irregular com terra e olhos a brotar
			var potato: Color = Color(0.58, 0.42, 0.26)
			var potato_dark: Color = Color(0.44, 0.30, 0.18)
			var sprout: Color = Color(0.46, 0.68, 0.30)
			ToolMesh.y_prism(st, Vector3.ZERO, 0.0, 0.035, 0.065, 0.058, 7, 0.2, potato_dark)
			ToolMesh.y_prism(st, Vector3(0.008, 0.0, -0.006), 0.035, 0.065, 0.060, 0.045, 7, -0.2, potato)
			# Olhos / brotos verdes
			LowPolyMesh.prism(st, Vector3(0.04, 0.045, 0.02), Vector3(0.055, 0.065, 0.025), 0.007, 0.002, 4, sprout)
			LowPolyMesh.prism(st, Vector3(-0.03, 0.05, -0.03), Vector3(-0.045, 0.07, -0.035), 0.006, 0.002, 4, sprout)

		"cogumelo_cripta":
			# Três cogumelos pálidos em pedaço de pedra
			var cap: Color = Color(0.82, 0.84, 0.86)
			var stem: Color = Color(0.92, 0.90, 0.85)
			var cap_spot: Color = Color(0.45, 0.60, 0.75)
			LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.0), Vector3(0.12, 0.03, 0.10), Basis(Vector3.UP, 0.4), STONE)
			# Cogumelo maior
			LowPolyMesh.prism(st, Vector3(-0.02, 0.03, 0.0), Vector3(-0.02, 0.09, 0.0), 0.012, 0.010, 6, stem)
			ToolMesh.y_prism(st, Vector3(-0.02, 0.0, 0.0), 0.085, 0.115, 0.040, 0.018, 7, 0.0, cap)
			LowPolyMesh.box(glow, Vector3(-0.02, 0.118, 0.0), Vector3(0.012, 0.006, 0.012), Basis.IDENTITY, cap_spot)
			# Cogumelo médio
			LowPolyMesh.prism(st, Vector3(0.03, 0.03, 0.02), Vector3(0.03, 0.07, 0.02), 0.009, 0.008, 5, stem)
			ToolMesh.y_prism(st, Vector3(0.03, 0.0, 0.02), 0.065, 0.09, 0.028, 0.014, 6, 0.2, cap)
			# Cogumelo pequeno
			LowPolyMesh.prism(st, Vector3(0.01, 0.03, -0.03), Vector3(0.01, 0.055, -0.03), 0.007, 0.006, 5, stem)
			ToolMesh.y_prism(st, Vector3(0.01, 0.0, -0.03), 0.05, 0.07, 0.020, 0.010, 6, -0.2, cap)
			glow_color = Color(0.1, 0.25, 0.4)

		"liquen_gelado":
			# Tufo de líquen ártico verde-menta em rocha com gelo
			var lichen: Color = Color(0.55, 0.74, 0.65)
			var lichen_dark: Color = Color(0.38, 0.55, 0.48)
			LowPolyMesh.box(st, Vector3(0.0, 0.015, 0.0), Vector3(0.13, 0.03, 0.11), Basis.IDENTITY, STONE)
			for k: int in 6:
				var a: float = TAU * float(k) / 6.0 + 0.2
				var r: float = 0.035 if k % 2 == 0 else 0.02
				LowPolyMesh.prism(st, Vector3(sin(a) * r, 0.03, cos(a) * r), Vector3(sin(a) * (r + 0.025), 0.07, cos(a) * (r + 0.025)), 0.016, 0.004, 5, lichen if k % 2 == 0 else lichen_dark)
			LowPolyMesh.box(glow, Vector3(0.0, 0.04, 0.0), Vector3(0.05, 0.015, 0.05), Basis(Vector3.UP, 0.3), ICE)
			glow_color = Color(0.2, 0.4, 0.5)

		"larva_termica":
			# Larva vulcânica gorda cor de brasa com brilho interior
			var lava_glow: Color = Color(0.98, 0.42, 0.12)
			var lava_dark: Color = Color(0.65, 0.20, 0.08)
			var head: Color = Color(0.25, 0.18, 0.18)
			LowPolyMesh.box(st, Vector3(0.0, 0.01, 0.0), Vector3(0.14, 0.02, 0.09), Basis.IDENTITY, Color(0.18, 0.18, 0.20))
			ToolMesh.y_prism(glow, Vector3(-0.04, 0.0, 0.0), 0.015, 0.045, 0.028, 0.024, 6, 0.0, lava_dark)
			ToolMesh.y_prism(glow, Vector3(0.0, 0.0, 0.0), 0.015, 0.055, 0.034, 0.028, 7, 0.0, lava_glow)
			ToolMesh.y_prism(glow, Vector3(0.04, 0.0, 0.0), 0.015, 0.045, 0.028, 0.022, 6, 0.0, lava_glow)
			LowPolyMesh.prism(st, Vector3(0.065, 0.03, 0.0), Vector3(0.085, 0.03, 0.0), 0.018, 0.010, 5, head)
			glow_color = Color(0.8, 0.3, 0.05)

	ToolMesh.part(self, "FoodMesh", st, ToonKit.vertex_material())
	var glow_mesh: ArrayMesh = glow.commit()
	if glow_mesh.get_surface_count() > 0:
		var gmat: ShaderMaterial = ToonKit.vertex_material(true, true)
		gmat.set_shader_parameter(&"emission_color", glow_color)
		var gmi: MeshInstance3D = MeshInstance3D.new()
		gmi.name = "Glow"
		gmi.mesh = ToonKit.bake_outline_normals(glow_mesh)
		gmi.material_override = gmat
		add_child(gmi)
