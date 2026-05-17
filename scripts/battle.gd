@tool
extends Control

signal textlabel_closed
signal question_answered(is_correct: bool)

@onready var text_label: RichTextLabel = $PlayerPanel/TextLabel
@onready var actions_panel: Panel = $ActionsPanel
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var question_popup: Panel = $QuestionPopup
@onready var question_label: RichTextLabel = $QuestionPopup/MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $QuestionPopup/MarginContainer/VBoxContainer/ChoicesContainer
@onready var game_over_ui: GameOverUI = $GameOverUI
@onready var shop_ui: ShopUI = $ShopUI
@onready var enemy_container: VBoxContainer = $EnemyContainer
@onready var player_animations: AnimationPlayer = $PlayerContainer/Player/PlayerAnimations


@export var enemy_pool: Array[BaseEnemy]
@export var enemy: BaseEnemy:
	set(value):
		enemy = value
		
		if not is_node_ready():
			return
		
		if enemy != null:
			set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
			$EnemyContainer/Enemy.play(enemy.name)


var current_player_health: int = 0
var current_enemy_health: int = 0
var is_defending: bool = false
var questions_pool: Array = []
var is_scrolling: bool = false

func _ready() -> void:
	set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
	$EnemyContainer/Enemy.play(enemy.name)
	
	
	if Engine.is_editor_hint():
		return
	
	set_health($PlayerContainer/PlayerHealthBar, GameState.current_health, GameState.max_health)
	
	
	current_player_health = GameState.current_health
	current_enemy_health = enemy.health
	
	var loaded_data = load_json("res://questions/easy.json")
	questions_pool = loaded_data
	
	text_label.text = ""
	text_label.hide()
	actions_panel.hide()
	question_popup.hide()
	
	player_animations.play("appear")
	await player_animations.animation_finished
	player_animations.play("idle")
	
	display_text("A wild [b]%s[/b] appears" % enemy.name)
	await self.textlabel_closed
	actions_panel.show()

func spawn_enemy() -> void:
	enemy = enemy_pool.pick_random()
	$EnemyContainer/EnemyHealthBar.value = enemy.health
	$EnemyContainer/EnemyHealthBar.max_value = enemy.health
	$EnemyContainer/Enemy.play(enemy.name)
	current_enemy_health = enemy.health
	
	player_animations.play("appear")
	await player_animations.animation_finished
	player_animations.play("idle")
	
	animations.play("enemy_appear")
	await animations.animation_finished
	display_text("A wild [b]%s[/b] appears" % enemy.name)
	await self.textlabel_closed
	actions_panel.show()

func set_health(progress_bar: ProgressBar, health: int, max_health: int):
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "HP: %d/%d" % [health, max_health]
	
	var tween = progress_bar.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC) 
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_bar, "value", health, 0.5)

func _input(_event) -> void:
	if Engine.is_editor_hint():
		return
	
	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT)) and text_label.visible and not is_scrolling:
		text_label.hide()
		self.textlabel_closed.emit()

func display_text(text) -> void:
	text_label.show()
	text_label.text = ""
	is_scrolling = true
	for letter in text:
		text_label.text += letter
		await get_tree().create_timer(15 / 1000.0).timeout
	is_scrolling = false

func enemy_turn() -> void:
	display_text("%s launches at you fiercely!" % enemy.name)
	await textlabel_closed
	
	if is_defending:
		is_defending = false
		
		player_animations.play("defend")
		animations.play("mini_shake")
		await animations.animation_finished
		player_animations.play("idle")
		
		display_text("You defended successfully!")
		await textlabel_closed
	else:
		current_player_health = max(0, current_player_health - enemy.damage)
		set_health($PlayerContainer/PlayerHealthBar, current_player_health, GameState.max_health)
		
		player_animations.play("hurt")
		animations.play("camera_shake")
		await animations.animation_finished
		player_animations.play("idle")
		
		if current_player_health == 0:
			game_over_ui.appear()
			return
		
		display_text("%s dealt %d damage!" % [enemy.name, enemy.damage])
		await textlabel_closed
	
	actions_panel.show()


func _on_run_button_pressed():
	actions_panel.hide()
	
	display_text("Got away safely!")
	await textlabel_closed
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


func _on_attack_button_pressed() -> void:
	actions_panel.hide()
	
	ask_question()
	var is_correct = await self.question_answered
	
	if not is_correct:
		display_text("Wrong answer! Your attack missed!")
		await textlabel_closed
		enemy_turn()
		return
	
	display_text("You swing your piercing sword!")
	await textlabel_closed
	
	current_enemy_health = max(0, current_enemy_health - GameState.damage)
	set_health($EnemyContainer/EnemyHealthBar, current_enemy_health, enemy.health)
	
	player_animations.play("attack")
	await player_animations.animation_finished
	animations.play("enemy_damaged")
	await animations.animation_finished
	player_animations.play("idle")
	
	display_text("You've dealt %d damage to the %s!" % [GameState.damage, enemy.name])
	await textlabel_closed
	
	if current_enemy_health == 0:
		GameState.coins += enemy.reward
		display_text("%s was defeated. You earned %d coins!" % [enemy.name, enemy.reward])
		await textlabel_closed
		
		animations.play("enemy_death")
		await animations.animation_finished
		
		player_animations.play("disappear")
		await player_animations.animation_finished
		
		shop_ui.reroll_shop()
		shop_ui.show()
		
		await shop_ui.shop_closed
		
		spawn_enemy()
		
		return
	
	enemy_turn()


func _on_defend_button_pressed() -> void:
	actions_panel.hide()
	
	ask_question()
	var is_correct = await self.question_answered
	
	if not is_correct:
		display_text("Wrong answer! Your attack missed!")
		await textlabel_closed
		enemy_turn()
		return
	
	is_defending = true
	
	display_text("You prepare  defensively!")
	await textlabel_closed
	
	await get_tree().create_timer(0.25).timeout
	
	enemy_turn()

func ask_question():
	if questions_pool.is_empty():
		printerr("No questions loaded! Automatically passing.")
		question_answered.emit(true)
		return
	
	var random_question = questions_pool.pick_random()
	question_label.text = random_question["question"]
	
	for child in choices_container.get_children():
		child.queue_free()
	
	for option in random_question["choices"]:
		var btn = Button.new()
		btn.text = option
		btn.pressed.connect(_on_choice_selected.bind(option, random_question["answer"]))
		choices_container.add_child(btn)
		
	question_popup.show()

func _on_choice_selected(selected_option: String, correct_answer: String) -> void:
	question_popup.hide()
	var is_correct = (selected_option == correct_answer)
	question_answered.emit(is_correct)

func load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Could not open file at ", path)
		return ""
	
	var content = file.get_as_text()
	return JSON.parse_string(content)


func _on_shop_ui_shop_closed() -> void:
	pass # Replace with function body.


func _on_items_button_pressed() -> void:
	pass # Replace with function body.
