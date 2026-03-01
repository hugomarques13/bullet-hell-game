extends CharacterBody2D

# ---------------- Exported Variables ----------------
@export var max_health: int = 400
@export var is_inverted := true
@export var circle_projectile_count := 40
@export var circle_projectile_radius := 5.0
@export var leg_swing_amplitude := deg_to_rad(15)
@export var leg_swing_speed := 10.0
@export var max_speed := 200.0
@export var wall_bullet_spacing := 40.0

# ---------------- Packed Scenes ----------------
var boss_explosion_scene: PackedScene = preload("res://Prefabs/boss_explosion.tscn")

const MUSIC_BOSS1 = preload("res://Sounds/boss1.mp3")
const MUSIC_BOSS2 = preload("res://Sounds/boss2.mp3")
const MUSIC_BOSSDEATH = preload("res://Sounds/bossdeath.mp3")

var projectile_scene: PackedScene = preload("res://Projectiles/base_bullet.tscn")
var growing_ball_scene: PackedScene = preload("res://Prefabs/growing_ball.tscn")
var medium_bullet_scene: PackedScene = preload("res://Projectiles/medium_bullet.tscn")
var egg_scene: PackedScene = preload("res://Prefabs/egg.tscn")
var spiral_carrier_scene: PackedScene = preload("res://Prefabs/spiral_carrier.tscn")
var spider_web_scene: PackedScene = preload("res://Prefabs/spider_web.tscn")
var beam_scene: PackedScene = preload("res://Projectiles/beam.tscn")


# ---------------- Runtime Variables ----------------
var health: int
var attack_timer := 0.0
var current_attack_index := 0

# Spin attack state
var is_spinning_attack := false
var spin_attack_duration := 2.0
var spin_attack_timer := 0.0
var spin_shoot_interval := 0.03
var spin_shoot_timer := 0.0
var spin_start_rotation := 0.0
var spin_recovering := false
var spin_spins_remaining := 0
var spin_clockwise := true

# Circle attack state
var circle_wave_count := 0
var circle_waves_total := 0
var circle_waiting_for_ball := false

# Charge wall attack state
var charge_attack_active := false
var charge_anticipating := false
var charge_anticipate_timer := 0.0
var charge_anticipate_duration := 0.3
var charge_turning := false
var charge_target_rotation := 0.0
var charge_direction := Vector2.DOWN
var charge_bullet = null
var charge_arena_boundary_y := 0.0
var charge_phase := 0
var charge_first_direction := Vector2.DOWN

# Web attack state
var web_attack_active := false
var web_recovering := false
var web_time := 0.0
var web_base_rotations = {}

# Spiral attack state
var spiral_attack_active := false
var spiral_turning := false
var spiral_target_rotation := 0.0
var spiral_direction := Vector2.UP
var spiral_target_corner := 0
var spiral_shots_remaining := 0

# Egg attack state
var egg_attack_active := false
var egg_targets: Array = []
var egg_current_index := 0
var egg_turning := false
var egg_target_rotation := 0.0
var egg_bullet = null
var egg_target_pos := Vector2.ZERO
var egg_arrival_threshold := 20.0

# Beam attack state
var beam_attack_active := false
var beam_turning := false
var beam_target_rotation := 0.0
var beam_tracking := false
var beam_shots_remaining := 0
var beam_anticipate_duration_base := 0.3

# Web shot attack state
var web_attack_active_shot := false
var web_shot_turning := false
var web_shot_target_rotation := 0.0
var web_shot_target_pos := Vector2.ZERO
var web_shot_targets: Array = []
var web_shot_current_index := 0

# Intro / walk-in state
var is_dormant := true
var is_walking_in := false
var is_dying := false

# Music state
var music_phase := 0

# Leg system
var leg_groups = {
	"A": ["A1", "A2", "A3", "A4"],
	"B": ["B1", "B2", "B3", "B4"]
}
var leg_rest_rotations = {}
var leg_time = 0.0

# ---------------- Node References ----------------
@onready var player: Node2D = $"../Player/CharacterBody2D"
@onready var head_projectile_marker = $HeadProjectileMarker
@onready var head_ball_marker = $HeadBallMarker

@onready var arena_markers = $"../ArenaMarkers"
@onready var arena_top = arena_markers.get_node("Top")
@onready var arena_bottom = arena_markers.get_node("Bottom")
@onready var arena_left = arena_markers.get_node("Left")
@onready var arena_right = arena_markers.get_node("Right")
@onready var egg_spawns = arena_markers.get_node("EggSpawns")
@onready var web_spawns = arena_markers.get_node("WebSpawns")
@onready var spiral_spots = arena_markers.get_node("SpiralSpots")
@onready var color_particles = $Particles
@onready var music: AudioStreamPlayer = $"../AudioStreamPlayer"
@onready var music_b: AudioStreamPlayer = $"../AudioStreamPlayerB"
@onready var background_to_invert = $"../Background/ToInvert"
@onready var hud = $"../HUD"
@onready var dead_spider_parts = $"../DeadSpiderParts"
@onready var spider_aggro = $SpiderAggro

