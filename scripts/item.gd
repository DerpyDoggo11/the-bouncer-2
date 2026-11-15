class_name Item
extends RigidBody2D

## Where the item's center attaches, relative to the holder's center in world
## space at the moment it's equipped (so it's predictable however the ball is spun).
@export var hold_offset := Vector2(0, 12)
## Rotation (degrees) the item is attached with, relative to how it's drawn in its scene.
@export var hold_rotation_degrees := 0.0
## Holder's bounce while this item is underneath them. Negative = unchanged.
@export var bounce_when_below := -1.0
## Holder's friction while this item is underneath them. Negative = unchanged.
@export var friction_when_below := -1.0
## Whether the item's collision shapes are added to the holder while equipped.
@export var collides_when_held := true

# Collision layers to restore if the item is ever put back in the world.
var saved_layer := 0
var saved_mask := 0


## Called every physics frame while equipped. Override for item behaviour.
func held_physics(_holder: RigidBody2D, _delta: float) -> void:
	pass
