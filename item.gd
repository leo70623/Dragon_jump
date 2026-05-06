extends Area2D

enum Type { EXTRA_LIFE = 0, BOOST = 1 }

var item_type: Type = Type.BOOST
var _already_collected: bool = false

signal collected(type: int)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _draw() -> void:
	match item_type:
		Type.EXTRA_LIFE:
			# type=0 無敵：黃色圓形
			draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.85, 0.1))
			draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.95, 0.4))
		Type.BOOST:
			# type=1 跳高：橘色星形
			_draw_star(Vector2.ZERO, 15.0, 6.5, 5, Color(1.0, 0.5, 0.1))

func _draw_star(center: Vector2, outer_r: float, inner_r: float, pts: int, color: Color) -> void:
	var polygon := PackedVector2Array()
	for i in pts * 2:
		var angle := -PI * 0.5 + PI * float(i) / float(pts)
		var r := outer_r if i % 2 == 0 else inner_r
		polygon.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_polygon(polygon, PackedColorArray([color]))

func _on_body_entered(body: Node) -> void:
	if _already_collected:
		return
	if body is CharacterBody2D:
		_already_collected = true
		collected.emit(int(item_type))
		queue_free()
