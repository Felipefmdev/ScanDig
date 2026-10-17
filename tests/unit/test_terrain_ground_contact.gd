extends GutTest

## Relevo dos mapas 3-5 (estudo How to Fish): tudo o que se usa no chão tem de continuar assente
## nele (nada a flutuar nem enterrado). Carrega cada mapa e compara a altura de cada ponto
## interativo com height_at() do terreno. As ofertas da Banca ficam por cima do balcão.
## Os spots enterrados nascem por raycast na colisão (malha facetada de 1 m, que nas arestas
## pode afastar-se ~0.2 m da fórmula): esses comparam-se com o chão real, por raycast.

const MAPS: Array = [
	["res://world/map_ruinas.tscn", "res://gameplay/environment/ruins_terrain.gd"],
	["res://world/map_geleira.tscn", "res://gameplay/environment/glacier_terrain.gd"],
	["res://world/map_cratera.tscn", "res://gameplay/environment/crater_terrain.gd"],
]
## Classes que assentam no chão (por class_name do script ou de uma base).
const KINDS: Array[String] = [
	"BossAltar", "BuriedSpot", "SellPoint", "ShopOffer", "Interactable", "QuestNpc",
	"DetectorSpawn", "RuinasProp", "GeleiraProp", "CrateraProp", "TriggerDigSpot",
	"FlagInteractable", "CraterStructure", "GlacierStructure",
]
const MAX_GAP: float = 0.15
## Altura das ofertas da Banca acima do chão (em cima do balcão).
const OFFER_HEIGHT: float = 0.9


static func _kind(n: Node) -> String:
	var s: Script = n.get_script()
	while s != null:
		if s.get_global_name() in KINDS:
			return s.get_global_name()
		s = s.get_base_script()
	return ""


func test_interactive_points_sit_on_the_ground(params: Array = use_parameters(MAPS)) -> void:
	var scene: Node = (load(params[0]) as PackedScene).instantiate()
	add_child_autoqfree(scene)
	await wait_frames(10)
	var terrain: Script = load(params[1])
	var checked: int = 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var kind: String = _kind(n)
		if kind == "" or not n is Node3D:
			continue
		var p: Vector3 = (n as Node3D).global_position
		var ground: float = float(terrain.call(&"height_at", p.x, p.z))
		if kind == "BuriedSpot":
			ground = _collision_height(scene as Node3D, p, ground)
		var gap: float = p.y - ground
		if kind == "ShopOffer":
			gap -= OFFER_HEIGHT
		assert_lt(absf(gap), MAX_GAP, "%s %s (%s) a %.2f m do chão em (%.1f, %.1f)" % [
			params[0].get_file(), n.name, kind, gap, p.x, p.z])
		checked += 1
	assert_gt(checked, 40, "%s: pontos verificados" % params[0].get_file())


## Altura da colisão do chão (layer 1) por baixo de `p`; `fallback` se o raio não acertar.
func _collision_height(scene: Node3D, p: Vector3, fallback: float) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(p.x, fallback + 3.0, p.z), Vector3(p.x, fallback - 3.0, p.z), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else fallback