# ---------------- Godot Callbacks ----------------
func _ready():
	health = max_health
	_cache_leg_rest_rotations()
	_cache_web_leg_positions()
	randomize()
	add_to_group("Boss")
	visible = false
	set_physics_process(false)
	_crossfade_music(MUSIC_BOSS1, true)

const MUSIC_VOLUME_QUIET := -35.0
const MUSIC_VOLUME_FIGHT := -25.0

var _music_active: AudioStreamPlayer = null

func start_intro():
	if is_dormant == false:
		return
	visible = true
	is_dormant = false
	is_walking_in = true
	set_physics_process(true)
	var t = create_tween()
	t.tween_property(_music_active, "volume_db", MUSIC_VOLUME_FIGHT, 1.2)
	background_to_invert.material.set_shader_parameter("invert_colors", true)

	spider_aggro.play()

	# Hide tutorial prompts now and again after a short delay (in case something was mid-tween)
	if player and player.has_method("hide_all_tutorial_prompts"):
		player.hide_all_tutorial_prompts()
	get_tree().create_timer(0.6).timeout.connect(func():
		if player and player.has_method("hide_all_tutorial_prompts"):
			player.hide_all_tutorial_prompts()
	)

	hud.play_boss_bar_intro()

func _crossfade_music(new_stream: AudioStream, fade_in_only := false):
	if not music or not music_b:
		return

	var fade_duration := 1.2

	if fade_in_only:
		music.stream = new_stream
		music.volume_db = -80.0
		music.play()
		_music_active = music
		var t = create_tween()
		t.tween_property(music, "volume_db", MUSIC_VOLUME_QUIET, fade_duration)
	else:
		var outgoing: AudioStreamPlayer = _music_active
		var incoming: AudioStreamPlayer = music_b if _music_active == music else music

		incoming.stream = new_stream
		incoming.volume_db = -80.0
		incoming.play()
		_music_active = incoming

		var t_in = create_tween()
		t_in.tween_property(incoming, "volume_db", MUSIC_VOLUME_FIGHT, fade_duration)

		var t_out = create_tween()
		t_out.tween_property(outgoing, "volume_db", -80.0, fade_duration)
		t_out.tween_callback(outgoing.stop)

func _walk_to_center(delta):
	var arena_center = Vector2(
		(arena_left.global_position.x + arena_right.global_position.x) / 2.0,
		(arena_top.global_position.y + arena_bottom.global_position.y) / 2.0
	)
	var dir = (arena_center - global_position).normalized()
	var walk_speed = 280.0
	velocity = dir * walk_speed
	move_and_slide()

	rotation = lerp_angle(rotation, dir.angle() + deg_to_rad(-90), delta * 6.0)

	leg_time += delta * 12.0
	for leg_name in leg_rest_rotations.keys():
		var leg = get_node_or_null(leg_name)
		if not leg:
			continue
		var base_rot = leg_rest_rotations[leg_name]
		var phase_offset = 0.0 if leg_name in leg_groups["A"] else PI
		leg.rotation = base_rot + sin(leg_time + phase_offset) * leg_swing_amplitude * 1.6

	_update_web_motion(delta)

	if global_position.distance_to(arena_center) < 8.0:
		global_position = arena_center
		velocity = Vector2.ZERO
		is_walking_in = false
		for leg_name in leg_rest_rotations.keys():
			var leg = get_node_or_null(leg_name)
			if leg:
				leg.rotation = leg_rest_rotations[leg_name]
		attack_timer = 1.5

func _physics_process(delta):
	if not player:
		return

	if is_walking_in:
		_walk_to_center(delta)
		return

	if is_dying:
		return

	if not _is_any_attack_active():
		attack_timer -= delta
		if attack_timer <= 0:
			execute_attack()

	if is_spinning_attack:
		process_spin_attack(delta)
	elif charge_attack_active:
		_process_charge_attack(delta)
	elif egg_attack_active:
		_process_egg_attack(delta)
	elif spiral_attack_active:
		_process_spiral_attack(delta)
	elif web_attack_active_shot:
		_process_web_shot(delta)
	elif beam_attack_active:
		_process_beam_attack(delta)

	_update_leg_animation(delta)
	_update_web_motion(delta)

# ---------------- Attack System ----------------
var attack_history: Array = []

