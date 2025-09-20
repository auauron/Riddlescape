extends CharacterBody2D

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
	print("DialogueArea entered by: ", body.name)
	if body.has_method("player"):
		print("Player detected! Starting dialogue...")
		player = body
		print("About to call start_interaction()...")
		start_interaction()
		print("start_interaction() completed")
	else:
		print("Not a player - no player() method")

func _on_dialogue_area_body_exited(body: Node2D) -> void:
	print("DialogueArea exited by: ", body.name)
	if body.has_method("player"):
		end_conversation()

func find_dialogue_ui():
	# Look for dialogue UI in the scene tree
	var root = get_tree().current_scene
	print("NPC ", name, " searching for dialogue UI from root: ", root.name)
	
	# Determine which dialogue UI this NPC should use based on its name
	var target_dialogue_name = "AiDialogue"
	if name == "AI_NPC1":
		target_dialogue_name = "AiDialogue1"
	elif name == "AI_NPC2":
		target_dialogue_name = "AiDialogue2"
	elif name == "AI_NPC3":
		target_dialogue_name = "AiDialogue3"
	
	print("NPC ", name, " looking for dialogue UI: ", target_dialogue_name)
	
	# Search for the specific dialogue UI for this NPC
	dialogue_ui = find_child_recursive(root, target_dialogue_name)
	if dialogue_ui:
		print("Found specific dialogue UI: ", dialogue_ui.name, " - Type: ", dialogue_ui.get_class())
		# Verify it has the required method
		if dialogue_ui.has_method("start_dialogue"):
			print("Dialogue UI ", target_dialogue_name, " has start_dialogue method - OK!")
			return
		else:
			print("ERROR: Dialogue UI ", target_dialogue_name, " found but missing start_dialogue method!")
			dialogue_ui = null
	
	print("Specific dialogue search failed. Trying fallback to generic AiDialogue...")
	# Fallback to generic AiDialogue if specific one not found
	dialogue_ui = find_child_recursive(root, "AiDialogue")
	if dialogue_ui:
		print("Found fallback AiDialogue UI: ", dialogue_ui.name, " - Type: ", dialogue_ui.get_class())
		if dialogue_ui.has_method("start_dialogue"):
			print("Fallback AiDialogue UI has start_dialogue method - OK!")
			return
		else:
			dialogue_ui = null
	
	print("ERROR: No dialogue UI found for NPC ", name, "!")

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
	print("Starting interaction...")
	is_in_conversation = true
	# Disable player movement during dialogue
	if player and player.has_method("set"):
		player.is_in_dialogue = true
	
	# Ensure we have a valid dialogue UI
	if not dialogue_ui or not dialogue_ui.has_method("start_dialogue"):
		print("No valid dialogue UI - searching...")
		find_dialogue_ui()
	
	if dialogue_ui and dialogue_ui.has_method("start_dialogue"):
		print("Opening dialogue UI: ", dialogue_ui.name)
		dialogue_ui.start_dialogue(self)
		# Connect to dialogue closed signal to resume movement
		if dialogue_ui.has_signal("dialogue_closed") and not dialogue_ui.dialogue_closed.is_connected(_on_dialogue_closed):
			dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)
	else:
		print("ERROR: Could not find valid dialogue UI with start_dialogue method!")
		# Fallback - end conversation
		is_in_conversation = false
		if player and player.has_method("set"):
			player.is_in_dialogue = false

func send_to_ai(message: String):
	print("send_to_ai called with message: ", message)
	last_player_message = message.to_lower().strip_edges()
	if not http_request:
		print("ERROR: HTTP request not initialized!")
		return
	
	var headers = ["Content-Type: application/json"]
	# Send the player message with NPC identifier for specific riddles
	var npc_prompt = "NPC_ID:" + name + " PLAYER_MESSAGE:" + message
	var json_body = JSON.stringify({"prompt": npc_prompt})
	
	print("Sending request to: ", AI_SERVER_URL)
	print("Request body: ", json_body)
	var error = http_request.request(AI_SERVER_URL, headers, HTTPClient.METHOD_POST, json_body)
	
	if error != OK:
		print("ERROR: Failed to send request to AI server. Error code: ", error)
		if dialogue_ui:
			dialogue_ui.display_ai_response("Sorry, I can't connect to the AI server right now.")
	else:
		print("Request sent successfully, waiting for response...")

