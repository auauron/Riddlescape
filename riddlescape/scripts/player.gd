extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var footstep_player1 = $FootstepPlayer1
@onready var footstep_player2 = $FootstepPlayer2

const SPEED = 140.0
const JUMP_VELOCITY = -400.0
var is_dead = false
var is_in_dialogue = false
var is_attacking = false

# Footstep system
var is_walking = false
var was_walking = false
var footstep_alternate = false  # false = sound1, true = sound2
var footstep_timer = 0.0
const FOOTSTEP_INTERVAL = 0.4  # Time between footsteps

# Player identification method for NPCs
func player():
	return true

func _ready():
	print("Player _ready() called")
	print("Checking audio nodes...")
	print("footstep_player1: ", footstep_player1)
	print("footstep_player2: ", footstep_player2)
	
	if footstep_player1:
		print("FootstepPlayer1 stream: ", footstep_player1.stream)
	if footstep_player2:
		print("FootstepPlayer2 stream: ", footstep_player2.stream)

func _physics_process(delta: float) -> void:
	if is_dead or is_in_dialogue or is_attacking:
		if is_in_dialogue and not is_dead and not is_attacking:
			animated_sprite.play("idle")
		return
		
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
		
	if is_on_floor():			
		if direction == 0:
			animated_sprite.play("idle")
			is_walking = false
		else:
			animated_sprite.play("move")
			is_walking = true
	else:
		animated_sprite.play("jump")
		is_walking = false
	
	handle_footsteps(delta)
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

func handle_footsteps(delta: float):
	if is_walking and is_on_floor():
		# Start walking - play first footstep immediately
		if not was_walking:
			play_footstep()
			footstep_timer = FOOTSTEP_INTERVAL
		else:
			# Continue walking - play footsteps at intervals
			footstep_timer -= delta
			if footstep_timer <= 0:
				play_footstep()
				footstep_timer = FOOTSTEP_INTERVAL
	
	# Update walking state
	was_walking = is_walking

func play_footstep():	
	# Alternate between two footstep sounds
	if footstep_alternate:
		if footstep_player2:
			footstep_player2.play()
	else:
		if footstep_player1:
			footstep_player1.play()
	
	# Switch to the other sound for next step
	footstep_alternate = !footstep_alternate
	
func attack_npc():
	if not is_attacking:
		is_attacking = true
		animated_sprite.play("atk")
		await animated_sprite.animation_finished
		is_attacking = false
		animated_sprite.play("idle")

func die():
	is_dead = true
	animated_sprite.play("dead")
	if not animated_sprite.animation_finished.is_connected(_on_dead_animation_finished):
		animated_sprite.animation_finished.connect(_on_dead_animation_finished)

func _on_dead_animation_finished():
	animated_sprite.stop()
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("dead") - 1
