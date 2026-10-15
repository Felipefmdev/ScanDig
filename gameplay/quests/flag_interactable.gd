class_name FlagInteractable
extends Interactable

## Interativo genérico ligado a bandeiras do mapa (#39): cobre itens de missão (o anzol),
## relíquias escondidas fora do item_pool, pedras que se empurram, garrafas com mensagem,
## easter eggs... Tudo por @export, sem código por objeto:
##   requires_flag  — só aparece/aceita [E] com esta bandeira ligada (ex. "mare_baixa");
##   sets_flag      — liga esta bandeira ao usar (ex. "anzol_encontrado", "pedra_empurrada");
##   item_id        — larga este item do catálogo no chão (relíquia, recompensa);
##   secret_id      — reporta o segredo (QuestRewards.report_secret);
##   say_text       — texto mostrado a quem usou (mensagem da garrafa, fala);
##   use_offset/use_rotation — o filho "Model" desliza/roda ao usar (pedra empurrada);
##   repeatable     — pode usar-se várias vezes (garrafas, pato) sem mudar de estado;
##   start_path     — chama start() nesse nó ao usar (ex.: o sino chama os corvos: WaveEvent).
## state: 0 = por usar, 1 = usado.

const STATE_UNUSED: int = 0
const STATE_USED: int = 1

@export var requires_flag: StringName = &""
@export var sets_flag: StringName = &""
@export var item_id: String = ""
@export var secret_id: String = ""
@export_multiline var say_text: String = ""
@export var say_seconds: float = 5.0
@export var repeatable: bool = false
## Prompt depois de usado (vazio = sem [E] depois de usado, se não for repetível).
@export var used_prompt: String = ""
## Esconde o modelo depois de usado (ex.: o anzol apanhado).
@export var hide_model_when_used: bool = false
@export var use_offset: Vector3 = Vector3.ZERO
@export var use_rotation_deg: Vector3 = Vector3.ZERO
## Onde (local) o item cai.
@export var drop_offset: Vector3 = Vector3(0.0, 0.6, 0.0)
## Som tocado em todos os peers ao usar (lista de caminhos do SFX ou caminho).
@export var use_sound: String = ""
## Nota sintetizada (Hz) tocada ao usar, em vez de/além de use_sound (ex.: o sino, ~196 Hz).
@export var use_note_hz: float = 0.0
## Nó com start() chamado ao usar (WaveEvent, BossTrigger...).
@export var start_path: NodePath = NodePath("")

var _model: Node3D = null
var _model_rest: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	if requires_flag != &"":
		start_active = false
		hide_when_inactive = true
	super._ready()
	_model = get_node_or_null(^"Model") as Node3D
	if _model != null:
		_model_rest = _model.transform
	if requires_flag != &"" and HostSync.is_host(self):
		_watch_flag.call_deferred()


func get_prompt() -> String:
	if state == STATE_USED and not used_prompt.is_empty():
		return used_prompt
	return prompt


func _watch_flag() -> void:
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags == null:
		return
	flags.flag_changed.connect(_on_flag_changed)
	_on_flag_changed(requires_flag, flags.has_flag(requires_flag))


## Host: a bandeira de que depende mudou (ex. a maré subiu e desceu).
func _on_flag_changed(flag: StringName, value: bool) -> void:
	if flag != requires_flag:
		return
	var can_use: bool = value and (repeatable or state == STATE_UNUSED or not used_prompt.is_empty())
	set_active(can_use)


func _on_interact(peer_id: int) -> void:
	if not say_text.is_empty():
		say_to(peer_id, say_text, say_seconds)
	if state == STATE_USED and not repeatable:
		super._on_interact(peer_id)
		return
	if not use_sound.is_empty() or use_note_hz > 0.0:
		_play_use_sound()
		HostSync.broadcast(self, &"_rpc_use_sound")
	if not repeatable:
		set_state(STATE_USED)
		if used_prompt.is_empty():
			set_active(false)
	if sets_flag != &"":
		var flags: WorldFlags = WorldFlags.find(get_tree())
		if flags != null:
			flags.set_flag(sets_flag)
	if not item_id.is_empty():
		QuestRewards.drop_item(get_tree(), item_id, global_transform * drop_offset)
	if not start_path.is_empty():
		var target: Node = get_node_or_null(start_path)
		if target != null and target.has_method(&"start"):
			target.call(&"start")
	if not secret_id.is_empty():
		QuestRewards.report_secret(secret_id)
	super._on_interact(peer_id)


func _on_state_applied() -> void:
	super._on_state_applied()
	if _model == null:
		return
	if state == STATE_USED:
		if hide_model_when_used:
			_model.visible = false
		if use_offset != Vector3.ZERO or use_rotation_deg != Vector3.ZERO:
			var target: Transform3D = Transform3D(
				_model_rest.basis * Basis.from_euler(use_rotation_deg * (PI / 180.0)),
				_model_rest.origin + use_offset)
			var tw: Tween = create_tween()
			tw.tween_property(_model, "transform", target, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


@rpc("authority", "call_remote", "reliable")
func _rpc_use_sound() -> void:
	_play_use_sound()


func _play_use_sound() -> void:
	if not use_sound.is_empty():
		SFX.play_at(use_sound, global_position)
	if use_note_hz > 0.0:
		SFX.play_at(MusicShell.make_note(use_note_hz), get_focus_point(), 4.0, 0.0)
