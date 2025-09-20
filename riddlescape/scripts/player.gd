extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 130.0
const JUMP_VELOCITY = -400.0

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_up") and is_on_floor():
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
