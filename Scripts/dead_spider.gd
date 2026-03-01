extends Area2D

var is_inverted := false

func _ready():
	_apply_invert()

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
	else:
		set_collision_layer_value(2, true)
		set_collision_layer_value(3, false)
