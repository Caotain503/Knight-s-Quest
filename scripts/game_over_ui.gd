extends Control
class_name GameOverUI

@export var death_messages: Array[String]

@onready var label: Label = $Label
@onready var button: Button = $Button
@onready var round_label: Label =$RoundLabel
@onready var animations: AnimationPlayer = $AnimationPlayer
@onready var button2:Button= $Button2

func _ready() -> void:
	button.pressed.connect(_on_retry)
	button2.pressed.connect(_on_main_menu)
	visible = false

func appear() -> void:
	button.disabled = true
	randomize()
	label.text = death_messages.pick_random()
	round_label.text = "You reached Round %d (Best: %d)" % [GameState.current_round, GameState.highest_round]
	visible = true
	animations.play("appear")
	await animations.animation_finished
	button.disabled = false

func disappear() -> void:
	button.disabled = true
	animations.play("disappear")
	await animations.animation_finished
	GameState.reset()
	get_tree().reload_current_scene()

func _on_retry() -> void:
	disappear()


func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
