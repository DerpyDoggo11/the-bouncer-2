extends Item
## While held, sticks the player to magnetic tiles (TileSet custom data "magnetic") they touch.

const MAGNETIC_DATA := "magnetic"

## After letting go, sticking re-arms once the player leaves the wall or this many seconds pass.
@export var release_cooldown := 0.5
## Sticks when the player's body center is this close to a magnetic tile (player radius + a little).
@export var contact_radius := 9.0

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
	if cooldown > 0.0:
		cooldown -= delta
		# Still touching the wall just launched from: don't grab it again yet.
		if _closest_magnetic(holder.global_position, contact_radius).is_finite():
			return
		cooldown = 0.0
	# Walk this frame's motion in small steps so fast launches can't skip past
	# or bounce off before sticking.
	var motion := holder.linear_velocity * delta
	var steps := maxi(1, ceili(motion.length() / 2.0))
	for i in steps + 1:
		var pos := holder.global_position + motion * (float(i) / steps)
		if _closest_magnetic(pos, contact_radius).is_finite():
			holder.global_position = pos
			holder.linear_velocity = Vector2.ZERO
			holder.angular_velocity = 0.0
			holder.freeze = true
			return


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
