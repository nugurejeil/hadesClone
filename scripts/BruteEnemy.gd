extends Enemy
## 덩치: 느리게 쫓아오다가 바닥에 빨간 경고 원을 띄우고, 차오르면 범위 내려찍기. 넉백을 받지 않는다.

@export var slam_radius := 2.5
@export var warning_color := Color(0.9, 0.05, 0.05, 0.35)
@export var warning_fill_color := Color(0.9, 0.0, 0.0, 0.6)
@export var slam_color := Color(1.0, 0.4, 0.3, 0.8)

@onready var _warning: Node3D = $Warning
@onready var _warning_outer: MeshInstance3D = $Warning/Outer
@onready var _warning_fill: MeshInstance3D = $Warning/Fill


func _ready() -> void:
	super()
	_warning.scale = Vector3(slam_radius, 1.0, slam_radius)
	_warning_outer.mesh = Fx.disc()
	_warning_outer.material_override = Fx.glow(warning_color)
	_warning_fill.mesh = Fx.disc()
	_warning_fill.material_override = Fx.glow(warning_fill_color)
	_warning.hide()


func prewarm() -> void:
	super()
	_warning.show()


func _start_windup() -> void:
	_warning.show()
	_update_windup(0.0)


func _update_windup(progress: float) -> void:
	var s := clampf(progress, 0.01, 1.0)
	_warning_fill.scale = Vector3(s, 1.0, s)


func _cancel_windup() -> void:
	_warning.hide()


func _perform_attack(_to_player: Vector3, distance: float) -> void:
	Fx.spawn(Fx.ring(), Fx.glow(slam_color), global_position + Vector3.UP * 0.05, 0.25, slam_radius * 0.8, slam_radius)
	if distance <= slam_radius:
		player.take_damage(damage, global_position)
