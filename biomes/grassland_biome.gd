extends "res://biomes/base_biome.gd"
class_name GrasslandBiome

## A circular grassland biome that allows prey to forage for energy
## Grasslands have abundant vegetation that regenerates over time,
## but can be over-grazed if too many prey animals consume it.

signal vegetation_depleted  # Emitted when vegetation hits zero
signal vegetation_restored  # Emitted when vegetation returns from zero

func _ready() -> void:
	# Visual properties
	biome_color = Color(0.2, 0.5, 0.15, 0.8)  # Grassy green
	biome_radius = 2000.0
	fade_start = 0.6
	
	# Grassland-specific vegetation properties
	allows_foraging = true
	max_vegetation_energy = 2000.0      # Grasslands have lots of vegetation
	vegetation_energy = 2000.0          # Start fully grown
	vegetation_regen_rate = 8.0         # Grass regrows fairly quickly
	foraging_energy_per_tick = 0.5      # Energy prey gains per tick while foraging
	
	super._ready()

func _regenerate_vegetation() -> void:
	var was_depleted = vegetation_energy <= 0
	vegetation_energy = clampf(
		vegetation_energy + vegetation_regen_rate * GlobalConstants.SIMULATION_TIMESTEP,
		0.0,
		max_vegetation_energy
	)
	
	# Emit signal when vegetation is restored from zero
	if was_depleted and vegetation_energy > 0:
		vegetation_restored.emit()
	
	# Update visual based on vegetation level (cheap modulate operation)
	_update_biome_visual()

func forage() -> float:
	## Attempt to forage from this biome. Returns energy gained (0 if not possible).
	if not allows_foraging or vegetation_energy <= 0:
		return 0.0
	
	var energy_gained = minf(foraging_energy_per_tick, vegetation_energy)
	vegetation_energy -= energy_gained
	
	if vegetation_energy <= 0:
		vegetation_depleted.emit()
	
	_update_biome_visual()
	return energy_gained

func _update_biome_visual() -> void:
	# Use sprite modulate to adjust color - this is GPU-accelerated and very cheap
	# compared to recreating the texture every frame
	var sprite = get_node_or_null("BiomeSprite")
	if sprite and sprite is Sprite2D:
		var veg_percent = vegetation_energy / max_vegetation_energy
		# Interpolate between depleted and full color using modulate
		sprite.modulate = depleted_color.lerp(biome_color, veg_percent)