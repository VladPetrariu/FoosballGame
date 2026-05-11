extends Node3D

@onready var table: Node3D = $Table
@onready var ball: Node3D = $Ball

var physics_world: PhysicsWorld = PhysicsWorld.new()

var bars: Array = []
var p1_bars: Array = []
var p2_bars: Array = []
var bar_states: Array = []
var input_handler: InputHandler

const BarScene = preload("res://scenes/game/bar.tscn")


func _ready() -> void:
	_setup_input_handler()
	_setup_bars()
	_init_bar_states()
	physics_world.initialize(table, bar_states, bars)
	reset_ball()


func _physics_process(delta: float) -> void:
	_update_bar_resets(delta)
	_update_bar_visuals()
	physics_world.step(Constants.PHYSICS_DT)
	if physics_world.goal_scored >= 0:
		_on_goal(physics_world.goal_scored)
	ball.update_position(physics_world.get_ball_3d_position())
	ball.update_rotation(physics_world.ball_vel, Constants.PHYSICS_DT)


func _setup_input_handler() -> void:
	input_handler = InputHandler.new()
	add_child(input_handler)
	input_handler.bar_input.connect(_on_bar_input)
	input_handler.bar_released.connect(_on_bar_released)


func _setup_bars() -> void:
	# Initialize arrays for quick lookup by bar_type (0-3)
	p1_bars.resize(4)
	p2_bars.resize(4)

	for i in range(Constants.BAR_CONFIG.size()):
		var config: Array = Constants.BAR_CONFIG[i]
		var player: int = config[0]
		var bar_type: int = config[1]
		var x_pos: float = config[2]
		var fig_count: int = config[3]

		var bar = BarScene.instantiate()
		var parent: Node3D = $Bars/P1Bars if player == Constants.PLAYER_1 else $Bars/P2Bars
		parent.add_child(bar)
		bar.setup(player, bar_type, x_pos, fig_count)
		bars.append(bar)

		# Store reference by bar_type for input lookup
		if player == Constants.PLAYER_1:
			p1_bars[bar_type] = bar
		else:
			p2_bars[bar_type] = bar


func _init_bar_states() -> void:
	for i in range(8):
		bar_states.append({
			"z_offset": 0.0,
			"rotation": 0.0,
			"rotation_speed": 0.0,
		})


func _on_bar_input(player: int, rot_delta: float, slide_delta: float) -> void:
	if player == Constants.PLAYER_1:
		var bar_type: int = input_handler.active_bar_index
		var bar_node = p1_bars[bar_type]
		var idx: int = bars.find(bar_node)
		var state: Dictionary = bar_states[idx]
		state.rotation += rot_delta
		state.rotation_speed = rot_delta / Constants.PHYSICS_DT
		state.z_offset = clampf(
			state.z_offset + slide_delta,
			-bar_node.slide_range,
			bar_node.slide_range
		)


func _on_bar_released(_player: int) -> void:
	pass


func _update_bar_resets(dt: float) -> void:
	for i in range(8):
		var state: Dictionary = bar_states[i]
		var bar_node = bars[i]

		var is_active := false
		if bar_node.player == Constants.PLAYER_1:
			is_active = (bar_node.bar_index == input_handler.active_bar_index
						and input_handler.is_mouse_held)

		if not is_active:
			# Normalize rotation to [-PI, PI] for shortest path reset
			var normalized: float = fmod(state.rotation, TAU)
			if normalized > PI:
				normalized -= TAU
			elif normalized < -PI:
				normalized += TAU

			if abs(normalized) > 0.01:
				var reset_dir: float = -sign(normalized)
				var reset_amount: float = reset_dir * Constants.BAR_ROTATION_RESET_SPEED * dt
				normalized += reset_amount
				# Check if we crossed zero
				if sign(normalized) != sign(normalized - reset_amount):
					normalized = 0.0
				state.rotation = normalized
				state.rotation_speed = reset_dir * Constants.BAR_ROTATION_RESET_SPEED
			else:
				state.rotation = 0.0
				state.rotation_speed = 0.0


func _update_bar_visuals() -> void:
	for i in range(bars.size()):
		var bar_node = bars[i]
		var state: Dictionary = bar_states[i]
		bar_node.apply_state(state.z_offset, state.rotation, state.rotation_speed)

		if bar_node.player == Constants.PLAYER_1:
			bar_node.is_selected = (bar_node.bar_index == input_handler.active_bar_index)
		else:
			bar_node.is_selected = false
		bar_node.update_selection_visual()


func _on_goal(scorer: int) -> void:
	GameManager.goal_scored(scorer)
	reset_ball()


func reset_ball() -> void:
	physics_world.reset_ball()
	ball.update_position(physics_world.get_ball_3d_position())
