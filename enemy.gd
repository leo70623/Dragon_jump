extends CharacterBody2D

signal stomped
signal hit_player

var cloud_ref: Node2D = null
var cloud_ref_half_h: float = 4.0
var speed: float = 0.0
var direction: float = 1.0
var _dead: bool = false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("enemy")
	$AnimatedSprite2D.play("idle")

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(cloud_ref):
		return
	var ptype: int = cloud_ref.get("platform_type") if cloud_ref.get("platform_type") != null else 0
	var cloud_half_h: float = 30.0 if ptype == 3 else 4.0
	global_position.y = cloud_ref.global_position.y - cloud_half_h - 32.0  # 32.0 = 512 * 0.125 / 2
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
	speed = 0.0
	stomped.emit()
	$CollisionShape2D.set_deferred("disabled", true)
	$AnimatedSprite2D.play("hit")
	$AnimatedSprite2D.animation_finished.connect(queue_free, CONNECT_ONE_SHOT)