func _on_ai_response_received(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	print("Received AI response. Code: ", response_code, " Body length: ", body.size())
	var body_string = body.get_string_from_utf8()
	print("Response body: ", body_string)
	
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body_string)
		
		if parse_result == OK:
			var response_data = json.data
			print("Parsed JSON data: ", response_data)
			if response_data.has("response"):
				var ai_response = response_data["response"]
				print("AI Response: ", ai_response)
				
				# Check if puzzle is solved
				print("Checking for PUZZLE_SOLVED token in response...")
				var response_lower = ai_response.to_lower()
				
				if ai_response.contains("<PUZZLE_SOLVED>"):
					print("🎉 PUZZLE SOLVED TOKEN FOUND! Triggering NPC death...")
					# Remove the token from the displayed message
					var clean_response = ai_response.replace("<PUZZLE_SOLVED>", "")
					if dialogue_ui:
						dialogue_ui.display_ai_response(clean_response)
					# Trigger death sequence after a short delay
					call_deferred("trigger_death_sequence")
				elif (response_lower.contains("correct") or response_lower.contains("well done") or 
					  response_lower.contains("congratulations") or response_lower.contains("you have bested") or
					  response_lower.contains("my duty is done") or response_lower.contains("puzzle solved") or
					  response_lower.contains("you win") or response_lower.contains("victory") or
					  response_lower.contains("duty is complete") or response_lower.contains("ancient duty") or
					  response_lower.contains("duty ends") or response_lower.contains("my duty") or
					  (response_lower.contains("correct") and response_lower.contains("echo")) or
					  (last_player_message.contains("echo") and response_lower.contains("correct"))):
					print("🎉 PUZZLE SOLVED detected by success keywords! Triggering NPC death...")
					print("Player said: '", last_player_message, "' and AI responded with success indicators")
					if dialogue_ui:
						dialogue_ui.display_ai_response(ai_response)
					call_deferred("trigger_death_sequence")
				else:
					# Normal response
					if dialogue_ui:
						dialogue_ui.display_ai_response(ai_response)
					else:
						print("ERROR: No dialogue UI available to display response")
			else:
				print("ERROR: No 'response' field in AI server response")
				print("Available fields: ", response_data.keys())
		else:
			print("ERROR: Failed to parse JSON response from AI server")
			print("Parse error: ", parse_result)
	else:
		print("ERROR: AI server returned error code: ", response_code)
		if dialogue_ui:
			dialogue_ui.display_ai_response("The riddle guardian seems distracted... (Server error)")
		else:
			print("ERROR: No dialogue UI available to display error message")

func end_conversation():
	# Conversation ended
	is_in_conversation = false
	# Re-enable player movement
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
	print("Starting NPC death sequence...")
	
	# IMMEDIATELY stop all movement and processing
	is_dead = true  # Mark as dead to stop all movement
	is_in_conversation = true  # Keep movement disabled permanently
	velocity = Vector2.ZERO
	set_physics_process(false)  # Stop physics processing immediately
	set_process(false)  # Stop regular processing too
	
	# Close dialogue after a brief delay to let player read the final message
	await get_tree().create_timer(2.0).timeout
	
	# Close dialogue and end conversation
	if dialogue_ui:
		dialogue_ui.close_dialogue()
	end_conversation()
	
	if animated_sprite:
		print("Playing death animation...")
		animated_sprite.play("dead")
		# Connect to animation finished signal if not already connected
		if not animated_sprite.animation_finished.is_connected(_on_death_animation_finished):
			animated_sprite.animation_finished.connect(_on_death_animation_finished)
	else:
		print("ERROR: No animated sprite found for death animation")

func _on_death_animation_finished():
	print("Death animation finished - starting fire phase...")
	# Stop the animation and keep it on the last frame briefly
	animated_sprite.stop()
	if animated_sprite.sprite_frames.has_animation("dead"):
		var frame_count = animated_sprite.sprite_frames.get_frame_count("dead")
		if frame_count > 0:
			animated_sprite.frame = frame_count - 1
	
	# Wait a moment then start fire phase
	await get_tree().create_timer(1.0).timeout
	start_fire_phase()

func start_fire_phase():
	print("Phase 2: Starting fire animation...")
	
	# Disable collision immediately so player can pass through
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	
	# Disable dialogue area so no more interactions
	if has_node("DialogueArea/DialogueCollision"):
		$DialogueArea/DialogueCollision.disabled = true
	
	# Create a static fire effect at the current position
	create_static_fire_effect()
	
	# Hide the NPC immediately so only the fire shows
	animated_sprite.visible = false

func create_static_fire_effect():
	print("Creating static fire effect at death location...")
	
	# Create a new AnimatedSprite2D for the fire effect
	var fire_sprite = AnimatedSprite2D.new()
	fire_sprite.sprite_frames = animated_sprite.sprite_frames
	fire_sprite.position = animated_sprite.global_position
	
	# Fix the fire orientation - remove the upside down rotation and scaling
	fire_sprite.rotation = 0  # No rotation
	fire_sprite.scale = Vector2(2, 2)  # Normal scale, not flipped
	
	# Add the fire sprite to the scene (not as child of NPC)
	get_tree().current_scene.add_child(fire_sprite)
	
	# Play fire animation if it exists
	if fire_sprite.sprite_frames.has_animation("fire"):
		print("Playing static fire animation...")
		fire_sprite.play("fire")
		
		# Set up timer to fade out the static fire
		var fire_timer = Timer.new()
		add_child(fire_timer)
		fire_timer.wait_time = 2.0 
		fire_timer.one_shot = true
		fire_timer.timeout.connect(func(): start_fade_out_static_fire(fire_sprite))
		fire_timer.start()
	else:
		print("No fire animation found, removing fire sprite")
		fire_sprite.queue_free()
		complete_disappearance()

func start_fade_out_static_fire(fire_sprite: AnimatedSprite2D):
	print("Fading out static fire...")
	# Create fade out effect for the static fire
	var tween = create_tween()
	tween.tween_property(fire_sprite, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(func(): 
		fire_sprite.queue_free()
		complete_disappearance()
	)


func complete_disappearance():
	print("Phase 3: NPC disappearing completely...")
	s
	# Make completely invisible and disable all interactions
	visible = false
	set_physics_process(false)
	set_process(false)
	
	# Optional: Remove from scene entirely
	# queue_free()  # Uncomment this if you want to completely remove the NPC
	
	print("NPC has disappeared from the map!")
