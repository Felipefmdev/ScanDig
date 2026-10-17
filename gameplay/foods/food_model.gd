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
			# Corpo contínuo em S (segmentos que se sobrepõem), anel mais claro e torrões.
			var pink: Color = Color(0.86, 0.50, 0.46)
			var band: Color = Color(0.93, 0.66, 0.6)
			var pts: Array[Vector3] = [Vector3(-0.1, 0.02, 0.025), Vector3(-0.065, 0.024, 0.0), Vector3(-0.03, 0.05, -0.012),
				Vector3(0.0, 0.07, -0.005), Vector3(0.03, 0.055, 0.01), Vector3(0.06, 0.035, 0.02), Vector3(0.095, 0.045, 0.005)]
			for k: int in pts.size() - 1:
				LowPolyMesh.prism(st, pts[k], pts[k + 1], 0.024, 0.024, 7, band if k == 3 else pink)
				LowPolyMesh.prism(st, pts[k + 1] - (pts[k + 1] - pts[k]) * 0.12, pts[k + 1] + (pts[k + 1] - pts[k]).normalized() * 0.008, 0.025, 0.024, 7, pink.darkened(0.06))
			LowPolyMesh.prism(st, pts[pts.size() - 1], pts[pts.size() - 1] + Vector3(0.018, 0.0, 0.0), 0.024, 0.012, 7, pink)
			for c: Vector3 in [Vector3(-0.07, 0.045, 0.0), Vector3(0.0, 0.094, -0.005), Vector3(0.06, 0.06, 0.02), Vector3(0.09, 0.07, 0.0)]:
				LowPolyMesh.box(st, c, Vector3(0.012, 0.01, 0.012), Basis(Vector3.UP, c.x * 30.0), SOIL)
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
			# Concha de duas valvas fechada: roxo-escuro com estrias, rebordo perolado, alga.
			var shell: Color = Color(0.27, 0.25, 0.4)
			LowPolyMesh.prism(st, Vector3(-0.065, 0.0, 0.0), Vector3(0.065, 0.0, 0.0), 0.035, 0.012, 9, shell.darkened(0.15))
			LowPolyMesh.box(st, Vector3(0.005, 0.033, 0.0), Vector3(0.12, 0.008, 0.1), Basis.IDENTITY, Color(0.86, 0.88, 0.94))
			LowPolyMesh.prism(st, Vector3(-0.065, 0.04, 0.0), Vector3(0.065, 0.04, 0.0), 0.05, 0.016, 9, shell)
			for k: int in 4:
				var x: float = -0.03 + 0.02 * float(k)
				LowPolyMesh.box(st, Vector3(0.0, 0.08, x), Vector3(0.11, 0.006, 0.004), Basis.IDENTITY, shell.lightened(0.15))
			LowPolyMesh.prism(st, Vector3(0.0, 0.03, 0.04), Vector3(0.005, -0.01, 0.06), 0.004, 0.003, 4, Color(0.42, 0.52, 0.18))
		"batata_esquecida":
			# Batata deitada e irregular: três volumes castanhos, olhos claros e terra.
			var potato: Color = Color(0.6, 0.42, 0.24)
			LowPolyMesh.prism(st, Vector3(-0.07, 0.045, 0.0), Vector3(0.07, 0.05, 0.005), 0.045, 0.04, 8, potato)
			LowPolyMesh.prism(st, Vector3(-0.04, 0.055, -0.01), Vector3(0.03, 0.06, 0.0), 0.05, 0.046, 7, potato.darkened(0.08))
			LowPolyMesh.prism(st, Vector3(0.05, 0.04, 0.01), Vector3(0.085, 0.042, 0.012), 0.032, 0.02, 6, potato.lightened(0.05))
			for e: Vector3 in [Vector3(0.02, 0.098, 0.01), Vector3(-0.045, 0.085, -0.035), Vector3(0.06, 0.07, 0.03)]:
				LowPolyMesh.box(st, e, Vector3(0.01, 0.008, 0.01), Basis.IDENTITY, potato.lightened(0.35))
			LowPolyMesh.box(st, Vector3(-0.02, 0.03, 0.042), Vector3(0.035, 0.018, 0.008), Basis.IDENTITY, SOIL)
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
			# Larva gorda em arco: gomos laranja arredondados que brilham, cabeça escura, cinza.
			var lava_glow: Color = Color(0.98, 0.45, 0.12)
			var lava_dark: Color = Color(0.8, 0.3, 0.08)
			LowPolyMesh.box(st, Vector3(0.0, 0.006, 0.0), Vector3(0.17, 0.012, 0.1), Basis.IDENTITY, Color(0.16, 0.14, 0.13))
			for k: int in 5:
				var x: float = -0.06 + 0.03 * float(k)
				var r: float = 0.038 - 0.004 * absf(float(k) - 2.0)
				var y: float = 0.04 + 0.006 * (2.0 - absf(float(k) - 2.0))
				LowPolyMesh.prism(glow, Vector3(x - 0.014, y, 0.0), Vector3(x + 0.014, y, 0.0), r, r * 0.92, 9, lava_glow if k % 2 == 0 else lava_dark)
			LowPolyMesh.prism(st, Vector3(-0.078, 0.036, 0.0), Vector3(-0.098, 0.03, 0.0), 0.022, 0.014, 7, Color(0.15, 0.1, 0.08))
			glow_color = Color(0.6, 0.22, 0.04)

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