func _is_any_attack_active() -> bool:
	return is_spinning_attack or charge_attack_active or egg_attack_active \
		or spiral_attack_active or web_attack_active_shot or beam_attack_active

func get_hp_percent() -> float:
	return float(health) / float(max_health) * 100.0

func get_cooldown_multiplier() -> float:
	var tiers_below = floor((100.0 - get_hp_percent()) / 10.0)
	return clamp(1.0 - tiers_below * 0.1, 0.3, 1.0)

func _get_turn_speed() -> float:
	var t = 1.0 - (get_hp_percent() / 100.0)
	return lerp(3.0, 10.0, t)

func get_attacks() -> Array:
	var hp_percent = get_hp_percent()
	var m = get_cooldown_multiplier()

	var all_attacks = [
		{
			"func": attack_spin_shoot,
			"cooldown": 1.5 * m,
			"unlock_hp": 100.0
		},
		{
			"func": attack_circle_shoot,
			"cooldown": 2.0 * m,
			"unlock_hp": 100.0
		},
		{
			"func": attack_egg_shoot,
			"cooldown": 2.5 * m,
			"unlock_hp": 100.0
		},
		{
			"func": attack_shoot_web,
			"cooldown": 0.3 * m,
			"unlock_hp": 100.0
		},
		{
			"func": attack_wall_from_top,
			"cooldown": 2.0 * m,
			"unlock_hp": 85.0
		},
		{
			"func": attack_spiral,
			"cooldown": 2.5 * m,
			"unlock_hp": 65.0
		},
		{
			"func": attack_beam,
			"cooldown": 2.5 * m,
			"unlock_hp": 50.0
		},
	]

	var available = []
	for attack in all_attacks:
		if hp_percent <= attack["unlock_hp"]:
			available.append(attack)
	return available

func execute_attack():
	var attacks = get_attacks()
	if attacks.is_empty():
		return

	var available_indices := []
	for i in range(attacks.size()):
		if not (i in attack_history):
			available_indices.append(i)

	if available_indices.is_empty():
		attack_history.clear()
		for i in range(attacks.size()):
			available_indices.append(i)

	var chosen_index = available_indices[randi() % available_indices.size()]
	var attack_data = attacks[chosen_index]

	attack_data["func"].call()
	attack_timer = attack_data["cooldown"]

	attack_history.append(chosen_index)
	if attack_history.size() > 2:
		attack_history.pop_front()

	_try_color_switch()

# ---------------- Color Switch ----------------
func _get_color_switch_chance() -> float:
	var hp = get_hp_percent()
	if hp <= 25.0:
		return 1.0
	elif hp <= 50.0:
		return 0.75
	elif hp <= 75.0:
		return 0.50
	else:
		return 0.25

func _try_color_switch():
	if get_hp_percent() > 75.0:
		return
	if randf() >= _get_color_switch_chance():
		return
	_apply_color_switch()

func _apply_color_switch():
	is_inverted = not is_inverted

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

	var body = get_node_or_null("Body")
	if body and body.material:
		body.material.set_shader_parameter("invert_colors", is_inverted)
		
	background_to_invert.material.set_shader_parameter("invert_colors", is_inverted)

	_play_switch_particles()

func _play_switch_particles():
	if not color_particles:
		return

	color_particles.visible = true

	if is_inverted:
		color_particles.play("Inverted")
	else:
		color_particles.play("Base")

	await color_particles.animation_finished

	var tween = create_tween()
	tween.tween_property(color_particles, "scale:x", 1.85, 0.2)
	await tween.finished

	var fade_tween = create_tween()
	fade_tween.tween_property(color_particles, "modulate:a", 0.0, 0.3)
	await fade_tween.finished

	color_particles.scale.x = 1.0
	color_particles.modulate.a = 1.0
	color_particles.visible = false

# ---------------- Projectile Helpers ----------------
func apply_projectile_logic(projectile: Node):
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

func spawn_projectile_circle_from_marker(center_pos: Vector2):
	for i in range(circle_projectile_count):
		var angle = TAU * i / circle_projectile_count
		var dir = Vector2.from_angle(angle)
		var projectile = projectile_scene.instantiate()
		apply_projectile_logic(projectile)
		get_tree().current_scene.add_child(projectile)
		projectile.global_position = center_pos + dir * circle_projectile_radius
		if projectile.has_method("setup"):
			projectile.setup(center_pos, dir)

# ---------------- Standard Attacks ----------------
func attack_shoot_single():
	if not player or not projectile_scene:
		return
	
	var dir_to_player = (player.global_position - global_position).normalized()
	rotation = dir_to_player.angle() + deg_to_rad(-90)
	
	var projectile = projectile_scene.instantiate()
	apply_projectile_logic(projectile)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = head_projectile_marker.global_position
	
	if projectile.has_method("setup"):
		projectile.setup(head_projectile_marker.global_position, dir_to_player)

