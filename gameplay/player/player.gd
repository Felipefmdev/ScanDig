class_name Player
extends CharacterBody3D

signal health_changed(current: float, max_value: float)
signal died

@export var speed: float = 4.5
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.0025
@export var dig_range: float = 1.8
## Nível da pá: cada nível reduz o cooldown de escavação e o dano à integridade dos itens.
@export_range(1, 10) var shovel_level: int = 1

@export_group("Vida")
@export var max_health: float = 100.0

@export_group("Golpe com a Pá")
@export var attack_damage: float = 25.0
@export var attack_range: float = 2.2
@export var attack_cooldown: float = 0.6
## Cosseno do meio-ângulo do cone à frente do jogador (0.5 = 60° para cada lado).
@export_range(-1.0, 1.0, 0.05) var attack_cone_dot: float = 0.5

@export_group("Mochila e Interação")
## Alcance do raycast da câmara para apanhar itens.
@export var interact_range: float = 2.5
## Cone frontal de recurso quando o raycast não acerta (cosseno do meio-ângulo).
@export_range(-1.0, 1.0, 0.05) var pickup_cone_dot: float = 0.85
@export var drop_impulse: float = 1.4

@export_group("Ferramentas Compráveis")
@export var slingshot_damage: float = 20.0
@export var slingshot_cooldown: float = 0.8
@export var slingshot_speed: float = 22.0
@export var repellent_radius: float = 8.0
@export var repellent_flee_seconds: float = 8.0
@export var repellent_noise_reduction: float = 30.0
@export var net_trap_distance: float = 1.6
@export var medkit_heal: float = 40.0

const BASE_DIG_COOLDOWN: float = 0.35
## Layer 5 (ItemPickup).
const PICKUP_MASK: int = 1 << 4
const GROUND_MASK: int = 1
const DIRT_CLOD_COLOR: Color = Color(0.78, 0.64, 0.42)
const DIRT_CLOD_LIFETIME: float = 3.0
const TOOL_SLINGSHOT: StringName = &"estilingue"
const TOOL_REPELLENT: StringName = &"repelente"
const TOOL_NET_TRAP: StringName = &"armadilha_rede"
const TOOL_MEDKIT: StringName = &"kit_medico"
const REPELLENT_COLOR: Color = Color(0.45, 1.0, 0.35, 0.85)
const SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL: float = 0.25
const SHOVEL_DAMAGE_REDUCTION_PER_LEVEL: float = 0.15
const MIN_SHOVEL_DAMAGE_MULTIPLIER: float = 0.3
const THREAT_COLORS: Array[Color] = [
	Color(0.55, 0.75, 0.35),
	Color(0.95, 0.85, 0.25),
	Color(1.0, 0.55, 0.15),
	Color(0.95, 0.15, 0.15),
]
const THREAT_MESSAGES: Array[String] = [
	"O chão treme...",
	"O chão treme... algo se mexe lá em baixo.",
	"O chão treme... O SUBSOLO ACORDOU!",
]

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var detector: MetalDetector = $Head/Camera3D/Hand/MetalDetector
@onready var shovel_rig: Node3D = $Head/Camera3D/ShovelRig
@onready var inventory: Inventory = $Inventory
@onready var dig_animator: ShovelDigAnimator = $ShovelDigAnimator
@onready var tool_view: Node3D = $Head/Camera3D/ToolView
@onready var slingshot_model: SlingshotModel = $Head/Camera3D/ToolView/Slingshot

# HUD Elements
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var session_info_label: Label = $HUD/SessionInfoLabel
@onready var threat_panel: Control = $HUD/ThreatPanel
@onready var threat_bar: ProgressBar = $HUD/ThreatPanel/ThreatBar
@onready var threat_message_label: Label = $HUD/ThreatMessageLabel
@onready var health_label: Label = $HUD/HealthPanel/HealthLabel
@onready var health_bar: ProgressBar = $HUD/HealthPanel/HealthBar
@onready var hotbar: Hotbar = $HUD/Hotbar
@onready var interact_prompt: Label = $HUD/InteractPrompt

var health: float = 100.0

var _dig_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _feedback_tween: Tween = null
var _threat_tween: Tween = null
var _shake_tween: Tween = null
var _threat_fill_style: StyleBoxFlat = null
var _spawn_transform: Transform3D = Transform3D.IDENTITY
var _target_pickup: ItemPickup = null
var _target_offer: ShopOffer = null
var _use_cooldown: float = 0.0
var _tool_view_rest: Vector3 = Vector3.ZERO
var _dig_target: BuriedSpot = null
var _dig_is_careful: bool = false

