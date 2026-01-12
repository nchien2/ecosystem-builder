extends "res://biomes/base_biome.gd"
class_name GrasslandBiome

## A circular grassland biome

func _ready() -> void:
	biome_color = Color(0.2, 0.5, 0.15, 0.8)  # Grassy green
	biome_radius = 600.0
	fade_start = 0.6
	
	super._ready()
