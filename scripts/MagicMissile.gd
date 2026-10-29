class_name MagicMissile
extends Area3D
## 매직 미사일: 직선으로 날아가 처음 맞은 적 하나에 피해를 주고 사라진다. 나무·벽에 막힌다.

@export var speed := 12.0
@export var max_distance := 12.0
@export var hit_color := Color(0.6, 0.9, 1.0, 0.8)

## 쏘는 쪽(플레이어)이 정한다.
var damage := 15
var direction := Vector3.FORWARD
var _traveled := 0.0
var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_traveled += step
	if _traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _done:
		return
	var enemy := body as Enemy
	if enemy != null:
		if not enemy.is_alive():
			return
		enemy.take_damage(damage, global_position)
	_done = true
	Fx.spawn(Fx.sphere(), Fx.glow(hit_color), global_position, 0.2, 0.15, 0.5)
	queue_free()