# Contador de Sessão: total já entregue na base
var session_money: int = 0
var session_items_count: int = 0


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ensure_default_input_mappings()
	_update_session_hud()
	if feedback_label != null:
		feedback_label.modulate.a = 0.0
	if threat_message_label != null:
		threat_message_label.modulate.a = 0.0

	_spawn_transform = global_transform
	health = max_health
	health_changed.connect(_on_health_changed)
	_on_health_changed(health, max_health)

	_setup_threat_hud()

	inventory.inventory_changed.connect(_on_inventory_changed)
	inventory.selected_slot_changed.connect(_on_selected_slot_changed)
	hotbar.bind(inventory)
	_on_inventory_changed()
	if interact_prompt != null:
		interact_prompt.text = ""

	dig_animator.setup(shovel_rig, camera, self)
	dig_animator.impact.connect(_on_shovel_impact)
	dig_animator.throw_dirt.connect(_on_shovel_throw_dirt)
	dig_animator.swing_hit.connect(_on_swing_hit)

	if tool_view != null:
		_tool_view_rest = tool_view.position
	if GameState.instance != null:
		GameState.instance.money_changed.connect(_on_team_money_changed)


func _ensure_default_input_mappings() -> void:
	_add_key_if_empty("move_forward", KEY_W)
	_add_key_if_empty("move_backward", KEY_S)
	_add_key_if_empty("move_left", KEY_A)
	_add_key_if_empty("move_right", KEY_D)
	_add_key_if_empty("jump", KEY_SPACE)
	_add_mouse_if_empty("use_tool", MOUSE_BUTTON_LEFT)
	_add_mouse_if_empty("careful_dig", MOUSE_BUTTON_RIGHT)
	_add_key_if_empty("attack", KEY_F)
	_add_key_if_empty("interact", KEY_E)
	_add_key_if_empty("drop", KEY_Q)
	_add_key_if_empty("slot_1", KEY_1)
	_add_key_if_empty("slot_2", KEY_2)
	_add_key_if_empty("slot_3", KEY_3)


