extends NinePatchRect
class_name InformationPopup

signal info_closed

@onready var info_label: RichTextLabel = $MarginContainer/Control/InfoLabel
@onready var close_button: Button = $MarginContainer/Control/CloseButton

@export var popup_scale: float = 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false
	
	
	
	
	

func show_info(explanation: String) -> void:
	info_label.text = explanation
	
	
	modulate.a = 0.0
	visible = true
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	

func _on_close_pressed() -> void:
	var tween = create_tween()
	
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	
	await tween.finished
	visible = false
	info_closed.emit()
