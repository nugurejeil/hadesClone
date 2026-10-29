extends CanvasLayer
## 체력 바, 스킬 쿨다운 3칸, 웨이브 표시, 웨이브 안내, 피격 비네트, 결과 화면을 코드로 만든다.
## 게임 상태는 플레이어와 WaveManager의 신호로만 받는다. R 키 재시작도 여기서 처리한다.

@export var player: Player
@export var wave_manager: WaveManager
@export var announce_time := 1.5
@export var vignette_time := 0.2
@export var defeat_delay := 1.0
@export var victory_delay := 0.6

const FONT_NAMES := ["Apple SD Gothic Neo", "Malgun Gothic", "Noto Sans CJK KR", "NanumGothic", "sans-serif"]
const SKILLS := [
	[&"melee", "우클릭", "근접"],
	[&"missile", "Q", "미사일"],
	[&"teleport", "Space", "순간이동"],
]
const SLOT_SIZE := 84.0
const SLOT_GAP := 12.0
const HEALTH_SIZE := Vector2(260.0, 28.0)
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = vec4(0.85, 0.0, 0.0, smoothstep(0.3, 0.75, d) * intensity * 0.85);
}
"""


class Slot:
	var shade: ColorRect
	var label: Label
	var left := 0.0


var _health_fill: ColorRect
var _health_label: Label
var _wave_label: Label
var _announce: Label
var _vignette: ShaderMaterial
var _result: ColorRect
var _result_title: Label
var _result_kills: Label
var _result_time: Label
var _slots := {}
var _last_health := -1
var _wave := 0
var _total_waves := 0
var _remaining := 0
var _announce_left := 0.0
var _vignette_left := 0.0
var _result_shown := false


func _ready() -> void:
	_build()
	_on_health_changed(player.health, player.max_health)
	player.health_changed.connect(_on_health_changed)
	player.skill_used.connect(_on_skill_used)
	player.died.connect(_show_result_later.bind(false, defeat_delay))
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.remaining_changed.connect(_on_remaining_changed)
	wave_manager.all_waves_cleared.connect(_show_result_later.bind(true, victory_delay))
	_total_waves = wave_manager.waves.size()
	_update_wave_label()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	for id: StringName in _slots:
		var slot: Slot = _slots[id]
		if slot.left > 0.0:
			slot.left = maxf(slot.left - delta, 0.0)
			slot.label.text = _seconds_text(slot.left)
			slot.shade.visible = slot.left > 0.0
	if _vignette_left > 0.0:
		_vignette_left = maxf(_vignette_left - delta, 0.0)
		_vignette.set_shader_parameter("intensity", _vignette_left / vignette_time)
	if _announce_left > 0.0:
		_announce_left = maxf(_announce_left - delta, 0.0)
		_announce.modulate.a = clampf(_announce_left / 0.3, 0.0, 1.0)
		_announce.visible = _announce_left > 0.0


func _on_health_changed(current: int, maximum: int) -> void:
	if _last_health >= 0 and current < _last_health:
		_vignette_left = vignette_time
	_last_health = current
	_health_fill.size.x = (HEALTH_SIZE.x - 6.0) * float(current) / float(maximum)
	_health_label.text = "%d / %d" % [current, maximum]


func _on_skill_used(skill: StringName, cooldown: float) -> void:
	var slot: Slot = _slots[skill]
	slot.left = cooldown
	slot.shade.visible = true
	slot.label.text = _seconds_text(cooldown)


## 남은 쿨다운을 0.1초 단위로 올림해서 보여준다(0.04초 남았는데 "0.0"이 뜨지 않게).
func _seconds_text(seconds: float) -> String:
	return "%.1f" % (ceilf(seconds * 10.0) / 10.0)


func _on_wave_started(wave: int, total: int) -> void:
	_wave = wave
	_total_waves = total
	_announce.text = "웨이브 %d" % wave
	_announce.visible = true
	_announce.modulate.a = 1.0
	_announce_left = announce_time
	_update_wave_label()


func _on_remaining_changed(remaining: int) -> void:
	_remaining = remaining
	_update_wave_label()


func _update_wave_label() -> void:
	if _wave == 0:
		_wave_label.text = "웨이브 - / %d" % _total_waves
	else:
		_wave_label.text = "웨이브 %d / %d · 남은 적 %d" % [_wave, _total_waves, _remaining]


func _show_result_later(victory: bool, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(_show_result.bind(victory))


func _show_result(victory: bool) -> void:
	if _result_shown:
		return
	_result_shown = true
	_result_title.text = "승리!" if victory else "쓰러졌다…"
	_result_kills.text = "처치 %d" % wave_manager.kills
	var seconds := int(wave_manager.elapsed)
	_result_time.text = "걸린 시간 %d:%02d" % [floori(seconds / 60.0), seconds % 60]
	_result.show()


# --- 화면 구성 ---

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(FONT_NAMES)
	theme.default_font = font
	theme.default_font_size = 18
	root.theme = theme
	add_child(root)

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette = ShaderMaterial.new()
	_vignette.shader = shader
	vignette.material = _vignette
	root.add_child(vignette)

	# 체력 바: 왼쪽 아래
	var health_back := _rect(Color(0.0, 0.0, 0.0, 0.6))
	_place(health_back, Vector2(0.0, 1.0), Vector2(24.0, -24.0 - HEALTH_SIZE.y), HEALTH_SIZE)
	root.add_child(health_back)
	_health_fill = _rect(Color(0.85, 0.15, 0.15))
	_health_fill.position = Vector2(3.0, 3.0)
	_health_fill.size = HEALTH_SIZE - Vector2(6.0, 6.0)
	health_back.add_child(_health_fill)
	_health_label = _label("", 18)
	_health_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	health_back.add_child(_health_label)

	# 스킬 칸 3개: 아래 가운데
	var total_width := SLOT_SIZE * SKILLS.size() + SLOT_GAP * (SKILLS.size() - 1)
	for i in SKILLS.size():
		var info: Array = SKILLS[i]
		var back := _rect(Color(0.1, 0.1, 0.16, 0.8))
		_place(back, Vector2(0.5, 1.0), Vector2(-total_width * 0.5 + (SLOT_SIZE + SLOT_GAP) * i, -24.0 - SLOT_SIZE),
				Vector2(SLOT_SIZE, SLOT_SIZE))
		root.add_child(back)
		var key := _label(info[1], 20)
		key.position = Vector2(0.0, 10.0)
		key.size = Vector2(SLOT_SIZE, 30.0)
		back.add_child(key)
		var skill_name := _label(info[2], 13)
		skill_name.position = Vector2(0.0, 50.0)
		skill_name.size = Vector2(SLOT_SIZE, 24.0)
		back.add_child(skill_name)
		var slot := Slot.new()
		slot.shade = _rect(Color(0.0, 0.0, 0.0, 0.65))
		slot.shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.shade.hide()
		back.add_child(slot.shade)
		slot.label = _label("", 28)
		slot.label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.shade.add_child(slot.label)
		_slots[info[0]] = slot

	# 웨이브 표시: 위 가운데
	_wave_label = _label("", 24)
	_place(_wave_label, Vector2(0.5, 0.0), Vector2(-300.0, 16.0), Vector2(600.0, 36.0))
	root.add_child(_wave_label)

	# 웨이브 안내: 화면 가운데
	_announce = _label("", 60)
	_place(_announce, Vector2(0.5, 0.5), Vector2(-300.0, -140.0), Vector2(600.0, 90.0))
	_announce.hide()
	root.add_child(_announce)

	# 결과 화면
	_result = _rect(Color(0.05, 0.05, 0.08, 0.85))
	_place(_result, Vector2(0.5, 0.5), Vector2(-230.0, -150.0), Vector2(460.0, 300.0))
	_result.hide()
	root.add_child(_result)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(column)
	_result_title = _label("", 52)
	_result_kills = _label("", 22)
	_result_time = _label("", 22)
	var hint := _label("R 키로 다시 시작", 18)
	hint.modulate = Color(1.0, 1.0, 1.0, 0.75)
	for label in [_result_title, _result_kills, _result_time, hint]:
		column.add_child(label)


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(int(font_size / 6.0), 3))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## anchor 지점을 기준으로 offset 위치에 size 크기로 놓는다.
func _place(control: Control, anchor: Vector2, offset: Vector2, size: Vector2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = offset.x
	control.offset_top = offset.y
	control.offset_right = offset.x + size.x
	control.offset_bottom = offset.y + size.y
