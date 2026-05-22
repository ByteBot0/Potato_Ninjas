extends Node2D

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const TARGET_DUMMY_SCENE := preload("res://scenes/TargetDummy.tscn")
const BOT_DINO_SCENE := preload("res://scenes/BotDino.tscn")
const PICKUP_SCENE := preload("res://scenes/Pickup.tscn")
const EFFECT_BURST_SCENE := preload("res://scenes/EffectBurst.tscn")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/TouchControls.tscn")
const CONCRETE_LAYER := 1
const PLAYER_LAYER := 2
const BOT_LAYER := 4
const MESH_LAYER := 64
const NO_GRAPPLE_LAYER := 128
const PROJECTILE_WORLD_MASK := CONCRETE_LAYER | NO_GRAPPLE_LAYER
const MENU_SCENE := "res://scenes/MainMenu.tscn"

var player: Node
var health_fill: ColorRect
var health_text: Label
var weapon_icon_back: ColorRect
var weapon_icon_label: Label
var weapon_label: Label
var ammo_label: Label
var score_label: Label
var timer_label: Label
var results_label: Label
var bots: Array[Node] = []
var players: Dictionary = {}
var player_scores: Dictionary = {}
var player_score := 0
var bot_score := 0
var player_deaths := 0
var match_time_left := 180.0
var match_active := true
var player_respawn_timer := 0.0
var match_sync_timer := 0.0
var rematch_ready: Dictionary = {}
var pickups: Array[Node] = []
var touch_controls: CanvasLayer
var player_spawn_position := Vector2(160, 400)
var player_spawn_positions: Array[Vector2] = []
var bot_spawn_positions: Array[Vector2] = []
var pickup_spawn_positions: Array[Vector2] = []
var hazard_rects: Array[Rect2] = []
var lan_host_map_data: Dictionary = {}
var arena_built := false
var host_left_match := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.09, 0.12, 0.17))
	match_time_left = float(GameSettings.match_seconds)
	_ensure_input_map()
	if _is_lan_match():
		_setup_lan_players()
		if multiplayer.is_server():
			_build_arena()
			_spawn_pickups()
	else:
		_build_arena()
		_spawn_player()
		_spawn_bots()
		_spawn_pickups()
	_build_debug_ui()
	_spawn_touch_controls()


func _process(delta: float) -> void:
	_update_match(delta)

	if not is_instance_valid(player):
		return

	_update_touch_controls_toggle()
	_update_hud()


func _build_arena() -> void:
	if arena_built:
		return

	arena_built = true
	if not lan_host_map_data.is_empty() and _build_custom_arena_data(lan_host_map_data):
		return
	if not GameSettings.map_path.is_empty() and _build_custom_arena(GameSettings.map_path):
		return

	var platforms := [
		{"pos": Vector2(640, 690), "size": Vector2(1450, 70), "color": Color(0.29, 0.34, 0.38)},
		{"pos": Vector2(280, 545), "size": Vector2(260, 34), "color": Color(0.35, 0.45, 0.48)},
		{"pos": Vector2(620, 470), "size": Vector2(260, 34), "color": Color(0.36, 0.50, 0.43)},
		{"pos": Vector2(980, 540), "size": Vector2(300, 34), "color": Color(0.44, 0.40, 0.53)},
		{"pos": Vector2(1170, 330), "size": Vector2(220, 34), "color": Color(0.40, 0.48, 0.58)},
		{"pos": Vector2(790, 285), "size": Vector2(220, 34), "color": Color(0.48, 0.46, 0.35)},
		{"pos": Vector2(395, 275), "size": Vector2(210, 34), "color": Color(0.45, 0.36, 0.42)},
		{"pos": Vector2(65, 390), "size": Vector2(70, 360), "color": Color(0.28, 0.33, 0.37)},
		{"pos": Vector2(1320, 380), "size": Vector2(70, 380), "color": Color(0.28, 0.33, 0.37)},
		{"pos": Vector2(700, 95), "size": Vector2(650, 34), "color": Color(0.31, 0.37, 0.44)}
	]

	for item in platforms:
		_add_platform(item["pos"], item["size"], item["color"])


func _build_custom_arena(path: String) -> bool:
	var parsed := _load_map_data_from_path(path)
	if parsed.is_empty():
		return false

	return _build_custom_arena_data(parsed)


func _load_map_data_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed


