extends CharacterBody2D

const SPEED := 300.0
const STEP_FREQUENCY := 10.0
const STEP_ANGLE := 0.3 # radians, how much legs swing
const MAX_HEAD_ROTATION = deg_to_rad(10)

var step_timer := 0.0

@onready var front_left_leg = $FrontLeftLeg
@onready var front_right_leg = $FrontRightLeg
@onready var back_left_leg = $BackLeftLeg
@onready var back_right_leg = $BackRightLeg
@onready var head = $Head


func _physics_process(delta):
	var direction = Vector2.ZERO
	direction.x = Input.get_axis("Left", "Right")
	direction.y = Input.get_axis("Up", "Down")
	direction = direction.normalized()
	
	velocity = direction * SPEED
	move_and_slide()
	
	# --- Mouse targeting ---
	var target_angle = (get_global_mouse_position() - global_position).angle() + deg_to_rad(90)
	
	# Body rotates smoothly
	rotation = lerp_angle(rotation, target_angle, delta * 5.0)
	
	# Head rotates faster but limited
	var head_target_global = (get_global_mouse_position() - head.global_position).angle() + deg_to_rad(90)
	
	# Properly compute shortest relative angle
	var head_target_local = wrapf(head_target_global - rotation, -PI, PI)
	
	head_target_local = clamp(head_target_local, -MAX_HEAD_ROTATION, MAX_HEAD_ROTATION)
	
	head.rotation = lerp_angle(head.rotation, head_target_local, delta * 10.0)
	
	
	# --- Procedural leg animation ---
	if velocity.length() > 0.1:
		step_timer += (delta * STEP_FREQUENCY) / 1.5
		
		front_left_leg.rotation = sin(step_timer) * STEP_ANGLE
		back_right_leg.rotation = sin(step_timer + PI) * STEP_ANGLE
		
		front_right_leg.rotation = sin(step_timer) * STEP_ANGLE
		back_left_leg.rotation = sin(step_timer + PI) * STEP_ANGLE
