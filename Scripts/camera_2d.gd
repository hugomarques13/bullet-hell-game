extends Camera2D

@onready var player = $".."
@onready var bounds_area = $"../../../CameraBounds"

var bounds_rect : Rect2

func _ready():
	var shape = bounds_area.get_node("CollisionShape2D").shape
	
	if shape is RectangleShape2D:
		var transform = bounds_area.get_node("CollisionShape2D").global_transform
		var extents = shape.extents
		
		var center = transform.origin
		
		bounds_rect = Rect2(
			center - extents,
			extents * 2
		)

func _process(delta):
	if not player:
		return
	
	var viewport_size = get_viewport_rect().size
	var half_screen = viewport_size / (2.0 * zoom)

	var pos = player.global_position

	pos.x = clamp(
		pos.x,
		bounds_rect.position.x + half_screen.x,
		bounds_rect.end.x - half_screen.x
	)

	pos.y = clamp(
		pos.y,
		bounds_rect.position.y + half_screen.y,
		bounds_rect.end.y - half_screen.y
	)

	global_position = pos
