extends CharacterBody2D

const dead_spider_scene = preload("res://Prefabs/dead_spider.tscn")
const explosion_scene = preload("res://Prefabs/explosion.tscn")
var projectile_scene: PackedScene = preload("res://Projectiles/base_bullet.tscn")

@export var is_inverted := false
@export var shoot_interval := 2.0

var shoot_timer := 0.0
var leg_time := 0.0
var prev_rotation := 0.0

const LEG_SWING_AMPLITUDE := 0.25
const LEG_SWING_SPEED := 10.0

@onready var player: Node2D = $"../Player/CharacterBody2D"
@onready var head_projectile_marker = $HeadProjectileMarker
@onready var legs_left  = [$A1, $A2, $A3, $A4]
@onready var legs_right = [$B1, $B2, $B3, $B4]

func _ready():
	add_to_group("IntroSpider")
	_apply_invert()
	set_meta("IsTongueable", true)
	shoot_timer = shoot_interval

func _apply_invert():
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

	# Stay still — just face the player
	var dir_to_player = (player.global_position - global_position).normalized()
	rotation = lerp_angle(rotation, dir_to_player.angle() + deg_to_rad(-90), delta * 6.0)

	# Animate legs when turning, settle back to rest when still
	var rotation_delta = abs(angle_difference(rotation, prev_rotation))
	prev_rotation = rotation
	var is_turning = rotation_delta > 0.001
	leg_time += delta

	for i in range(legs_left.size()):
		if is_turning:
			var phase_a = sin(leg_time * LEG_SWING_SPEED)
			var phase_b = sin(leg_time * LEG_SWING_SPEED + PI)
			legs_left[i].rotation  = (phase_a if i % 2 == 0 else phase_b) * LEG_SWING_AMPLITUDE
			legs_right[i].rotation = (phase_b if i % 2 == 0 else phase_a) * LEG_SWING_AMPLITUDE
		else:
			legs_left[i].rotation  = lerp_angle(legs_left[i].rotation,  0.0, delta * 6.0)
			legs_right[i].rotation = lerp_angle(legs_right[i].rotation, 0.0, delta * 6.0)

	# Shoot at player on interval
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		_shoot_at_player()

func _shoot_at_player():
	if not projectile_scene or not player:
		return

	var dir = (player.global_position - global_position).normalized()
	var projectile = projectile_scene.instantiate()

	var sprite = projectile.get_node_or_null("Sprite2D")
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		sprite.material.set_shader_parameter("invert_colors", is_inverted)

	if is_inverted:
		projectile.set_collision_layer_value(2, false)
		projectile.set_collision_layer_value(3, true)
		projectile.set_collision_mask_value(2, true)
		projectile.set_collision_mask_value(3, false)
	else:
		projectile.set_collision_layer_value(2, true)
		projectile.set_collision_layer_value(3, false)
		projectile.set_collision_mask_value(2, false)
		projectile.set_collision_mask_value(3, true)

	get_tree().current_scene.add_child(projectile)
	projectile.global_position = head_projectile_marker.global_position
	if projectile.has_method("setup"):
		projectile.setup(head_projectile_marker.global_position, dir)

var was_eaten := false

func take_damage(_amount: int):
	die()

func die():
	var parent = get_parent()

	# Notify player for tutorial progression
	var player_node = get_node_or_null("../Player/CharacterBody2D")
	if player_node and player_node.has_method("on_intro_spider_killed"):
		player_node.on_intro_spider_killed()

	# Spawn corpse
	var corpse = dead_spider_scene.instantiate()
	corpse.is_inverted = is_inverted
	corpse.global_position = global_position
	corpse.global_rotation = global_rotation + deg_to_rad(180)
	parent.call_deferred("add_child", corpse)

	# Spawn explosion
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	explosion.global_rotation = global_rotation + deg_to_rad(180)
	var sprite = explosion.get_node_or_null("Sprite2D")
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		sprite.material.set_shader_parameter("invert_colors", is_inverted)
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

# The player tongue calls queue_free on hooked objects directly —
# we set this flag from the outside before that happens
func notify_eaten():
	pass  # Boss trigger is handled by the player's tongue system

func _trigger_boss_intro():
	pass
