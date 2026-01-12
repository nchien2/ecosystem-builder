extends Button
class_name ToolbarSlot

## A single slot in the toolbar for selecting a node type

signal slot_selected(node_type: String)

@export var node_type: String = ""  # The node type this slot represents
@export var label_text: String = ""  # Text to display on the slot
@export var preview_color: Color = Color.CYAN  # Color for the preview icon
@export var inventory_count: int = 0  # Number of items available

@export var selected_color: Color = Color(0.2, 0.5, 0.8, 0.9)  # Background color when selected (soft blue)
@export var default_color: Color = Color(0.2, 0.2, 0.2, 0.8)  # Background color when not selected
@export var border_color: Color = Color(0.7, 0.7, 0.7, 1.0)  # Border color when not selected
@export var selected_border_color: Color = Color.WHITE  # Border color when selected
@export var border_width: int = 2  # Border width when not selected
@export var selected_border_width: int = 3  # Border width when selected

var is_slot_selected: bool = false
var count_label: Label = null  # Reference to the count label

func _ready() -> void:
	toggle_mode = true
	# Ensure minimum size is set (should be set by parent, but fallback to default)
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(80, 80)
	
	# Setup content (uses label_text, preview_color, custom_minimum_size)
	_setup_content()
	_update_style(false)
	
	# Connect signals
	toggled.connect(_on_toggled)
	pressed.connect(_on_pressed)

func _setup_content() -> void:
	# Create centered container for slot content
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)
	
	# Create vertical container for icon and label
	var content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 5)
	center_container.add_child(content)
	
	# Create preview icon (circular)
	var preview_size = custom_minimum_size.x * 0.5
	var preview = ColorRect.new()
	preview.custom_minimum_size = Vector2(preview_size, preview_size)
	preview.color = preview_color
	
	# Make it circular with rounded corners
	var preview_stylebox = StyleBoxFlat.new()
	preview_stylebox.bg_color = preview_color
	var radius = preview_size / 2.0
	preview_stylebox.corner_radius_top_left = radius
	preview_stylebox.corner_radius_top_right = radius
	preview_stylebox.corner_radius_bottom_left = radius
	preview_stylebox.corner_radius_bottom_right = radius
	preview.add_theme_stylebox_override("panel", preview_stylebox)
	
	# Create label
	var label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 12)
	
	content.add_child(preview)
	content.add_child(label)
	
	# Create inventory count label in bottom left corner
	count_label = Label.new()
	count_label.text = str(inventory_count)
	count_label.add_theme_color_override("font_color", Color.WHITE)
	count_label.add_theme_font_size_override("font_size", 14)
	count_label.position = Vector2(6, custom_minimum_size.y - 20)
	add_child(count_label)

func _on_pressed() -> void:
	# This slot was pressed - emit signal
	if button_pressed:
		is_slot_selected = true
		_update_style(true)
		slot_selected.emit(node_type)

func _on_toggled(toggled_state: bool) -> void:
	is_slot_selected = toggled_state
	_update_style(toggled_state)

func set_selected(selected: bool) -> void:
	button_pressed = selected
	is_slot_selected = selected
	_update_style(selected)

func get_inventory_count() -> int:
	return inventory_count

func decrement_inventory() -> bool:
	# Returns true if successfully decremented, false if already at 0
	if inventory_count > 0:
		inventory_count -= 1
		count_label.text = str(inventory_count)
		return true
	return false

func _update_style(is_selected: bool) -> void:
	var normal_stylebox = StyleBoxFlat.new()
	normal_stylebox.draw_center = true  # Enable background drawing
	
	# Add padding around slot contents
	var padding = 8
	normal_stylebox.content_margin_left = padding
	normal_stylebox.content_margin_right = padding
	normal_stylebox.content_margin_top = padding
	normal_stylebox.content_margin_bottom = padding
	
	if is_selected:
		normal_stylebox.bg_color = selected_color
		normal_stylebox.border_color = selected_border_color
		normal_stylebox.border_width_left = selected_border_width
		normal_stylebox.border_width_right = selected_border_width
		normal_stylebox.border_width_top = selected_border_width
		normal_stylebox.border_width_bottom = selected_border_width
	else:
		normal_stylebox.bg_color = default_color
		normal_stylebox.border_color = border_color
		normal_stylebox.border_width_left = border_width
		normal_stylebox.border_width_right = border_width
		normal_stylebox.border_width_top = border_width
		normal_stylebox.border_width_bottom = border_width
	
	# Apply to button states
	add_theme_stylebox_override("normal", normal_stylebox)
	
	# Hover state - slightly brighter border and background when not selected
	var hover_stylebox = normal_stylebox.duplicate()
	if not is_selected:
		hover_stylebox.border_color = border_color.lightened(0.2)
		hover_stylebox.bg_color = default_color.lightened(0.1)
	else:
		hover_stylebox.bg_color = selected_color.lightened(0.1)
	add_theme_stylebox_override("hover", hover_stylebox)
	
	# Pressed state - same as normal
	add_theme_stylebox_override("pressed", normal_stylebox)
