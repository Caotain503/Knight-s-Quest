extends Control






func _ready():
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/OptionsButton.pressed.connect(_on_options_button_pressed)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit_pressed)
	
	
	$OptionsPanel.visible=false
	
	$OptionsPanel/Control/MusicSlider.value_changed.connect(_on_music_changed)
	$OptionsPanel/Control/SFXSlider.value_changed.connect(_on_sfx_changed)
	$OptionsPanel/Control/WindowModeOption.item_selected.connect(_on_window_mode_selected)
	$OptionsPanel/Control/CloseButton.pressed.connect(_on_close_options)
	
	_setup_window_mode_options()
	
	# Hover animasyonları için sinyalleri bağla
	_setup_button_hover($VBoxContainer/StartButton)
	_setup_button_hover($VBoxContainer/OptionsButton)
	_setup_button_hover($VBoxContainer/ExitButton)
	_setup_button_hover($OptionsPanel/Control/CloseButton, true)
	
	



func _setup_button_hover(button: Button,animate_label:bool=false) -> void:
	var hover_texture = button.get_node("HoverTexture")
	var label = button.get_node("ButtonLabel")
	
	hover_texture.modulate.a = 0.0
	# Butona başlangıç font rengini ata (tween'in çalışması için gerekli)
	
	
	button.mouse_entered.connect(func(): _animate_button(label, hover_texture, true,animate_label))
	button.mouse_exited.connect(func(): _animate_button(label, hover_texture, false,animate_label))
	button.button_down.connect(func(): _animate_button(label, hover_texture, true,animate_label))
	button.button_up.connect(func(): _animate_button(label, hover_texture, button.is_hovered(),animate_label))

func _animate_button(label: Label, hover_texture: Control, is_hover: bool,animate_label:bool) -> void:
	var target_alpha: float = 1.0 if is_hover else 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(hover_texture, "modulate:a", target_alpha, 0.25)
	
	if animate_label:
		var target_color: Color = Color(0.0, 0.0, 0.0, 1.0) if is_hover else Color.WHITE
		tween.tween_property(label, "modulate", target_color, 0.25)
	





func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/battle.tscn")





func _on_options_button_pressed():
	_open_options_panel()


func _on_exit_pressed():
	get_tree().quit()


func _on_close_options():
	_close_options_panel()

func _open_options_panel() -> void:
	var panel = $OptionsPanel
	
	# Pivot'u panelin merkezine ayarla (scale ortadan olsun)
	panel.pivot_offset = panel.size / 2
	
	# Başlangıç durumunu ayarla: küçük ve şeffaf
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	panel.visible = true
	
	# Animasyon: tam boyuta ve görünür hale geç
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)


func _close_options_panel() -> void:
	var panel = $OptionsPanel
	
	panel.pivot_offset = panel.size / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	 
	tween.tween_property(panel, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	
	# Animasyon bitince paneli gizle
	await tween.finished
	panel.visible = false











func _setup_window_mode_options():
	var option_button = $OptionsPanel/Control/WindowModeOption
	option_button.clear()
	option_button.add_item("Pencereli")     
	option_button.add_item("Tam Ekran")     


func _on_music_changed(value: float):
	var bus_index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_sfx_changed(value: float):
	var bus_index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))




func _on_window_mode_selected(index: int):
	if index == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	elif index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
