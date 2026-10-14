class_name SlingshotProjectile
extends RigidBody3D

## Pedra do estilingue: voa em arco com a gravidade, dá dano ao primeiro inimigo em que
## toca e desaparece pouco depois de bater no mundo.

const ENEMY_LAYER_MASK: int = 1 << 3  # layer 4
const WORLD_MASK: int = 1
const LIFETIME: float = 4.0

var damage: float = 20.0
var shot_origin: Vector3 = Vector3.ZERO
var _spent: bool = false
var _hit_world: bool = false


## Cria e lança a pedra. `shooter` fica excluído das colisões.
static func launch(parent: Node, shooter: PhysicsBody3D, pos: Vector3, velocity_start: Vector3, p_damage: float) -> SlingshotProjectile:
	var p: SlingshotProjectile = SlingshotProjectile.new()
	p.damage = p_damage
	p.shot_origin = pos
	parent.add_child(p)
	p.global_position = pos
	if shooter != null:
		p.add_collision_exception_with(shooter)
	p.linear_velocity = velocity_start
	p.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = WORLD_MASK | ENEMY_LAYER_MASK
	mass = 0.15
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.045
	shape.shape = sphere
	add_child(shape)

	var mesh: MeshInstance3D = MeshInstance3D.new()
	var rock: SphereMesh = SphereMesh.new()
	rock.radius = 0.045
	rock.height = 0.08
	rock.radial_segments = 6
	rock.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.48, 0.45)
	mat.roughness = 0.9
	rock.material = mat
	mesh.mesh = rock
	add_child(mesh)

	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _on_body_entered(body: Node) -> void:
	if _spent:
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		_spent = true
		SFX.play_at(SFX.STONE_IMPACT, global_position, 0.0)
		body.call("take_damage", damage, shot_origin)
		queue_free()
		return
	# Bateu no mundo: continua a magoar enquanto ressalta/rola e some pouco depois.
	if not _hit_world:
		_hit_world = true
		SFX.play_at(SFX.STONE_IMPACT, global_position, -6.0, 0.15)
		get_tree().create_timer(0.6).timeout.connect(queue_free)
