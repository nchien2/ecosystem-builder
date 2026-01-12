extends Control

## Toolbar UI for selecting node types to place

signal node_type_selected(node_type: String)  # Emitted when a slot is selected

@export var slot_size: Vector2 = Vector2(80, 80)  # Size of each slot
@export var slot_spacing: int = 5  # Spacing between slots
@export var num_slots: int = 3  # Number of slots to display (easily configurable)

var selected_slot: String = ""  # Currently selected node type
var slots: Array = []  # Array of ToolbarSlot nodes

# Slot configurations - easy to extend
var slot_configs: Array = [
	{"type": "small", "label": "Small\nFast", "color": Color.LIGHT_CYAN, "count": 10},
	{"type": "large", "label": "Large\nDefault", "color": Color.CYAN, "count": 10},
	{"type": "grassland", "label": "Grassland\nBiome", "color": Color(0.2, 0.5, 0.15, 1.0), "count": 2}
]

func _ready() -> void:
	_setup_toolbar()

func _setup_toolbar() -> void:
	# Create background panel
	var background = ColorRect.new()
	background.color = Color(0.15, 0.15, 0.15, 0.9)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Create centered container for slots
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.offset_left = slot_spacing
	center_container.offset_right = -slot_spacing
	center_container.offset_top = slot_spacing
	center_container.offset_bottom = -slot_spacing
	add_child(center_container)
	
	# Create vertical container for slots
	var slot_container = VBoxContainer.new()
	slot_container.add_theme_constant_override("separation", slot_spacing)
	slot_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(slot_container)
	
	# Create slots based on num_slots parameter
	var slots_to_create = min(num_slots, slot_configs.size())
	for i in range(slots_to_create):
		var config = slot_configs[i]
		_create_slot(slot_container, config)
	
	mouse_filter = Control.MOUSE_FILTER_STOP

func _create_slot(container: VBoxContainer, config: Dictionary) -> void:
	# Load slot script and create button with it
	var slot_script = load("res://ui/toolbar_slot.gd")
	var slot = Button.new()
	slot.set_script(slot_script)
	
	# Set all properties after script is attached (available in _ready)
	slot.custom_minimum_size = slot_size
	slot.node_type = config["type"]
	slot.label_text = config["label"]
	slot.preview_color = config["color"]
	slot.inventory_count = config["count"]
	
	# Connect slot signal
	slot.slot_selected.connect(_on_slot_selected)
	
	# Add to container (this triggers _ready() with all properties set)
	slots.append(slot)
	container.add_child(slot)

func _on_slot_selected(node_type: String) -> void:
	# Deselect all other slots
	for slot in slots:
		if slot.node_type != node_type:
			slot.set_selected(false)
	
	# Update selected slot
	selected_slot = node_type
	node_type_selected.emit(node_type)

func get_selected_node_type() -> String:
	return selected_slot

func decrement_inventory(node_type: String) -> bool:
	# Decrement inventory for the given node type, returns true if successful
	for slot in slots:
		if slot.node_type == node_type:
			return slot.decrement_inventory()
	return false

func get_inventory_count(node_type: String) -> int:
	# Get current inventory count for the given node type
	for slot in slots:
		if slot.node_type == node_type:
			return slot.get_inventory_count()
	return 0
