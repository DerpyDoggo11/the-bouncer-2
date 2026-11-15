extends CanvasLayer
## Autoload: fades to black, swaps the scene, fades back in.

const DURATION := 0.5

var rect := ColorRect.new()


func _ready() -> void:
	layer = 100 # above everything
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


func change_scene(path: String) -> void:
	rect.mouse_filter = Control.MOUSE_FILTER_STOP # block clicks mid-fade
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, DURATION)
	await tween.finished
	get_tree().change_scene_to_file(path)
	tween = create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, DURATION)
	await tween.finished
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
