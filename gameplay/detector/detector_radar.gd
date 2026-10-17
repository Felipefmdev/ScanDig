class_name DetectorRadar
extends Control

## Ecrã circular do radar. Normalmente desenhado num SubViewport e mostrado no ecrã do aparelho;
## opcionalmente no canto do ecrã (debug). Só desenha: o estado (varrimento, blips, nível)
## vem do MetalDetector. Frente da câmara = cima, jogador no centro.

@export var detector_path: NodePath = NodePath("../..")
## Escala de todo o desenho (coordenadas virtuais = size / ui_scale).
@export var ui_scale: float = 1.0
## Pinta o fundo inteiro (ecrã do aparelho); desligado no modo HUD transparente.
@export var fill_background: bool = false

const BG_COLOR: Color = Color(0.02, 0.08, 0.05, 0.78)
const GRID_COLOR: Color = Color(0.25, 1.0, 0.45, 0.22)
const RIM_COLOR: Color = Color(0.25, 1.0, 0.45, 0.65)
const SWEEP_COLOR: Color = Color(0.35, 1.0, 0.5, 1.0)
const TEXT_COLOR: Color = Color(0.45, 1.0, 0.55, 1.0)
const ENEMY_COLOR: Color = Color(1.0, 0.18, 0.15)
const LEVEL1_COLOR: Color = Color(1.0, 1.0, 1.0)

const SWEEP_TRAIL_STEPS: int = 18
const SWEEP_TRAIL_ANGLE: float = 0.7
const BLIP_RADIUS: float = 5.0
const ENEMY_BLIP_RADIUS: float = 6.0
const SCREEN_BG_COLOR: Color = Color(0.015, 0.07, 0.04, 1.0)
const RARE_COLOR: Color = Color(1.0, 0.85, 0.3)
const PIN_COLOR: Color = Color(0.4, 0.95, 1.0)
## Linhas do rodapé: 4 até ao Nv.3, 5 com a faixa de valor (Nv.4+).
const FOOTER_LINES: int = 4
const FOOTER_LINE_HEIGHT: float = 17.0
const FOOTER_FONT_SIZE: int = 14
## Profundidade (cm) a partir da qual o blip do Nv3 fica no tamanho/brilho mínimo.
const DEEP_CM: float = 60.0
## Opacidade dos blips falsos da chuva (#99), relativa a um blip real.
const NOISE_BLIP_ALPHA: float = 0.35

var detector: MetalDetector = null
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if detector == null and has_node(detector_path):
		detector = get_node(detector_path) as MetalDetector


func _process(delta: float) -> void:
	_time += delta
	visible = detector != null and detector.is_visible_in_tree()
	if visible:
		queue_redraw()


static func get_material_color(material: ItemData.MaterialType) -> Color:
	match material:
		ItemData.MaterialType.FERRO:
			return Color(0.55, 0.55, 0.58)
		ItemData.MaterialType.ALUMINIO:
			return Color(0.55, 0.85, 1.0)
		ItemData.MaterialType.PRATA:
			return Color(0.88, 0.94, 1.0)
		ItemData.MaterialType.OURO:
			return Color(1.0, 0.8, 0.15)
		ItemData.MaterialType.DESCONHECIDO:
			return Color(0.72, 0.3, 1.0)
	return LEVEL1_COLOR


