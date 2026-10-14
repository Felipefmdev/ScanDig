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

const BASE_DIG_COOLDOWN: float = 0.35
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
@onready var readout_label: Label3D = $Head/Camera3D/Hand/VisorLabel
@onready var hand: Node3D = $Head/Camera3D/Hand

# HUD Elements
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var session_info_label: Label = $HUD/SessionInfoLabel
@onready var threat_panel: Control = $HUD/ThreatPanel
@onready var threat_bar: ProgressBar = $HUD/ThreatPanel/ThreatBar
@onready var threat_message_label: Label = $HUD/ThreatMessageLabel
@onready var health_label: Label = $HUD/HealthPanel/HealthLabel
@onready var health_bar: ProgressBar = $HUD/HealthPanel/HealthBar

var health: float = 100.0

var _dig_cooldown: float = 0.0
var _attack_cooldown: float = 0.0
var _feedback_tween: Tween = null
var _threat_tween: Tween = null
var _shake_tween: Tween = null
var _swing_tween: Tween = null
var _threat_fill_style: StyleBoxFlat = null
var _hand_rest_rotation: Vector3 = Vector3.ZERO
var _spawn_transform: Transform3D = Transform3D.IDENTITY

# Contador de Sessão (Mochila / Dinheiro)
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
	if hand != null:
		_hand_rest_rotation = hand.rotation

	_spawn_transform = global_transform
	health = max_health
	health_changed.connect(_on_health_changed)
	_on_health_changed(health, max_health)

	_setup_threat_hud()


func _ensure_default_input_mappings() -> void:
	_add_key_if_empty("move_forward", KEY_W)
	_add_key_if_empty("move_backward", KEY_S)
	_add_key_if_empty("move_left", KEY_A)
	_add_key_if_empty("move_right", KEY_D)
	_add_key_if_empty("jump", KEY_SPACE)
	_add_mouse_if_empty("use_tool", MOUSE_BUTTON_LEFT)
	_add_mouse_if_empty("careful_dig", MOUSE_BUTTON_RIGHT)
	_add_key_if_empty("attack", KEY_F)


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

	_handle_dig_actions()
	_handle_attack_action()


func _process(_delta: float) -> void:
	if detector != null and readout_label != null:
		readout_label.text = detector.get_readout_text()


func _handle_dig_actions() -> void:
	if _dig_cooldown > 0.0:
		return

	var is_careful: bool = false
	var triggered: bool = false

	if Input.is_action_just_pressed("use_tool"):
		is_careful = false
		triggered = true
	elif Input.is_action_just_pressed("careful_dig"):
		is_careful = true
		triggered = true

	if triggered:
		_perform_dig(is_careful)


func get_dig_cooldown() -> float:
	var level_bonus: float = float(maxi(shovel_level, 1) - 1)
	return BASE_DIG_COOLDOWN / (1.0 + level_bonus * SHOVEL_COOLDOWN_REDUCTION_PER_LEVEL)


func get_dig_damage_multiplier() -> float:
	var level_bonus: float = float(maxi(shovel_level, 1) - 1)
	return maxf(MIN_SHOVEL_DAMAGE_MULTIPLIER, 1.0 - level_bonus * SHOVEL_DAMAGE_REDUCTION_PER_LEVEL)


func _perform_dig(is_careful: bool) -> void:
	_dig_cooldown = get_dig_cooldown()
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

	if closest_spot != null and min_dist <= dig_range:
		var res: Dictionary = closest_spot.dig(is_careful, get_dig_damage_multiplier())
		_show_dig_feedback(res, is_careful)
	else:
		_show_temporary_message("❌ Nenhum sinal para escavar por perto (aproxime-se)", Color(0.95, 0.4, 0.4), 1.2)


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
		session_items_count += 1
		session_money += final_val
		_update_session_hud()

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
	if session_info_label != null:
		session_info_label.text = "🎒 Mochila: %d itens | 💰 R$ %d" % [session_items_count, session_money]


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
	_show_temporary_message("💀 Você desmaiou... e acordou de volta no ponto de partida.", Color(1.0, 0.4, 0.4), 3.0)
	_respawn()


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
	if _attack_cooldown > 0.0:
		return
	if Input.is_action_just_pressed("attack"):
		_perform_attack()


func get_attack_damage() -> float:
	return attack_damage * (1.0 + 0.2 * float(maxi(shovel_level, 1) - 1))


func _perform_attack() -> void:
	_attack_cooldown = attack_cooldown
	_play_swing_animation()

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
		target.call("take_damage", damage)
		hits += 1

	if hits > 0:
		_shake_camera(0.02, 0.15)
		_show_temporary_message("⚔️ Golpe com a pá! (%d de dano)" % int(damage), Color(1.0, 0.75, 0.4), 0.8)


func _play_swing_animation() -> void:
	if hand == null:
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	hand.rotation = _hand_rest_rotation
	_swing_tween = create_tween()
	_swing_tween.tween_property(hand, "rotation:x", _hand_rest_rotation.x + 0.5, 0.08).set_ease(Tween.EASE_OUT)
	_swing_tween.tween_property(hand, "rotation:x", _hand_rest_rotation.x - 0.9, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_swing_tween.tween_property(hand, "rotation:x", _hand_rest_rotation.x, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
