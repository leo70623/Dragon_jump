extends Area2D

enum Type { EXTRA_LIFE = 0, BOOST = 1, PUMP = 2 }

var item_type: Type = Type.BOOST
var _already_collected: bool = false

signal collected(type: int)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	$PowerSprite.visible = item_type == Type.EXTRA_LIFE
	$BoostSprite.visible = item_type == Type.BOOST
	$PumpSprite.visible = item_type == Type.PUMP

func _on_body_entered(body: Node) -> void:
	if _already_collected:
		return
	if body is CharacterBody2D:
		_already_collected = true
		collected.emit(int(item_type))
		queue_free()
