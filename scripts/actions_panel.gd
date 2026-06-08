extends NinePatchRect
class_name ActionsPanel

@export var parent: BattleScene

func _ready() -> void:
	_setup_button_hover($VBoxContainer/AttackButton)
	_setup_button_hover($VBoxContainer/DefendButton)
	_setup_button_hover($VBoxContainer/HealButton)
	_setup_button_hover($VBoxContainer/RunButton)


func _setup_button_hover(button:Button)-> void:
	
	var left_divider = button.get_node("LeftDivider")
	var right_divider = button.get_node("RightDivider")
	
	left_divider.modulate.a = 0.0
	right_divider.modulate.a = 0.0
	
	button.mouse_entered.connect(func(): _animate_dividers(left_divider, right_divider, true))
	button.mouse_exited.connect(func(): _animate_dividers(left_divider, right_divider, false))
	button.button_down.connect(func(): _animate_dividers(left_divider, right_divider, true))
	button.button_up.connect(func(): _animate_dividers(left_divider, right_divider, button.is_hovered()))
	
	

func _animate_dividers(left: Control, right: Control, is_hover: bool) -> void:
	var target_alpha: float = 1.0 if is_hover else 0.0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(left, "modulate:a", target_alpha, 0.2)
	tween.tween_property(right, "modulate:a", target_alpha, 0.2)
	


func _on_run_button_pressed():
	parent.actions_panel.hide()
	parent.add_history_entry("Got away safely!")
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_attack_button_pressed() -> void:
	parent.actions_panel.hide()
	
	parent.question_popup.ask_question()
	var result = await parent.question_popup.question_answered
	var is_correct = result[0]
	var explanation = result[1]
	
	if not is_correct:
		
		parent.information_popup.show_info(explanation)
		await parent.information_popup.info_closed
		parent.add_history_entry("[color=red]Wrong answer! Your attack missed![/color]")
		await get_tree().create_timer(0.6).timeout
		parent.enemy_turn()
		return
	
	parent.add_history_entry("You swing your piercing sword!")
	await get_tree().create_timer(0.3).timeout
	
	parent.current_enemy_health = max(0, parent.current_enemy_health - GameState.damage)
	parent.set_health(parent.get_node("EnemyContainer/EnemyHealthBar"), parent.current_enemy_health, parent.enemy.health)
	
	parent.player.play("attack")
	await parent.play_enemy_animation("hurt")
	parent.enemy_animations.play("enemy_damaged")
	await parent.enemy_animations.animation_finished
	parent.player.play("idle")
	
	parent.add_history_entry("[color=green]You've dealt %d damage to the %s![/color]" % [GameState.damage, parent.enemy.name])
	await get_tree().create_timer(0.4).timeout
	
	if parent.current_enemy_health == 0:
		GameState.coins += parent.enemy.reward
		parent.add_history_entry("[b]%s was defeated. You earned %d coins![/b]" % [parent.enemy.name, parent.enemy.reward])
		await get_tree().create_timer(0.8).timeout
		
		
		var enemy_sprite=parent.get_node("EnemyContainer/Enemy")
		var death_anim =parent.enemy.name + "_death"
		if enemy_sprite.sprite_frames.has_animation(death_anim):
			enemy_sprite.play(death_anim)
			await enemy_sprite.animation_finished
		
		
		parent.enemy_animations.play("enemy_death")
		await parent.enemy_animations.animation_finished
		
		await parent.player_exit()
		
		parent.shop_ui.reroll_shop()
		parent.shop_ui.show()
		
		await parent.shop_ui.shop_closed
		
		parent.spawn_enemy()
		return
	
	parent.enemy_turn()


func _on_defend_button_pressed() -> void:
	self.hide()
	
	parent.question_popup.ask_question()
	var result = await parent.question_popup.question_answered
	var is_correct = result[0]
	var explanation = result[1]
	
	if not is_correct:
		parent.information_popup.show_info(explanation)
		await parent.information_popup.info_closed
		parent.add_history_entry("[color=red]Wrong answer! Your defence failed![/color]")
		await get_tree().create_timer(0.6).timeout
		parent.enemy_turn()
		return
	
	parent.is_defending = true
	
	parent.add_history_entry("You prepare defensively!")
	await get_tree().create_timer(0.4).timeout
	
	parent.enemy_turn()


func _on_heal_button_pressed() -> void:
	
	if parent.heal_used_this_turn:
		parent.add_history_entry("[color=yellow]You can only use 1 heal per turn![/color]")
		return
	if GameState.potion_count<=0:
		parent.add_history_entry("[color=yellow]No potion available![/color]")
		return
	if GameState.current_health>=GameState.max_health:
		parent.add_history_entry("[color=yellow]Your health is already full![/color]")
		return
	
	parent.heal_used_this_turn = true
	
	_fade_actions_panel(false)
	await get_tree().create_timer(0.25).timeout
	
	var healed_amount = GameState.use_potion()
	parent.current_player_health = GameState.current_health
	
	parent.player.play("heal")
	parent.set_health(parent.get_node("PlayerContainer/PlayerHealthBar"), GameState.current_health, GameState.max_health)
	await parent.player.animation_finished
	parent.player.play("idle")
	
	
	parent.add_history_entry("[color=green]You healed %d HP![/color]" % healed_amount)
	
	
	_fade_actions_panel(true)


func _fade_actions_panel(fade_in: bool) -> void:
	var target_alpha: float = 1.0 if fade_in else 0.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", target_alpha, 0.25)