# ---------------- Spin Attack ----------------
func _get_spin_count() -> int:
	var hp = get_hp_percent()
	if hp <= 20.0:
		return 3
	elif hp <= 60.0:
		return 2
	else:
		return 1

func _get_spin_interval() -> float:
	var hp = get_hp_percent()
	if hp <= 35.0:
		return 0.015
	elif hp <= 55.0:
		return 0.02
	else:
		return spin_shoot_interval

func attack_spin_shoot():
	if not player or not projectile_scene:
		return
	is_spinning_attack = true
	spin_attack_timer = 0.0
	spin_shoot_timer = 0.0
	spin_start_rotation = rotation
	spin_spins_remaining = _get_spin_count()
	spin_clockwise = randi() % 2 == 0

func process_spin_attack(delta):
	if spin_spins_remaining <= 0:
		if not spin_recovering:
			spin_recovering = true
			is_spinning_attack = false
		rotation = lerp_angle(rotation, spin_start_rotation, delta * 6.0)
		if abs(angle_difference(rotation, spin_start_rotation)) < 0.01:
			rotation = spin_start_rotation
			spin_recovering = false
		return

	spin_attack_timer += delta
	spin_shoot_timer += delta

	var scaled_duration = spin_attack_duration / (_get_turn_speed() / 3.0)
	var direction_sign = 1.0 if spin_clockwise else -1.0

	if spin_attack_timer < scaled_duration:
		var progress = spin_attack_timer / scaled_duration
		rotation = spin_start_rotation + direction_sign * progress * TAU
		if spin_shoot_timer >= _get_spin_interval():
			spin_shoot_timer = 0.0
			spawn_spin_projectile()
	else:
		spin_spins_remaining -= 1
		spin_attack_timer = 0.0
		spin_shoot_timer = 0.0
		spin_start_rotation = rotation
		spin_clockwise = randi() % 2 == 0

func spawn_spin_projectile():
	var forward_dir = Vector2.from_angle(rotation + PI / 2)
	var projectile = projectile_scene.instantiate()
	apply_projectile_logic(projectile)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = head_projectile_marker.global_position
	if projectile.has_method("setup"):
		projectile.setup(head_projectile_marker.global_position, forward_dir)

# ---------------- Circle Attack ----------------
func _get_circle_wave_count() -> int:
	var hp = get_hp_percent()
	if hp <= 35.0:
		return 3
	elif hp <= 55.0:
		return 2
	else:
		return 1

func attack_circle_shoot():
	if not growing_ball_scene:
		return

	circle_wave_count = 0
	circle_waves_total = _get_circle_wave_count()
	circle_waiting_for_ball = true
	web_attack_active = true
	_spawn_circle_ball()

func _spawn_circle_ball():
	# Don't spawn if we're dying
	if is_dying:
		web_attack_active = false
		circle_waiting_for_ball = false
		return

	var ball = growing_ball_scene.instantiate()
	get_tree().current_scene.add_child(ball)
	ball.global_position = head_ball_marker.global_position
	ball.animation_finished.connect(_on_circle_growing_ball_finished.bind(ball))
	ball.play("default")

func _on_circle_growing_ball_finished(ball: Node):
	# Bail out if we died while the ball was growing
	if is_dying:
		if is_instance_valid(ball):
			ball.queue_free()
		web_attack_active = false
		circle_waiting_for_ball = false
		return

	var fire_pos = head_ball_marker.global_position
	ball.queue_free()
	circle_wave_count += 1

	var hp = get_hp_percent()
	if hp <= 20.0:
		_spawn_returning_circle(fire_pos)
	else:
		spawn_projectile_circle_from_marker(fire_pos)

	if circle_wave_count < circle_waves_total:
		get_tree().create_timer(0.6).timeout.connect(func():
			if not is_dying:
				_spawn_circle_ball()
		)
	else:
		web_attack_active = false
		web_recovering = true
		web_time = 0.0
		circle_waiting_for_ball = false

func _spawn_returning_circle(center_pos: Vector2):
	if is_dying:
		return
	spawn_projectile_circle_from_marker(center_pos)
	var boss_pos = center_pos
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_dying:
			return
		for i in range(circle_projectile_count):
			var angle = TAU * i / circle_projectile_count
			var outer_radius = min(
				arena_right.global_position.x - arena_left.global_position.x,
				arena_bottom.global_position.y - arena_top.global_position.y
			) * 0.5
			var spawn_pos = boss_pos + Vector2.from_angle(angle) * outer_radius
			var inward_dir = (boss_pos - spawn_pos).normalized()
			var projectile = projectile_scene.instantiate()
			apply_projectile_logic(projectile)
			get_tree().current_scene.add_child(projectile)
			projectile.global_position = spawn_pos
			if projectile.has_method("setup"):
				projectile.setup(spawn_pos, inward_dir)
	)

