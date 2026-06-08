extends NinePatchRect
class_name QuestionPopup

signal question_answered(is_correct: bool, explanation: String)
signal questions_loaded

@export var parent: BattleScene

@onready var question_label: RichTextLabel = $MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoicesContainer
@onready var use_scroll_button: Button = $MarginContainer/VBoxContainer/UseScrollButton

var question_pool: Array = []
var available_questions: Array = []
var current_question: Dictionary = {}

func _ready() -> void:
	var loaded_data = load_json("res://questions/easy.json")
	question_pool = loaded_data
	available_questions = question_pool.duplicate()
	available_questions.shuffle()
	questions_loaded.emit()
	
	use_scroll_button.pressed.connect(_on_use_scroll_pressed)
	GameState.inventory_changed.connect(_update_scroll_button)

func ask_question():
	if question_pool.is_empty():
		printerr("No questions loaded! Automatically passing.")
		question_answered.emit(true, "")
		return
	
	if available_questions.is_empty():
		available_questions = question_pool.duplicate()
		available_questions.shuffle()
	
	current_question = available_questions.pop_back()
	question_label.text = current_question["question"]
	
	for child in choices_container.get_children():
		child.queue_free()
	
	for i in range(current_question["options"].size()):
		var btn = Button.new()
		btn.text = current_question["options"][i]
		btn.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(btn)
	
	_update_scroll_button()
	self.show()

func _on_choice_selected(selected_index: int) -> void:
	self.hide()
	var is_correct = (selected_index == current_question["correct"])
	var explanation = current_question["explanation"]
	question_answered.emit(is_correct, explanation)

func _on_use_scroll_pressed() -> void:
	if not GameState.use_scroll():
		return
	
	self.hide()
	var explanation = current_question["explanation"]
	parent.information_popup.show_info(explanation)
	await parent.information_popup.info_closed
	question_answered.emit(true, "")

func _update_scroll_button() -> void:
	use_scroll_button.disabled = GameState.scroll_count <= 0

func load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Could not open file at ", path)
		return ""
	
	var content = file.get_as_text()
	return JSON.parse_string(content)
