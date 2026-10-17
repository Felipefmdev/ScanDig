class_name PressurePlate
extends Node3D

## Placa de pressão do chão do templo (#97). Pisá-la (jogador OU inimigo) afunda a laje e dispara
## a armadilha: DARTS = rajada de dardos de um bocal na parede (emitter) que atravessa a placa;
## ROCK = pedra que cai do teto em cima da placa. Atrair um inimigo para cima é uma forma de a usar
## a nosso favor. Rearma passados `cooldown` s. Host deteta e aplica o dano; todos veem por rpc.

enum Trap { DARTS, ROCK }

const SIZE: float = 1.1
const DART_WIDTH: float = 0.8
const ROCK_RADIUS: float = 1.5
const PLAYER_DAMAGE: float = 14.0
const ENEMY_DAMAGE: float = 40.0
const STONE: Color = Color(0.62, 0.56, 0.47)
const GLYPH: Color = Color(0.35, 0.55, 0.42)
const BRONZE: Color = Color(0.55, 0.38, 0.2)

@export var trap: Trap = Trap.DARTS
## Bocal dos dardos, relativo à placa (os dardos voam do bocal através da placa e além).
@export var emitter_offset: Vector3 = Vector3(5.5, 1.0, 0.0)
@export var cooldown: float = 5.0
@export var delay: float = 0.35

var armed: bool = true
var triggered_count: int = 0
var _left: float = 0.0
var _slab: MeshInstance3D = null


func _ready() -> void:
	add_to_group(&"pressure_plates")
	_build()


func _is_host() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if not _is_host():
		return
	if not armed:
		_left -= delta
		if _left <= 0.0:
			armed = true
			_announce(&"_rpc_set_pressed", [false])
		return
	if _something_on_plate():
		press()


func _something_on_plate() -> bool:
	for group: StringName in [&"players", &"enemies"]:
		for n: Node in get_tree().get_nodes_in_group(group):
			var b: Node3D = n as Node3D
			if b != null and is_instance_valid(b) and b.is_inside_tree() and is_on_plate(b.global_position):
				return true
	return false


func is_on_plate(p: Vector3) -> bool:
	var d: Vector3 = p - global_position
	return absf(d.x) <= SIZE * 0.6 and absf(d.z) <= SIZE * 0.6 and d.y > -0.4 and d.y < 1.2


## Host: aciona a armadilha (também usado pelo bot/testes com o passo "call" ... "trigger").
func press() -> void:
	if not armed or not _is_host():
		return
	armed = false
	_left = cooldown
	triggered_count += 1
	_announce(&"_rpc_fire", [])
	var tree: SceneTree = get_tree()
	if tree != null:
		await tree.create_timer(delay, false, true).timeout
	if is_inside_tree():
		_apply_hits()


func trigger() -> void:
	press()


func _announce(method: StringName, args: Array) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		callv(&"rpc", [method] + args)
	else:
		callv(method, args)


@rpc("authority", "call_local", "reliable")
func _rpc_set_pressed(pressed: bool) -> void:
	if _slab != null:
		var t: Tween = create_tween()
		t.tween_property(_slab, "position:y", 0.02 if pressed else 0.08, 0.1)


@rpc("authority", "call_local", "reliable")
func _rpc_fire() -> void:
	_rpc_set_pressed(true)
	SFX.play_at(SFX.SLINGSHOT_FIRE, global_position, -4.0, 0.1)
	match trap:
		Trap.DARTS:
			_darts_fx()
		Trap.ROCK:
			_rock_fx()


func dart_line() -> Array[Vector3]:
	var a: Vector3 = global_position + emitter_offset
	var through: Vector3 = global_position + Vector3.UP * emitter_offset.y
	var dir: Vector3 = (through - a)
	dir.y = 0.0
	var b: Vector3 = a + dir.normalized() * (dir.length() + 4.0)
	return [a, b]


func is_hit(p: Vector3) -> bool:
	if trap == Trap.ROCK:
		var d: Vector3 = p - global_position
		return Vector2(d.x, d.z).length() <= ROCK_RADIUS and d.y > -0.5 and d.y < 2.0
	var line: Array[Vector3] = dart_line()
	var a: Vector3 = line[0]
	var ab: Vector2 = Vector2(line[1].x - a.x, line[1].z - a.z)
	var ap: Vector2 = Vector2(p.x - a.x, p.z - a.z)
	var t: float = clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * t).length() <= DART_WIDTH and absf(p.y - global_position.y) < 2.0


