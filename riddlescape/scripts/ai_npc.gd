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
	body_entered.connect(_on_body_entered)
	
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

func _on_body_entered(body):
	if body.name == "Player":
		print("You failed!")

		var timer = Timer.new()
		timer.wait_time = 0.3
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_on_death_timer_timeout)
		timer.start()

func _on_death_timer_timeout():
	get_tree().reload_current_scene()
