extends "res://animals/base_animal.gd"
class_name PreyAnimal

var flee_cooldown_timer: Timer
var is_fleeing_on_cooldown: bool = false
var time_since_last_hop: float = 0.0  # Track time since last hop calculation

func _ready() -> void:
	# Set prey properties (smaller and faster)
	sprite_size = 24
	sprite_color = Color.LIGHT_CYAN
	node_type = "Prey"
	hop_distance = 50.0 
	idle_hop_interval_min = 0.5
	idle_hop_interval_max = 1.5
	fast_hop_interval = randf_range(0.2, 0.4) # Set a random speed for fleeing
	hop_duration = 0.2  # Faster hop animation
	detection_range = 180.0  # Prey are more alert, can detect predators from further
	
	# Prey energy settings (smaller, more efficient)
	max_energy = 80.0
	energy = 80.0
	energy_drain_rates = {
		State.IDLE: 0.3,          # Small body = efficient at rest
		State.CHASING: 2.5,
		State.FLEEING: 2.5,       # Fleeing is exhausting
		State.INTERACTING: 0.15,
	}
	
	super._ready()
	
	# Setup cooldown timer for fleeing state
	flee_cooldown_timer = Timer.new()
	flee_cooldown_timer.one_shot = true
	flee_cooldown_timer.wait_time = 2.0  # Check again after 2 seconds of no predators
	flee_cooldown_timer.timeout.connect(_on_flee_cooldown_timeout)
	add_child(flee_cooldown_timer)

func _process(_delta: float) -> void:
	# Don't process behaviors if simulation isn't running
	pass

func _process_simulation() -> void:
	# Behavior calculations at fixed timestep
	if not SimManager.is_running or current_state == State.INTERACTING:
		return
	
	_deplete_energy()
	_forage_for_food()
	_scan_for_predators()
	_movement()

func _forage_for_food() -> void:
	## Prey forage for food when idle and inside a biome.
	## This consumes vegetation energy from the biome (over-grazing mechanic).
	if current_state != State.IDLE or current_biome == null:
		return
	
	var energy_received = current_biome.forage()
	if energy_received > 0:
		gain_energy(energy_received)


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
			hop_interval = randf_range(idle_hop_interval_min, idle_hop_interval_max) / SimManager.speed_multiplier
		State.CHASING, State.FLEEING:
			hop_interval = fast_hop_interval / SimManager.speed_multiplier
		_:
			hop_interval = idle_hop_interval_max / SimManager.speed_multiplier
	
	# Calculate new desired position if enough time has passed
	if time_since_last_hop >= hop_interval:
		time_since_last_hop = 0.0
		
		var target_position: Vector2
		match current_state:
			State.IDLE:
				target_position = _get_random_hop_target()
			State.FLEEING:
				target_position = _get_flee_hop_target()
			_:
				target_position = _get_random_hop_target()
		
		desired_position = target_position

func _scan_for_predators() -> void:
	# Look for nearby predator animals using efficient Area2D detection
	var closest_predator = find_closest_animal_of_type(PredatorAnimal)
	
	if closest_predator:
		target_animal = closest_predator
		if current_state != State.FLEEING:
			current_state = State.FLEEING
			# Flash to indicate panic
			_flash_sprite(Color.YELLOW)
		
		# Reset cooldown timer while predator is nearby
		flee_cooldown_timer.stop()
		is_fleeing_on_cooldown = false
	else:
		# No predators nearby
		if current_state == State.FLEEING and not is_fleeing_on_cooldown:
			# Start cooldown before returning to idle
			is_fleeing_on_cooldown = true
			flee_cooldown_timer.wait_time = 2.0 / SimManager.speed_multiplier
			flee_cooldown_timer.start()

func _on_flee_cooldown_timeout() -> void:
	# Safe now, return to idle
	if current_state == State.FLEEING:
		target_animal = null
		current_state = State.IDLE
		is_fleeing_on_cooldown = false
				
		# Restore normal color
		_restore_sprite_color()

func _flash_sprite(flash_color: Color) -> void:
	var sprite = get_node_or_null("Sprite")
	if sprite and sprite is Sprite2D:
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
