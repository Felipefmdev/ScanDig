class_name ToolData
extends Resource

## Definição de uma ferramenta/arma comprável (catálogo em res://items/tools/).
## Ocupa um slot da mochila como CarriedItem (ver CarriedItem.create_from_tool_data).

enum Category {
	WEAPON = 0,      ## Uso infinito (ex.: estilingue)
	CONSUMABLE = 1,  ## Gasta cargas e some quando acabam (ex.: repelente)
	FOOD = 2,        ## Comida escavada: não se compra; comer cura `heal_amount`
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
@export_group("Comida")
## Vida recuperada ao comer (só FOOD).
@export var heal_amount: float = 0.0
## Fome saciada ao comer (0-100 da barra de fome).
@export var hunger_restore: float = 0.0
## Mapas (MapData.id) onde aparece ao cavar fora de um sinal.
@export var dig_maps: PackedStringArray = PackedStringArray()
## Peso no sorteio entre as comidas do mesmo mapa.
@export var dig_weight: float = 1.0
