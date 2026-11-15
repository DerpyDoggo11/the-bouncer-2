extends Item

const MAGNETIC_DATA := "magnetic"

@export var reach := 60.0
@export var tip_length := 16.0
@export var pull_far := 1000.0
@export var pull_near := 3000.0
## After letting go, sticking re-arms once the player leaves the wall or this many seconds pass.
@export var release_cooldown := 0.5
## How close (px) the tip must get to a magnetic tile to stick.
@export var snap_radius := 4.0
## Sticks if the player's body center is this close to a magnetic tile, whichever way the magnet faces.
@export var contact_radius := 12.0

var cooldown := 0.0
var layers: Array[TileMapLayer] = []


func held_physics(holder: RigidBody2D, delta: float) -> void:
	if holder.freeze:
		cooldown = release_cooldown
		return
	if layers.is_empty():
		for layer in get_tree().root.find_children("*", "TileMapLayer", true, false):
			if layer.collision_enabled and layer.tile_set:
				layers.append(layer)
	var start := holder.global_position
	var to_center := global_position - start
	var dir := to_center.normalized()
	var tip := to_center.length() + tip_length
	if cooldown > 0.0:
		cooldown -= delta
		# Still touching the wall just launched from (by body or magnet tip): don't grab it again yet.
		if _closest_magnetic(start, contact_radius).is_finite() \
				or _closest_magnetic(start + dir * tip, snap_radius * 2.0).is_finite():
			return
		cooldown = 0.0
	if _snap(holder, dir, tip, delta):
		return
	var query := PhysicsRayQueryParameters2D.create(start, start + dir * (tip + reach), holder.collision_mask, [holder.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	# Step just inside the surface to find which tile was hit.
	if hit.is_empty() or not _closest_magnetic(hit.position - hit.normal * 0.5, 0.0).is_finite():
		return
	var gap := maxf(start.distance_to(hit.position) - tip, 0.0)
	# Gentle at range, ramping up hard as the gap closes.
	var closeness := 1.0 - gap / reach
	holder.apply_central_force(dir * lerpf(pull_far, pull_near, closeness * closeness) * holder.mass)


# Walks this frame's motion in small steps so fast launches can't skip past or
# bounce off before sticking.
func _snap(holder: RigidBody2D, dir: Vector2, tip: float, delta: float) -> bool:
	var motion := holder.linear_velocity * delta
	var steps := maxi(1, ceili(motion.length() / 2.0))
	for i in steps + 1:
		var pos := holder.global_position + motion * (float(i) / steps)
		var tip_pos := pos + dir * tip
		var target := _closest_magnetic(tip_pos, snap_radius)
		if target.is_finite():
			pos += target - tip_pos # pull in flush against the tile
		elif not _closest_magnetic(pos, contact_radius).is_finite():
			continue
		holder.global_position = pos
		holder.linear_velocity = Vector2.ZERO
		holder.angular_velocity = 0.0
		holder.freeze = true
		return true
	return false


# Closest point on any magnetic tile within radius of point, or Vector2.INF.
# Reads the tile grid directly, so it doesn't depend on how tile collisions are merged.
func _closest_magnetic(point: Vector2, radius: float) -> Vector2:
	var best := Vector2.INF
	var best_dist := INF
	for layer in layers:
		var size := Vector2(layer.tile_set.tile_size)
		var local := layer.to_local(point)
		var center := layer.local_to_map(local)
		var span := ceili(radius / minf(size.x, size.y))
		for x in range(-span, span + 1):
			for y in range(-span, span + 1):
				var cell := center + Vector2i(x, y)
				var data := layer.get_cell_tile_data(cell)
				if data == null or not data.get_custom_data(MAGNETIC_DATA):
					continue
				var rect := Rect2(layer.map_to_local(cell) - size / 2.0, size)
				var closest := local.clamp(rect.position, rect.end)
				var dist := local.distance_to(closest)
				if dist <= radius and dist < best_dist:
					best_dist = dist
					best = layer.to_global(closest)
	return best
