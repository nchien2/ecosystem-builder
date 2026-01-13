extends Node

func _create_circular_collision_area(radius: float, area_name: String, layer: int = 1, mask: int = 1) -> Area2D:
	# Create circular 2D collision area with given radius, layer, mask, and name
	var area = Area2D.new()
	area.name = area_name
	area.set_collision_layer_value(layer, true)
	area.set_collision_mask_value(mask, true)
	area.collision_layer = layer
	area.collision_mask = GlobalConstants.COLLISION_LAYER_ANIMAL_DETECTION

	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = radius
	collision_shape.shape = circle_shape

	area.add_child(collision_shape)
	return area
