extends Node3D

## #155: ilhas de luz nos destinos, sem alterar ambiente global ou regras da noite.
@export_enum("praia", "campo", "ruinas", "geleira") var theme: String = "praia"

const SUPPORTED: Array[String] = ["praia", "campo", "ruinas", "geleira"]
const WARM: Color = Color(1.0, 0.74, 0.43)

var _session: SessionManager = null
var _active: bool = false
var _borrowed: Dictionary = {}


func _ready() -> void:
	_session = SessionManager.instance
	if _session != null:
		_session.scene_loaded.connect(_on_scene_loaded)
	_refresh()


func _exit_tree() -> void:
	if is_instance_valid(_session) and _session.scene_loaded.is_connected(_on_scene_loaded):
		_session.scene_loaded.disconnect(_on_scene_loaded)
	_restore_borrowed()


func _on_scene_loaded(_scene_path: String) -> void:
	_refresh()


func _refresh() -> void:
	if _active or not SUPPORTED.has(theme) or not SessionManager.is_night():
		return
	_active = true
	if theme == "praia":
		# BeachDressing cria as lanternas antes de scene_loaded. Nunca duplicar.
		var dressing: Node = get_parent().get_node_or_null("BeachDressing")
		if dressing != null:
			for node: Node in dressing.get_children():
				if node is OmniLight3D and _borrowed.size() < 2:
					var lamp: OmniLight3D = node as OmniLight3D
					_borrowed[lamp] = [lamp.light_energy, lamp.omni_range,
						lamp.distance_fade_enabled, lamp.distance_fade_begin, lamp.distance_fade_length]
					_configure(lamp, 0.8, 6.0)
		# Se ready veio antes do dressing, scene_loaded faz a tentativa final.
		_active = not _borrowed.is_empty()
		return
	_add_light(&"LandmarkDelivery", ^"BaseEntrega", 0.8, 6.0)
	_add_light(&"LandmarkShop", ^"Banca", 0.6, 4.0)


func _add_light(light_name: StringName, anchor_path: NodePath, energy: float, radius: float) -> void:
	var anchor: Node3D = get_parent().get_node_or_null(anchor_path) as Node3D
	if anchor == null:
		return
	var light: OmniLight3D = OmniLight3D.new()
	light.name = light_name
	light.position = to_local(anchor.to_global(Vector3(0.0, 2.0, 0.0)))
	light.light_color = WARM
	light.shadow_enabled = false
	_configure(light, energy, radius)
	add_child(light)


func _configure(light: OmniLight3D, energy: float, radius: float) -> void:
	light.light_energy = energy
	light.omni_range = radius
	light.distance_fade_enabled = true
	light.distance_fade_begin = 30.0
	light.distance_fade_length = 15.0


func _restore_borrowed() -> void:
	for lamp: OmniLight3D in _borrowed:
		if not is_instance_valid(lamp):
			continue
		var original: Array = _borrowed[lamp]
		lamp.light_energy = original[0]
		lamp.omni_range = original[1]
		lamp.distance_fade_enabled = original[2]
		lamp.distance_fade_begin = original[3]
		lamp.distance_fade_length = original[4]
	_borrowed.clear()
