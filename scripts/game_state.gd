extends Node

var current_health: int = 30
var max_health = 30
var damage = 20
var coins: int = 0

var potion_count:int=0
var scroll_count:int=0

var player_items:Array[BaseItem]


func upgrade_damage(amount:int)->void:
	damage += amount

func upgrade_max_health(amount:int)->void:
	max_health += amount
	current_health += amount

func heal(amount:int)->int:
	var missing =max_health- current_health
	var heal_amount = min(amount, missing)
	current_health += heal_amount
	return heal_amount

func add_potion(count:int=1)->void:
	potion_count += count

func add_scroll(count:int=1)->void:
	scroll_count += count

func use_potion()->int:
	if potion_count<=0:
		return 0
	potion_count -=1
	return heal(20)

func use_scroll()->bool:
	if scroll_count<=0:
		return false
	scroll_count -= 1
	return true