## Host: dano e empurrão em quem está na trajetória (jogadores remotos pelo dono, como a dinamite).
func _apply_hits() -> int:
	var hits: int = 0
	var push_dir: Vector3 = Vector3.ZERO
	if trap == Trap.DARTS:
		var line: Array[Vector3] = dart_line()
		push_dir = (line[1] - line[0]).normalized()
	for n: Node in get_tree().get_nodes_in_group(&"players"):
		var pl: Node3D = n as Node3D
		if pl == null or not is_instance_valid(pl) or not is_hit(pl.global_position):
			continue
		var push: Vector3 = (push_dir * 6.0 if trap == Trap.DARTS else (pl.global_position - global_position).normalized() * 6.0) + Vector3.UP * 3.0
		if pl.has_method("is_local") and bool(pl.call("is_local")):
			pl.call("apply_knockback", push, 0.06)
			pl.call("take_damage", PLAYER_DAMAGE)
		elif pl.multiplayer.has_multiplayer_peer():
			pl.rpc_id(pl.get_multiplayer_authority(), &"apply_knockback", push, 0.06)
			pl.rpc_id(pl.get_multiplayer_authority(), &"apply_damage", PLAYER_DAMAGE, global_position)
		hits += 1
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e != null and is_instance_valid(e) and is_hit(e.global_position) and e.has_method("take_damage"):
			e.call("take_damage", ENEMY_DAMAGE, global_position)
			if e.has_method("stun"):
				e.call("stun", 1.2)
			hits += 1
	return hits


# --- Visuais -------------------------------------------------------------------

func _build() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Moldura rente ao chão e a laje com um glifo gasto (a pista para quem repara).
	LowPolyMesh.box(st, Vector3(0, 0.03, 0), Vector3(SIZE + 0.25, 0.06, SIZE + 0.25), Basis.IDENTITY, STONE.darkened(0.25))
	var frame: MeshInstance3D = MeshInstance3D.new()
	frame.mesh = ToonKit.commit(st)
	frame.material_override = ToonKit.vertex_material(true, true)
	add_child(frame)
	var st2: SurfaceTool = SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st2, Vector3.ZERO, Vector3(SIZE, 0.08, SIZE), Basis.IDENTITY, STONE)
	LowPolyMesh.box(st2, Vector3(0, 0.045, 0), Vector3(SIZE * 0.6, 0.01, 0.1), Basis.IDENTITY, GLYPH)
	LowPolyMesh.box(st2, Vector3(0, 0.045, 0), Vector3(0.1, 0.01, SIZE * 0.6), Basis.IDENTITY, GLYPH)
	_slab = MeshInstance3D.new()
	_slab.name = "Slab"
	_slab.mesh = ToonKit.commit(st2)
	_slab.material_override = ToonKit.vertex_material(true, true)
	_slab.position.y = 0.08
	add_child(_slab)
	if trap == Trap.DARTS:
		var st3: SurfaceTool = SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		var local_a: Vector3 = emitter_offset
		var face: Vector3 = (Vector3(0, emitter_offset.y, 0) - emitter_offset).normalized()
		LowPolyMesh.box(st3, local_a, Vector3(0.36, 0.36, 0.36), Basis.looking_at(face, Vector3.UP), BRONZE)
		LowPolyMesh.box(st3, local_a + face * 0.2, Vector3(0.16, 0.16, 0.06), Basis.looking_at(face, Vector3.UP), Color(0.08, 0.06, 0.05))
		var nozzle: MeshInstance3D = MeshInstance3D.new()
		nozzle.name = "Nozzle"
		nozzle.mesh = ToonKit.commit(st3)
		nozzle.material_override = ToonKit.vertex_material(true, true)
		add_child(nozzle)


func _darts_fx() -> void:
	var line: Array[Vector3] = dart_line()
	for k: int in 3:
		var dart: MeshInstance3D = MeshInstance3D.new()
		var m: BoxMesh = BoxMesh.new()
		m.size = Vector3(0.04, 0.04, 0.45)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = BRONZE.darkened(0.2)
		m.material = mat
		dart.mesh = m
		add_child(dart)
		var off: Vector3 = Vector3(0, (k - 1) * 0.25, 0)
		dart.global_position = line[0] + off
		dart.look_at(line[1] + off, Vector3.UP)
		var t: Tween = dart.create_tween()
		t.tween_interval(delay * 0.8 + k * 0.05)
		t.tween_property(dart, "global_position", line[1] + off, 0.3)
		t.tween_callback(dart.queue_free)


func _rock_fx() -> void:
	var rock: MeshInstance3D = MeshInstance3D.new()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0, -0.45, 0), Vector3(0, 0.45, 0), 0.55, 0.4, 6, STONE.darkened(0.1))
	rock.mesh = ToonKit.commit(st)
	rock.material_override = ToonKit.vertex_material(true, true)
	add_child(rock)
	rock.position = Vector3(0, 7.0, 0)
	var t: Tween = rock.create_tween()
	t.tween_property(rock, "position:y", 0.5, delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func() -> void: SFX.play_at(SFX.PLAYER_DEATH, global_position, 0.0, 0.15))
	t.tween_interval(2.5)
	t.tween_property(rock, "scale", Vector3.ONE * 0.01, 0.4)
	t.tween_callback(rock.queue_free)
