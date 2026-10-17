class_name TreasureHoard
extends Node3D

## Tesouros à vista da Ilha do Tesouro (#113): ao chegar, o host espalha achados de topo (do
## item_pool do mapa) junto às pilhas, baús e ídolos do IslandLayout — apanháveis logo, sem cavar.
## O PickupsRoot replica-os para todos. O maior tesouro (planalto do monte) fica de fora: é do
## chefe disfarçado (#114).

@export var map_data: MapData = null
@export var per_treasure: int = 1
@export var seed_value: int = 113

var spawned: int = 0


func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var tree: SceneTree = get_tree()
	await tree.physics_frame
	await tree.physics_frame
	if is_inside_tree():
		scatter()


## Host: um achado por tesouro à vista (exceto o principal). Devolve quantos espalhou.
func scatter() -> int:
	if map_data == null or map_data.item_pool.is_empty():
		return 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var main: Vector3 = IslandLayout.main_treasure_position()
	for n: Node in get_tree().get_nodes_in_group(&"island_treasures"):
		var t: Node3D = n as Node3D
		if t == null or not is_instance_valid(t) or Vector2(t.global_position.x - main.x, t.global_position.z - main.z).length() < 1.0:
			continue
		for k: int in per_treasure:
			var item: ItemData = map_data.item_pool[rng.randi() % map_data.item_pool.size()]
			if item == null:
				continue
			var a: float = rng.randf() * TAU
			var pos: Vector3 = t.global_position + Vector3(cos(a) * 1.1, 0.6, sin(a) * 1.1)
			var c: CarriedItem = CarriedItem.create(item, item.base_value, rng.randf_range(0.75, 1.0), false)
			ItemPickup.spawn(self, c, pos, Vector3.UP * 1.5)
			spawned += 1
	return spawned
