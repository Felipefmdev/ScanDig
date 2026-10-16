@tool
class_name GlacierLayout
extends Node3D

## Cenário da Geleira Eterna (#43) montado em código a partir de uma tabela determinística:
##   - Cabana de madeira do Velho Björn;
##   - Iglu no planalto sudoeste;
##   - Boca da gruta de gelo a norte (abrigo do Yeti);
##   - Arco colossal de gelo na passagem para o norte;
##   - Agulhas de gelo (spires) a rodear a bacia do lago gelado e cumes glaciais;
##   - Blocos de gelo espalhados e pinheiros árticos nevados.
##
## As peças são GlacierStructure geradas sem owner e assentes no GlacierTerrain.

const GlacierTerrain = preload("res://gameplay/environment/glacier_terrain.gd")
const Structure := preload("res://gameplay/environment/glacier_structure.gd")
const K := Structure.Kind

## [kind, x, z, rot_y_graus, size(Vector3) ou null]
const PIECES: Array = [
	# Cabana do Velho Björn (a noroeste, no planalto seguro)
	[K.CABIN, -14.0, 8.0, 30, null],

	# Iglu dos exploradores (a sudoeste, próximo ao cume)
	[K.IGLOO, -20.0, -18.0, -45, Vector3(2.6, 2.0, 2.6)],

	# Entrada da Gruta de Gelo do Yeti (a norte, cravada no paredão glacial)
	[K.ICE_CAVE_ARCH, 0.0, -28.5, 0, Vector3(5.5, 4.4, 3.0)],

	# Arco Colossal de Gelo (entre o lago e a rota norte)
	[K.ICE_ARCH, 4.0, -16.0, 45, Vector3(6.5, 5.0, 1.4)],

	# Pináculos e agulhas de gelo (em volta do lago gelado a este)
	[K.ICE_SPIRE, 23.0, -6.0, 0, Vector3(1.2, 5.2, 1.2)],
	[K.ICE_SPIRE, 22.0, -13.0, 20, Vector3(1.0, 4.4, 1.0)],
	[K.ICE_SPIRE, 16.0, -17.5, -30, Vector3(0.9, 3.8, 0.9)],
	[K.ICE_SPIRE, 7.0, -7.0, 15, Vector3(1.1, 4.8, 1.1)],
	[K.ICE_SPIRE, 12.0, 1.0, -10, Vector3(0.85, 3.6, 0.85)],

	# Pináculos na crista ocidental
	[K.ICE_SPIRE, -24.0, 4.0, 0, Vector3(1.1, 5.0, 1.1)],
	[K.ICE_SPIRE, -25.0, -8.0, 40, Vector3(1.3, 5.8, 1.3)],
	[K.ICE_SPIRE, -15.0, -25.0, -25, Vector3(1.0, 4.2, 1.0)],

	# Blocos e rochedos de gelo caídos
	[K.ICE_BLOCK, 8.0, -2.0, 35, Vector3(1.8, 1.2, 1.5)],
	[K.ICE_BLOCK, 20.0, 3.0, -20, Vector3(1.5, 1.0, 1.4)],
	[K.ICE_BLOCK, -8.0, -12.0, 50, Vector3(1.6, 1.1, 1.3)],
	[K.ICE_BLOCK, -6.0, 14.0, -15, Vector3(2.0, 1.4, 1.8)],
	[K.ICE_BLOCK, 12.0, 16.0, 60, Vector3(1.7, 1.2, 1.4)],
	[K.ICE_BLOCK, -18.0, 20.0, 10, Vector3(1.9, 1.3, 1.6)],
	[K.ICE_BLOCK, 22.0, -22.0, -45, Vector3(2.2, 1.5, 1.8)],

	# Pinheiros nevados (floresta polar protegida do vento)
	[K.SNOW_PINE, -10.0, 12.0, 0, Vector3(1.0, 4.5, 1.0)],
	[K.SNOW_PINE, -18.0, 11.0, 45, Vector3(1.0, 4.8, 1.0)],
	[K.SNOW_PINE, -16.0, 4.0, -30, Vector3(1.0, 3.9, 1.0)],
	[K.SNOW_PINE, -8.0, 5.0, 20, Vector3(1.0, 4.2, 1.0)],
	[K.SNOW_PINE, -4.0, 20.0, 60, Vector3(1.0, 5.0, 1.0)],
	[K.SNOW_PINE, 4.0, 22.0, -15, Vector3(1.0, 4.4, 1.0)],
	[K.SNOW_PINE, 15.0, 20.0, 35, Vector3(1.0, 4.6, 1.0)],
	[K.SNOW_PINE, -24.0, 16.0, -40, Vector3(1.0, 4.1, 1.0)],
	[K.SNOW_PINE, -26.0, -2.0, 15, Vector3(1.0, 4.7, 1.0)],
	[K.SNOW_PINE, -10.0, -22.0, 70, Vector3(1.0, 4.3, 1.0)],
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
		n.set(&"seed_value", i + 10)
		n.name = "%s%d" % [String(Structure.Kind.keys()[p[0]]).to_pascal_case(), i]
		var px: float = float(p[1])
		var pz: float = float(p[2])
		n.position = Vector3(px, GlacierTerrain.height_at(px, pz) - 0.05, pz)
		n.rotation.y = deg_to_rad(float(p[3]))
		add_child(n)
		i += 1
