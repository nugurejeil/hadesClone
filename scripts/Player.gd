class_name Player
extends CharacterBody3D
## 플레이어(마법사): 좌클릭/WASD 이동, 우클릭 근접 공격, Q 매직 미사일, Space 순간이동.
## 공격과 순간이동은 모두 마우스 커서가 가리키는 바닥 지점 쪽으로 나간다.

signal died
signal health_changed(current: int, maximum: int)
signal skill_used(skill: StringName, cooldown: float)

@export_group("Movement")
@export var move_speed := 5.0
@export var stop_distance := 0.2
## 근접 공격·미사일을 쓴 뒤 제자리에 서 있는 시간
@export var attack_pause := 0.15
@export var map_half_size := 20.0

@export_group("Health")
@export var max_health := 100
@export var hurt_invincible_time := 0.5

@export_group("Melee")
@export var melee_damage := 20
@export var melee_range := 1.8
@export var melee_angle := 90.0
@export var melee_knockback := 1.0
@export var melee_cooldown := 0.4

@export_group("Missile")
@export var missile_scene: PackedScene
@export var missile_damage := 15
@export var missile_cooldown := 0.6
@export var missile_forward_offset := 0.5
@export var missile_height := 1.0

@export_group("Teleport")
@export var teleport_distance := 4.0
@export var teleport_invincible_time := 0.3
@export var teleport_cooldown := 3.0

@export_group("Knight")
## 검을 들고 있는지. 처음엔 없고, 보물상자가 열리면 equip_sword()로 든다.
@export var has_sword := false
## 공격 동작(punch, sword-slash)을 이 시간 안에 끝나도록 빠르게 재생한다
@export var attack_anim_time := 0.4
@export var run_anim_speed := 1.0
## 멈춰 있을 때 보여 줄 달리기 동작의 시점(초). 걷기·대기 동작 없이 이 자세로 선다.
@export var idle_pose_time := 0.0

@export_group("")
@export var projectiles: Node3D

const BLINK_PERIOD := 0.08
const CLICK_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const MELEE_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const TELEPORT_COLOR := Color(0.35, 0.6, 1.0, 0.9)
const DEAD_COLOR := Color(0.45, 0.45, 0.45)

var health := 0
var _target := Vector3.ZERO
var _has_target := false
var _click_locked := false
var _pause_left := 0.0
var _invincible_left := 0.0
var _blink_left := 0.0
var _melee_left := 0.0
var _missile_left := 0.0
var _teleport_left := 0.0
var _dead := false
var _moving := false
var _attack_anim_left := 0.0
## 지금 보여 주는 동작: &"run", &"idle", &"attack"
var _anim_state := &""

@onready var _visual: Node3D = $Visual
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _anim: AnimationPlayer = $Visual/Knight/AnimationPlayer
@onready var _sword: Node3D = $Visual/Knight.find_child("Sword") as Node3D


func _ready() -> void:
	health = max_health
	_sword.visible = has_sword
	_update_animation()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_tick_timers(delta)
	_handle_skills()
	_handle_movement()
	_update_animation()


## 보물상자가 열리면 부른다. 이때부터 검이 보이고 근접 공격이 칼질이 된다.
func equip_sword() -> void:
	has_sword = true
	_sword.visible = true


func is_alive() -> bool:
	return not _dead


func body_radius() -> float:
	return (_shape.shape as CapsuleShape3D).radius


func take_damage(amount: int, _from_position: Vector3) -> void:
	if _dead or _invincible_left > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()
		return
	_invincible_left = hurt_invincible_time
	_blink_left = hurt_invincible_time


func _tick_timers(delta: float) -> void:
	_pause_left = maxf(_pause_left - delta, 0.0)
	_invincible_left = maxf(_invincible_left - delta, 0.0)
	_melee_left = maxf(_melee_left - delta, 0.0)
	_missile_left = maxf(_missile_left - delta, 0.0)
	_teleport_left = maxf(_teleport_left - delta, 0.0)
	_attack_anim_left = maxf(_attack_anim_left - delta, 0.0)
	if _blink_left > 0.0:
		_blink_left -= delta
		_visual.visible = _blink_left <= 0.0 or fmod(_blink_left, BLINK_PERIOD * 2.0) < BLINK_PERIOD


func _handle_skills() -> void:
	if Input.is_action_just_pressed("teleport") and _teleport_left <= 0.0:
		_try_teleport()
	if Input.is_action_pressed("attack_melee") and _melee_left <= 0.0:
		_melee()
	elif Input.is_action_pressed("cast_missile") and _missile_left <= 0.0:
		_cast_missile()


func _handle_movement() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("move"):
		_click_locked = false
		Fx.spawn(Fx.ring(), Fx.glow(CLICK_COLOR), _clamp_to_map(_mouse_ground_point()) + Vector3.UP * 0.05,
				0.3, 0.35, 0.15)
	elif not Input.is_action_pressed("move"):
		_click_locked = false

	if input != Vector2.ZERO:
		_has_target = false
	elif Input.is_action_pressed("move") and not _click_locked:
		_target = _clamp_to_map(_mouse_ground_point())
		_has_target = true

	if _pause_left > 0.0:
		velocity = Vector3.ZERO
		_moving = false
		return

	var direction := Vector3.ZERO
	if input != Vector2.ZERO:
		direction = _screen_to_world(input)
	elif _has_target:
		var to_target := _target - global_position
		to_target.y = 0.0
		if to_target.length() <= stop_distance:
			_has_target = false
		else:
			direction = to_target.normalized()
			# 목표가 나무 바로 뒤라면 나무를 계속 밀지 않고 멈춘다.
			if to_target.length() < 1.0 and Steering.tree_normal(self) != Vector3.ZERO:
				_has_target = false
				direction = Vector3.ZERO
	if direction != Vector3.ZERO:
		_face(direction)
	Steering.move(self, direction, move_speed)
	_moving = direction != Vector3.ZERO