# ---------------- Charge Wall Attack ----------------
func attack_wall_from_top():
	if not medium_bullet_scene:
		return

	var go_down = randi() % 2 == 0
	charge_first_direction = Vector2.DOWN if go_down else Vector2.UP
	charge_direction = charge_first_direction
	charge_arena_boundary_y = arena_bottom.global_position.y if go_down else arena_top.global_position.y
	charge_phase = 0

	charge_target_rotation = charge_direction.angle() + deg_to_rad(-90)
	charge_anticipating = true
	charge_anticipate_timer = 0.0
	charge_turning = false
	charge_attack_active = true
	charge_bullet = null

func _process_charge_attack(delta):
	if charge_anticipating:
		charge_anticipate_timer += delta
		if charge_anticipate_timer >= charge_anticipate_duration:
			charge_anticipating = false
			charge_turning = true
		return

	if charge_turning:
		var diff = angle_difference(rotation, charge_target_rotation)
		var turn_speed = _get_turn_speed()
		if abs(diff) <= turn_speed * delta:
			rotation = charge_target_rotation
			charge_turning = false
			_fire_charge_bullet()
		else:
			rotation += sign(diff) * turn_speed * delta
		return

	if charge_bullet == null or not is_instance_valid(charge_bullet):
		charge_attack_active = false
		charge_bullet = null
		return

	var past_boundary = (
		(charge_direction == Vector2.DOWN and charge_bullet.global_position.y >= charge_arena_boundary_y) or
		(charge_direction == Vector2.UP   and charge_bullet.global_position.y <= charge_arena_boundary_y)
	)

	if past_boundary:
		charge_bullet.queue_free()
		charge_bullet = null
		_spawn_charge_wall()

		if get_hp_percent() <= 40.0 and charge_phase == 0:
			charge_phase = 1
			charge_direction = -charge_first_direction
			charge_arena_boundary_y = arena_top.global_position.y if charge_first_direction == Vector2.DOWN else arena_bottom.global_position.y
			charge_target_rotation = charge_direction.angle() + deg_to_rad(-90)
			charge_anticipating = true
			charge_anticipate_timer = 0.0
			charge_turning = false
		else:
			charge_attack_active = false

func _fire_charge_bullet():
	var bullet = medium_bullet_scene.instantiate()
	apply_projectile_logic(bullet)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = head_projectile_marker.global_position
	if bullet.has_method("setup"):
		bullet.setup(bullet.global_position, charge_direction)
	charge_bullet = bullet

func _spawn_charge_wall():
	var left_x  = arena_left.global_position.x
	var right_x = arena_right.global_position.x
	var spawn_y = charge_arena_boundary_y
	var wall_dir = -charge_direction

	var width = right_x - left_x
	var count = max(1, int(width / wall_bullet_spacing))

	for i in range(count):
		var t = 0 if count == 1 else float(i) / (count - 1)
		var spawn_x = lerp(left_x, right_x, t)

		var bullet = medium_bullet_scene.instantiate()
		apply_projectile_logic(bullet)
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = Vector2(spawn_x, spawn_y)
		if bullet.has_method("setup"):
			bullet.setup(bullet.global_position, wall_dir)

# ---------------- Egg Attack ----------------
func _get_egg_count() -> int:
	var hp = get_hp_percent()
	if hp <= 50.0:
		return 1
	elif hp <= 75.0:
		return 2
	else:
		return 3

func _get_egg_turn_speed() -> float:
	return _get_turn_speed()

func attack_egg_shoot():
	if not medium_bullet_scene or not egg_scene:
		return

	var count = _get_egg_count()
	var all_indices = range(1, 15)
	all_indices.shuffle()
	var chosen = all_indices.slice(0, count)

	egg_targets = []
	for i in chosen:
		var marker = egg_spawns.get_node_or_null(str(i))
		if marker:
			egg_targets.append(marker.global_position)

	if egg_targets.is_empty():
		return

	egg_current_index = 0
	egg_attack_active = true
	_egg_start_next_shot()

func _egg_start_next_shot():
	if egg_current_index >= egg_targets.size():
		egg_attack_active = false
		return

	egg_target_pos = egg_targets[egg_current_index]
	var dir = (egg_target_pos - global_position).normalized()
	egg_target_rotation = dir.angle() + deg_to_rad(-90)
	egg_turning = true
	egg_bullet = null

