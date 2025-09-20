extends Area2D

@onready var timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	print("You failed!")
	
	# Call player's die function
	if body.name == "Player":
		body.die()
		print("Starting death timer...")
		timer.start()

func _on_timer_timeout() -> void:
	print("Timer timeout - reloading scene...")
	get_tree().reload_current_scene()
