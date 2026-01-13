extends "res://animals/base_animal.gd"
class_name PredatorAnimal

## Predator animal that chases and catches prey

@export var catch_distance: float = 30.0  # Distance at which predator catches prey
@export var catch_duration: float = 1.5  # How long the catch animation lasts before prey is destroyed
@export var speed: float = 5.0  # Distance traveled per simulation tick

var catch_timer: Timer
var time_since_last_hop: float = 0.0  # Track time since last hop calculation

func _ready() -> void:
	# Set predator properties
	sprite_size = 48
	sprite_color = Color.CYAN
	node_type = "Predator"
	hop_distance = 50.0
	idle_hop_interval_min = 1.0
	idle_hop_interval_max = 3.0
	fast_hop_interval = randf_range(0.15, 0.3)
	hop_duration = 0.3
	detection_range = 200.0  # Predators can see further
	
	super._ready()
	
	# Setup catch timer
	catch_timer = Timer.new()
	catch_timer.one_shot = true
	catch_timer.timeout.connect(_on_catch_complete)
	add_child(catch_timer)

func _process_simulation() -> void:
	# Behavior calculations at fixed timestep
	if not simulation_running or current_state == State.INTERACTING:
		return
	
	_scan_for_prey()
	_attempt_prey_catch()
	_movement()

func _movement() -> void:
	# Calculate desired position based on behavior state
	# This runs at fixed timestep in _physics_process
	if current_state == State.INTERACTING:
		return
	
	time_since_last_hop += GlobalConstants.SIMULATION_TIMESTEP
	
	# Determine hop interval based on current state
	var hop_interval: float
	match current_state:
		State.IDLE:
			hop_interval = randf_range(idle_hop_interval_min, idle_hop_interval_max) / speed_multiplier
		State.CHASING, State.FLEEING:
			hop_interval = fast_hop_interval / speed_multiplier
		_:
			hop_interval = idle_hop_interval_max / speed_multiplier
	
	# Calculate new desired position if enough time has passed
	if time_since_last_hop >= hop_interval:
		time_since_last_hop = 0.0
		
		var target_position: Vector2
		match current_state:
			State.IDLE:
				target_position = _get_random_hop_target()
			State.CHASING:
				target_position = _get_chase_hop_target()
			State.FLEEING:
				target_position = _get_flee_hop_target()
			_:
				target_position = _get_random_hop_target()
		
		desired_position = target_position

func _scan_for_prey() -> void:
	# Look for nearby prey animals using efficient Area2D detection
	var closest_prey = find_closest_animal_of_type(PreyAnimal)
	
	if closest_prey:
		target_animal = closest_prey
		if current_state != State.CHASING:
			current_state = State.CHASING
	else:
		# No prey nearby, return to idle
		if current_state == State.CHASING:
			target_animal = null
			current_state = State.IDLE

func _attempt_prey_catch() -> void:
	if current_state != State.CHASING or target_animal == null:
		return
	
	if not is_instance_valid(target_animal):
		target_animal = null
		current_state = State.IDLE
		return
	
	var distance = global_position.distance_to(target_animal.global_position)

	if distance <= catch_distance:
		# Prey is caught
		# Lock both animals in place
		set_interacting_state()
		target_animal.set_interacting_state()
		
		# Change colors to indicate catching
		_flash_sprite(Color.RED)
		
		# Start timer to destroy prey
		catch_timer.wait_time = catch_duration / speed_multiplier
		catch_timer.start()
	

func _on_catch_complete() -> void:
	# Destroy the prey
	if target_animal and is_instance_valid(target_animal):
		target_animal.queue_free()
	
	# Reset predator state
	target_animal = null
	current_state = State.IDLE
	
	# Restore normal color
	_restore_sprite_color()
	
	# Reset hop timing to allow new hops immediately
	time_since_last_hop = 0.0

# Not currently working or used
func _flash_sprite(flash_color: Color) -> void:
	var sprite = get_node_or_null("Sprite")
	if sprite and sprite is Sprite2D:
		# Create a new flashing texture
		var image = Image.create(sprite_size, sprite_size, false, Image.FORMAT_RGBA8)
		image.fill(flash_color)
		
		var center = Vector2(sprite_size / 2.0, sprite_size / 2.0)
		var outer_radius = sprite_size / 2.0 - 2
		var inner_radius = sprite_size / 2.0 - 4
		
		for x in range(sprite_size):
			for y in range(sprite_size):
				var pos = Vector2(x, y)
				var dist = pos.distance_to(center)
				if dist > outer_radius:
					image.set_pixel(x, y, Color.TRANSPARENT)
				elif dist > inner_radius:
					image.set_pixel(x, y, flash_color.darkened(0.3))
		
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture

func _restore_sprite_color() -> void:
	_flash_sprite(sprite_color)
