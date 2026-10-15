class_name GazeTrigger
extends Interactable

## Segredo "visto do alto" (#41, ex.: o círculo nas searas): dispara sozinho quando o jogador
## local está pelo menos `min_height` m acima do chão, a menos de `max_distance` de
## `look_point` e a olhar para ele (cone). O jogador local pede ao host (Interactable.
## request_interact), que reporta o segredo e mostra o texto a quem viu. Não tem [E] nem
## prompt (interact_range = 0 tira-o do foco).

## Ponto (local) para onde é preciso olhar.
@export var look_point: Vector3 = Vector3.ZERO
@export var min_height: float = 1.6
@export var max_distance: float = 30.0
@export var look_dot: float = 0.93
@export var secret_id: String = ""
## Bandeira ligada quando é visto (para missões/testes).
@export var sets_flag: StringName = &""
@export_multiline var seen_text: String = ""
@export_flags_3d_physics var ground_mask: int = 1

var _sent: bool = false


func _ready() -> void:
	interact_range = 0.0
	prompt = ""
	once = true
	super._ready()
	# O texto aparece por cima do que se viu (longe): maior.
	_say_label.position = look_point + Vector3.UP * 2.5
	_say_label.pixel_size = 0.012


func _process(delta: float) -> void:
	super._process(delta)
	if _sent or not active:
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var cam: Camera3D = get_viewport().get_camera_3d()
	if player == null or cam == null:
		return
	var target: Vector3 = global_transform * look_point
	if player.global_position.distance_to(target) > max_distance:
		return
	var to_t: Vector3 = (target - cam.global_position).normalized()
	if (-cam.global_basis.z).dot(to_t) < look_dot:
		return
	if _height_above_ground(player) < min_height:
		return
	_sent = true
	request_interact()


func _on_interact(peer_id: int) -> void:
	if not seen_text.is_empty():
		say_to(peer_id, seen_text, 6.0)
	if not secret_id.is_empty():
		QuestRewards.report_secret(secret_id)
	if sets_flag != &"":
		var flags: WorldFlags = WorldFlags.find(get_tree())
		if flags != null:
			flags.set_flag(sets_flag)
	super._on_interact(peer_id)


func _height_above_ground(player: Node3D) -> float:
	var p: Vector3 = player.global_position
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.1, p + Vector3.DOWN * 30.0, ground_mask)
	if player is CollisionObject3D:
		q.exclude = [(player as CollisionObject3D).get_rid()]
	# Só o terreno conta como "chão" (camada 1 sem os fardos): ver ground_mask na cena.
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	return p.y - (hit["position"] as Vector3).y if not hit.is_empty() else 0.0
