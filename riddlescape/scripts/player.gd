extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 140.0
const JUMP_VELOCITY = -400.0

var is_dead = false

func _physics_process(delta: float) -> void:
	# Don't process movement or animations if dead
	if is_dead:
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	# Handle animations
	update_animation()

func update_animation():
	# Jumping animation (when not on floor)
	if not is_on_floor():
		animated_sprite.play("jump")
	# Running animation (when moving horizontally and on floor)
	elif abs(velocity.x) > 0.1 and is_on_floor():
		animated_sprite.play("run")
		# Flip sprite based on direction
		if velocity.x < 0:
			animated_sprite.flip_h = true
		elif velocity.x > 0:
			animated_sprite.flip_h = false
	# Idle animation (when not moving and on floor)
	else:
		animated_sprite.play("idle")

func die():
	is_dead = true
	# Play dead animation
	animated_sprite.play("dead")
	# Connect to animation finished signal to stop looping
	if not animated_sprite.animation_finished.is_connected(_on_dead_animation_finished):
		animated_sprite.animation_finished.connect(_on_dead_animation_finished)

func _on_dead_animation_finished():
	# Stop the animation and keep it on the last frame
	animated_sprite.stop()
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("dead") - 1
