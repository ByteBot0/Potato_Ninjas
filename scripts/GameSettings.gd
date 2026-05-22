extends Node

const GAME_VERSION := "0.1.0-dev"
const DEFAULT_MODE := "Deathmatch"
const DEFAULT_MAP := "Prototype Arena"
const DEFAULT_BOT_COUNT := 4
const DEFAULT_BOT_DIFFICULTY := "Normal"
const DEFAULT_MATCH_SECONDS := 180
const DEFAULT_PICKUPS_ENABLED := true
const DEFAULT_HAZARDS_ENABLED := false
const DEFAULT_NETWORK_MODE := "Solo"
const DEFAULT_LAN_IP := "127.0.0.1"
const DEFAULT_LAN_PORT := 24567
const MAP_DIR := "user://maps"
const INPUT_SETTINGS_PATH := "user://input_settings.json"
const LEGACY_PROJECT_NAMES := ["HookRex Arena"]

var game_mode := DEFAULT_MODE
var map_name := DEFAULT_MAP
var map_path := ""
var bot_count := DEFAULT_BOT_COUNT
var bot_difficulty := DEFAULT_BOT_DIFFICULTY
var match_seconds := DEFAULT_MATCH_SECONDS
var pickups_enabled := DEFAULT_PICKUPS_ENABLED
var hazards_enabled := DEFAULT_HAZARDS_ENABLED
var network_mode := DEFAULT_NETWORK_MODE
var lan_ip := DEFAULT_LAN_IP
var lan_port := DEFAULT_LAN_PORT
var builder_test_mode := false
var builder_return_map_name := ""
var builder_return_map_path := ""
var gameplay_bindings := {}
var builder_bindings := {}


func _ready() -> void:
	reset_input_defaults()
	load_input_settings()
	apply_gameplay_input_map()


func reset_defaults() -> void:
	game_mode = DEFAULT_MODE
	map_name = DEFAULT_MAP
	map_path = ""
	bot_count = DEFAULT_BOT_COUNT
	bot_difficulty = DEFAULT_BOT_DIFFICULTY
	match_seconds = DEFAULT_MATCH_SECONDS
	pickups_enabled = DEFAULT_PICKUPS_ENABLED
	hazards_enabled = DEFAULT_HAZARDS_ENABLED
	network_mode = DEFAULT_NETWORK_MODE
	lan_ip = DEFAULT_LAN_IP
	lan_port = DEFAULT_LAN_PORT
	builder_test_mode = false
	builder_return_map_name = ""
	builder_return_map_path = ""


func reset_input_defaults() -> void:
	gameplay_bindings = {
		"move_left": {"type": "key", "code": KEY_A},
		"move_right": {"type": "key", "code": KEY_D},
		"jump": {"type": "key", "code": KEY_SPACE},
		"drop": {"type": "key", "code": KEY_S},
		"fire_weapon": {"type": "mouse", "code": MOUSE_BUTTON_LEFT},
		"melee": {"type": "key", "code": KEY_F},
		"grapple": {"type": "mouse", "code": MOUSE_BUTTON_RIGHT},
		"restart_match": {"type": "key", "code": KEY_R},
		"return_to_menu": {"type": "key", "code": KEY_ESCAPE},
		"toggle_touch_controls": {"type": "key", "code": KEY_T}
	}
	builder_bindings = {
		"draw_or_move": {"type": "mouse", "code": MOUSE_BUTTON_LEFT},
		"select": {"type": "mouse", "code": MOUSE_BUTTON_LEFT},
		"pan": {"type": "mouse", "code": MOUSE_BUTTON_RIGHT},
		"delete_selected": {"type": "key", "code": KEY_DELETE},
		"return_to_menu": {"type": "key", "code": KEY_ESCAPE},
		"recenter": {"type": "key", "code": KEY_HOME}
	}


func set_binding(category: String, action: String, event: InputEvent) -> void:
	var binding := _event_to_binding(event)
	if binding.is_empty():
		return

	if category == "gameplay":
		gameplay_bindings[action] = binding
		apply_gameplay_input_map()
	else:
		builder_bindings[action] = binding

	save_input_settings()


func save_input_settings() -> void:
	var file := FileAccess.open(INPUT_SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify({"gameplay": gameplay_bindings, "builder": builder_bindings}, "\t"))


func load_input_settings() -> void:
	if not FileAccess.file_exists(INPUT_SETTINGS_PATH):
		return

	var file := FileAccess.open(INPUT_SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for key in parsed.get("gameplay", {}):
		if gameplay_bindings.has(key):
			gameplay_bindings[key] = parsed["gameplay"][key]
	for key in parsed.get("builder", {}):
		if builder_bindings.has(key):
			builder_bindings[key] = parsed["builder"][key]


func apply_gameplay_input_map() -> void:
	for action in gameplay_bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)

		var event := _binding_to_event(gameplay_bindings[action])
		if event != null:
			InputMap.action_add_event(action, event)


