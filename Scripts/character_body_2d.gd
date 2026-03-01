extends CharacterBody2D
const SPEED := 300.0
const STEP_FREQUENCY := 10.0
const STEP_ANGLE := 0.3
const MAX_HEAD_ROTATION = deg_to_rad(10)
var step_timer := 0.0

@onready var front_left_leg = $FrontLeftLeg
@onready var front_right_leg = $FrontRightLeg
@onready var back_left_leg = $BackLeftLeg
@onready var back_right_leg = $BackRightLeg
@onready var head = $Head
@onready var shoot_marker = $Head/Marker2D
@onready var particles = $Particles
@onready var tongue = $Head/Tongue
@onready var tongue_tip = $Head/TongueTip
@onready var tongue_cast = $Head/TongueCast
@onready var spit_sound = $Spit
@onready var tongue_out = $Tongue
@onready var tongue_back = $Tongue2
@onready var change1 = $Change1
@onready var change2 = $Change2
@onready var left_click = $"../../HUD/LeftClick"
@onready var right_click = $"../../HUD/RightClick"
@onready var space_bar = $"../../HUD/SpaceBar"
@onready var eat_visuals = $"../../EatVisuals/Tutorial"
@onready var ending_visuals = $"../../EatVisuals/Ending"

var player_bullet = preload("res://Projectiles/player_bullet.tscn")
var spit_scene = preload("res://Prefabs/Spit.tscn")
var shockwave_scene = preload("res://Prefabs/Shockwave.tscn")

# Tongue sprites
const TONGUE_SPRITE_A = preload("res://Sprites/Player/linguaA1.png")
const TONGUE_SPRITE_B = preload("res://Sprites/Player/linguaB1.png")
const TONGUE_TIP_SPRITE_A = preload("res://Sprites/Player/linguaA2.png")
const TONGUE_TIP_SPRITE_B = preload("res://Sprites/Player/linguaB2.png")

# Shoot effect textures
const SPIT_TEXTURE = preload("res://Sprites/Player/tiroguspe.png")
const SPIT_TEXTURE_INVERTED = preload("res://Sprites/Player/tiroguspe2.png")
const SHOCKWAVE_TEXTURE = preload("res://Sprites/Player/tiroshockwave.png")
const SHOCKWAVE_TEXTURE_INVERTED = preload("res://Sprites/Player/tiroshockwave2.png")

@export var is_inverted := false
@export var max_health: int = 4
var health: int
var is_on_invert_cooldown = false
var is_on_shoot_cooldown = false
const SHOOT_COOLDOWN = 0.3

# Tongue state
const TONGUE_MAX_DISTANCE := 180.0
const TONGUE_SPEED := 800.0
const TONGUE_RETRACT_SPEED := 1200.0
var tongue_active := false
var tongue_extending := false
var tongue_retracting := false
var tongue_current_scale := 0.0
var tongue_hooked_object: Node = null

# Web state
var is_web_trapped := false
var is_web_immune := false

# Iframe state
var is_invincible := false
var iframe_timer := 0.0
var iframe_duration := 2.0
var iframe_flash_interval := 0.1
var iframe_flash_timer := 0.0

# ---------------- Tutorial State ----------------
enum TutorialStep {
	LEFT_CLICK,        # waiting for player to shoot
	RIGHT_CLICK,       # waiting for player to invert
	LEFT_CLICK_AGAIN,  # waiting for player to kill the baby spider
	SPACE_BAR,         # waiting for player to eat the corpse
	DONE
}
var tutorial_step := TutorialStep.LEFT_CLICK
var tutorial_active := true

func _ready():
	health = max_health
	_init_tongue()
	_tutorial_setup()

func _tutorial_setup():
	# All nodes start with visible=false in editor — fade in left_click to begin
	_tutorial_fade_in(left_click)

func _tutorial_fade_in(node: Control):
	node.visible = true
	node.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(node, "modulate:a", 1.0, 0.4)

func _tutorial_fade_out(node: Control, then_show: Control = null):
	var t = create_tween()
	t.tween_property(node, "modulate:a", 0.0, 0.4)
	t.tween_callback(func(): node.visible = false)
	if then_show:
		t.tween_callback(func(): _tutorial_fade_in(then_show))

func _tutorial_advance(step: TutorialStep):
	if not tutorial_active:
		return
	tutorial_step = step
	match step:
		TutorialStep.RIGHT_CLICK:
			_tutorial_fade_out(left_click, right_click)
		TutorialStep.LEFT_CLICK_AGAIN:
			_tutorial_fade_out(right_click, left_click)
		TutorialStep.SPACE_BAR:
			_tutorial_fade_out(left_click, space_bar)
			_eat_visuals_show()
		TutorialStep.DONE:
			_tutorial_fade_out(space_bar)
			_eat_visuals_hide()
			tutorial_active = false

