extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

const SPEED = 140.0
const JUMP_VELOCITY = -400.0
var is_dead = false
var is_in_dialogue = false

# Player identification method for NPCs
func player():
	return true

func _physics_process(delta: float) -> void:
	# Don't process movement or animations if dead or in dialogue
	if is_dead or is_in_dialogue:
		# Force idle animation during dialogue
		if is_in_dialogue and not is_dead:
			animated_sprite.play("idle")
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if (Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump")) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	
	update_animation()

func update_animation():
	if not is_on_floor():
		animated_sprite.play("jump")
	elif abs(velocity.x) > 0.1 and is_on_floor():
		animated_sprite.play("move")
		if velocity.x < 0:
			animated_sprite.flip_h = true
		elif velocity.x > 0:
			animated_sprite.flip_h = false
	else:
		animated_sprite.play("idle")

func die():
	is_dead = true
	animated_sprite.play("dead")
	if not animated_sprite.animation_finished.is_connected(_on_dead_animation_finished):
		animated_sprite.animation_finished.connect(_on_dead_animation_finished)

func _on_dead_animation_finished():
	animated_sprite.stop()
	animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("dead") - 1
