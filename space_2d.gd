extends Node2D

## A 2D space that allows clicking to place nodes
@export var placeholder_scene: PackedScene
var placeholder_instance: PackedScene
@onready var toolbar: Control  = $UILayer/Toolbar # Reference to the toolbar UI
@onready var simulation_control: Control = $UILayer/SimulationControl  # Reference to simulation control

var selected_node_type: String = ""  # Currently selected node type from toolbar
var is_simulation_running: bool = false  # Track simulation state
var has_simulation_started: bool = false  # True after first simulation start
var current_speed_multiplier: float = 1.0  # Track current speed multiplier
var selected_animal: BaseAnimal = null  # Currently selected animal for camera follow

# Camera panning variables (for left-click drag)
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var drag_start_camera_position: Vector2 = Vector2.ZERO
var drag_threshold: float = 5.0  # Pixels of movement before considering it a drag
var mouse_clicked: bool = false  # Track if mouse is currently clicked
@onready var camera_2d: Camera2D = $Camera2D

func _ready() -> void:
	z_index = 0
	# Create a simple placeholder scene if none is provided
	if placeholder_scene == null:
		placeholder_instance = _create_placeholder_scene()
	else:
		placeholder_instance = placeholder_scene
	
	# Connect to toolbar signals
	toolbar.node_type_selected.connect(_on_node_type_selected)
	
	# Connect to simulation control signals
	simulation_control.simulation_toggled.connect(_on_simulation_toggled)
	simulation_control.speed_changed.connect(_on_speed_changed)

	# Create a larger 2D space background
	_create_background()

func _process(_delta: float) -> void:
	# Camera follows selected animal (unless dragging)
	if selected_animal:
		if not is_instance_valid(selected_animal):
			# Animal was destroyed, clear selection
			selected_animal = null
		elif not is_dragging:
			camera_2d.global_position = selected_animal.global_position

func _input(event: InputEvent) -> void:
	# Handle left mouse button for node placement and camera panning
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _is_mouse_over_ui():
			# Start potential drag/placement
			is_dragging = false
			mouse_clicked = true
			drag_start_position = get_viewport().get_mouse_position()
			drag_start_camera_position = camera_2d.global_position
		else:
			# Left mouse released - re-enable smoothing and check if it was a drag or a click
			# Re-enable camera smoothing after drag ends
			if not camera_2d.position_smoothing_enabled:
				camera_2d.position_smoothing_enabled = true
			
			if mouse_clicked and not is_dragging:
				# It was a click, not a drag
				var world_mouse_pos = get_global_mouse_position()
				var local_mouse_pos = to_local(world_mouse_pos)
				
				if has_simulation_started:
					# After simulation started, try to select animal at click position
					var clicked_animal = _get_animal_at_position(local_mouse_pos)
					if clicked_animal:
						_select_animal(clicked_animal)
					else:
						_deselect_animal()
				else:
					# Before simulation, place nodes
					if not selected_node_type.is_empty() or placeholder_instance:
						_place_node_at(local_mouse_pos)
					else:
						print("Please select a node type from the toolbar first")
			
			# Reset drag state
			is_dragging = false
			mouse_clicked = false
	
	# Handle mouse movement for dragging (camera panning)
	elif mouse_clicked and event is InputEventMouseMotion:
		# Only process if drag was started and left button is pressed
		var current_mouse_pos = get_viewport().get_mouse_position()
		var mouse_delta = current_mouse_pos - drag_start_position
		
		# If mouse moved beyond threshold, start dragging
		if mouse_delta.length() > drag_threshold:
			if not is_dragging:
				is_dragging = true
				# Deselect animal when starting to drag (allows free camera panning)
				_deselect_animal()
				# Disable camera smoothing during manual drag for immediate response
				if camera_2d.position_smoothing_enabled:
					camera_2d.position_smoothing_enabled = false
			
			# Pan camera relative to the start position
			# Negative because we want to move camera opposite to mouse movement
			var pan_delta = -mouse_delta / camera_2d.zoom.x
			camera_2d.global_position = drag_start_camera_position + pan_delta

func _is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	var toolbar_rect = Rect2(toolbar.global_position, toolbar.size)
	
	# Also check simulation control button area
	var sim_control_rect = Rect2(
		simulation_control.global_position - Vector2(simulation_control.button_width / 2, 0),
		Vector2(simulation_control.button_width, simulation_control.button_height + simulation_control.top_margin)
	)
	
	return toolbar_rect.has_point(mouse_pos) or sim_control_rect.has_point(mouse_pos)


func _on_node_type_selected(node_type: String) -> void:
	selected_node_type = node_type
	print("Selected node type: ", node_type)

