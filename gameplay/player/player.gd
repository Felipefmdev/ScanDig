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

var _dig_cooldown: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ensure_default_input_mappings()


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

	for s in spots:
		if s is BuriedSpot and s.is_inside_tree():
			var dist: float = player_pos.distance_to(s.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_spot = s

	if closest_spot != null and min_dist <= dig_range:
		print("[Player] >> Escavando (%s) a %.2fm do alvo..." % ["Cuidadosa" if is_careful else "Pá Rápida", min_dist])
		var _res: Dictionary = closest_spot.dig(is_careful)
	else:
		print("[Player] Nenhum ponto de escavação a menos de %.1fm (alvo mais próximo a %.2fm)." % [dig_range, min_dist])
