extends Node3D

# Returns wall segments as an array of dictionaries.
# Each segment has "start" (Vector2) and "end" (Vector2) in the XZ plane,
# plus "normal" (Vector2) pointing inward.
func get_wall_segments() -> Array:
	var half_l = Constants.TABLE_LENGTH / 2.0
	var half_w = Constants.TABLE_WIDTH / 2.0
	var half_goal = Constants.GOAL_WIDTH / 2.0
	var segments: Array = []

	# Top wall (positive Z)
	segments.append({
		"start": Vector2(-half_l, half_w),
		"end": Vector2(half_l, half_w),
		"normal": Vector2(0, -1)
	})

	# Bottom wall (negative Z)
	segments.append({
		"start": Vector2(-half_l, -half_w),
		"end": Vector2(half_l, -half_w),
		"normal": Vector2(0, 1)
	})

	# Left wall segments (negative X) - two segments with goal gap
	# Upper segment (positive Z side)
	segments.append({
		"start": Vector2(-half_l, half_w),
		"end": Vector2(-half_l, half_goal),
		"normal": Vector2(1, 0)
	})
	# Lower segment (negative Z side)
	segments.append({
		"start": Vector2(-half_l, -half_goal),
		"end": Vector2(-half_l, -half_w),
		"normal": Vector2(1, 0)
	})

	# Right wall segments (positive X) - two segments with goal gap
	segments.append({
		"start": Vector2(half_l, half_w),
		"end": Vector2(half_l, half_goal),
		"normal": Vector2(-1, 0)
	})
	segments.append({
		"start": Vector2(half_l, -half_goal),
		"end": Vector2(half_l, -half_w),
		"normal": Vector2(-1, 0)
	})

	# Goal box interior walls so the ball settles inside after scoring
	var depth = Constants.GOAL_DEPTH

	# Left goal: back wall + top + bottom
	segments.append({
		"start": Vector2(-half_l - depth, half_goal),
		"end": Vector2(-half_l - depth, -half_goal),
		"normal": Vector2(1, 0)
	})
	segments.append({
		"start": Vector2(-half_l, half_goal),
		"end": Vector2(-half_l - depth, half_goal),
		"normal": Vector2(0, -1)
	})
	segments.append({
		"start": Vector2(-half_l - depth, -half_goal),
		"end": Vector2(-half_l, -half_goal),
		"normal": Vector2(0, 1)
	})

	# Right goal: back wall + top + bottom
	segments.append({
		"start": Vector2(half_l + depth, half_goal),
		"end": Vector2(half_l + depth, -half_goal),
		"normal": Vector2(-1, 0)
	})
	segments.append({
		"start": Vector2(half_l, half_goal),
		"end": Vector2(half_l + depth, half_goal),
		"normal": Vector2(0, -1)
	})
	segments.append({
		"start": Vector2(half_l + depth, -half_goal),
		"end": Vector2(half_l, -half_goal),
		"normal": Vector2(0, 1)
	})

	return segments

# Returns two Rect2 for goal detection zones (in XZ plane).
# Index 0 = left goal (Player 2 scores here), Index 1 = right goal (Player 1 scores here)
func get_goal_rects() -> Array:
	var half_l = Constants.TABLE_LENGTH / 2.0
	var half_goal = Constants.GOAL_WIDTH / 2.0
	var depth = Constants.GOAL_DEPTH

	var left_goal = Rect2(
		Vector2(-half_l - depth, -half_goal),
		Vector2(depth, Constants.GOAL_WIDTH)
	)
	var right_goal = Rect2(
		Vector2(half_l, -half_goal),
		Vector2(depth, Constants.GOAL_WIDTH)
	)

	return [left_goal, right_goal]
