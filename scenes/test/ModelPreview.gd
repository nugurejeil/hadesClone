extends Node3D
## 새 캐릭터 모델 확인용 씬. 모델 크기에 맞춰 카메라를 잡고, 애니메이션이 있으면 재생한다.
## `-- --shot=경로.png` 를 붙여 실행하면 스크린샷을 찍고 종료한다.

@onready var model: Node3D = $Model
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	var aabb := _world_aabb(model)
	print("모델 크기: ", aabb.size, "  위치: ", aabb.position)
	var center := aabb.get_center()
	var radius := aabb.size.length() * 0.5
	camera.look_at_from_position(center + Vector3(0.6, 0.35, 1.0).normalized() * radius * 2.6, center)

	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		var names := player.get_animation_list()
		print("애니메이션: ", names)
		if not names.is_empty():
			player.play(names[0])

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			await get_tree().create_timer(0.5).timeout
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--shot="))
			get_tree().quit()


func _world_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
