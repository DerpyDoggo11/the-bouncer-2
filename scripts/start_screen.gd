extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const PICKAXE_SPEED := 700.0
const PICKAXE_SPIN := 20.0 # rad/s
const HIT_RADIUS := 30.0
const DROP_GRAVITY := 1200.0
const DROP_TIME := 0.8 # seconds the player falls before the fade starts

@onready var pickaxe: Sprite2D = $Pickaxe
@onready var ufo: Sprite2D = $UFO
@onready var player: Sprite2D = $Player

var flying := false
var dropping := false
var drop_speed := 0.0


func _ready() -> void:
	pickaxe.hide()
	$StartButton.pressed.connect(_on_start)


func _on_start() -> void:
	$StartButton.disabled = true
	# Start just off-screen in a random direction from the UFO.
	var dir := Vector2.from_angle(randf() * TAU)
	pickaxe.position = ufo.position + dir * get_viewport_rect().size.length()
	pickaxe.show()
	flying = true


func _process(delta: float) -> void:
	if flying:
		pickaxe.rotation += PICKAXE_SPIN * delta
		pickaxe.position = pickaxe.position.move_toward(ufo.position, PICKAXE_SPEED * delta)
		if pickaxe.position.distance_to(ufo.position) < HIT_RADIUS:
			flying = false
			pickaxe.queue_free()
			dropping = true
			get_tree().create_timer(DROP_TIME).timeout.connect(Fade.change_scene.bind(GAME_SCENE))
	if dropping:
		drop_speed += DROP_GRAVITY * delta
		player.position.y += drop_speed * delta
