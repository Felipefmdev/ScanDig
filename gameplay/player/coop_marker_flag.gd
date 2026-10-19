class_name CoopMarkerFlag
extends Node3D

## Bandeirinha física 3D fincada no mundo pelo sistema de marcadores no coop (#107).
## Sinaliza um ponto de interesse ("sinal aqui"), alerta ("perigo") ou pedido de socorro ("ajuda").
## Fica visível para todos por LIFETIME s (20s) com flâmula animada, ícone 3D e desaparece com fade.

enum MarkerType {
	SIGNAL = 0,
	DANGER = 1,
	HELP = 2,
}

const GROUP: StringName = &"coop_markers"
const LIFETIME: float = 20.0
const FADE_TIME: float = 2.0

const TYPE_CONFIG: Dictionary = {
	MarkerType.SIGNAL: {
		"name": "Sinal aqui",
		"icon": "🚩",
		"color": Color(0.18, 0.88, 0.45), # Verde esmeralda / sinal
		"desc": "Ponto de interesse ou sinal detectado",
	},
	MarkerType.DANGER: {
		"name": "Perigo",
		"icon": "⚠️",
		"color": Color(0.95, 0.25, 0.20), # Vermelho alerta
		"desc": "Criatura hostil ou armadilha",
	},
	MarkerType.HELP: {
		"name": "Ajuda",
		"icon": "🆘",
		"color": Color(0.25, 0.65, 1.0), # Azul socorro
		"desc": "Preciso de socorro ou reforço",
	},
}

@export var marker_type: int = MarkerType.SIGNAL:
	set(value):
		marker_type = clampi(value, 0, 2)
		if is_inside_tree():
			_apply_visuals()

@export var owner_peer_id: int = 1
@export var owner_player_name: String = ""

var time_left: float = LIFETIME
var _is_fading: bool = false
var _flag_mesh: MeshInstance3D = null
var _label_icon: Label3D = null
var _label_text: Label3D = null
var _beacon_mesh: MeshInstance3D = null
var _seed: float = 0.0


func _init(p_type: int = MarkerType.SIGNAL, p_owner_id: int = 1, p_name: String = "") -> void:
	marker_type = p_type
	owner_peer_id = p_owner_id
	owner_player_name = p_name
	_seed = randf() * 100.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_build_flag_3d()
	_apply_visuals()
	SFX.play_at(SFX.STONE_IMPACT, global_position, -2.0, 0.1)


func _process(delta: float) -> void:
	if _is_fading:
		return
	time_left -= delta
	if time_left <= 0.0:
		fade_out_and_free()
		return

	# Leve ondulação da flâmula ao vento
	if _flag_mesh != null:
		var wave: float = sin(Time.get_ticks_msec() * 0.007 + _seed) * 0.18
		_flag_mesh.rotation.y = wave

	# Leve pulso de flutuação no ícone
	if _label_icon != null:
		_label_icon.position.y = 1.58 + sin(Time.get_ticks_msec() * 0.005 + _seed) * 0.035

	# Nos últimos segundos: encolhe suavemente
	if time_left <= FADE_TIME:
		var ratio: float = clampf(time_left / FADE_TIME, 0.0, 1.0)
		scale = Vector3.ONE * ratio


func fade_out_and_free() -> void:
	if _is_fading:
		return
	_is_fading = true
	var t: Tween = create_tween()
	t.tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func get_type_config() -> Dictionary:
	return TYPE_CONFIG.get(marker_type, TYPE_CONFIG[MarkerType.SIGNAL])


func get_display_label() -> String:
	var cfg: Dictionary = get_type_config()
	var type_name: String = tr(cfg.get("name", "Marcador"))
	if not owner_player_name.is_empty():
		return "%s (%s)" % [type_name, owner_player_name]
	return type_name


## Idioma trocado ao vivo (#131): "Tipo (dono)" se refaz.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label_text != null:
		_label_text.text = get_display_label()


func _build_flag_3d() -> void:
	# 1. Mastro metálico (cilindro)
	var mast: MeshInstance3D = MeshInstance3D.new()
	mast.name = "Mast"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.03
	cyl.height = 1.35
	mast.mesh = cyl
	mast.position = Vector3(0.0, 0.675, 0.0)

	var mast_mat: StandardMaterial3D = StandardMaterial3D.new()
	mast_mat.albedo_color = Color(0.28, 0.28, 0.32)
	mast_mat.metallic = 0.85
	mast_mat.roughness = 0.35
	mast.material_override = mast_mat
	add_child(mast)

	# 2. Flâmula (pano da bandeira)
	_flag_mesh = MeshInstance3D.new()
	_flag_mesh.name = "Banner"
	var banner: BoxMesh = BoxMesh.new()
	banner.size = Vector3(0.48, 0.32, 0.02)
	_flag_mesh.mesh = banner
	_flag_mesh.position = Vector3(0.25, 1.12, 0.0)
	add_child(_flag_mesh)

	# 3. Esfera brilhante na ponta do mastro
	_beacon_mesh = MeshInstance3D.new()
	_beacon_mesh.name = "Beacon"
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	_beacon_mesh.mesh = sphere
	_beacon_mesh.position = Vector3(0.0, 1.38, 0.0)
	add_child(_beacon_mesh)

	# 4. Ícone do símbolo flutuante (Label3D)
	_label_icon = Label3D.new()
	_label_icon.name = "IconLabel"
	_label_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_icon.no_depth_test = true
	_label_icon.pixel_size = 0.007
	_label_icon.font_size = 40
	_label_icon.outline_size = 10
	_label_icon.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	_label_icon.position = Vector3(0.0, 1.58, 0.0)
	add_child(_label_icon)

	# 5. Rótulo de texto e dono
	_label_text = Label3D.new()
	_label_text.name = "TextLabel"
	_label_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_text.no_depth_test = true
	_label_text.pixel_size = 0.0045
	_label_text.font_size = 26
	_label_text.outline_size = 8
	_label_text.outline_modulate = Color(0.05, 0.05, 0.05, 0.9)
	_label_text.position = Vector3(0.0, 1.82, 0.0)
	add_child(_label_text)


func _apply_visuals() -> void:
	var cfg: Dictionary = get_type_config()
	var color: Color = cfg.get("color", Color.WHITE)
	var icon: String = cfg.get("icon", "🚩")

	if _flag_mesh != null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color * 0.7
		mat.roughness = 0.4
		_flag_mesh.material_override = mat

	if _beacon_mesh != null:
		var b_mat: StandardMaterial3D = StandardMaterial3D.new()
		b_mat.albedo_color = color
		b_mat.emission_enabled = true
		b_mat.emission = color
		_beacon_mesh.material_override = b_mat

	if _label_icon != null:
		_label_icon.text = icon
		_label_icon.modulate = color

	if _label_text != null:
		_label_text.text = get_display_label()
		_label_text.modulate = Color.WHITE
