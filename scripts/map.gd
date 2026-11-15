extends Node2D
## Checkpoints and death areas.

const BOSS_CHECKPOINT := 3
const END_CHECKPOINT := 4
const END_SCENE := "res://scenes/endScreen.tscn"

@onready var player: RigidBody2D = get_parent().get_node("Player")
@onready var spawn_point := player.global_position
@onready var start_ticks := Time.get_ticks_msec()

var reached := 0 # highest checkpoint number entered


func _ready() -> void:
	var checkpoints := $Checkpoints.get_children()
	for i in checkpoints.size():
		checkpoints[i].body_entered.connect(_on_checkpoint.bind(i + 1, checkpoints[i]))
		_flag(i + 1).stop()
		_flag(i + 1).frame = 0 # off
	for area in $DeathAreas.get_children():
		area.body_entered.connect(_on_death)


func _on_checkpoint(body: Node2D, number: int, area: Area2D) -> void:
	if body != player or number <= reached:
		return
	reached = number
	spawn_point = area.get_node("CollisionShape2D").global_position # center of the box
	_flag(number).frame = 1 # on
	if number == BOSS_CHECKPOINT:
		get_tree().call_group("boss", "activate")
	elif number == END_CHECKPOINT:
		EndScreen.elapsed = (Time.get_ticks_msec() - start_ticks) / 1000.0
		Fade.change_scene(END_SCENE)


func _flag(number: int) -> AnimatedSprite2D:
	return get_node("Checkpoint %d" % number)


# ponytail: every death area sends you to the latest checkpoint, which in
# normal play is the one that death area belongs to.
func _on_death(body: Node2D) -> void:
	if body == player:
		player.respawn.call_deferred(spawn_point)
