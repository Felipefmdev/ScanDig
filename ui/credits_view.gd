class_name CreditsView
extends VBoxContainer

## Créditos (#81, #149): a equipe e a seção "Sons (CC0)" por autor (AudioCredits, gerada do
## assets/audio/CREDITS.md), numa área com rolagem e o botão Voltar. Usada pela VictoryScreen e
## pela tela de título. Teclado/comando: o foco começa na área; ↑/↓ rolam e, no fim (ou no
## topo), passam ao Voltar; PgUp/PgDn uma página, Home/End até a ponta. Esc/B é de quem abriu.
## Nomes de autor e de obra não se traduzem; os rótulos sim (refeitos ao trocar de idioma).

signal back_pressed

const TITLE_TEXT: String = "— CRÉDITOS —"
## Fonte única dos créditos da equipe (veio do overlay do gameplay/environment/crater_altar.gd).
const TEAM_TEXT: String = "Maestro / Lead_Gameplay (Antigravity #2) — Coordenação e Arquitetura Geral\nBroca (Dev_Player) — Controle em 1ª Pessoa, Ferramentas, Terrenos e Segredos\nSonda (Dev_Enemies) — Inteligência Artificial, Inimigos e Chefes\nDev B — Sistemas Core, Interface, HUD e Multiplayer Cooperativo\nFelipe — Concepção, Arte Low-Poly Toon e Direção Criativa"
const SOUNDS_TITLE: String = "Sons (CC0)"
const SOUNDS_INTRO: String = "Todos os sons do jogo são CC0 1.0 (domínio público)."
const GENERATED_TEXT: String = "Sons gerados pelo projeto"
const RECORDING_TEXT: String = "gravação: %s"
const FILES_TEXT: String = "Arquivos: %d"
## Altura da área com rolagem: cabe no cartão da vitória em 960x540 (o FitCenterContainer encolhe
## o resto com ui_scale 1.3).
const SCROLL_SIZE: Vector2 = Vector2(660, 300)
const SCROLL_STEP: int = 48

var scroll: ScrollContainer = null
var team_label: Label = null
var back_button: Button = null
## Nome do autor -> Label do cabeçalho (nome, "CC0 1.0").
var author_labels: Dictionary = {}

var _authors: Array[Dictionary] = []
## [Label, autor] dos detalhes (obras, gravação, arquivos), refeitos ao trocar de idioma.
var _detail_labels: Array[Array] = []


func _init() -> void:
	add_theme_constant_override("separation", 14)
	_authors = AudioCredits.load_authors()
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_texts()


func _ready() -> void:
	_refresh_texts()


## Foco na área de rolagem, do topo.
func focus_start() -> void:
	scroll.scroll_vertical = 0
	if scroll.is_visible_in_tree():
		scroll.grab_focus()


## Rola `delta` pixels; false se já estava na ponta (nada mudou).
func scroll_by(delta: int) -> bool:
	var before: int = scroll.scroll_vertical
	scroll.scroll_vertical = before + delta
	return scroll.scroll_vertical != before


## Texto visível da seção de sons (para os testes e capturas).
func sounds_text() -> String:
	var out: PackedStringArray = []
	for label: Label in author_labels.values():
		out.append(label.text)
	for pair: Array in _detail_labels:
		out.append((pair[0] as Label).text)
	return "\n".join(out)


func _on_scroll_input(event: InputEvent) -> void:
	var page: int = int(scroll.size.y * 0.8)
	var delta: int = 0
	if event.is_action_pressed(&"ui_down", true):
		delta = SCROLL_STEP
	elif event.is_action_pressed(&"ui_up", true):
		delta = -SCROLL_STEP
	elif event.is_action_pressed(&"ui_page_down", true):
		delta = page
	elif event.is_action_pressed(&"ui_page_up", true):
		delta = -page
	elif event.is_action_pressed(&"ui_end", true):
		delta = 1 << 20
	elif event.is_action_pressed(&"ui_home", true):
		delta = -(1 << 20)
	# Na ponta, ↑/↓ seguem para o Voltar (a área não prende o foco).
	if delta != 0 and scroll_by(delta):
		scroll.accept_event()


