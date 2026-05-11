extends Node

# --- Physics ---
const PHYSICS_HZ: int = 120
const PHYSICS_DT: float = 1.0 / 120.0
const FIXED_POINT_SCALE: int = 10000

# --- Table Dimensions (in Godot units ≈ meters) ---
const TABLE_LENGTH: float = 1.20
const TABLE_WIDTH: float = 0.68
const TABLE_HEIGHT: float = 0.09
const TABLE_SURFACE_Y: float = 0.75
const WALL_THICKNESS: float = 0.03
const GOAL_WIDTH: float = 0.20
const GOAL_DEPTH: float = 0.08

# --- Ball ---
const BALL_RADIUS: float = 0.017
const BALL_MAX_SPEED: float = 5.0
const BALL_FRICTION: float = 0.985
const BALL_WALL_RESTITUTION: float = 0.75
const BALL_DRIFT_ACCELERATION: float = 0.02    # m/s² very gentle drift so ball never sits still
const BALL_DRIFT_PHASE_SPEED: float = 0.3      # rad/s rotation of drift direction
const BALL_DRIFT_ACTIVATION_SPEED: float = 0.1 # m/s — drift only kicks in below this speed

# --- Figure Collision ---
const FIGURE_BODY_HALF_WIDTH: float = 0.015     # 30mm body / 2 (visual reference)
const FIGURE_BODY_HALF_DEPTH: float = 0.022     # Z half-extent with small safety margin
const FIGURE_COLLISION_HALF_REACH: float = 0.085  # sqrt(half_w^2 + body_height^2) + margin — covers the rotated body at any angle so the ball can't phase through during a swing
const FIGURE_FOOT_LENGTH: float = 0.08          # Lever arm for kick power (body height)
const FIGURE_KICK_POWER_SCALE: float = 1.5      # Tunable shot-power multiplier
const BALL_MIN_BOUNCE_SPEED: float = 0.2        # Floor after figure collision

# --- Bars ---
# Interleaved bar layout from left to right: [player, bar_type, x_position, figure_count]
# bar_type: 0=goalie, 1=defense, 2=midfield, 3=attack
const BAR_CONFIG: Array = [
	[PLAYER_1, 0, -0.50, 1],  # P1 Goalie
	[PLAYER_1, 1, -0.36, 2],  # P1 Defense
	[PLAYER_2, 3, -0.22, 3],  # P2 Attack
	[PLAYER_1, 2, -0.08, 5],  # P1 Midfield
	[PLAYER_2, 2,  0.08, 5],  # P2 Midfield
	[PLAYER_1, 3,  0.22, 3],  # P1 Attack
	[PLAYER_2, 1,  0.36, 2],  # P2 Defense
	[PLAYER_2, 0,  0.50, 1],  # P2 Goalie
]

const BAR_MAX_ROTATION_SPEED: float = 20.0
const BAR_ROTATION_RESET_SPEED: float = 10.0

# --- Scoring ---
const GOALS_TO_WIN: int = 5

# --- Network ---
const INPUT_BUFFER_SIZE: int = 8
const MAX_ROLLBACK_FRAMES: int = 10
const INPUT_DELAY_FRAMES: int = 2

# --- Player IDs ---
const PLAYER_1: int = 0
const PLAYER_2: int = 1
