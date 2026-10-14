class_name Player
extends CharacterBody3D

@export var speed: float = 4.5
@export var jump_velocity: float = 4.2
@export var mouse_sensitivity: float = 0.0025
@export var dig_range: float = 1.8

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var detector: MetalDetector = $Head/Camera3D/Hand/MetalDetector
@onready var readout_label: Label3D = $Head/Camera3D/Hand/VisorLabel

# HUD Elements
@onready var feedback_label: Label = $HUD/FeedbackLabel
@onready var session_info_label: Label = $HUD/SessionInfoLabel

var _dig_cooldown: float = 0.0
var _feedback_tween: Tween = null

# Contador de Sessão (Mochila / Dinheiro)
var session_money: int = 0
var session_items_count: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ensure_default_input_mappings()
	_update_session_hud()
	if feedback_label != null:
		feedback_label.modulate.a = 0.0


func _ensure_default_input_mappings() -> void:
	_add_key_if_empty("move_forward", KEY_W)
	_add_key_if_empty("move_backward", KEY_S)
	_add_key_if_empty("move_left", KEY_A)
	_add_key_if_empty("move_right", KEY_D)
	_add_key_if_empty("jump", KEY_SPACE)
	_add_mouse_if_empty("use_tool", MOUSE_BUTTON_LEFT)
	_add_mouse_if_empty("careful_dig", MOUSE_BUTTON_RIGHT)


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

	_handle_dig_actions()


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


func _perform_dig(is_careful: bool) -> void:
	_dig_cooldown = 0.35
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
		var res: Dictionary = closest_spot.dig(is_careful)
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

	if revealed:
		session_items_count += 1
		session_money += final_val
		_update_session_hud()

		var rarity_str: String = _get_category_name(item.category if item != null else 0)
		var item_name: String = item.display_name if item != null else "Artefato Misterioso"
		var msg: String = "★ DESCOBERTA: %s [%s]!\nIntegridade: %d%% | Valor: R$ %d" % [
			item_name, rarity_str, int(integrity * 100.0), final_val
		]
		_show_temporary_message(msg, Color(1.0, 0.88, 0.25), 3.5)
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