func _process_egg_attack(delta):
	if egg_turning:
		var diff = angle_difference(rotation, egg_target_rotation)
		var turn_speed = _get_egg_turn_speed()
		if abs(diff) <= turn_speed * delta:
			rotation = egg_target_rotation
			egg_turning = false
			_egg_fire_bullet()
		else:
			rotation += sign(diff) * turn_speed * delta
		return

	if egg_bullet == null or not is_instance_valid(egg_bullet):
		egg_current_index += 1
		_egg_start_next_shot()
		return

	if egg_bullet.global_position.distance_to(egg_target_pos) <= egg_arrival_threshold:
		egg_bullet.queue_free()
		egg_bullet = null
		_spawn_egg(egg_target_pos)
		egg_current_index += 1
		_egg_start_next_shot()

func _egg_fire_bullet():
	var dir = (egg_target_pos - global_position).normalized()
	var bullet = medium_bullet_scene.instantiate()
	apply_projectile_logic(bullet)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = head_projectile_marker.global_position
	if bullet.has_method("setup"):
		bullet.setup(bullet.global_position, dir)
	egg_bullet = bullet

func _spawn_egg(pos: Vector2):
	var egg = egg_scene.instantiate()
	egg.is_inverted = is_inverted
	get_tree().current_scene.add_child(egg)
	egg.global_position = pos

# ---------------- Spiral Attack ----------------
func _get_spiral_count() -> int:
	return 2 if get_hp_percent() <= 30.0 else 1

func attack_spiral():
	if not spiral_carrier_scene:
		return

	spiral_shots_remaining = _get_spiral_count()
	_spiral_start_next()

func _spiral_start_next():
	if is_dying:
		spiral_attack_active = false
		return

	if spiral_shots_remaining <= 0:
		spiral_attack_active = false
		return

	var spot_index = (randi() % 4) + 1
	var spot = spiral_spots.get_node_or_null(str(spot_index))
	if not spot:
		spiral_attack_active = false
		return

	spiral_target_corner = spot_index
	var dir = (spot.global_position - global_position).normalized()
	spiral_target_rotation = dir.angle() + deg_to_rad(-90)
	spiral_turning = true
	spiral_attack_active = true

func _process_spiral_attack(delta):
	if spiral_turning:
		var diff = angle_difference(rotation, spiral_target_rotation)
		var turn_speed = _get_turn_speed()
		if abs(diff) <= turn_speed * delta:
			rotation = spiral_target_rotation
			spiral_turning = false
			web_attack_active = true
			web_time = 0.0
			_fire_spiral_carrier()
			spiral_shots_remaining -= 1
			if spiral_shots_remaining > 0:
				get_tree().create_timer(0.4).timeout.connect(func():
					if not is_dying:
						_spiral_start_next()
				)
			else:
				spiral_attack_active = false
		else:
			rotation += sign(diff) * turn_speed * delta

func _fire_spiral_carrier():
	var spot = spiral_spots.get_node_or_null(str(spiral_target_corner))
	if not spot:
		return

	var carrier = spiral_carrier_scene.instantiate()
	carrier.corner_pos = spot.global_position
	carrier.is_inverted = is_inverted
	carrier.arena_left_x = arena_left.global_position.x
	carrier.arena_right_x = arena_right.global_position.x
	carrier.arena_top_y = arena_top.global_position.y
	carrier.arena_bottom_y = arena_bottom.global_position.y
	get_tree().current_scene.add_child(carrier)
	carrier.global_position = head_projectile_marker.global_position
	get_tree().create_timer(0.5).timeout.connect(func(): web_attack_active = false; web_recovering = true)

# ---------------- Web Shot Attack ----------------
func _get_web_count() -> int:
	var hp = get_hp_percent()
	if hp <= 25.0:
		return 4
	elif hp <= 50.0:
		return 3
	elif hp <= 75.0:
		return 2
	else:
		return 1

func attack_shoot_web():
	if not spider_web_scene:
		return

	var count = _get_web_count()
	var all_indices = range(1, 11)
	all_indices.shuffle()
	var chosen = all_indices.slice(0, count)

	web_shot_targets = []
	for i in chosen:
		var marker = web_spawns.get_node_or_null(str(i))
		if marker:
			web_shot_targets.append(marker.global_position)

	if web_shot_targets.is_empty():
		return

	web_shot_current_index = 0
	_web_shot_start_next()

func _web_shot_start_next():
	if web_shot_current_index >= web_shot_targets.size():
		web_attack_active_shot = false
		return

	web_shot_target_pos = web_shot_targets[web_shot_current_index]
	var dir = (web_shot_target_pos - global_position).normalized()
	web_shot_target_rotation = dir.angle() + deg_to_rad(-90)
	web_shot_turning = true
	web_attack_active_shot = true

