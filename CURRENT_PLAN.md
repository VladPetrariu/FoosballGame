# Foosball Game - Phase 03 Implementation Plan

## Project Status

**Completed:** Phase 01 - Project Scaffold and Table
- Godot 4.6 project structure established (autoloads, scenes/, scripts/, assets/)
- 3D foosball table (1.20m × 0.68m) with surface, walls, goal openings, legs, center line
- Ball visual (sphere, 0.017m radius)
- HUD with score display, wired to `GameManager.on_goal_scored`
- Camera (top-down with slight angle) and lighting (directional + 2 spotlights)
- Constants autoload with physics, table, ball, bar, scoring, network parameters

**Completed:** Phase 02 - Bars, Figures, and Controls
- 8 bars spawned via interleaved `BAR_CONFIG` (4 per player, alternating along X)
- Per-bar figure spawning (1/2/5/3 figures for goalie/defense/midfield/attack)
- Red (P1) / blue (P2) figure materials, silver metallic rod, emissive selection indicator
- `InputHandler` with mouse capture, KEY_1-4 bar selection, ESC release, left-mouse hold for rotation, vertical mouse motion always slides
- Bar state array (z_offset, rotation, rotation_speed) updated from input
- Smooth return-to-vertical for inactive bars (with rotation normalized to [-π, π] for shortest path)
- Selection indicator visibility synced to active bar each frame

**Current Phase:** Phase 03 - Ball Physics

**Goal:** Replace the `PhysicsWorld` stub with a custom deterministic 2D (XZ-plane) ball simulation: movement + friction, swept circle-vs-segment wall collisions, swept circle-vs-AABB figure collisions where bar `rotation_speed` translates into shot power, and goal detection.

---

## Implementation Divergences from Phase 02 Plan (carry forward)

Things the codebase does differently from the original plan text — physics work in Phase 03 must respect these:

1. **`BAR_CONFIG` interleaved layout** — `constants.gd` stores all 8 bars as `[player, bar_type, x_position, fig_count]` rows ordered by world X position. Physics iterates `bars[]` (which mirrors `BAR_CONFIG`) directly, not separate P1/P2 arrays.
2. **`table.gd` exposes `get_goal_rects()`**, not `get_goal_zones()`. Physics will call the existing name.
3. **Wall segments currently lack goal-box internal walls.** The current `get_wall_segments()` returns only the 6 outer-perimeter segments (top, bottom, left-upper, left-lower, right-upper, right-lower). Phase 03 must add the 3-walls-per-goal back/side segments so the ball settles inside the goal box after a score, instead of flying off into infinity.
4. **`physics_world.gd` has `class_name PhysicsWorld` with no `extends`** (implicit RefCounted). `game.gd` instantiates it with `PhysicsWorld.new()`. Keep this structure — do not convert to a Node.
5. **`physics_world.step()` currently takes no parameter.** Phase 03 changes the signature to `step(dt: float)` and `game.gd` will pass `Constants.PHYSICS_DT`.

---

## Existing Files to Modify

### 1. `scripts/game/physics_world.gd`
**Current state:** Stub with `ball_pos`, `ball_vel`, `wall_segments`, empty `step()`, `get_ball_3d_position()`.
**Required changes:** Full ball simulation — friction, swept collision (walls + figures), goal detection, shot power resolution.

### 2. `scripts/game/table.gd`
**Current state:** Returns outer wall segments and goal rects.
**Required changes:** Extend `get_wall_segments()` to include 3 internal walls per goal box (back wall + two side walls).

### 3. `scripts/game/game.gd`
**Current state:** Calls `physics_world.step()` (no args), reads `get_ball_3d_position()`, calls `reset_ball()` directly.
**Required changes:** Pass dt to `step()`, pass bar references on `initialize()`, react to `goal_scored` result, drive ball visual rotation.

### 4. `scripts/game/ball.gd`
**Current state:** Just `update_position(pos)`.
**Required changes:** Add `update_rotation(vel, dt)` so the ball mesh visually rolls when moving (cosmetic).

