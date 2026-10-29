class_name WaveManager
extends Node
## 웨이브 구성표대로 스폰 지점에서 적을 하나씩 내보내고, 전멸하면 쉬었다가 다음 웨이브를 보낸다.

signal wave_started(wave: int, total: int)
signal remaining_changed(remaining: int)
signal all_waves_cleared

enum Phase { WAITING, SPAWNING, FIGHTING, DONE }

## 웨이브별 (근거리, 원거리, 덩치) 마릿수
@export var waves: Array[Vector3i] = [Vector3i(6, 0, 0), Vector3i(6, 3, 0), Vector3i(6, 4, 2)]
@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var brute_scene: PackedScene
@export var first_wave_delay := 1.0
@export var rest_time := 3.0
@export var spawn_interval := 0.5
@export var min_spawn_distance := 10.0
@export var player: Player
@export var enemies: Node3D
@export var projectiles: Node3D
@export var spawn_points: Node3D

var kills := 0
var elapsed := 0.0
var current_wave := 0
var remaining := 0
var _phase := Phase.WAITING
var _wait := 0.0
var _queue: Array[PackedScene] = []


func _ready() -> void:
	_wait = first_wave_delay
	player.died.connect(func() -> void: _phase = Phase.DONE)


func _physics_process(delta: float) -> void:
	if _phase == Phase.DONE:
		return
	elapsed += delta
	_wait -= delta
	if _wait > 0.0:
		return
	match _phase:
		Phase.WAITING:
			_begin_wave()
		Phase.SPAWNING:
			_spawn(_queue.pop_front())
			_wait = spawn_interval
			if _queue.is_empty():
				_phase = Phase.FIGHTING


func _begin_wave() -> void:
	var counts := waves[current_wave]
	current_wave += 1
	_queue.clear()
	for i in counts.x:
		_queue.append(melee_scene)
	for i in counts.y:
		_queue.append(ranged_scene)
	for i in counts.z:
		_queue.append(brute_scene)
	_queue.shuffle()
	remaining = _queue.size()
	wave_started.emit(current_wave, waves.size())
	remaining_changed.emit(remaining)
	_phase = Phase.SPAWNING
	_wait = 0.0
	if _queue.is_empty():
		_phase = Phase.FIGHTING
		_on_wave_cleared()


func _spawn(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as Enemy
	enemy.player = player
	enemy.projectiles = projectiles
	enemy.position = _pick_spawn_point() + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
	enemy.died.connect(_on_enemy_died)
	enemies.add_child(enemy)
	enemy.reset_physics_interpolation()


## 플레이어와 min_spawn_distance 이상 떨어진 스폰 지점 중 하나. 없으면 가장 먼 곳.
func _pick_spawn_point() -> Vector3:
	var candidates: Array[Vector3] = []
	var farthest := Vector3.ZERO
	var farthest_distance := -1.0
	for marker: Node3D in spawn_points.get_children():
		var distance := marker.global_position.distance_to(player.global_position)
		if distance >= min_spawn_distance:
			candidates.append(marker.global_position)
		if distance > farthest_distance:
			farthest_distance = distance
			farthest = marker.global_position
	return candidates.pick_random() if not candidates.is_empty() else farthest


func _on_enemy_died(_enemy: Enemy) -> void:
	kills += 1
	remaining -= 1
	remaining_changed.emit(remaining)
	if remaining <= 0 and _phase == Phase.FIGHTING:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	if current_wave >= waves.size():
		_phase = Phase.DONE
		all_waves_cleared.emit()
	else:
		_phase = Phase.WAITING
		_wait = rest_time
