@tool
extends Control

signal textlabel_closed
signal question_answered(is_correct: bool)

@export var enemy: BaseEnemy:
	set(value):
		enemy = value

		if not is_node_ready():
			return

		if enemy != null:
			set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
			$EnemyContainer/Enemy.texture = enemy.texture

@onready var text_label: RichTextLabel = $PlayerPanel/TextLabel
@onready var actions_panel: Panel = $ActionsPanel
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var question_popup: Panel = $QuestionPopup
@onready var question_label: RichTextLabel = $QuestionPopup/MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $QuestionPopup/MarginContainer/VBoxContainer/ChoicesContainer

const GOLD_REWARD = 15
const SHOP_ITEMS = [
	{"name": "Health Potion", "desc": "Restore 20 HP", "cost": 10, "id": "potion"},
	{"name": "Sharp Sword", "desc": "+5 Attack damage", "cost": 15, "id": "sword"},
	{"name": "Iron Shield", "desc": "-5 damage taken", "cost": 15, "id": "shield"},
	{"name": "Elixir", "desc": "Fully restore HP", "cost": 25, "id": "elixir"},
]

var current_player_health: int = 0
var current_enemy_health: int = 0
var is_defending: bool = false
var questions_pool: Array = []
var merchant_active: bool = false
var merchant_panel: Panel
var merchant_gold_label: Label
var item_buy_buttons: Array[Button] = []
var items_panel: Panel
var items_content: VBoxContainer
var run_panel: Panel
var rpg_font: Font


func _ready() -> void:
	if Engine.is_editor_hint():
		set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
		$EnemyContainer/Enemy.texture = enemy.texture
		return

	# Scale enemy stats for current round (linear scaling)
	var scaled = BaseEnemy.new()
	scaled.name = enemy.name
	scaled.texture = enemy.texture
	scaled.health = enemy.health + (GameState.current_round - 1) * 10
	scaled.damage = enemy.damage + (GameState.current_round - 1) * 3
	enemy = scaled

	set_health($EnemyContainer/EnemyHealthBar, enemy.health, enemy.health)
	$EnemyContainer/Enemy.texture = enemy.texture
	set_health($PlayerContainer/PlayerHealthBar, GameState.current_health, GameState.max_health)

	current_player_health = GameState.current_health
	current_enemy_health = enemy.health

	var loaded_data = load_json("res://questions/easy.json")
	questions_pool = loaded_data

	text_label.hide()
	actions_panel.hide()
	question_popup.hide()

	rpg_font = load("res://assets/fonts/9 Bit RPG.ttf") as Font
	_build_merchant_panel()
	_build_items_panel()
	_build_run_panel()
	$ActionsPanel/VBoxContainer/ItemsButton.pressed.connect(_on_items_button_pressed)

	display_text("A wild [b]%s[/b] appears" % enemy.name)
	await self.textlabel_closed
	actions_panel.show()


func set_health(progress_bar: ProgressBar, health: int, max_health: int) -> void:
	progress_bar.max_value = max_health
	progress_bar.get_node("Label").text = "HP: %d/%d" % [health, max_health]

	var tween = progress_bar.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(progress_bar, "value", health, 0.5)


func _input(_event) -> void:
	if Engine.is_editor_hint():
		return
	var overlay_open = merchant_active \
		or (items_panel != null and items_panel.visible) \
		or (run_panel != null and run_panel.visible)
	if overlay_open:
		return

	if (Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT)) and text_label.visible:
		text_label.hide()
		self.textlabel_closed.emit()


func display_text(text) -> void:
	text_label.show()
	text_label.text = text


func enemy_turn() -> void:
	display_text("%s launches at you fiercely!" % enemy.name)
	await textlabel_closed

	if is_defending:
		is_defending = false
		animations.play("mini_shake")
		await animations.animation_finished

		display_text("You defended successfully!")
		await textlabel_closed
	else:
		var damage_taken = max(0, enemy.damage - GameState.defense)
		current_player_health = max(0, current_player_health - damage_taken)
		set_health($PlayerContainer/PlayerHealthBar, current_player_health, GameState.max_health)

		animations.play("camera_shake")
		await animations.animation_finished

		display_text("%s dealt %d damage!" % [enemy.name, damage_taken])
		await textlabel_closed

	actions_panel.show()


func _on_run_button_pressed() -> void:
	actions_panel.hide()
	run_panel.show()
	run_panel.move_to_front()


