class_name UiIcons
extends RefCounted

## Ícones planos da UI (#119), desenhados aqui em SVG (grade 24 x 24, contorno INK) e
## rasterizados com Image.load_svg_from_string: sem asset externo e sem passar pelo import (vale
## no headless e no .exe). get_icon(nome, lado) devolve a ImageTexture em cache; nome
## desconhecido devolve null.

const INK: String = "#2B2118"
const STROKE: String = "stroke=\"#2B2118\" stroke-width=\"1.6\" stroke-linejoin=\"round\" stroke-linecap=\"round\""

## Corpo de cada ícone (dentro de <svg viewBox="0 0 24 24">). {s} vira o atributo do contorno.
const SHAPES: Dictionary = {
	"backpack": "<path d=\"M8 6 Q8 3 12 3 Q16 3 16 6\" fill=\"none\" {s}/>"
		+ "<rect x=\"4.5\" y=\"6\" width=\"15\" height=\"15\" rx=\"4\" fill=\"#C07A3A\" {s}/>"
		+ "<path d=\"M4.5 11 Q12 14 19.5 11\" fill=\"none\" {s}/>"
		+ "<rect x=\"8\" y=\"14\" width=\"8\" height=\"5\" rx=\"1.5\" fill=\"#9A5A28\" {s}/>",
	"coin": "<circle cx=\"12\" cy=\"12\" r=\"9\" fill=\"#E0A82E\" {s}/>"
		+ "<circle cx=\"12\" cy=\"12\" r=\"5.6\" fill=\"#F2C65A\" stroke=\"#A8761C\" stroke-width=\"1.2\"/>"
		+ "<path d=\"M12 8.5 V15.5 M10 10.2 H13.4 M10.6 13.8 H14\" fill=\"none\" stroke=\"#8A5A12\" stroke-width=\"1.4\" stroke-linecap=\"round\"/>",
	"skull": "<path d=\"M12 3 C6.5 3 4 6.8 4 10.5 C4 13 5.3 14.6 7 15.4 V19 Q7 20.5 8.5 20.5 H15.5 Q17 20.5 17 19 V15.4 C18.7 14.6 20 13 20 10.5 C20 6.8 17.5 3 12 3 Z\" fill=\"#F3EAD3\" {s}/>"
		+ "<circle cx=\"8.8\" cy=\"11\" r=\"2.1\" fill=\"#2B2118\"/><circle cx=\"15.2\" cy=\"11\" r=\"2.1\" fill=\"#2B2118\"/>"
		+ "<path d=\"M10.5 17.5 V20 M13.5 17.5 V20\" {s}/>",
	"heart": "<path d=\"M12 20.5 C6 16 3 12.8 3 9 C3 6.2 5.1 4 7.7 4 C9.5 4 11 5 12 6.6 C13 5 14.5 4 16.3 4 C18.9 4 21 6.2 21 9 C21 12.8 18 16 12 20.5 Z\" fill=\"#C8463A\" {s}/>"
		+ "<path d=\"M7 7.5 Q5.8 8.5 6 10\" fill=\"none\" stroke=\"#F3B0A0\" stroke-width=\"1.4\" stroke-linecap=\"round\"/>",
	"food": "<ellipse cx=\"10\" cy=\"10\" rx=\"6.5\" ry=\"5.5\" transform=\"rotate(-35 10 10)\" fill=\"#B8642E\" {s}/>"
		+ "<path d=\"M14 14 L18.5 18.5\" stroke=\"#2B2118\" stroke-width=\"4.4\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M14 14 L18.5 18.5\" stroke=\"#F3EAD3\" stroke-width=\"1.8\" stroke-linecap=\"round\"/>"
		+ "<circle cx=\"19.5\" cy=\"17.5\" r=\"1.9\" fill=\"#F3EAD3\" {s}/><circle cx=\"17.5\" cy=\"19.5\" r=\"1.9\" fill=\"#F3EAD3\" {s}/>",
	"wrench": "<path d=\"M15.5 3.5 A5 5 0 0 0 10.8 10.1 L3.8 17.1 A2.1 2.1 0 0 0 6.9 20.2 L13.9 13.2 A5 5 0 0 0 20.5 8.5 L17.6 10.4 L14.7 9.3 L13.6 6.4 Z\" fill=\"#AEB7BE\" {s}/>",
	"gem": "<path d=\"M7 4 H17 L21 9 L12 20.5 L3 9 Z\" fill=\"#5FB7C8\" {s}/>"
		+ "<path d=\"M3 9 H21 M9.5 4 L8 9 L12 20.5 L16 9 L14.5 4\" fill=\"none\" stroke=\"#2B2118\" stroke-width=\"1.1\" stroke-linejoin=\"round\"/>",
	"detector": "<path d=\"M16.5 3 L9 15.5\" stroke=\"#2B2118\" stroke-width=\"3.6\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M16.5 3 L9 15.5\" stroke=\"#9AA6AE\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>"
		+ "<rect x=\"14.5\" y=\"2\" width=\"5\" height=\"3.4\" rx=\"1\" transform=\"rotate(30 17 3.7)\" fill=\"#D9772B\" {s}/>"
		+ "<ellipse cx=\"8\" cy=\"18\" rx=\"6\" ry=\"3.2\" fill=\"#E0A82E\" {s}/><ellipse cx=\"8\" cy=\"18\" rx=\"2.6\" ry=\"1.3\" fill=\"#6E4A2D\"/>",
	"museum": "<path d=\"M2.5 9 L12 3 L21.5 9 Z\" fill=\"#E0A82E\" {s}/>"
		+ "<rect x=\"4\" y=\"9\" width=\"16\" height=\"2\" fill=\"#F3EAD3\" {s}/>"
		+ "<path d=\"M6.5 11 V18 M10 11 V18 M14 11 V18 M17.5 11 V18\" stroke=\"#2B2118\" stroke-width=\"2.6\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M6.5 11 V18 M10 11 V18 M14 11 V18 M17.5 11 V18\" stroke=\"#F3EAD3\" stroke-width=\"1\" stroke-linecap=\"round\"/>"
		+ "<rect x=\"3\" y=\"18\" width=\"18\" height=\"2.6\" rx=\"0.6\" fill=\"#F3EAD3\" {s}/>",
	"pinpointer": "<circle cx=\"12\" cy=\"12\" r=\"7\" fill=\"#F3EAD3\" {s}/><circle cx=\"12\" cy=\"12\" r=\"3\" fill=\"#C8463A\" {s}/>"
		+ "<path d=\"M12 2 V6 M12 18 V22 M2 12 H6 M18 12 H22\" {s}/>",
	"shovel": "<path d=\"M17.5 3.5 L10.5 10.5\" stroke=\"#2B2118\" stroke-width=\"3.6\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M17.5 3.5 L10.5 10.5\" stroke=\"#A8703C\" stroke-width=\"1.6\" stroke-linecap=\"round\"/>"
		+ "<path d=\"M16 2.5 L21.5 8\" {s}/>"
		+ "<path d=\"M10 8 L16 14 L11 19.5 Q7 22 4.5 19.5 Q2 17 4.5 13 Z\" fill=\"#AEB7BE\" {s}/>",
	"play": "<path d=\"M7 4.5 L19.5 12 L7 19.5 Z\" fill=\"#D9772B\" {s}/>",
	"new": "<path d=\"M12 2.5 L14.3 9.2 L21.5 9.4 L15.8 13.8 L17.9 20.6 L12 16.6 L6.1 20.6 L8.2 13.8 L2.5 9.4 L9.7 9.2 Z\" fill=\"#E0A82E\" {s}/>",
	"load": "<path d=\"M2.5 6 Q2.5 4.5 4 4.5 H9 L11 6.5 H20 Q21.5 6.5 21.5 8 V18 Q21.5 19.5 20 19.5 H4 Q2.5 19.5 2.5 18 Z\" fill=\"#C07A3A\" {s}/>"
		+ "<path d=\"M2.5 10 H21.5\" {s}/>",
	"multiplayer": "<circle cx=\"8\" cy=\"8\" r=\"3.4\" fill=\"#D9772B\" {s}/><path d=\"M2 20 Q2 13 8 13 Q14 13 14 20 Z\" fill=\"#D9772B\" {s}/>"
		+ "<circle cx=\"16.5\" cy=\"9\" r=\"3\" fill=\"#5FA87A\" {s}/><path d=\"M13.6 14.3 Q15 13.4 16.5 13.4 Q22 13.4 22 20 H15.5\" fill=\"#5FA87A\" {s}/>",
	"gear": "<path d=\"M10.3 2.5 H13.7 L14.2 5.2 L16.4 6.2 L18.7 4.6 L21.1 7 L19.5 9.3 L20.4 11.5 L23 12 V12.1 L20.4 12.6 L19.5 14.8 L21.1 17.1 L18.7 19.5 L16.4 17.9 L14.2 18.9 L13.7 21.5 H10.3 L9.8 18.9 L7.6 17.9 L5.3 19.5 L2.9 17.1 L4.5 14.8 L3.6 12.6 L1 12.1 V12 L3.6 11.5 L4.5 9.3 L2.9 7 L5.3 4.6 L7.6 6.2 L9.8 5.2 Z\" fill=\"#9AA6AE\" {s}/>"
		+ "<circle cx=\"12\" cy=\"12\" r=\"3.2\" fill=\"#F3EAD3\" {s}/>",
	"door": "<path d=\"M5 21 V4 Q5 3 6 3 H15 Q16 3 16 4 V21\" fill=\"#8A5A34\" {s}/>"
		+ "<path d=\"M3 21 H21\" {s}/><circle cx=\"13\" cy=\"12.5\" r=\"1.1\" fill=\"#E0A82E\"/>"
		+ "<path d=\"M18 9 L21 12 L18 15 M21 12 H15.5\" fill=\"none\" {s}/>",
	"moon": "<path d=\"M15.5 3.5 A8.8 8.8 0 1 0 20.5 16 A7 7 0 1 1 15.5 3.5 Z\" fill=\"#F2D27A\" {s}/>"
		+ "<circle cx=\"9\" cy=\"10\" r=\"1.2\" fill=\"#D9B456\"/><circle cx=\"11\" cy=\"16\" r=\"0.9\" fill=\"#D9B456\"/>",
	"lock": "<path d=\"M8 10 V7.5 Q8 3.5 12 3.5 Q16 3.5 16 7.5 V10\" fill=\"none\" {s}/>"
		+ "<rect x=\"5\" y=\"10\" width=\"14\" height=\"10.5\" rx=\"2\" fill=\"#E0A82E\" {s}/><circle cx=\"12\" cy=\"15\" r=\"1.5\" fill=\"#2B2118\"/>",
	"map": "<path d=\"M3 6 L9 4 L15 6 L21 4 V18 L15 20 L9 18 L3 20 Z\" fill=\"#E8DCC0\" {s}/>"
		+ "<path d=\"M9 4 V18 M15 6 V20\" fill=\"none\" {s}/>"
		+ "<path d=\"M11 13 L13 11 M11 11 L13 13\" fill=\"none\" stroke=\"#C8463A\" stroke-width=\"1.8\" stroke-linecap=\"round\"/>",
}

static var _cache: Dictionary = {}


static func has_icon(icon_name: String) -> bool:
	return SHAPES.has(icon_name)


## SVG completo do ícone (testes conferem que rasteriza).
static func svg(icon_name: String) -> String:
	if not SHAPES.has(icon_name):
		return ""
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"24\" height=\"24\">%s</svg>" \
		% str(SHAPES[icon_name]).replace("{s}", STROKE)


## Textura do ícone com `side` px de lado (cache por nome e tamanho); null se o nome não existe.
static func get_icon(icon_name: String, side: int = 24) -> Texture2D:
	var key: String = "%s@%d" % [icon_name, side]
	if _cache.has(key):
		return _cache[key]
	var source: String = svg(icon_name)
	if source.is_empty():
		return null
	var image: Image = Image.new()
	if image.load_svg_from_string(source, float(side) / 24.0) != OK or image.is_empty():
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
