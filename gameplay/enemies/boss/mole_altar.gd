class_name MoleAltar
extends BossAltar

## Altar do Campo Antigo, no centro do círculo de pedras: laje de pedra com musgo e um
## monte de terra remexida. Cavar até ao fim acorda a Toupeira Gigante (GiantMole).

const GIANT_MOLE_SCENE: PackedScene = preload("res://gameplay/enemies/boss/giant_mole.tscn")
const LABEL: String = "Algo cava debaixo das pedras... [cavar]"
const STONE: Color = Color(0.55, 0.55, 0.52)
const STONE_DARK: Color = Color(0.4, 0.4, 0.38)
const MOSS: Color = Color(0.35, 0.5, 0.2)
const SOIL: Color = Color(0.36, 0.25, 0.15)


func _ready() -> void:
	if boss_scene == null:
		boss_scene = GIANT_MOLE_SCENE
	if label_text == "Algo grande dorme aqui... [cavar]":
		label_text = LABEL
	super._ready()


func _build_totem() -> void:
	_totem = Node3D.new()
	_totem.name = "Totem"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Laje inclinada sobre duas pedras, como um pequeno dólmen
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.95, 0.35, 0.4 + 0.3 * side), Vector3(0.22, 0.7, 0.22), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.95, 0.78, 0.4), Vector3(0.45, 0.14, 0.95), Basis(Vector3.RIGHT, 0.08), STONE)
	LowPolyMesh.box(st, Vector3(0.95, 0.87, 0.4), Vector3(0.38, 0.04, 0.8), Basis(Vector3.RIGHT, 0.08), MOSS)
	# Anel de terra remexida e calhaus à volta do ponto
	for k: int in range(9):
		var ang: float = TAU * float(k) / 9.0
		var p: Vector3 = Vector3(cos(ang), 0.03, sin(ang)) * 0.75
		if k % 2 == 0:
			LowPolyMesh.box(st, p + Vector3(0, 0.05, 0), Vector3(0.16, 0.12, 0.14), Basis(Vector3.UP, ang), STONE)
		else:
			LowPolyMesh.prism(st, p, p + Vector3(0, 0.1, 0), 0.12, 0.03, 5, SOIL)
	_totem.add_child(LowPolyMesh.commit(st, "Mesh", LowPolyMesh.make_material()))
	add_child(_totem)

	_label = Label3D.new()
	_label.name = "Label"
	_label.text = label_text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.3, 0.0)
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.modulate = Color(1.0, 0.85, 0.45)
	add_child(_label)