func _on_attack_button_pressed() -> void:
	actions_panel.hide()

	ask_question()
	var is_correct = await self.question_answered

	if not is_correct:
		display_text("Wrong answer! Your attack missed!")
		await textlabel_closed
		await enemy_turn()
		return

	display_text("You swing your piercing sword!")
	await textlabel_closed

	current_enemy_health = max(0, current_enemy_health - GameState.damage)
	set_health($EnemyContainer/EnemyHealthBar, current_enemy_health, enemy.health)

	animations.play("enemy_damaged")
	await animations.animation_finished

	display_text("You've dealt %d damage to the %s!" % [GameState.damage, enemy.name])
	await textlabel_closed

	if current_enemy_health == 0:
		display_text("%s was defeated!" % enemy.name)
		await textlabel_closed

		animations.play("enemy_death")
		await animations.animation_finished
		GameState.gold += GOLD_REWARD
		_show_merchant()
		return

	await enemy_turn()


func _on_defend_button_pressed() -> void:
	actions_panel.hide()

	ask_question()
	var is_correct = await self.question_answered

	if not is_correct:
		display_text("Wrong answer! Your attack missed!")
		await textlabel_closed
		await enemy_turn()
		return

	is_defending = true

	display_text("You prepare defensively!")
	await textlabel_closed

	await get_tree().create_timer(0.25).timeout

	await enemy_turn()


func _on_items_button_pressed() -> void:
	actions_panel.hide()
	_refresh_items_panel()
	items_panel.show()
	items_panel.move_to_front()


func ask_question() -> void:
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


# ─── Merchant Panel ───────────────────────────────────────────────────────────

func _build_merchant_panel() -> void:
	merchant_panel = Panel.new()
	merchant_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0, 0, 0, 0.88)
	merchant_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(merchant_panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 60)
	merchant_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "A Merchant Appears!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", rpg_font)
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	merchant_gold_label = Label.new()
	merchant_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merchant_gold_label.add_theme_font_override("font", rpg_font)
	merchant_gold_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(merchant_gold_label)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	item_buy_buttons.clear()
	for item in SHOP_ITEMS:
		hbox.add_child(_build_item_card(item))

	var next_btn = Button.new()
	next_btn.text = "Next Round"
	next_btn.add_theme_font_override("font", rpg_font)
	next_btn.add_theme_font_size_override("font_size", 30)
	next_btn.custom_minimum_size = Vector2(260, 50)
	next_btn.pressed.connect(_on_next_round_pressed)
	vbox.add_child(next_btn)

	merchant_panel.hide()


func _build_item_card(item: Dictionary) -> Panel:
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.08, 0.13, 1)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 6
	card_style.corner_radius_top_right = 6
	card_style.corner_radius_bottom_right = 6
	card_style.corner_radius_bottom_left = 6

	var card = Panel.new()
	card.custom_minimum_size = Vector2(210, 190)
	card.add_theme_stylebox_override("panel", card_style)

	var inner = VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 10)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(inner)

	var name_lbl = Label.new()
	name_lbl.text = item["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", rpg_font)
	name_lbl.add_theme_font_size_override("font_size", 22)
	inner.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = item["desc"]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_override("font", rpg_font)
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(desc_lbl)

	var cost_lbl = Label.new()
	cost_lbl.text = "%d Gold" % item["cost"]
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_font_override("font", rpg_font)
	cost_lbl.add_theme_font_size_override("font_size", 18)
	cost_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	inner.add_child(cost_lbl)

	var buy_btn = Button.new()
	buy_btn.text = "Buy"
	buy_btn.add_theme_font_override("font", rpg_font)
	buy_btn.add_theme_font_size_override("font_size", 20)
	buy_btn.pressed.connect(_on_buy_item.bind(item, buy_btn))
	item_buy_buttons.append(buy_btn)
	inner.add_child(buy_btn)

	return card


func _show_merchant() -> void:
	merchant_active = true
	GameState.current_health = current_player_health
	merchant_gold_label.text = "Gold: %d" % GameState.gold
	_update_buy_buttons()
	merchant_panel.show()
	merchant_panel.move_to_front()


func _update_buy_buttons() -> void:
	for i in range(item_buy_buttons.size()):
		item_buy_buttons[i].disabled = GameState.gold < SHOP_ITEMS[i]["cost"]


