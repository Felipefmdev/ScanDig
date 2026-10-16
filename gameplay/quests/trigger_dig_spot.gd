class_name TriggerDigSpot
extends BuriedSpot

## Ponto fixo de missão que se encontra com o detector e se cava (#39), como o BossAltar mas
## em vez de chefe liga uma bandeira do mapa (ex. "anzol_desenterrado": aparece o anzol de ouro
## para apanhar). Não tem item do item_pool. Coop: fixo na cena (networked = false); quem cava
## corre o dig() localmente e, num cliente, o fim da escavação pede ao host que ligue a bandeira.

@export var reveal_flag: StringName = &""

var _fired: bool = false


func _ready() -> void:
	item = null
	rare_variant_chance = 0.0
	super._ready()
	_watch_flag.call_deferred()


## Todos os peers: quando a bandeira liga (cavado por qualquer jogador), o ponto sai do
## detector e desaparece também aqui.
func _watch_flag() -> void:
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags != null and reveal_flag != &"":
		flags.when_set(reveal_flag, _on_revealed_elsewhere)


func _on_revealed_elsewhere() -> void:
	_fired = true
	if is_in_group(&"buried_spots"):
		remove_from_group(&"buried_spots")
		get_tree().create_timer(4.0).timeout.connect(queue_free)


func dig(is_careful: bool, damage_multiplier: float = 1.0, report_noise: bool = true, digger: Node = null) -> Dictionary:
	var res: Dictionary = super.dig(is_careful, damage_multiplier, report_noise, digger)
	if bool(res.get("revealed", false)) and not _fired:
		_fired = true
		if HostSync.is_host(self):
			_fire()
		else:
			_rpc_request_fire.rpc_id(1)
	return res


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_fire() -> void:
	if multiplayer.is_server():
		_fire()


func _fire() -> void:
	var flags: WorldFlags = WorldFlags.find(get_tree())
	if flags != null and reveal_flag != &"":
		flags.set_flag(reveal_flag)