func _add_key_if_empty(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev: InputEventKey = InputEventKey.new()
		ev.physical_keycode = keycode
		InputMap.action_add_event(action, ev)


func _add_mouse_if_empty(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		var ev: InputEventMouseButton = InputEventMouseButton.new()
		ev.button_index = button
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event is InputEventKey and event.is_pressed() and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseButton and event.is_pressed():
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			inventory.cycle(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			inventory.cycle(1)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()

	# Aplica balanço procedural (sway) na haste do detector enquanto caminha
	if detector != null:
		var is_walking: bool = (velocity.length() > 0.2 and is_on_floor())
		detector.apply_walk_sway(is_walking, delta)

	if _dig_cooldown > 0.0:
		_dig_cooldown -= delta
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if _use_cooldown > 0.0:
		_use_cooldown -= delta

	_handle_dig_actions()
	_handle_attack_action()
	_handle_inventory_actions()
	_handle_use_tool_action()


func _process(_delta: float) -> void:
	_update_interaction_target()


## Botão direito saca a pá e cava: sozinho = pá rápida, com Shift = escavação cuidadosa.
## (A ação "careful_dig" é o botão direito no InputMap; o botão esquerdo já não cava.)
func _handle_dig_actions() -> void:
	if _dig_cooldown > 0.0 or dig_animator.is_playing():
		return
	if Input.is_action_just_pressed("careful_dig"):
		_perform_dig(Input.is_physical_key_pressed(KEY_SHIFT))


func get_dig_cooldown() -> float:
	var level_bonus: float = float(maxi(shovel_level, 1) - 1)
	return BASE_DIG_COOLDOWN / (1.0 + level_bonus * SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL)


func get_dig_damage_multiplier() -> float:
	var level_bonus: float = float(maxi(shovel_level, 1) - 1)
	return maxf(MIN_SHOVEL_DAMAGE_MULTIPLIER, 1.0 - level_bonus * SHOVEL_DAMAGE_REDUCTION_PER_LEVEL)


## Fator de velocidade da animação de cavar (pás melhores cavam mais depressa).
func get_dig_speed_factor() -> float:
	return 1.0 + float(maxi(shovel_level, 1) - 1) * SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL


func _perform_dig(is_careful: bool) -> void:
	var spots: Array[Node] = get_tree().get_nodes_in_group("buried_spots")
	var closest_spot: BuriedSpot = null
	var min_dist: float = dig_range + 0.1
	var player_pos: Vector3 = global_position

	for s: Node in spots:
		if s is BuriedSpot and s.is_inside_tree():
			var dist: float = player_pos.distance_to(s.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_spot = s

	var has_spot: bool = closest_spot != null and min_dist <= dig_range
	_dig_target = closest_spot if has_spot else null
	_dig_is_careful = is_careful

	# Ponto real do chão onde a lâmina vai cravar: no spot, ou à frente do jogador.
	var aim: Vector3
	if has_spot:
		aim = closest_spot.global_position
	else:
		var fwd: Vector3 = -global_basis.z
		fwd.y = 0.0
		aim = global_position + fwd.normalized() * 1.2
	var ground: Vector3 = _find_ground_point(aim)

	var duration: float = dig_animator.play(ground, is_careful, get_dig_speed_factor())
	_dig_cooldown = maxf(get_dig_cooldown(), duration)


func _find_ground_point(around: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		around + Vector3.UP * 1.5, around + Vector3.DOWN * 3.0, GROUND_MASK, [get_rid()]
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return Vector3(around.x, global_position.y, around.z)
	return hit["position"]


## A lâmina cravou: só agora o dig() é aplicado.
func _on_shovel_impact(_ground_point: Vector3) -> void:
	if not _dig_is_careful:
		_shake_camera(0.035, 0.2)
	var spot: BuriedSpot = _dig_target
	_dig_target = null
	if spot != null and is_instance_valid(spot) and spot.is_inside_tree() and spot.is_in_group("buried_spots"):
		var res: Dictionary = spot.dig(_dig_is_careful, get_dig_damage_multiplier())
		_show_dig_feedback(res, _dig_is_careful)
	else:
		_show_temporary_message("❌ Só areia... nenhum sinal aqui (aproxime-se de um sinal)", Color(0.95, 0.4, 0.4), 1.2)


func _on_shovel_throw_dirt(blade_position: Vector3, side: Vector3) -> void:
	var count: int = randi_range(3, 6)
	var parent: Node = get_parent() if get_parent() != null else self
	var strength: float = 1.0 if _dig_is_careful else 1.6
	for i: int in count:
		_spawn_dirt_clod(parent, blade_position + Vector3(randf_range(-0.08, 0.08), 0.0, randf_range(-0.08, 0.08)),
			(side * randf_range(1.2, 2.2) + Vector3.UP * randf_range(1.6, 2.8)) * strength
			+ Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4)))


## Torrão de terra físico: não colide com o jogador (layer 0, só vê o chão) e some em ~3s.
func _spawn_dirt_clod(parent: Node, pos: Vector3, velocity_start: Vector3) -> void:
	var clod: RigidBody3D = RigidBody3D.new()
	clod.collision_layer = 0
	clod.collision_mask = GROUND_MASK
	clod.mass = 0.08
	var size: float = randf_range(0.05, 0.1)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3.ONE * size
	shape.shape = box
	clod.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var cube: BoxMesh = BoxMesh.new()
	cube.size = box.size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = DIRT_CLOD_COLOR.darkened(randf_range(0.0, 0.25))
	mat.roughness = 1.0
	cube.material = mat
	mesh.mesh = cube
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	clod.add_child(mesh)
	parent.add_child(clod)
	clod.global_position = pos
	clod.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	clod.linear_velocity = velocity_start
	clod.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var tween: Tween = clod.create_tween()
	tween.tween_interval(DIRT_CLOD_LIFETIME - 0.5)
	tween.tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.5)
	tween.tween_callback(clod.queue_free)


func _show_dig_feedback(res: Dictionary, is_careful: bool) -> void:
	var revealed: bool = res.get("revealed", false)
	var dirt_left: int = res.get("dirt_layers", 0)
	var max_layers: int = res.get("max_layers", 3)
	var integrity: float = res.get("integrity", 1.0)
	var damaged: bool = res.get("damaged", false)
	var item: ItemData = res.get("item", null)
	var final_val: int = res.get("final_value", 0)
	var is_rare_variant: bool = res.get("is_rare_variant", false)
	var is_perfect: bool = res.get("is_perfect", false)

	if revealed:
		var rarity_str: String = _get_category_name(item.category if item != null else 0)
		var item_name: String = item.display_name if item != null else "Artefato Misterioso"
		var msg: String = ""
		var color: Color = Color(1.0, 0.88, 0.25)
		var duration: float = 3.5
		if is_rare_variant:
			msg += "✦ RARO ✦\n"
			color = Color(0.85, 0.55, 1.0)
			duration = 4.5
		msg += "★ DESCOBERTA: %s [%s]!\nIntegridade: %d%% | Valor: R$ %d" % [
			item_name, rarity_str, int(integrity * 100.0), final_val
		]
		if is_perfect:
			msg += "\n✔ ESCAVAÇÃO PERFEITA! (+25%)"
		msg += "\n[E] apanhar"
		_show_temporary_message(msg, color, duration)
	elif damaged:
		var layer_num: int = max_layers - dirt_left
		var msg: String = "💥 CRACK! Você bateu com a pá no objeto!\nIntegridade caiu para %d%% (Camada %d/%d)" % [
			int(integrity * 100.0), layer_num, max_layers
		]
		_show_temporary_message(msg, Color(1.0, 0.35, 0.35), 2.2)
	else:
		var tool_name: String = "Escavação Cuidadosa" if is_careful else "Pá Rápida"
		var layer_num: int = max_layers - dirt_left
		var msg: String = "⛏️ [%s] Escavando terra... (Camada %d/%d)" % [
			tool_name, layer_num, max_layers
		]
		_show_temporary_message(msg, Color(0.85, 0.95, 0.85), 1.6)


func _show_temporary_message(text: String, color: Color = Color.WHITE, duration: float = 2.0) -> void:
	if feedback_label == null:
		return

	feedback_label.text = text
	feedback_label.modulate = color

	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()

	_feedback_tween = create_tween()
	_feedback_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.08)
	_feedback_tween.tween_interval(duration)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.4)


