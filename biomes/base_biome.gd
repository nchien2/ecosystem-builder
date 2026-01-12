extends Node2D
class_name BaseBiome

## Base class for biomes

@export var biome_radius: float = 300.0  
@export var biome_color: Color = Color.WHITE  
@export var fade_start: float = 0.6  # Where the fade begins (0-1, as fraction of radius)

func _ready() -> void:
	z_index = 1 
	_create_biome_visual()

func _create_biome_visual() -> void:
	# Use Godot's built-in GradientTexture2D with radial fill
	var gradient = Gradient.new()
	
	# Create color stops: solid color -> fade to transparent
	var transparent_color = Color(biome_color.r, biome_color.g, biome_color.b, 0.0)
	gradient.set_color(0, biome_color)      # Center color
	gradient.add_point(fade_start, biome_color)  # Solid until fade_start
	gradient.set_color(2, transparent_color)     # Fade to transparent at edge
	
	# Create radial gradient texture
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)  # Center
	gradient_texture.fill_to = Vector2(1.0, 0.5)    # Edge (radius)
	gradient_texture.width = int(biome_radius * 2)
	gradient_texture.height = int(biome_radius * 2)
	
	var sprite = Sprite2D.new()
	sprite.texture = gradient_texture
	sprite.name = "BiomeSprite"
	add_child(sprite)
