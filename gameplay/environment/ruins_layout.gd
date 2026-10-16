@tool
extends Node3D

## Cenário das Ruínas (#42) montado em código a partir de uma tabela (sem centenas de nós no
## .tscn, e sem transforms gravados que o editor possa estragar): templo com fachada de pilares,
## salão, trono, muros, cripta com arco e obeliscos, pátio do guardião, blocos caídos e selva.
## As peças são RuinsStructure / FieldTreeModel geradas sem owner e assentes no RuinsTerrain.

const Structure := preload("res://gameplay/environment/ruins_structure.gd")
const TREE_SCRIPT: Script = preload("res://gameplay/environment/field_tree_model.gd")
const K := Structure.Kind

## [kind, x, z, rot_y_graus, size(Vector3) ou null]
const PIECES: Array = [
	# Fachada do templo (z = -14.6), ladeia a rampa
	[K.PILLAR, -4.0, -14.6, 0, Vector3(0.45, 3.4, 0)], [K.PILLAR, 4.0, -14.6, 0, Vector3(0.45, 3.4, 0)],
	[K.PILLAR, -6.5, -14.6, 0, Vector3(0.45, 3.4, 0)], [K.BROKEN_PILLAR, 6.5, -14.6, 0, Vector3(0.45, 3.4, 0)],
	[K.PILLAR, -9.0, -14.6, 0, Vector3(0.45, 3.4, 0)], [K.PILLAR, 9.0, -14.6, 0, Vector3(0.45, 3.4, 0)],
	[K.BROKEN_PILLAR, -11.3, -14.6, 0, Vector3(0.45, 3.4, 0)], [K.PILLAR, 11.3, -14.6, 0, Vector3(0.45, 3.4, 0)],
	# Salão: duas filas de pilares
	[K.PILLAR, -5.0, -17.5, 0, Vector3(0.42, 3.6, 0)], [K.PILLAR, 5.0, -17.5, 0, Vector3(0.42, 3.6, 0)],
	[K.BROKEN_PILLAR, -5.0, -20.5, 0, Vector3(0.42, 3.6, 0)], [K.PILLAR, 5.0, -20.5, 0, Vector3(0.42, 3.6, 0)],
	[K.PILLAR, -5.0, -23.5, 0, Vector3(0.42, 3.6, 0)], [K.BROKEN_PILLAR, 5.0, -23.5, 0, Vector3(0.42, 3.6, 0)],
	# Muros (oeste com uma abertura em z -21..-19 para a parede falsa)
	[K.WALL, -11.6, -25.0, 90, Vector3(7.2, 2.2, 0.6)], [K.WALL, -11.6, -16.8, 90, Vector3(3.6, 2.2, 0.6)],
	[K.WALL, 11.6, -21.8, 90, Vector3(13.6, 2.2, 0.6)], [K.WALL, 0.0, -28.6, 0, Vector3(23.2, 2.6, 0.6)],
	# Trono e estátuas (viradas para sul)
	[K.THRONE, 0.0, -26.6, 180, null], [K.STATUE, -3.2, -26.2, 180, null], [K.STATUE, 3.2, -26.2, 180, null],
	[K.TORCH, -7.8, -16.0, 0, null], [K.TORCH, 7.8, -16.0, 0, null],
	# Cripta: arco de entrada (a leste, sobre a rampa) e obeliscos
	[K.ARCH, -16.4, -6.0, 90, Vector3(2.4, 2.6, 0.7)],
	[K.OBELISK, -22.0, -13.0, 0, Vector3(0.6, 3.2, 0)], [K.OBELISK, -29.0, -6.0, 0, Vector3(0.6, 2.8, 0)],
	[K.BROKEN_PILLAR, -22.0, 1.0, 0, Vector3(0.4, 3.0, 0)],
	# Muretes à volta da cripta (aberta a leste, na rampa)
	[K.WALL, -19.9, -0.8, 22, Vector3(3.6, 1.1, 0.5)], [K.WALL, -24.1, -0.8, -22, Vector3(3.6, 1.1, 0.5)], [K.WALL, -27.2, -3.9, -68, Vector3(3.6, 1.1, 0.5)], [K.WALL, -27.2, -8.1, -112, Vector3(3.6, 1.1, 0.5)], [K.WALL, -24.1, -11.2, -157, Vector3(3.6, 1.1, 0.5)], [K.WALL, -19.9, -11.2, -202, Vector3(3.6, 1.1, 0.5)],
	# Pátio central: pilares partidos à volta
	[K.BROKEN_PILLAR, -8.5, 1.1, 0, Vector3(0.45, 3.4, 0)], [K.BROKEN_PILLAR, -8.5, -5.1, 0, Vector3(0.45, 3.4, 0)],
	[K.PILLAR, 6.9, -7.8, 0, Vector3(0.45, 3.4, 0)], [K.BROKEN_PILLAR, -3.1, 6.5, 0, Vector3(0.45, 3.4, 0)],
	[K.BROKEN_PILLAR, 8.8, 0.5, 0, Vector3(0.45, 3.4, 0)],
	# Pátio do guardião (a leste)
	[K.OBELISK, 16.0, -11.0, 0, Vector3(0.6, 3.6, 0)], [K.OBELISK, 24.0, -11.0, 0, Vector3(0.6, 3.6, 0)],
	[K.OBELISK, 16.0, -19.0, 0, Vector3(0.6, 3.6, 0)], [K.OBELISK, 24.0, -19.0, 0, Vector3(0.6, 3.6, 0)],
	# Blocos caídos
	[K.BLOCK, -6.0, 10.0, 20, Vector3(1.4, 0.8, 1.0)], [K.BLOCK, 10.0, 13.0, -35, Vector3(1.2, 0.7, 1.1)],
	[K.BLOCK, 15.0, -3.0, 10, Vector3(1.6, 0.9, 1.0)], [K.BLOCK, -14.0, 14.0, 60, Vector3(1.3, 0.8, 1.2)],
	[K.BLOCK, 22.0, 8.0, -15, Vector3(1.5, 1.0, 1.1)], [K.BLOCK, -25.0, 18.0, 40, Vector3(1.4, 0.8, 1.0)],
	[K.BLOCK, 4.0, 20.0, 5, Vector3(1.2, 0.8, 1.2)], [K.BLOCK, 18.0, 22.0, -50, Vector3(1.6, 0.9, 1.0)],
	[K.WALL, -18.0, 22.0, 30, Vector3(5.0, 1.6, 0.6)], [K.WALL, 24.0, -2.0, 80, Vector3(4.0, 1.2, 0.6)],
]

