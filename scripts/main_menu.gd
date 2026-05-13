extends Control



var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440)
]




func _ready():
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/OptionsButton.pressed.connect(_on_options_button_pressed)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)
	
	
	$OptionsPanel.visible=false
	
	$OptionsPanel/VBoxContainer/MusicSlider.value_changed.connect(_on_music_changed)
	$OptionsPanel/VBoxContainer/SFXSlider.value_changed.connect(_on_sfx_changed)
	$OptionsPanel/VBoxContainer/ResolutionOption.item_selected.connect(_on_resolution_selected)
	$OptionsPanel/VBoxContainer/WindowModeOption.item_selected.connect(_on_window_mode_selected)
	$OptionsPanel/VBoxContainer/CloseButton.pressed.connect(_on_close_options)
	
	_setup_resolution_options()
	_setup_window_mode_options()



func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/battle.tscn")





func _on_options_button_pressed():
	$OptionsPanel.visible=true


func _on_exit_pressed():
	get_tree().quit()


func _on_close_options():
	$OptionsPanel.visible = false


func _setup_resolution_options():
	var option_button = $OptionsPanel/VBoxContainer/ResolutionOption
	option_button.clear() 
	for res in resolutions:
		option_button.add_item(str(res.x) + " x " + str(res.y))


func _setup_window_mode_options():
	var option_button = $OptionsPanel/VBoxContainer/WindowModeOption
	option_button.clear()
	option_button.add_item("Pencereli")     
	option_button.add_item("Tam Ekran")     


func _on_music_changed(value: float):
	var bus_index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_sfx_changed(value: float):
	var bus_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))


func _on_resolution_selected(index: int):
	var selected = resolutions[index]
	DisplayServer.window_set_size(selected)

func _on_window_mode_selected(index: int):
	if index == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
