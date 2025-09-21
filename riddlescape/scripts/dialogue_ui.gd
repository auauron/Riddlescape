extends Control

@onready var name_label = $NinePatchRect/Name
@onready var dialogue_text = $NinePatchRect/DialogueText
@onready var input_field = $NinePatchRect/InputField
@onready var send_button = $NinePatchRect/SendButton
@onready var close_button = $NinePatchRect/CloseButton
@onready var audio_player = $AudioStreamPlayer

var current_npc = null
var is_dialogue_active = false
var is_typing = false
var typing_timer: Timer
var current_text = ""
var target_text = ""
var typing_speed = 0.025  # Time between each character
var word_sound_timer: Timer
var sound_alternate = false  # Track if we should play reversed sound
var sound_stop_timer: Timer  # Timer to stop sound at specific time
var fade_timer: Timer  # Timer for fade effect
var is_fading = false

var sfx: AudioStream

signal dialogue_closed

func _ready():
	print("Dialogue UI _ready() called")
	# Hide dialogue initially
	visible = false
	print("Initial visibility set to false")
	
	# Load talking sound
	var talking_sound = load("res://assets/sprites/sound/talking.wav")
	if talking_sound:
		audio_player.stream = talking_sound
		print("Talking sound loaded successfully")
	else:
		print("ERROR: Could not load talking.wav")
	
	# Create typing timer
	typing_timer = Timer.new()
	typing_timer.wait_time = typing_speed
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(typing_timer)
	
	# Create word sound timer
	word_sound_timer = Timer.new()
	word_sound_timer.wait_time = 0.01  # Check every 0.01 seconds for sound restart
	word_sound_timer.timeout.connect(_on_word_sound_timer_timeout)
	add_child(word_sound_timer)
	
	# Create sound stop timer
	sound_stop_timer = Timer.new()
	sound_stop_timer.one_shot = true
	sound_stop_timer.timeout.connect(_on_sound_stop_timer_timeout)
	add_child(sound_stop_timer)
	
	# Create fade timer for smooth ending
	fade_timer = Timer.new()
	fade_timer.wait_time = 0.02  # Update fade every 0.02 seconds
	fade_timer.timeout.connect(_on_fade_timer_timeout)
	add_child(fade_timer)
	
	# Debug UI element finding
	print("Looking for UI elements...")
	print("name_label: ", name_label)
	print("dialogue_text: ", dialogue_text)
	print("input_field: ", input_field)
	print("send_button: ", send_button)
	print("close_button: ", close_button)
	print("audio_player: ", audio_player)
	
	# Connect button signals
	if send_button:
		send_button.pressed.connect(_on_send_button_pressed)
		print("Send button connected")
	else:
		print("ERROR: Send button not found!")
	
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
		print("Close button connected")
	else:
		print("ERROR: Close button not found!")
	
	# Ensure input field is properly configured
	if input_field:
		input_field.editable = true
		input_field.selecting_enabled = true
		input_field.context_menu_enabled = true
		print("Input field configured")
	else:
		print("ERROR: Input field not found!")

func _input(event):
	if not is_dialogue_active:
		return
		
	# Close dialogue with Escape
	if event.is_action_pressed("ui_cancel"):
		close_dialogue()
		get_viewport().set_input_as_handled()
		return
	
	# Manual override: Press K to force NPC death (for testing)
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_K):
		print("MANUAL OVERRIDE: Forcing NPC death...")
		if current_npc and current_npc.has_method("trigger_death_sequence"):
			current_npc.trigger_death_sequence()
		get_viewport().set_input_as_handled()
		return
	
	# Send message with Enter (only if input field has focus and has text)
	if event.is_action_pressed("ui_accept") and input_field and input_field.has_focus() and input_field.text.strip_edges() != "":
		_on_send_button_pressed()
		get_viewport().set_input_as_handled()
		return
	
	# Ensure input field gets focus when clicking anywhere in dialogue
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if input_field:
			call_deferred("_focus_input_field")
			get_viewport().set_input_as_handled()
		return

func start_dialogue(npc):
	print("start_dialogue called! NPC: ", npc.name if npc else "null")
	current_npc = npc
	is_dialogue_active = true

	
	print("Setting dialogue visible...")
	visible = true
	print("Dialogue visible set to: ", visible)
	print("Dialogue position: ", position)
	print("Dialogue size: ", size)
	
	# Set NPC name
	if name_label:
		name_label.text = "Riddle Guardian"
		print("Name label set")
	else:
		print("ERROR: name_label not found!")
	
	# Set initial dialogue
	if dialogue_text:
		dialogue_text.text = "Greetings, brave traveler! I am the Riddle Guardian of this ancient dungeon. To pass through these halls, you must prove your wit with riddles and puzzles. Are you ready to test your mind against the mysteries I guard?"
		print("Dialogue text set")
	else:
		print("ERROR: dialogue_text not found!")
	
	# Focus input field with a small delay to ensure UI is ready
	if input_field:
		print("Input field found, focusing...")
		call_deferred("_focus_input_field")
	else:
		print("ERROR: input_field not found!")