func _process_web_shot(delta):
	if web_shot_turning:
		var diff = angle_difference(rotation, web_shot_target_rotation)
		var turn_speed = _get_turn_speed()
		if abs(diff) <= turn_speed * delta:
			rotation = web_shot_target_rotation
			web_shot_turning = false
			_fire_web()
			web_shot_current_index += 1
			_web_shot_start_next()
		else:
			rotation += sign(diff) * turn_speed * delta

func _fire_web():
	var web = spider_web_scene.instantiate()
	web.is_inverted = is_inverted
	web.start_pos = head_projectile_marker.global_position
	web.target_pos = web_shot_target_pos
	get_tree().current_scene.add_child(web)
	web.global_position = head_projectile_marker.global_position

# ---------------- Beam Attack ----------------
func _get_beam_count() -> int:
	var hp = get_hp_percent()
	if hp <= 10.0:
		return 4
	elif hp <= 33.0:
		return 2
	else:
		return 1

func _get_beam_anticipate_duration() -> float:
	var hp = get_hp_percent()
	if hp <= 10.0:
		return 0.1
	elif hp <= 33.0:
		return 0.18
	else:
		return charge_anticipate_duration

func attack_beam():
	if not beam_scene or not player:
		return

	beam_shots_remaining = _get_beam_count()
	_beam_start_next()

func _beam_start_next():
	if is_dying:
		beam_attack_active = false
		return

	if beam_shots_remaining <= 0:
		beam_attack_active = false
		return

	var dir = (player.global_position - global_position).normalized()
	beam_target_rotation = dir.angle() + deg_to_rad(-90)
	beam_turning = true
	beam_attack_active = true

func _process_beam_attack(delta):
	if beam_turning:
		var diff = angle_difference(rotation, beam_target_rotation)
		var turn_speed = _get_turn_speed()
		if abs(diff) <= turn_speed * delta:
			rotation = beam_target_rotation
			beam_turning = false
			_fire_beam()
		else:
			rotation += sign(diff) * turn_speed * delta

	if beam_tracking and player and is_instance_valid(player):
		var dir = (player.global_position - global_position).normalized()
		rotation = dir.angle() + deg_to_rad(-90)

func _fire_beam():
	var beam = beam_scene.instantiate()
	beam.player = player
	beam.origin_marker = head_projectile_marker
	if "anticipate_duration" in beam:
		beam.anticipate_duration = _get_beam_anticipate_duration()
	get_tree().current_scene.add_child(beam)
	beam.global_position = head_projectile_marker.global_position
	beam.global_rotation = global_rotation
	beam.beam_firing.connect(_on_beam_firing)
	beam_tracking = true

func _on_beam_firing():
	beam_tracking = false
	beam_shots_remaining -= 1
	if beam_shots_remaining > 0:
		get_tree().create_timer(0.3).timeout.connect(func():
			if not is_dying:
				_beam_start_next()
		)
	else:
		beam_attack_active = false

func _cache_leg_rest_rotations():
	for group in leg_groups.values():
		for leg_name in group:
			var leg = get_node_or_null(leg_name)
			if leg:
				leg_rest_rotations[leg_name] = leg.rotation
	for group in leg_groups.values():
		for leg_name in group:
			var leg = get_node_or_null(leg_name)
			if leg:
				leg_rest_rotations[leg_name] = leg.rotation
				
func _update_leg_animation(delta):
	leg_time += delta
	for leg_name in leg_rest_rotations.keys():
		var leg = get_node_or_null(leg_name)
		if not leg:
			continue
		var base_rot = leg_rest_rotations[leg_name]
		if is_spinning_attack or charge_turning or egg_turning or spiral_turning or web_shot_turning or beam_turning or beam_tracking:
			var scaled_swing = leg_swing_speed * (_get_turn_speed() / 3.0)
			var move_phase = leg_time * scaled_swing
			var phase_offset = 0.0 if leg_name in leg_groups["A"] else PI
			leg.rotation = base_rot + sin(move_phase + phase_offset) * leg_swing_amplitude
		else:
			leg.rotation = lerp_angle(leg.rotation, base_rot, delta * 6.0)

# ---------------- Web Animations ----------------
func _cache_web_leg_positions():
	for name in ["M1", "M2"]:
		var node = get_node_or_null(name)
		if node:
			web_base_rotations[name] = {"rot": node.rotation}

