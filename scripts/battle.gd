@tool
extends Control
class_name BattleScene


const timed_message_scene: PackedScene = preload("res://scenes/timed_message.tscn")

@onready var actions_panel: NinePatchRect = $ActionsPanel
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var question_popup: QuestionPopup = $QuestionPopup
@onready var question_label: RichTextLabel = $QuestionPopup/MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $QuestionPopup/MarginContainer/VBoxContainer/ChoicesContainer
@onready var game_over_ui: GameOverUI = $GameOverUI
@onready var shop_ui: ShopUI = $ShopUI
@onready var enemy_container: VBoxContainer = $EnemyContainer
@onready var player_animations: AnimationPlayer = $PlayerContainer/Player/PlayerAnimations

@onready var timed_messages: VBoxContainer = $MessagePanel/ScrollContainer/Messages
@onready var message_scroll: ScrollContainer = $MessagePanel/ScrollContainer

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


func _ready() -> void:
	set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
	$EnemyContainer/Enemy.play(enemy.name)
	
	if Engine.is_editor_hint():
		return
	
	set_health($PlayerContainer/PlayerHealthBar, GameState.current_health, GameState.max_health)
	
	current_player_health = GameState.current_health
	current_enemy_health = enemy.health
	
	actions_panel.hide()
	question_popup.hide()
	
	#await question_popup.questions_loaded
	
	player_animations.play("appear")
	await player_animations.animation_finished
	player_animations.play("idle")
	
	
	add_history_entry("A wild [b]%s[/b] appears!" % enemy.name)
	await get_tree().create_timer(0.6).timeout
	actions_panel.show()

func add_history_entry(text: String) -> void:
	var timed_msg = timed_message_scene.instantiate()
	timed_msg.text = text
	timed_messages.add_child(timed_msg)
	
	await get_tree().process_frame
	message_scroll.scroll_vertical = int(message_scroll.get_v_scroll_bar().max_value)

func spawn_enemy() -> void:
	randomize()
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
	
	add_history_entry("A wild [b]%s[/b] appears!" % enemy.name)
	await get_tree().create_timer(0.6).timeout
	actions_panel.show()

func set_health(progress_bar: ProgressBar, health: int, max_health: int):
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "HP: %d/%d" % [health, max_health]
	
	var tween = progress_bar.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_bar, "value", health, 0.5)


func enemy_turn() -> void:
	add_history_entry("[color=yellow]%s[/color] launches at you fiercely!" % enemy.name)
	await get_tree().create_timer(0.5).timeout
	
	if is_defending:
		is_defending = false
		
		player_animations.play("defend")
		animations.play("mini_shake")
		await animations.animation_finished
		player_animations.play("idle")
		
		add_history_entry("You defended successfully!")
		await get_tree().create_timer(0.5).timeout
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
		
		add_history_entry("[color=yellow]%s[/color] dealt [color=red]%d[/color] damage!" % [enemy.name, enemy.damage])
		await get_tree().create_timer(0.5).timeout
	
	actions_panel.show()