func _update_session_hud() -> void:
	if session_info_label == null:
		return
	var bag: String = "🎒 Mochila: %d/%d (R$ %d)" % [inventory.get_count(), inventory.capacity, inventory.get_total_value()]
	if GameState.instance != null:
		session_info_label.text = "%s | 💰 Equipa: R$ %d" % [bag, GameState.instance.team_money]
	else:
		session_info_label.text = "%s | 💰 Entregue: R$ %d" % [bag, session_money]


func _on_team_money_changed(_new_amount: int) -> void:
	_update_session_hud()


func _get_category_name(cat: int) -> String:
	match cat:
		ItemData.Category.COMUM:
			return "Comum"
		ItemData.Category.HISTORICO:
			return "Histórico"
		ItemData.Category.RARO:
			return "Raro"
		ItemData.Category.ESTRANHO:
			return "Estranho"
	return "Comum"


# ---------------------------------------------------------------------------
# Ameaça do Subsolo (DisturbanceMeter)
# ---------------------------------------------------------------------------

func _setup_threat_hud() -> void:
	if threat_bar != null:
		var fill: StyleBox = threat_bar.get_theme_stylebox("fill")
		if fill is StyleBoxFlat:
			_threat_fill_style = (fill as StyleBoxFlat).duplicate() as StyleBoxFlat
			threat_bar.add_theme_stylebox_override("fill", _threat_fill_style)

	var meter: DisturbanceMeter = DisturbanceMeter.instance
	if meter == null:
		# Cena sem DisturbanceMeter: esconde o indicador.
		if threat_panel != null:
			threat_panel.visible = false
		return

	meter.noise_changed.connect(_on_noise_changed)
	meter.threshold_reached.connect(_on_threshold_reached)
	meter.threshold_cleared.connect(_on_threshold_cleared)
	_on_noise_changed(meter.current_noise, meter.max_noise)


func _on_noise_changed(current: float, max_noise: float) -> void:
	if threat_bar == null:
		return
	threat_bar.max_value = max_noise
	threat_bar.value = current
	_update_threat_color()


func _on_threshold_reached(level: int, _origin: Vector3) -> void:
	_update_threat_color()
	var idx: int = clampi(level - 1, 0, THREAT_MESSAGES.size() - 1)
	_show_threat_message(THREAT_MESSAGES[idx], 2.5 + float(level) * 0.5)
	_shake_camera(0.04 * float(level), 0.5 + 0.15 * float(level))


