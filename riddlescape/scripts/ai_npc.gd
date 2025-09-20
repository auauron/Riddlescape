extends Area2D

const speed = 60
const MOVE_DISTANCE = 48  

var direction = 1
var start_position: float
var left_boundary: float
var right_boundary: float

@onready var ray_cast_right: RayCast2D = $RayCastRight
@onready var ray_cast_left: RayCast2D = $RayCastLeft
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	start_position = position.x
	left_boundary = start_position - MOVE_DISTANCE
	right_boundary = start_position + MOVE_DISTANCE

func _process(delta: float) -> void:
	if position.x >= right_boundary:
		direction = -1
	elif position.x <= left_boundary:
		direction = 1
		#
	#if ray_cast_right.is_colliding():
		#direction = -1
	#if ray_cast_left.is_colliding():
		#direction = 1
	#
	if direction == 1:
		animated_sprite.flip_h = true  
	else:
		animated_sprite.flip_h = false 
		
	position.x += direction * speed * delta
