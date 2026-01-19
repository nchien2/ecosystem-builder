extends Node
class_name SimulationManager

## Centralized simulation timing and coordination
## Handles fixed timestep updates for all simulation entities

signal simulation_started
signal simulation_stopped
signal timestep_processed  # Emitted each time a simulation timestep is processed

var is_running: bool = false
var speed_multiplier: float = 1.0
var has_simulation_started: bool = false  # True after first simulation start (permanently disables placement)

# Centralized accumulator - ensures all entities update in perfect sync
var sim_accumulator: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	
	# Accumulate time and process at fixed timestep
	sim_accumulator += delta
	if sim_accumulator >= GlobalConstants.SIMULATION_TIMESTEP:
		sim_accumulator -= GlobalConstants.SIMULATION_TIMESTEP
		_process_timestep()

func _process_timestep() -> void:
	# Notify all simulation entities to process their logic
	# get_tree().call_group("animals", "_process_simulation")
	
	# Emit signal for any other systems that need to react to timesteps
	timestep_processed.emit()

func start_simulation() -> void:
	if is_running:
		return
	
	is_running = true
	has_simulation_started = true  # Once simulation starts, placement is permanently disabled
	sim_accumulator = 0.0  # Reset accumulator on start
	simulation_started.emit()
	
	# Notify all animals
	# get_tree().call_group("animals", "set_simulation_running", true)

func stop_simulation() -> void:
	if not is_running:
		return
	
	is_running = false
	sim_accumulator = 0.0  # Reset accumulator on stop
	simulation_stopped.emit()
	
	# Notify all animals
	# get_tree().call_group("animals", "set_simulation_running", false)