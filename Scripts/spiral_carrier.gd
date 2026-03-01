extends Area2D
# ---------------- Configuration ----------------
@export var travel_speed := 400.0
@export var sweep_speed := 120.0
@export var spiral_shoot_interval := 0.08
@export var spiral_arms := 3
var is_inverted := false
var arena_left_x := -999.0
var arena_right_x := 999.0
var arena_top_y := -999.0
var arena_bottom_y := 999.0
# Set by boss before add_child
var corner_pos := Vector2.ZERO
var projectile_scene: PackedScene = preload("res://Projectiles/base_bullet.tscn")
var spiral_angle := 0.0
var shoot_timer := 0.0
var spiral_rotation_speed := 6.0
# Phase state
var phase := "traveling"
var sweep_direction := 1.0
var sweep_target_x := 0.0
var is_cleared := false  # set to true by boss death — stops all shooting immediately
# ---------------- Godot Callbacks ----------------
func _ready():
	add_to_group("Projectile")  # so boss death sweep catches the carrier itself
	var sprite = get_node_or_null("Sprite2D")
	if sprite and sprite.material:
		sprite.material = sprite.material.duplicate()
		sprite.material.set_shader_parameter("invert_colors", is_inverted)
func _process(delta):
	if is_cleared:
		return
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.rotation = spiral_angle
	if phase == "traveling":
		_process_travel(delta)
	elif phase == "sweeping":
		_process_sweep(delta)
func _process_travel(delta):
	var dir = (corner_pos - global_position).normalized()
	global_position += dir * travel_speed * delta
	if global_position.distance_to(corner_pos) < 5.0:
		global_position = corner_pos
		# Determine sweep direction based on which horizontal side we arrived at
		var mid_x = (arena_left_x + arena_right_x) / 2.0
		if corner_pos.x < mid_x:
			# Arrived at left side, sweep right
			sweep_direction = 1.0
			sweep_target_x = arena_right_x + 50.0
		else:
			# Arrived at right side, sweep left
			sweep_direction = -1.0
			sweep_target_x = arena_left_x - 50.0
		phase = "sweeping"
func _process_sweep(delta):
	global_position.x += sweep_direction * sweep_speed * delta
	shoot_timer += delta
	spiral_angle += spiral_rotation_speed * delta
	if shoot_timer >= spiral_shoot_interval:
		shoot_timer = 0.0
		_shoot_spiral()
	var past_edge = (
		(sweep_direction > 0 and global_position.x > sweep_target_x) or
		(sweep_direction < 0 and global_position.x < sweep_target_x)
	)
	if past_edge:
		queue_free()
func _shoot_spiral():
	for i in range(spiral_arms):
		var angle = spiral_angle + (TAU / spiral_arms) * i
		var dir = Vector2.from_angle(angle)
		var projectile = projectile_scene.instantiate()
		_apply_projectile_logic(projectile)
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = global_position
		if projectile.has_method("setup"):
			projectile.setup(global_position, dir)
func _apply_projectile_logic(projectile: Node):
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
