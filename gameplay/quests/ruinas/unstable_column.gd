class_name UnstableColumn
extends Node3D

## Coluna instável das Ruínas (#97): marcada com rachas escuras e pó a cair. Cavar perto dela
## (STRESS_RADIUS) faz o subsolo ceder: ao STRESS_TO_FALL-ésimo golpe de pá a coluna abana
## (WOBBLE_TIME s, telegrafado) e tomba para o lado de onde se cavou. Quem estiver na linha da
## queda leva dano e é empurrado; inimigos também. Fica deitada como entulho e às vezes revela
## um nicho (ponto de escavação fresco na base). Host decide (contagem, direção, nicho e dano);
## todos veem a animação por rpc.

const STRUCTURE: Script = preload("res://gameplay/environment/ruins_structure.gd")
const STRESS_RADIUS: float = 3.2
const STRESS_TO_FALL: int = 2
const WOBBLE_TIME: float = 1.8
const FALL_TIME: float = 0.55
const HIT_WIDTH: float = 1.0
const PLAYER_DAMAGE: float = 18.0
const ENEMY_DAMAGE: float = 45.0
const PUSH: float = 9.0
const CRACK: Color = Color(0.2, 0.16, 0.13)
const DUST: Color = Color(0.78, 0.72, 0.6, 0.8)

@export var height: float = 3.4
@export var radius: float = 0.45
@export_range(0.0, 1.0) var niche_chance: float = 0.5
## Índice único no mapa (nome do spot do nicho).
@export var index: int = 0

var stress: int = 0
var fallen: bool = false
var wobbling: bool = false
var _pivot: Node3D = null
var _dust: CPUParticles3D = null
var _connected: Dictionary = {}
var _scan_left: float = 0.0


func _ready() -> void:
	add_to_group(&"unstable_columns")
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)
	var s: Node3D = STRUCTURE.new()
	s.set("kind", 0)
	s.set("size", Vector3(radius, height, 0.0))
	s.set("seed_value", 31 + index)
	_pivot.add_child(s)
	_pivot.add_child(_cracks())
	_dust = _particles()
	_dust.position = Vector3(0, height * 0.7, 0)
	add_child(_dust)
	_dust.emitting = true


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if fallen or not _is_host():
		return
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = 0.5
	# Liga-se aos spots que vão aparecendo perto (o SpotSpawner cria-os ao longo do jogo).
	for n: Node in get_tree().get_nodes_in_group(&"buried_spots"):
		var spot: Node3D = n as Node3D
		if spot == null or not is_instance_valid(spot) or _connected.has(spot.get_instance_id()):
			continue
		if not spot.has_signal(&"spot_dug") or spot.global_position.distance_to(global_position) > STRESS_RADIUS:
			continue
		_connected[spot.get_instance_id()] = true
		spot.connect(&"spot_dug", _on_spot_dug.bind(spot))


func _on_spot_dug(_dirt_left: int, _integrity: float, spot: Node3D) -> void:
	if fallen or wobbling or not is_instance_valid(spot):
		return
	add_stress(spot.global_position)


## Host: um golpe de pá a `from`. Devolve true se começou a cair.
func add_stress(from: Vector3) -> bool:
	if fallen or wobbling or not _is_host():
		return false
	stress += 1
	if stress < STRESS_TO_FALL:
		_announce(&"_rpc_creak", [])
		return false
	var dir: Vector3 = from - global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		dir = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	_announce(&"_rpc_topple", [dir.normalized()])
	return true


## Atalho de debug/bot (passo "call" com method "trigger"): faz a coluna ceder já.
func trigger() -> void:
	var from: Vector3 = global_position + Vector3(1.0, 0.0, 1.0)
	while not fallen and not wobbling and _is_host():
		add_stress(from)


func _announce(method: StringName, args: Array) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


## Primeiro aviso: estalo e uma lufada de pó.
@rpc("authority", "call_local", "reliable")
func _rpc_creak() -> void:
	SFX.play_at(SFX.SLINGSHOT_FIRE, global_position + Vector3.UP * height * 0.5, -6.0, 0.15)
	if _dust != null:
		_dust.amount = 24
	var t: Tween = create_tween()
	t.tween_property(_pivot, "rotation:z", 0.04, 0.08)
	t.tween_property(_pivot, "rotation:z", -0.03, 0.1)
	t.tween_property(_pivot, "rotation:z", 0.0, 0.1)


