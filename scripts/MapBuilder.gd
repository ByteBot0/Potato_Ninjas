extends Node2D

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const DEFAULT_MAP_NAME := "custom_arena"
const TEST_MAP_NAME := "_builder_test"
const TEST_MAP_PATH := "user://maps/_builder_test.json"
const MIN_ZOOM := 0.35
const MAX_ZOOM := 3.0
const ZOOM_STEP := 1.14

var material_colors := {
	"concrete": Color(0.36, 0.43, 0.46, 0.86),
	"mesh": Color(0.35, 0.72, 0.86, 0.58),
	"nograpple": Color(0.55, 0.38, 0.62, 0.82),
	"hazard": Color(0.95, 0.28, 0.22, 0.76),
	"out_of_bounds": Color(0.18, 0.18, 0.24, 0.5),
	"player_spawn": Color(0.48, 1.0, 0.42, 0.92),
	"test_spawn": Color(0.42, 0.82, 1.0, 0.95),
	"bot_spawn": Color(1.0, 0.36, 0.28, 0.92),
	"item_spawn": Color(1.0, 0.84, 0.28, 0.92)
}

var shapes: Array[Dictionary] = []
var selected_index := -1
var drawing := false
var moving_shape := false
var panning := false
var draw_start := Vector2.ZERO
var move_start_mouse := Vector2.ZERO
var move_start_shape_pos := Vector2.ZERO
var pan_start_mouse := Vector2.ZERO
var pan_start_camera := Vector2.ZERO
var move_drag_distance := 0.0
var preview_rect := Rect2()
var current_map_path := ""
var menu_warning_pending := false

