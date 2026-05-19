@tool
extends Control

# textlabel_closed sinyali kaldırıldı, artık beklenecek bir şey yok
signal question_answered(is_correct: bool)

# text_label referansı kaldırıldı
@onready var actions_panel: Panel = $ActionsPanel
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var question_popup: Panel = $QuestionPopup
@onready var question_label: RichTextLabel = $QuestionPopup/MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $QuestionPopup/MarginContainer/VBoxContainer/ChoicesContainer
@onready var game_over_ui: GameOverUI = $GameOverUI
@onready var shop_ui: ShopUI = $ShopUI
@onready var enemy_container: VBoxContainer = $EnemyContainer
@onready var player_animations: AnimationPlayer = $PlayerContainer/Player/PlayerAnimations

# YENİ: history paneli referansları
@onready var history_list: VBoxContainer = $HistoryPanel/MarginContainer/ScrollContainer/HistoryList
@onready var history_scroll: ScrollContainer = $HistoryPanel/MarginContainer/ScrollContainer

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
# is_scrolling değişkeni kaldırıldı, harf harf yazma yok

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
	
	# text_label ile ilgili satırlar kaldırıldı
	actions_panel.hide()
	question_popup.hide()
	
	player_animations.play("appear")
	await player_animations.animation_finished
	player_animations.play("idle")
	
	
	# display_text yerine add_history_entry, await kaldırıldı
	add_history_entry("A wild [b]%s[/b] appears!" % enemy.name)
	await get_tree().create_timer(0.6).timeout
	actions_panel.show()

# YENİ FONKSİYON: history paneline mesaj ekler
func add_history_entry(text: String) -> void:
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = text
	history_list.add_child(label)
	
	# Layout güncellensin diye bir frame bekle, sonra en alta kaydır
	await get_tree().process_frame
	history_scroll.scroll_vertical = int(history_scroll.get_v_scroll_bar().max_value)

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

# _input fonksiyonu tamamen kaldırıldı, artık tıklamayla atlanacak bir mesaj yok
# Eğer ileride başka amaçlarla _input'a ihtiyaç olursa boş bırakabilirsin

func enemy_turn() -> void:
	add_history_entry("[color=red]%s launches at you fiercely![/color]" % enemy.name)
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
		
		add_history_entry("[color=red]%s dealt %d damage![/color]" % [enemy.name, enemy.damage])
		await get_tree().create_timer(0.5).timeout
	
	actions_panel.show()


func _on_run_button_pressed():
	actions_panel.hide()
	add_history_entry("Got away safely!")
	await get_tree().create_timer(0.8).timeout
	get_tree().quit()


func _on_attack_button_pressed() -> void:
	actions_panel.hide()
	
	ask_question()
	var is_correct = await self.question_answered
	
	if not is_correct:
		add_history_entry("[color=yellow]Wrong answer! Your attack missed![/color]")
		await get_tree().create_timer(0.6).timeout
		enemy_turn()
		return
	
	add_history_entry("You swing your piercing sword!")
	await get_tree().create_timer(0.3).timeout
	
	current_enemy_health = max(0, current_enemy_health - GameState.damage)
	set_health($EnemyContainer/EnemyHealthBar, current_enemy_health, enemy.health)
	
	player_animations.play("attack")
	await player_animations.animation_finished
	animations.play("enemy_damaged")
	await animations.animation_finished
	player_animations.play("idle")
	
	add_history_entry("[color=green]You've dealt %d damage to the %s![/color]" % [GameState.damage, enemy.name])
	await get_tree().create_timer(0.4).timeout
	
	if current_enemy_health == 0:
		GameState.coins += enemy.reward
		add_history_entry("[b]%s was defeated. You earned %d coins![/b]" % [enemy.name, enemy.reward])
		await get_tree().create_timer(0.8).timeout
		
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
		add_history_entry("[color=yellow]Wrong answer! Your defense failed![/color]")
		await get_tree().create_timer(0.6).timeout
		enemy_turn()
		return
	
	is_defending = true
	
	add_history_entry("You prepare defensively!")
	await get_tree().create_timer(0.4).timeout
	
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
	pass

func _on_items_button_pressed() -> void:
	pass
