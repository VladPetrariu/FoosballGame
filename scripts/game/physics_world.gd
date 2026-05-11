class_name PhysicsWorld

# Deterministic 2D ball simulation on the table XZ plane.
# Vector2.x = world X, Vector2.y = world Z. Y is constant (table surface).

var ball_pos: Vector2 = Vector2.ZERO
var ball_vel: Vector2 = Vector2.ZERO
var ball_radius: float = Constants.BALL_RADIUS

var wall_segments: Array = []
var goal_zones: Array = []

# References owned by game.gd; we read but don't reassign.
var bar_states: Array = []
var bar_nodes: Array = []

# Set during step(): -1 = no goal, 0 = P1 scored, 1 = P2 scored.
var goal_scored: int = -1

# Continuously rotating phase used to drive a slow drift force on the ball,
# so it never sits perfectly still where no player can reach it.
var drift_phase: float = 0.0


func initialize(table: Node, p_bar_states: Array, p_bar_nodes: Array) -> void:
	wall_segments = table.get_wall_segments()
	goal_zones = table.get_goal_rects()
	bar_states = p_bar_states
	bar_nodes = p_bar_nodes


func reset_ball() -> void:
	ball_pos = Vector2.ZERO
	ball_vel = Vector2.ZERO
	goal_scored = -1


func step(dt: float) -> void:
	goal_scored = -1
	_apply_friction()
	_apply_drift(dt)
	_move_and_collide(dt)
	_check_goals()
	_clamp_speed()


func get_ball_3d_position() -> Vector3:
	return Vector3(ball_pos.x, Constants.TABLE_SURFACE_Y + Constants.BALL_RADIUS, ball_pos.y)


func _apply_friction() -> void:
	ball_vel *= Constants.BALL_FRICTION


func _apply_drift(dt: float) -> void:
	# Phase always advances so direction naturally varies between drift periods.
	drift_phase += Constants.BALL_DRIFT_PHASE_SPEED * dt
	# Skip drift force entirely if the ball is already in play (kicked).
	var threshold: float = Constants.BALL_DRIFT_ACTIVATION_SPEED
	if ball_vel.length_squared() >= threshold * threshold:
		return
	var direction: Vector2 = Vector2(cos(drift_phase), sin(drift_phase))
	ball_vel += direction * Constants.BALL_DRIFT_ACCELERATION * dt


func _clamp_speed() -> void:
	var speed: float = ball_vel.length()
	if speed > Constants.BALL_MAX_SPEED:
		ball_vel = ball_vel.normalized() * Constants.BALL_MAX_SPEED


func _reflect(vel: Vector2, normal: Vector2) -> Vector2:
	return vel - 2.0 * vel.dot(normal) * normal


func _move_and_collide(dt: float) -> void:
	var remaining_dt: float = dt
	var max_iterations: int = 5

	for iteration in range(max_iterations):
		if remaining_dt <= 0.0 or ball_vel.length_squared() < 0.00001:
			break

		var move: Vector2 = ball_vel * remaining_dt
		var earliest_t: float = 1.0
		var hit_normal: Vector2 = Vector2.ZERO
		var hit_type: String = ""
		var hit_data: Dictionary = {}

		for wall in wall_segments:
			var t: float = _swept_circle_segment(
				ball_pos, move, ball_radius,
				wall.start, wall.end, wall.normal
			)
			if t >= 0.0 and t < earliest_t:
				earliest_t = t
				hit_normal = wall.normal
				hit_type = "wall"

		var fig_hit: Dictionary = _check_figure_collisions(ball_pos, move)
		if fig_hit.t >= 0.0 and fig_hit.t < earliest_t:
			earliest_t = fig_hit.t
			hit_normal = fig_hit.normal
			hit_type = "figure"
			hit_data = fig_hit

		var safe_t: float = max(earliest_t - 0.001, 0.0)
		ball_pos += move * safe_t

		if hit_type == "wall":
			ball_vel = _reflect(ball_vel, hit_normal) * Constants.BALL_WALL_RESTITUTION
			remaining_dt *= (1.0 - earliest_t)
		elif hit_type == "figure":
			_resolve_figure_collision(hit_data)
			remaining_dt *= (1.0 - earliest_t)
		else:
			ball_pos += move * (1.0 - safe_t)
			break