### 5. `scripts/autoload/constants.gd`
**Current state:** Has all physics tunables already.
**Required changes:** Add figure-collision constants (`FIGURE_BODY_HALF_WIDTH`, `FIGURE_BODY_HALF_DEPTH`, `FIGURE_FOOT_LENGTH`, `FIGURE_KICK_POWER_SCALE`, `BALL_MIN_BOUNCE_SPEED`). Keep them in one place so Phase 06 fixed-point conversion can find them.

---

## New Files to Create

None. Phase 03 is a focused rewrite of the physics stub.

---

## Implementation Steps

### Step 1: Add figure-collision constants (`constants.gd`)

Append under the `# --- Ball ---` block (or a new `# --- Figure Collision ---` block):

```gdscript
# --- Figure Collision ---
const FIGURE_BODY_HALF_WIDTH: float = 0.0075    # 15mm body / 2
const FIGURE_BODY_HALF_DEPTH: float = 0.01      # 20mm body / 2
const FIGURE_FOOT_LENGTH: float = 0.045         # How far the foot reaches
const FIGURE_KICK_POWER_SCALE: float = 0.8      # Tunable shot-power multiplier
const BALL_MIN_BOUNCE_SPEED: float = 0.2        # Floor after figure collision
```

### Step 2: Extend `table.gd::get_wall_segments()`

Append goal-box back + two side walls for each goal (6 new segments total). Inward normals:

- **Left goal back** at `x = -half_l - GOAL_DEPTH`, normal `Vector2(1, 0)`
- **Left goal top side** from `(-half_l, half_goal)` to `(-half_l - GOAL_DEPTH, half_goal)`, normal `Vector2(0, -1)`
- **Left goal bottom side** mirrored, normal `Vector2(0, 1)`
- **Right goal back** at `x = half_l + GOAL_DEPTH`, normal `Vector2(-1, 0)`
- **Right goal top side**, normal `Vector2(0, -1)`
- **Right goal bottom side**, normal `Vector2(0, 1)`

### Step 3: Rewrite `physics_world.gd`

**Properties:**
- `ball_pos: Vector2`, `ball_vel: Vector2`, `ball_radius: float`
- `wall_segments: Array` (from table)
- `goal_zones: Array` (from `table.get_goal_rects()`)
- `bar_states: Array` (reference, owned by game)
- `bar_nodes: Array` (reference, owned by game)
- `goal_scored: int` (-1 / 0 / 1, set during `step()`)

**New `initialize` signature:**
```gdscript
func initialize(table: Node, p_bar_states: Array, p_bar_nodes: Array) -> void:
    wall_segments = table.get_wall_segments()
    goal_zones = table.get_goal_rects()
    bar_states = p_bar_states
    bar_nodes = p_bar_nodes
```

**New `step(dt)`:**
```gdscript
func step(dt: float) -> void:
    goal_scored = -1
    _apply_friction()
    _move_and_collide(dt)
    _check_goals()
    _clamp_speed()
```

**Methods to implement (per plan 03):**
- `_apply_friction()` — `ball_vel *= BALL_FRICTION`; zero if `length_squared() < 0.0001`
- `_clamp_speed()` — cap at `BALL_MAX_SPEED`
- `_move_and_collide(dt)` — iterative swept solver (up to 5 substeps); picks earliest of wall/figure hits, advances ball to safe_t, reflects, recurses with remaining dt
- `_swept_circle_segment(...)` — distance-to-line + endpoint fallback to `_swept_circle_point`
- `_swept_circle_point(...)` — quadratic ray-vs-expanded-circle
- `_check_figure_collisions(pos, move)` — loops `bar_nodes[i]`; skips bar if `cos(rotation) < 0.1` (figures raised); for each figure, builds AABB whose X half-width grows with `|sin(rotation)| * FIGURE_FOOT_LENGTH`; tests with `_swept_circle_aabb`
- `_swept_circle_aabb(...)` — slab-based ray-vs-expanded-AABB
- `_resolve_figure_collision(hit)` — reflect normal, add `hit.normal * abs(rotation_speed) * FIGURE_FOOT_LENGTH * FIGURE_KICK_POWER_SCALE`, enforce `BALL_MIN_BOUNCE_SPEED`, clamp
- `_check_goals()` — `goal_zones[0]` (left) = P2 scored, `goal_zones[1]` (right) = P1 scored
- `_reflect(vel, normal)` — `vel - 2 * vel.dot(normal) * normal`
- `reset_ball()` — zero pos/vel, clear `goal_scored`

