extends CharacterBody2D
const SPEED := 180.0
const LEG_STEP_FREQUENCY := 14.0
const LEG_STEP_HEIGHT := 4.0
const LEG_STEP_LENGTH := 10.0
const EXPLOSION_RANGE := 55.0
const MAX_HEALTH := 2
const dead_spider_scene = preload("res://Prefabs/dead_spider.tscn")
const explosion_scene = preload("res://Prefabs/explosion.tscn")
var health := MAX_HEALTH
var is_inverted := false
var leg_timer := 0.0

@onready var player := $"../Player/CharacterBody2D"
@onready var legs_left = [
	$A1,
	$A2,
	$A3,
	$A4
]
@onready var legs_right = [
	$B1,
	$B2,
	$B3,
	$B4
]
var leg_phases = [
	0.0,
	PI * 0.5,
	PI,
	PI * 1.5
]

func _ready():
	_apply_invert()

func _apply_invert():
	# Duplicate the material once and share it across all sprites that use it
	var shared_material: Material = null
	for child in find_children("*", "Sprite2D", true, false) + find_children("*", "AnimatedSprite2D", true, false):
		if child.material:
			if shared_material == null:
				shared_material = child.material.duplicate()
				shared_material.set_shader_parameter("invert_colors", is_inverted)
			child.material = shared_material

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

func _physics_process(delta):
	if not player or not is_instance_valid(player):
		return
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * SPEED
	move_and_slide()

	rotation = lerp_angle(rotation, direction.angle() + deg_to_rad(-90), delta * 6.0)

	if velocity.length() > 0.1:
		leg_timer += delta * LEG_STEP_FREQUENCY
		for i in range(4):
			var phase = leg_phases[i]
			var left_leg = legs_left[i]
			var right_leg = legs_right[i]
			var is_tripod_a = i % 2 == 0
			var base_phase = leg_timer + phase
			if not is_tripod_a:
				base_phase += PI
			var step = sin(base_phase)
			var leg_order_factor = 1.0 - (i * 0.2)
			var forward_motion = step * LEG_STEP_LENGTH * 0.6 * leg_order_factor
			var lift = abs(cos(base_phase)) * LEG_STEP_HEIGHT
			left_leg.rotation = step * 0.45
			left_leg.position.x = forward_motion
			left_leg.position.y = lift
			var step_right = sin(base_phase + PI)
			right_leg.rotation = step_right * 0.45
			right_leg.position.x = step_right * LEG_STEP_LENGTH * 0.6 * leg_order_factor
			right_leg.position.y = abs(cos(base_phase + PI)) * LEG_STEP_HEIGHT
	else:
		leg_timer = 0
		for i in range(4):
			legs_left[i].rotation = lerp_angle(legs_left[i].rotation, 0.0, delta * 6.0)
			legs_right[i].rotation = lerp_angle(legs_right[i].rotation, 0.0, delta * 6.0)
			legs_left[i].position = legs_left[i].position.lerp(Vector2.ZERO, delta * 6.0)
			legs_right[i].position = legs_right[i].position.lerp(Vector2.ZERO, delta * 6.0)

	if global_position.distance_to(player.global_position) < EXPLOSION_RANGE:
		explode()

func explode():
	var parent = get_parent()

	# Spawn corpse with matching rotation
	var corpse = dead_spider_scene.instantiate()
	corpse.is_inverted = is_inverted
	corpse.global_position = global_position
	corpse.global_rotation = global_rotation + deg_to_rad(180)
	parent.call_deferred("add_child", corpse)

	# Spawn explosion
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	explosion.global_rotation = global_rotation + deg_to_rad(180)

	# Apply invert shader to explosion sprite
	var sprite = explosion.get_node_or_null("Sprite2D")
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		sprite.material.set_shader_parameter("invert_colors", is_inverted)

	# Set collision layers — explosion hits the opposite team
	if is_inverted:
		explosion.set_collision_layer_value(2, false)
		explosion.set_collision_layer_value(3, true)
		explosion.set_collision_mask_value(2, true)
		explosion.set_collision_mask_value(3, false)
	else:
		explosion.set_collision_layer_value(2, true)
		explosion.set_collision_layer_value(3, false)
		explosion.set_collision_mask_value(2, false)
		explosion.set_collision_mask_value(3, true)

	parent.call_deferred("add_child", explosion)

	queue_free()

func take_damage(amount: int):
	health -= amount
	if health <= 0:
		die()

func die():
	explode()