func _update_web_motion(delta):
	var nodes = ["M1", "M2"]
	if web_attack_active:
		web_time += delta
		var wave = sin(web_time * 13.0) * deg_to_rad(10)
		for name in nodes:
			var node = get_node_or_null(name)
			if node and web_base_rotations.has(name):
				var base = web_base_rotations[name]
				var direction = 1.0 if name == "M1" else -1.0
				node.rotation = base["rot"] + wave * direction
		return

	if web_recovering:
		var done = true
		for name in nodes:
			var node = get_node_or_null(name)
			if node and web_base_rotations.has(name):
				var base = web_base_rotations[name]
				node.rotation = lerp_angle(node.rotation, base["rot"], delta * 5.0)
				if abs(angle_difference(node.rotation, base["rot"])) > 0.02:
					done = false
		if done:
			web_recovering = false

# ---------------- Combat ----------------
func take_damage(amount: int):
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)

	if music_phase == 0 and get_hp_percent() <= 50.0:
		music_phase = 1
		_crossfade_music(MUSIC_BOSS2)

	if health <= 0:
		die()

func die():
	if is_dying:
		return
	is_dying = true

	# Cancel all active attack states so nothing keeps firing
	is_spinning_attack = false
	spin_recovering = false
	spin_spins_remaining = 0
	charge_attack_active = false
	charge_anticipating = false
	charge_turning = false
	if charge_bullet and is_instance_valid(charge_bullet):
		charge_bullet.queue_free()
		charge_bullet = null
	egg_attack_active = false
	egg_turning = false
	if egg_bullet and is_instance_valid(egg_bullet):
		egg_bullet.queue_free()
		egg_bullet = null
	spiral_attack_active = false
	spiral_turning = false
	spiral_shots_remaining = 0
	web_attack_active_shot = false
	web_shot_turning = false
	beam_attack_active = false
	beam_turning = false
	beam_tracking = false
	beam_shots_remaining = 0
	# Stop circle attack — the is_dying flag gates all its timer callbacks
	circle_waiting_for_ball = false
	web_attack_active = false
	circle_wave_count = circle_waves_total  # prevent any further waves

	hud.play_boss_bar_outro()

	_crossfade_music(MUSIC_BOSSDEATH)

	for node in get_tree().get_nodes_in_group("Projectile"):
		if is_instance_valid(node):
			if "is_cleared" in node:
				node.is_cleared = true
			node.queue_free()

	_clear_projectiles_recursive(get_tree().current_scene)

	for spider in get_tree().get_nodes_in_group("BabySpider"):
		if spider.has_method("explode"):
			spider.explode()
		else:
			spider.queue_free()

	_run_death_sequence()

func _clear_projectiles_recursive(node: Node):
	for child in node.get_children():
		if child == self or child == player:
			continue
		if child.has_method("setup") and not (child is CharacterBody2D):
			child.queue_free()
		else:
			_clear_projectiles_recursive(child)

func _run_death_sequence():
	var duration := 6.0
	var elapsed := 0.0
	var blink_interval := 0.15
	var blink_timer := 0.0
	var color_switch_interval := 0.8   # slower than blink
	var color_switch_timer := 0.0
	var shake_strength := 3.0
	var origin := global_position

	while elapsed < duration:
		var delta = get_process_delta_time()
		elapsed += delta
		blink_timer -= delta
		color_switch_timer -= delta

		var progress = elapsed / duration
		shake_strength = lerp(3.0, 10.0, progress)
		blink_interval = lerp(0.15, 0.04, progress)
		# Color switch speeds up slightly toward the end but stays slower than blink
		color_switch_interval = lerp(0.8, 0.35, progress)

		global_position = origin + Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)

		if blink_timer <= 0.0:
			blink_timer = blink_interval
			visible = !visible

		if color_switch_timer <= 0.0:
			color_switch_timer = color_switch_interval
			_apply_color_switch()

		await get_tree().process_frame

	global_position = origin
	visible = true

	await get_tree().create_timer(0.4).timeout

	var explosion = boss_explosion_scene.instantiate()
	explosion.global_position = global_position
	get_tree().current_scene.add_child(explosion)

	# Show dead spider parts and randomise inverted state
	if dead_spider_parts:
		dead_spider_parts.visible = true

		var total_inverted = 0

		for area in dead_spider_parts.get_children():
			var collision = area.get_node_or_null("CollisionShape2D")
			if collision:
				collision.disabled = false

			var random = randi_range(1, 2)

			if random == 1 and total_inverted < 3:
				total_inverted += 1
				area.is_inverted = true
				area.get_node("Sprite2D").material.set_shader_parameter("invert_colors", true)
				area.set_collision_layer_value(2, false)
				area.set_collision_layer_value(3, true)
			else:
				area.set_collision_layer_value(2, true)
				area.set_collision_layer_value(3, false)

	# Count dead parts and tell the player to show ending visuals
	var part_count = 0
	if dead_spider_parts:
		part_count = dead_spider_parts.get_child_count()
	if player and player.has_method("show_ending_visuals"):
		player.show_ending_visuals(part_count)

	queue_free()
