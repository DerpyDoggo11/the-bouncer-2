extends RigidBody2D

const LAUNCH_POWER := 6.5
const MAX_PULL := 60.0
const GRAB_RADIUS := 16.0
const SLOW_MO := 0.2
const DOT_COUNT := 20
const DOT_STEP := 0.05 # seconds of flight between dots
const DOT_SIZE := 2.0
const TURN_SPEED := 6.0 # radians per second from A/D or arrow keys
const TURN_RESPONSE := 10.0 # how quickly spin reaches TURN_SPEED
const ZOOM_OUT_SPEED := 600.0 # speed (px/s) at which zoom halves
const MIN_ZOOM_FACTOR := 0.4
const ZOOM_SMOOTHING := 3.0
const LOOK_AHEAD := 0.08 # seconds of velocity the camera leads by

@onready var camera: Camera2D = $Camera2D
@onready var base_zoom := camera.zoom
@onready var body_radius: float = ($CollisionShape2D.shape as CircleShape2D).radius

var dragging := false
var dots := Node2D.new()
var dot_points: PackedVector2Array = []

var inventory: Array[Item] = []
var equipped: Array[Item] = []
var held_shapes := {} # Item -> Array of its shapes, copied onto the player
var base_bounce: float
var base_friction: float


func _ready() -> void:
	# Own copy so changing bounce doesn't touch the shared resource.
	physics_material_override = physics_material_override.duplicate()
	base_bounce = physics_material_override.bounce
	base_friction = physics_material_override.friction
	# Auto mode recomputes center of mass from all shapes, so a held item would
	# drag it off-center and make the ball tip and roll on its own.
	center_of_mass_mode = CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector2.ZERO
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)
	# Drawn in global space so the dots don't spin with the ball.
	dots.top_level = true
	dots.draw.connect(_draw_dots)
	add_child(dots)


func _process(delta: float) -> void:
	Engine.time_scale = SLOW_MO if Input.is_key_pressed(KEY_SPACE) else 1.0
	var speed := linear_velocity.length()
	var target_zoom := base_zoom * maxf(MIN_ZOOM_FACTOR, 1.0 / (1.0 + speed / ZOOM_OUT_SPEED))
	var weight := 1.0 - exp(-ZOOM_SMOOTHING * delta)
	camera.zoom = camera.zoom.lerp(target_zoom, weight)
	camera.offset = camera.offset.lerp(linear_velocity * LOOK_AHEAD, weight)
	dots.queue_redraw()


func _physics_process(delta: float) -> void:
	var turn := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) \
			- float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if turn != 0.0:
		angular_velocity = lerpf(angular_velocity, turn * TURN_SPEED, 1.0 - exp(-TURN_RESPONSE * delta))
	for item in equipped:
		item.held_physics(self, delta)
	_update_material()
	_update_dots()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# physical_keycode so the number row works on any keyboard layout.
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			_toggle_equip(event.physical_keycode - KEY_1)
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
			_toggle_equip(event.keycode - KEY_KP_1)
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed and get_global_mouse_position().distance_to(global_position) < GRAB_RADIUS:
		dragging = true
	elif not event.pressed and dragging:
		dragging = false
		freeze = false # e.g. stuck by a magnet
		linear_velocity = _launch_velocity()


func _launch_velocity() -> Vector2:
	return (global_position - get_global_mouse_position()).limit_length(MAX_PULL) * LAUNCH_POWER


func _on_body_entered(body: Node) -> void:
	if body is Item:
		# Physics state can't change mid-callback.
		_pick_up.call_deferred(body)


func _pick_up(item: Item) -> void:
	if item in inventory:
		return
	item.saved_layer = item.collision_layer
	item.saved_mask = item.collision_mask
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	item.top_level = true
	item.reparent(self)
	item.hide()
	inventory.append(item)


# Number keys 1-9 equip that inventory slot; pressing it again unequips it.
# Any number of items can be equipped at once.
func _toggle_equip(slot: int) -> void:
	if slot >= inventory.size():
		return
	var item := inventory[slot]
	if item in equipped:
		for shape in held_shapes[item]:
			shape.queue_free()
		held_shapes.erase(item)
		equipped.erase(item)
		item.hide()
		freeze = false # e.g. stuck by a magnet
		return
	# Refuse if an equipped item already sits in that direction.
	for other in equipped:
		if (other.global_position - global_position).normalized().dot(item.hold_offset.normalized()) > 0.9:
			return
	# Attach at hold_offset in world space, whichever way the ball is spun.
	# From then on it's rigidly part of the player and turns with it.
	var hold := Transform2D(deg_to_rad(item.hold_rotation_degrees), global_position + item.hold_offset)
	var local_hold := global_transform.affine_inverse() * hold
	item.top_level = false
	item.transform = local_hold
	item.reset_physics_interpolation()
	item.show()
	# The item's own body stays frozen with collisions off; the player carries copies of its shapes.
	var copies: Array[Node2D] = []
	for shape in item.get_children():
		if item.collides_when_held and (shape is CollisionShape2D or shape is CollisionPolygon2D):
			var copy: Node2D = shape.duplicate()
			copy.transform = local_hold * shape.transform
			add_child(copy)
			copies.append(copy)
	held_shapes[item] = copies
	equipped.append(item)


# The lowest equipped item underneath is the one touching the ground, so it sets bounce/friction.
func _update_material() -> void:
	var bottom: Item
	var bottom_dist := 0.0
	for item in equipped:
		var to_item := item.global_position - global_position
		if to_item.normalized().dot(Vector2.DOWN) > 0.7 and to_item.length() > bottom_dist:
			bottom = item
			bottom_dist = to_item.length()
	var bounce := bottom.bounce_when_below if bottom else -1.0
	var friction := bottom.friction_when_below if bottom else -1.0
	physics_material_override.bounce = bounce if bounce >= 0.0 else base_bounce
	physics_material_override.friction = friction if friction >= 0.0 else base_friction


# ponytail: ballistic arc, ignores damping; stops at the first collider it crosses.
func _update_dots() -> void:
	dot_points.clear()
	if not dragging:
		return
	var space := get_world_2d().direct_space_state
	var v := _launch_velocity()
	var g: Vector2 = get_gravity() * gravity_scale
	var prev := global_position
	for i in DOT_COUNT:
		var t := (i + 1) * DOT_STEP
		var p := global_position + v * t + 0.5 * g * t * t
		var query := PhysicsRayQueryParameters2D.create(prev, p, collision_mask, [get_rid()])
		if space.intersect_ray(query):
			break
		dot_points.append(p)
		prev = p


func _draw_dots() -> void:
	for i in dot_points.size():
		if dot_points[i].distance_to(global_position) < body_radius:
			continue
		var size := roundf(lerpf(DOT_SIZE, DOT_SIZE * 0.5, float(i) / DOT_COUNT))
		dots.draw_rect(Rect2(dot_points[i].round() - Vector2.ONE * size / 2, Vector2.ONE * size), Color.WHITE)
