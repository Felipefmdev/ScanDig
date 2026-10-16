class_name MammothAltar
extends BossAltar

## Altar do Mamute na Geleira Eterna (#43):
## Presas ancestrais de marfim curvadas emergindo do gelo milenar e blocos glaciais.
## Cavar até ao fim acorda o chefe principal: o Mamute Congelado (FrozenMammoth).
##
## Carrega a cena condicionalmente (pois o Sonda está a criar os chefes em paralelo).

const MAMMOTH_SCENE_PATH: String = "res://gameplay/enemies/boss/frozen_mammoth.tscn"
const DEFAULT_LABEL: String = "Um titã ancestral dorme sob o gelo eterno... [cavar]"

const IVORY_COLOR: Color = Color(0.94, 0.92, 0.84)
const ICE_COLOR: Color = Color(0.55, 0.78, 0.92)
const ICE_DEEP: Color = Color(0.35, 0.60, 0.76)
const SNOW_WHITE: Color = Color(0.96, 0.98, 1.0)


func _ready() -> void:
	if boss_scene == null:
		if ResourceLoader.exists(MAMMOTH_SCENE_PATH):
			boss_scene = load(MAMMOTH_SCENE_PATH) as PackedScene
	if label_text == "Algo grande dorme aqui... [cavar]":
		label_text = DEFAULT_LABEL
	super._ready()


func _build_totem() -> void:
	_totem = Node3D.new()
	_totem.name = "Totem"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Duas grandes presas de marfim pré-histórico curvando para cima e para fora
	for sx: float in [-1.0, 1.0]:
		var p0: Vector3 = Vector3(sx * 0.45, 0.0, 0.3)
		var p1: Vector3 = Vector3(sx * 0.75, 1.1, 0.1)
		var p2: Vector3 = Vector3(sx * 0.65, 1.9, -0.3)
		var p3: Vector3 = Vector3(sx * 0.35, 2.3, -0.5)
		LowPolyMesh.prism(st, p0, p1, 0.16, 0.12, 6, IVORY_COLOR)
		LowPolyMesh.prism(st, p1, p2, 0.12, 0.08, 6, IVORY_COLOR)
		LowPolyMesh.prism(st, p2, p3, 0.08, 0.015, 5, IVORY_COLOR)

	# Anel de monólitos e blocos facetados de gelo azul ao redor do ponto de escavação
	for k: int in range(8):
		var ang: float = TAU * float(k) / 8.0
		var pos: Vector3 = Vector3(cos(ang) * 0.85, 0.0, sin(ang) * 0.85)
		var top_p: Vector3 = pos + Vector3(0.0, 0.35 + float(k % 3) * 0.15, 0.0)
		LowPolyMesh.prism(st, pos, top_p, 0.14, 0.08, 5, ICE_COLOR if k % 2 == 0 else ICE_DEEP)

	_totem.add_child(LowPolyMesh.commit(st, "Mesh", LowPolyMesh.make_material()))
	add_child(_totem)

	_label = Label3D.new()
	_label.name = "Label"
	_label.text = label_text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.6, 0.0)
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.modulate = Color(0.65, 0.88, 1.0)
	add_child(_label)
