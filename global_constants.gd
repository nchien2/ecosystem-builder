extends Node

## Shared constants used across the ecosystem builder project

# Map/World Constants
const MAP_SIZE: Vector2 = Vector2(5000, 5000)  # Full size of the 2D space
const MAP_BOUNDARY: float = 2500.0  # Half of the map size (for boundary clamping)

# Collision Layers
## Layer 1: Animal detection areas (for spatial queries between animals)
const COLLISION_LAYER_ANIMAL_DETECTION: int = 1
## Layer 2: Animal body areas (for click detection and biome detection)
const COLLISION_LAYER_ANIMAL_BODY: int = 2
## Layer 3: Biome areas (for biome detection)
const COLLISION_LAYER_BIOME: int = 4

# Simulation Constants
const SIMULATION_TIMESTEP: float = 0.1  # Time step for sim processing (seconds)
