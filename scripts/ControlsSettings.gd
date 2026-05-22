extends Control

const MENU_SCENE := "res://scenes/MainMenu.tscn"

var category := "gameplay"
var waiting_action := ""
var waiting_button: Button = null
var rows: VBoxContainer
var category_options: OptionButton
var status_label: Label

var display_names := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"drop": "Drop / Fast Fall",
	"fire_weapon": "Fire",
	"melee": "Bo Staff",
	"grapple": "Grapple",
	"restart_match": "Restart Match",
	"return_to_menu": "Menu / Back",
	"toggle_touch_controls": "Toggle Touch Controls",
	"draw_or_move": "Draw / Move Object",
	"select": "Select Object",
	"pan": "Pan View",
	"delete_selected": "Delete Selected",
	"recenter": "Recenter View"
}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.11, 0.16))
	_build_ui()
	_rebuild_rows()


func _input(event: InputEvent) -> void:
	if waiting_action.is_empty():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		_accept_binding(event)
	elif event is InputEventMouseButton and event.pressed:
		_accept_binding(event)


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.11, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 560)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "Controls"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.48))
	root.add_child(title)

	category_options = OptionButton.new()
	category_options.add_item("Gameplay")
	category_options.add_item("Map Builder")
	category_options.item_selected.connect(_on_category_selected)
	root.add_child(category_options)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	status_label = Label.new()
	status_label.text = "Select an action to remap."
	status_label.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	root.add_child(status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	var reset_button := Button.new()
	reset_button.text = "Reset Defaults"
	reset_button.pressed.connect(_reset_defaults)
	buttons.add_child(reset_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(MENU_SCENE))
	buttons.add_child(back_button)


func _rebuild_rows() -> void:
	for child in rows.get_children():
		child.queue_free()

	var bindings: Dictionary = GameSettings.gameplay_bindings if category == "gameplay" else GameSettings.builder_bindings
	for action in bindings.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		rows.add_child(row)

		var label := Label.new()
		label.custom_minimum_size = Vector2(250, 0)
		label.text = display_names.get(action, action)
		row.add_child(label)

		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 0)
		button.text = GameSettings.binding_to_text(bindings[action])
		button.pressed.connect(_begin_rebind.bind(action, button))
		row.add_child(button)


func _on_category_selected(index: int) -> void:
	category = "builder" if index == 1 else "gameplay"
	waiting_action = ""
	waiting_button = null
	status_label.text = "Select an action to remap."
	_rebuild_rows()


func _begin_rebind(action: String, button: Button) -> void:
	waiting_action = action
	waiting_button = button
	button.text = "Press key or mouse..."
	status_label.text = "Waiting for %s binding." % display_names.get(action, action)


func _accept_binding(event: InputEvent) -> void:
	GameSettings.set_binding(category, waiting_action, event)
	if waiting_button != null:
		var bindings: Dictionary = GameSettings.gameplay_bindings if category == "gameplay" else GameSettings.builder_bindings
		waiting_button.text = GameSettings.binding_to_text(bindings[waiting_action])
	status_label.text = "Saved binding."
	waiting_action = ""
	waiting_button = null
	get_viewport().set_input_as_handled()


func _reset_defaults() -> void:
	GameSettings.reset_input_defaults()
	GameSettings.save_input_settings()
	GameSettings.apply_gameplay_input_map()
	waiting_action = ""
	waiting_button = null
	status_label.text = "Restored default controls."
	_rebuild_rows()
