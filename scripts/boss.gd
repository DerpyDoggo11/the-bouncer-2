extends Node2D
## Hidden until activate(), then hovers at a distance from the player and fires
## lasers that pass through walls. Each shot is telegraphed so it can be dodged.

enum Beam { NONE, WARN, FIRE }

const KEEP_DISTANCE := 120.0 # backs off if the player gets closer than this
const SPEED := 220.0
const BOB_HEIGHT := 3.0
const BOB_SPEED := 2.0
const FIRE_INTERVAL := 2.5
const WARN_TIME := 0.7
const BEAM_TIME := 0.15
const BEAM_LENGTH := 2000.0
const BEAM_WIDTH := 15.0
const PLAYER_RADIUS := 15.0
const KNOCKBACK := 700.0
const WARN_DASH := 3 # px between warning-line pixels

@onready var sprite: Sprite2D = $BossUfo

var player: RigidBody2D
var beam := Beam.NONE
var timer := FIRE_INTERVAL
var beam_from: Vector2
var beam_dir: Vector2
var hit := false
var age := 0.0


func _ready() -> void:
	add_to_group("boss")
	hide()
	set_physics_process(false)


func activate() -> void:
	player = get_tree().current_scene.get_node("Player")
	show()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	age += delta
	sprite.position.y = roundf(sin(age * BOB_SPEED) * BOB_HEIGHT)
	# Hold still while aiming/firing so the beam comes from the boss.
	if beam == Beam.NONE:
		# Stay KEEP_DISTANCE away, leaning above the player.
		var away := (player.global_position.direction_to(global_position) + Vector2.UP).normalized()
		global_position = global_position.move_toward(player.global_position + away * KEEP_DISTANCE, SPEED * delta)
	timer -= delta
	match beam:
		Beam.NONE:
			if timer <= 0.0:
				# Aim is locked now, so moving after the warning dodges it.
				beam = Beam.WARN
				timer = WARN_TIME
				beam_from = global_position
				beam_dir = beam_from.direction_to(player.global_position)
		Beam.WARN:
			if timer <= 0.0:
				beam = Beam.FIRE
				timer = BEAM_TIME
				hit = false
		Beam.FIRE:
			var closest := Geometry2D.get_closest_point_to_segment(player.global_position, beam_from, beam_from + beam_dir * BEAM_LENGTH)
			if not hit and closest.distance_to(player.global_position) < BEAM_WIDTH / 2.0 + PLAYER_RADIUS:
				hit = true
				player.freeze = false # e.g. stuck by a magnet
				player.linear_velocity += beam_dir * KNOCKBACK
			if timer <= 0.0:
				beam = Beam.NONE
				timer = FIRE_INTERVAL
	queue_redraw()


# Beam is drawn as whole-pixel squares stepped along the line, so it stays pixelated at any angle.
func _draw() -> void:
	if beam == Beam.NONE:
		return
	var warn := beam == Beam.WARN
	var size := 1.0 if warn else BEAM_WIDTH
	var color := Color(1, 0, 0, 0.5) if warn else Color(1, 0.3, 0.3)
	var step := WARN_DASH if warn else 1
	for d in range(0, int(BEAM_LENGTH), step):
		var p := (to_local(beam_from + beam_dir * d) - Vector2.ONE * size / 2.0).round()
		draw_rect(Rect2(p, Vector2.ONE * size), color)
