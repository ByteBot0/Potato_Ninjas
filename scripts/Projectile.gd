extends Area2D

@export var speed := 920.0
@export var damage := 20
@export var lifetime := 1.6
@export var hit_radius := 5.0
@export var splash_radius := 0.0
@export var poison_damage := 0
@export var poison_duration := 0.0

var direction := Vector2.RIGHT
var traveled := 0.0
var shooter: Node = null
var deals_damage := true
var checked_initial_overlap := false

@onready var visual: Polygon2D = $Visual


func launch(origin: Vector2, aim_direction: Vector2, inherited_velocity: Vector2 = Vector2.ZERO, source: Node = null, target_mask: int = 5) -> void:
	global_position = origin
	direction = aim_direction.normalized()
	rotation = direction.angle()
	traveled = inherited_velocity.dot(direction) * 0.04
	shooter = source
	collision_mask = target_mask
	_update_visual_shape()


func _physics_process(delta: float) -> void:
	if not checked_initial_overlap:
		checked_initial_overlap = true
		var initial_hit := _check_initial_overlap()
		if not initial_hit.is_empty():
			_apply_hit(initial_hit)
			return

	var previous_position := global_position
	var step := direction * speed * delta
	global_position += step
	traveled += step.length()
	lifetime -= delta

	var hit := _cast_for_hit(previous_position, global_position)
	if not hit.is_empty():
		_apply_hit(hit)
		return

	if lifetime <= 0.0:
		queue_free()


func _cast_for_hit(from: Vector2, to: Vector2) -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, _get_collision_excludes())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)


func _check_initial_overlap() -> Dictionary:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = max(hit_radius, 10.0)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = _get_collision_excludes()

	var fallback_hit := {}
	for item in space_state.intersect_shape(query, 8):
		var collider: Object = item.get("collider")
		if collider == null:
			continue
		if deals_damage and collider.has_method("take_damage"):
			item["position"] = global_position
			return item
		if fallback_hit.is_empty():
			item["position"] = global_position
			fallback_hit = item

	return fallback_hit


func _get_collision_excludes() -> Array[RID]:
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		exclude.append(shooter.get_rid())

	return exclude


func _apply_hit(hit: Dictionary) -> void:
	var collider: Object = hit.get("collider")
	if deals_damage and collider != null and collider.has_method("take_damage"):
		collider.take_damage(damage, direction, shooter)
		if poison_damage > 0 and poison_duration > 0.0 and collider.has_method("apply_poison"):
			collider.apply_poison(poison_damage, poison_duration, shooter)

	var scene := get_tree().current_scene
	if scene != null and scene.has_method("spawn_hit_effect"):
		scene.spawn_hit_effect(global_position, modulate, 30.0 if splash_radius <= 0.0 else splash_radius * 0.7)
	if scene != null and scene.has_method("add_screen_shake"):
		scene.add_screen_shake(2.0 if splash_radius <= 0.0 else 7.0)

	if splash_radius > 0.0:
		_apply_splash_damage()

	queue_free()


func _apply_splash_damage() -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = splash_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hits := space_state.intersect_shape(query, 16)
	for item in hits:
		var collider: Object = item.get("collider")
		if collider == shooter:
			continue
		if deals_damage and collider != null and collider.has_method("take_damage"):
			var away: Vector2 = (collider.global_position - global_position).normalized()
			collider.take_damage(max(8, damage / 2), away, shooter)


func _update_visual_shape() -> void:
	if visual == null:
		return

	if poison_damage > 0:
		visual.polygon = PackedVector2Array([Vector2(-13, -2), Vector2(8, -2), Vector2(15, 0), Vector2(8, 2), Vector2(-13, 2), Vector2(-18, 5), Vector2(-15, 0), Vector2(-18, -5)])
	elif splash_radius > 0.0:
		visual.polygon = PackedVector2Array([Vector2(-8, -7), Vector2(7, -7), Vector2(12, 0), Vector2(7, 7), Vector2(-8, 7), Vector2(-13, 0)])
	else:
		visual.polygon = PackedVector2Array([Vector2(0, -11), Vector2(3, -3), Vector2(11, 0), Vector2(3, 3), Vector2(0, 11), Vector2(-3, 3), Vector2(-11, 0), Vector2(-3, -3)])
