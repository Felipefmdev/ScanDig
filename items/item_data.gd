class_name ItemData
extends Resource

enum Category {
	COMUM = 0,
	HISTORICO = 1,
	RARO = 2,
	ESTRANHO = 3,
}

enum MaterialType {
	FERRO = 0,
	ALUMINIO = 1,
	PRATA = 2,
	OURO = 3,
	DESCONHECIDO = 4,
}

enum SizeCategory {
	PEQUENO = 0,
	MEDIO = 1,
	GRANDE = 2,
	COLOSSAL = 3,
}

@export var id: String = ""
@export var display_name: String = ""
@export var category: Category = Category.COMUM
@export var material_type: MaterialType = MaterialType.FERRO
@export var size_category: SizeCategory = SizeCategory.PEQUENO
@export var base_value: int = 0
@export_range(0.0, 1.0, 0.01) var fragility: float = 0.0
@export var depth_cm: int = 0


func calculate_value(integrity: float) -> int:
	var clamped_integrity: float = clampf(integrity, 0.0, 1.0)
	return int(round(float(base_value) * clamped_integrity))
