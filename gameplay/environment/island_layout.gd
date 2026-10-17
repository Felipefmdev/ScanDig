@tool
class_name IslandLayout
extends Node3D

## Cenário da Ilha do Tesouro (#113), montado em código a partir de tabelas determinísticas
## (todos os peers veem o mesmo): palmeiras na orla e na selva, rochas, o cais de chegada com o
## barco, um naufrágio antigo e, à vista de todos, pilhas de ouro, baús abertos e ídolos
## espalhados pela ilha — com o maior tesouro no planalto do Monte do Tesouro (#114).
## Peças sem owner (#47), assentes no IslandTerrain.

const KENNEY: String = "res://assets/models/kenney_pirate/%s.glb"
const TK := TreasureModel.Kind

## [x, z, altura, curvatura]
const PALMS: Array = [
	[12.0, 12.0, 5.8, 1.1], [15.0, -8.0, 5.2, 0.9], [-4.0, 17.0, 6.0, 1.2], [-15.0, 10.0, 5.4, 0.8],
	[-18.0, -2.0, 5.6, 1.0], [6.0, -17.0, 5.0, 0.9], [-1.0, -14.0, 6.2, 0.6], [19.0, 7.0, 4.8, 1.3],
	[9.0, 16.5, 5.0, 0.7], [-11.0, 15.5, 5.6, 1.0], [-17.0, -12.0, 5.2, 0.9], [2.0, 19.0, 4.6, 1.2],
]
## [kind, x, z, rot_y°, size] — tesouros à vista; o último fica no planalto do monte.
const TREASURES: Array = [
	[TK.GOLD_PILE, 6.0, -8.0, 20, 1.0], [TK.CHEST, 11.0, -3.5, -30, 1.0], [TK.IDOL, -2.5, 9.0, 160, 1.0],
	[TK.GOLD_PILE, -12.0, 4.0, 70, 0.9], [TK.CHEST, 2.0, 13.5, 200, 0.9], [TK.GOLD_PILE, 14.0, 9.0, -60, 0.8],
	[TK.IDOL, -14.0, -6.0, 90, 1.1], [TK.CHEST, -5.5, -12.5, 30, 1.1], [TK.GOLD_PILE, -8.0, -9.0, 0, 1.6],
]
## [modelo, x, z, rot_y°, escala]
const PROPS: Array = [
	["structure-platform-dock", 20.5, 2.0, 90, 1.0], ["boat-row-small", 22.5, 4.2, 15, 1.0],
	["ship-wreck", -19.0, 17.0, 140, 1.2], ["rocks-sand-a", 16.0, -14.0, 30, 1.4],
	["rocks-sand-b", -20.0, 6.0, 0, 1.3], ["rocks-a", -10.0, -14.0, 60, 1.2], ["rocks-b", -3.0, -6.5, 10, 1.0],
	["rocks-sand-c", 10.0, 19.0, 110, 1.2], ["barrel", 18.5, 0.6, 0, 0.8], ["crate", 18.7, 3.6, 25, 0.8],
	["flag-pirate", -8.0, -11.6, 0, 1.0],
]

@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()


func _ready() -> void:
	rebuild()


static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, IslandTerrain.height_at(x, z), z)


func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()
	var i: int = 0
	for p: Array in PALMS:
		var palm: Node3D = PalmModel.new()
		palm.name = "Palm%d" % i
		palm.set(&"height", p[2])
		palm.set(&"bend", p[3])
		palm.set(&"seed_value", 70 + i)
		palm.position = ground(p[0], p[1]) + Vector3.DOWN * 0.1
		palm.rotation.y = float(i) * 1.7
		add_child(palm)
		i += 1
	i = 0
	for t: Array in TREASURES:
		var tm: TreasureModel = TreasureModel.new()
		tm.name = "Treasure%d" % i
		tm.kind = t[0]
		tm.size = t[4]
		tm.seed_value = 300 + i
		tm.position = ground(t[1], t[2]) + Vector3.DOWN * 0.04
		tm.rotation.y = deg_to_rad(float(t[3]))
		tm.add_to_group(&"island_treasures")
		add_child(tm)
		i += 1
	i = 0
	for p: Array in PROPS:
		var path: String = KENNEY % p[0]
		if not ResourceLoader.exists(path):
			continue
		var n: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		n.name = "Prop%d" % i
		n.position = ground(p[1], p[2])
		if p[0] == "structure-platform-dock" or p[0] == "boat-row-small":
			n.position.y = maxf(n.position.y, -0.35)
		n.rotation.y = deg_to_rad(float(p[3]))
		n.scale = Vector3.ONE * float(p[4])
		add_child(n)
		ToonKit.apply_to_imported(n)
		i += 1


## Posição (no chão) do maior tesouro, no planalto do Monte do Tesouro.
static func main_treasure_position() -> Vector3:
	var t: Array = TREASURES[TREASURES.size() - 1]
	return ground(t[1], t[2])