**Determinism notes for Phase 06 prep:** prefer squared-distance comparisons where possible; avoid Dictionary allocations in hot path (consider Array tuples or pre-allocated state). Acceptable to use floats for Phase 03 — Phase 06 does the fixed-point pass.

### Step 4: Update `ball.gd` for visual rolling

```gdscript
func update_rotation(vel: Vector2, dt: float) -> void:
    if vel.length_squared() < 0.0001:
        return
    var speed: float = vel.length()
    var spin: float = speed * dt / Constants.BALL_RADIUS  # rolling: ω = v/r
    rotate_x(spin * sign(vel.y))
    rotate_z(-spin * sign(vel.x))
```

Cosmetic only — does not feed back into physics.

### Step 5: Wire `game.gd` to new physics API

**Modified `_ready()`:**
```gdscript
func _ready() -> void:
    _setup_input_handler()
    _setup_bars()
    _init_bar_states()
    physics_world.initialize(table, bar_states, bars)
    reset_ball()
```

**Modified `_physics_process(delta)`:**
```gdscript
func _physics_process(delta: float) -> void:
    _update_bar_resets(delta)
    _update_bar_visuals()
    physics_world.step(Constants.PHYSICS_DT)
    if physics_world.goal_scored >= 0:
        _on_goal(physics_world.goal_scored)
    ball.update_position(physics_world.get_ball_3d_position())
    ball.update_rotation(physics_world.ball_vel, Constants.PHYSICS_DT)
```

**New `_on_goal(scorer)`:**
```gdscript
func _on_goal(scorer: int) -> void:
    GameManager.goal_scored(scorer)
    reset_ball()
```

Match-end / kickoff-delay polish is deferred to Phase 04.

**`reset_ball()` already exists** — zero `ball_pos`/`ball_vel` and place visual at center. No change needed.

---

## Verification Checklist

After implementation, verify by running the project and using a temporary debug action (e.g., a key that calls `physics_world.ball_vel = Vector2(2.0, 0.3)`) to inject motion:

- [ ] Ball with velocity slides across table and slows to a halt (friction works)
- [ ] Ball bounces off top/bottom walls realistically
- [ ] Ball bounces off left/right walls outside goal openings
- [ ] Ball entering goal opening passes through and stops inside goal box
- [ ] HUD score increments when ball enters a goal
- [ ] Ball resets to center after a goal
- [ ] Swinging a vertical-pointed bar into the ball pushes the ball away
- [ ] Fast bar rotation = faster shot than slow rotation (rotation_speed matters)
- [ ] Bar with figures pointing up (rotation ≈ π) doesn't collide with the ball
- [ ] Ball never tunnels through walls or figures, even at high speed
- [ ] Ball mesh visually rolls in the direction of motion

---

## File Change Summary

| File | Action | Approx LOC |
|------|--------|------------|
| `scripts/game/physics_world.gd` | Rewrite | ~180 |
| `scripts/game/table.gd` | Add 6 wall segments | +30 |
| `scripts/game/game.gd` | Wire new API, goal handler | +10 |
| `scripts/game/ball.gd` | Add `update_rotation` | +8 |
| `scripts/autoload/constants.gd` | Add figure-collision block | +6 |

---

## Notes

- This is the hottest code path in the project. At 120 Hz with future rollback (Phase 06, up to 10 frame re-sims), the loop can run 1200 times per second. Keep allocations out of `_move_and_collide` if reasonably possible — pre-size temporaries where it helps.
- Trig (`sin`, `cos`) is used for figure foot-reach. Phase 06 will replace this with a lookup table or fixed-point approximation for determinism. Acceptable for Phase 03.
- Floor-state ("ball stopped") is handled by zeroing velocity below a threshold so it doesn't drift forever — keep the threshold tight, or "soft tap from figure" tests fail.
- Goal detection currently uses `Rect2.has_point(ball_pos)` — center-point check, ignores ball radius. Sufficient for Phase 03; tighten in Phase 04 polish if needed.
- After Phase 03, Phase 04 layers the match state machine (KICKOFF / PLAYING / GOAL_SCORED / MATCH_END) on top, including a kickoff delay and goal celebration freeze.
