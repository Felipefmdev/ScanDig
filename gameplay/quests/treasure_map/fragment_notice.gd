class_name FragmentNotice
extends Node

## Mapa do Tesouro (#112): aviso no HUD do jogador local quando a equipa encontra um fragmento.
## Corre em cada peer (o GameState de cada um emite map_fragment_found pelo snapshot do host).
## O SpotSpawner de cada mapa cria-o; os primeiros segundos depois de entrar no mapa ignoram-se
## (a sincronização inicial de um convidado traz os fragmentos que a equipa já tinha).

const MSG_COLOR: Color = Color(1.0, 0.85, 0.35)
const MSG_TIME: float = 5.0
const IGNORE_FIRST: float = 3.0

var _ready_ms: int = 0


func _ready() -> void:
	_ready_ms = Time.get_ticks_msec()
	if GameState.instance != null:
		GameState.instance.map_fragment_found.connect(_on_fragment_found)


static func message_for(fragment_id: String, found: int, total: int) -> String:
	if found >= total:
		return "🗺️ Último fragmento! O Mapa do Tesouro está completo: há uma ilha esperando a equipe."
	var map_id: String = str(GameState.MAP_FRAGMENTS.get(fragment_id, {}).get("map", ""))
	return "🗺️ Fragmento do Mapa do Tesouro (%s)! %d/%d — veja o pergaminho na base." % [
		map_id.capitalize(), found, total]


func _on_fragment_found(fragment_id: String) -> void:
	if Time.get_ticks_msec() - _ready_ms < int(IGNORE_FIRST * 1000.0) or not is_inside_tree():
		return
	var gs: GameState = GameState.instance
	var text: String = message_for(fragment_id, gs.map_fragments.size(), GameState.MAP_FRAGMENT_IDS.size())
	for n: Node in get_tree().get_nodes_in_group(&"player"):
		if n.has_method(&"_show_temporary_message"):
			n.call(&"_show_temporary_message", text, MSG_COLOR, MSG_TIME)
	SFX.play_ui(SFX.BUY)
