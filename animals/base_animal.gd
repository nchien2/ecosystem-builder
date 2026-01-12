extends Node2D
class_name BaseAnimal

## Base class for all animals

enum State { IDLE, CHASING, FLEEING, INTERACTING }

@export var hop_distance: float = 50.0  # How far each hop travels
@export var idle_hop_interval_min: float = 1.0  # Minimum seconds between hops
@export var idle_hop_interval_max: float = 3.0  # Maximum seconds between hops
@export var fast_hop_interval: float = 0.3  # Minimum seconds between hops when fast hopping
@export var hop_duration: float = 0.3  # How long each hop animation takes
@export var sprite_size: int = 32  # Size of the sprite in pixels
@export var sprite_color: Color = Color.CYAN  # Color of the sprite
@export var detection_range: float = 150.0  # Range to detect other animals
@export var node_type: String = "Animal"  # Type name for display

var start_position: Vector2
var hop_timer: Timer
var tween: Tween
var current_state: State = State.IDLE
var target_animal: BaseAnimal = null  # Target to chase or flee from
var detection_area: Area2D  # For efficient spatial queries
var body_area: Area2D  # Small area for click detection (sprite-sized)
var simulation_running: bool = false  # Track if simulation is active
var speed_multiplier: float = 1.0  # Speed multiplier for timers (2.0 = 2x speed)
var is_selected: bool = false  # Whether this animal is currently selected
var info_panel: AnimalInfoPanel  # UI panel shown when selected

func _ready() -> void:
	z_index = 2
	add_to_group("animals")  # Join group for simulation signals
	_create_sprite()
	_create_detection_area()
	_create_body_area()
	_create_info_panel()
	start_position = position
	_setup_hopping()

func _create_sprite() -> void:
	# Create a simple visual representation
	var sprite = Sprite2D.new()
	
	# Create a colored circle texture based on size
	var image = Image.create(sprite_size, sprite_size, false, Image.FORMAT_RGBA8)
	image.fill(sprite_color)
	
	# Draw a circle outline for better visibility
	var center = Vector2(sprite_size / 2.0, sprite_size / 2.0)
	var outer_radius = sprite_size / 2.0 - 2
	var inner_radius = sprite_size / 2.0 - 4
	
	for x in range(sprite_size):
		for y in range(sprite_size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist > outer_radius:  # Outer edge - transparent
				image.set_pixel(x, y, Color.TRANSPARENT)
			elif dist > inner_radius:  # Border
				image.set_pixel(x, y, sprite_color.darkened(0.3))
	
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	
	add_child(sprite)

func _create_detection_area() -> void:
	# Create Area2D for efficient spatial detection (uses Godot's built-in broadphase)
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = GlobalConstants.COLLISION_LAYER_ANIMAL_DETECTION
	detection_area.collision_mask = GlobalConstants.COLLISION_LAYER_ANIMAL_DETECTION
	
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = detection_range
	collision_shape.shape = circle_shape
	
	detection_area.add_child(collision_shape)
	add_child(detection_area)

func _create_body_area() -> void:
	# Small Area2D for click detection (layer 2)
	body_area = Area2D.new()
	body_area.name = "BodyArea"
	body_area.collision_layer = GlobalConstants.COLLISION_LAYER_ANIMAL_BODY
	body_area.collision_mask = 0
	
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = sprite_size / 2.0
	collision_shape.shape = circle_shape
	
	body_area.add_child(collision_shape)
	add_child(body_area)

func _create_info_panel() -> void:
	# Create info panel using the reusable UI component
	info_panel = AnimalInfoPanel.new()
	info_panel.name = "InfoPanel"
	info_panel.set_position_from_sprite(sprite_size)
	add_child(info_panel)  # Must add to tree first so _ready() runs
	info_panel.update_info(node_type, fast_hop_interval)

func _draw() -> void:
	# Draw selection highlight ring when selected
	if is_selected:
		var radius = sprite_size / 2.0 + 4
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 3.0)

func set_selected(selected: bool) -> void:
	is_selected = selected
	info_panel.visible = selected
	if selected:
		info_panel.update_info(node_type, fast_hop_interval)
	queue_redraw()