func builder_event_matches(action: String, event: InputEvent) -> bool:
	if not builder_bindings.has(action):
		return false

	var binding: Dictionary = builder_bindings[action]
	if event is InputEventKey and binding.get("type", "") == "key":
		return event.keycode == int(binding.get("code", 0))
	if event is InputEventMouseButton and binding.get("type", "") == "mouse":
		return event.button_index == int(binding.get("code", 0))

	return false


func binding_to_text(binding: Dictionary) -> String:
	if binding.get("type", "") == "key":
		return OS.get_keycode_string(int(binding.get("code", 0)))
	if binding.get("type", "") == "mouse":
		match int(binding.get("code", 0)):
			MOUSE_BUTTON_LEFT:
				return "Left Mouse"
			MOUSE_BUTTON_RIGHT:
				return "Right Mouse"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Mouse"
			MOUSE_BUTTON_WHEEL_UP:
				return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Wheel Down"
			_:
				return "Mouse %d" % int(binding.get("code", 0))
	return "Unbound"


func _event_to_binding(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": event.keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "code": event.button_index}
	return {}


func _binding_to_event(binding: Dictionary) -> InputEvent:
	if binding.get("type", "") == "key":
		var event := InputEventKey.new()
		event.keycode = int(binding.get("code", 0))
		return event
	if binding.get("type", "") == "mouse":
		var event := InputEventMouseButton.new()
		event.button_index = int(binding.get("code", 0))
		return event
	return null


func apply_match_setup(mode: String, selected_map: String, rivals: int, difficulty: String, seconds: int, enable_pickups: bool, enable_hazards: bool, selected_map_path: String = "") -> void:
	game_mode = mode
	map_name = selected_map
	map_path = selected_map_path
	bot_count = clampi(rivals, 0, 8)
	bot_difficulty = difficulty
	match_seconds = clampi(seconds, 30, 900)
	pickups_enabled = enable_pickups
	hazards_enabled = enable_hazards
	builder_test_mode = false
	builder_return_map_name = ""
	builder_return_map_path = ""


func apply_network_setup(mode: String, ip: String, port: int) -> void:
	network_mode = mode
	lan_ip = ip.strip_edges()
	lan_port = clampi(port, 1024, 65535)


func get_difficulty_tuning() -> Dictionary:
	match bot_difficulty:
		"Easy":
			return {
				"move_speed_multiplier": 0.82,
				"fire_rate_multiplier": 0.7,
				"health_multiplier": 0.82,
				"pickup_awareness": false
			}
		"Hard":
			return {
				"move_speed_multiplier": 1.13,
				"fire_rate_multiplier": 1.35,
				"health_multiplier": 1.18,
				"pickup_awareness": true
			}
		_:
			return {
				"move_speed_multiplier": 1.0,
				"fire_rate_multiplier": 1.0,
				"health_multiplier": 1.0,
				"pickup_awareness": true
			}


func ensure_map_dir() -> void:
	if not DirAccess.dir_exists_absolute(MAP_DIR):
		DirAccess.make_dir_recursive_absolute(MAP_DIR)
	_migrate_legacy_maps()


func _migrate_legacy_maps() -> void:
	var current_maps_dir := ProjectSettings.globalize_path(MAP_DIR)
	var app_userdata_dir := ProjectSettings.globalize_path("user://").get_base_dir()
	for project_name in LEGACY_PROJECT_NAMES:
		var legacy_maps_dir := app_userdata_dir.path_join(project_name).path_join("maps")
		if legacy_maps_dir == current_maps_dir or not DirAccess.dir_exists_absolute(legacy_maps_dir):
			continue

		var legacy_dir := DirAccess.open(legacy_maps_dir)
		if legacy_dir == null:
			continue

		legacy_dir.list_dir_begin()
		var file_name := legacy_dir.get_next()
		while not file_name.is_empty():
			if not legacy_dir.current_is_dir() and _is_user_map_file(file_name):
				var target_path := "%s/%s" % [MAP_DIR, file_name]
				if not FileAccess.file_exists(target_path):
					_copy_file(legacy_maps_dir.path_join(file_name), ProjectSettings.globalize_path(target_path))
			file_name = legacy_dir.get_next()

		legacy_dir.list_dir_end()


func _is_user_map_file(file_name: String) -> bool:
	return file_name.ends_with(".json") and not file_name.begins_with("_")


func _copy_file(from_path: String, to_path: String) -> void:
	var source := FileAccess.open(from_path, FileAccess.READ)
	if source == null:
		return
	var target := FileAccess.open(to_path, FileAccess.WRITE)
	if target == null:
		return
	target.store_buffer(source.get_buffer(source.get_length()))


func get_saved_maps() -> Array[Dictionary]:
	ensure_map_dir()
	var maps: Array[Dictionary] = []
	var dir := DirAccess.open(MAP_DIR)
	if dir == null:
		return maps

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and _is_user_map_file(file_name):
			var map_name_from_file := file_name.get_basename()
			var display_name := map_name_from_file.capitalize()
			maps.append(
				{
					"name": display_name,
					"path": "%s/%s" % [MAP_DIR, file_name]
				}
			)
		file_name = dir.get_next()

	dir.list_dir_end()
	return maps
