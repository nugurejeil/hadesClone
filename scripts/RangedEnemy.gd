extends Enemy
## 원거리 적(궁수): 플레이어와 7~9 m 거리를 유지하고, 조준한 뒤 화살을 쏜다.
## 화살은 조준이 끝나는 순간의 플레이어 방향으로 직선으로 날아가므로 움직이면 피할 수 있다.

@export var arrow_scene: PackedScene
@export var min_distance := 7.0
@export var max_distance := 9.0
## min_distance에서 이만큼 더 가까우면 쏘지 않고 먼저 물러난다
@export var retreat_margin := 1.0
@export var arrow_forward_offset := 0.5
@export var arrow_height := 0.8

## 물러나려는데 벽·나무에 막혀 거의 못 움직이면 true. 이때는 가까워도 쏜다.
var _cornered := false


func _can_start_attack(distance: float) -> bool:
	if distance > max_distance + 0.5:
		return false
	return _cornered or distance >= min_distance - retreat_margin


func _move(direction: Vector3) -> void:
	super(direction)
	_cornered = direction != Vector3.ZERO and get_real_velocity().length() < move_speed * 0.3


func _chase_direction(to_player: Vector3, distance: float) -> Vector3:
	return _keep_distance(to_player, distance)


func _recover_direction(to_player: Vector3, distance: float) -> Vector3:
	return _keep_distance(to_player, distance)


func _keep_distance(to_player: Vector3, distance: float) -> Vector3:
	if distance < 0.01:
		return Vector3.ZERO
	if distance < min_distance:
		return -to_player / distance
	if distance > max_distance:
		return to_player / distance
	return Vector3.ZERO


func _perform_attack(to_player: Vector3, distance: float) -> void:
	var direction := to_player / distance if distance > 0.01 else -global_basis.z
	_face(direction)
	var arrow := arrow_scene.instantiate() as EnemyArrow
	arrow.direction = direction
	arrow.damage = damage
	projectiles.add_child(arrow)
	arrow.global_position = global_position + direction * arrow_forward_offset + Vector3.UP * arrow_height
	arrow.rotation.y = rotation.y
	arrow.reset_physics_interpolation()
