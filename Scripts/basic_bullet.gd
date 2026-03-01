extends Area2D

@export var speed: float = 600.0
@export var damage: int = 1
@export var lifetime: float = 10

var direction: Vector2 = Vector2.ZERO

func setup(start_position: Vector2, dir: Vector2):
	body_entered.connect(_on_body_entered)
	global_position = start_position
	direction = dir.normalized()
	rotation = direction.angle() + deg_to_rad(90)

func _ready():
	if lifetime > 0:
		await get_tree().create_timer(lifetime).timeout
		queue_free()

func _physics_process(delta):
	global_position += direction.normalized() * speed * delta

func _on_body_entered(body):
	print(body)
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	queue_free()