func _build_custom_arena_data(map_data: Dictionary) -> bool:
	for item: Variant in map_data.get("shapes", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var pos := Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))
		var size := Vector2(float(item.get("w", 80.0)), float(item.get("h", 40.0)))
		var material: String = item.get("material", "concrete")
		var center := pos + size * 0.5
		if item.get("type", "rect") == "point":
			_apply_custom_spawn_point(material, center)
			continue

		match material:
			"hazard":
				_add_hazard(center, size, Color(0.95, 0.28, 0.22, 0.76))
			"out_of_bounds":
				_add_out_of_bounds(center, size)
			"mesh":
				_add_platform(center, size, Color(0.35, 0.72, 0.86, 0.58), MESH_LAYER)
			"nograpple":
				_add_platform(center, size, Color(0.55, 0.38, 0.62, 0.82), NO_GRAPPLE_LAYER)
			_:
				_add_platform(center, size, Color(0.36, 0.43, 0.46, 0.86), CONCRETE_LAYER)

	return true


func _apply_custom_spawn_point(material: String, pos: Vector2) -> void:
	match material:
		"player_spawn":
			player_spawn_positions.append(pos)
			player_spawn_position = pos
		"test_spawn":
			if GameSettings.builder_test_mode:
				player_spawn_positions.clear()
				player_spawn_positions.append(pos)
				player_spawn_position = pos
		"bot_spawn":
			bot_spawn_positions.append(pos)
		"item_spawn":
			pickup_spawn_positions.append(pos)


func _ensure_input_map() -> void:
	GameSettings.apply_gameplay_input_map()
	_bind_key_action("reel_modifier", [KEY_SHIFT])


func _bind_key_action(action_name: StringName, keycodes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	else:
		InputMap.action_erase_events(action_name)

	for keycode in keycodes:
		var event := InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)


