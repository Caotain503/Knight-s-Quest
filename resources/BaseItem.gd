extends Resource
class_name BaseItem

enum ItemType{
	SWORD_UPGRADE,
	ARMOR_UPGRADE,
	HEALTH_POTION,
	KNOWLEDGE_SCROLL
}



@export var name: String = ""
@export var price: int = 0
@export var type:ItemType =ItemType.SWORD_UPGRADE
@export var description:String =""
@export var icon:Texture2D
