extends Button

var button1: Texture2D = preload("res://Sprites/play1.png")
var button2: Texture2D = preload("res://Sprites/play2.png")

func _ready():
	icon = button1

func _on_mouse_entered() -> void:
	icon = button2

func _on_mouse_exited() -> void:
	icon = button1

func _on_pressed() -> void:
	TransitionScreen.transition()
	await TransitionScreen.on_transition_finished
	
	call_deferred("_change_scene", "res://Scenes/cutscene1.tscn")


func _change_scene(novo_caminho):
	get_tree().change_scene_to_file(novo_caminho)
