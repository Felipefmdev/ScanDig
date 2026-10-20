class_name CraterAltar
extends BossAltar

## Altar da Cratera (#44):
## Monólitos de obsidiana cósmica e cristais pulsantes que guardam o chefe da Cratera:
## O Dorminhoco (TheSleeper).
##
## Carrega a cena condicionalmente (res://gameplay/enemies/boss/the_sleeper.tscn).
## Sem overlay de vitória próprio (#115): o the_sleeper reporta a própria derrota ao core e não
## é mais o final; vitória e créditos ficam na VictoryScreen (chefe final: gold_colossus).

const SLEEPER_SCENE_PATH: String = "res://gameplay/enemies/boss/the_sleeper.tscn"
const DEFAULT_LABEL: String = "O Dorminhoco aguarda no abismo cósmico... [cavar]"

const OBSIDIAN_DARK: Color = Color(0.12, 0.10, 0.15)
const VIOLET_RUNE: Color = Color(0.68, 0.25, 0.90)
const CYAN_CRYSTAL: Color = Color(0.25, 0.95, 0.90)
const METEOR_RUST: Color = Color(0.52, 0.30, 0.18)


func _ready() -> void:
	if boss_scene == null:
		if ResourceLoader.exists(SLEEPER_SCENE_PATH):
			boss_scene = load(SLEEPER_SCENE_PATH) as PackedScene
	if label_text == "Algo grande dorme aqui... [cavar]":
		label_text = DEFAULT_LABEL
	super._ready()


func _build_totem() -> void:
	_totem = Node3D.new()
	_totem.name = "Totem"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 4 Monólitos de obsidiana inclinados convergindo para o centro
	for k: int in range(4):
		var ang: float = TAU * float(k) / 4.0
		var p0: Vector3 = Vector3(cos(ang) * 1.3, 0.0, sin(ang) * 1.3)
		var p1: Vector3 = Vector3(cos(ang) * 0.9, 2.2, sin(ang) * 0.9)
		var p2: Vector3 = Vector3(cos(ang) * 0.5, 3.1, sin(ang) * 0.5)
		LowPolyMesh.prism(st, p0, p1, 0.22, 0.16, 5, OBSIDIAN_DARK)
		LowPolyMesh.prism(st, p1, p2, 0.16, 0.04, 5, OBSIDIAN_DARK)

		# Glifo cósmico em cada monólito
		var r_pos: Vector3 = (p0 + p1) * 0.5 + Vector3(0.0, 0.0, 0.05)
		LowPolyMesh.box(st, r_pos, Vector3(0.08, 0.45, 0.08), Basis.IDENTITY, VIOLET_RUNE)

	# Anel de cristais ciano e fragmentos de meteorito no chão
	for k: int in range(8):
		var ang: float = TAU * float(k) / 8.0 + 0.2
		var p: Vector3 = Vector3(cos(ang) * 0.85, 0.0, sin(ang) * 0.85)
		var top_p: Vector3 = p + Vector3(0.0, 0.35 + float(k % 2) * 0.25, 0.0)
		var col: Color = CYAN_CRYSTAL if k % 2 == 0 else METEOR_RUST
		LowPolyMesh.prism(st, p, top_p, 0.12, 0.02, 5, col)

	_totem.add_child(LowPolyMesh.commit(st, "Mesh", LowPolyMesh.make_material()))
	add_child(_totem)

	_label = Label3D.new()
	_label.name = "Label"
	_label.text = label_text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 3.5, 0.0)
	_label.font_size = 48
	_label.outline_size = 14
	_label.pixel_size = 0.007
	_label.modulate = Color(0.85, 0.55, 1.0)
	add_child(_label)