func _melee() -> void:
	var aim := _aim_direction()
	_begin_attack(aim)
	_melee_left = melee_cooldown
	skill_used.emit(&"melee", melee_cooldown)
	_play_attack(&"sword-slash" if has_sword else &"punch")
	var half_angle := deg_to_rad(melee_angle * 0.5)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() > melee_range + enemy.body_radius():
			continue
		if to_enemy.length() > 0.05 and aim.angle_to(to_enemy) > half_angle:
			continue
		enemy.take_damage(melee_damage, global_position, melee_knockback)
	Fx.spawn(Fx.fan(melee_range, melee_angle), Fx.glow(MELEE_COLOR), global_position + Vector3.UP * 0.06,
			0.1, 1.0, 1.05, rotation.y)


func _cast_missile() -> void:
	var aim := _aim_direction()
	_begin_attack(aim)
	_missile_left = missile_cooldown
	skill_used.emit(&"missile", missile_cooldown)
	_play_attack(&"punch")
	var missile := missile_scene.instantiate() as MagicMissile
	missile.direction = aim
	missile.damage = missile_damage
	projectiles.add_child(missile)
	missile.global_position = global_position + aim * missile_forward_offset + Vector3.UP * missile_height
	missile.reset_physics_interpolation()


func _try_teleport() -> void:
	var offset := _mouse_ground_point() - global_position
	offset.y = 0.0
	if offset.length() < 0.1:
		return
	offset = offset.limit_length(teleport_distance)
	var destination := global_position + offset
	if not _is_free_spot(destination):
		return
	Fx.spawn(Fx.ring(), Fx.glow(TELEPORT_COLOR), global_position + Vector3.UP * 0.05, 0.3, 0.5, 1.0)
	Fx.spawn(Fx.ring(), Fx.glow(TELEPORT_COLOR), destination + Vector3.UP * 0.05, 0.3, 1.0, 0.5)
	global_position = destination
	reset_physics_interpolation()
	_face(offset.normalized())
	_has_target = false
	_invincible_left = maxf(_invincible_left, teleport_invincible_time)
	_teleport_left = teleport_cooldown
	skill_used.emit(&"teleport", teleport_cooldown)


## 플레이어 몸(캡슐)을 그 자리에 놓았을 때 나무·벽과 겹치지 않고 맵 안이면 true.
func _is_free_spot(point: Vector3) -> bool:
	var limit := map_half_size - body_radius()
	if absf(point.x) > limit or absf(point.z) > limit:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = Transform3D(Basis(), point + _shape.position)
	query.collision_mask = collision_mask
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _begin_attack(aim: Vector3) -> void:
	_face(aim)
	_pause_left = attack_pause
	_has_target = false
	# 누르고 있던 좌클릭은 무시하고, 다음 좌클릭부터 다시 걷는다.
	if Input.is_action_pressed("move"):
		_click_locked = true


func _play_attack(anim_name: StringName) -> void:
	_anim.play(anim_name, 0.05, _anim.get_animation(anim_name).length / attack_anim_time)
	_anim_state = &"attack"
	_attack_anim_left = attack_anim_time


## 공격 동작이 끝났으면, 움직이는 중엔 달리기, 멈췄으면 달리기 동작의 한 자세로 세운다.
func _update_animation() -> void:
	if _attack_anim_left > 0.0:
		return
	if _moving:
		if _anim_state != &"run":
			_anim_state = &"run"
			_anim.play(&"run", 0.1, run_anim_speed)
	elif _anim_state != &"idle":
		_anim_state = &"idle"
		_anim.play(&"run", 0.1, 0.0)
		_anim.seek(idle_pose_time, true)


func _die() -> void:
	_dead = true
	velocity = Vector3.ZERO
	_visual.visible = true
	_anim.pause()
	for mesh: MeshInstance3D in _visual.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = Fx.solid(DEAD_COLOR)
	var tween := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_visual, "rotation:z", PI * 0.5, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(_visual, "position:y", body_radius(), 0.4)
	died.emit()


## 카메라에서 마우스 위치로 쏜 광선이 바닥(y = 0)과 만나는 점.
func _mouse_ground_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return global_position
	return origin + normal * (-origin.y / normal.y)


func _aim_direction() -> Vector3:
	var to_mouse := _mouse_ground_point() - global_position
	to_mouse.y = 0.0
	if to_mouse.length() < 0.05:
		return -global_basis.z
	return to_mouse.normalized()


## WASD 입력을 화면 기준(W = 화면 위쪽) 바닥 방향으로 바꾼다.
func _screen_to_world(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x - forward.normalized() * input.y).normalized()


func _clamp_to_map(point: Vector3) -> Vector3:
	var limit := map_half_size - body_radius() - 0.05
	return Vector3(clampf(point.x, -limit, limit), 0.0, clampf(point.z, -limit, limit))


func _face(direction: Vector3) -> void:
	rotation.y = atan2(-direction.x, -direction.z)
