@tool
class_name CraterLayout
extends Node3D

## Cenário da Cratera (#44) montado em código a partir de uma tabela determinística:
##   - Módulos da estação de pesquisa da Dra. Vega;
##   - Torres de antena e transmissão;
##   - Arcos colossais de basalto e rocha de impacto;
##   - Agulhas e cachos de cristais alienígenas violeta e ciano;
##   - Rochas e blocos de meteorito fumegantes;
##   - Pilares de basalto e muros de ruína extraterrestre.
##
## As peças são CraterStructure geradas sem owner e assentes no CraterTerrain.

const CraterTerrain = preload("res://gameplay/environment/crater_terrain.gd")
const Structure := preload("res://gameplay/environment/crater_structure.gd")
const K := Structure.Kind

## [kind, x, z, rot_y_graus, size(Vector3) ou null]
const PIECES: Array = [
	# Estação de Pesquisa da Dra. Vega (a noroeste, planalto seguro)
	[K.RESEARCH_MODULE, -14.0, 10.0, 15, null],

	# Torre principal de comunicações da estação
	[K.ANTENNA_TOWER, -17.5, 12.0, 0, Vector3(0.5, 6.5, 0.5)],

	# Pilar alto de basalto columnar para o puzzle de baixa gravidade (a sudoeste)
	[K.CRATER_PILLAR, -16.0, -14.0, 30, Vector3(2.2, 5.8, 2.2)],

	# Arcos colossais de basalto
	[K.CRATER_ARCH, 0.0, -22.0, 0, Vector3(7.5, 5.2, 1.5)],
	[K.CRATER_ARCH, -20.0, 0.0, 75, Vector3(6.5, 4.8, 1.4)],

	# Torres de antena de retransmissão periféricas
	[K.ANTENNA_TOWER, 14.0, 16.0, 0, Vector3(0.5, 5.5, 0.5)],
	[K.ANTENNA_TOWER, -4.0, -24.0, 0, Vector3(0.5, 5.5, 0.5)],

	# Muros de ruínas alienígenas
	[K.ALIEN_RUIN_WALL, 16.0, -10.0, 45, Vector3(5.5, 2.4, 0.7)],
	[K.ALIEN_RUIN_WALL, 12.0, -18.0, -30, Vector3(4.8, 2.2, 0.7)],

	# Agulhas e cachos de cristais violeta/ciano
	[K.CRYSTAL_SPIRE, 8.0, -6.0, 0, Vector3(1.4, 4.5, 1.4)],
	[K.CRYSTAL_SPIRE, -8.0, -8.0, 25, Vector3(1.2, 4.2, 1.2)],
	[K.CRYSTAL_SPIRE, 18.0, 6.0, -40, Vector3(1.3, 4.8, 1.3)],
	[K.CRYSTAL_SPIRE, -12.0, -22.0, 15, Vector3(1.5, 5.0, 1.5)],
	[K.CRYSTAL_SPIRE, 22.0, -8.0, -10, Vector3(1.2, 3.8, 1.2)],
	[K.CRYSTAL_SPIRE, 4.0, 20.0, 50, Vector3(1.1, 3.6, 1.1)],

	# Rochas e blocos de meteorito
	[K.METEOR_BOULDER, 6.0, 2.0, 30, Vector3(2.0, 1.4, 1.6)],
	[K.METEOR_BOULDER, -6.0, 4.0, -20, Vector3(1.8, 1.2, 1.5)],
	[K.METEOR_BOULDER, 12.0, 10.0, 45, Vector3(2.4, 1.6, 2.0)],
	[K.METEOR_BOULDER, -10.0, 18.0, -35, Vector3(1.9, 1.3, 1.7)],
	[K.METEOR_BOULDER, 20.0, -16.0, 15, Vector3(2.2, 1.5, 1.9)],
	[K.METEOR_BOULDER, -22.0, -8.0, 60, Vector3(2.5, 1.7, 2.1)],
	[K.METEOR_BOULDER, 2.0, -14.0, -15, Vector3(1.7, 1.1, 1.4)],
	[K.METEOR_BOULDER, -18.0, 18.0, 20, Vector3(2.1, 1.4, 1.8)]
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
		n.set(&"seed_value", i + 20)
		n.name = "%s%d" % [String(Structure.Kind.keys()[p[0]]).to_pascal_case(), i]
		var px: float = float(p[1])
		var pz: float = float(p[2])
		n.position = Vector3(px, CraterTerrain.height_at(px, pz) - 0.05, pz)
		n.rotation.y = deg_to_rad(float(p[3]))
		add_child(n)
		i += 1
