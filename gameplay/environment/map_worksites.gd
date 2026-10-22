extends Node3D

## #161: composição interna cosmética, sem estado de jogo ou processamento por frame.
@export var theme: String = "praia"

const GENERATORS: Dictionary = {
	"praia": "res://gameplay/environment/beach_worksites.gd",
	"campo": "res://gameplay/environment/field_worksites.gd",
	"ruinas": "res://gameplay/environment/regional_worksites.gd",
	"geleira": "res://gameplay/environment/regional_worksites.gd",
	"cratera": "res://gameplay/environment/regional_worksites.gd",
}


func _ready() -> void:
	build()


func build() -> bool:
	for child: Node in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()
	if not GENERATORS.has(theme):
		return false
	var path: String = GENERATORS[theme]
	if not ResourceLoader.exists(path):
		push_warning("MapWorksites: missing generator %s" % path)
		return false
	var generator: Script = load(path) as Script
	var args: Array = [theme] if theme in ["ruinas", "geleira", "cratera"] else []
	var mesh: Mesh = generator.callv("build", args) as Mesh
	if mesh == null:
		return false
	var batch: MeshInstance3D = MeshInstance3D.new()
	batch.name = &"WorksiteBatch"
	batch.mesh = mesh
	batch.material_override = ToonKit.vertex_material(false, true)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(batch)
	return true
