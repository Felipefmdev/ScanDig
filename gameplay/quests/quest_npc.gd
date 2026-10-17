class_name QuestNpc
extends Interactable

## NPC com balão de fala e uma missão simples (#39). Estados (state, decididos no host):
##   OFFER  — oferece a missão (marcador "!" por cima);
##   ACTIVE — à espera do objetivo: a bandeira `objective_flag` do WorldFlags (encontrar algo,
##            apanhar, acender, tocar uma sequência... quem cumpre liga a bandeira);
##   READY  — objetivo cumprido (marcador "?"): falar com ele entrega e começa o evento;
##   EVENT  — evento a decorrer (`event_path`: WaveEvent ou qualquer nó com start() e o sinal
##            finished(success)); se falhar volta a READY para tentar outra vez;
##   DONE   — concluída: recompensa (QuestRewards.complete_quest + item no chão), uma vez.
## Sem evento, READY → DONE logo ao entregar.

signal quest_state_changed(new_state: int)

enum QuestState { OFFER, ACTIVE, READY, EVENT, DONE }

@export var npc_name: String = "NPC"
@export var quest_id: String = ""
@export var objective_flag: StringName = &""
## Bandeira ligada quando a missão é aceite (ex.: o sino passa a chamar os corvos das chaves).
@export var accept_flag: StringName = &""
## Nó do evento (WaveEvent, BossTrigger...) com start() e finished(success: bool).
@export var event_path: NodePath = NodePath("")
## Item do catálogo largado ao concluir (ex. concha_dourada).
@export var reward_item_id: String = ""
@export var reward_drop_offset: Vector3 = Vector3(0.0, 1.2, -1.5)

@export_group("Falas")
@export_multiline var line_offer: String = ""
@export_multiline var line_active: String = ""
@export_multiline var line_ready: String = ""
@export_multiline var line_turn_in: String = ""
@export_multiline var line_event: String = ""
@export_multiline var line_failed: String = ""
@export_multiline var line_win: String = ""
@export_multiline var line_done: String = ""

var _marker: Label3D = null
var _model: Node3D = null
var _bob_time: float = 0.0
var _model_base_pos: Vector3 = Vector3.ZERO
var _model_base_rot: Vector3 = Vector3.ZERO
var _head_node: Node3D = null
var _pupils_node: Node3D = null
var _mouth_node: Node3D = null
var _look_yaw: float = 0.0
var _look_pitch: float = 0.0
var _talk_time: float = 0.0


func _ready() -> void:
	super._ready()
	if prompt == "[E] Interagir":
		prompt = "[E] Falar com %s" % npc_name
	_model = get_node_or_null(^"Model") as Node3D
	if _model != null:
		_model_base_pos = _model.position
		_model_base_rot = _model.rotation
		_cache_face_parts()
	_marker = _make_label(Color(1.0, 0.82, 0.1), Color(0.1, 0.06, 0.02), 110)
	_marker.name = "Marker"
	_marker.position = focus_offset + Vector3.UP * 1.25
	add_child(_marker)
	if HostSync.is_host(self):
		if QuestRewards.is_quest_completed(quest_id):
			state = QuestState.DONE
		_connect_host.call_deferred()
	_refresh_marker()


func _cache_face_parts() -> void:
	if _model == null:
		return
	_head_node = _model.find_child("NpcHead", true, false) as Node3D
	_pupils_node = _model.find_child("NpcPupils", true, false) as Node3D
	_mouth_node = _model.find_child("NpcMouth", true, false) as Node3D


func _connect_host() -> void:
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags != null and objective_flag != &"":
		flags.flag_changed.connect(func(flag: StringName, value: bool) -> void:
			if flag == objective_flag and value and state == QuestState.ACTIVE:
				_set_quest_state(QuestState.READY)
				say_all(line_ready, 5.0))
	var ev: Node = _event()
	if ev != null and ev.has_signal(&"finished"):
		ev.connect(&"finished", _on_event_finished)


func _process(delta: float) -> void:
	super._process(delta)
	_bob_time += delta
	if _marker.visible:
		_marker.position.y = focus_offset.y + 1.25 + sin(_bob_time * 3.0) * 0.06

	# Estudo How to Fish (NPC.cs): respiração/balanço, olhar que segue e boca ao falar
	if _model != null:
		if _head_node == null:
			_cache_face_parts()
		_process_npc_life(delta)