func _on_threshold_cleared(_level: int) -> void:
	_update_threat_color()


func _update_threat_color() -> void:
	if _threat_fill_style == null:
		return
	var level: int = DisturbanceMeter.instance.current_level if DisturbanceMeter.instance != null else 0
	_threat_fill_style.bg_color = THREAT_COLORS[clampi(level, 0, THREAT_COLORS.size() - 1)]


func _show_threat_message(text: String, duration: float) -> void:
	if threat_message_label == null:
		return
	threat_message_label.text = text
	if _threat_tween != null and _threat_tween.is_valid():
		_threat_tween.kill()
	_threat_tween = create_tween()
	_threat_tween.tween_property(threat_message_label, "modulate:a", 1.0, 0.15)
	_threat_tween.tween_interval(duration)
	_threat_tween.tween_property(threat_message_label, "modulate:a", 0.0, 0.8)


func _shake_camera(strength: float, duration: float) -> void:
	if camera == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: int = maxi(int(duration / 0.04), 1)
	for i: int in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * falloff
		_shake_tween.tween_property(camera, "h_offset", offset.x, 0.04)
		_shake_tween.parallel().tween_property(camera, "v_offset", offset.y, 0.04)
	_shake_tween.tween_property(camera, "h_offset", 0.0, 0.05)
	_shake_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.05)


# ---------------------------------------------------------------------------
# Vida
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	_shake_camera(0.03, 0.25)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


func _die() -> void:
	died.emit()
	dig_animator.cancel()
	var lost: int = _drop_all_items()
	var msg: String = "💀 Você desmaiou... e acordou de volta no ponto de partida."
	if lost > 0:
		msg += "\nA mochila caiu no local da morte (%d itens) — volte para apanhar!" % lost
	_show_temporary_message(msg, Color(1.0, 0.4, 0.4), 4.0)
	_respawn()


## Larga todos os itens da mochila espalhados à volta do jogador. Devolve quantos caíram.
func _drop_all_items() -> int:
	var items: Array[CarriedItem] = inventory.take_all()
	var parent: Node = get_parent()
	if parent == null:
		return 0
	var origin: Vector3 = global_position + Vector3.UP * 0.8
	for i: int in items.size():
		var angle: float = TAU * float(i) / float(items.size()) + randf_range(-0.3, 0.3)
		var dir: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		ItemPickup.spawn(parent, items[i], origin + dir * 0.3, dir * randf_range(0.8, 1.4) + Vector3.UP * 1.6)
	return items.size()


func _respawn() -> void:
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	if head != null:
		head.rotation.x = 0.0
	health = max_health
	health_changed.emit(health, max_health)


func _on_health_changed(current: float, max_value: float) -> void:
	if health_bar != null:
		health_bar.max_value = max_value
		health_bar.value = current
	if health_label != null:
		health_label.text = "❤ Vida: %d / %d" % [int(ceilf(current)), int(max_value)]


# ---------------------------------------------------------------------------
# Golpe corpo-a-corpo com a pá
# ---------------------------------------------------------------------------

func _handle_attack_action() -> void:
	if _attack_cooldown > 0.0 or dig_animator.is_playing():
		return
	if Input.is_action_just_pressed("attack"):
		_perform_attack()


func get_attack_damage() -> float:
	return attack_damage * (1.0 + 0.2 * float(maxi(shovel_level, 1) - 1))


func _perform_attack() -> void:
	_attack_cooldown = attack_cooldown
	if dig_animator.play_swing() <= 0.0:
		_on_swing_hit()


func _on_swing_hit() -> void:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin: Vector3 = global_position
	var damage: float = get_attack_damage()
	var hits: int = 0

	for n: Node in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node3D) or not n.has_method("take_damage"):
			continue
		var target: Node3D = n as Node3D
		var to_target: Vector3 = target.global_position - origin
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist > attack_range:
			continue
		if dist > 0.05 and forward.dot(to_target / dist) < attack_cone_dot:
			continue
		if target.has_method("is_alive"):
			target.call("take_damage", damage, global_position)  # EnemyBase: origem do golpe
		else:
			target.call("take_damage", damage)
		hits += 1

	if hits > 0:
		_shake_camera(0.02, 0.15)
		_show_temporary_message("⚔️ Golpe com a pá! (%d de dano)" % int(damage), Color(1.0, 0.75, 0.4), 0.8)


