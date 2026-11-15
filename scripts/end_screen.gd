class_name EndScreen
extends Control

const EXPLODE_DELAY := 1.0

static var elapsed := 0.0 # seconds, set by the map when the flag is reached

@onready var boss: Sprite2D = $BossUfoPng
@onready var time_label: Label = $TimeLabel


func _ready() -> void:
	time_label.modulate.a = 0.0
	await get_tree().create_timer(EXPLODE_DELAY).timeout
	# self_modulate hides the boss but not its particle child.
	boss.self_modulate.a = 0.0
	$BossUfoPng/CPUParticles2D.emitting = true
	$Explosion.play()
	time_label.text = "Time: %d:%05.2f" % [int(elapsed) / 60, fmod(elapsed, 60.0)]
	create_tween().tween_property(time_label, "modulate:a", 1.0, 0.5)