func _draw() -> void:
	if detector == null:
		return

	var k: float = maxf(ui_scale, 0.01)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	var vsize: Vector2 = size / k
	if fill_background:
		draw_rect(Rect2(Vector2.ZERO, vsize), SCREEN_BG_COLOR)

	var lines: PackedStringArray = detector.get_footer_lines()
	var footer_h: float = FOOTER_LINE_HEIGHT * float(maxi(lines.size(), FOOTER_LINES)) + 4.0
	var radius: float = minf(vsize.x, vsize.y - footer_h) * 0.5 - 3.0
	if radius <= 4.0:
		return
	var center: Vector2 = Vector2(vsize.x * 0.5, radius + 3.0)
	var level: int = detector.get_detector_level()

	_draw_background(center, radius)
	_draw_sweep(center, radius)

	var view_dist: float = detector.get_radar_view_distance()
	var scale_px: float = radius / maxf(view_dist, 0.1)
	var pinpointing: bool = detector.is_pinpointing()
	for blip: MetalDetector.RadarBlip in detector.get_blips():
		var radar_pos: Vector2 = detector.world_to_radar(blip.world_pos)
		if radar_pos.length() > view_dist * 1.05:
			# Inimigos fora da escala (Nv.6 a 1.5× o alcance, ou zoom do pinpointer) ficam na borda.
			if not blip.is_enemy:
				continue
			radar_pos = radar_pos.normalized() * view_dist
		if pinpointing and not blip.is_enemy and blip.world_pos.is_equal_approx(detector.get_current_target().global_position):
			continue  # o alvo do pinpointer é desenhado ao vivo por _draw_pinpoint
		var p: Vector2 = center + Vector2(radar_pos.x, -radar_pos.y) * scale_px
		var alpha: float = detector.get_blip_alpha(blip)
		if blip.is_enemy:
			_draw_enemy_blip(p, alpha)
		else:
			_draw_item_blip(p, alpha, blip, level)

	# Jogador no centro (seta para a frente)
	var tri: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -6.0), center + Vector2(4.5, 4.5), center + Vector2(-4.5, 4.5)
	])
	draw_colored_polygon(tri, TEXT_COLOR)

	if pinpointing:
		_draw_pinpoint(center, scale_px)
	var compass: Vector2 = detector.get_rare_compass()
	if compass != Vector2.ZERO:
		_draw_rare_compass(center, radius, compass)

	_draw_footer(center, radius, lines, vsize.x)


func _draw_background(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, BG_COLOR)
	draw_arc(center, radius * 0.333, 0.0, TAU, 48, GRID_COLOR, 1.0, true)
	draw_arc(center, radius * 0.666, 0.0, TAU, 48, GRID_COLOR, 1.0, true)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), GRID_COLOR, 1.0)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), GRID_COLOR, 1.0)
	draw_arc(center, radius, 0.0, TAU, 64, RIM_COLOR, 2.0, true)


func _draw_sweep(center: Vector2, radius: float) -> void:
	# Rasto em leque atrás da linha, a desvanecer
	for i: int in range(SWEEP_TRAIL_STEPS, 0, -1):
		var a: float = detector.sweep_angle - SWEEP_TRAIL_ANGLE * float(i) / float(SWEEP_TRAIL_STEPS)
		var trail_color: Color = SWEEP_COLOR
		trail_color.a = 0.28 * (1.0 - float(i) / float(SWEEP_TRAIL_STEPS))
		draw_line(center, center + _angle_dir(a) * radius, trail_color, 3.0, true)
	draw_line(center, center + _angle_dir(detector.sweep_angle) * radius, SWEEP_COLOR, 2.0, true)


## Ângulo do radar (0 = cima, sentido horário) para direção no ecrã.
func _angle_dir(angle: float) -> Vector2:
	return Vector2(sin(angle), -cos(angle))


func _draw_item_blip(p: Vector2, alpha: float, blip: MetalDetector.RadarBlip, level: int) -> void:
	if blip.is_noise:
		# Chuva (#99): blip falso pequeno e esmaecido, sem cor de material.
		draw_circle(p, BLIP_RADIUS * 0.6, Color(LEVEL1_COLOR, alpha * NOISE_BLIP_ALPHA))
		return
	var color: Color = LEVEL1_COLOR
	var r: float = BLIP_RADIUS
	var brightness: float = 1.0

	if level >= 2 and blip.has_item:
		color = get_material_color(blip.material)
		if blip.material == ItemData.MaterialType.DESCONHECIDO:
			# Desconhecido pisca
			brightness *= 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 14.0))

	if level >= 3 and blip.has_item:
		# Mais raso = maior e mais brilhante
		var shallow: float = 1.0 - clampf(float(blip.depth_cm) / DEEP_CM, 0.0, 1.0)
		r = lerpf(3.0, 7.0, shallow)
		brightness *= lerpf(0.5, 1.0, shallow)

	var c: Color = Color(color.r * brightness, color.g * brightness, color.b * brightness, alpha)
	var glow: Color = c
	glow.a = alpha * 0.25
	draw_circle(p, r * 1.8, glow)
	draw_circle(p, r, c)

	if blip.is_rare:
		# Anel cintilante para variantes raras
		var pulse: float = 0.5 + 0.5 * sin(_time * 9.0)
		var ring: Color = Color(1.0, 0.95, 0.6, alpha * (0.45 + 0.55 * pulse))
		draw_arc(p, r + 3.0 + pulse * 3.0, 0.0, TAU, 20, ring, 1.5, true)
		var spark: float = _time * 4.0
		for k: int in range(4):
			var d: Vector2 = Vector2.from_angle(spark + float(k) * TAU * 0.25) * (r + 6.0 + pulse * 2.0)
			draw_circle(p + d, 1.3, ring)