func _refresh_texts() -> void:
	for author: Dictionary in _authors:
		var header: Label = author_labels.get(author["name"]) as Label
		if header == null:
			continue
		var who: String = str(author["name"])
		if author.get("generated", false):
			who = tr(GENERATED_TEXT)
			var contributors: Array = author.get("contributors", [])
			if not contributors.is_empty():
				who += " (%s)" % ", ".join(PackedStringArray(contributors))
		header.text = "%s — %s" % [who, AudioCredits.LICENSE]
	for pair: Array in _detail_labels:
		(pair[0] as Label).text = _detail_text(pair[1])


func _detail_text(author: Dictionary) -> String:
	var lines: PackedStringArray = []
	var works: Array = author.get("works", [])
	if author.get("generated", false):
		var tools: PackedStringArray = []
		for work: Dictionary in works:
			tools.append(str(work["title"]))
		lines.append(", ".join(tools))
	else:
		for work: Dictionary in works:
			lines.append("%s — %s" % [work["title"], AudioCredits.short_url(str(work["url"]))])
	for who: Variant in author.get("recordings", []):
		lines.append(tr(RECORDING_TEXT) % str(who))
	lines.append(tr(FILES_TEXT) % int(author.get("files", 0)))
	return "\n".join(lines)


# --- Montagem ------------------------------------------------------------------

func _build() -> void:
	var title: Label = Label.new()
	title.text = TITLE_TEXT
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", UiPalette.WOOD_DARK)
	add_child(title)
	add_child(HSeparator.new())

	scroll = FocusScroll.new()
	scroll.name = "CreditsScroll"
	scroll.custom_minimum_size = SCROLL_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(_on_scroll_input)
	add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	team_label = _wrapped_label(UiPalette.INK)
	team_label.text = TEAM_TEXT
	team_label.add_theme_constant_override(&"line_spacing", 6)
	body.add_child(team_label)
	body.add_child(HSeparator.new())
	var sounds_title: Label = Label.new()
	sounds_title.name = "SoundsTitle"
	sounds_title.text = SOUNDS_TITLE
	sounds_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sounds_title.add_theme_font_size_override(&"font_size", 24)
	sounds_title.add_theme_color_override(&"font_color", UiPalette.WOOD_DARK)
	body.add_child(sounds_title)
	var intro: Label = _wrapped_label(UiPalette.WOOD)
	intro.text = SOUNDS_INTRO
	body.add_child(intro)
	var license_url: Label = _wrapped_label(UiPalette.WOOD)
	license_url.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	license_url.text = AudioCredits.short_url(AudioCredits.LICENSE_URL)
	body.add_child(license_url)
	for author: Dictionary in _authors:
		var header: Label = _wrapped_label(UiPalette.WOOD_DARK)
		header.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		header.add_theme_font_size_override(&"font_size", 22)
		body.add_child(header)
		author_labels[author["name"]] = header
		var detail: Label = _wrapped_label(UiPalette.INK)
		detail.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		body.add_child(detail)
		_detail_labels.append([detail, author])
	_refresh_texts()

	add_child(HSeparator.new())
	back_button = Button.new()
	back_button.text = "Voltar"
	back_button.theme_type_variation = &"PrimaryButton"
	back_button.custom_minimum_size = Vector2(320, 48)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.pressed.connect(back_pressed.emit)
	add_child(back_button)
	# Anel área <-> Voltar em todas as direções: nada prende o foco.
	var to_back: NodePath = scroll.get_path_to(back_button)
	var to_scroll: NodePath = back_button.get_path_to(scroll)
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		scroll.set_focus_neighbor(side, to_back)
		back_button.set_focus_neighbor(side, to_scroll)
	scroll.focus_next = to_back
	scroll.focus_previous = to_back
	back_button.focus_next = to_scroll
	back_button.focus_previous = to_scroll


func _wrapped_label(color: Color) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override(&"font_color", color)
	return label


## Área com rolagem que desenha a borda de foco do tema (a ScrollContainer da 4.3 não desenha),
## só com teclado/comando (#122).
class FocusScroll extends ScrollContainer:
	const THEME: Theme = preload("res://ui/theme/scandig_theme.tres")

	func _init() -> void:
		add_theme_stylebox_override(&"focus", THEME.get_stylebox(&"focus", &"Button"))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _ready() -> void:
		if InputDevice.instance != null:
			InputDevice.instance.pointer_changed.connect(_on_pointer_changed)

	func _on_pointer_changed(_on: bool) -> void:
		queue_redraw()

	func _draw() -> void:
		if has_focus() and not InputDevice.using_pointer():
			draw_style_box(get_theme_stylebox(&"focus"), Rect2(Vector2.ZERO, size))
