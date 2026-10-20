class_name FitCenterContainer
extends Container

## CenterContainer que encolhe para caber (#146): centra cada filho no tamanho mínimo e, quando o
## mínimo passa da área (ui_scale 1.3 numa tela baixa, como 1366x768 ou 2560x1080), aplica uma
## escala uniforme até caber, com `margin` de folga nas bordas. Se o filho cabe, é um
## CenterContainer comum (escala 1). O filho fica com pivot (0, 0): a escala parte do canto.

## Folga mínima entre o conteúdo encolhido e a borda, em pixels.
@export var margin: float = 8.0
## Menor escala aceita: abaixo dela o conteúdo passa da área, como num CenterContainer.
@export var min_scale: float = 0.5


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for node: Node in get_children():
		var child: Control = node as Control
		if child == null or not child.visible or child.top_level:
			continue
		var need: Vector2 = child.get_combined_minimum_size()
		var fit: float = fit_scale(need, size, margin, min_scale)
		fit_child_in_rect(child, Rect2(((size - need * fit) * 0.5).floor(), need))
		child.pivot_offset = Vector2.ZERO
		child.scale = Vector2(fit, fit)


## Escala (min_scale..1) para `need` caber em `area` menos `margin_px` de cada lado.
static func fit_scale(need: Vector2, area: Vector2, margin_px: float = 8.0, lowest: float = 0.5) -> float:
	if need.x <= 0.0 or need.y <= 0.0:
		return 1.0
	var avail: Vector2 = area - Vector2(margin_px, margin_px) * 2.0
	return clampf(minf(avail.x / need.x, avail.y / need.y), lowest, 1.0)
