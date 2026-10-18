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
## Item/criatura que faz o NPC reagir ao ver na mão do jogador a <= 4 m (How to Fish QuestLineType.HoldingItem, #87).
@export var holding_item_id: String = ""

@export_group("Falas")
@export_multiline var line_offer: String = ""
@export_multiline var line_active: String = ""
@export_multiline var line_ready: String = ""
@export_multiline var line_turn_in: String = ""
@export_multiline var line_event: String = ""
@export_multiline var line_failed: String = ""
@export_multiline var line_win: String = ""
@export_multiline var line_done: String = ""
@export_multiline var line_holding: String = ""
## Dica do Mapa do Tesouro (#115). Depois da missão (DONE), enquanto faltar algum fragmento,
## alterna com line_done a cada conversa (a dica primeiro); com o mapa completo, só line_done.
@export_multiline var line_map_hint: String = ""

const HOLDING_DETECT_RANGE: float = 4.0
const HOLDING_REACT_COOLDOWN: float = 10.0
const DEFAULT_HOLDING_LINE: String = "É isso! Traga aqui!"
const QUEST_HOLDING_ITEMS: Dictionary = {
	"ze_anzol": ["concha_dourada", "alianca_ouro", "bussola_naufragio", "medalhao_sereia", "mapa_na_garrafa", "tatuira", "marisco"],
	"lurdes_chaves": ["chave_enferrujada", "sino_bronze", "anel_do_poco", "ferradura_velha"],
	"ines_camara": ["idolo_jade", "idolo_ouro", "escaravelho_jade", "adaga_cerimonial", "mascara_ouro"],
	"bjorn_expedicao": ["bussola_antiga", "bussola_congelada", "cronometro_explorador", "lanterna_expedicao", "crampon_enferrujado", "medalha_polar"],
	"vega_sinal": ["cristal_eco", "orbe_vibrante", "geodo_estrelar", "engrenagem_alienigena", "fragmento_meteorito", "nucleo_adormecido"],
}

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
var _holding_cooldown_left: float = 0.0
var _was_holding_in_range: bool = false
var _last_held_item_id: String = ""
## Conversas no DONE enquanto falta fragmento (só no host, que decide as falas).
var _done_talks: int = 0


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
		var marker_lift: float = 1.62 if _say_left > 0.0 else 1.25
		_marker.position.y = focus_offset.y + marker_lift + sin(_bob_time * 3.0) * 0.06

	var local_player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D if is_inside_tree() else null
	_check_holding_reaction(delta, local_player)

	# Estudo How to Fish (NPC.cs): respiração/balanço, olhar que segue e boca ao falar
	if _model != null:
		if _head_node == null:
			_cache_face_parts()
		_process_npc_life(delta, local_player)


## Devolve o id do item/ferramenta/comida atualmente selecionado na mão do jogador (ou "").
static func get_player_held_item_id(player: Node) -> String:
	if player == null:
		return ""
	if player.has_method(&"get_held_item_id"):
		var id_val: String = str(player.call(&"get_held_item_id"))
		if not id_val.is_empty():
			return id_val
	if "held_item_id" in player and not str(player.get("held_item_id")).is_empty():
		return str(player.get("held_item_id"))
	if "inventory" in player and player.inventory != null and player.inventory.has_method(&"get_selected"):
		var sel: Variant = player.inventory.call(&"get_selected")
		if sel != null:
			if "item" in sel and sel.item != null and "id" in sel.item:
				return str(sel.item.id)
			if "tool_id" in sel and not String(sel.tool_id).is_empty():
				return String(sel.tool_id)
			if "tool_data" in sel and sel.tool_data != null and "id" in sel.tool_data:
				return str(sel.tool_data.id)
	if "held_tool_id" in player and not String(player.get("held_tool_id")).is_empty():
		return String(player.get("held_tool_id"))
	if player.has_method(&"get_selected_item"):
		var sel_item: Variant = player.call(&"get_selected_item")
		if sel_item is Dictionary and sel_item.has("id"):
			return str(sel_item["id"])
		if sel_item != null and "id" in sel_item:
			return str(sel_item.get("id"))
	return ""


