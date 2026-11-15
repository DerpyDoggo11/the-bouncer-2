extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const PICKAXE_SPEED := 700.0
const PICKAXE_SPIN := 20.0 # rad/s
const HIT_RADIUS := 30.0
const HOVER_SCALE := 1.2 # UFO size while hovered, relative to its scene scale
const HOVER_SMOOTHING := 10.0
const DRIFT_SPEED := 120.0 # player's initial float speed after the explosion
const DRIFT_SPIN := 3.0 # rad/s
const DROP_GRAVITY := 300.0 # weak, so the player floats before falling
const DROP_TIME := 1.5 # seconds the player drifts before the fade starts

@onready var pickaxe: Sprite2D = $Pickaxe
@onready var ufo: Sprite2D = $UFOWithPlayer
@onready var explosion: CPUParticles2D = $UFOWithPlayer/CPUParticles2D
@onready var player: Sprite2D = $Player
@onready var base_scale := ufo.scale

var started := false
var flying := false
var dropping := false
var player_velocity := Vector2.ZERO


func _ready() -> void:
	pickaxe.hide()


func _hovered() -> bool:
	return ufo.get_rect().has_point(ufo.get_local_mouse_position())


# _input, not _unhandled_input: the full-screen root Control eats clicks otherwise.
func _input(event: InputEvent) -> void:
	if not started and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _hovered():
		_start()


func _start() -> void:
	started = true
	# Start just off-screen in a random direction from the UFO.
	var dir := Vector2.from_angle(randf() * TAU)
	pickaxe.position = ufo.position + dir * get_viewport_rect().size.length()
	pickaxe.show()
	flying = true


func _explode() -> void:
	flying = false
	pickaxe.queue_free()
	$Explosion.play()
	# self_modulate hides the UFO but not its particle child.
	ufo.self_modulate.a = 0.0
	explosion.emitting = true
	player.position = ufo.position
	player.show()
	player_velocity = Vector2.from_angle(randf_range(-PI, 0.0)) * DRIFT_SPEED # float off upward-ish
	dropping = true
	get_tree().create_timer(DROP_TIME).timeout.connect(Fade.change_scene.bind(GAME_SCENE))


func _process(delta: float) -> void:
	var target := base_scale * (HOVER_SCALE if not started and _hovered() else 1.0)
	ufo.scale = ufo.scale.lerp(target, 1.0 - exp(-HOVER_SMOOTHING * delta))
	if flying:
		pickaxe.rotation += PICKAXE_SPIN * delta
		pickaxe.position = pickaxe.position.move_toward(ufo.position, PICKAXE_SPEED * delta)
		if pickaxe.position.distance_to(ufo.position) < HIT_RADIUS:
			_explode()
	if dropping:
		player_velocity.y += DROP_GRAVITY * delta
		player.position += player_velocity * delta
		player.rotation += DRIFT_SPIN * delta
