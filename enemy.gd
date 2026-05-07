extends CharacterBody2D

signal stomped
signal hit_player

var cloud_ref: Node2D = null
var speed: float = 0.0
var direction: float = 1.0
var _dead: bool = false

func _ready() -> void:
	add_to_group("enemy")
	$AnimatedSprite2D.play("idle")

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(cloud_ref):
		return
	if speed > 0.0:
		position.x += speed * direction * delta
		$AnimatedSprite2D.flip_h = direction < 0.0
		var cloud_left: float = cloud_ref.position.x - 50.0
		var cloud_right: float = cloud_ref.position.x + 50.0
		if position.x > cloud_right:
			direction = -1.0
		elif position.x < cloud_left:
			direction = 1.0

func die() -> void:
	if _dead:
		return
	_dead = true
	stomped.emit()
	$CollisionShape2D.set_deferred("disabled", true)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation", PI * 2.0, 0.5)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.5)
	tw.chain().tween_callback(queue_free)
