extends Control

var gi_color := Color(0.91, 0.92, 0.86)
var mask_color := Color(0.055, 0.065, 0.08)
var belt_color := Color(0.995, 0.998, 0.0)
var mustache_enabled := false
var draw_center := Vector2.ZERO
var draw_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_cosmetics(cosmetics: Dictionary) -> void:
	gi_color = cosmetics.get("gi_color", gi_color)
	mask_color = cosmetics.get("mask_color", mask_color)
	belt_color = cosmetics.get("belt_color", belt_color)
	mustache_enabled = bool(cosmetics.get("mustache_enabled", false))
	queue_redraw()


func _draw() -> void:
	draw_scale = min(size.x / 92.0, size.y / 118.0)
	draw_center = size * 0.5 + Vector2(0, 8) * draw_scale

	_draw_poly(PackedVector2Array([Vector2(-16, -24), Vector2(-5, -33), Vector2(12, -29), Vector2(22, -14), Vector2(20, 10), Vector2(12, 29), Vector2(-5, 34), Vector2(-19, 24), Vector2(-23, 4), Vector2(-21, -13)]), Color(0.78, 0.56, 0.31))
	_draw_poly(PackedVector2Array([Vector2(-9, 9), Vector2(-5, 6), Vector2(-1, 9), Vector2(-3, 14), Vector2(-8, 14)]), Color(0.46, 0.29, 0.14, 0.34))
	_draw_poly(PackedVector2Array([Vector2(6, 15), Vector2(11, 14), Vector2(14, 18), Vector2(10, 22), Vector2(5, 20)]), Color(0.46, 0.29, 0.14, 0.28))
	_draw_poly(PackedVector2Array([Vector2(-20, -6), Vector2(-12, -6), Vector2(0, 0), Vector2(3, 6), Vector2(11, -5), Vector2(23, -5), Vector2(22, 8), Vector2(15, 27), Vector2(-3, 33), Vector2(-17, 22), Vector2(-22, 3)]), gi_color, Vector2(-2, 2))
	_draw_poly(PackedVector2Array([Vector2(-18, -23.7), Vector2(-14, -20.9), Vector2(-11, -12.5), Vector2(-5, -25.1), Vector2(-3, -22.3), Vector2(-10, -8.4), Vector2(-5, 7), Vector2(-8, 7)]), gi_color.darkened(0.22), Vector2(12, 17), Vector2(1, 0.72))
	_draw_poly(PackedVector2Array([Vector2(-29, 6), Vector2(-21, -4), Vector2(17, -3), Vector2(16, 2), Vector2(-19, 1), Vector2(-27, 8), Vector2(-29, 8), Vector2(-21, -1), Vector2(-29, 7)]), belt_color, Vector2(0, 21))
	_draw_poly(PackedVector2Array([Vector2(-24.8, -4), Vector2(-18, -5), Vector2(19.9, -2), Vector2(20.9, 0), Vector2(17, 4), Vector2(-20.9, 1), Vector2(-23.8, 0), Vector2(-21.9, -2)]), mask_color, Vector2(0.5, -14), Vector2(1.03, 1))
	draw_rect(Rect2(_to_screen(Vector2(7, -16)), Vector2(6, 4) * draw_scale), Color(0.86, 0.94, 1.0), true)
	if mustache_enabled:
		_draw_poly(PackedVector2Array([Vector2(-9, 1), Vector2(-2, -2), Vector2(0, 0), Vector2(2, -2), Vector2(10, 1), Vector2(2, 4), Vector2(0, 2), Vector2(-2, 4)]), Color(0.06, 0.04, 0.03), Vector2(7, -8))


func _draw_poly(points: PackedVector2Array, color: Color, offset: Vector2 = Vector2.ZERO, local_scale: Vector2 = Vector2.ONE) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(_to_screen(offset + point * local_scale))
	draw_colored_polygon(transformed, color)


func _to_screen(point: Vector2) -> Vector2:
	return draw_center + point * draw_scale