func _bind_mouse_action(action_name: StringName, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	else:
		InputMap.action_erase_events(action_name)

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


func _add_platform(pos: Vector2, size: Vector2, color: Color, layer: int = CONCRETE_LAYER) -> void:
	var body := StaticBody2D.new()
	body.name = "GrapplePlatform"
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	var half := size * 0.5
	var visual := Polygon2D.new()
	visual.color = color
	visual.polygon = PackedVector2Array(
		[
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		]
	)
	body.add_child(visual)


func _add_hazard(pos: Vector2, size: Vector2, color: Color) -> void:
	hazard_rects.append(Rect2(pos - size * 0.5, size))
	var area := Area2D.new()
	area.name = "Hazard"
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 6
	area.body_entered.connect(_on_hazard_body_entered)
	add_child(area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	area.add_child(_make_rect_visual(size, color))


func _add_out_of_bounds(pos: Vector2, size: Vector2) -> void:
	hazard_rects.append(Rect2(pos - size * 0.5, size))
	var area := Area2D.new()
	area.name = "OutOfBounds"
	area.position = pos
	area.collision_layer = 32
	area.collision_mask = 6
	area.body_entered.connect(_on_hazard_body_entered)
	add_child(area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	area.add_child(_make_rect_visual(size, Color(0.18, 0.18, 0.24, 0.36)))


func _on_hazard_body_entered(body: Node) -> void:
	if body == player and player.get("is_alive"):
		player.take_damage(player.max_health, Vector2.DOWN, null)
	elif body.has_method("_die"):
		body._die(null)


func _make_rect_visual(size: Vector2, color: Color) -> Polygon2D:
	var half := size * 0.5
	var visual := Polygon2D.new()
	visual.color = color
	visual.polygon = PackedVector2Array(
		[
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		]
	)
	return visual


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = _get_random_player_spawn()
	player.died.connect(_on_player_died)


func _setup_lan_players() -> void:
	multiplayer.peer_disconnected.connect(_on_network_peer_disconnected)

	if multiplayer.is_server():
		multiplayer.peer_connected.connect(_on_network_peer_connected)
		_host_spawn_peer(1)
	else:
		multiplayer.server_disconnected.connect(_on_host_disconnected)
		multiplayer.connected_to_server.connect(_request_network_spawn)
		call_deferred("_request_network_spawn")


func _host_spawn_peer(peer_id: int) -> void:
	if players.has(peer_id):
		return

	_spawn_network_player.rpc(peer_id, _get_random_player_spawn())


func _on_network_peer_connected(_peer_id: int) -> void:
	pass


func _on_network_peer_disconnected(peer_id: int) -> void:
	if not players.has(peer_id):
		return

	players[peer_id].queue_free()
	players.erase(peer_id)
	player_scores.erase(peer_id)
	rematch_ready.erase(peer_id)
	if multiplayer.is_server() and not match_active:
		_check_lan_rematch_ready()


func _on_host_disconnected() -> void:
	_show_host_left_message()


@rpc("authority", "call_remote", "reliable")
func _receive_host_left_game() -> void:
	_show_host_left_message()


func _show_host_left_message() -> void:
	host_left_match = true
	match_active = false
	multiplayer.multiplayer_peer = null
	results_label.text = "Host left the game\nPress Escape to return to the main menu"
	results_label.visible = true


func _return_to_menu() -> void:
	if _is_lan_match() and multiplayer.is_server():
		_receive_host_left_game.rpc()
		await get_tree().process_frame

	_change_to_main_menu()


func _change_to_main_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


func _request_network_spawn() -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		return

	_request_spawn_sync.rpc_id(1, multiplayer.get_unique_id(), GameSettings.GAME_VERSION)


@rpc("any_peer", "call_remote", "reliable")
func _request_spawn_sync(_peer_id: int, client_version: String) -> void:
	if not multiplayer.is_server():
		return

	var requester := multiplayer.get_remote_sender_id()
	if requester == 0:
		return
	if client_version != GameSettings.GAME_VERSION:
		_receive_version_mismatch.rpc_id(requester, GameSettings.GAME_VERSION, client_version)
		return

	_apply_host_match_config.rpc_id(requester, _get_host_match_config())
	_host_spawn_peer(requester)
	for peer_id in players.keys():
		_spawn_network_player.rpc_id(requester, int(peer_id), players[peer_id].global_position)


@rpc("authority", "call_remote", "reliable")
func _receive_version_mismatch(host_version: String, client_version: String) -> void:
	match_active = false
	multiplayer.multiplayer_peer = null
	results_label.text = "Version mismatch\nHost: %s\nYou: %s\nUpdate before joining" % [host_version, client_version]
	results_label.visible = true


func _get_host_match_config() -> Dictionary:
	var map_data := {}
	if not GameSettings.map_path.is_empty():
		map_data = _load_map_data_from_path(GameSettings.map_path)

	return {
		"game_version": GameSettings.GAME_VERSION,
		"game_mode": GameSettings.game_mode,
		"map_name": GameSettings.map_name,
		"map_path": "",
		"bot_count": GameSettings.bot_count,
		"bot_difficulty": GameSettings.bot_difficulty,
		"match_seconds": GameSettings.match_seconds,
		"pickups_enabled": GameSettings.pickups_enabled,
		"hazards_enabled": GameSettings.hazards_enabled,
		"map_data": map_data
	}


@rpc("authority", "call_remote", "reliable")
func _apply_host_match_config(config: Dictionary) -> void:
	GameSettings.apply_match_setup(
		String(config.get("game_mode", GameSettings.DEFAULT_MODE)),
		String(config.get("map_name", GameSettings.DEFAULT_MAP)),
		int(config.get("bot_count", GameSettings.DEFAULT_BOT_COUNT)),
		String(config.get("bot_difficulty", GameSettings.DEFAULT_BOT_DIFFICULTY)),
		int(config.get("match_seconds", GameSettings.DEFAULT_MATCH_SECONDS)),
		bool(config.get("pickups_enabled", GameSettings.DEFAULT_PICKUPS_ENABLED)),
		bool(config.get("hazards_enabled", GameSettings.DEFAULT_HAZARDS_ENABLED)),
		String(config.get("map_path", ""))
	)
	lan_host_map_data = config.get("map_data", {})
	match_time_left = float(GameSettings.match_seconds)
	_build_arena()
	_spawn_pickups()


@rpc("authority", "call_local", "reliable")
func _spawn_network_player(peer_id: int, spawn_pos: Vector2) -> void:
	if players.has(peer_id):
		players[peer_id].global_position = spawn_pos
		return

	var new_player := PLAYER_SCENE.instantiate()
	new_player.name = "Player_%d" % peer_id
	add_child(new_player)
	new_player.global_position = spawn_pos
	new_player.configure_network_player(peer_id, peer_id == multiplayer.get_unique_id(), _get_player_color(peer_id))
	new_player.died.connect(_on_player_died)
	players[peer_id] = new_player
	if not player_scores.has(peer_id):
		player_scores[peer_id] = 0

	if peer_id == multiplayer.get_unique_id():
		player = new_player


func _get_player_color(peer_id: int) -> Color:
	var palette: Array[Color] = [
		Color(0.44, 0.89, 0.36),
		Color(0.34, 0.78, 1.0),
		Color(1.0, 0.44, 0.32),
		Color(1.0, 0.78, 0.28),
		Color(0.78, 0.54, 1.0),
		Color(0.36, 1.0, 0.72)
	]
	return palette[abs(peer_id) % palette.size()]


func _is_lan_match() -> bool:
	return GameSettings.network_mode != "Solo" and multiplayer.has_multiplayer_peer()


func get_network_player_by_peer(peer_id: int) -> Node:
	return players.get(peer_id, null)


func request_network_projectile(shooter_peer_id: int, origin: Vector2, aim_direction: Vector2, inherited_velocity: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float, shot_poison_damage: int = 0, shot_poison_duration: float = 0.0) -> void:
	if not _is_lan_match():
		return

	if multiplayer.is_server():
		if shooter_peer_id != multiplayer.get_unique_id():
			_spawn_network_projectile_local(shooter_peer_id, origin, aim_direction, inherited_velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)
		_spawn_network_projectile.rpc(shooter_peer_id, origin, aim_direction, inherited_velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)
	else:
		_request_network_projectile_server.rpc_id(1, shooter_peer_id, origin, aim_direction, inherited_velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)


@rpc("any_peer", "call_remote", "unreliable")
func _request_network_projectile_server(shooter_peer_id: int, origin: Vector2, aim_direction: Vector2, inherited_velocity: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float, shot_poison_damage: int, shot_poison_duration: float) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != shooter_peer_id:
		return

	_spawn_network_projectile_local(shooter_peer_id, origin, aim_direction, inherited_velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)
	_spawn_network_projectile.rpc(shooter_peer_id, origin, aim_direction, inherited_velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)


@rpc("authority", "call_remote", "unreliable")
func _spawn_network_projectile(shooter_peer_id: int, origin: Vector2, aim_direction: Vector2, inherited_velocity: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float, shot_poison_damage: int, shot_poison_duration: float) -> void:
	if shooter_peer_id == multiplayer.get_unique_id():
		return

	_spawn_network_projectile_local(shooter_peer_id, origin, aim_direction, inherited_velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)


func _spawn_network_projectile_local(shooter_peer_id: int, origin: Vector2, aim_direction: Vector2, inherited_velocity: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float, shot_poison_damage: int = 0, shot_poison_duration: float = 0.0) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	var shooter_node: Node = get_network_player_by_peer(shooter_peer_id)
	add_child(projectile)
	projectile.damage = shot_damage
	projectile.speed = shot_speed
	projectile.lifetime = shot_lifetime
	projectile.splash_radius = shot_splash_radius
	projectile.poison_damage = shot_poison_damage
	projectile.poison_duration = shot_poison_duration
	projectile.modulate = shot_color
	projectile.scale = Vector2.ONE * visual_scale
	projectile.deals_damage = multiplayer.is_server()
	projectile.launch(origin, aim_direction, inherited_velocity, shooter_node, PROJECTILE_WORLD_MASK | PLAYER_LAYER | BOT_LAYER)


func request_network_melee(shooter_peer_id: int) -> void:
	if not _is_lan_match():
		return

	if multiplayer.is_server():
		_apply_network_melee(shooter_peer_id)
	else:
		_request_network_melee_server.rpc_id(1, shooter_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_network_melee_server(shooter_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != shooter_peer_id:
		return

	_apply_network_melee(shooter_peer_id)


func _apply_network_melee(shooter_peer_id: int) -> void:
	var shooter_node: Node = get_network_player_by_peer(shooter_peer_id)
	if shooter_node == null or not shooter_node.has_method("_start_melee"):
		return

	shooter_node._start_melee(false)


func request_network_kusarigama(shooter_peer_id: int) -> void:
	if not _is_lan_match():
		return

	if multiplayer.is_server():
		_apply_network_kusarigama(shooter_peer_id)
	else:
		_request_network_kusarigama_server.rpc_id(1, shooter_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_network_kusarigama_server(shooter_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != shooter_peer_id:
		return

	_apply_network_kusarigama(shooter_peer_id)


func _apply_network_kusarigama(shooter_peer_id: int) -> void:
	var shooter_node: Node = get_network_player_by_peer(shooter_peer_id)
	if shooter_node == null or not shooter_node.has_method("_apply_kusarigama"):
		return

	shooter_node._apply_kusarigama()


func broadcast_network_melee(shooter_peer_id: int) -> void:
	if not _is_lan_match() or not multiplayer.is_server():
		return

	_receive_network_melee.rpc(shooter_peer_id)


@rpc("authority", "call_remote", "reliable")
func _receive_network_melee(shooter_peer_id: int) -> void:
	if shooter_peer_id == multiplayer.get_unique_id():
		return

	var shooter_node: Node = get_network_player_by_peer(shooter_peer_id)
	if shooter_node != null and shooter_node.has_method("play_network_melee"):
		shooter_node.play_network_melee()


func report_network_player_death(victim_peer_id: int, attacker_peer_id: int) -> void:
	if not _is_lan_match():
		return

	if multiplayer.is_server():
		_apply_network_player_death(victim_peer_id, attacker_peer_id)
	else:
		_report_network_player_death_server.rpc_id(1, victim_peer_id, attacker_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _report_network_player_death_server(victim_peer_id: int, attacker_peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != victim_peer_id:
		return

	_apply_network_player_death(victim_peer_id, attacker_peer_id)


func _apply_network_player_death(victim_peer_id: int, attacker_peer_id: int) -> void:
	if not player_scores.has(victim_peer_id):
		player_scores[victim_peer_id] = 0
	if attacker_peer_id != 0 and attacker_peer_id != victim_peer_id:
		if not player_scores.has(attacker_peer_id):
			player_scores[attacker_peer_id] = 0
		player_scores[attacker_peer_id] = int(player_scores[attacker_peer_id]) + 1
	else:
		player_scores[victim_peer_id] = int(player_scores[victim_peer_id]) - 1

	_apply_network_player_death_visibility(victim_peer_id)
	if multiplayer.is_server():
		_receive_network_player_death.rpc(victim_peer_id)
	_sync_match_state()


@rpc("authority", "call_remote", "reliable")
func _receive_network_player_death(victim_peer_id: int) -> void:
	_apply_network_player_death_visibility(victim_peer_id)


func _apply_network_player_death_visibility(victim_peer_id: int) -> void:
	var victim := get_network_player_by_peer(victim_peer_id)
	if victim != null and victim.has_method("apply_network_death_visibility"):
		victim.apply_network_death_visibility()


func _sync_match_state() -> void:
	if not _is_lan_match() or not multiplayer.is_server():
		return

	match_sync_timer = 0.25
	_receive_match_state.rpc(match_time_left, player_scores, match_active, rematch_ready)


@rpc("authority", "call_remote", "reliable")
func _receive_match_state(host_time_left: float, host_scores: Dictionary, host_match_active: bool, host_ready: Dictionary) -> void:
	match_time_left = host_time_left
	player_scores = host_scores.duplicate()
	match_active = host_match_active
	rematch_ready = host_ready.duplicate()
	_update_lan_round_results()


func _spawn_target_dummies() -> void:
	var dummy_positions := [
		Vector2(620, 408),
		Vector2(980, 478),
		Vector2(1170, 268),
		Vector2(405, 213)
	]

	for pos in dummy_positions:
		var dummy := TARGET_DUMMY_SCENE.instantiate()
		add_child(dummy)
		dummy.global_position = pos


func _spawn_bots() -> void:
	var default_bot_positions: Array[Vector2] = [
		Vector2(620, 408),
		Vector2(980, 478),
		Vector2(1170, 268),
		Vector2(405, 213)
	]
	var bot_positions: Array[Vector2] = bot_spawn_positions if not bot_spawn_positions.is_empty() else default_bot_positions
	var requested_bot_count: int = min(GameSettings.bot_count, bot_positions.size())
	var difficulty_tuning: Dictionary = GameSettings.get_difficulty_tuning()

	for index in range(requested_bot_count):
		var pos: Vector2 = bot_positions[index]
		var bot := BOT_DINO_SCENE.instantiate()
		add_child(bot)
		bot.global_position = pos
		bot.spawn_position = pos
		bot.set_target(player)
		bot.set_pickups(pickups)
		bot.set_hazards(hazard_rects)
		bot.apply_difficulty_tuning(difficulty_tuning)
		bot.died.connect(_on_bot_died)
		bots.append(bot)


func _spawn_pickups() -> void:
	if not GameSettings.pickups_enabled:
		return
	if not pickups.is_empty():
		return

	var pickup_types := ["shotgun", "machine_gun", "egg_launcher", "health", "shield"]
	var pickup_defs: Array[Dictionary] = [
		{"pos": Vector2(285, 498), "type": "shotgun", "respawn": 9.0},
		{"pos": Vector2(620, 423), "type": "machine_gun", "respawn": 10.0},
		{"pos": Vector2(980, 493), "type": "egg_launcher", "respawn": 13.0},
		{"pos": Vector2(790, 238), "type": "health", "respawn": 8.0},
		{"pos": Vector2(1170, 283), "type": "shield", "respawn": 14.0}
	]
	if not GameSettings.map_path.is_empty():
		pickup_defs.clear()
	if not pickup_spawn_positions.is_empty():
		for index in range(pickup_spawn_positions.size()):
			pickup_defs.append(
				{
					"pos": pickup_spawn_positions[index],
					"type": pickup_types[index % pickup_types.size()],
					"respawn": 10.0
				}
			)

	for item in pickup_defs:
		var pickup := PICKUP_SCENE.instantiate()
		pickup.pickup_type = item["type"]
		pickup.respawn_time = item["respawn"]
		add_child(pickup)
		pickup.global_position = item["pos"]
		pickups.append(pickup)

	for bot in bots:
		bot.set_pickups(pickups)


func _build_debug_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var player_panel := _make_panel(Vector2(16, 14), Vector2(330, 72))
	canvas.add_child(player_panel)

	var health_back := ColorRect.new()
	health_back.position = Vector2(16, 18)
	health_back.size = Vector2(250, 18)
	health_back.color = Color(0.16, 0.06, 0.06, 0.95)
	player_panel.add_child(health_back)

	health_fill = ColorRect.new()
	health_fill.size = Vector2(250, 18)
	health_fill.color = Color(0.45, 0.95, 0.42, 1.0)
	health_back.add_child(health_fill)

	health_text = _make_hud_label(Vector2(16, 40), 16)
	player_panel.add_child(health_text)

	var weapon_panel := _make_panel(Vector2(930, 14), Vector2(330, 92))
	canvas.add_child(weapon_panel)

	weapon_icon_back = ColorRect.new()
	weapon_icon_back.position = Vector2(16, 24)
	weapon_icon_back.size = Vector2(42, 38)
	weapon_icon_back.color = Color(0.98, 0.82, 0.24)
	weapon_panel.add_child(weapon_icon_back)

	weapon_icon_label = _make_hud_label(Vector2(16, 27), 22, HORIZONTAL_ALIGNMENT_CENTER)
	weapon_icon_label.size = Vector2(42, 30)
	weapon_icon_label.add_theme_color_override("font_color", Color(0.08, 0.1, 0.12))
	weapon_panel.add_child(weapon_icon_label)

	weapon_label = _make_hud_label(Vector2(70, 20), 18)
	weapon_label.size = Vector2(230, 28)
	weapon_panel.add_child(weapon_label)

	ammo_label = _make_hud_label(Vector2(70, 48), 15)
	ammo_label.size = Vector2(230, 24)
	weapon_panel.add_child(ammo_label)

	var score_panel := _make_panel(Vector2(465, 14), Vector2(350, 86))
	canvas.add_child(score_panel)

	timer_label = _make_hud_label(Vector2(0, 10), 28, HORIZONTAL_ALIGNMENT_CENTER)
	timer_label.size = Vector2(350, 34)
	score_panel.add_child(timer_label)

	score_label = _make_hud_label(Vector2(0, 48), 18, HORIZONTAL_ALIGNMENT_CENTER)
	score_label.size = Vector2(350, 28)
	score_panel.add_child(score_label)

	results_label = Label.new()
	results_label.visible = false
	results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_label.position = Vector2(390, 250)
	results_label.size = Vector2(500, 180)
	results_label.add_theme_font_size_override("font_size", 32)
	results_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	results_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	results_label.add_theme_constant_override("shadow_offset_x", 3)
	results_label.add_theme_constant_override("shadow_offset_y", 3)
	canvas.add_child(results_label)
	_update_hud()


func _make_panel(pos: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	return panel


func _make_hud_label(pos: Vector2, font_size: int, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = alignment
	return label


func _spawn_touch_controls() -> void:
	touch_controls = TOUCH_CONTROLS_SCENE.instantiate()
	add_child(touch_controls)


func _update_touch_controls_toggle() -> void:
	if Input.is_action_just_pressed("toggle_touch_controls") and is_instance_valid(touch_controls):
		touch_controls.visible = not touch_controls.visible


func _update_match(delta: float) -> void:
	if Input.is_action_just_pressed("return_to_menu"):
		_return_to_menu()
		return

	if host_left_match:
		return

	if Input.is_action_just_pressed("restart_match") and _can_restart_match():
		_restart_match()
		return

	if Input.is_action_just_pressed("restart_match") and _can_ready_for_lan_rematch():
		_ready_for_lan_rematch()
		return

	if not match_active:
		return

	if player_respawn_timer > 0.0:
		player_respawn_timer -= delta
		if player_respawn_timer <= 0.0:
			player.respawn(_get_random_player_spawn())

	if _is_lan_match() and not multiplayer.is_server():
		match_time_left = max(match_time_left - delta, 0.0)
		return

	match_time_left = max(match_time_left - delta, 0.0)

	if _is_lan_match():
		match_sync_timer -= delta
		if match_sync_timer <= 0.0:
			_sync_match_state()

	if match_time_left <= 0.0:
		_end_match()


func _on_bot_died(_victim: Node, attacker: Node) -> void:
	if not match_active:
		return

	spawn_hit_effect(_victim.global_position, Color(1.0, 0.3, 0.22), 46.0)
	add_screen_shake(6.0)
	if attacker == player:
		player_score += 1


func _on_player_died(_victim: Node, attacker: Node) -> void:
	if not match_active:
		return

	player_deaths += 1
	player_respawn_timer = 1.5
	spawn_hit_effect(_victim.global_position, Color(0.5, 1.0, 0.38), 52.0)
	add_screen_shake(9.0)
	if _is_lan_match():
		return

	if attacker != null and attacker != player:
		bot_score += 1
	elif attacker == null:
		player_score -= 1


func _end_match() -> void:
	match_active = false
	rematch_ready.clear()
	if _is_lan_match():
		_update_lan_round_results()
		_sync_match_state()
	else:
		var result := "DRAW"
		if player_score > bot_score:
			result = "YOU WIN"
		elif player_score < bot_score:
			result = "BOTS WIN"

		results_label.text = "%s\nPlayer %d  Rivals %d\nPress R to restart" % [result, player_score, bot_score]
		results_label.visible = true


func _restart_match() -> void:
	player_score = 0
	bot_score = 0
	player_scores.clear()
	rematch_ready.clear()
	player_deaths = 0
	match_time_left = float(GameSettings.match_seconds)
	match_active = true
	player_respawn_timer = 0.0
	results_label.visible = false
	if not _is_lan_match() and is_instance_valid(player):
		player.respawn(_get_random_player_spawn())

	for bot in bots:
		bot.global_position = bot.spawn_position
		bot.health = bot.max_health
		bot.is_alive = true
		bot.respawn_timer = 0.0
		bot.show()
		bot._update_health_bar()

	for peer_id in players.keys():
		player_scores[peer_id] = 0
		var network_player: Node = players[peer_id]
		if network_player != null and network_player.has_method("respawn"):
			network_player.respawn(_get_random_player_spawn())
	if _is_lan_match() and multiplayer.is_server():
		_sync_match_state()


func _can_restart_match() -> bool:
	return not _is_lan_match() and not match_active


func _can_ready_for_lan_rematch() -> bool:
	return _is_lan_match() and not match_active


func _ready_for_lan_rematch() -> void:
	var peer_id := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_set_lan_rematch_ready(peer_id)
	else:
		_request_lan_rematch_ready.rpc_id(1, peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_lan_rematch_ready(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != peer_id:
		return

	_set_lan_rematch_ready(peer_id)


func _set_lan_rematch_ready(peer_id: int) -> void:
	if match_active or not players.has(peer_id):
		return

	rematch_ready[peer_id] = true
	_update_lan_round_results()
	_sync_match_state()
	_check_lan_rematch_ready()


func _check_lan_rematch_ready() -> void:
	if not multiplayer.is_server() or match_active or players.is_empty():
		return

	for peer_id in players.keys():
		if not bool(rematch_ready.get(peer_id, false)):
			_sync_match_state()
			return

	_restart_match()


func _update_lan_round_results() -> void:
	if not _is_lan_match():
		return

	if match_active:
		results_label.visible = false
		return

	var local_peer_id := multiplayer.get_unique_id()
	var local_score := int(player_scores.get(local_peer_id, 0))
	var best_score := local_score
	for peer_id in player_scores.keys():
		best_score = max(best_score, int(player_scores[peer_id]))

	var result := "DRAW"
	if local_score >= best_score:
		var tied_for_best := false
		for peer_id in player_scores.keys():
			if int(peer_id) != local_peer_id and int(player_scores[peer_id]) == local_score:
				tied_for_best = true
				break
		result = "DRAW" if tied_for_best else "YOU WIN"
	else:
		result = "YOU LOSE"

	var ready_count := 0
	for peer_id in players.keys():
		if bool(rematch_ready.get(peer_id, false)):
			ready_count += 1

	var ready_text := "Ready" if bool(rematch_ready.get(local_peer_id, false)) else "Press R when ready"
	results_label.text = "%s\nYou %d   Best %d\n%s\nReady %d / %d" % [
		result,
		local_score,
		best_score,
		ready_text,
		ready_count,
		players.size()
	]
	results_label.visible = true


func _get_match_text() -> String:
	var seconds_left := int(ceil(match_time_left))
	var minutes := seconds_left / 60
	var seconds := seconds_left % 60
	var text := "%s %d:%02d\n" % [GameSettings.game_mode, minutes, seconds]
	text += "Map: %s\n" % GameSettings.map_name
	text += "Rivals: %d %s\n" % [GameSettings.bot_count, GameSettings.bot_difficulty]
	text += "Player score: %d\n" % player_score
	text += "Rival score: %d\n" % bot_score
	text += "Deaths: %d\n" % player_deaths
	text += "Rivals alive: %d / %d\n" % [_count_alive_bots(), bots.size()]
	text += "Menu: Esc"
	if _can_restart_match():
		text += "  Restart: R"
	return text


func _update_hud() -> void:
	if not is_instance_valid(player):
		return

	var current_health: int = player.get("health")
	var max_health: int = player.get("max_health")
	var health_ratio: float = clamp(float(current_health) / float(max_health), 0.0, 1.0)
	health_fill.size.x = 250.0 * health_ratio
	health_text.text = "Health %d / %d" % [current_health, max_health]
	weapon_icon_back.color = player.get_hud_weapon_color()
	weapon_icon_label.text = player.get_hud_weapon_icon()
	weapon_label.text = player.get_hud_weapon_name()
	ammo_label.text = player.get_hud_ammo_text()

	var seconds_left := int(ceil(match_time_left))
	var minutes := seconds_left / 60
	var seconds := seconds_left % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
	if _is_lan_match():
		var local_peer_id := multiplayer.get_unique_id()
		var local_score := int(player_scores.get(local_peer_id, 0))
		var rival_score := 0
		for peer_id in player_scores.keys():
			if int(peer_id) != local_peer_id:
				rival_score += int(player_scores[peer_id])
		score_label.text = "You %d   Rivals %d" % [local_score, rival_score]
	else:
		score_label.text = "Player %d   Rivals %d" % [player_score, bot_score]


func _count_alive_bots() -> int:
	var alive := 0
	for bot in bots:
		if bot.get("is_alive"):
			alive += 1
	return alive


func _get_random_player_spawn() -> Vector2:
	if player_spawn_positions.is_empty():
		return player_spawn_position

	return player_spawn_positions.pick_random()


func spawn_hit_effect(pos: Vector2, color: Color = Color(1.0, 0.84, 0.28), radius: float = 28.0) -> void:
	var effect := EFFECT_BURST_SCENE.instantiate()
	add_child(effect)
	effect.global_position = pos
	effect.color = color
	effect.radius = radius


func add_screen_shake(amount: float) -> void:
	if is_instance_valid(player) and player.has_method("add_camera_shake"):
		player.add_camera_shake(amount)
