class_name Enemy
extends CharacterBody3D
## 적 3종의 공통 부분: 체력, 상태 머신(추적 → 예비 동작 → 공격 → 대기, 사망), 피격, 넉백, 사망 연출.
## 이 스크립트 그대로가 근거리 적(졸개)이고, 원거리·덩치는 상속해서 차이점만 덮어쓴다.

signal died(enemy: Enemy)

enum State { CHASE, WINDUP, ATTACK, RECOVER, DEAD }

@export var max_health := 30
@export var move_speed := 3.5
## 이 거리 안에 들면 예비 동작을 시작한다
@export var attack_range := 1.2
## 예비 동작이 끝나는 순간 이 거리 밖이면 빗나간다
@export var hit_range := 1.6
@export var windup_time := 0.3
## 공격과 공격 사이 간격(예비 동작 포함)
@export var attack_interval := 1.0
@export var damage := 10
@export var knockback_immune := false
@export var windup_color := Color(1.0, 0.85, 0.3)
@export var flash_time := 0.1
@export var knockback_time := 0.12
@export var death_time := 0.3
@export var health_bar_width := 0.9

var player: Player
var projectiles: Node3D
var health := 0
var state := State.CHASE
var _state_time := 0.0
var _flash_left := 0.0
var _knock_velocity := Vector3.ZERO
var _knock_left := 0.0

@onready var _visual: Node3D = $Visual
@onready var _body: MeshInstance3D = $Visual/Body
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _bar: Node3D = $HealthBar
@onready var _bar_back: Sprite3D = $HealthBar/Back
@onready var _bar_fill: Sprite3D = $HealthBar/Fill


func _ready() -> void:
	add_to_group("enemy")
	health = max_health
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	_setup_health_bar()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_update_material()
	if _knock_left > 0.0:
		_knock_left -= delta
		velocity = _knock_velocity
		move_and_slide()
		return
	# 플레이어가 쓰러지면 공격을 멈추고 제자리에 선다.
	if player == null or not player.is_alive():
		if state != State.CHASE:
			_cancel_windup()
			_set_state(State.CHASE)
		velocity = Vector3.ZERO
		return

	_state_time += delta
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	match state:
		State.CHASE:
			if _can_start_attack(distance):
				_face(to_player)
				_set_state(State.WINDUP)
				_start_windup()
			else:
				_move(_chase_direction(to_player, distance))
		State.WINDUP:
			velocity = Vector3.ZERO
			_update_windup(_state_time / windup_time)
			if _state_time >= windup_time:
				_cancel_windup()
				_set_state(State.ATTACK)
				_perform_attack(to_player, distance)
				_set_state(State.RECOVER)
		State.RECOVER:
			_move(_recover_direction(to_player, distance))
			if _state_time >= maxf(attack_interval - windup_time, 0.0):
				_set_state(State.CHASE)


func is_alive() -> bool:
	return state != State.DEAD


func body_radius() -> float:
	return (_shape.shape as CapsuleShape3D).radius


func take_damage(amount: int, from_position: Vector3, knockback := 0.0) -> void:
	if state == State.DEAD:
		return
	health = maxi(health - amount, 0)
	_update_health_bar()
	_flash_left = flash_time
	if health == 0:
		_die()
		return
	if knockback > 0.0 and not knockback_immune:
		var away := global_position - from_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = global_basis.z
		_knock_velocity = away.normalized() * (knockback / knockback_time)
		_knock_left = knockback_time
		# 넉백으로 밀려나면 하던 예비 동작이 끊긴다.
		if state == State.WINDUP:
			_cancel_windup()
			_set_state(State.CHASE)
	_update_material()


## 셰이더 미리 컴파일용으로 바닥 아래에 둘 때 부른다.
func prewarm() -> void:
	remove_from_group("enemy")
	set_physics_process(false)
	_bar.show()


# --- 종류별로 덮어쓰는 부분 ---

func _can_start_attack(distance: float) -> bool:
	return distance <= attack_range


func _chase_direction(to_player: Vector3, distance: float) -> Vector3:
	return to_player / distance if distance > 0.01 else Vector3.ZERO


func _recover_direction(_to_player: Vector3, _distance: float) -> Vector3:
	return Vector3.ZERO


func _start_windup() -> void:
	pass


func _update_windup(_progress: float) -> void:
	pass


func _cancel_windup() -> void:
	pass


func _perform_attack(_to_player: Vector3, distance: float) -> void:
	if distance <= hit_range:
		player.take_damage(damage, global_position)


# --- 공통 내부 처리 ---

func _move(direction: Vector3) -> void:
	if direction != Vector3.ZERO:
		_face(direction)
	Steering.move(self, direction, move_speed)


func _face(direction: Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_update_material()


func _update_material() -> void:
	if _flash_left > 0.0:
		_body.material_override = Fx.solid(Color.WHITE)
	elif state == State.WINDUP:
		_body.material_override = Fx.solid(windup_color)
	else:
		_body.material_override = null


func _die() -> void:
	_cancel_windup()
	_set_state(State.DEAD)
	remove_from_group("enemy")
	collision_layer = 0
	collision_mask = 0
	_bar.hide()
	died.emit(self)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_visual, "scale", Vector3.ONE * 0.01, death_time).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _setup_health_bar() -> void:
	for sprite: Sprite3D in [_bar_back, _bar_fill]:
		sprite.texture = Fx.bar_texture()
		sprite.pixel_size = health_bar_width / 100.0
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = true
		sprite.centered = false
		sprite.offset = Vector2(-50.0, -5.0)
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0.0, 0.0, 100.0, 10.0)
	_bar_back.modulate = Color(0.1, 0.1, 0.1, 0.8)
	_bar_fill.modulate = Color(0.95, 0.2, 0.2)
	_bar_fill.render_priority = 1
	# 첫 피해를 입은 뒤부터 보인다.
	_bar.hide()


func _update_health_bar() -> void:
	_bar.show()
	var ratio := float(health) / float(max_health)
	_bar_fill.region_rect = Rect2(0.0, 0.0, maxf(100.0 * ratio, 0.5), 10.0)
