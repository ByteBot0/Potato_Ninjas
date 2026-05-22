extends CharacterBody2D

signal died(victim: Node, attacker: Node)

enum WeaponKind { BLASTER, SHOTGUN, MACHINE_GUN, EGG_LAUNCHER }

const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")

@export var move_speed := 310.0
@export var acceleration := 2100.0
@export var friction := 2200.0
@export var jump_velocity := -820.0
@export var max_health := 80
@export var fire_rate := 1.25
@export var preferred_range := 430.0
@export var projectile_spawn_distance := 30.0
@export var low_health_ratio := 0.42

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body
@onready var gi_top: Polygon2D = $GiTop
@onready var gi_lapels: Polygon2D = $GiLapels
@onready var belt: Polygon2D = $Belt
@onready var mask_band: Polygon2D = $MaskBand
@onready var potato_spots: Polygon2D = $PotatoSpots
@onready var potato_spot_two: Polygon2D = $PotatoSpotTwo
@onready var health_bar: ColorRect = $HealthBar

var gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var target: Node2D = null
var pickups: Array[Node] = []
var hazard_rects: Array[Rect2] = []
var spawn_position := Vector2.ZERO
var health := max_health
var fire_cooldown := 0.4
var respawn_timer := 0.0
var is_alive := true
var weapon_kind := WeaponKind.BLASTER
var weapon_ammo := 0
var weapon_time := 0.0
var poison_damage_per_tick := 0
var poison_timer := 0.0
var poison_tick_timer := 0.0
var poison_attacker: Node = null
var current_goal := "chase"
var pickup_awareness := true
var base_body_color := Color(0.7, 0.47, 0.25)
var current_facing := 1.0


func _ready() -> void:
	_capture_visual_home_transforms()
	spawn_position = global_position
	body.color = base_body_color
	_set_collision_enabled(is_alive)
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if not is_alive:
		_update_respawn(delta)
		return

	fire_cooldown = max(fire_cooldown - delta, 0.0)
	_update_weapon_timer(delta)
	_update_poison(delta)
	_apply_gravity(delta)
	_update_movement(delta)
	_update_shooting()
	move_and_slide()


func set_target(new_target: Node2D) -> void:
	target = new_target


func set_pickups(new_pickups: Array[Node]) -> void:
	pickups = new_pickups


func set_hazards(new_hazards: Array[Rect2]) -> void:
	hazard_rects = new_hazards


func apply_difficulty_tuning(tuning: Dictionary) -> void:
	move_speed *= tuning.get("move_speed_multiplier", 1.0)
	acceleration *= tuning.get("move_speed_multiplier", 1.0)
	fire_rate *= tuning.get("fire_rate_multiplier", 1.0)
	max_health = int(round(float(max_health) * tuning.get("health_multiplier", 1.0)))
	health = max_health
	pickup_awareness = tuning.get("pickup_awareness", true)
	_update_health_bar()


func take_damage(amount: int, hit_direction: Vector2, attacker: Node = null) -> void:
	if not is_alive:
		return

	health = max(health - amount, 0)
	velocity += hit_direction.normalized() * 150.0
	_flash_body()
	_update_health_bar()
	_add_scene_feedback(global_position, Color(1.0, 0.35, 0.28), 24.0, 3.0)

	if health <= 0:
		_die(attacker)


func apply_poison(damage_per_tick: int, duration: float, attacker: Node = null) -> void:
	if not is_alive:
		return

	poison_damage_per_tick = max(poison_damage_per_tick, damage_per_tick)
	poison_timer = max(poison_timer, duration)
	if poison_tick_timer <= 0.0:
		poison_tick_timer = 1.0
	poison_attacker = attacker
	_add_scene_feedback(global_position, Color(0.32, 0.95, 0.24), 24.0, 1.2)


func apply_pull(source_pos: Vector2, strength: float) -> void:
	var pull_direction := (source_pos - global_position).normalized()
	velocity += pull_direction * strength


func _update_poison(delta: float) -> void:
	if poison_timer <= 0.0:
		return

	poison_timer = max(poison_timer - delta, 0.0)
	poison_tick_timer -= delta
	if poison_tick_timer > 0.0:
		return

	poison_tick_timer = 1.0
	take_damage(poison_damage_per_tick, Vector2.ZERO, poison_attacker)


func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
	else:
		velocity.y += gravity * delta


func _update_movement(delta: float) -> void:
	if not is_instance_valid(target) or not target.get("is_alive"):
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		return

	var move_target := _choose_move_target()
	var to_move_target := move_target - global_position
	var to_player := target.global_position - global_position
	var desired_axis: float = sign(to_move_target.x)

	if current_goal == "retreat":
		desired_axis = -sign(to_player.x)
	elif current_goal == "chase" and abs(to_player.x) < preferred_range * 0.45:
		desired_axis = -sign(to_player.x)

	if desired_axis != 0.0 and _direction_is_dangerous(desired_axis):
		var alternate_axis: float = -desired_axis
		if not _direction_is_dangerous(alternate_axis):
			desired_axis = alternate_axis
		else:
			desired_axis = 0.0

	if desired_axis != 0.0:
		velocity.x = move_toward(velocity.x, desired_axis * move_speed, acceleration * delta)
		_set_facing_direction(sign(desired_axis))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if is_on_floor() and (to_move_target.y < -45.0 or is_on_wall()):
		velocity.y = jump_velocity


