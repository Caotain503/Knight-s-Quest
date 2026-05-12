extends Control
class_name GameOverUI

@export var death_messages: Array[String]

@onready var label: Label = $Label
@onready var button: Button = $Button
@onready var animations: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	button.pressed.connect(_on_retry)
	visible = false

func appear() -> void:
	button.disabled = true
	randomize()
	label.text = death_messages.pick_random()
	visible = true
	animations.play("appear")
	await animations.animation_finished
	button.disabled = false

func disappear() -> void:
	button.disabled = true
	animations.play("disappear")
	await animations.animation_finished
	get_tree().reload_current_scene()

func _on_retry() -> void:
	disappear()