# ---------------------------------------------------------------------------
# Mochila, apanhar/largar e entrega
# ---------------------------------------------------------------------------

func _handle_inventory_actions() -> void:
	for i: int in inventory.capacity:
		var action: StringName = StringName("slot_%d" % (i + 1))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			inventory.select(i)
	if Input.is_action_just_pressed("interact"):
		_interact()
	if InputMap.has_action("drop") and Input.is_action_just_pressed("drop"):
		_drop_selected()


func _interact() -> void:
	if _target_offer != null and is_instance_valid(_target_offer):
		_buy_offer(_target_offer)
		return
	var sell_point: SellPoint = _get_sell_point_in_range()
	if sell_point != null and _count_deliverable() > 0:
		var items: Array[CarriedItem] = inventory.take_where(SellPoint.can_deliver)
		var total: int = sell_point.deliver(items)
		session_items_count += items.size()
		session_money += total
		_update_session_hud()
		_show_temporary_message("📦 Entregue: %d itens, R$ %d" % [items.size(), total], Color(0.5, 1.0, 0.55), 2.5)
		return

	if _target_pickup == null or not is_instance_valid(_target_pickup):
		if sell_point != null:
			_show_temporary_message("Nada para entregar (as ferramentas ficam na mochila).", Color(0.9, 0.9, 0.9), 1.4)
		return
	if inventory.is_full():
		_show_temporary_message("🎒 Mochila cheia! Entregue na base ou largue um item [Q].", Color(1.0, 0.6, 0.3), 1.8)
		return
	var c: CarriedItem = _target_pickup.take()
	_target_pickup = null
	if c == null:
		return
	inventory.add_item(c)
	var value: String = "" if c.is_tool() else " (R$ %d)" % c.final_value
	_show_temporary_message("✋ Apanhou: %s%s" % [c.get_display_name(), value],
		Color(0.85, 0.55, 1.0) if c.is_rare_variant else Color(0.95, 0.95, 0.85), 1.4)


func _drop_selected() -> void:
	var c: CarriedItem = inventory.take_selected()
	if c == null:
		_show_temporary_message("Slot vazio.", Color(0.9, 0.9, 0.9), 0.8)
		return
	var fwd: Vector3 = -camera.global_basis.z
	var pos: Vector3 = camera.global_position + fwd * 0.7 + Vector3.DOWN * 0.3
	var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z).normalized()
	ItemPickup.spawn(get_parent(), c, pos, flat * drop_impulse + Vector3.UP * 0.6)


func _get_sell_point_in_range() -> SellPoint:
	for n: Node in get_tree().get_nodes_in_group(SellPoint.GROUP):
		var sp: SellPoint = n as SellPoint
		if sp != null and sp.is_in_range(global_position):
			return sp
	return null


## Pickup em mira: raycast da câmara (layer 5) ou, em alternativa, o mais próximo num cone frontal.
func _find_target_pickup() -> ItemPickup:
	var from: Vector3 = camera.global_position
	var fwd: Vector3 = -camera.global_basis.z
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + fwd * interact_range, PICKUP_MASK, [get_rid()]
	)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty() and hit["collider"] is ItemPickup:
		return hit["collider"] as ItemPickup

	var best: ItemPickup = null
	var best_dist: float = interact_range
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var p: ItemPickup = n as ItemPickup
		if p == null or p.carried == null:
			continue
		var to_p: Vector3 = p.global_position - from
		var dist: float = to_p.length()
		if dist > best_dist or dist < 0.01:
			continue
		if fwd.dot(to_p / dist) < pickup_cone_dot:
			continue
		best = p
		best_dist = dist
	return best