@rpc("authority", "call_local", "reliable")
func _rpc_topple(dir: Vector3) -> void:
	if fallen or wobbling:
		return
	wobbling = true
	if _dust != null:
		_dust.amount = 40
	var axis: Vector3 = Vector3.UP.cross(dir).normalized()
	var t: Tween = create_tween()
	# Telegrafado: abana cada vez mais na direção em que vai cair.
	for k: int in 6:
		var a: float = 0.03 + 0.012 * k
		t.tween_method(_set_tilt.bind(axis), 0.0, a, WOBBLE_TIME / 12.0)
		t.tween_method(_set_tilt.bind(axis), a, -a * 0.4, WOBBLE_TIME / 12.0)
	t.tween_method(_set_tilt.bind(axis), 0.0, PI * 0.5 - 0.06, FALL_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(_on_landed.bind(dir))


func _set_tilt(angle: float, axis: Vector3) -> void:
	if _pivot != null:
		_pivot.quaternion = Quaternion(axis, angle)


func _on_landed(dir: Vector3) -> void:
	wobbling = false
	fallen = true
	if _dust != null:
		_dust.emitting = false
	_rubble(dir)
	SFX.play_at(SFX.PLAYER_DEATH, global_position + dir * height * 0.5, 2.0, 0.15)
	var local: Node = get_tree().get_first_node_in_group(&"player")
	if local != null and local.has_method("_shake_camera") and (local as Node3D).global_position.distance_to(global_position) < 12.0:
		local.call("_shake_camera", 0.08, 0.4)
	if _is_host():
		_apply_hits(dir)
		if randf() < niche_chance:
			FreshSpot.spawn(self, global_position + Vector3.UP * 0.05, 9500 + index, &"column_niches")


## Host: tudo o que estiver na faixa da queda (base -> topo) leva com a coluna.
func _apply_hits(dir: Vector3) -> void:
	var a: Vector3 = global_position
	var b: Vector3 = global_position + dir * height
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Node3D = n as Node3D
		if pl == null or not is_instance_valid(pl) or not in_fall_line(pl.global_position, a, b):
			continue
		var push: Vector3 = Vector3.UP.cross(dir) * signf(Vector3.UP.cross(dir).dot(pl.global_position - a)) * PUSH + Vector3.UP * 4.0
		if pl.has_method("is_local") and bool(pl.call("is_local")):
			pl.call("apply_knockback", push, 0.1)
			pl.call("take_damage", PLAYER_DAMAGE)
		elif pl.multiplayer.has_multiplayer_peer():
			pl.rpc_id(pl.get_multiplayer_authority(), &"apply_knockback", push, 0.1)
			pl.rpc_id(pl.get_multiplayer_authority(), &"apply_damage", PLAYER_DAMAGE, a)
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e != null and is_instance_valid(e) and in_fall_line(e.global_position, a, b) and e.has_method("take_damage"):
			e.call("take_damage", ENEMY_DAMAGE, a)
			if e.has_method("stun"):
				e.call("stun", 1.5)
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var pk: ItemPickup = n as ItemPickup
		if pk != null and is_instance_valid(pk) and pk.is_inside_tree() and in_fall_line(pk.global_position, a, b):
			pk.push((Vector3.UP + dir * 0.5).normalized() * 5.0)


static func in_fall_line(p: Vector3, a: Vector3, b: Vector3) -> bool:
	var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	var ap: Vector2 = Vector2(p.x - a.x, p.z - a.z)
	var t: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length() <= HIT_WIDTH and absf(p.y - a.y) < 2.5 and t > 0.05


# --- Visuais -------------------------------------------------------------------

## Rachas escuras em zigue-zague pelo fuste (o sinal de que a coluna é instável).
func _cracks() -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in 3:
		var ang: float = TAU * float(side) / 3.0 + 0.4
		var out: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var y: float = 0.5
		var off: float = 0.0
		while y < height - 0.6:
			var y2: float = y + 0.45
			var off2: float = off + (0.12 if int(y * 10.0) % 2 == 0 else -0.12)
			var p0: Vector3 = out * (radius + 0.005) + Vector3.UP * y + out.cross(Vector3.UP) * off
			var p1: Vector3 = out * (radius + 0.005) + Vector3.UP * y2 + out.cross(Vector3.UP) * off2
			var mid: Vector3 = (p0 + p1) * 0.5
			var len: float = p0.distance_to(p1)
			var basis: Basis = Basis.looking_at(out, (p1 - p0).normalized())
			LowPolyMesh.box(st, mid, Vector3(0.05, len, 0.02), basis, CRACK)
			y = y2
			off = off2
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Cracks"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(false, true)
	return mi


func _rubble(dir: Vector3) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 6:
		var p: Vector3 = dir * randf_range(0.3, height + 0.4) + Vector3.UP.cross(dir) * randf_range(-0.9, 0.9)
		LowPolyMesh.box(st, p + Vector3.UP * 0.12, Vector3.ONE * randf_range(0.2, 0.42),
			Basis.from_euler(Vector3(randf(), randf() * TAU, randf())), STRUCTURE.STONE_DARK)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Rubble"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	add_child(mi)
	var burst: CPUParticles3D = _particles()
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = 50
	burst.position = dir * height * 0.5 + Vector3.UP * 0.3
	add_child(burst)
	burst.emitting = true


func _particles() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 6
	p.lifetime = 1.2
	p.direction = Vector3.DOWN
	p.spread = 60.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -2.0, 0)
	var m: BoxMesh = BoxMesh.new()
	m.size = Vector3.ONE * 0.06
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = DUST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	return p