# Called by boss when intro starts — hides any visible tutorial prompts immediately
func hide_all_tutorial_prompts():
	tutorial_active = false
	tutorial_step = TutorialStep.DONE
	for node in [left_click, right_click, space_bar]:
		if node.visible:
			_tutorial_fade_out(node)
	if eat_visuals.visible:
		_eat_visuals_hide()

func _eat_visuals_show():
	eat_visuals.visible = true
	for child in eat_visuals.get_children():
		if child is Sprite2D:
			child.modulate.a = 0.0
			var t = create_tween()
			t.tween_property(child, "modulate:a", 1.0, 0.4)
	_eat_visuals_wobble()

func _eat_visuals_hide():
	for child in eat_visuals.get_children():
		if child is Sprite2D:
			var t = create_tween()
			t.tween_property(child, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(0.45).timeout
	eat_visuals.visible = false

func _eat_visuals_wobble():
	while tutorial_step == TutorialStep.SPACE_BAR and is_instance_valid(eat_visuals):
		for child in eat_visuals.get_children():
			if child is Sprite2D:
				var t = create_tween()
				t.tween_property(child, "position:x", child.position.x + 4.0, 0.35)
				t.tween_property(child, "position:x", child.position.x - 4.0, 0.35)
				t.tween_property(child, "position:x", child.position.x, 0.35)
		await get_tree().create_timer(1.05).timeout

# Called by boss death sequence to show ending eat visuals
var ending_parts_total := 0
var ending_parts_eaten := 0

func show_ending_visuals(part_count: int):
	ending_parts_total = part_count
	ending_parts_eaten = 0
	ending_visuals.visible = true
	for child in ending_visuals.get_children():
		if child is Sprite2D:
			child.modulate.a = 0.0
			var t = create_tween()
			t.tween_property(child, "modulate:a", 1.0, 0.5)
	_ending_visuals_shake()

func _ending_visuals_shake():
	while is_instance_valid(ending_visuals) and ending_visuals.visible:
		for child in ending_visuals.get_children():
			if child is Sprite2D:
				var t = create_tween()
				t.tween_property(child, "position:x", child.position.x + 10.0, 0.1)
				t.tween_property(child, "position:x", child.position.x - 10.0, 0.1)
				t.tween_property(child, "position:x", child.position.x + 6.0, 0.1)
				t.tween_property(child, "position:x", child.position.x, 0.1)
		await get_tree().create_timer(0.4).timeout

func on_ending_part_eaten():
	ending_parts_eaten += 1
	if ending_parts_eaten >= ending_parts_total:
		_go_to_credits()

func _go_to_credits():
	TransitionScreen.transition()
	await TransitionScreen.on_transition_finished
	var credits_scene = preload("res://Scenes/Credits.tscn").instantiate()
	get_tree().current_scene.queue_free()
	get_tree().root.add_child(credits_scene)
	get_tree().current_scene = credits_scene

# Called by intro_spider when it dies
func on_intro_spider_killed():
	if tutorial_step == TutorialStep.LEFT_CLICK_AGAIN:
		_tutorial_advance(TutorialStep.SPACE_BAR)

# Called from _end_tongue when player eats something
func on_player_ate():
	if tutorial_step == TutorialStep.SPACE_BAR:
		_tutorial_advance(TutorialStep.DONE)

func _physics_process(delta):
	if is_invincible:
		iframe_timer -= delta
		iframe_flash_timer -= delta
		var progress = clamp(iframe_timer / iframe_duration, 0.0, 1.0)
		iframe_flash_interval = lerp(0.3, 0.05, progress)
		if iframe_flash_timer <= 0.0:
			iframe_flash_timer = iframe_flash_interval
			visible = !visible
		if iframe_timer <= 0.0:
			is_invincible = false
			visible = true

	if Input.is_action_just_pressed("Invert") and not is_on_invert_cooldown:
		var mat = head.material
		var current = mat.get_shader_parameter("invert_colors")
		mat.set_shader_parameter("invert_colors", !current)
		is_inverted = !is_inverted
		set_collision_layer_value(2, !is_inverted)
		set_collision_layer_value(3, is_inverted)
		
		var randomNum = randi_range(1,2)
		if randomNum == 1:
			change1.play()
		else:
			change2.play()
		
		_update_tongue_sprites()
		playParticles()

		# Tutorial: right click used
		if tutorial_step == TutorialStep.RIGHT_CLICK:
			_tutorial_advance(TutorialStep.LEFT_CLICK_AGAIN)

	if Input.is_action_pressed("Shoot"):
		shoot()

	if Input.is_action_just_pressed("Eat") and not tongue_active:
		_start_tongue()

	if tongue_active:
		_process_tongue(delta)

	# Block movement while trapped but still allow rotation
	if is_web_trapped:
		velocity = Vector2.ZERO
		move_and_slide()

	if not is_web_trapped:
		var direction = Vector2.ZERO
		direction.x = Input.get_axis("Left", "Right")
		direction.y = Input.get_axis("Up", "Down")
		direction = direction.normalized()
		velocity = direction * SPEED
		move_and_slide()

	var target_angle = (get_global_mouse_position() - global_position).angle() + deg_to_rad(90)
	rotation = lerp_angle(rotation, target_angle, delta * 5.0)

	var head_target_global = (get_global_mouse_position() - head.global_position).angle() + deg_to_rad(90)
	var head_target_local = wrapf(head_target_global - rotation, -PI, PI)
	head_target_local = clamp(head_target_local, -MAX_HEAD_ROTATION, MAX_HEAD_ROTATION)
	head.rotation = lerp_angle(head.rotation, head_target_local, delta * 10.0)

	if velocity.length() > 0.1:
		step_timer += (delta * STEP_FREQUENCY) / 1.5
		front_left_leg.rotation = sin(step_timer) * STEP_ANGLE
		back_right_leg.rotation = sin(step_timer + PI) * STEP_ANGLE
		front_right_leg.rotation = sin(step_timer) * STEP_ANGLE
		back_left_leg.rotation = sin(step_timer + PI) * STEP_ANGLE

func apply_web():
	if is_web_immune:
		return
	is_web_trapped = true
	await get_tree().create_timer(2.0).timeout
	is_web_trapped = false
	is_web_immune = true
	await get_tree().create_timer(5.0).timeout
	is_web_immune = false

func playParticles():
	is_on_invert_cooldown = true
	particles.visible = true

	if is_inverted:
		particles.play("Inverted")
	else:
		particles.play("Base")

	await particles.animation_finished

	var tween = create_tween()
	tween.tween_property(particles, "scale:x", 1.85, 0.2)
	await tween.finished

	var fade_tween = create_tween()
	fade_tween.tween_property(particles, "modulate:a", 0.0, 0.3)
	await fade_tween.finished

	particles.scale.x = 1.0
	particles.modulate.a = 1.0
	particles.visible = false
	is_on_invert_cooldown = false

func shoot():
	if is_on_shoot_cooldown:
		return
		
	is_on_shoot_cooldown = true

	# Tutorial: first left click used
	if tutorial_step == TutorialStep.LEFT_CLICK:
		_tutorial_advance(TutorialStep.RIGHT_CLICK)
	
	spit_sound.pitch_scale = randf_range(0.9, 1.1)
	spit_sound.play()
	
	var projectile = player_bullet.instantiate()
	var sprite = projectile.get_node_or_null("Sprite2D")

	if sprite:
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
	var mouse_pos = get_global_mouse_position()
	var dir = (mouse_pos - global_position).normalized()
	projectile.global_rotation = dir.angle() + deg_to_rad(90)
	projectile.setup(shoot_marker.global_position, dir)

	# Spawn Spit and Shockwave — root nodes are Sprite2D directly
	for scene in [spit_scene, shockwave_scene]:
		var effect = scene.instantiate()

		var extra_timer = 0.0

		if scene == spit_scene:
			extra_timer = 0.2
			effect.texture = SPIT_TEXTURE_INVERTED if is_inverted else SPIT_TEXTURE
		else:
			effect.texture = SHOCKWAVE_TEXTURE_INVERTED if is_inverted else SHOCKWAVE_TEXTURE

		if effect.material:
			effect.material = effect.material.duplicate()
			effect.material.set_shader_parameter("invert_colors", is_inverted)
		get_tree().current_scene.add_child(effect)
		effect.global_position = shoot_marker.global_position
		effect.global_rotation = shoot_marker.global_rotation
		var tween = effect.create_tween()
		effect.modulate.a = 1.0
		tween.tween_property(effect, "modulate:a", 0.0, 0.6 + extra_timer)
		tween.tween_callback(effect.queue_free)
	
	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	
	is_on_shoot_cooldown = false

func _init_tongue():
	tongue.visible = false
	tongue_tip.visible = false
	tongue.scale.y = 0.0
	tongue_current_scale = 0.0
	tongue_cast.enabled = false
	tongue_cast.collide_with_areas = true
	tongue_cast.collide_with_bodies = false
	_update_tongue_sprites()
	_update_tongue_area_mask()

func _update_tongue_sprites():
	tongue.texture = TONGUE_SPRITE_B if is_inverted else TONGUE_SPRITE_A
	tongue_tip.texture = TONGUE_TIP_SPRITE_B if is_inverted else TONGUE_TIP_SPRITE_A
	_update_tongue_area_mask()

func _update_tongue_area_mask():
	var mask = 2 if is_inverted else 4
	tongue_cast.collision_mask = mask

func _start_tongue():
	tongue_out.pitch_scale = randf_range(0.9, 1.1)
	tongue_out.play()
	
	tongue_active = true
	tongue_extending = true
	tongue_retracting = false
	tongue_current_scale = 0.0
	tongue_hooked_object = null
	tongue.scale.y = 0.0
	tongue.visible = true
	tongue_tip.visible = true
	tongue_cast.enabled = true
	_update_tongue_sprites()

func _process_tongue(delta):
	var sprite_height = tongue.get_rect().size.y
	var max_scale = TONGUE_MAX_DISTANCE / sprite_height if sprite_height > 0 else 1.0

	if tongue_extending:
		tongue_current_scale += (TONGUE_SPEED / sprite_height) * delta if sprite_height > 0 else delta * 2.0
		tongue_current_scale = min(tongue_current_scale, max_scale)
		tongue.scale.y = tongue_current_scale
		tongue_tip.position.y = tongue.position.y - (tongue_current_scale * sprite_height)

		tongue_cast.target_position = Vector2(0, -(tongue_current_scale * sprite_height))
		tongue_cast.force_shapecast_update()

		if tongue_cast.is_colliding() and tongue_hooked_object == null:
			for i in range(tongue_cast.get_collision_count()):
				var collider = tongue_cast.get_collider(i)
				if collider and collider.has_meta("IsTongueable"):
					tongue_hooked_object = collider
					_begin_retract()
					return

		var tip_global = tongue_tip.global_position
		var space = get_world_2d().direct_space_state
		var ray = PhysicsRayQueryParameters2D.create(global_position, tip_global)
		ray.exclude = [self]
		ray.collision_mask = 8
		var ray_result = space.intersect_ray(ray)
		if ray_result or tongue_current_scale >= max_scale:
			_begin_retract()

	elif tongue_retracting:
		tongue_current_scale -= (TONGUE_RETRACT_SPEED / sprite_height) * delta if sprite_height > 0 else delta * 3.0
		tongue_current_scale = max(tongue_current_scale, 0.0)
		tongue.scale.y = tongue_current_scale
		tongue_tip.position.y = tongue.position.y - (tongue_current_scale * sprite_height)

		if tongue_hooked_object != null and is_instance_valid(tongue_hooked_object):
			tongue_hooked_object.global_position = tongue_tip.global_position

		if tongue_current_scale <= 0.0:
			_end_tongue()

func _fade_effect(effect: Node):
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(effect):
		return
	var tween = create_tween()
	tween.tween_property(effect, "self_modulate:a", 0.0, 0.15)
	await tween.finished
	if is_instance_valid(effect):
		effect.queue_free()

func _begin_retract():
	tongue_extending = false
	tongue_retracting = true

func _end_tongue():
	tongue_active = false
	tongue_extending = false
	tongue_retracting = false
	tongue.visible = false
	tongue_tip.visible = false
	tongue.scale.y = 0.0
	tongue_cast.enabled = false

	if tongue_hooked_object != null and is_instance_valid(tongue_hooked_object):
		tongue_back.pitch_scale = randf_range(0.9, 1.1)
		tongue_back.play()

		# Check if this is a dead boss part before freeing
		var is_ending_part = tongue_hooked_object.get_parent() == get_node_or_null("../../DeadSpiderParts")

		tongue_hooked_object.queue_free()
		health = min(health + 1, max_health)
		print("Ate dead spider! Health: ", health)

		if is_ending_part:
			on_ending_part_eaten()
		else:
			# Trigger boss intro on first eat (tutorial spider)
			var boss = get_tree().get_first_node_in_group("Boss")
			if boss and boss.has_method("start_intro"):
				boss.start_intro()
			# Tutorial: player ate something
			on_player_ate()
	tongue_hooked_object = null

func take_damage(amount: int):
	if is_invincible:
		return
	health -= amount
	print("Player took ", amount, " damage. Health: ", health)
	if health <= 0:
		die()
	else:
		_start_iframes()

func _start_iframes():
	is_invincible = true
	iframe_timer = iframe_duration
	iframe_flash_timer = 0.0

var alreadyGone = false

func die():
	print("Player died")
	
	if not alreadyGone:
		alreadyGone = true
		TransitionScreen.transition()
		await TransitionScreen.on_transition_finished

		var game_over_scene = preload("res://Scenes/death.tscn").instantiate()
		get_tree().current_scene.queue_free()
		get_tree().root.add_child(game_over_scene)
		get_tree().current_scene = game_over_scene
