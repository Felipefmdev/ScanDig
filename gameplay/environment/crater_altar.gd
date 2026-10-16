class_name CraterAltar
extends BossAltar

## Altar da Cratera (#44):
## Monólitos de obsidiana cósmica e cristais pulsantes que guardam o chefe final:
## O Dorminhoco (TheSleeper).
##
## Carrega a cena condicionalmente (res://gameplay/enemies/boss/the_sleeper.tscn).
## Quando o chefe &'the_sleeper' é derrotado, apresenta o painel/overlay de créditos finais
## e celebração do Modo Museu completo!

const SLEEPER_SCENE_PATH: String = "res://gameplay/enemies/boss/the_sleeper.tscn"
const DEFAULT_LABEL: String = "O Dorminhoco aguarda no abismo cósmico... [cavar]"

const OBSIDIAN_DARK: Color = Color(0.12, 0.10, 0.15)
const VIOLET_RUNE: Color = Color(0.68, 0.25, 0.90)
const CYAN_CRYSTAL: Color = Color(0.25, 0.95, 0.90)
const METEOR_RUST: Color = Color(0.52, 0.30, 0.18)

var _victory_overlay: CanvasLayer = null
var _monitored_boss: Node3D = null
var _credits_shown: bool = false


func _ready() -> void:
	if boss_scene == null:
		if ResourceLoader.exists(SLEEPER_SCENE_PATH):
			boss_scene = load(SLEEPER_SCENE_PATH) as PackedScene
	if label_text == "Algo grande dorme aqui... [cavar]":
		label_text = DEFAULT_LABEL
	super._ready()
	boss_spawned.connect(_on_boss_spawned)


func _process(_delta: float) -> void:
	if _credits_shown:
		return
	# Verifica se o chefe foi derrotado (via GameState ou sinal de morte do monstro)
	if GameState.instance != null and GameState.instance.defeated_bosses.has("the_sleeper"):
		show_victory_and_credits()


func _on_boss_spawned(boss: Node3D) -> void:
	_monitored_boss = boss
	if boss == null:
		return
	if boss.has_signal(&"died"):
		boss.connect(&"died", _on_sleeper_defeated)
	elif boss.has_signal(&"defeated"):
		boss.connect(&"defeated", _on_sleeper_defeated)
	boss.tree_exiting.connect(_on_sleeper_tree_exiting)


func _on_sleeper_defeated() -> void:
	show_victory_and_credits()


func _on_sleeper_tree_exiting() -> void:
	# Se o chefe saiu da árvore e não estava vivo, assume vitória
	if _monitored_boss != null and _monitored_boss.has_method("is_alive") and not _monitored_boss.call("is_alive"):
		show_victory_and_credits()


## Mostra o overlay de créditos finais e conclusão do jogo / Modo Museu
func show_victory_and_credits() -> void:
	if _credits_shown:
		return
	_credits_shown = true

	if _victory_overlay != null and is_instance_valid(_victory_overlay):
		_victory_overlay.visible = true
		return

	_victory_overlay = CanvasLayer.new()
	_victory_overlay.layer = 100
	_victory_overlay.name = "VictoryCreditsOverlay"

	var root_panel: PanelContainer = PanelContainer.new()
	root_panel.name = "RootPanel"
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.04, 0.10, 0.92)
	bg_style.border_color = Color(0.75, 0.45, 0.95)
	bg_style.set_border_width_all(3)
	bg_style.set_corner_radius_all(12)
	root_panel.add_theme_stylebox_override("panel", bg_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	root_panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "🏆 VITÓRIA! O SUBSOLO FOI PACIFICADO!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "O Dorminhoco despertou e foi vencido. Todos os 5 mapas foram explorados com sucesso!\nO Museu de Achados está em festa com as tuas descobertas arqueológicas e alienígenas!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	vbox.add_child(subtitle)

	var separator: HSeparator = HSeparator.new()
	vbox.add_child(separator)

	# Créditos da Equipa
	var credits_box: VBoxContainer = VBoxContainer.new()
	credits_box.add_theme_constant_override("separation", 6)

	var credits_title: Label = Label.new()
	credits_title.text = "— CRÉDITOS —"
	credits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_title.add_theme_font_size_override("font_size", 20)
	credits_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	credits_box.add_child(credits_title)

	var credits_text: Label = Label.new()
	credits_text.text = "Maestro / Lead_Gameplay (Antigravity #2) — Coordenação e Arquitetura Geral\nBroca (Dev_Player) — Controlo 1ª Pessoa, Ferramentas, Terrenos e Segredos\nSonda (Dev_Enemies) — Inteligência Artificial, Inimigos e Chefes\nDev B — Sistemas Core, Interface, HUD e Multiplayer Cooperativo\nFelipe — Concepção, Arte Low-Poly Toon e Direção Criativa"
	credits_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_text.add_theme_font_size_override("font_size", 16)
	credits_text.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	credits_box.add_child(credits_text)
	vbox.add_child(credits_box)

	var btn_continue: Button = Button.new()
	btn_continue.text = "Explorar no Modo Museu (Continuar a Jogar)"
	btn_continue.custom_minimum_size = Vector2(300, 48)
	btn_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_continue.pressed.connect(func(): _victory_overlay.visible = false)
	vbox.add_child(btn_continue)

	add_child(_victory_overlay)
	_victory_overlay.add_child(root_panel)


func _build_totem() -> void:
	_totem = Node3D.new()
	_totem.name = "Totem"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 4 Monólitos de obsidiana inclinados convergindo para o centro
	for k: int in range(4):
		var ang: float = TAU * float(k) / 4.0
		var p0: Vector3 = Vector3(cos(ang) * 1.3, 0.0, sin(ang) * 1.3)
		var p1: Vector3 = Vector3(cos(ang) * 0.9, 2.2, sin(ang) * 0.9)
		var p2: Vector3 = Vector3(cos(ang) * 0.5, 3.1, sin(ang) * 0.5)
		LowPolyMesh.prism(st, p0, p1, 0.22, 0.16, 5, OBSIDIAN_DARK)
		LowPolyMesh.prism(st, p1, p2, 0.16, 0.04, 5, OBSIDIAN_DARK)

		# Glifo cósmico em cada monólito
		var r_pos: Vector3 = (p0 + p1) * 0.5 + Vector3(0.0, 0.0, 0.05)
		LowPolyMesh.box(st, r_pos, Vector3(0.08, 0.45, 0.08), Basis.IDENTITY, VIOLET_RUNE)

	# Anel de cristais ciano e fragmentos de meteorito no chão
	for k: int in range(8):
		var ang: float = TAU * float(k) / 8.0 + 0.2
		var p: Vector3 = Vector3(cos(ang) * 0.85, 0.0, sin(ang) * 0.85)
		var top_p: Vector3 = p + Vector3(0.0, 0.35 + float(k % 2) * 0.25, 0.0)
		var col: Color = CYAN_CRYSTAL if k % 2 == 0 else METEOR_RUST
		LowPolyMesh.prism(st, p, top_p, 0.12, 0.02, 5, col)

	_totem.add_child(LowPolyMesh.commit(st, "Mesh", LowPolyMesh.make_material()))
	add_child(_totem)

	_label = Label3D.new()
	_label.name = "Label"
	_label.text = label_text
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0.0, 3.4, 0.0)
	_label.font_size = 40
	_label.outline_size = 10
	_label.pixel_size = 0.005
	_label.modulate = Color(0.85, 0.55, 1.0)
	add_child(_label)
