extends Node2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var press_anything = $PressAnything

var alreadyGone = false
var show_press_label = false
var timer = 0.0

var input_cooldown = 0.2
var input_timer = 0.0

func _ready() -> void:
	press_anything.visible = false

func _process(delta: float) -> void:
	if input_timer > 0:
		input_timer -= delta

	if animated_sprite.frame == 0 and not show_press_label:
		timer += delta
		if timer >= 5.0:
			press_anything.visible = true
			show_press_label = true

	# Transition to menu once animation finishes
	if animated_sprite.frame >= 1 and not alreadyGone:
		alreadyGone = true
		TransitionScreen.transition()
		await TransitionScreen.on_transition_finished

		var game_over_scene = preload("res://Scenes/main_scene.tscn").instantiate()
		get_tree().current_scene.queue_free()
		get_tree().root.add_child(game_over_scene)
		get_tree().current_scene = game_over_scene

func _unhandled_input(event):
	if input_timer <= 0:
		if event is InputEventKey and event.pressed:
			_on_input()
		elif event is InputEventMouseButton and event.pressed:
			_on_input()
		elif event is InputEventJoypadButton and event.pressed:
			_on_input()

func _on_input():
	if press_anything.visible:
		press_anything.visible = false

	animated_sprite.frame += 1
	input_timer = input_cooldown 
