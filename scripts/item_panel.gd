extends Panel
class_name ItemPanel

signal item_bought

var item: BaseItem 
@onready var item_label: Label = %ItemLabel
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %Button


func _ready() -> void:
	item_label.text = item.name
	price_label.text = "%d$" % item.price
	if GameState.coins < item.price:
		buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_button_pressed)


func _on_buy_button_pressed() -> void:
	GameState.coins -= item.price
	item_bought.emit()
	if GameState.coins < item.price:
		buy_button.disabled = true
