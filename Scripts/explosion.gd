extends Area2D

@onready var collision = $CollisionShape2D

func _ready():
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.play("default")
		sprite.frame_changed.connect(_on_frame_changed.bind(sprite))

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _on_frame_changed(sprite: AnimatedSprite2D):
	if sprite.frame >= 3:
		collision.set_deferred("disabled", true)

func _on_body_entered(body: Node):
	if body.has_method("take_damage"):
		body.take_damage(1)

func _on_area_entered(area: Node):
	if area.has_method("take_damage"):
		area.take_damage(1)
