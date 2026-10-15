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


func _ready() -> void:
	super._ready()
	if prompt == "[E] Interagir":
		prompt = "[E] Falar com %s" % npc_name
	_model = get_node_or_null(^"Model") as Node3D
	_marker = _make_label(Color(1.0, 0.82, 0.1), Color(0.1, 0.06, 0.02), 110)
	_marker.name = "Marker"
	_marker.position = focus_offset + Vector3.UP * 1.25
	add_child(_marker)
	if HostSync.is_host(self):
		if QuestRewards.is_quest_completed(quest_id):
			state = QuestState.DONE
		_connect_host.call_deferred()
	_refresh_marker()


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
