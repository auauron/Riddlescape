extends CharacterBody2D

# Signal to notify when the NPC is defeated
signal npc_defeated

const speed = 60
const MOVE_DISTANCE = 48  
const AI_SERVER_URL = "http://localhost:3000/ai"

var direction = 1
var start_position: float
var left_boundary: float
var right_boundary: float
var player
var dialogue_ui = null
var http_request: HTTPRequest
var is_in_conversation = false
var last_player_message = ""
var is_dead = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	start_position = position.x
	left_boundary = start_position - MOVE_DISTANCE
	right_boundary = start_position + MOVE_DISTANCE
	
	# Create HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_ai_response_received)
	
	# Find dialogue UI in the scene tree
	call_deferred("find_dialogue_ui")

func _process(_delta: float) -> void:
	# Don't move if dead, in conversation, or physics is disabled
	if is_dead or is_in_conversation:
		velocity.x = 0
		velocity.y = 0
		move_and_slide()
		return
		
	if position.x >= right_boundary:
		direction = -1
	elif position.x <= left_boundary:
		direction = 1
	if direction == 1:
		animated_sprite.flip_h = true  
	else:
		animated_sprite.flip_h = false 
		
	velocity.x = direction * speed
	velocity.y = 0  # No vertical movement
	move_and_slide()

# Dialogue area detection - triggers chat
func _on_dialogue_area_body_entered(body: Node2D) -> void:
	if body.has_method("player"):
		player = body
		start_interaction()

func _on_dialogue_area_body_exited(body: Node2D) -> void:
	if body.has_method("player"):
		end_conversation()

func find_dialogue_ui():
	var root = get_tree().current_scene
	
	# Determine which dialogue UI this NPC should use based on its name
	var target_dialogue_name = "AiDialogue"
	if name == "AI_NPC1":
		target_dialogue_name = "AiDialogue1"
	elif name == "AI_NPC2":
		target_dialogue_name = "AiDialogue2"
	elif name == "AI_NPC3":
		target_dialogue_name = "AiDialogue3"
	elif name == "AI_NPC4":
		target_dialogue_name = "AiDialogue4"
	elif name == "AI_NPC5":
		target_dialogue_name = "AiDialogue5"
	
	# Search for the specific dialogue UI for this NPC
	dialogue_ui = find_child_recursive(root, target_dialogue_name)
	if dialogue_ui and dialogue_ui.has_method("start_dialogue"):
		return
	
	# Fallback to generic AiDialogue if specific one not found
	dialogue_ui = find_child_recursive(root, "AiDialogue")
	if not dialogue_ui or not dialogue_ui.has_method("start_dialogue"):
		dialogue_ui = null

func find_node_with_method(node: Node, method_name: String) -> Node:
	# Check if this node has the method
	if node.has_method(method_name):
		return node
	# Recursively check all children
	for child in node.get_children():
		var result = find_node_with_method(child, method_name)
		if result:
			return result
	return null

func find_child_recursive(node: Node, child_name: String) -> Node:
	if node.name == child_name:
		return node
	for child in node.get_children():
		var result = find_child_recursive(child, child_name)
		if result:
			return result
	return null

func start_interaction():
	is_in_conversation = true
	if player and player.has_method("set"):
		player.is_in_dialogue = true
		
		if player.has_method("connect_to_npc"):
			player.connect_to_npc(self)
	
	if dialogue_ui:
		dialogue_ui.start_dialogue(self)
	else:
		is_in_conversation = false
		if player and player.has_method("set"):
			player.is_in_dialogue = false

