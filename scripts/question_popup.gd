extends NinePatchRect
class_name QuestionPopup

signal question_answered(is_correct: bool)
signal questions_loaded

@export var parent: BattleScene

@onready var question_label: RichTextLabel = $MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoicesContainer

var question_pool: Array = []

func _ready() -> void:
	var loaded_data = load_json("res://questions/easy.json")
	question_pool = loaded_data
	questions_loaded.emit()

func ask_question():
	if question_pool.is_empty():
		printerr("No questions loaded! Automatically passing.")
		question_answered.emit(true)
		return
	
	randomize()
	var random_question = question_pool.pick_random()
	question_label.text = random_question["question"]
	
	for child in choices_container.get_children():
		child.queue_free()
	
	for option in random_question["choices"]:
		var btn = Button.new()
		btn.text = option
		btn.pressed.connect(_on_choice_selected.bind(option, random_question["answer"]))
		choices_container.add_child(btn)
	
	self.show()

func _on_choice_selected(selected_option: String, correct_answer: String) -> void:
	self.hide()
	var is_correct = (selected_option == correct_answer)
	question_answered.emit(is_correct)

func load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Could not open file at ", path)
		return ""
	
	var content = file.get_as_text()
	return JSON.parse_string(content)
