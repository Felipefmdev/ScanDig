extends RigidBody3D

## Dinamite (estudo How to Fish: explosões empurram tudo, inclusive quem lançou).
## Banana física com pavio aceso; ao fim do pavio explode no lugar onde parou.
## Quem lança simula a física e aplica tudo pelo caminho de rede de cada coisa:
## inimigos por request_hit/stun, itens por ItemPickup.push, jogadores por apply_knockback,
## buracos por BuriedSpot.dig/request_dig. Os outros peers só veem a explosão (rpc no player).

const FUSE: float = 2.2
const DAMAGE: float = 60.0
const ENEMY_RADIUS: float = 4.5
const PUSH_RADIUS: float = 5.0
const PLAYER_RADIUS: float = 4.0
const DIG_RADIUS: float = 2.5
const STUN: float = 1.0
const ITEM_PUSH: float = 6.0
const PLAYER_PUSH: float = 9.0
const SELF_DAMAGE: float = 10.0
## Bem mais alto que uma pazada (8): explodir o chão acorda o subsolo.
const NOISE: float = 30.0
const COLOR: Color = Color(0.85, 0.2, 0.15)
const MODEL: Script = preload("res://gameplay/weapons/dynamite/dynamite_model.gd")

var thrower: Node3D = null
var _fuse_left: float = FUSE
var _spark: CPUParticles3D = null
var _exploded: bool = false


func _ready() -> void:
	mass = 0.4
	collision_layer = 0
	collision_mask = 1
	continuous_cd = true
	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.05
	cap.height = 0.3
	col.shape = cap
	add_child(col)
	var model: Node3D = MODEL.new()
	model.position = Vector3(0, -0.06, 0)
	add_child(model)
	_spark = CPUParticles3D.new()
	_spark.amount = 12
	_spark.lifetime = 0.25
	_spark.direction = Vector3.UP
	_spark.initial_velocity_min = 0.6
	_spark.initial_velocity_max = 1.4
	_spark.position = Vector3(0.16, 0.08, 0.0)
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.02, 0.02, 0.02)
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.85, 0.3)
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh.material = spark_mat
	_spark.mesh = spark_mesh
	add_child(_spark)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		explode()


## Aplica a explosão onde a banana está. Devolve {enemies, items, players, spots}.
func explode() -> Dictionary:
	var out: Dictionary = {"enemies": 0, "items": 0, "players": 0, "spots": 0}
	if _exploded or not is_inside_tree():
		return out
	_exploded = true
	var center: Vector3 = global_position
	out = apply_blast(get_tree(), center, thrower)
	if thrower != null and is_instance_valid(thrower) and thrower.has_method("show_explosion"):
		thrower.call("show_explosion", center)
		if thrower.has_method("is_local") and bool(thrower.call("is_local")) and thrower.multiplayer.has_multiplayer_peer():
			thrower.rpc(&"show_explosion", center)
	queue_free()
	return out


static func apply_blast(tree: SceneTree, center: Vector3, thrower: Node3D) -> Dictionary:
	var out: Dictionary = {"enemies": 0, "items": 0, "players": 0, "spots": 0}
	for n: Node in tree.get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not is_instance_valid(e):
			continue
		var d: float = e.global_position.distance_to(center)
		if d > ENEMY_RADIUS:
			continue
		var dmg: float = DAMAGE * lerpf(1.0, 0.4, d / ENEMY_RADIUS)
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, center)  # EnemyBase manda request_hit sozinho no cliente
		if e.has_method("stun"):
			e.call("stun", STUN)
		out["enemies"] += 1
	for n: Node in tree.get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or not is_instance_valid(p):
			continue
		var to: Vector3 = p.global_position - center
		if to.length() > PUSH_RADIUS:
			continue
		var dir: Vector3 = to.normalized() if to.length() > 0.05 else Vector3.UP
		p.push((dir + Vector3.UP * 0.8).normalized() * ITEM_PUSH)
		p.crack(ItemPickup.EXPLOSION_CRACK)
		out["items"] += 1
	for n: Node in tree.get_nodes_in_group(&"wheelbarrows"):
		var wb: Node3D = n as Node3D
		if wb == null or not is_instance_valid(wb):
			continue
		var to: Vector3 = wb.global_position - center
		if to.length() > PUSH_RADIUS:
			continue
		var dir: Vector3 = to.normalized() if to.length() > 0.05 else Vector3.UP
		wb.call("apply_impulse", (dir + Vector3.UP * 0.8).normalized() * 12.0)
	for n: Node in tree.get_nodes_in_group(&"players"):
		var pl: Node3D = n as Node3D
		if pl == null or not is_instance_valid(pl) or not pl.has_method("apply_knockback"):
			continue
		var to: Vector3 = pl.global_position - center
		if to.length() > PLAYER_RADIUS:
			continue
		var dir: Vector3 = Vector3(to.x, 0.0, to.z).normalized() if Vector2(to.x, to.z).length() > 0.05 else Vector3.FORWARD
		var impulse: Vector3 = dir * PLAYER_PUSH + Vector3.UP * 5.0
		var local: bool = pl.has_method("is_local") and bool(pl.call("is_local"))
		if local:
			pl.call("apply_knockback", impulse, 0.08)
			pl.call("take_damage", SELF_DAMAGE * (0.5 if pl != thrower else 1.0))
		elif pl.multiplayer.has_multiplayer_peer():
			pl.rpc_id(pl.get_multiplayer_authority(), &"apply_knockback", impulse, 0.08)
			pl.rpc_id(pl.get_multiplayer_authority(), &"apply_damage", SELF_DAMAGE * 0.5, center)
		out["players"] += 1
	for n: Node in tree.get_nodes_in_group(&"buried_spots"):
		var s: BuriedSpot = n as BuriedSpot
		if s == null or not is_instance_valid(s) or s.global_position.distance_to(center) > DIG_RADIUS:
			continue
		# Explode as camadas todas de uma vez, como pazadas rápidas: o achado sai trincado.
		for i: int in BuriedSpot.MAX_DIRT_LAYERS:
			if s.networked and not s.multiplayer.is_server():
				s.request_dig.rpc_id(1, false, 1.0)
			else:
				s.dig(false, 1.0, false, thrower)
		out["spots"] += 1
	out["ice_floes"] = 0
	for n: Node in tree.get_nodes_in_group(&"ice_floes"):
		var floe: Node3D = n as Node3D
		if floe == null or not is_instance_valid(floe):
			continue
		var to_floe: Vector3 = floe.global_position - center
		var r: float = float(floe.get("floe_radius")) if "floe_radius" in floe else 1.8
		if to_floe.length() <= PUSH_RADIUS + r * 0.5:
			if floe.has_method("apply_blast_damage"):
				floe.call("apply_blast_damage", center, PUSH_RADIUS)
			elif floe.has_method("shatter"):
				floe.call("shatter")
			out["ice_floes"] += 1
	DisturbanceMeter.report(NOISE, center)
	return out
