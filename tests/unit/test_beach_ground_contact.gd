extends GutTest

## Dunas da Praia (estudo How to Fish, mesmo método do relevo dos mapas 3-5): tudo o que se usa
## no chão continua assente nele, o mar e o barco do Zé ficam iguais e as dunas sobem para longe
## do mar. Os spots enterrados nascem por raycast na colisão facetada: comparam-se com o chão
## real, por raycast.

const MAP: String = "res://world/map_praia.tscn"
const KINDS: Array[String] = [
	"BossAltar", "BuriedSpot", "SellPoint", "ShopOffer", "Interactable", "QuestNpc",
	"DetectorSpawn", "TriggerDigSpot", "FlagInteractable",
]
const MAX_GAP: float = 0.15
## Altura das ofertas da Banca da Praia acima do chão (em cima do balcão baixo).
const OFFER_HEIGHT: float = 0.54
## Fora do chão de propósito (y fixo na cena): o Zé está de pé no barco e o pato flutua na água.
## O chão por baixo deles não pode mudar, por isso a folga mantém-se.
const RAISED: Dictionary = {"Ze": 0.243, "Duck": 0.226}


static func _kind(n: Node) -> String:
	if n.get_parent() is GroundSnap:
		return "GroundSnap"
	var s: Script = n.get_script()
	while s != null:
		if s.get_global_name() in KINDS:
			return s.get_global_name()
		if s.resource_path.get_file() == "praia_prop.gd":
			return "PraiaProp"
		s = s.get_base_script()
	return ""


func test_points_sit_on_the_ground() -> void:
	var scene: Node3D = (load(MAP) as PackedScene).instantiate() as Node3D
	add_child_autoqfree(scene)
	await wait_frames(10)
	var checked: int = 0
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var kind: String = _kind(n)
		if kind == "" or not n is Node3D:
			continue
		# os modelos dentro do Zé e do pato seguem o pai
		if n.get_parent() != null and RAISED.has(String(n.get_parent().name)):
			continue
		var p: Vector3 = (n as Node3D).global_position
		var ground: float = BeachTerrain.height_at(p.x, p.z)
		if kind == "BuriedSpot":
			ground = _collision_height(scene, p, ground)
		var gap: float = p.y - ground
		if kind == "ShopOffer":
			gap -= OFFER_HEIGHT
		if RAISED.has(String(n.name)):
			gap -= float(RAISED[String(n.name)])
		assert_lt(absf(gap), MAX_GAP, "Praia %s (%s) a %.2f m do chão em (%.1f, %.1f)" % [
			n.name, kind, gap, p.x, p.z])
		checked += 1
	assert_gt(checked, 100, "Praia: pontos verificados")


func test_dunes_rise_inland_and_vanish_at_the_sea() -> void:
	var inland_max: float = 0.0
	for ix: int in range(-28, -8):
		for iz: int in range(-28, 28):
			inland_max = maxf(inland_max, BeachTerrain.dune_at(float(ix), float(iz)))
	assert_between(inland_max, 0.8, 1.5, "Dunas de 0.8-1.5 m longe do mar")
	for iz: int in range(-30, 31):
		for x: float in [20.0, 22.5, 25.0, 29.2, 34.0]:
			assert_eq(BeachTerrain.dune_at(x, float(iz)), 0.0, "Sem dunas junto ao mar (x=%.1f)" % x)


func test_flat_zones_and_props_stay_flat() -> void:
	for f: Vector3 in BeachTerrain.FLAT_ZONES:
		assert_eq(BeachTerrain.dune_at(f.x, f.y), 0.0, "Zona plana %s" % f)
	for p: Vector3 in BeachTerrain.PROP_ZONES:
		assert_eq(BeachTerrain.dune_at(p.x, p.y), 0.0, "Adereço %s" % p)


## Altura da colisão do chão (layer 1) por baixo de `p`; `fallback` se o raio não acertar.
func _collision_height(scene: Node3D, p: Vector3, fallback: float) -> float:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(p.x, fallback + 3.0, p.z), Vector3(p.x, fallback - 3.0, p.z), 1)
	var hit: Dictionary = space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else fallback
