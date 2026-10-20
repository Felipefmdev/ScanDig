extends RefCounted

## Checagem de layout por retângulos (#146), usada pelas capturas de proporção de tela
## (aspect_snapshots.gd) e pelo test_aspect_layout.gd. Olha os Controls visíveis sob `root`, em
## coordenadas da viewport (as mesmas do get_visible_rect, já com o ui_scale), e devolve problemas:
## - "fora": Control fora da área visível (o que está dentro de rolagem ou de pai que recorta conta
##   pelo pai);
## - "sobreposto": dois painéis de topo (PanelContainer/Panel sem painel acima) da mesma camada que
##   se cruzam;
## - "cortado": texto que não cabe no próprio Control (Label/Button com clip/reticências, Label com
##   linhas escondidas, RichTextLabel sem rolagem) ou que passa do painel que o contém.
## Cada problema é {"kind", "path", "rect", "detail"}.

## Folga em pixels lógicos (arredondamento de âncoras e de escala).
const EPS: float = 1.5


## `scope` limita a busca a uma subárvore (nos testes GUT, para não pegar o painel do próprio GUT).
## `floating` (avisos por cima de tudo, como o toast) não pode cruzar painel nenhum, de qualquer camada.
static func audit(root: Window, ignore: Array[NodePath] = [], scope: Node = null, floating: Array[Control] = []) -> Array[Dictionary]:
	var view: Rect2 = root.get_visible_rect()
	var out: Array[Dictionary] = []
	var panels: Array[Control] = []
	var ignored: Array[Node] = []
	for p: NodePath in ignore:
		var n: Node = root.get_node_or_null(p)
		if n != null:
			ignored.append(n)
	var top: Node = root if scope == null else scope
	var nodes: Array[Node] = top.find_children("*", "Control", true, false)
	if top is Control:
		nodes.push_front(top)
	for node: Node in nodes:
		var c: Control = node as Control
		if not _shown(c) or _under_any(c, ignored):
			continue
		var r: Rect2 = rect_of(c)
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		var clipper: Control = _clip_ancestor(c)
		if clipper == null and not _inside(r, view):
			out.append(_issue("fora", c, r, "viewport %s" % view.size))
		if (c is PanelContainer or c is Panel) and _panel_ancestor(c) == null and clipper == null:
			panels.append(c)
		_check_text(c, r, clipper, out)
	for f: Control in floating:
		if f != null and _shown(f) and not panels.has(f):
			panels.append(f)
	for i: int in panels.size():
		for j: int in range(i + 1, panels.size()):
			var a: Control = panels[i]
			var b: Control = panels[j]
			var cross: bool = floating.has(a) or floating.has(b)
			if (_layer(a) != _layer(b) and not cross) or a.is_ancestor_of(b) or b.is_ancestor_of(a):
				continue
			var inter: Rect2 = rect_of(a).intersection(rect_of(b))
			if inter.size.x > EPS and inter.size.y > EPS:
				out.append(_issue("sobreposto", a, rect_of(a), "com %s %s" % [_short(b), rect_of(b)]))
	return out


