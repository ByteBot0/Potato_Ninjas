extends Control

const ARENA_SCENE := "res://scenes/TestArena.tscn"
const MAP_BUILDER_SCENE := "res://scenes/MapBuilder.tscn"
const CONTROLS_SCENE := "res://scenes/ControlsSettings.tscn"

@onready var mode_options: OptionButton = %ModeOptions
@onready var map_options: OptionButton = %MapOptions
@onready var difficulty_options: OptionButton = %DifficultyOptions
@onready var bot_count_slider: HSlider = %BotCountSlider
@onready var bot_count_value: Label = %BotCountValue
@onready var timer_slider: HSlider = %TimerSlider
@onready var timer_value: Label = %TimerValue
@onready var pickups_check: CheckBox = %PickupsCheck
@onready var hazards_check: CheckBox = %HazardsCheck
@onready var network_options: OptionButton = %NetworkOptions
@onready var lan_ip_edit: LineEdit = %LanIpEdit
@onready var lan_port_spin: SpinBox = %LanPortSpin
@onready var network_status_label: Label = %NetworkStatusLabel
@onready var start_button: Button = %StartButton
@onready var reset_button: Button = %ResetButton
@onready var controls_button: Button = %ControlsButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel

var map_paths: Array[String] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.11, 0.16))
	version_label.text = "Version %s" % GameSettings.GAME_VERSION
	_populate_options()
	_load_settings_into_ui()
	bot_count_slider.value_changed.connect(_on_bot_count_changed)
	timer_slider.value_changed.connect(_on_timer_changed)
	mode_options.item_selected.connect(_on_mode_selected)
	network_options.item_selected.connect(_on_network_selected)
	start_button.pressed.connect(_on_start_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	controls_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(CONTROLS_SCENE))
	quit_button.pressed.connect(_on_quit_pressed)


func _populate_options() -> void:
	_add_options(mode_options, ["Deathmatch", "Hook Playground", "Map Builder"])
	mode_options.set_item_disabled(1, true)
	_populate_maps()
	_add_options(difficulty_options, ["Easy", "Normal", "Hard"])
	_add_options(network_options, ["Solo", "Host LAN", "Join LAN"])


func _populate_maps() -> void:
	map_options.clear()
	map_paths.clear()
	map_options.add_item("Prototype Arena")
	map_paths.append("")

	for map_info in GameSettings.get_saved_maps():
		map_options.add_item(map_info["name"])
		map_paths.append(map_info["path"])


func _add_options(button: OptionButton, values: Array[String]) -> void:
	button.clear()
	for value in values:
		button.add_item(value)


func _load_settings_into_ui() -> void:
	_select_option(mode_options, GameSettings.game_mode)
	_select_option(map_options, GameSettings.map_name)
	_select_option(difficulty_options, GameSettings.bot_difficulty)
	bot_count_slider.value = GameSettings.bot_count
	timer_slider.value = GameSettings.match_seconds / 60
	pickups_check.button_pressed = GameSettings.pickups_enabled
	hazards_check.button_pressed = GameSettings.hazards_enabled
	_select_option(network_options, GameSettings.network_mode)
	lan_ip_edit.text = GameSettings.lan_ip
	lan_port_spin.value = GameSettings.lan_port
	_update_bot_count_label(GameSettings.bot_count)
	_update_timer_label(GameSettings.match_seconds / 60)
	_update_lan_fields()
	_update_start_button_text()


func _select_option(button: OptionButton, value: String) -> void:
	for index in range(button.item_count):
		if button.get_item_text(index) == value:
			button.select(index)
			return

	button.select(0)


func _on_bot_count_changed(value: float) -> void:
	_update_bot_count_label(int(value))


func _on_timer_changed(value: float) -> void:
	_update_timer_label(int(value))


func _on_mode_selected(_index: int) -> void:
	_update_start_button_text()


func _on_network_selected(_index: int) -> void:
	_update_lan_fields()
	_update_start_button_text()


func _update_bot_count_label(value: int) -> void:
	bot_count_value.text = "%d" % value


func _update_timer_label(value: int) -> void:
	timer_value.text = "%d min" % value


func _update_start_button_text() -> void:
	var selected_mode := mode_options.get_item_text(mode_options.selected)
	if selected_mode == "Map Builder":
		start_button.text = "Open Builder"
		return

	var selected_network := network_options.get_item_text(network_options.selected)
	start_button.text = selected_network if selected_network != "Solo" else "Start Match"


func _update_lan_fields() -> void:
	var selected_network := network_options.get_item_text(network_options.selected)
	lan_ip_edit.editable = selected_network == "Join LAN"
	lan_port_spin.editable = selected_network != "Solo"
	network_status_label.text = ""


func _on_start_pressed() -> void:
	var selected_mode := mode_options.get_item_text(mode_options.selected)
	var selected_map_path := map_paths[map_options.selected] if map_options.selected < map_paths.size() else ""
	if selected_mode == "Map Builder":
		GameSettings.map_name = map_options.get_item_text(map_options.selected)
		GameSettings.map_path = selected_map_path
		get_tree().change_scene_to_file(MAP_BUILDER_SCENE)
		return

	GameSettings.apply_match_setup(
		selected_mode,
		map_options.get_item_text(map_options.selected),
		int(bot_count_slider.value),
		difficulty_options.get_item_text(difficulty_options.selected),
		int(timer_slider.value) * 60,
		pickups_check.button_pressed,
		hazards_check.button_pressed,
		selected_map_path
	)
	GameSettings.apply_network_setup(
		network_options.get_item_text(network_options.selected),
		lan_ip_edit.text,
		int(lan_port_spin.value)
	)
	if not _configure_network_peer():
		return

	get_tree().change_scene_to_file(ARENA_SCENE)


func _on_reset_pressed() -> void:
	GameSettings.reset_defaults()
	_load_settings_into_ui()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _configure_network_peer() -> bool:
	multiplayer.multiplayer_peer = null
	if GameSettings.network_mode == "Solo":
		return true

	var peer := ENetMultiplayerPeer.new()
	var err := OK
	if GameSettings.network_mode == "Host LAN":
		err = peer.create_server(GameSettings.lan_port, 8)
	else:
		err = peer.create_client(GameSettings.lan_ip, GameSettings.lan_port)

	if err != OK:
		network_status_label.text = "Network error %d" % err
		return false

	multiplayer.multiplayer_peer = peer
	return true
