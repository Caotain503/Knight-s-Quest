extends NinePatchRect
class_name ActionsPanel

@export var parent: BattleScene

func _on_run_button_pressed():
	parent.actions_panel.hide()
	parent.add_history_entry("Got away safely!")
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()


func _on_attack_button_pressed() -> void:
	parent.actions_panel.hide()
	
	parent.question_popup.ask_question()
	var is_correct = await parent.question_popup.question_answered
	
	if not is_correct:
		parent.add_history_entry("[color=red]Wrong answer! Your attack missed![/color]")
		await get_tree().create_timer(0.6).timeout
		parent.enemy_turn()
		return
	
	parent.add_history_entry("You swing your piercing sword!")
	await get_tree().create_timer(0.3).timeout
	
	parent.current_enemy_health = max(0, parent.current_enemy_health - GameState.damage)
	parent.set_health(parent.get_node("EnemyContainer/EnemyHealthBar"), parent.current_enemy_health, parent.enemy.health)
	
	parent.player_animations.play("attack")
	await parent.player_animations.animation_finished
	parent.enemy_animations.play("enemy_damaged")
	await parent.enemy_animations.animation_finished
	parent.player_animations.play("idle")
	
	parent.add_history_entry("[color=green]You've dealt %d damage to the %s![/color]" % [GameState.damage, parent.enemy.name])
	await get_tree().create_timer(0.4).timeout
	
	if parent.current_enemy_health == 0:
		GameState.coins += parent.enemy.reward
		parent.add_history_entry("[b]%s was defeated. You earned %d coins![/b]" % [parent.enemy.name, parent.enemy.reward])
		await get_tree().create_timer(0.8).timeout
		
		parent.enemy_animations.play("enemy_death")
		await parent.enemy_animations.animation_finished
		
		parent.player_animations.play("disappear")
		await parent.player_animations.animation_finished
		
		parent.shop_ui.reroll_shop()
		parent.shop_ui.show()
		
		await parent.shop_ui.shop_closed
		
		parent.spawn_enemy()
		return
	
	parent.enemy_turn()


func _on_defend_button_pressed() -> void:
	self.hide()
	
	parent.question_popup.ask_question()
	var is_correct = await parent.question_popup.question_answered
	
	if not is_correct:
		parent.add_history_entry("[color=yellow]Wrong answer! Your defense failed![/color]")
		await get_tree().create_timer(0.6).timeout
		parent.enemy_turn()
		return
	
	parent.is_defending = true
	
	parent.add_history_entry("You prepare defensively!")
	await get_tree().create_timer(0.4).timeout
	
	parent.enemy_turn()
