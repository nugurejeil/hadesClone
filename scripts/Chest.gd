extends StaticBody3D
## 보물상자. 플레이어가 Trigger 영역에 들어오면 뚜껑 여는 애니메이션을 한 번만 재생한다.
## 나무처럼 "tree" 그룹에 넣어 두어, 플레이어와 적이 부딪히면 Steering이 옆으로 비켜 가게 한다.

@export var open_animation := &"open"

var _opened := false

@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _trigger: Area3D = $Trigger


func _ready() -> void:
	_trigger.body_entered.connect(_on_trigger_body_entered)


func _on_trigger_body_entered(body: Node3D) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	_anim.play(open_animation)
