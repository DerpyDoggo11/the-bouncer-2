extends Item

## Speed (px/s) along the board at which the wheel animation plays at normal speed.
@export var roll_speed := 60.0
## Below this speed the wheels stop.
@export var min_roll_speed := 5.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func held_physics(holder: RigidBody2D, _delta: float) -> void:
	var along := holder.linear_velocity.dot(global_transform.x)
	if absf(along) < min_roll_speed:
		sprite.pause()
		return
	# Negative speed_scale plays the frames backwards when rolling the other way.
	sprite.speed_scale = along / roll_speed
	sprite.play()
