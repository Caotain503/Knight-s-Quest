extends Node

signal inventory_changed

const SAVE_DIR_NAME = "Knights Quest Save"
const SAVE_FILE_NAME = "save.json"



var current_health: int = 30
var max_health = 30
var damage = 5
var coins: int = 0
var potion_count:int=0
var scroll_count:int=0
var current_round: int=1
var player_items:Array[BaseItem]
var upgrade_amount=3


var user_id:String=""
var highest_round:int=0

func _ready()->void:
	_load_save()


func upgrade_damage()->void:
	damage += upgrade_amount

func upgrade_max_health()->void:
	max_health += upgrade_amount
	current_health += upgrade_amount

func heal(amount:int)->int:
	var missing =max_health- current_health
	var heal_amount = min(amount, missing)
	current_health += heal_amount
	return heal_amount

func add_potion(count:int=1)->void:
	potion_count += count
	inventory_changed.emit()

func add_scroll(count:int=1)->void:
	scroll_count += count
	inventory_changed.emit()

func use_potion()->int:
	if potion_count<=0:
		return 0
	potion_count -=1
	inventory_changed.emit()
	return heal(20)

func use_scroll()->bool:
	if scroll_count<=0:
		return false
	scroll_count -= 1
	inventory_changed.emit()
	return true
	

func reset() -> void:
	current_health = 30
	max_health = 30
	damage = 5
	coins = 0
	potion_count = 0
	scroll_count = 0
	current_round=1
	player_items.clear()
	inventory_changed.emit()





# ---------------- Save / Load ----------------


func _get_save_path() -> String:
	var documents = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return documents.path_join(SAVE_DIR_NAME).path_join(SAVE_FILE_NAME)



func _load_save() -> void:
	var save_path = _get_save_path()
	
	if not FileAccess.file_exists(save_path):
		_create_new_save()
		return
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_create_new_save()
		return
	
	var content = file.get_as_text()
	var data = JSON.parse_string(content)
	
	if data == null or not data is Dictionary:
		_create_new_save()
		return
	
	user_id = data.get("user_id", OS.get_unique_id())
	highest_round = data.get("highest_round", 0)



func _create_new_save() -> void:
	user_id = OS.get_unique_id()
	highest_round = 0
	_write_save()

func _write_save() -> void:
	var save_path = _get_save_path()
	var dir_path = save_path.get_base_dir()
	
	# Belgeler altında klasör yoksa oluştur
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	var data = {
		"user_id": user_id,
		"highest_round": highest_round
	}
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		printerr("Could not open save file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))

func update_highest_round() -> void:
	if current_round > highest_round:
		highest_round = current_round
		_write_save()