func _setup_hopping() -> void:
	# Create a timer for random intervals
	hop_timer = Timer.new()
	hop_timer.wait_time = randf_range(idle_hop_interval_min, idle_hop_interval_max)
	hop_timer.one_shot = true
	hop_timer.timeout.connect(_perform_hop)
	add_child(hop_timer)
	# Don't start timer automatically - wait for simulation to begin
	
	# Create tween for animations
	tween = create_tween()
	tween.set_loops()

func set_simulation_running(running: bool) -> void:
	simulation_running = running
	
	if running:
		# Start behaviors when simulation begins
		if current_state != State.INTERACTING:
			hop_timer.start()
	else:
		# Stop behaviors when simulation stops
		hop_timer.stop()
		if tween:
			tween.kill()
		# Reset to idle state
		if current_state != State.INTERACTING:
			current_state = State.IDLE
			target_animal = null

func set_speed_multiplier(multiplier: float) -> void:
	speed_multiplier = multiplier

func _perform_hop() -> void:
	if current_state == State.INTERACTING or not simulation_running:
		return
	
	var target_position: Vector2
	
	var hop_interval = 0
	match current_state:
		State.IDLE:
			target_position = _get_random_hop_target()
			hop_interval = randf_range(idle_hop_interval_min, idle_hop_interval_max)
		State.CHASING:
			target_position = _get_chase_hop_target()
			hop_interval = fast_hop_interval
		State.FLEEING:
			target_position = _get_flee_hop_target()
			hop_interval = fast_hop_interval
		State.INTERACTING:
			return
	
	# Clamp target position to map boundaries
	target_position = _clamp_to_map_bounds(target_position)
	
	_animate_hop_to(target_position)
	
	# Schedule next hop (faster with speed multiplier)
	hop_timer.wait_time = hop_interval / speed_multiplier
	hop_timer.start()

func _clamp_to_map_bounds(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, -GlobalConstants.MAP_BOUNDARY, GlobalConstants.MAP_BOUNDARY),
		clampf(pos.y, -GlobalConstants.MAP_BOUNDARY, GlobalConstants.MAP_BOUNDARY)
	)

func _get_random_hop_target() -> Vector2:
	# Choose a random direction
	var angle = randf() * TAU  # Random angle in radians (0 to 2π)
	var hop_direction = Vector2(cos(angle), sin(angle)) * hop_distance
	return position + hop_direction

func _get_chase_hop_target() -> Vector2:
	# Move towards target animal
	if target_animal and is_instance_valid(target_animal):
		var direction = (target_animal.global_position - global_position).normalized()
		return position + direction * hop_distance
	return _get_random_hop_target()

func _get_flee_hop_target() -> Vector2:
	# Move away from target animal
	if target_animal and is_instance_valid(target_animal):
		var direction = (global_position - target_animal.global_position).normalized()
		return position + direction * hop_distance
	return _get_random_hop_target()

func _animate_hop_to(target_position: Vector2) -> void:
	# Create hop arc - move up then down while moving horizontally
	var hop_direction = target_position - position
	var mid_position = position + hop_direction * 0.5 + Vector2(0, -hop_distance * 0.3)
	
	# Animate the hop
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
	
	# Move position in an arc
	var actual_duration = hop_duration / speed_multiplier
	tween.tween_method(_set_position_arc.bind(position, mid_position, target_position), 0.0, 1.0, actual_duration)

func _set_position_arc(progress: float, start_pos: Vector2, mid_pos: Vector2, end_pos: Vector2) -> void:
	# Quadratic bezier curve for smooth arc motion
	var pos1 = start_pos.lerp(mid_pos, progress)
	var pos2 = mid_pos.lerp(end_pos, progress)
	position = pos1.lerp(pos2, progress)

func find_closest_animal_of_type(animal_type: Variant) -> BaseAnimal:
	# Uses Godot's Area2D broadphase for O(1) spatial lookup instead of O(n) iteration
	var overlapping_areas = detection_area.get_overlapping_areas()
	var closest: BaseAnimal = null
	var closest_distance: float = INF
	
	for area in overlapping_areas:
		var animal = area.get_parent()
		if animal is BaseAnimal and animal != self and is_instance_of(animal, animal_type):
			if animal.current_state != State.INTERACTING:
				var distance = global_position.distance_to(animal.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest = animal
	
	return closest

func set_interacting_state() -> void:
	current_state = State.INTERACTING
	if tween:
		tween.kill()
	hop_timer.stop()