@onready var shape_root: Node2D = $ShapeRoot
@onready var preview: Polygon2D = $Preview
@onready var camera: Camera2D = $Camera2D
@onready var saved_map_options: OptionButton = %SavedMapOptions
@onready var material_options: OptionButton = %MaterialOptions
@onready var map_name_edit: LineEdit = %MapNameEdit
@onready var status_label: Label = %StatusLabel
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@onready var test_button: Button = %TestButton
@onready var delete_button: Button = %DeleteButton
@onready var clear_button: Button = %ClearButton
@onready var menu_button: Button = %MenuButton
@onready var help_label: Label = %HelpLabel


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.11, 0.16))
	GameSettings.ensure_map_dir()
	_populate_saved_maps()
	_populate_materials()
	map_name_edit.text = DEFAULT_MAP_NAME
	if GameSettings.builder_test_mode and not GameSettings.builder_return_map_name.is_empty():
		map_name_edit.text = GameSettings.builder_return_map_name
	saved_map_options.item_selected.connect(_on_saved_map_selected)
	save_button.pressed.connect(_save_map)
	load_button.pressed.connect(_load_map)
	test_button.pressed.connect(_test_map)
	delete_button.pressed.connect(_delete_selected)
	clear_button.pressed.connect(_clear_map)
	menu_button.pressed.connect(_request_menu)
	var initial_map_path := TEST_MAP_PATH if GameSettings.builder_test_mode and FileAccess.file_exists(TEST_MAP_PATH) else GameSettings.map_path
	if initial_map_path.is_empty() and GameSettings.map_name != GameSettings.DEFAULT_MAP:
		initial_map_path = _find_saved_map_path(GameSettings.map_name)

	if not initial_map_path.is_empty():
		if not GameSettings.builder_test_mode:
			map_name_edit.text = initial_map_path.get_file().get_basename()
		_select_saved_map_path(initial_map_path)
		_load_map_path(initial_map_path)
		if GameSettings.builder_test_mode and not GameSettings.builder_return_map_name.is_empty():
			map_name_edit.text = GameSettings.builder_return_map_name
	else:
		_update_status("Draw rectangles with left mouse. Select with right mouse.")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)

	if event is InputEventKey and event.pressed and not event.echo:
		if GameSettings.builder_event_matches("return_to_menu", event):
			_request_menu()
		elif GameSettings.builder_event_matches("delete_selected", event):
			_delete_selected()
		elif GameSettings.builder_event_matches("recenter", event):
			camera.global_position = Vector2(640, 360)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.ctrl_pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_zoom_at_mouse(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		get_viewport().set_input_as_handled()
		return

	if not event.pressed:
		if moving_shape and GameSettings.builder_event_matches("draw_or_move", event):
			moving_shape = false
			_rebuild_shapes()
			if move_drag_distance > 2.0:
				_update_status("Moved selected object.")
			else:
				_update_status("Selected object.")
			return
		if drawing and GameSettings.builder_event_matches("draw_or_move", event):
			drawing = false
			preview.visible = false
			_commit_rect(_make_rect(draw_start, get_global_mouse_position()))
			return
		if panning and GameSettings.builder_event_matches("pan", event):
			panning = false
			return

	if _mouse_over_ui():
		return

	if GameSettings.builder_event_matches("draw_or_move", event) and event.pressed:
		var shape_index := _find_shape_at(get_global_mouse_position())
		if shape_index != -1:
			selected_index = shape_index
			moving_shape = true
			move_start_mouse = get_global_mouse_position()
			move_start_shape_pos = shapes[selected_index]["position"]
			move_drag_distance = 0.0
			_rebuild_shapes()
			_update_status("Selected object. Hold and drag to move.")
		elif _is_spawn_material(_current_material()):
			_commit_spawn(get_global_mouse_position())
		else:
			drawing = true
			draw_start = get_global_mouse_position()
			preview_rect = Rect2(draw_start, Vector2.ZERO)
			preview.visible = true
	elif GameSettings.builder_event_matches("select", event) and event.pressed:
		_select_shape_at(get_global_mouse_position())
	elif GameSettings.builder_event_matches("pan", event) and event.pressed:
		panning = true
		pan_start_mouse = event.position
		pan_start_camera = camera.global_position


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if drawing:
		preview_rect = _make_rect(draw_start, get_global_mouse_position())
		_update_preview()
	elif moving_shape and selected_index >= 0:
		var delta := get_global_mouse_position() - move_start_mouse
		move_drag_distance = max(move_drag_distance, delta.length())
		shapes[selected_index]["position"] = move_start_shape_pos + delta
		_rebuild_shapes()
	elif panning:
		camera.global_position = pan_start_camera - (event.position - pan_start_mouse) / camera.zoom


func _zoom_at_mouse(multiplier: float) -> void:
	if _mouse_over_ui():
		return

	var before_zoom_mouse_pos := get_global_mouse_position()
	var next_zoom: float = clamp(camera.zoom.x * multiplier, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(next_zoom, next_zoom)
	var after_zoom_mouse_pos := get_global_mouse_position()
	camera.global_position += before_zoom_mouse_pos - after_zoom_mouse_pos
	_update_status("Zoom %.0f%%" % (next_zoom * 100.0))


func _commit_rect(rect: Rect2) -> void:
	if rect.size.x < 12.0 or rect.size.y < 12.0:
		_update_status("Rectangle too small.")
		return

	var shape := {
		"type": "rect",
		"material": _current_material(),
		"position": rect.position,
		"size": rect.size
	}
	shapes.append(shape)
	menu_warning_pending = false
	selected_index = shapes.size() - 1
	_rebuild_shapes()
	_update_status("Added %s rectangle." % shape["material"])


func _commit_spawn(pos: Vector2) -> void:
	var marker_size := Vector2(36, 36)
	var shape := {
		"type": "point",
		"material": _current_material(),
		"position": pos - marker_size * 0.5,
		"size": marker_size
	}
	if _current_material() == "test_spawn":
		_remove_existing_test_spawn()
	shapes.append(shape)
	menu_warning_pending = false
	selected_index = shapes.size() - 1
	_rebuild_shapes()
	_update_status("Placed %s." % shape["material"])


func _select_shape_at(pos: Vector2) -> void:
	selected_index = _find_shape_at(pos)
	if selected_index != -1:
		var shape := shapes[selected_index]
		_update_status("Selected %s." % shape["material"])

	_rebuild_shapes()
	if selected_index == -1:
		_update_status("Nothing selected.")


func _delete_selected() -> void:
	if selected_index < 0 or selected_index >= shapes.size():
		_update_status("No shape selected.")
		return

	shapes.remove_at(selected_index)
	menu_warning_pending = false
	selected_index = -1
	_rebuild_shapes()
	_update_status("Deleted selected shape.")


func _clear_map() -> void:
	shapes.clear()
	selected_index = -1
	menu_warning_pending = false
	_rebuild_shapes()
	_update_status("Cleared map.")


func _save_map() -> void:
	var map_name := _safe_map_name(map_name_edit.text)
	if map_name.is_empty():
		_update_status("Enter a map name.")
		return

	var data := {
		"version": 1,
		"name": map_name,
		"shapes": _serialize_shapes()
	}
	var file := FileAccess.open("%s/%s.json" % [GameSettings.MAP_DIR, map_name], FileAccess.WRITE)
	if file == null:
		_update_status("Could not save map.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	current_map_path = "%s/%s.json" % [GameSettings.MAP_DIR, map_name]
	GameSettings.map_name = map_name.capitalize()
	GameSettings.map_path = current_map_path
	_populate_saved_maps()
	_select_saved_map_path(current_map_path)
	_update_status("Saved %s.json with %d shapes." % [map_name, shapes.size()])


func _load_map() -> void:
	var map_name := _safe_map_name(map_name_edit.text)
	if map_name.is_empty():
		_update_status("Enter a map name.")
		return

	var path := _find_saved_map_path(map_name_edit.text)
	if path.is_empty():
		path = "%s/%s.json" % [GameSettings.MAP_DIR, map_name]
	if not FileAccess.file_exists(path):
		_update_status("No saved map named %s at %s." % [map_name, path])
		return

	_load_map_path(path)


func _test_map() -> void:
	var data := {
		"version": 1,
		"name": TEST_MAP_NAME,
		"shapes": _serialize_shapes()
	}
	var file := FileAccess.open(TEST_MAP_PATH, FileAccess.WRITE)
	if file == null:
		_update_status("Could not create test map.")
		return

	file.store_string(JSON.stringify(data, "\t"))
	GameSettings.builder_return_map_name = map_name_edit.text.strip_edges()
	GameSettings.builder_return_map_path = current_map_path
	GameSettings.apply_match_setup("Deathmatch", "Builder Test", 0, GameSettings.bot_difficulty, GameSettings.match_seconds, GameSettings.pickups_enabled, GameSettings.hazards_enabled, TEST_MAP_PATH)
	GameSettings.builder_test_mode = true
	GameSettings.builder_return_map_name = map_name_edit.text.strip_edges()
	GameSettings.builder_return_map_path = current_map_path
	GameSettings.apply_network_setup("Solo", GameSettings.lan_ip, GameSettings.lan_port)
	get_tree().change_scene_to_file("res://scenes/TestArena.tscn")


func _load_map_path(path: String) -> void:
	if not FileAccess.file_exists(path):
		_update_status("Map file not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_update_status("Could not load map: %s" % path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_update_status("Map file is invalid.")
		return

	shapes.clear()
	map_name_edit.text = String(parsed.get("name", path.get_file().get_basename()))
	for item: Variant in parsed.get("shapes", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		shapes.append(
			{
				"type": item.get("type", "rect"),
				"material": item.get("material", "concrete"),
				"position": Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0))),
				"size": Vector2(float(item.get("w", 80.0)), float(item.get("h", 40.0)))
			}
		)

	selected_index = -1
	current_map_path = path
	GameSettings.map_name = map_name_edit.text
	GameSettings.map_path = path
	_select_saved_map_path(path)
	_rebuild_shapes()
	_frame_all_shapes()
	_update_status("Loaded %s with %d shapes." % [path.get_file(), shapes.size()])


func _serialize_shapes() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for shape in shapes:
		var pos: Vector2 = shape["position"]
		var size: Vector2 = shape["size"]
		output.append(
			{
				"type": shape["type"],
				"material": shape["material"],
				"x": pos.x,
				"y": pos.y,
				"w": size.x,
				"h": size.y
			}
		)
	return output


func _rebuild_shapes() -> void:
	for child in shape_root.get_children():
		child.queue_free()

	for index in range(shapes.size()):
		var shape := shapes[index]
		var rect := Rect2(shape["position"], shape["size"])
		if shape["material"] == "test_spawn":
			_add_test_spawn_marker(shape, rect)
		elif shape["type"] == "point":
			_add_spawn_marker(shape, rect)
		else:
			var node := Polygon2D.new()
			node.polygon = _rect_polygon(rect)
			node.color = material_colors.get(shape["material"], Color.WHITE)
			shape_root.add_child(node)

		if index == selected_index:
			var outline := Line2D.new()
			outline.width = 4.0
			outline.default_color = Color(1.0, 0.96, 0.45)
			outline.points = PackedVector2Array(
				[
					rect.position,
					Vector2(rect.end.x, rect.position.y),
					rect.end,
					Vector2(rect.position.x, rect.end.y),
					rect.position
				]
			)
			shape_root.add_child(outline)


func _frame_all_shapes() -> void:
	if shapes.is_empty():
		camera.global_position = Vector2(640, 360)
		camera.zoom = Vector2.ONE
		return

	var bounds := Rect2(shapes[0]["position"], shapes[0]["size"])
	for index in range(1, shapes.size()):
		var rect := Rect2(shapes[index]["position"], shapes[index]["size"])
		bounds = bounds.merge(rect)

	var viewport_size := get_viewport_rect().size
	var usable_size := Vector2(viewport_size.x, max(viewport_size.y - 160.0, 240.0))
	var padded_size := bounds.size + Vector2(180.0, 180.0)
	var fit_zoom: float = min(usable_size.x / max(padded_size.x, 1.0), usable_size.y / max(padded_size.y, 1.0))
	var zoom_value: float = clamp(fit_zoom, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.global_position = bounds.get_center()


func _update_preview() -> void:
	preview.polygon = _rect_polygon(preview_rect)
	preview.color = material_colors.get(_current_material(), Color.WHITE)


func _add_spawn_marker(shape: Dictionary, rect: Rect2) -> void:
	var marker := Polygon2D.new()
	marker.position = rect.get_center()
	marker.color = material_colors.get(shape["material"], Color.WHITE)
	var radius := rect.size.x * 0.5
	marker.polygon = PackedVector2Array([Vector2(0, -radius), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
	shape_root.add_child(marker)

	var label := Label.new()
	label.position = rect.position + Vector2(4, 6)
	label.size = rect.size
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.04, 0.06, 0.08))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = _spawn_label(shape["material"])
	shape_root.add_child(label)


func _add_test_spawn_marker(shape: Dictionary, rect: Rect2) -> void:
	var center := rect.get_center()
	var body := Polygon2D.new()
	body.position = center
	body.color = material_colors.get(shape["material"], Color.WHITE)
	body.polygon = PackedVector2Array([Vector2(-18, -20), Vector2(-8, -30), Vector2(12, -28), Vector2(21, -13), Vector2(18, 18), Vector2(8, 31), Vector2(-12, 28), Vector2(-21, 12)])
	shape_root.add_child(body)

	var mask := Polygon2D.new()
	mask.position = center + Vector2(0, -14)
	mask.color = Color(0.035, 0.045, 0.06, 1)
	mask.polygon = PackedVector2Array([Vector2(-15, -4), Vector2(16, -4), Vector2(16, 4), Vector2(-15, 4)])
	shape_root.add_child(mask)

	var eye := Polygon2D.new()
	eye.position = center + Vector2(8, -14)
	eye.color = Color(0.86, 0.94, 1, 1)
	eye.polygon = PackedVector2Array([Vector2(-3, -2), Vector2(3, -2), Vector2(3, 2), Vector2(-3, 2)])
	shape_root.add_child(eye)


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)


func _make_rect(a: Vector2, b: Vector2) -> Rect2:
	var pos := Vector2(min(a.x, b.x), min(a.y, b.y))
	var end := Vector2(max(a.x, b.x), max(a.y, b.y))
	return Rect2(pos, end - pos)


func _populate_materials() -> void:
	material_options.clear()
	for material in ["concrete", "mesh", "nograpple", "hazard", "out_of_bounds", "player_spawn", "test_spawn", "bot_spawn", "item_spawn"]:
		material_options.add_item(material)


func _populate_saved_maps() -> void:
	saved_map_options.clear()
	saved_map_options.add_item("New Map")
	saved_map_options.set_item_metadata(0, "")
	for map_info in GameSettings.get_saved_maps():
		var index := saved_map_options.item_count
		saved_map_options.add_item(String(map_info.get("name", "Map")))
		saved_map_options.set_item_metadata(index, String(map_info.get("path", "")))


func _on_saved_map_selected(index: int) -> void:
	var path := String(saved_map_options.get_item_metadata(index))
	if path.is_empty():
		shapes.clear()
		selected_index = -1
		current_map_path = ""
		menu_warning_pending = false
		map_name_edit.text = DEFAULT_MAP_NAME
		_rebuild_shapes()
		camera.global_position = Vector2(640, 360)
		camera.zoom = Vector2.ONE
		_update_status("Started a new blank map.")
		return

	_load_map_path(path)


func _select_saved_map_path(path: String) -> void:
	for index in range(saved_map_options.item_count):
		if String(saved_map_options.get_item_metadata(index)) == path:
			saved_map_options.select(index)
			return


func _current_material() -> String:
	return material_options.get_item_text(material_options.selected)


func _safe_map_name(value: String) -> String:
	var cleaned := value.strip_edges().to_lower().replace(" ", "_")
	var output := ""
	for character in cleaned:
		if character.is_valid_identifier() or character.is_valid_int() or character == "_":
			output += character
	return output


func _request_menu() -> void:
	if not _has_out_of_bounds() and not menu_warning_pending:
		menu_warning_pending = true
		_update_status("Warning: this map has no out-of-bounds zone. Press Menu/Esc again to leave anyway.")
		return

	get_tree().change_scene_to_file(MENU_SCENE)


func _has_out_of_bounds() -> bool:
	for shape in shapes:
		if String(shape.get("material", "")) == "out_of_bounds":
			return true

	return false


func _remove_existing_test_spawn() -> void:
	for index in range(shapes.size() - 1, -1, -1):
		if String(shapes[index].get("material", "")) == "test_spawn":
			shapes.remove_at(index)
			if selected_index == index:
				selected_index = -1
			elif selected_index > index:
				selected_index -= 1


func _find_saved_map_path(map_name: String) -> String:
	var safe_name := _safe_map_name(map_name)
	if safe_name.is_empty():
		return ""

	var exact_path := "%s/%s.json" % [GameSettings.MAP_DIR, safe_name]
	if FileAccess.file_exists(exact_path):
		return exact_path

	for map_info in GameSettings.get_saved_maps():
		if _safe_map_name(String(map_info.get("name", ""))) == safe_name:
			return String(map_info.get("path", ""))
		if _safe_map_name(String(map_info.get("path", "")).get_file().get_basename()) == safe_name:
			return String(map_info.get("path", ""))

	return ""


func _mouse_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _update_status(message: String) -> void:
	status_label.text = message
	help_label.text = "Left-drag draws blocks. Spawn tools place markers with left-click. Right-click selects. Drag selected object to move. Middle-drag pans. Ctrl+wheel zooms."


func _selected_shape_contains(pos: Vector2) -> bool:
	if selected_index < 0 or selected_index >= shapes.size():
		return false

	var shape := shapes[selected_index]
	return Rect2(shape["position"], shape["size"]).has_point(pos)


func _find_shape_at(pos: Vector2) -> int:
	for index in range(shapes.size() - 1, -1, -1):
		var shape := shapes[index]
		var rect := Rect2(shape["position"], shape["size"])
		if rect.has_point(pos):
			return index

	return -1


func _is_spawn_material(material: String) -> bool:
	return material in ["player_spawn", "test_spawn", "bot_spawn", "item_spawn"]


func _spawn_label(material: String) -> String:
	match material:
		"player_spawn":
			return "P"
		"test_spawn":
			return "T"
		"bot_spawn":
			return "B"
		"item_spawn":
			return "I"
		_:
			return "?"
