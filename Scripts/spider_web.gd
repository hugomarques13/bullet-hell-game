extends Area2D

# ---------------- Configuration ----------------
var arc_height := 150.0
var travel_duration := 0.6

var target_pos := Vector2.ZERO
var start_pos := Vector2.ZERO
var is_inverted := false

var travel_timer := 0.0
var is_traveling := true
var has_landed := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionPolygon2D = $CollisionPolygon2D

# ---------------- Godot Callbacks ----------------
func _ready():
	collision.disabled = true
	_apply_invert()
	sprite.play("default")

func _process(delta):
	if not is_traveling:
		return

	travel_timer += delta
	var t = clamp(travel_timer / travel_duration, 0.0, 1.0)

	# Arc using quadratic bezier — control point is midpoint lifted by arc_height
	var mid = start_pos.lerp(target_pos, 0.5) + Vector2.UP * arc_height
	var a = start_pos.lerp(mid, t)
	var b = mid.lerp(target_pos, t)
	global_position = a.lerp(b, t)

	# Play the default anim while traveling
	if is_traveling and travel_timer < travel_duration:
		if not sprite.is_playing():
			sprite.play("default")

	if t >= 1.0:
		_on_landed()

func _on_landed():
	is_traveling = false
	global_position = target_pos
	rotation = deg_to_rad(randf_range(-15.0, 15.0))
	sprite.play("landed")
	sprite.animation_finished.connect(_on_landed_animation_finished)
	get_tree().create_timer(15.0).timeout.connect(queue_free)

func _on_landed_animation_finished():
	if sprite.animation == "landed":
		collision.disabled = false
		# Connect player collision — only fire once
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if body.has_method("apply_web"):
		body.apply_web()

func _apply_invert():
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		sprite.material.set_shader_parameter("invert_colors", is_inverted)

	if is_inverted:
		set_collision_layer_value(2, false)
		set_collision_layer_value(3, true)
		set_collision_mask_value(2, true)
		set_collision_mask_value(3, false)
	else:
		set_collision_layer_value(2, true)
		set_collision_layer_value(3, false)
		set_collision_mask_value(2, false)
		set_collision_mask_value(3, true)