func _draw_enemy_blip(p: Vector2, alpha: float) -> void:
	var pulse: float = 0.75 + 0.25 * sin(_time * 10.0)
	var c: Color = Color(ENEMY_COLOR.r, ENEMY_COLOR.g, ENEMY_COLOR.b, alpha)
	var glow: Color = c
	glow.a = alpha * 0.3
	draw_circle(p, ENEMY_BLIP_RADIUS * 1.9 * pulse, glow)
	var s: float = ENEMY_BLIP_RADIUS
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0.0, -s), p + Vector2(s, 0.0), p + Vector2(0.0, s), p + Vector2(-s, 0.0)
	]), c)


## Pinpointer: anel do alcance da pá (dourado quando o alvo está dentro) e o alvo ao vivo
## com mira, para o jogador acertar o ponto exato.
func _draw_pinpoint(center: Vector2, scale_px: float) -> void:
	var target: BuriedSpot = detector.get_current_target()
	if target == null:
		return
	var in_reach: bool = detector.get_target_distance() <= MetalDetector.PINPOINT_DIG_DISTANCE
	var ring: Color = RARE_COLOR if in_reach else PIN_COLOR
	draw_arc(center, MetalDetector.PINPOINT_DIG_DISTANCE * scale_px, 0.0, TAU, 40, Color(ring, 0.8), 1.5, true)
	var radar_pos: Vector2 = detector.world_to_radar(target.global_position)
	var p: Vector2 = center + Vector2(radar_pos.x, -radar_pos.y) * scale_px
	var pulse: float = 0.5 + 0.5 * sin(_time * 12.0)
	var color: Color = get_material_color(target.item.material_type) if target.item != null and detector.get_detector_level() >= 2 else LEVEL1_COLOR
	draw_circle(p, 9.0 + pulse * 3.0, Color(color, 0.25))
	draw_circle(p, 5.0, color)
	var arm: float = 11.0
	draw_line(p + Vector2(-arm, 0.0), p + Vector2(-6.0, 0.0), PIN_COLOR, 1.5)
	draw_line(p + Vector2(6.0, 0.0), p + Vector2(arm, 0.0), PIN_COLOR, 1.5)
	draw_line(p + Vector2(0.0, -arm), p + Vector2(0.0, -6.0), PIN_COLOR, 1.5)
	draw_line(p + Vector2(0.0, 6.0), p + Vector2(0.0, arm), PIN_COLOR, 1.5)


## Pinpointer Nv.2: triângulo dourado na borda a apontar para a variante rara mais próxima.
func _draw_rare_compass(center: Vector2, radius: float, compass: Vector2) -> void:
	var dir: Vector2 = Vector2(compass.x, -compass.y).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = center + dir * (radius + 1.0)
	var base: Vector2 = center + dir * (radius - 9.0)
	var pulse: float = 0.7 + 0.3 * sin(_time * 6.0)
	draw_colored_polygon(PackedVector2Array([tip, base + side * 5.0, base - side * 5.0]), Color(RARE_COLOR, pulse))


## Texto por baixo do círculo (MetalDetector.get_footer_lines: nível/alcance/inimigos/raro,
## sinal ou pinpointer, material ou nome, profundidade, valor).
func _draw_footer(center: Vector2, radius: float, lines: PackedStringArray, width: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var y: float = center.y + radius + FOOTER_LINE_HEIGHT
	for line: String in lines:
		var pos: Vector2 = Vector2(0.0, y)
		if not fill_background:
			draw_string(font, pos + Vector2(1.0, 1.0), line, HORIZONTAL_ALIGNMENT_CENTER, width, FOOTER_FONT_SIZE, Color(0, 0, 0, 0.8))
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_CENTER, width, FOOTER_FONT_SIZE, TEXT_COLOR)
		y += FOOTER_LINE_HEIGHT
