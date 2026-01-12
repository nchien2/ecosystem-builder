extends PanelContainer
class_name AnimalInfoPanel

## Info panel for displaying animal information
## Anchors to the right of the animal and follows it

@export var offset_x: float = 10.0  # Offset from sprite edge
@export var offset_y: float = -40.0  # Vertical offset

var type_label: Label
var speed_label: Label
var sample_label: Label

func _ready() -> void:
	_setup_panel()
	_setup_content()

func _setup_panel() -> void:
	visible = false
	
	# Semi-transparent background style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

func _setup_content() -> void:
	# Content container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	# Node type label
	type_label = Label.new()
	type_label.name = "TypeLabel"
	type_label.add_theme_font_size_override("font_size", 14)
	type_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(type_label)
	
	# Speed label
	speed_label = Label.new()
	speed_label.name = "SpeedLabel"
	speed_label.add_theme_font_size_override("font_size", 14)
	speed_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(speed_label)
	
	# Sample text label
	sample_label = Label.new()
	sample_label.name = "SampleLabel"
	sample_label.add_theme_font_size_override("font_size", 14)
	sample_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	vbox.add_child(sample_label)
	
	add_child(vbox)

func update_info(node_type: String, speed: float, sample_text: String = "Sample Text") -> void:
	if not type_label or not speed_label or not sample_label:
		return
	
	type_label.text = "Type: " + node_type
	speed_label.text = "Speed: " + str(snapped(speed, 0.01))
	sample_label.text = sample_text

func set_position_from_sprite(sprite_size: float) -> void:
	position = Vector2(sprite_size / 2.0 + offset_x, offset_y)
