class_name Steering
extends RefCounted
## 플레이어와 적이 같이 쓰는 이동. move_and_slide()로 미끄러지듯 비켜가고,
## 나무에 정면으로 부딪혀 미끄러질 방향이 없으면 옆으로 살짝 틀어 비켜간다.

## 진행 방향과 나무 쪽 방향의 내적이 이보다 크면 정면 충돌로 본다.
const HEAD_ON_DOT := 0.97


static func move(body: CharacterBody3D, direction: Vector3, speed: float) -> void:
	body.velocity = direction * speed
	body.move_and_slide()
	if direction == Vector3.ZERO:
		return
	var normal := tree_normal(body)
	if normal == Vector3.ZERO or direction.dot(-normal) < HEAD_ON_DOT:
		return
	# 법선 기준으로 고르면 나무 중심선을 넘나들 때마다 좌우가 바뀌어 제자리에서 떨기만 한다.
	# 진행 방향의 왼쪽으로 항상 같은 쪽으로 튼다.
	var side := direction.rotated(Vector3.UP, PI * 0.5)
	body.velocity = (direction * 0.3 + side).normalized() * speed
	body.move_and_slide()


## 마지막 move_and_slide()에서 부딪힌 나무의 바닥 방향 법선. 없으면 ZERO.
static func tree_normal(body: CharacterBody3D) -> Vector3:
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider != null and collider.is_in_group("tree"):
			var normal := collision.get_normal()
			normal.y = 0.0
			if normal.length_squared() > 0.0001:
				return normal.normalized()
	return Vector3.ZERO