## Retângulo do Control na viewport (com rotação, a caixa que o envolve).
static func rect_of(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


static func describe(issues: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	for it: Dictionary in issues:
		lines.append("%s %s %s %s" % [it["kind"], it["path"], it["rect"], it["detail"]])
	return "\n".join(lines)


static func _issue(kind: String, c: Control, r: Rect2, detail: String) -> Dictionary:
	return {"kind": kind, "path": _short(c), "rect": "(%d,%d %dx%d)" % [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)], "detail": detail}


## Caminho curto: os 3 últimos nós (os nomes automáticos @Label@123 viram a classe).
static func _short(n: Node) -> String:
	var parts: PackedStringArray = []
	var cur: Node = n
	while cur != null and parts.size() < 3 and not (cur is Window):
		var nm: String = String(cur.name)
		parts.insert(0, cur.get_class() if nm.begins_with("@") else nm)
		cur = cur.get_parent()
	return "/".join(parts)


static func _shown(c: Control) -> bool:
	if not c.is_visible_in_tree():
		return false
	if c.self_modulate.a < 0.05:
		return false
	var cur: Node = c
	while cur != null:
		if cur is CanvasLayer and not (cur as CanvasLayer).visible:
			return false
		if cur is CanvasItem and (cur as CanvasItem).modulate.a < 0.05:
			return false
		cur = cur.get_parent()
	return true


static func _under_any(n: Node, list: Array[Node]) -> bool:
	for a: Node in list:
		if a == n or a.is_ancestor_of(n):
			return true
	return false


static func _inside(r: Rect2, view: Rect2) -> bool:
	return r.position.x >= view.position.x - EPS and r.position.y >= view.position.y - EPS \
		and r.end.x <= view.end.x + EPS and r.end.y <= view.end.y + EPS


## Pai que recorta o filho (ScrollContainer ou clip_contents).
static func _clip_ancestor(c: Control) -> Control:
	var cur: Node = c.get_parent()
	while cur is Control:
		if cur is ScrollContainer or (cur as Control).clip_contents:
			return cur as Control
		cur = cur.get_parent()
	return null


static func _panel_ancestor(c: Control) -> Control:
	var cur: Node = c.get_parent()
	while cur is Control:
		if cur is PanelContainer or cur is Panel:
			return cur as Control
		cur = cur.get_parent()
	return null


static func _layer(c: Control) -> int:
	var cur: Node = c.get_parent()
	while cur != null:
		if cur is CanvasLayer:
			return (cur as CanvasLayer).layer
		cur = cur.get_parent()
	return 0


static func _text_width(c: Control, text: String) -> float:
	var font: Font = c.get_theme_font(&"font")
	var fs: int = c.get_theme_font_size(&"font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


static func _check_text(c: Control, r: Rect2, clipper: Control, out: Array[Dictionary]) -> void:
	var text: String = ""
	if c is Label:
		var label: Label = c as Label
		text = label.tr(label.text) if label.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else label.text
		if text.strip_edges().is_empty():
			return
		if label.uppercase:
			text = text.to_upper()
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var need: float = 0.0
			for line: String in text.split("\n"):
				need = maxf(need, _text_width(c, line))
			var box: StyleBox = label.get_theme_stylebox(&"normal")
			var avail: float = label.size.x - (box.get_minimum_size().x if box != null else 0.0)
			if need > avail + EPS:
				out.append(_issue("cortado", c, r, "\"%s\" pede %d, tem %d" % [text.left(40), roundi(need), roundi(avail)]))
		elif label.max_lines_visible < 0 and label.get_visible_line_count() < label.get_line_count():
			out.append(_issue("cortado", c, r, "\"%s\" mostra %d de %d linhas" % [text.left(40), label.get_visible_line_count(), label.get_line_count()]))
	elif c is Button and not (c is OptionButton):
		var button: Button = c as Button
		text = button.tr(button.text) if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else button.text
		if text.strip_edges().is_empty() or button.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return
		var need_b: float = _text_width(c, text) + button.get_theme_stylebox(&"normal").get_minimum_size().x
		if button.icon != null and not button.expand_icon:
			var icon_w: int = button.icon.get_width()
			var max_w: int = button.get_theme_constant(&"icon_max_width")
			need_b += (mini(icon_w, max_w) if max_w > 0 else icon_w) + button.get_theme_constant(&"h_separation")
		if need_b > button.size.x + EPS:
			out.append(_issue("cortado", c, r, "\"%s\" pede %d, tem %d" % [text.left(40), roundi(need_b), roundi(button.size.x)]))
	elif c is RichTextLabel:
		var rich: RichTextLabel = c as RichTextLabel
		if rich.get_parsed_text().strip_edges().is_empty() or rich.scroll_active or rich.fit_content:
			pass
		elif rich.get_content_height() > rich.size.y + EPS:
			out.append(_issue("cortado", c, r, "conteúdo %d > altura %d" % [rich.get_content_height(), roundi(rich.size.y)]))
		text = rich.get_parsed_text()
	else:
		return
	if text.strip_edges().is_empty():
		return
	# Texto que passa da borda do painel que o contém (fora de rolagem, que recorta de propósito).
	var panel: Control = _panel_ancestor(c)
	if panel != null and clipper == null and not _inside(r, rect_of(panel)):
		out.append(_issue("cortado", c, r, "passa do painel %s %s" % [_short(panel), rect_of(panel)]))