func _on_buy_item(item: Dictionary, buy_btn: Button) -> void:
	if GameState.gold < item["cost"]:
		return
	GameState.gold -= item["cost"]
	match item["id"]:
		"potion":
			GameState.inventory["potion"] += 1
		"sword":
			GameState.damage += 5
			buy_btn.disabled = true
		"shield":
			GameState.defense += 5
			buy_btn.disabled = true
		"elixir":
			GameState.inventory["elixir"] += 1
	merchant_gold_label.text = "Gold: %d" % GameState.gold
	_update_buy_buttons()


func _on_next_round_pressed() -> void:
	GameState.current_round += 1
	get_tree().reload_current_scene()


# ─── Items Panel ──────────────────────────────────────────────────────────────

func _build_items_panel() -> void:
	items_panel = Panel.new()
	items_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.88)
	items_panel.add_theme_stylebox_override("panel", style)
	add_child(items_panel)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 80)
	items_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "Items"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", rpg_font)
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	items_content = VBoxContainer.new()
	items_content.add_theme_constant_override("separation", 16)
	items_content.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(items_content)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(180, 44)
	close_btn.add_theme_font_override("font", rpg_font)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(_on_items_panel_closed)
	vbox.add_child(close_btn)

	items_panel.hide()


func _refresh_items_panel() -> void:
	for child in items_content.get_children():
		child.queue_free()

	var consumables = [
		{"id": "potion", "name": "Health Potion", "desc": "Restore 20 HP"},
		{"id": "elixir", "name": "Elixir", "desc": "Fully restore HP"},
	]

	var has_items = false
	for c in consumables:
		var count = GameState.inventory.get(c["id"], 0)
		if count == 0:
			continue
		has_items = true

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		items_content.add_child(row)

		var lbl = Label.new()
		lbl.text = "%s x%d  —  %s" % [c["name"], count, c["desc"]]
		lbl.add_theme_font_override("font", rpg_font)
		lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(lbl)

		var use_btn = Button.new()
		use_btn.text = "Use"
		use_btn.add_theme_font_override("font", rpg_font)
		use_btn.add_theme_font_size_override("font_size", 22)
		use_btn.pressed.connect(_on_use_item.bind(c["id"]))
		row.add_child(use_btn)

	if not has_items:
		var empty_lbl = Label.new()
		empty_lbl.text = "No items in inventory."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", rpg_font)
		empty_lbl.add_theme_font_size_override("font_size", 22)
		items_content.add_child(empty_lbl)


func _on_use_item(item_id: String) -> void:
	match item_id:
		"potion":
			current_player_health = min(GameState.max_health, current_player_health + 20)
		"elixir":
			current_player_health = GameState.max_health
	GameState.current_health = current_player_health
	GameState.inventory[item_id] -= 1
	set_health($PlayerContainer/PlayerHealthBar, current_player_health, GameState.max_health)
	_refresh_items_panel()


func _on_items_panel_closed() -> void:
	items_panel.hide()
	actions_panel.show()


# ─── Run Confirmation Panel ───────────────────────────────────────────────────

func _build_run_panel() -> void:
	run_panel = Panel.new()
	run_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.88)
	run_panel.add_theme_stylebox_override("panel", style)
	add_child(run_panel)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 32)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	run_panel.add_child(vbox)

	var question_lbl = Label.new()
	question_lbl.text = "Do you wanna exit from the game?"
	question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_lbl.add_theme_font_override("font", rpg_font)
	question_lbl.add_theme_font_size_override("font_size", 36)
	vbox.add_child(question_lbl)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 48)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn = Button.new()
	yes_btn.text = "Yes"
	yes_btn.custom_minimum_size = Vector2(160, 50)
	yes_btn.add_theme_font_override("font", rpg_font)
	yes_btn.add_theme_font_size_override("font_size", 28)
	yes_btn.pressed.connect(_on_run_confirmed)
	btn_row.add_child(yes_btn)

	var no_btn = Button.new()
	no_btn.text = "No"
	no_btn.custom_minimum_size = Vector2(160, 50)
	no_btn.add_theme_font_override("font", rpg_font)
	no_btn.add_theme_font_size_override("font_size", 28)
	no_btn.pressed.connect(_on_run_cancelled)
	btn_row.add_child(no_btn)

	run_panel.hide()


func _on_run_confirmed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_run_cancelled() -> void:
	run_panel.hide()
	actions_panel.show()