func _update_shooting() -> void:
	if fire_cooldown > 0.0 or not is_instance_valid(target) or not target.get("is_alive"):
		return

	var aim := target.global_position - global_position
	if aim.length() > preferred_range * 1.5:
		return

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 131, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty() and hit.get("collider") != target:
		return

	var direction := aim.normalized()
	match weapon_kind:
		WeaponKind.SHOTGUN:
			for angle_offset in [-0.13, 0.0, 0.13]:
				_spawn_projectile(direction.rotated(angle_offset), 10, 800.0, 0.85, Color(1.0, 0.5, 0.24), 0.0)
			fire_cooldown = 0.9
		WeaponKind.MACHINE_GUN:
			_spawn_projectile(direction, 9, 980.0, 1.2, Color(0.42, 0.85, 1.0), 0.0)
			fire_cooldown = 0.16
		WeaponKind.EGG_LAUNCHER:
			_spawn_projectile(direction, 20, 660.0, 1.85, Color(0.42, 0.92, 0.36), 0.0, 1.15, 4, 4.0)
			fire_cooldown = 1.2
		_:
			_spawn_projectile(direction, 14, 850.0, 1.4, Color(1.0, 0.35, 0.28), 0.0)
			fire_cooldown = 1.0 / fire_rate

	_consume_weapon_ammo()


func _spawn_projectile(aim_direction: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float = 1.0, shot_poison_damage: int = 0, shot_poison_duration: float = 0.0) -> void:
	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.damage = shot_damage
	projectile.speed = shot_speed
	projectile.lifetime = shot_lifetime
	projectile.splash_radius = shot_splash_radius
	projectile.poison_damage = shot_poison_damage
	projectile.poison_duration = shot_poison_duration
	projectile.modulate = shot_color
	projectile.scale = Vector2.ONE * visual_scale
	projectile.launch(_get_safe_projectile_origin(aim_direction), aim_direction, velocity, self, 131)


func _get_safe_projectile_origin(aim_direction: Vector2) -> Vector2:
	var desired_origin := global_position + aim_direction * projectile_spawn_distance
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, desired_origin, 129, [get_rid()])
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_origin

	return hit.position - aim_direction * 6.0


func apply_pickup(pickup_type: StringName) -> bool:
	if not is_alive:
		return false

	match pickup_type:
		&"health":
			if health >= max_health:
				return false
			health = min(max_health, health + 35)
			_update_health_bar()
			_add_scene_feedback(global_position, Color(0.36, 0.95, 0.42), 32.0, 1.5)
		&"shield":
			health = min(max_health, health + 18)
			_update_health_bar()
			_add_scene_feedback(global_position, Color(0.48, 0.72, 1.0), 34.0, 1.5)
		&"shotgun":
			weapon_kind = WeaponKind.SHOTGUN
			weapon_ammo = 6
			weapon_time = 16.0
			_add_scene_feedback(global_position, Color(1.0, 0.63, 0.24), 30.0, 1.5)
		&"machine_gun":
			weapon_kind = WeaponKind.MACHINE_GUN
			weapon_ammo = 44
			weapon_time = 14.0
			_add_scene_feedback(global_position, Color(0.45, 0.9, 1.0), 30.0, 1.5)
		&"egg_launcher":
			weapon_kind = WeaponKind.EGG_LAUNCHER
			weapon_ammo = 4
			weapon_time = 18.0
			_add_scene_feedback(global_position, Color(0.72, 1.0, 0.46), 34.0, 1.5)
		_:
			return false

	return true


func _choose_move_target() -> Vector2:
	var health_ratio := float(health) / float(max_health)
	var desired_pickup := _find_desired_pickup(health_ratio)
	if desired_pickup != null:
		current_goal = "pickup"
		return desired_pickup.global_position

	if health_ratio <= low_health_ratio:
		current_goal = "retreat"
		return global_position

	current_goal = "chase"
	return target.global_position


func _find_desired_pickup(health_ratio: float) -> Node2D:
	if not pickup_awareness:
		return null

	var best_pickup: Node2D = null
	var best_distance := INF

	for pickup in pickups:
		if not is_instance_valid(pickup) or not pickup.get("is_available"):
			continue

		var pickup_type: String = pickup.get("pickup_type")
		var wants_pickup := false
		if health_ratio <= low_health_ratio and pickup_type == "health":
			wants_pickup = true
		elif weapon_kind == WeaponKind.BLASTER and pickup_type in ["shotgun", "machine_gun", "egg_launcher"]:
			wants_pickup = true
		elif health_ratio <= 0.65 and pickup_type == "shield":
			wants_pickup = true

		if not wants_pickup:
			continue
		if _point_is_in_hazard(pickup.global_position, 28.0):
			continue

		var distance := global_position.distance_to(pickup.global_position)
		if distance < best_distance:
			best_distance = distance
			best_pickup = pickup

	return best_pickup


