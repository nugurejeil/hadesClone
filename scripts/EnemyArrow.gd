class_name EnemyArrow
extends Area3D
## 궁수의 화살: 직선으로 날아가 플레이어에게 피해를 준다. 나무·벽에 닿거나 최대 거리를 날면 사라진다.

@export var speed := 7.0
@export var max_distance := 20.0

## 쏘는 쪽(궁수)이 정한다.
var damage := 8
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
	var player := body as Player
	if player != null:
		if not player.is_alive():
			return
		player.take_damage(damage, global_position)
	_done = true
	queue_free()
