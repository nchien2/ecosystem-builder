extends Camera2D

## Camera controller with pan and zoom functionality

@export var pan_sensitivity: float = 1.0  # Pan sensitivity multiplier
@export var min_zoom: float = 0.5  # Minimum zoom level
@export var max_zoom: float = 3.0  # Maximum zoom level
@export var zoom_step: float = 0.1  # Zoom increment per scroll step

var is_panning: bool = false
var pan_start_position: Vector2 = Vector2.ZERO
var camera_start_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Set initial zoom
	zoom = Vector2(1.0, 1.0)
	# Enable smoothing for smoother camera movement
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0


func _process(_delta: float) -> void:
	# Continuously clamp camera position in case it's set from elsewhere
	global_position = _clamp_camera_position(global_position)

func _input(event: InputEvent) -> void:
	# Handle zoom with scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out()
			get_viewport().set_input_as_handled()

func _start_pan() -> void:
	is_panning = true
	pan_start_position = get_viewport().get_mouse_position()  # Screen coordinates
	camera_start_position = global_position

func _end_pan() -> void:
	is_panning = false

func _update_pan(mouse_delta: Vector2) -> void:
	if not is_panning:
		return
	
	# Pan in the opposite direction of mouse movement (screen space)
	# Convert screen delta to world delta based on current zoom
	var screen_delta = mouse_delta
	var world_delta = screen_delta / zoom.x * pan_sensitivity
	var new_position = camera_start_position - world_delta
	global_position = _clamp_camera_position(new_position)

func _zoom_in() -> void:
	var old_zoom = zoom.x
	var new_zoom = clamp(old_zoom + zoom_step, min_zoom, max_zoom)
	
	if new_zoom != old_zoom:
		# Get the world position under the mouse before zooming
		var world_pos_before = get_global_mouse_position()
		
		zoom = Vector2(new_zoom, new_zoom)
		
		# Adjust camera position so the point under the mouse stays the same
		var world_pos_after = get_global_mouse_position()
		var new_position = global_position + (world_pos_before - world_pos_after)
		global_position = _clamp_camera_position(new_position)

func _zoom_out() -> void:
	var old_zoom = zoom.x
	var new_zoom = clamp(old_zoom - zoom_step, min_zoom, max_zoom)
	
	if new_zoom != old_zoom:
		# Get the world position under the mouse before zooming
		var world_pos_before = get_global_mouse_position()
		
		zoom = Vector2(new_zoom, new_zoom)
		
		# Adjust camera position so the point under the mouse stays the same
		var world_pos_after = get_global_mouse_position()
		var new_position = global_position + (world_pos_before - world_pos_after)
		global_position = _clamp_camera_position(new_position)

func _clamp_camera_position(camera_pos: Vector2) -> Vector2:
	# Get the viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate half the visible world size (viewport size divided by zoom)
	var half_visible_world = viewport_size / zoom.x / 2.0
	
	# Calculate map boundaries (map is centered at 0,0)
	var map_half_size = GlobalConstants.MAP_SIZE / 2.0
	
	# Clamp camera position so the viewport edges don't go past map boundaries
	var min_x = -map_half_size.x + half_visible_world.x
	var max_x = map_half_size.x - half_visible_world.x
	var min_y = -map_half_size.y + half_visible_world.y
	var max_y = map_half_size.y - half_visible_world.y
	
	# If the visible area is larger than the map, center the camera
	if half_visible_world.x * 2.0 >= GlobalConstants.MAP_SIZE.x:
		min_x = 0.0
		max_x = 0.0
	if half_visible_world.y * 2.0 >= GlobalConstants.MAP_SIZE.y:
		min_y = 0.0
		max_y = 0.0
	
	return Vector2(
		clamp(camera_pos.x, min_x, max_x),
		clamp(camera_pos.y, min_y, max_y)
	)