## Árvores da selva: [x, z, altura]
const TREES: Array = [
	[-27, 26, 4.2], [-20, 27, 3.8], [-10, 27, 4.4], [2, 27, 4.0], [12, 26, 4.6], [22, 27, 4.1], [27, 20, 3.9],
	[27, 10, 4.3], [27, -3, 3.7], [27, -25, 4.5], [20, -27, 4.0], [-27, -27, 4.4], [-27, -16, 3.9],
	[-27, 8, 4.1], [-27, 16, 4.3], [-16, 18, 3.4], [14, 17, 3.6], [-12, 6, 3.2], [17, 4, 3.5],
	[-17, -20, 3.6], [15, -26, 3.8], [-6, 18, 3.3],
]

@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()
	var i: int = 0
	for p: Array in PIECES:
		var n: Node3D = Structure.new()
		n.set(&"kind", p[0])
		if p[4] != null:
			n.set(&"size", p[4])
		n.set(&"seed_value", i + 3)
		n.name = "%s%d" % [String(Structure.Kind.keys()[p[0]]).to_pascal_case(), i]
		n.position = Vector3(p[1], RuinsTerrain.height_at(p[1], p[2]) - 0.05, p[2])
		n.rotation.y = deg_to_rad(float(p[3]))
		add_child(n)
		i += 1
	for t: Array in TREES:
		var tree: Node3D = Node3D.new()
		tree.set_script(TREE_SCRIPT)
		tree.set(&"height", float(t[2]))
		tree.set(&"canopy_radius", float(t[2]) * 0.55)
		tree.set(&"leaf_dark", Color(0.1, 0.3, 0.12))
		tree.set(&"leaf_light", Color(0.25, 0.5, 0.2))
		tree.set(&"seed_value", i)
		tree.name = "JungleTree%d" % i
		tree.position = Vector3(t[0], RuinsTerrain.height_at(t[0], t[1]) - 0.1, t[1])
		add_child(tree)
		i += 1