func _would_step_into_hazard(axis: float) -> bool:
	var probe_points: Array[Vector2] = [
		global_position + Vector2(axis * 54.0, 24.0),
		global_position + Vector2(axis * 90.0, 24.0),
		global_position + Vector2(axis * 54.0, 56.0)
	]

	for point in probe_points:
		if _point_is_in_hazard(point, 24.0):
			return true

	return false


func _set_facing_direction(direction: float) -> void:
	if is_zero_approx(direction):
		return

	current_facing = -1.0 if direction < 0.0 else 1.0
	for node in _mirrored_visual_nodes():
		_apply_node_facing(node, current_facing)


func _capture_visual_home_transforms() -> void:
	for node in _mirrored_visual_nodes():
		if node == null:
			continue
		node.set_meta("home_position", node.position)
		node.set_meta("home_scale", node.scale)


func _mirrored_visual_nodes() -> Array:
	return [body, gi_top, gi_lapels, belt, mask_band, potato_spots, potato_spot_two]


func _apply_node_facing(node: Node2D, facing: float) -> void:
	if node == null:
		return

	var home_position: Vector2 = node.get_meta("home_position", node.position)
	var home_scale: Vector2 = node.get_meta("home_scale", node.scale)
	node.position = Vector2(home_position.x * facing, home_position.y)
	node.scale = Vector2(home_scale.x * facing, home_scale.y)


func _direction_is_dangerous(axis: float) -> bool:
	return _would_step_into_hazard(axis) or _would_drop_through_hazard(axis)


func _would_drop_through_hazard(axis: float) -> bool:
	if not is_on_floor():
		return false

	var probe_starts: Array[Vector2] = [
		global_position + Vector2(axis * 42.0, 20.0),
		global_position + Vector2(axis * 78.0, 20.0)
	]

	var probe_end_y := global_position.y + 150.0
	for start in probe_starts:
		if _vertical_fall_path_hits_hazard(start, probe_end_y, 18.0):
			return true

	return false


func _lowest_hazard_edge_y() -> float:
	var lowest := global_position.y
	for rect in hazard_rects:
		lowest = max(lowest, rect.end.y)
	return lowest


func _vertical_fall_path_hits_hazard(start: Vector2, end_y: float, margin: float) -> bool:
	for rect in hazard_rects:
		var grown_rect := rect.grow(margin)
		if start.x < grown_rect.position.x or start.x > grown_rect.end.x:
			continue
		if start.y <= grown_rect.end.y and end_y >= grown_rect.position.y:
			return true

	return false


func _point_is_in_hazard(point: Vector2, margin: float) -> bool:
	for rect in hazard_rects:
		if rect.grow(margin).has_point(point):
			return true

	return false


func _consume_weapon_ammo() -> void:
	if weapon_kind == WeaponKind.BLASTER:
		return

	weapon_ammo -= 1
	if weapon_ammo <= 0:
		_set_base_weapon()


func _update_weapon_timer(delta: float) -> void:
	if weapon_kind == WeaponKind.BLASTER:
		return

	weapon_time -= delta
	if weapon_time <= 0.0:
		_set_base_weapon()


func _set_base_weapon() -> void:
	weapon_kind = WeaponKind.BLASTER
	weapon_ammo = 0
	weapon_time = 0.0


func _die(attacker: Node) -> void:
	is_alive = false
	_set_collision_enabled(false)
	hide()
	velocity = Vector2.ZERO
	respawn_timer = 1.8
	died.emit(self, attacker)


func _update_respawn(delta: float) -> void:
	respawn_timer -= delta
	if respawn_timer > 0.0:
		return

	global_position = spawn_position
	health = max_health
	is_alive = true
	poison_timer = 0.0
	poison_tick_timer = 0.0
	poison_damage_per_tick = 0
	poison_attacker = null
	_set_base_weapon()
	body.color = base_body_color
	_set_collision_enabled(true)
	show()
	_update_health_bar()


func _set_collision_enabled(enabled: bool) -> void:
	if collision_shape == null:
		return

	collision_shape.set_deferred("disabled", not enabled)


func _flash_body() -> void:
	body.color = Color(1.0, 0.9, 0.3)
	var tween := create_tween()
	tween.tween_property(body, "color", base_body_color, 0.12)


func _update_health_bar() -> void:
	health_bar.scale.x = float(health) / float(max_health)


func _add_scene_feedback(pos: Vector2, color: Color, radius: float, shake: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("spawn_hit_effect"):
		scene.spawn_hit_effect(pos, color, radius)
	if scene != null and scene.has_method("add_screen_shake"):
		scene.add_screen_shake(shake)
