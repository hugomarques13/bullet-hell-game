extends CanvasLayer

const HUD_NORMAL = preload("res://Sprites/HUD/hud.png")
const HUD_INVERTED = preload("res://Sprites/HUD/hud2.png")
const HUDNODE_NORMAL = preload("res://Sprites/HUD/hudnode1.png")
const HUDNODE_INVERTED = preload("res://Sprites/HUD/hudnode2.png")

@onready var hud_sprite = $Hud
@onready var hud_nodes = [
	$Hudnode1,
	$Hudnode2,
	$Hudnode3,
	$Hudnode4,
]
@onready var real_bar: TextureRect = $RealBar
@onready var boss_bar_background: TextureRect = $BossBar

var player: Node = null
var boss: Node = null
var real_bar_base_scale: float = 1.0

# --- NEW ---
var boss_bar_animating: bool = false
var displayed_boss_ratio: float = 0.0


func _ready():
	await get_tree().process_frame
	
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		player = get_node_or_null("../Player/CharacterBody2D")

	boss = get_tree().get_first_node_in_group("Spider")
	if not boss:
		boss = get_node_or_null("../Spider")

	if real_bar:
		real_bar_base_scale = real_bar.scale.x
		real_bar.pivot_offset.x = 0

	# Start hidden
	if boss_bar_background:
		boss_bar_background.visible = false
	if real_bar:
		real_bar.visible = false


func _process(_delta):
	if not player or not is_instance_valid(player):
		return
		
	_update_sprites(player.is_inverted)
	_update_health(player.health)
	_update_boss_bar()


func _update_sprites(inverted: bool):
	hud_sprite.texture = HUD_INVERTED if inverted else HUD_NORMAL
	var node_texture = HUDNODE_INVERTED if inverted else HUDNODE_NORMAL
	
	for node in hud_nodes:
		node.texture = node_texture


func _update_health(current_health: int):
	for i in range(hud_nodes.size()):
		hud_nodes[i].visible = i < current_health


func _update_boss_bar():
	if not real_bar:
		return

	if not boss or not is_instance_valid(boss):
		return

	var ratio = clamp(float(boss.health) / float(boss.max_health), 0.0, 1.0)

	if boss_bar_animating:
		real_bar.scale.x = real_bar_base_scale * displayed_boss_ratio
		return

	displayed_boss_ratio = ratio
	real_bar.scale.x = real_bar_base_scale * displayed_boss_ratio


# =========================================================
# ================== BOSS BAR INTRO =======================
# =========================================================

func play_boss_bar_intro():
	if not real_bar or not boss_bar_background:
		return

	if not boss or not is_instance_valid(boss):
		return

	boss_bar_animating = true

	# Make visible
	boss_bar_background.visible = true
	real_bar.visible = true

	# Fade background in
	var bg_color = boss_bar_background.modulate
	bg_color.a = 0.0
	boss_bar_background.modulate = bg_color

	# Start empty
	displayed_boss_ratio = 0.0
	real_bar.scale.x = 0.0

	var target_ratio = clamp(float(boss.health) / float(boss.max_health), 0.0, 1.0)

	var tween = create_tween()

	tween.tween_property(
		boss_bar_background,
		"modulate:a",
		1.0,
		0.5
	)

	tween.parallel().tween_property(
		self,
		"displayed_boss_ratio",
		target_ratio,
		0.8
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		boss_bar_animating = false
	)


func play_boss_bar_outro():
	if not real_bar or not boss_bar_background:
		return

	boss_bar_animating = true

	var tween = create_tween()

	# Fade background out
	tween.tween_property(
		boss_bar_background,
		"modulate:a",
		0.0,
		0.4
	)

	# Shrink bar to zero
	tween.parallel().tween_property(
		self,
		"displayed_boss_ratio",
		0.0,
		0.4
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.finished.connect(func():
		boss_bar_background.visible = false
		real_bar.visible = false
		boss_bar_animating = false
	)