func _swept_circle_segment(
	circle_pos: Vector2, circle_move: Vector2, radius: float,
	seg_start: Vector2, seg_end: Vector2, seg_normal: Vector2
) -> float:
	var d: float = (circle_pos - seg_start).dot(seg_normal)
	if d < -radius:
		return -1.0

	var vn: float = circle_move.dot(seg_normal)
	if vn >= 0.0:
		return -1.0

	var t: float = (d - radius) / -vn
	if t < 0.0 or t > 1.0:
		return -1.0

	var contact: Vector2 = circle_pos + circle_move * t
	var seg_dir: Vector2 = seg_end - seg_start
	var seg_len: float = seg_dir.length()
	if seg_len < 0.00001:
		return -1.0
	seg_dir /= seg_len
	var proj: float = (contact - seg_start).dot(seg_dir)

	if proj < 0.0 or proj > seg_len:
		var endpoint: Vector2 = seg_start if proj < 0.0 else seg_end
		return _swept_circle_point(circle_pos, circle_move, radius, endpoint)

	return t


func _swept_circle_point(
	circle_pos: Vector2, circle_move: Vector2, radius: float,
	point: Vector2
) -> float:
	var diff: Vector2 = circle_pos - point
	var a: float = circle_move.dot(circle_move)
	if a < 0.00001:
		return -1.0
	var b: float = 2.0 * diff.dot(circle_move)
	var c: float = diff.dot(diff) - radius * radius

	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0

	var sqrt_d: float = sqrt(discriminant)
	var t: float = (-b - sqrt_d) / (2.0 * a)

	if t >= 0.0 and t <= 1.0:
		return t
	return -1.0


func _check_figure_collisions(pos: Vector2, move: Vector2) -> Dictionary:
	var best: Dictionary = {"t": -1.0, "normal": Vector2.ZERO, "bar_index": -1, "rotation_speed": 0.0}

	for i in range(bar_nodes.size()):
		var bar = bar_nodes[i]
		var state: Dictionary = bar_states[i]

		var fig_positions: Array = bar.get_figure_world_positions()
		for fig_idx in range(fig_positions.size()):
			var fig_pos: Vector2 = fig_positions[fig_idx]

			# Conservative AABB that always contains the body's rotated swept reach.
			# No rotation gating: ensures the ball cannot tunnel through a figure
			# regardless of how fast the bar is spinning.
			var half_w: float = Constants.FIGURE_COLLISION_HALF_REACH
			var half_d: float = Constants.FIGURE_BODY_HALF_DEPTH

			var t: float = _swept_circle_aabb(
				pos, move, ball_radius,
				fig_pos, Vector2(half_w, half_d)
			)

			if t >= 0.0 and (best.t < 0.0 or t < best.t):
				var contact_pos: Vector2 = pos + move * t
				var normal: Vector2 = contact_pos - fig_pos
				if normal.length_squared() < 0.000001:
					normal = -move.normalized() if move.length_squared() > 0.0 else Vector2(1, 0)
				else:
					normal = normal.normalized()

				best = {
					"t": t,
					"normal": normal,
					"bar_index": i,
					"rotation_speed": state.rotation_speed,
					"fig_pos": fig_pos
				}

	return best


func _swept_circle_aabb(
	pos: Vector2, move: Vector2, radius: float,
	aabb_center: Vector2, aabb_half: Vector2
) -> float:
	var expanded_half: Vector2 = aabb_half + Vector2(radius, radius)
	var min_corner: Vector2 = aabb_center - expanded_half
	var max_corner: Vector2 = aabb_center + expanded_half

	var t_enter: float = 0.0
	var t_exit: float = 1.0

	for axis in range(2):
		var p: float = pos[axis]
		var d: float = move[axis]
		var mn: float = min_corner[axis]
		var mx: float = max_corner[axis]

		if abs(d) < 0.00001:
			if p < mn or p > mx:
				return -1.0
		else:
			var t1: float = (mn - p) / d
			var t2: float = (mx - p) / d
			if t1 > t2:
				var tmp: float = t1
				t1 = t2
				t2 = tmp
			t_enter = max(t_enter, t1)
			t_exit = min(t_exit, t2)
			if t_enter > t_exit:
				return -1.0

	if t_enter >= 0.0 and t_enter <= 1.0:
		return t_enter
	return -1.0


func _resolve_figure_collision(hit: Dictionary) -> void:
	var normal: Vector2 = hit.normal
	var rot_speed: float = abs(hit.rotation_speed)

	ball_vel = _reflect(ball_vel, normal)

	var kick_power: float = rot_speed * Constants.FIGURE_FOOT_LENGTH
	ball_vel += normal * kick_power * Constants.FIGURE_KICK_POWER_SCALE

	if ball_vel.length() < Constants.BALL_MIN_BOUNCE_SPEED:
		ball_vel = normal * Constants.BALL_MIN_BOUNCE_SPEED

	_clamp_speed()


func _check_goals() -> void:
	for i in range(goal_zones.size()):
		var zone: Rect2 = goal_zones[i]
		if zone.has_point(ball_pos):
			# goal_zones[0] (left) -> P2 scored, goal_zones[1] (right) -> P1 scored.
			goal_scored = 1 - i
			return
