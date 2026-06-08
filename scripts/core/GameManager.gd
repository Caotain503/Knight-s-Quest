extends Node

# Oyuncu durumu
var player_hp: int = 100
var player_max_hp: int = 100
var player_atk: int = 15
var player_def: int = 5
var player_gold: int = 0

# Ekipman seviyeleri
var sword_level: int = 0
var armor_level: int = 0

# Aktif jokerler
var active_jokers: Array = []

# Bölge ve encounter takibi
var current_region: int = 1
var current_encounter: int = 1  # 1: kolay, 2: orta, 3: boss

func reset_run():
	player_hp = player_max_hp
	player_gold = 0
	sword_level = 0
	armor_level = 0
	active_jokers = []
	current_region = 1
	current_encounter = 1