func _on_simulation_toggled(running: bool) -> void:
	is_simulation_running = running
	
	# Once simulation starts, placement is permanently disabled
	if running:
		has_simulation_started = true
	
	print("Simulation ", "started" if running else "stopped")
	
	# Notify all animals via group call
	get_tree().call_group("animals", "set_simulation_running", running)

func _on_speed_changed(multiplier: float) -> void:
	current_speed_multiplier = multiplier
	print("Speed changed to ", multiplier, "x")
	
	# Notify all animals via group call
	get_tree().call_group("animals", "set_speed_multiplier", multiplier)

func _select_animal(animal: BaseAnimal) -> void:
	# Deselect previous
	if selected_animal and is_instance_valid(selected_animal):
		selected_animal.set_selected(false)
	
	# Select new
	selected_animal = animal
	if selected_animal:
		selected_animal.set_selected(true)
		# Center camera on selected animal
		camera_2d.global_position = selected_animal.global_position

func _deselect_animal() -> void:
	if selected_animal and is_instance_valid(selected_animal):
		selected_animal.set_selected(false)
	selected_animal = null

func _get_animal_at_position(pos: Vector2) -> BaseAnimal:
	# Use physics query for O(1) lookup via spatial partitioning
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = GlobalConstants.COLLISION_LAYER_ANIMAL_BODY  # Layer 2 = animal body areas
	query.collide_with_areas = true
	
	var results = space_state.intersect_point(query, 1)
	if results.size() > 0:
		var collider = results[0].collider
		if collider and collider.get_parent() is BaseAnimal:
			return collider.get_parent()
	return null

func _place_node_at(coords: Vector2) -> void:
	# Placement disabled after simulation has started
	if has_simulation_started:
		return
	
	# Check if we have inventory for the selected node type
	if toolbar.get_inventory_count(selected_node_type) <= 0:
		print("No ", selected_node_type, " remaining in inventory")
		return
	
	var node: Node2D
	
	if placeholder_instance:
		node = placeholder_instance.instantiate()
	else:
		# Use selected node type from toolbar
		node = _create_placeholder_by_type(selected_node_type)
		if node == null:
			print("Failed to create node of type: ", selected_node_type)
			return
	
	add_child(node)
	node.position = coords
	
	# Set initial simulation state and speed for animals
	if node.has_method("set_simulation_running"):
		node.set_simulation_running(is_simulation_running)
	if node.has_method("set_speed_multiplier"):
		node.set_speed_multiplier(current_speed_multiplier)
	
	# Decrement inventory after successful placement
	toolbar.decrement_inventory(selected_node_type)
	
	print("Placed ", selected_node_type, " node at: ", coords)

func _create_placeholder_by_type(node_type: String) -> Node2D:
	# Create placeholder node based on the selected type using class_name declarations
	var node_class: Variant = null
	
	match node_type.to_lower():
		"small":
			node_class = PreyAnimal
		"large":
			node_class = PredatorAnimal
		"grassland":
			node_class = GrasslandBiome
		_:
			# Fallback to base if unknown type
			node_class = BaseAnimal
	
	if node_class:
		return node_class.new()
	
	return null

func _create_placeholder_scene() -> PackedScene:
	# Create and save a simple placeholder scene programmatically
	# For now, we'll use the simple placeholder method above
	return null

func _create_background() -> void:
	# Create a large background area for the 2D space
	var background_size = GlobalConstants.MAP_SIZE  # Large 2D space
	var background = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.15, 1.0)  # Dark blue-gray background
	background.position = -background_size / 2  # Center it
	background.size = background_size
	background.name = "Background"
	add_child(background)
	
	# Optionally add a grid pattern for better visual reference
	_create_grid(background_size)

func _create_grid(size: Vector2) -> void:
	# Create a subtle grid pattern
	var grid_spacing = 100.0
	var grid_color = Color(0.2, 0.2, 0.25, 0.5)
	
	# Draw grid lines using Line2D nodes or a tile pattern
	# For simplicity, we'll create vertical and horizontal lines
	var grid_container = Node2D.new()
	grid_container.name = "Grid"
	add_child(grid_container)
	
	# Vertical lines
	var vertical_lines = ceil(size.x / grid_spacing)
	for i in range(-vertical_lines, vertical_lines + 1):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = grid_color
		line.add_point(Vector2(i * grid_spacing, -size.y / 2))
		line.add_point(Vector2(i * grid_spacing, size.y / 2))
		grid_container.add_child(line)
	
	# Horizontal lines
	var horizontal_lines = ceil(size.y / grid_spacing)
	for i in range(-horizontal_lines, horizontal_lines + 1):
		var line = Line2D.new()
		line.width = 1.0
		line.default_color = grid_color
		line.add_point(Vector2(-size.x / 2, i * grid_spacing))
		line.add_point(Vector2(size.x / 2, i * grid_spacing))
		grid_container.add_child(line)
