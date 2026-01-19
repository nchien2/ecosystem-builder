@abstract
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

# Energy system
@export var max_energy: float = 100.0
@export var energy: float = 100.0
## Energy drain rate per second for each state
var energy_drain_rates: Dictionary = {
	State.IDLE: 0.5,
	State.CHASING: 2.0,
	State.FLEEING: 2.0,
	State.INTERACTING: 0.25,
}

signal died  # Emitted when animal runs out of energy

var start_position: Vector2
var hop_timer: Timer
var tween: Tween
var current_state: State = State.IDLE
var target_animal: BaseAnimal = null  # Target to chase or flee from
var detection_area: Area2D  # For efficient spatial queries
var body_area: Area2D  # Small area for click detection and biome detection (sprite-sized)
var is_selected: bool = false  # Whether this animal is currently selected
var info_panel: AnimalInfoPanel  # UI panel shown when selected
var current_biome: BaseBiome = null  # The biome this animal is currently in

# Desired position calculated in _process_simulation -> _movement()
var desired_position: Vector2

func _ready() -> void:
	z_index = 2
	add_to_group("animals")  # Join group for simulation signals
	_create_sprite()
	detection_area = Utilities._create_circular_collision_area(
		detection_range, 
		"DetectionArea", 
		GlobalConstants.COLLISION_LAYER_ANIMAL_DETECTION, 
		GlobalConstants.COLLISION_LAYER_ANIMAL_DETECTION
	)
	add_child(detection_area)
	body_area = Utilities._create_circular_collision_area(
		sprite_size / 2.0,
		"BodyArea",
		GlobalConstants.COLLISION_LAYER_ANIMAL_BODY, 
		0
	)
	add_child(body_area)
	_create_info_panel()
	start_position = position
	_setup_hopping()
	SimManager.simulation_started.connect(_on_simulation_start)
	SimManager.simulation_stopped.connect(_on_simulation_stop)
	SimManager.timestep_processed.connect(_process_simulation)

# Note: _physics_process removed - simulation logic is now driven by space_2d
# at fixed timesteps via _process_simulation() calls
				

func _process(_delta: float) -> void:
	# Visual updates happen every frame via tween animation
	# The timer in _on_hop_timer_timeout() handles starting new hops
	pass

@abstract
func _process_simulation() -> void

@abstract
func _movement() -> void

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


func _create_info_panel() -> void:
	# Create info panel using the reusable UI component
	info_panel = AnimalInfoPanel.new()
	info_panel.name = "InfoPanel"
	info_panel.set_position_from_sprite(sprite_size)
	add_child(info_panel)  # Must add to tree first so _ready() runs
	_update_info_panel()

func _draw() -> void:
	# Draw selection highlight ring when selected
	if is_selected:
		var radius = sprite_size / 2.0 + 4
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.WHITE, 3.0)

func set_selected(selected: bool) -> void:
	is_selected = selected
	info_panel.visible = selected
	if selected:
		_update_info_panel()
	queue_redraw()

func _update_info_panel() -> void:
	var energy_text = "Energy: %d/%d" % [int(energy), int(max_energy)]
	info_panel.update_info(node_type, fast_hop_interval, energy_text)

func _setup_hopping() -> void:
	# Initialize desired position
	desired_position = position
	
	# Create timer for hop animation loop
	hop_timer = Timer.new()
	hop_timer.wait_time = 0.016  # ~60fps update rate for smooth animation
	hop_timer.timeout.connect(_on_hop_timer_timeout)
	add_child(hop_timer)
	hop_timer.start()
	
	# Create tween for hop arc animation
	tween = create_tween()
	tween.set_loops()

func _on_simulation_start():
	if tween.is_valid():
		tween.play()

func _on_simulation_stop():
	if tween.is_valid():
		tween.pause()

func _animate_movement() -> void:
	# Check if we need to animate toward desired position
	var distance_to_target = position.distance_to(desired_position)
	if distance_to_target > 0.1:  # Small threshold to avoid jitter
		# If not already animating, start a new hop animation
		if not tween or not tween.is_valid():
			_start_hop_animation()

func _start_hop_animation() -> void:
	# Calculate direction toward desired position
	var direction_to_target = (desired_position - position).normalized()
	
	# Move one hop_distance toward the target (or less if we're close)
	var distance_to_target = position.distance_to(desired_position)
	var hop_length = min(hop_distance, distance_to_target)
	var target_pos = position + direction_to_target * hop_length
	
	# Clamp to map boundaries
	target_pos = _clamp_to_map_bounds(target_pos)
	
	# Create hop arc - move up then down while moving horizontally
	var hop_direction = target_pos - position
	var mid_position = position + hop_direction * 0.5 + Vector2(0, -hop_distance * 0.3)
	
	# Kill existing tween if any
	if tween:
		tween.kill()
	
	# Create new tween for hop arc animation
	tween = create_tween()
	var actual_duration = hop_duration / SimManager.speed_multiplier
	tween.tween_method(_set_position_arc.bind(position, mid_position, target_pos), 0.0, 1.0, actual_duration)

func _on_hop_timer_timeout() -> void:
	# Timer loops continuously to animate hops until desired position is reached
	# This ensures smooth animation that adapts to changing desired positions
	if SimManager.is_running and current_state != State.INTERACTING:
		_animate_movement()

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
	desired_position = position  # Stop movement

# Energy system methods
func _deplete_energy() -> void:
	var drain_rate: float = energy_drain_rates.get(current_state, energy_drain_rates[State.IDLE])
	
	energy -= drain_rate * GlobalConstants.SIMULATION_TIMESTEP
	energy = clampf(energy, 0.0, max_energy)
	
	# Update info panel if visible
	if is_selected:
		_update_info_panel()
	
	# Check for death
	if energy <= 0:
		_die()

func _die() -> void:
	died.emit()
	queue_free()

func gain_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, max_energy)
	if is_selected:
		_update_info_panel()
