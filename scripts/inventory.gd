extends Control
## HUD showing how many items are unlocked: frame N = N items picked up.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player: RigidBody2D = owner.get_node("Player") if owner else null


func _ready() -> void:
	sprite.stop()


func _process(_delta: float) -> void:
	if player:
		sprite.frame = mini(player.inventory.size(), sprite.sprite_frames.get_frame_count("default") - 1)
