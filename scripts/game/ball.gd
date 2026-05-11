extends Node3D

# Ball visual representation. Physics handled by PhysicsWorld.

func update_position(pos: Vector3) -> void:
	global_transform.origin = pos


func update_rotation(vel: Vector2, dt: float) -> void:
	if vel.length_squared() < 0.0001:
		return
	var speed: float = vel.length()
	var spin: float = speed * dt / Constants.BALL_RADIUS
	rotate_x(spin * sign(vel.y))
	rotate_z(-spin * sign(vel.x))
