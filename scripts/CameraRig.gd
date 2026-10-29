extends Node3D
## 플레이어를 부드럽게 따라가는 카메라 받침대. 물리 보간을 쓰므로 _physics_process에서 움직인다.

@export var target: Node3D
@export var follow_speed := 6.0


func _ready() -> void:
	if target != null:
		global_position = target.global_position
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if target != null:
		global_position = global_position.lerp(target.global_position, 1.0 - exp(-follow_speed * delta))