## Verdadeiro se `item_id` for o item pedido/associado a este NPC (#87).
func is_matching_holding_item(item_id: String) -> bool:
	if item_id.is_empty():
		return false
	if not holding_item_id.is_empty():
		for part: String in holding_item_id.split(","):
			if part.strip_edges() == item_id:
				return true
	if not reward_item_id.is_empty() and item_id == reward_item_id:
		return true
	if QUEST_HOLDING_ITEMS.has(quest_id):
		var list: Array = QUEST_HOLDING_ITEMS[quest_id]
		if list.has(item_id):
			return true
	return false


func _check_holding_reaction(delta: float = 0.0, local_player: Node3D = null) -> void:
	if _holding_cooldown_left > 0.0:
		_holding_cooldown_left = maxf(_holding_cooldown_left - delta, 0.0)
	if local_player == null and is_inside_tree():
		local_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if state == QuestState.EVENT or local_player == null:
		_was_holding_in_range = false
		_last_held_item_id = ""
		return
	var dist: float = global_position.distance_to(local_player.global_position)
	if dist > HOLDING_DETECT_RANGE:
		_was_holding_in_range = false
		_last_held_item_id = ""
		return
	var held_id: String = get_player_held_item_id(local_player)
	if not is_matching_holding_item(held_id):
		_was_holding_in_range = false
		_last_held_item_id = ""
		return
	var should_trigger: bool = (not _was_holding_in_range) or (held_id != _last_held_item_id) or (_holding_cooldown_left <= 0.0)
	if should_trigger and _say_left <= 0.0:
		var text: String = line_holding if not line_holding.is_empty() else DEFAULT_HOLDING_LINE
		show_say(text, 4.0)
		_holding_cooldown_left = HOLDING_REACT_COOLDOWN
		_was_holding_in_range = true
		_last_held_item_id = held_id


func _process_npc_life(delta: float, p_local_player: Node3D = null) -> void:
	# 1. Respiração e balanço suave (idle breathing)
	var breath: float = sin(_bob_time * 2.2)
	_model.position.y = _model_base_pos.y + breath * 0.015
	_model.scale.y = 1.0 + breath * 0.012
	_model.rotation.z = _model_base_rot.z + sin(_bob_time * 1.1) * 0.012

	# 2. Olhos e cabeça que seguem o jogador mais próximo
	var player_pos: Vector3 = Vector3.ZERO
	var has_player: bool = false
	var p: Node3D = p_local_player
	if p == null and is_inside_tree():
		p = get_tree().get_first_node_in_group(&"player") as Node3D
	if p != null and global_position.distance_to(p.global_position) <= 7.0:
		player_pos = p.global_position + Vector3(0, 1.4, 0)
		has_player = true
	else:
		var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null and global_position.distance_to(cam.global_position) <= 7.0:
			player_pos = cam.global_position
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
			var hint: bool = _map_hint_turn()
			say_to(peer_id, line_map_hint if hint else line_done, 6.0 if hint else 4.0)
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


## Vez da line_map_hint no DONE: alterna com line_done (a dica primeiro) até a equipa juntar
## os fragmentos todos do Mapa do Tesouro.
func _map_hint_turn() -> bool:
	if line_map_hint.is_empty() or GameState.instance == null or GameState.instance.has_all_map_fragments():
		return false
	_done_talks += 1
	return _done_talks % 2 == 1


func _objective_done() -> bool:
	if objective_flag == &"":
		return true
	var flags: WorldFlags = WorldFlags.find(get_tree())
	return flags != null and flags.has_flag(objective_flag)


func _event() -> Node:
	return get_node_or_null(event_path) if not event_path.is_empty() else null
