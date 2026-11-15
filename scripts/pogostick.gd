extends Item

@export var foot_length := 14.0
@export var boost := 1.3
@export var min_launch_speed := 80.0
@export var min_landing_speed := 40.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func held_physics(holder: RigidBody2D, delta: float) -> void:
	var axis := global_transform.y.normalized()
	var start := holder.global_position
	var tip := (global_position - start).dot(axis) + foot_length
	var space := get_world_2d().direct_space_state
	var sunk := space.intersect_ray(PhysicsRayQueryParameters2D.create(start, start + axis * tip, holder.collision_mask, [holder.get_rid()]))
	if not sunk.is_empty():
		holder.global_position -= axis * (tip - start.distance_to(sunk.position))
		start = holder.global_position
	var incoming := holder.linear_velocity.dot(axis)
	if incoming < min_landing_speed:
		if not sunk.is_empty() and incoming > 0.0:
			holder.linear_velocity -= axis * incoming
		return
	var query := PhysicsRayQueryParameters2D.create(start, start + axis * (tip + incoming * delta + 1.0), holder.collision_mask, [holder.get_rid()])
	if space.intersect_ray(query).is_empty():
		return
	holder.linear_velocity -= axis * (incoming + maxf(incoming * boost, min_launch_speed))
	sprite.frame = 0
	sprite.play()
