@tool
extends Control
class_name BattleScene


const timed_message_scene: PackedScene = preload("res://scenes/timed_message.tscn")
@onready var portal: AnimatedSprite2D =$PlayerContainer/EntryPortal
@onready var actions_panel: NinePatchRect = $ActionsPanel
@onready var enemy_animations: AnimationPlayer = $EnemyContainer/Enemy/EnemyAnimations
@onready var question_popup: QuestionPopup = $QuestionPopup
@onready var question_label: RichTextLabel = $QuestionPopup/MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $QuestionPopup/MarginContainer/VBoxContainer/ChoicesContainer
@onready var game_over_ui: GameOverUI = $GameOverUI
@onready var shop_ui: ShopUI = $ShopUI
@onready var enemy_container: Control = $EnemyContainer
@onready var player: AnimatedSprite2D = $PlayerContainer/Player
@onready var information_popup = $InformationPopup
@onready var timed_messages: VBoxContainer = $MessagePanel/ScrollContainer/Messages
@onready var message_scroll: ScrollContainer = $MessagePanel/ScrollContainer


var player_start_position: Vector2  
var available_enemies: Array[BaseEnemy] = []

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
var heal_used_this_turn:bool=false

func _ready() -> void:
	set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
	$EnemyContainer/Enemy.play(enemy.name)
	
	if Engine.is_editor_hint():
		return
	GameState.inventory_changed.connect(_update_inventory_display)
	_update_inventory_display()
	
	portal.visible=false
	
	
	_setup_button_hover($InformationPopup/MarginContainer/Control/CloseButton, true)
	
	
	
	set_health($PlayerContainer/PlayerHealthBar, GameState.current_health, GameState.max_health)
	current_player_health = GameState.current_health
	current_enemy_health = enemy.health
	
	actions_panel.hide()
	question_popup.hide()
	information_popup.hide()
	
	player_start_position = player.position
	await player_enter()
	
	$PlayerContainer/PlayerHealthBar.visible=true
	
	
	add_history_entry("A wild [b]%s[/b] appears!" % enemy.name)
	await get_tree().create_timer(0.6).timeout
	show_actions_panel()
	


func _update_inventory_display() -> void:
	$PlayerContainer/InventoryDisplay/PotionCount.text = str(GameState.potion_count)
	$PlayerContainer/InventoryDisplay/ScrollCount.text = str(GameState.scroll_count)

func add_history_entry(text: String) -> void:
	var timed_msg = timed_message_scene.instantiate()
	timed_msg.text = text
	timed_messages.add_child(timed_msg)
	
	await get_tree().process_frame
	message_scroll.scroll_vertical = int(message_scroll.get_v_scroll_bar().max_value)
	


func spawn_enemy() -> void:
	
	if available_enemies.is_empty():
		available_enemies = enemy_pool.duplicate()
	
	var index = randi() % available_enemies.size()
	enemy = available_enemies[index]
	available_enemies.remove_at(index)
	
	
	$EnemyContainer/EnemyHealthBar.value = enemy.health
	$EnemyContainer/EnemyHealthBar.max_value = enemy.health
	$EnemyContainer/Enemy.play(enemy.name)
	current_enemy_health = enemy.health
	
	await player_enter()
	
	enemy_animations.play("enemy_appear")
	await enemy_animations.animation_finished
	
	add_history_entry("A wild [b]%s[/b] appears!" % enemy.name)
	await get_tree().create_timer(0.6).timeout
	show_actions_panel()

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
		
		player.play("defend")
		play_enemy_animation("attack")
		enemy_animations.play("mini_shake")
		await enemy_animations.animation_finished
		player.play("idle")
		
		add_history_entry("You defended successfully!")
		await get_tree().create_timer(0.5).timeout
	else:
		play_enemy_animation("attack")
		await get_tree().create_timer(0.3).timeout
		
		current_player_health = max(0, current_player_health - enemy.damage)
		GameState.current_health=current_player_health
		set_health($PlayerContainer/PlayerHealthBar, current_player_health, GameState.max_health)
		
		player.play("hurt")
		enemy_animations.play("camera_shake")
		await enemy_animations.animation_finished
		player.play("idle")
		
		if current_player_health == 0:
			player.play("death")
			await player.animation_finished
			$PlayerContainer/PlayerHealthBar.visible=false
			game_over_ui.appear()
			return
		
		add_history_entry("[color=yellow]%s[/color] dealt [color=red]%d[/color] damage!" % [enemy.name, enemy.damage])
		await get_tree().create_timer(0.5).timeout
	
	show_actions_panel()






#-------------------------------Animasyon bölgesi------------------------------------------------------------------



func player_exit() -> void:
	portal.flip_h = true
	var portal_position = player_start_position + Vector2(1200, -30)
	portal.position = portal_position
	portal.visible = true
	
	portal.play("portal_appear")
	await portal.animation_finished
	portal.play("portal_idle")
	
	
	$PlayerContainer/PlayerHealthBar.visible=false
	player.play("walk")
	var exit_tween = create_tween()
	exit_tween.set_trans(Tween.TRANS_LINEAR)
	exit_tween.tween_property(player, "position", portal_position, 2)
	await exit_tween.finished
	
	player.visible = false
	
	portal.play("portal_disappear")
	await portal.animation_finished
	portal.visible = false
	
	player.visible = true

func player_enter() -> void:
	portal.flip_h = false
	var portal_position = player_start_position + Vector2(-300, 0)
	player.position = portal_position
	player.visible = false
	
	
	portal.position = portal_position
	portal.visible = true
	
	portal.play("portal_appear")
	await portal.animation_finished
	portal.play("portal_idle")
	
	player.visible = true
	player.play("walk")
	
	var walk_tween = create_tween()
	walk_tween.set_trans(Tween.TRANS_LINEAR)
	walk_tween.tween_property(player, "position", player_start_position, 1)
	
	await get_tree().create_timer(1 ).timeout
	portal.play("portal_disappear")
	await walk_tween.finished
	
	
	$PlayerContainer/PlayerHealthBar.visible=true
	
	player.play("idle")
	
	portal.visible = false

func play_enemy_animation(anim_type: String) ->void:
	var enemy_sprite =$EnemyContainer/Enemy
	var anim_name = enemy.name + "_" + anim_type
	
	if enemy_sprite.sprite_frames.has_animation(anim_name):
		enemy_sprite.play(anim_name)
		await enemy_sprite.animation_finished
		enemy_sprite.play(enemy.name)
	else:
		push_warning("Animation Not Found" + anim_name)

func show_actions_panel() -> void:
	heal_used_this_turn=false
	actions_panel.pivot_offset = actions_panel.size / 2
	actions_panel.scale = Vector2(0.8, 0.8)
	actions_panel.modulate.a = 0.0
	actions_panel.visible = true
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(actions_panel, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(actions_panel, "modulate:a", 1.0, 0.25)

func hide_actions_panel() -> void:
	actions_panel.pivot_offset = actions_panel.size / 2
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	
	tween.tween_property(actions_panel, "scale", Vector2(0.8, 0.8), 0.2)
	tween.tween_property(actions_panel, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	actions_panel.visible = false

func _setup_button_hover(button: Button,animate_label:bool=false) -> void:
	var hover_texture = button.get_node("HoverTexture")
	var label = button.get_node("ButtonLabel")
	
	hover_texture.modulate.a = 0.0
	
	
	
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
