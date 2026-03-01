extends CharacterBody2D
@onready var Sprite = $Sprite2D
const baby_spider = preload("res://Prefabs/baby_spider.tscn")
const explosion_scene = preload("res://Prefabs/explosion.tscn")
const dead_spider_scene = preload("res://Prefabs/dead_spider.tscn")
@export var max_health: int = 2
var health: int
var is_inverted := false

func _ready():
	health = max_health
	_apply_invert()
	Sprite.play("default")
	Sprite.animation_finished.connect(_on_animation_finished)

func _apply_invert():
	if Sprite and Sprite.material:
		Sprite.material = Sprite.material.duplicate()
		Sprite.material.set_shader_parameter("invert_colors", is_inverted)

	if is_inverted:
		set_collision_layer_value(2, false)
		set_collision_layer_value(3, true)
	else:
		set_collision_layer_value(2, true)
		set_collision_layer_value(3, false)

func _on_animation_finished():
	if health > 0 and not is_queued_for_deletion():
		spawn_baby_spider()
		queue_free()

func spawn_baby_spider():
	var baby = baby_spider.instantiate()
	baby.global_position = global_position
	baby.is_inverted = is_inverted
	get_parent().add_child(baby)

func take_damage(amount: int):
	health -= amount
	print("Enemy took ", amount, " damage. Health: ", health)
	if health <= 0:
		die()

func die():
	if not is_queued_for_deletion():
		var parent = get_parent()

		# Spawn corpse
		var corpse = dead_spider_scene.instantiate()
		corpse.is_inverted = is_inverted
		
		var random_rotation = randi_range(0,360)
		
		corpse.global_position = global_position
		corpse.global_rotation = global_rotation + deg_to_rad(random_rotation)
		parent.call_deferred("add_child", corpse)

		# Spawn explosion
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		explosion.global_rotation = global_rotation + deg_to_rad(random_rotation)

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
