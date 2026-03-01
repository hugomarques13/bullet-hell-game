extends Control

func _ready():
	$Label.text = $".".get_meta("texto")
	$AnimationPlayer.play("RESET")

func resume():
	$"..".visible = false
	get_tree().paused = false
	$AnimationPlayer.play_backwards("blur")
	$Label.visible = false
	
func pause():
	get_tree().paused = true
	$Label.visible = true
	$AnimationPlayer.play("blur")

func testEsc():
	if Input.is_action_just_pressed("Pause") and !get_tree().paused:
		$"..".visible = true
		pause()
	elif Input.is_action_just_pressed("Pause") and get_tree().paused:
		resume()


func _on_resume_pressed():
	resume()


func _process(delta):
	testEsc()


func _on_restart_pressed() -> void:
	resume()
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	resume()
	
	get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")

func mostrar_texto() -> void:
	for i in $Label.text.length():
		$Label.visible_characters += 1
		await get_tree().create_timer(0.05).timeout