func _focus_input_field():
	if input_field:
		print("Attempting to focus input field...")
		# Force enable input
		input_field.editable = true
		input_field.selecting_enabled = true
		input_field.context_menu_enabled = true
		# Clear any existing text and focus
		input_field.text = ""
		input_field.grab_focus()
		input_field.caret_column = 0
		print("Input field focused. Has focus: ", input_field.has_focus())
		print("Input field editable: ", input_field.editable)
		
		# Connect to input field signals for debugging
		if not input_field.text_changed.is_connected(_on_input_text_changed):
			input_field.text_changed.connect(_on_input_text_changed)
		if not input_field.text_submitted.is_connected(_on_input_text_submitted):
			input_field.text_submitted.connect(_on_input_text_submitted)
		if not input_field.gui_input.is_connected(_on_input_gui_input):
			input_field.gui_input.connect(_on_input_gui_input)

func _on_input_gui_input(event: InputEvent):
	print("Input field received GUI input: ", event)

func _on_input_text_changed(new_text: String):
	print("Input text changed to: ", new_text)

func _on_input_text_submitted(text: String):
	print("Input text submitted: ", text)
	_on_send_button_pressed()

func _on_close_button_pressed():
	print("Close button pressed!")
	close_dialogue()

func close_dialogue():
	is_dialogue_active = false
	visible = false
	current_npc = null
	
	# Clear input
	if input_field:
		input_field.text = ""
	
	# Emit signal
	dialogue_closed.emit()

func _on_send_button_pressed():
	print("Send button pressed!")
	if not input_field or input_field.text.strip_edges() == "":
		print("Input field is empty or null")
		return
	
	var player_message = input_field.text.strip_edges()
	print("Player message: ", player_message)
	input_field.text = ""
	
	# Show player message
	if dialogue_text:
		dialogue_text.text += "\n\nYou: " + player_message
		print("Added player message to dialogue")
	
	# Send to AI server
	if current_npc and current_npc.has_method("send_to_ai"):
		print("Sending message to NPC...")
		current_npc.send_to_ai(player_message)
	else:
		print("ERROR: No current NPC or NPC doesn't have send_to_ai method")
	
	# Refocus input field after sending
	call_deferred("_focus_input_field")

func display_ai_response(response: String):
	if dialogue_text:
		# Store the current text and prepare for typing effect
		current_text = dialogue_text.text + "\n\nRiddle Guardian: "
		target_text = current_text + response
		
		# Start typing effect
		start_typing_effect()

func start_typing_effect():
	is_typing = true
	typing_timer.start()
	word_sound_timer.start()

func _on_typing_timer_timeout():
	if current_text.length() < target_text.length():
		# Add next character
		current_text += target_text[current_text.length()]
		dialogue_text.text = current_text
		
		# Auto-scroll to bottom if possible
		if dialogue_text.has_method("scroll_to_line"):
			dialogue_text.scroll_to_line(dialogue_text.get_line_count())
	else:
		# Finished typing
		is_typing = false
		typing_timer.stop()
		word_sound_timer.stop()
		# Start fade out when typing is complete
		if audio_player.playing and not is_fading:
			is_fading = true
			fade_timer.start()
			print("Typing finished, starting fade out...")

func _on_word_sound_timer_timeout():
	# Keep playing sound continuously during typing
	if is_typing and audio_player and audio_player.stream and not is_fading:
		# Only restart if sound has finished playing
		if not audio_player.playing:
			# Reset volume to full
			audio_player.volume_db = 0.0
			
			# Alternate between normal and reversed playback
			if sound_alternate:
				audio_player.pitch_scale = -1.0  # Reverse playback
				audio_player.play()  # Start from beginning but play backwards
				print("Playing talking sound REVERSED continuously")
			else:
				audio_player.pitch_scale = 1.0   # Normal playback
				audio_player.play()  # Start playing from beginning
				print("Playing talking sound NORMAL continuously")
			
			# Toggle for next sound
			sound_alternate = !sound_alternate

func _on_sound_stop_timer_timeout():
	# This function is no longer used for continuous playback
	pass

func _on_fade_timer_timeout():
	if audio_player.playing and is_fading:
		# Gradually reduce volume
		audio_player.volume_db -= 3.0  # Reduce by 3dB each step
		
		# Stop when volume is very low or we've reached 0.67s total
		if audio_player.volume_db <= -30.0:
			audio_player.stop()
			fade_timer.stop()
			is_fading = false
			print("Audio faded out smoothly")
