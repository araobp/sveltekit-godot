extends CharacterBody3D


const SPEED = 5.0
const SPRINT_SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

@onready var forward_button = get_node("/root/Node3D/CanvasLayer/Control/Forward")
@onready var backward_button = get_node("/root/Node3D/CanvasLayer/Control/Backward")
@onready var left_button = get_node("/root/Node3D/CanvasLayer/Control/Left")
@onready var right_button = get_node("/root/Node3D/CanvasLayer/Control/Right")
@onready var camera = $Camera3D

var mouse_captured = false
const MOUSE_CAPTURE_TIMEOUT = 1.0
var mouse_captured_timer = 0.0

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	if mouse_captured_timer > 0:
		mouse_captured_timer -= delta
		if mouse_captured_timer < 0:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
			mouse_captured_timer = 0.0
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and event.is_pressed():
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
			mouse_captured_timer = 0.0
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true
			mouse_captured_timer = MOUSE_CAPTURE_TIMEOUT
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		mouse_captured_timer = MOUSE_CAPTURE_TIMEOUT

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if forward_button.is_pressed():
		input_dir.y = -1
	if backward_button.is_pressed():
		input_dir.y = 1
	if left_button.is_pressed():
		input_dir.x = -1
	if right_button.is_pressed():
		input_dir.x = 1
		
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_speed = SPEED
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
