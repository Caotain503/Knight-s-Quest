extends Control
class_name ShopUI

signal shop_closed

const item_panel_scene = preload("res://scenes/item_panel.tscn")

@export var item_pool: Array[BaseItem]

@onready var item_panel_container: HBoxContainer = $MarginContainer/ItemPanelContainer
@onready var coin_label: Label = $HBoxContainer/CoinLabel

func clear_items() -> void:
	for item_panel in item_panel_container.get_children():
		item_panel.disconnect("item_bought", _on_item_bought)
		item_panel.queue_free()

func reroll_shop() -> void:
	clear_items()
	
	if item_pool.is_empty():
		push_error("ShopUI: item_pool is empty! Fill it in the Inspector.")
		return
	
	coin_label.text = "X %d" % GameState.coins
	for i in range(3):
		randomize()
		var item_panel: ItemPanel = item_panel_scene.instantiate()
		item_panel.item = item_pool.pick_random()
		item_panel.item_bought.connect(_on_item_bought)
		item_panel_container.add_child(item_panel)

func _on_button_pressed() -> void:
	shop_closed.emit()
	hide()

func _on_item_bought() -> void:
	coin_label.text = "X %d" % GameState.coins
