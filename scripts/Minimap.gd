extends Control

var platform_rects: Array[Rect2] = []
var hazard_rects: Array[Rect2] = []
var pickup_points: Array[Vector2] = []
var spawn_points: Array[Vector2] = []
var player_node: Node2D = null
var world_rect := Rect2(Vector2.ZERO, Vector2.ONE)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(true)


func set_map_data(platforms: Array[Rect2], hazards: Array[Rect2], pickups: Array[Vector2], spawns: Array[Vector2], tracked_player: Node2D) -> void:
	platform_rects = platforms.duplicate()
	hazard_rects = hazards.duplicate()
	pickup_points = pickups.duplicate()
	spawn_points = spawns.duplicate()
	player_node = tracked_player
	_update_world_rect()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.047, 0.06, 0.82), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.58, 0.68, 0.72, 0.72), false, 1.0)
	if world_rect.size.x <= 1.0 or world_rect.size.y <= 1.0:
		return

	for rect in platform_rects:
		draw_rect(_world_rect_to_minimap(rect), Color(0.52, 0.62, 0.66, 0.78), true)
	for rect in hazard_rects:
		draw_rect(_world_rect_to_minimap(rect), Color(1.0, 0.2, 0.16, 0.82), true)
	for point in pickup_points:
		var p := _world_to_minimap(point)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.84, 0.28, 0.95), true)
	for point in spawn_points:
		var p := _world_to_minimap(point)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color(0.42, 1.0, 0.58, 0.82), true)

	if is_instance_valid(player_node):
		draw_circle(_world_to_minimap(player_node.global_position), 3.5, Color(0.58, 0.95, 1.0, 1.0))


func _update_world_rect() -> void:
	var has_bounds := false
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	for rect in platform_rects + hazard_rects:
		if not has_bounds:
			bounds = rect
			has_bounds = true
		else:
			bounds = bounds.merge(rect)
	for point in pickup_points + spawn_points:
		var point_rect := Rect2(point - Vector2(8, 8), Vector2(16, 16))
		if not has_bounds:
			bounds = point_rect
			has_bounds = true
		else:
			bounds = bounds.merge(point_rect)

	if not has_bounds:
		world_rect = Rect2(Vector2(-640, -360), Vector2(1280, 720))
		return

	world_rect = bounds.grow(140.0)
	world_rect.size.x = max(world_rect.size.x, 1.0)
	world_rect.size.y = max(world_rect.size.y, 1.0)


func _world_rect_to_minimap(rect: Rect2) -> Rect2:
	var top_left := _world_to_minimap(rect.position)
	var bottom_right := _world_to_minimap(rect.position + rect.size)
	return Rect2(top_left, bottom_right - top_left)


func _world_to_minimap(point: Vector2) -> Vector2:
	var normalized := Vector2(
		(point.x - world_rect.position.x) / world_rect.size.x,
		(point.y - world_rect.position.y) / world_rect.size.y
	)
	return Vector2(normalized.x * size.x, normalized.y * size.y)
