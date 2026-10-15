class_name BossAltar
extends BuriedSpot

## Ponto especial onde dorme o chefe do mapa: totem de conchas + aviso. Só o jogador o acorda,
## ao cavar até ao fim (nunca aparece por acaso). Não tem item: no fim surge o chefe.

signal boss_spawned(boss: Node3D)

const BOSS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/king_crab.tscn")
const SHELL_WHITE: Color = Color(0.95, 0.9, 0.82)
const SHELL_PINK: Color = Color(0.95, 0.68, 0.62)
const DRIFTWOOD: Color = Color(0.52, 0.38, 0.26)
const GOLD: Color = Color(1.0, 0.78, 0.12)

@export var boss_scene: PackedScene = null
## Distância (para a frente do altar, -Z) a que o chefe sai da areia.
@export var boss_offset: Vector3 = Vector3(0.0, 0.0, -3.0)
@export var label_text: String = "Algo grande dorme aqui... [cavar]"

var _label: Label3D = null
var _totem: Node3D = null
var _woken: bool = false


func _ready() -> void:
	item = null
	rare_variant_chance = 0.0
	super._ready()
	if boss_scene == null:
		boss_scene = BOSS_SCENE
	_build_totem()


func dig(is_careful: bool, damage_multiplier: float = 1.0) -> Dictionary:
	var res: Dictionary = super.dig(is_careful, damage_multiplier)
	if bool(res.get("revealed", false)) and not _woken:
		_wake_boss()
	return res


func _wake_boss() -> void:
	_woken = true
	if _label != null:
		_label.text = "Ele acordou!"
		_label.modulate = Color(1.0, 0.35, 0.25)
	DisturbanceMeter.report(DisturbanceMeter.NOISE_REVEAL * 3.0, global_position)
	SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
	var boss: Node3D = boss_scene.instantiate() as Node3D
	var parent: Node = get_parent()
	var world_pos: Vector3 = global_transform * boss_offset
	# Posiciona antes de entrar na árvore: o _ready do chefe guarda a posição de partida.
	boss.position = (parent as Node3D).global_transform.affine_inverse() * world_pos if parent is Node3D else world_pos
	boss.rotation.y = global_rotation.y
	parent.add_child(boss)
	boss.global_position = world_pos
	boss_spawned.emit(boss)


func _build_totem() -> void:
	_totem = Node3D.new()
	_totem.name = "Totem"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Poste de madeira com uma coroa de conchas no topo
	LowPolyMesh.prism(st, Vector3(0.9, 0.0, 0.4), Vector3(0.9, 1.6, 0.4), 0.09, 0.07, 6, DRIFTWOOD)
	LowPolyMesh.prism(st, Vector3(0.9, 1.6, 0.4), Vector3(0.9, 1.78, 0.4), 0.16, 0.18, 6, GOLD)
	for k: int in range(5):
		var ang: float = TAU * float(k) / 5.0
		var b: Vector3 = Vector3(0.9 + cos(ang) * 0.15, 1.78, 0.4 + sin(ang) * 0.15)
		LowPolyMesh.prism(st, b, b + Vector3(0, 0.16, 0), 0.05, 0.0, 4, GOLD)
	# Círculo de conchas à volta do ponto
	for k: int in range(9):
		var ang: float = TAU * float(k) / 9.0
		var p: Vector3 = Vector3(cos(ang), 0.02, sin(ang)) * 0.75
		LowPolyMesh.prism(st, p, p + Vector3(0, 0.12, 0) + Vector3(cos(ang), 0, sin(ang)) * 0.05, 0.09, 0.0, 5,
			SHELL_WHITE if k % 2 == 0 else SHELL_PINK)
	_totem.add_child(LowPolyMesh.commit(st, "Mesh", LowPolyMesh.make_material()))
	add_child(_totem)

	_label = Label3D.new()
	_label.name = "Label"
	_label.text = label_text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 2.3, 0.0)
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.modulate = Color(1.0, 0.85, 0.45)
	add_child(_label)
