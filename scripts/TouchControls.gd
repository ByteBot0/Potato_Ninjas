extends CanvasLayer

@export var joystick_radius := 58.0
@export var aim_radius := 76.0

var move_axis := 0.0
var aim_direction := Vector2.RIGHT
var fire_pressed := false
var grapple_pressed := false
var jump_pressed := false

var _left_touch_id := -1
var _right_touch_id := -1
var _left_start := Vector2.ZERO
var _right_start := Vector2.ZERO

var _move_base: Line2D
var _move_knob: Polygon2D
var _aim_base: Line2D
var _aim_knob: Polygon2D
var _jump_button: Button
var _fire_button: Button
var _hook_button: Button


func _ready() -> void:
	add_to_group("touch_controls")
	visible = OS.has_feature("mobile")
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func get_move_axis() -> float:
	return move_axis


func get_aim_direction() -> Vector2:
	return aim_direction


func is_fire_pressed() -> bool:
	return fire_pressed


func is_grapple_pressed() -> bool:
	return grapple_pressed


func consume_jump_pressed() -> bool:
	var was_pressed := jump_pressed
	jump_pressed = false
	return was_pressed


func _build_ui() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_move_base = _make_ring(Vector2(118, 600), joystick_radius, Color(0.75, 0.9, 1.0, 0.35))
	root.add_child(_move_base)
	_move_knob = _make_diamond(Vector2(118, 600), 24.0, Color(0.75, 0.9, 1.0, 0.55))
	root.add_child(_move_knob)

	_aim_base = _make_ring(Vector2(1045, 590), aim_radius, Color(1.0, 0.9, 0.55, 0.28))
	root.add_child(_aim_base)
	_aim_knob = _make_diamond(Vector2(1045, 590), 22.0, Color(1.0, 0.9, 0.55, 0.52))
	root.add_child(_aim_knob)

	_jump_button = _make_button("J", Vector2(875, 590), Color(0.55, 0.92, 0.55, 0.5))
	_fire_button = _make_button("F", Vector2(1135, 505), Color(1.0, 0.72, 0.28, 0.52))
	_hook_button = _make_button("H", Vector2(1190, 610), Color(0.96, 0.8, 0.32, 0.55))
	root.add_child(_jump_button)
	root.add_child(_fire_button)
	root.add_child(_hook_button)

	_jump_button.button_down.connect(func() -> void: jump_pressed = true)
	_fire_button.button_down.connect(func() -> void: fire_pressed = true)
	_fire_button.button_up.connect(func() -> void: fire_pressed = false)
	_hook_button.button_down.connect(func() -> void: grapple_pressed = true)
	_hook_button.button_up.connect(func() -> void: grapple_pressed = false)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if event.position.x < get_viewport().get_visible_rect().size.x * 0.45 and _left_touch_id == -1:
			_left_touch_id = event.index
			_left_start = event.position
			_update_move_stick(event.position)
		elif _right_touch_id == -1:
			_right_touch_id = event.index
			_right_start = event.position
			_update_aim_stick(event.position)
	else:
		if event.index == _left_touch_id:
			_left_touch_id = -1
			move_axis = 0.0
			_move_knob.position = _left_start
		elif event.index == _right_touch_id:
			_right_touch_id = -1
			fire_pressed = false
			grapple_pressed = false
			_aim_knob.position = _right_start


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _left_touch_id:
		_update_move_stick(event.position)
	elif event.index == _right_touch_id:
		_update_aim_stick(event.position)


func _update_move_stick(pos: Vector2) -> void:
	var offset := pos - _left_start
	var clamped := offset.limit_length(joystick_radius)
	move_axis = clamp(clamped.x / joystick_radius, -1.0, 1.0)
	_move_base.position = _left_start
	_move_knob.position = _left_start + clamped


func _update_aim_stick(pos: Vector2) -> void:
	var offset := pos - _right_start
	var clamped := offset.limit_length(aim_radius)
	if clamped.length_squared() > 16.0:
		aim_direction = clamped.normalized()
		fire_pressed = true
	_aim_base.position = _right_start
	_aim_knob.position = _right_start + clamped


func _make_ring(pos: Vector2, radius: float, color: Color) -> Line2D:
	var ring := Line2D.new()
	ring.position = pos
	ring.width = 4.0
	ring.default_color = color
	for index in range(33):
		var angle: float = TAU * float(index) / 32.0
		ring.add_point(Vector2.RIGHT.rotated(angle) * radius)
	return ring


func _make_diamond(pos: Vector2, radius: float, color: Color) -> Polygon2D:
	var diamond := Polygon2D.new()
	diamond.position = pos
	diamond.color = color
	diamond.polygon = PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
	return diamond


func _make_button(label: String, pos: Vector2, color: Color) -> Button:
	var button := Button.new()
	button.position = pos - Vector2(34, 34)
	button.size = Vector2(68, 68)
	button.text = label
	button.add_theme_font_size_override("font_size", 24)
	button.modulate = color
	return button
