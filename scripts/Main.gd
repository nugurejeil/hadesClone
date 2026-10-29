extends Node3D
## 처음 그릴 때 생기는 셰이더 컴파일 멈춤을 없애려고, 게임에 나오는 것들을 시작할 때
## 바닥 아래(카메라에는 잡히지만 땅에 가려 안 보이는 곳)에 잠깐 한 번씩 그려 둔다.

@export var prewarm_scenes: Array[PackedScene] = []
@export var prewarm_time := 0.2

const PREWARM_SPOT := Vector3(0.0, -3.0, 0.0)


func _ready() -> void:
	for scene in prewarm_scenes:
		var inst := scene.instantiate() as Node3D
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		inst.position = PREWARM_SPOT
		add_child(inst)
		if inst is Enemy:
			(inst as Enemy).prewarm()
		get_tree().create_timer(prewarm_time).timeout.connect(inst.queue_free)
	Fx.prewarm(PREWARM_SPOT)