func send_to_ai(message: String):
	last_player_message = message.to_lower().strip_edges()
	if not http_request:
		return
	
	var headers = ["Content-Type: application/json"]
	var npc_prompt = "NPC_ID:" + name + " PLAYER_MESSAGE:" + message
	var json_body = JSON.stringify({"prompt": npc_prompt})
	
	var error = http_request.request(AI_SERVER_URL, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK and dialogue_ui:
		dialogue_ui.display_ai_response("Sorry, I can't connect to the AI server right now.")

func _on_ai_response_received(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_string = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body_string)
		
		if parse_result == OK:
			var response_data = json.data
			if response_data.has("response"):
				var ai_response = response_data["response"]
				var response_lower = ai_response.to_lower()
				
				if ai_response.contains("<PUZZLE_SOLVED>"):
					var clean_response = ai_response.replace("<PUZZLE_SOLVED>", "")
					if dialogue_ui:
						dialogue_ui.display_ai_response(clean_response)
					call_deferred("trigger_death_sequence")
				elif (response_lower.contains("correct") or response_lower.contains("well done") or 
					  response_lower.contains("congratulations") or response_lower.contains("you have bested") or
					  response_lower.contains("my duty is done") or response_lower.contains("puzzle solved") or
					  response_lower.contains("you win") or response_lower.contains("victory") or
					  response_lower.contains("duty is complete") or response_lower.contains("ancient duty") or
					  response_lower.contains("duty ends") or response_lower.contains("my duty") or
					  (response_lower.contains("correct") and response_lower.contains("echo")) or
					  (last_player_message.contains("echo") and response_lower.contains("correct"))):
					if dialogue_ui:
						dialogue_ui.display_ai_response(ai_response)
					call_deferred("trigger_death_sequence")
				else:
					if dialogue_ui:
						dialogue_ui.display_ai_response(ai_response)
	else:
		if dialogue_ui:
			dialogue_ui.display_ai_response("The riddle guardian seems distracted... (Server error)")

func end_conversation():
	is_in_conversation = false

	if player and player.has_method("set"):
		player.is_in_dialogue = false
	if dialogue_ui:
		dialogue_ui.close_dialogue()

func _on_dialogue_closed():
	# Resume movement when dialogue is closed
	is_in_conversation = false
	# Re-enable player movement
	if player and player.has_method("set"):
		player.is_in_dialogue = false

func trigger_death_sequence():
	await get_tree().create_timer(3.0).timeout
	
	if dialogue_ui:
		dialogue_ui.close_dialogue()
	end_conversation()
	
	await get_tree().create_timer(0.5).timeout
	
	if player:
		player.attack_npc()
	
	is_dead = true
	is_in_conversation = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
	
	await get_tree().create_timer(1.0).timeout
	
	if dialogue_ui:
		dialogue_ui.close_dialogue()
	end_conversation()
	
	if animated_sprite:
		animated_sprite.play("dead")
		
		if not animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
			animated_sprite.animation_finished.connect(_on_death_animation_finished)

func _on_death_animation_finished():
	animated_sprite.stop()
	if animated_sprite.sprite_frames.has_animation("dead"):
		var frame_count = animated_sprite.sprite_frames.get_frame_count("dead")
		if frame_count > 0:
			animated_sprite.frame = frame_count - 1
	
	await get_tree().create_timer(1.0).timeout
	start_fire_phase()

func start_fire_phase():
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	if has_node("DialogueArea/DialogueCollision"):
		$DialogueArea/DialogueCollision.disabled = true
	
	create_static_fire_effect()
	animated_sprite.visible = false

func create_static_fire_effect():
	var fire_sprite = AnimatedSprite2D.new()
	fire_sprite.sprite_frames = animated_sprite.sprite_frames
	fire_sprite.position = animated_sprite.global_position
	fire_sprite.rotation = 0
	fire_sprite.scale = Vector2(2, 2)
	
	get_tree().current_scene.add_child(fire_sprite)
	
	if fire_sprite.sprite_frames.has_animation("fire"):
		fire_sprite.play("fire")
		
		var fire_timer = Timer.new()
		add_child(fire_timer)
		fire_timer.wait_time = 2.0 
		fire_timer.one_shot = true
		fire_timer.timeout.connect(func(): start_fade_out_static_fire(fire_sprite))
		fire_timer.start()
	else:
		fire_sprite.queue_free()
		complete_disappearance()

func start_fade_out_static_fire(fire_sprite: AnimatedSprite2D):
	var tween = create_tween()
	tween.tween_property(fire_sprite, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(func(): 
		fire_sprite.queue_free()
		complete_disappearance()
	)


func complete_disappearance():
	visible = false
	set_physics_process(false)
	set_process(false)
