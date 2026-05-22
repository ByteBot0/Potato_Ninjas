extends Control

const MENU_SCENE := "res://scenes/MainMenu.tscn"
const PREVIEW_SCRIPT := preload("res://scripts/CharacterPreview.gd")

var preview: Control
var gi_options: OptionButton
var mask_options: OptionButton
var belt_options: OptionButton
var accessory_options: OptionButton
var achievements_box: VBoxContainer
var status_label: Label
var gi_ids: Array[String] = []
var mask_ids: Array[String] = []
var belt_ids: Array[String] = []
var accessory_ids: Array[String] = []


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.08, 0.11, 0.16))
	GameSettings.load_profile()
	_build_ui()
	_populate_options()
	_refresh_preview()
	_refresh_achievements()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_to_menu()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.11, 0.16)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := Label.new()
	title.text = "Character"
	title.position = Vector2(52, 32)
	title.size = Vector2(420, 52)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.78, 1.0, 0.48))
	add_child(title)

	var preview_panel := _make_panel(Vector2(52, 110), Vector2(360, 520))
	add_child(preview_panel)
	preview = Control.new()
	preview.set_script(PREVIEW_SCRIPT)
	preview.position = Vector2(35, 40)
	preview.size = Vector2(290, 380)
	preview_panel.add_child(preview)

	status_label = Label.new()
	status_label.position = Vector2(28, 438)
	status_label.size = Vector2(304, 50)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	preview_panel.add_child(status_label)

	var edit_panel := _make_panel(Vector2(455, 110), Vector2(360, 520))
	add_child(edit_panel)
	var rows := VBoxContainer.new()
	rows.position = Vector2(26, 28)
	rows.size = Vector2(308, 460)
	rows.add_theme_constant_override("separation", 16)
	edit_panel.add_child(rows)

	gi_options = _add_option_row(rows, "Gi")
	mask_options = _add_option_row(rows, "Mask")
	belt_options = _add_option_row(rows, "Belt")
	accessory_options = _add_option_row(rows, "Mod")
	gi_options.item_selected.connect(_on_gi_selected)
	mask_options.item_selected.connect(_on_mask_selected)
	belt_options.item_selected.connect(_on_belt_selected)
	accessory_options.item_selected.connect(_on_accessory_selected)

	var reset_button := Button.new()
	reset_button.text = "Reset Look"
	reset_button.pressed.connect(_reset_cosmetics)
	rows.add_child(reset_button)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_return_to_menu)
	rows.add_child(back_button)

	var achievements_panel := _make_panel(Vector2(850, 110), Vector2(380, 520))
	add_child(achievements_panel)
	var ach_title := Label.new()
	ach_title.text = "Achievements"
	ach_title.position = Vector2(24, 22)
	ach_title.add_theme_font_size_override("font_size", 24)
	ach_title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	achievements_panel.add_child(ach_title)
	achievements_box = VBoxContainer.new()
	achievements_box.position = Vector2(24, 70)
	achievements_box.size = Vector2(332, 420)
	achievements_box.add_theme_constant_override("separation", 12)
	achievements_panel.add_child(achievements_box)


func _make_panel(pos: Vector2, panel_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = panel_size
	return panel


func _add_option_row(parent: VBoxContainer, label_text: String) -> OptionButton:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	parent.add_child(label)
	var options := OptionButton.new()
	parent.add_child(options)
	return options


func _populate_options() -> void:
	_populate_color_options(gi_options, gi_ids, GameSettings.get_gi_options(), GameSettings.profile.get("gi_color_id", "white"))
	_populate_color_options(mask_options, mask_ids, GameSettings.get_mask_options(), GameSettings.profile.get("mask_color_id", "black"))
	_populate_color_options(belt_options, belt_ids, GameSettings.get_unlocked_belt_options(), GameSettings.profile.get("belt_color_id", "white"))
	_populate_accessory_options()


func _populate_color_options(button: OptionButton, ids: Array[String], options: Array[Dictionary], selected_id: String) -> void:
	button.clear()
	ids.clear()
	var selected_index := 0
	for option in options:
		var id := String(option.get("id", ""))
		ids.append(id)
		button.add_item(String(option.get("name", id.capitalize())))
		if id == selected_id:
			selected_index = ids.size() - 1
	button.select(selected_index)


func _populate_accessory_options() -> void:
	accessory_options.clear()
	accessory_ids.clear()
	accessory_ids.append("none")
	accessory_options.add_item("None")
	if GameSettings.is_mustache_unlocked():
		accessory_ids.append("mustache")
		accessory_options.add_item("Mustache")
	accessory_options.select(accessory_ids.find(GameSettings.profile.get("accessory_id", "none")))


func _refresh_preview() -> void:
	preview.set_cosmetics(GameSettings.get_current_cosmetics())
	status_label.text = "Kills %d    Melee %d" % [GameSettings.get_stat("kills"), GameSettings.get_stat("melee_kills")]


func _refresh_achievements() -> void:
	for child in achievements_box.get_children():
		child.queue_free()
	_add_achievement_row("10 Kills", "Yellow belt", GameSettings.get_stat("kills"), 10, GameSettings.get_belt_color("yellow"))
	_add_achievement_row("25 Kills", "Green belt", GameSettings.get_stat("kills"), 25, GameSettings.get_belt_color("green"))
	_add_achievement_row("50 Kills", "Black belt", GameSettings.get_stat("kills"), 50, GameSettings.get_belt_color("black"))
	_add_achievement_row("10 Melee Kills", "Mustache", GameSettings.get_stat("melee_kills"), 10, Color(0.06, 0.04, 0.03))


func _add_achievement_row(label_text: String, reward_text: String, value: int, target: int, reward_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(28, 28)
	swatch.color = reward_color if value >= target else Color(0.18, 0.2, 0.22)
	row.add_child(swatch)
	var label := Label.new()
	label.text = "%s  %d/%d  %s" % [label_text, min(value, target), target, reward_text]
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0) if value >= target else Color(0.62, 0.68, 0.72))
	row.add_child(label)
	achievements_box.add_child(row)


func _on_gi_selected(index: int) -> void:
	GameSettings.profile["gi_color_id"] = gi_ids[index]
	_save_and_refresh()


func _on_mask_selected(index: int) -> void:
	GameSettings.profile["mask_color_id"] = mask_ids[index]
	_save_and_refresh()


func _on_belt_selected(index: int) -> void:
	GameSettings.profile["belt_color_id"] = belt_ids[index]
	_save_and_refresh()


func _on_accessory_selected(index: int) -> void:
	GameSettings.profile["accessory_id"] = accessory_ids[index]
	_save_and_refresh()


func _reset_cosmetics() -> void:
	GameSettings.reset_cosmetics()
	_populate_options()
	_refresh_preview()


func _save_and_refresh() -> void:
	GameSettings.save_profile()
	_refresh_preview()
	_refresh_achievements()


func _return_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
