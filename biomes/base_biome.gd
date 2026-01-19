@abstract
extends Node2D
class_name BaseBiome

## Base class for biomes

@export var biome_radius: float = 300.0  
@export var biome_color: Color = Color.WHITE  
@export var fade_start: float = 0.6  # Where the fade begins (0-1, as fraction of radius)

# Vegetation/Energy system for over-grazing mechanics
@export var max_vegetation_energy: float = 1000.0  # Maximum energy available in this biome
@export var vegetation_energy: float = 1000.0      # Current energy available
@export var vegetation_regen_rate: float = 5.0     # Energy regenerated per second
@export var allows_foraging: bool = false          # Whether prey can forage here (override in subclasses)
@export var foraging_energy_per_tick: float = 0.0  # Energy given to prey per forage attempt

var biome_area: Area2D  # Collision area for biome detection
var depleted_color: Color  # Color when vegetation is depleted

func _ready() -> void:
	z_index = 1 
	add_to_group("biomes")
	depleted_color = Color(biome_color.r * 0.4, biome_color.g * 0.4, biome_color.b * 0.4, biome_color.a)
	_create_biome_visual()
	_create_biome_collision()
	SimManager.timestep_processed.connect(_process_simulation)

func _create_biome_visual() -> void:
	# Use Godot's built-in GradientTexture2D with radial fill
	# Create with WHITE color so we can use modulate to tint it efficiently
	var gradient = Gradient.new()
	
	# Create color stops: white -> fade to transparent
	# Using white allows sprite.modulate to control the actual color
	gradient.set_color(0, Color.WHITE)           # Center color (white)
	gradient.add_point(fade_start, Color.WHITE)  # Solid until fade_start
	gradient.set_color(2, Color.TRANSPARENT)     # Fade to transparent at edge
	
	# Create radial gradient texture (created once, never recreated)
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
	sprite.modulate = biome_color  # Apply color via modulate (GPU-accelerated)
	add_child(sprite)

func _create_biome_collision() -> void:
	# Create collision area to detect animals entering/exiting this biome
	biome_area = Utilities._create_circular_collision_area(
		biome_radius,
		"BiomeArea",
		GlobalConstants.COLLISION_LAYER_BIOME,
		GlobalConstants.COLLISION_LAYER_ANIMAL_BODY
	)
	biome_area.monitoring = true
	add_child(biome_area)
	biome_area.area_entered.connect(_on_animal_entered)
	biome_area.area_exited.connect(_on_animal_exited)

func _on_animal_entered(area: Area2D) -> void:
	var animal = area.get_parent()
	if animal is BaseAnimal:
		animal.current_biome = self

func _on_animal_exited(area: Area2D) -> void:
	var animal = area.get_parent()
	if animal is BaseAnimal and animal.current_biome == self:
		animal.current_biome = null

func _process_simulation() -> void:
	if not SimManager.is_running:
		return
	
	# Regenerate vegetation over time
	_regenerate_vegetation()

@abstract
func _regenerate_vegetation() -> void

@abstract
func forage() -> float