func _process_npc_life(delta: float) -> void:
	# 1. Respiração e balanço suave (idle breathing)
	var breath: float = sin(_bob_time * 2.2)
	_model.position.y = _model_base_pos.y + breath * 0.015
	_model.scale.y = 1.0 + breath * 0.012
	_model.rotation.z = _model_base_rot.z + sin(_bob_time * 1.1) * 0.012

	# 2. Olhos e cabeça que seguem o jogador mais próximo
	var player_pos: Vector3 = Vector3.ZERO
	var has_player: bool = false
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and global_position.distance_to(cam.global_position) <= 7.0:
		player_pos = cam.global_position
		has_player = true
	elif is_inside_tree():
		var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		if p != null and global_position.distance_to(p.global_position) <= 7.0:
			player_pos = p.global_position + Vector3(0, 1.4, 0)
			has_player = true

	if has_player:
		var to_player: Vector3 = _model.to_local(player_pos)
		var target_yaw: float = clampf(atan2(-to_player.x, -to_player.z), -deg_to_rad(40.0), deg_to_rad(40.0))
		var flat_dist: float = maxf(Vector2(to_player.x, to_player.z).length(), 0.1)
		var target_pitch: float = clampf(atan2(to_player.y - focus_offset.y, flat_dist), -deg_to_rad(15.0), deg_to_rad(15.0))
		_look_yaw = lerp_angle(_look_yaw, target_yaw, clampf(4.0 * delta, 0.0, 1.0))
		_look_pitch = lerpf(_look_pitch, target_pitch, clampf(4.0 * delta, 0.0, 1.0))
		if _pupils_node != null:
			var px: float = clampf(-to_player.x * 0.015, -0.012, 0.012)
			var py: float = clampf((to_player.y - focus_offset.y) * 0.015, -0.01, 0.01)
			_pupils_node.position = _pupils_node.position.lerp(Vector3(px, py, 0.0), clampf(6.0 * delta, 0.0, 1.0))
	else:
		_look_yaw = lerp_angle(_look_yaw, 0.0, clampf(3.0 * delta, 0.0, 1.0))
		_look_pitch = lerpf(_look_pitch, 0.0, clampf(3.0 * delta, 0.0, 1.0))
		if _pupils_node != null:
			_pupils_node.position = _pupils_node.position.lerp(Vector3.ZERO, clampf(4.0 * delta, 0.0, 1.0))

	if _head_node != null:
		_head_node.rotation.y = _look_yaw
		_head_node.rotation.x = -_look_pitch
	else:
		_model.rotation.y = _model_base_rot.y + _look_yaw * 0.65
		_model.rotation.x = _model_base_rot.x - _look_pitch * 0.45

	# 3. Boca que mexe ao falar e leve aceno de cabeça expressivo
	if _say_left > 0.0:
		_talk_time += delta
		var mouth_val: float = 0.4 + 1.2 * absf(sin(_talk_time * 18.0))
		if _mouth_node != null:
			_mouth_node.scale.y = mouth_val
			_mouth_node.scale.x = 1.0 + 0.2 * sin(_talk_time * 12.0)
		var nod: float = sin(_talk_time * 11.0) * 0.035
		if _head_node != null:
			_head_node.rotation.x += nod
		else:
			_model.rotation.x += nod
	else:
		if _mouth_node != null:
			_mouth_node.scale = _mouth_node.scale.lerp(Vector3.ONE, clampf(10.0 * delta, 0.0, 1.0))


func get_quest_state() -> QuestState:
	return state as QuestState


func _on_interact(peer_id: int) -> void:
	match state as QuestState:
		QuestState.OFFER:
			say_to(peer_id, line_offer, 7.0)
			_set_quest_state(QuestState.READY if _objective_done() else QuestState.ACTIVE)
			if accept_flag != &"":
				var flags: WorldFlags = WorldFlags.find(get_tree())
				if flags != null:
					flags.set_flag(accept_flag)
		QuestState.ACTIVE:
			say_to(peer_id, line_active, 5.0)
		QuestState.READY:
			say_all(line_turn_in, 5.0)
			var ev: Node = _event()
			if ev != null and ev.has_method(&"start"):
				if bool(ev.call(&"start")):
					_set_quest_state(QuestState.EVENT)
			else:
				_complete()
		QuestState.EVENT:
			say_to(peer_id, line_event, 3.0)
		QuestState.DONE:
			say_to(peer_id, line_done, 4.0)
	super._on_interact(peer_id)


func _on_event_finished(success: bool) -> void:
	if not HostSync.is_host(self) or state != QuestState.EVENT:
		return
	if success:
		_complete()
	else:
		_set_quest_state(QuestState.READY)
		say_all(line_failed, 6.0)


func _complete() -> void:
	_set_quest_state(QuestState.DONE)
	say_all(line_win, 7.0)
	QuestRewards.complete_quest(quest_id)
	if not reward_item_id.is_empty():
		QuestRewards.drop_item(get_tree(), reward_item_id, global_transform * reward_drop_offset)


func _set_quest_state(s: QuestState) -> void:
	set_state(int(s))


func _on_state_applied() -> void:
	super._on_state_applied()
	_refresh_marker()
	quest_state_changed.emit(state)


func _refresh_marker() -> void:
	if _marker == null:
		return
	match state as QuestState:
		QuestState.OFFER:
			_marker.text = "!"
			_marker.visible = true
		QuestState.READY:
			_marker.text = "?"
			_marker.visible = true
		_:
			_marker.visible = false


func _objective_done() -> bool:
	if objective_flag == &"":
		return true
	var flags: WorldFlags = WorldFlags.find(get_tree())
	return flags != null and flags.has_flag(objective_flag)


func _event() -> Node:
	return get_node_or_null(event_path) if not event_path.is_empty() else null