func _update_interaction_target() -> void:
	var offer: ShopOffer = _find_target_offer()
	if offer != _target_offer:
		if _target_offer != null and is_instance_valid(_target_offer):
			_target_offer.set_highlighted(false)
		_target_offer = offer
		if _target_offer != null:
			_target_offer.set_highlighted(true)

	var target: ItemPickup = null if _target_offer != null else _find_target_pickup()
	if target != _target_pickup:
		if _target_pickup != null and is_instance_valid(_target_pickup):
			_target_pickup.set_highlighted(false)
		_target_pickup = target
		if _target_pickup != null:
			_target_pickup.set_highlighted(true)

	if interact_prompt == null:
		return
	var sell_point: SellPoint = _get_sell_point_in_range()
	var deliverable: int = _count_deliverable()
	if _target_offer != null:
		var full: String = "  — mochila cheia!" if inventory.is_full() else ""
		interact_prompt.text = _target_offer.get_prompt() + full
	elif sell_point != null and deliverable > 0:
		interact_prompt.text = "[E] Entregar mochila (%d itens, R$ %d)" % [deliverable, inventory.get_total_value()]
	elif _target_pickup != null and _target_pickup.carried != null:
		var aimed: CarriedItem = _target_pickup.carried
		var suffix: String = "  — mochila cheia!" if inventory.is_full() else ""
		var value: String = "" if aimed.is_tool() else " (R$ %d)" % aimed.final_value
		interact_prompt.text = "[E] Apanhar %s%s%s" % [aimed.get_display_name(), value, suffix]
	else:
		interact_prompt.text = ""


func _on_inventory_changed() -> void:
	_update_session_hud()
	_update_tool_in_hand()


func _on_selected_slot_changed(_index: int) -> void:
	_update_tool_in_hand()


func _count_deliverable() -> int:
	var n: int = 0
	for c: CarriedItem in inventory.slots:
		if SellPoint.can_deliver(c):
			n += 1
	return n


## O detector só aparece e funciona com o slot selecionado a conter a ferramenta "detector".
func _update_tool_in_hand() -> void:
	if detector == null:
		return
	var c: CarriedItem = inventory.get_selected()
	var active: bool = c != null and c.tool_id == &"detector"
	if detector.has_method("set_active"):
		detector.call("set_active", active)
	else:
		detector.visible = active
	if tool_view != null:
		tool_view.visible = c != null and c.tool_id == TOOL_SLINGSHOT


# ---------------------------------------------------------------------------
# Loja (ShopOffer) e ferramentas compráveis (botão esquerdo)
# ---------------------------------------------------------------------------

## Produto da banca em mira: o mais alinhado com a mira dentro do alcance (cone frontal).
func _find_target_offer() -> ShopOffer:
	var from: Vector3 = camera.global_position
	var fwd: Vector3 = -camera.global_basis.z
	var best: ShopOffer = null
	var best_dot: float = 0.93
	for n: Node in get_tree().get_nodes_in_group(ShopOffer.GROUP):
		var offer: ShopOffer = n as ShopOffer
		if offer == null or offer.tool_data == null:
			continue
		var to_o: Vector3 = (offer.global_position + Vector3.UP * 0.15) - from
		var dist: float = to_o.length()
		if dist > interact_range or dist < 0.01:
			continue
		var d: float = fwd.dot(to_o / dist)
		if d > best_dot:
			best = offer
			best_dot = d
	return best


func _buy_offer(offer: ShopOffer) -> void:
	if inventory.is_full():
		_show_temporary_message("🎒 Mochila cheia! Liberte um slot antes de comprar.", Color(1.0, 0.6, 0.3), 1.8)
		return
	var result: Dictionary = offer.try_buy()
	var message: String = result.get("message", "")
	if not result.get("ok", false):
		_show_temporary_message("❌ " + message, Color(1.0, 0.45, 0.4), 1.8)
		return
	var c: CarriedItem = result.get("carried", null)
	if c != null:
		inventory.add_item(c)
	_show_temporary_message("🛒 " + message, Color(0.55, 0.9, 1.0), 1.6)


## A gaivota (Dev_Detector) chama isto: há algum item escavado para roubar?
func has_loot() -> bool:
	return _count_deliverable() > 0


## Tira e devolve UM item escavado aleatório (nunca ferramentas). null se não houver.
func steal_loot() -> CarriedItem:
	var candidates: Array[int] = []
	for i: int in inventory.slots.size():
		if SellPoint.can_deliver(inventory.slots[i]):
			candidates.append(i)
	if candidates.is_empty():
		return null
	var c: CarriedItem = inventory.remove_at(candidates.pick_random())
	if c != null:
		_show_temporary_message("🐦 Uma gaivota roubou %s!" % c.get_display_name(), Color(1.0, 0.55, 0.35), 2.2)
		_shake_camera(0.02, 0.2)
	return c


