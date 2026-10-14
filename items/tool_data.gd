class_name ToolData
extends Resource

## Definição de uma ferramenta/arma comprável (catálogo em res://items/tools/).
## Ocupa um slot da mochila como CarriedItem (ver CarriedItem.create_from_tool_data).

enum Category {
	WEAPON = 0,      ## Uso infinito (ex.: estilingue)
	CONSUMABLE = 1,  ## Gasta cargas e some quando acabam (ex.: repelente)
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var price: int = 0
@export var category: Category = Category.WEAPON
## Cargas iniciais para consumíveis (-1 = infinito).
@export var charges: int = -1
@export var color: Color = Color(0.9, 0.6, 0.2)
## Visual opcional quando está no chão; sem cena, usa uma caixa com `color`.
@export var world_scene: PackedScene = null
