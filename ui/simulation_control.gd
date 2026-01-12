extends Control

## Simulation control bar - play/pause and speed controls
## Centered at top of screen

signal simulation_toggled(is_running: bool)
signal speed_changed(multiplier: float)

var is_simulation_running: bool = false
var is_speed_2x: bool = false
var has_started_once: bool = false  # Track if simulation has ever been started

# UI elements
var start_button: Button
var control_bar: HBoxContainer
var play_pause_button: Button
var speed_button: Button

@export var button_width: float = 200.0
@export var button_height: float = 50.0
@export var control_button_width: float = 80.0
@export var top_margin: float = 20.0

func _ready() -> void:
	_setup_ui()

func _setup_ui() -> void:
	# Set up this Control to be centered at top
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	custom_minimum_size = Vector2(button_width, button_height + top_margin)
	size = custom_minimum_size
	
	_create_start_button()
	_create_control_bar()
	
	# Ensure mouse events are captured
	mouse_filter = Control.MOUSE_FILTER_STOP

func _create_start_button() -> void:
	start_button = Button.new()
	start_button.text = "▶ Start Simulation"
	start_button.custom_minimum_size = Vector2(button_width, button_height)
	start_button.position = Vector2(-button_width / 2, top_margin)
	
	_apply_start_button_style(start_button)
	start_button.pressed.connect(_on_start_pressed)
	
	add_child(start_button)

func _create_control_bar() -> void:
	control_bar = HBoxContainer.new()
	control_bar.position = Vector2(-button_width / 2, top_margin)
	control_bar.add_theme_constant_override("separation", 5)
	control_bar.visible = false
	
	# Play/Pause button
	play_pause_button = Button.new()
	play_pause_button.text = "⏸ Pause"
	play_pause_button.custom_minimum_size = Vector2(control_button_width + 20, button_height)
	play_pause_button.pressed.connect(_on_play_pause_pressed)
	_apply_pause_style(play_pause_button)
	control_bar.add_child(play_pause_button)
	
	# Speed toggle button
	speed_button = Button.new()
	speed_button.text = "1x"
	speed_button.toggle_mode = true
	speed_button.custom_minimum_size = Vector2(control_button_width - 20, button_height)
	speed_button.toggled.connect(_on_speed_toggled)
	_apply_speed_button_style(speed_button, false)
	control_bar.add_child(speed_button)
	
	add_child(control_bar)

func _on_start_pressed() -> void:
	has_started_once = true
	is_simulation_running = true
	
	# Hide start button, show control bar
	start_button.visible = false
	control_bar.visible = true
	
	# Center the control bar
	var bar_width = control_bar.get_combined_minimum_size().x
	control_bar.position = Vector2(-bar_width / 2, top_margin)
	
	simulation_toggled.emit(true)

func _on_play_pause_pressed() -> void:
	is_simulation_running = not is_simulation_running
	
	if is_simulation_running:
		play_pause_button.text = "⏸ Pause"
		_apply_pause_style(play_pause_button)
	else:
		play_pause_button.text = "▶ Play"
		_apply_play_style(play_pause_button)
	
	simulation_toggled.emit(is_simulation_running)

func _on_speed_toggled(button_pressed: bool) -> void:
	is_speed_2x = button_pressed
	
	if is_speed_2x:
		speed_button.text = "2x"
		_apply_speed_button_style(speed_button, true)
	else:
		speed_button.text = "1x"
		_apply_speed_button_style(speed_button, false)
	
	var multiplier = 2.0 if is_speed_2x else 1.0
	speed_changed.emit(multiplier)

func _apply_start_button_style(button: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.3, 0.95)
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.3, 0.7, 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.25, 0.6, 0.35, 0.95)
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color.WHITE)

func _apply_play_style(button: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.3, 0.95)
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.3, 0.7, 0.4)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 0
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.25, 0.6, 0.35, 0.95)
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color.WHITE)

func _apply_pause_style(button: Button) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.5, 0.35, 0.2, 0.95)
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_color = Color(0.7, 0.5, 0.3)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 0
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.6, 0.4, 0.25, 0.95)
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color.WHITE)

func _apply_speed_button_style(button: Button, is_fast: bool) -> void:
	var style = StyleBoxFlat.new()
	if is_fast:
		style.bg_color = Color(0.4, 0.3, 0.6, 0.95)
		style.border_color = Color(0.5, 0.4, 0.8)
	else:
		style.bg_color = Color(0.3, 0.3, 0.35, 0.95)
		style.border_color = Color(0.4, 0.4, 0.5)
	
	style.border_width_bottom = 3
	style.border_width_top = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 8
	
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.1)
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover_pressed", style)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

func get_simulation_state() -> bool:
	return is_simulation_running

func get_speed_multiplier() -> float:
	return 2.0 if is_speed_2x else 1.0