func _handle_use_tool_action() -> void:
	if not Input.is_action_just_pressed("use_tool") or _use_cooldown > 0.0:
		return
	var c: CarriedItem = inventory.get_selected()
	if c == null or c.tool_data == null:
		return
	match c.tool_id:
		TOOL_SLINGSHOT:
			_fire_slingshot()
		TOOL_REPELLENT:
			_use_repellent()
			_consume(c)
		TOOL_NET_TRAP:
			if _place_net_trap():
				_consume(c)
		TOOL_MEDKIT:
			if health >= max_health:
				_show_temporary_message("A vida já está cheia.", Color(0.9, 0.9, 0.9), 1.0)
				return
			heal(medkit_heal)
			_show_temporary_message("🩹 +%d de vida" % int(medkit_heal), Color(0.5, 1.0, 0.55), 1.2)
			_consume(c)


## Gasta uma carga do item selecionado; remove-o do slot quando acaba.
func _consume(c: CarriedItem) -> void:
	_use_cooldown = 0.35
	if c.consume_charge():
		var idx: int = inventory.slots.find(c)
		if idx >= 0:
			inventory.remove_at(idx)
		_show_temporary_message("%s acabou." % c.tool_name, Color(0.9, 0.9, 0.9), 1.2)
	else:
		inventory.notify_changed()


func _fire_slingshot() -> void:
	_use_cooldown = slingshot_cooldown
	var fwd: Vector3 = -camera.global_basis.z
	var pos: Vector3 = camera.global_position + fwd * 0.6 + camera.global_basis.x * 0.04 - camera.global_basis.y * 0.05
	SlingshotProjectile.launch(get_parent(), self, pos, fwd * slingshot_speed + Vector3.UP * 1.2, slingshot_damage)
	# Recuo do estilingue na mão: elástico estica e solta.
	if slingshot_model != null and tool_view != null:
		var t: Tween = create_tween()
		t.tween_property(slingshot_model, "pull", 1.0, 0.06)
		t.parallel().tween_property(tool_view, "position", _tool_view_rest + Vector3(0, -0.02, 0.06), 0.06)
		t.tween_property(slingshot_model, "pull", 0.0, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tool_view, "position", _tool_view_rest, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _use_repellent() -> void:
	var fwd: Vector3 = -camera.global_basis.z
	_spawn_spray(camera.global_position + fwd * 0.6 - camera.global_basis.y * 0.15, fwd)
	var fled: int = 0
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e: Node3D = n as Node3D
		if e == null or e.global_position.distance_to(global_position) > repellent_radius:
			continue
		if e.has_method("is_alive") and not e.call("is_alive"):
			continue
		if e.has_method("flee_from"):
			e.call("flee_from", global_position, repellent_flee_seconds)
			fled += 1
	if DisturbanceMeter.instance != null:
		DisturbanceMeter.instance.add_noise(-repellent_noise_reduction, global_position)
	_show_temporary_message("💨 Repelente! %d criatura(s) fugiram. A ameaça baixou." % fled, Color(0.5, 1.0, 0.45), 1.6)


func _spawn_spray(pos: Vector3, dir: Vector3) -> void:
	var parent: Node = get_parent() if get_parent() != null else self
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 70
	p.lifetime = 0.9
	p.explosiveness = 0.75
	p.direction = Vector3.FORWARD
	p.spread = 22.0
	p.initial_velocity_min = 3.5
	p.initial_velocity_max = 6.5
	p.gravity = Vector3(0, -0.6, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = REPELLENT_COLOR
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	p.global_position = pos
	p.look_at(pos + dir, Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD)
	p.restart()
	get_tree().create_timer(p.lifetime + 0.6).timeout.connect(p.queue_free)


func _place_net_trap() -> bool:
	var fwd: Vector3 = -global_basis.z
	fwd.y = 0.0
	var aim: Vector3 = global_position + fwd.normalized() * net_trap_distance
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		aim + Vector3.UP * 1.5, aim + Vector3.DOWN * 3.0, GROUND_MASK, [get_rid()]
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		_show_temporary_message("Não dá para pousar a rede aqui.", Color(1.0, 0.6, 0.4), 1.2)
		return false
	NetTrap.place(get_parent(), hit["position"], rotation.y)
	_show_temporary_message("🕸️ Armadilha de rede armada.", Color(0.95, 0.85, 0.6), 1.2)
	return true
