extends Node3D

var player: int = 0
var bar_index: int = 0
var z_offset: float = 0.0
var rotation_angle: float = 0.0
var rotation_speed: float = 0.0
var figure_count: int = 1
var figure_base_positions: Array = []
var slide_range: float = 0.0
var is_selected: bool = false

@onready var rod: MeshInstance3D = $Rod
@onready var figures: Node3D = $Figures
@onready var selection_indicator: MeshInstance3D = $SelectionIndicator


func setup(p_player: int, p_bar_index: int, p_x_pos: float, p_fig_count: int) -> void:
	player = p_player
	bar_index = p_bar_index
	figure_count = p_fig_count
	position.x = p_x_pos
	position.y = Constants.TABLE_SURFACE_Y + 0.035
	_setup_rod()
	_setup_selection_indicator()
	_create_figures()
	_compute_slide_range()


func _compute_slide_range() -> void:
	# Outermost figure on the bar should be able to reach the wall edge.
	var max_abs_z: float = 0.0
	for z in figure_base_positions:
		max_abs_z = max(max_abs_z, abs(z))
	slide_range = Constants.TABLE_WIDTH / 2.0 - max_abs_z


func _setup_rod() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.004
	mesh.bottom_radius = 0.004
	mesh.height = Constants.TABLE_WIDTH + 0.10
	rod.mesh = mesh
	rod.rotation.x = deg_to_rad(90)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.78)
	mat.metallic = 0.8
	mat.roughness = 0.3
	rod.material_override = mat


func _setup_selection_indicator() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03
	selection_indicator.mesh = mesh
	selection_indicator.position = Vector3(0, 0.03, (Constants.TABLE_WIDTH + 0.10) / 2.0 + 0.02)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.9, 0.0)
	mat.emission_energy_multiplier = 2.0
	selection_indicator.material_override = mat
	selection_indicator.visible = false


func _create_figures() -> void:
	var usable_range := 0.60
	var spacing := usable_range / (figure_count + 1)
	for i in range(figure_count):
		var fig := _make_figure_mesh()
		var z := -usable_range / 2.0 + spacing * (i + 1)
		fig.position.z = z
		figure_base_positions.append(z)
		figures.add_child(fig)


func _make_figure_mesh() -> Node3D:
	var fig := Node3D.new()
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.03, 0.08, 0.035)
	body.mesh = mesh
	body.position.y = -0.04

	var mat := StandardMaterial3D.new()
	if player == Constants.PLAYER_1:
		mat.albedo_color = Color("#CC2200")
	else:
		mat.albedo_color = Color("#0044CC")
	body.material_override = mat
	fig.add_child(body)
	return fig


func apply_state(p_z_offset: float, p_rotation: float, p_rot_speed: float) -> void:
	z_offset = p_z_offset
	rotation_angle = p_rotation
	rotation_speed = p_rot_speed
	position.z = z_offset
	figures.rotation.z = rotation_angle


func get_figure_world_positions() -> Array:
	var positions: Array = []
	for base_z in figure_base_positions:
		var world_z: float = base_z + z_offset
		positions.append(Vector2(position.x, world_z))
	return positions


func get_figure_collision_rect(fig_index: int) -> Rect2:
	var base_z: float = figure_base_positions[fig_index] + z_offset
	var x: float = position.x
	var foot_reach: float = 0.05 * sin(rotation_angle)
	var half_w: float = 0.015 / 2.0 + abs(foot_reach)
	var half_d: float = 0.02 / 2.0
	return Rect2(x - half_w, base_z - half_d, half_w * 2, half_d * 2)


func update_selection_visual() -> void:
	selection_indicator.visible = is_selected
