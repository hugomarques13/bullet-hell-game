extends Area2D

signal beam_firing

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var warning_box = $WarningBox
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var blink_interval := 0.12
var blink_timer := 0.0
var blink_count := 0
var max_blinks := 8
var warning_phase := true
var warning_material: Material = null
var player: Node = null
var origin_marker: Node = null  # set by boss before add_child

func _ready():
	collision.disabled = true
	sprite.visible = false
	warning_box.visible = true

	if warning_box.material:
		warning_material = warning_box.material.duplicate()
		warning_box.material = warning_material

	sprite.animation_finished.connect(_on_sprite_animation_finished)

func _process(delta):
	if not warning_phase:
		return

	# Follow the marker position and rotation
	if origin_marker and is_instance_valid(origin_marker):
		global_position = origin_marker.global_position
		global_rotation = origin_marker.get_parent().global_rotation

	blink_timer += delta
	if blink_timer >= blink_interval:
		blink_timer = 0.0
		blink_count += 1
		var current = warning_material.get_shader_parameter("invert_colors")
		warning_material.set_shader_parameter("invert_colors", !current)

		if blink_count >= max_blinks:
			_start_beam()

func _start_beam():
	warning_phase = false
	emit_signal("beam_firing")
	warning_box.visible = false
	sprite.visible = true
	sprite.play("default")

func _on_sprite_animation_finished():
	collision.disabled = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(1.0).timeout
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()

func _on_body_entered(body: Node):
	if body.has_method("take_damage"):
		body.take_damage(1)

func _on_area_entered(area: Node):
	if area.has_method("take_damage"):
		area.take_damage(1)
