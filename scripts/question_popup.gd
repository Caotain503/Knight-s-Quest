extends NinePatchRect
class_name QuestionPopup

signal question_answered(is_correct: bool,explanation: String)
signal questions_loaded

@export var parent: BattleScene

@onready var question_label: RichTextLabel = $MarginContainer/VBoxContainer/QuestionLabel
@onready var choices_container: VBoxContainer = $MarginContainer/VBoxContainer/ChoicesContainer

var question_pool: Array = []
var current_question: Dictionary = {}


func _ready() -> void:
	var loaded_data = load_json("res://questions/easy.json")
	question_pool = loaded_data
	questions_loaded.emit()

func ask_question():
	if question_pool.is_empty():
		printerr("No questions loaded! Automatically passing.")
		question_answered.emit(true,"")
		return
	
	randomize()
	current_question = question_pool.pick_random()
	question_label.text = current_question["question"]
	
	for child in choices_container.get_children():
		child.queue_free()
	
	for i in range(current_question["options"].size()):
		var btn = Button.new()
		btn.text = current_question["options"][i]
		btn.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(btn)
	
	self.show()

func _on_choice_selected(selected_index:int) -> void:
	self.hide()
	var is_correct = (selected_index == current_question["correct"])
	var explanation = current_question["explanation"]
	question_answered.emit(is_correct,explanation)

func load_json(path: String) -> Variant:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Could not open file at ", path)
		return ""
	
	var content = file.get_as_text()
	return JSON.parse_string(content)
