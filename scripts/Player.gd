extends CharacterBody2D

signal died(victim: Node, attacker: Node)

enum HookState { IDLE, FIRING, ATTACHED, HANGING }
enum WeaponKind { BLASTER, SHOTGUN, MACHINE_GUN, EGG_LAUNCHER }

const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const PLAYER_HIT_LAYER := 2
const BOT_HIT_LAYER := 4
const FACE_VELOCITY_THRESHOLD := 18.0
const MELEE_TARGET_MASK := PLAYER_HIT_LAYER | BOT_HIT_LAYER

@export var move_speed := 410.0
@export var ground_acceleration := 3600.0
@export var air_acceleration := 3200.0
@export var air_turnaround_multiplier := 1.65
@export var friction := 3100.0
@export var jump_velocity := -640.0
@export var fast_fall_gravity_multiplier := 1.45

@export var max_hook_range := 640.0
@export var hook_projectile_speed := 1800.0
@export var auto_reel_speed := 680.0
@export var pull_acceleration := 5200.0
@export var max_pull_speed := 1320.0
@export var arrival_distance := 22.0
@export var swing_influence := 1.0
@export var detach_momentum_multiplier := 1.08
@export var air_control_while_hooked := 0.42
@export_flags_2d_physics var grapple_collision_mask := 97
@export_flags_2d_physics var projectile_block_mask := 129

@export var fire_rate := 5.0
@export var projectile_spawn_distance := 32.0
@export var max_health := 100
@export var shield_damage_multiplier := 0.45
@export var camera_look_offset := Vector2(0, -130)
@export var network_state_send_rate := 18.0
@export var remote_interpolation_speed := 18.0
@export var remote_prediction_time := 0.045
@export var remote_snap_distance := 180.0
@export var respawn_protection_time := 0.75
@export var melee_damage := 28
@export var melee_radius := 58.0
@export var melee_cooldown_time := 0.65
@export var melee_spin_time := 0.28
@export var kusarigama_radius := 118.0
@export var kusarigama_damage_radius := 68.0
@export var kusarigama_pull_strength := 520.0
@export var poison_tick_interval := 1.0

@onready var rope: Line2D = $HookRope
@onready var hook_tip_visual: Polygon2D = $HookTip
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var body: Polygon2D = $Body
@onready var gi_top: Polygon2D = $GiTop
@onready var gi_lapels: Polygon2D = $GiLapels
@onready var belt: Polygon2D = $Belt
@onready var mask_band: Polygon2D = $MaskBand
@onready var eye: Polygon2D = $Eye
@onready var potato_spots: Polygon2D = $PotatoSpots
@onready var potato_spot_two: Polygon2D = $PotatoSpotTwo
@onready var mustache: Polygon2D = $Mustache
@onready var weapon_visual: Polygon2D = $WeaponVisual
@onready var staff_spin: Polygon2D = $StaffSpin
@onready var health_bar: ColorRect = $HealthBar
@onready var muzzle: Marker2D = $Muzzle
@onready var shield_ring: Line2D = $ShieldRing
@onready var camera: Camera2D = $Camera2D

var gravity := ProjectSettings.get_setting("physics/2d/default_gravity") as float
var hook_state := HookState.IDLE
var hook_origin := Vector2.ZERO
var hook_tip := Vector2.ZERO
var hook_anchor := Vector2.ZERO
var hook_direction := Vector2.RIGHT
var current_rope_length := 0.0
var last_pull_force := 0.0
var was_grounded := false
var fire_cooldown := 0.0
var shots_fired := 0
var health := max_health
var is_alive := true
var weapon_kind := WeaponKind.BLASTER
var weapon_ammo := 0
var weapon_time := 0.0
var shield_time := 0.0
var camera_shake := 0.0
var network_peer_id := 1
var network_send_timer := 0.0
var respawn_protection_timer := 0.0
var melee_cooldown := 0.0
var melee_spin_timer := 0.0
var melee_hit_done := false
var poison_damage_per_tick := 0
var poison_timer := 0.0
var poison_tick_timer := 0.0
var poison_attacker: Node = null
var remote_target_position := Vector2.ZERO
var remote_target_velocity := Vector2.ZERO
var remote_has_state := false
var base_body_color := Color(0.78, 0.56, 0.31)
var current_facing := 1.0
var eye_home_position := Vector2.ZERO
var _touch_controls: Node = null
var _touch_grapple_was_pressed := false
var _last_aim_direction := Vector2.RIGHT


func _ready() -> void:
	_capture_visual_home_transforms()
	eye_home_position = eye.position
	_apply_cosmetics()
	_update_health_bar()
	_set_collision_enabled(is_alive)
	_update_weapon_visual()


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	if not is_alive:
		return

	_update_touch_controls_reference()
	var input_axis := _get_move_axis()
	var touch_jump_pressed := _consume_touch_jump()
	var grounded := is_on_floor()
	was_grounded = grounded

	respawn_protection_timer = max(respawn_protection_timer - delta, 0.0)
	melee_cooldown = max(melee_cooldown - delta, 0.0)
	_update_poison(delta)
	_handle_grapple_input()
	_apply_horizontal_movement(input_axis, grounded, delta)
	_apply_gravity(grounded, delta)
	_apply_jump(grounded, touch_jump_pressed)
	_update_hook(delta, input_axis)
	_update_weapon(delta)
	_update_melee(delta, true)

	if Input.is_action_pressed("drop") and not grounded:
		velocity.y += gravity * (fast_fall_gravity_multiplier - 1.0) * delta

	move_and_slide()
	_update_visuals()
	_update_camera_shake(delta)
	_send_network_state(delta)


func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		return

	melee_cooldown = max(melee_cooldown - delta, 0.0)
	_update_remote_interpolation(delta)


func configure_network_player(peer_id: int, is_local_player: bool, player_color: Color) -> void:
	network_peer_id = peer_id
	body.color = base_body_color
	_apply_cosmetics()
	if not is_local_player:
		mask_band.color = player_color.darkened(0.35)
	eye_home_position = eye.position
	set_multiplayer_authority(peer_id)
	camera.enabled = is_local_player
	set_physics_process(is_local_player)
	set_process(not is_local_player)
	remote_target_position = global_position
	_set_facing_direction(1.0)
	_update_health_bar()
	_update_weapon_visual()


func _handle_grapple_input() -> void:
	var touch_grapple_pressed := _is_touch_grapple_pressed()
	if Input.is_action_just_pressed("grapple") or (touch_grapple_pressed and not _touch_grapple_was_pressed):
		_fire_hook()

	if Input.is_action_just_released("grapple") or (not touch_grapple_pressed and _touch_grapple_was_pressed):
		_release_hook()

	_touch_grapple_was_pressed = touch_grapple_pressed


func _apply_horizontal_movement(input_axis: float, grounded: bool, delta: float) -> void:
	var control_multiplier := 1.0
	if hook_state == HookState.ATTACHED or hook_state == HookState.HANGING:
		control_multiplier = air_control_while_hooked

	if not is_zero_approx(input_axis):
		var accel := ground_acceleration if grounded else air_acceleration
		if not grounded and not is_zero_approx(velocity.x) and sign(velocity.x) != sign(input_axis):
			accel *= air_turnaround_multiplier
		velocity.x = move_toward(velocity.x, input_axis * move_speed, accel * control_multiplier * delta)
	elif grounded:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)


func _apply_gravity(grounded: bool, delta: float) -> void:
	if grounded and velocity.y > 0.0:
		velocity.y = 0.0
		return

	var gravity_scale := 0.22 if hook_state == HookState.HANGING else 1.0
	velocity.y += gravity * gravity_scale * delta


func _apply_jump(grounded: bool, touch_jump_pressed: bool) -> void:
	if (Input.is_action_just_pressed("jump") or touch_jump_pressed) and grounded:
		velocity.y = jump_velocity


func _update_weapon(delta: float) -> void:
	fire_cooldown = max(fire_cooldown - delta, 0.0)
	_update_pickup_timers(delta)
	if Input.is_action_just_pressed("melee"):
		_start_melee(true)
	if (Input.is_action_pressed("fire_weapon") or _is_touch_fire_pressed()) and fire_cooldown <= 0.0:
		_fire_weapon()


func _start_melee(should_request_network: bool) -> void:
	if melee_cooldown > 0.0:
		return

	melee_cooldown = melee_cooldown_time
	melee_spin_timer = melee_spin_time
	melee_hit_done = false
	staff_spin.visible = true
	staff_spin.rotation = 0.0

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_apply_melee_damage()
			_broadcast_network_melee()
		elif should_request_network:
			var scene := get_tree().current_scene
			if scene != null and scene.has_method("request_network_melee"):
				scene.request_network_melee(network_peer_id)
	else:
		_apply_melee_damage()


func play_network_melee() -> void:
	melee_spin_timer = melee_spin_time
	melee_hit_done = true
	staff_spin.visible = true
	staff_spin.rotation = 0.0


func _update_melee(delta: float, can_damage: bool) -> void:
	if melee_spin_timer <= 0.0:
		staff_spin.visible = false
		return

	melee_spin_timer = max(melee_spin_timer - delta, 0.0)
	var progress := 1.0 - (melee_spin_timer / melee_spin_time)
	staff_spin.visible = true
	staff_spin.rotation = progress * TAU

	if can_damage and not melee_hit_done and melee_spin_timer <= melee_spin_time * 0.68:
		_apply_melee_damage()


func _apply_melee_damage() -> void:
	if melee_hit_done:
		return

	melee_hit_done = true
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = melee_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = MELEE_TARGET_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var hit_anyone := false
	for item in space_state.intersect_shape(query, 12):
		var collider: Object = item.get("collider")
		if collider == null or collider == self or not collider.has_method("take_damage"):
			continue

		var hit_direction := Vector2.RIGHT
		if collider is Node2D:
			hit_direction = (collider.global_position - global_position).normalized()
			if hit_direction.length_squared() <= 0.01:
				hit_direction = Vector2(body.scale.x, 0.0)
		if collider is Object:
			collider.set_meta("last_damage_kind", "melee")
		collider.take_damage(melee_damage, hit_direction, self)
		hit_anyone = true

	var feedback_color := Color(0.88, 1.0, 0.58) if hit_anyone else Color(0.68, 0.9, 1.0)
	_add_scene_feedback(global_position, feedback_color, melee_radius, 3.5 if hit_anyone else 1.5)


func _broadcast_network_melee() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("broadcast_network_melee"):
		scene.broadcast_network_melee(network_peer_id)


func _fire_weapon() -> void:
	var aim_direction := _get_aim_direction()
	match weapon_kind:
		WeaponKind.SHOTGUN:
			_fire_kusarigama()
		WeaponKind.MACHINE_GUN:
			_fire_machine_gun(aim_direction)
		WeaponKind.EGG_LAUNCHER:
			_fire_poison_dart(aim_direction)
		_:
			_spawn_projectile(aim_direction, 20, 920.0, 1.6, Color(0.98, 0.84, 0.28), 0.0)
			fire_cooldown = 1.0 / fire_rate

	shots_fired += 1
	_consume_weapon_ammo()


func _fire_kusarigama() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("request_network_kusarigama"):
			scene.request_network_kusarigama(network_peer_id)
		_add_scene_feedback(global_position, Color(0.62, 0.42, 0.24), kusarigama_radius, 2.0)
	else:
		_apply_kusarigama()

	fire_cooldown = 0.72


func _apply_kusarigama() -> void:
	var space_state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = kusarigama_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = MELEE_TARGET_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var hit_anyone := false
	for item in space_state.intersect_shape(query, 16):
		var collider: Object = item.get("collider")
		if collider == null or collider == self:
			continue

		if collider.has_method("apply_pull"):
			collider.apply_pull(global_position, kusarigama_pull_strength)
		elif collider is CharacterBody2D:
			var pull_direction: Vector2 = (global_position - collider.global_position).normalized()
			collider.velocity += pull_direction * kusarigama_pull_strength

		if collider is Node2D and collider.has_method("take_damage"):
			var distance: float = global_position.distance_to(collider.global_position)
			if distance <= kusarigama_damage_radius:
				var hit_direction: Vector2 = (collider.global_position - global_position).normalized()
				collider.take_damage(36, hit_direction, self)
			else:
				collider.take_damage(10, Vector2.ZERO, self)
			hit_anyone = true

	_add_scene_feedback(global_position, Color(0.62, 0.42, 0.24), kusarigama_radius, 5.0 if hit_anyone else 2.0)


func _fire_machine_gun(aim_direction: Vector2) -> void:
	_spawn_projectile(aim_direction, 12, 1040.0, 1.35, Color(0.7, 0.95, 1.0), 0.0)
	fire_cooldown = 0.095


func _fire_poison_dart(aim_direction: Vector2) -> void:
	_spawn_projectile(aim_direction, 24, 720.0, 1.85, Color(0.42, 0.92, 0.36), 0.0, 1.15, 5, 4.0)
	fire_cooldown = 0.95


func _spawn_projectile(aim_direction: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float = 1.0, shot_poison_damage: int = 0, shot_poison_duration: float = 0.0) -> void:
	var origin := _get_safe_projectile_origin(aim_direction)
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
	projectile.deals_damage = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	projectile.launch(origin, aim_direction, velocity, self, projectile_block_mask | PLAYER_HIT_LAYER | BOT_HIT_LAYER)
	_request_network_projectile(origin, aim_direction, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)


func _request_network_projectile(origin: Vector2, aim_direction: Vector2, shot_damage: int, shot_speed: float, shot_lifetime: float, shot_color: Color, shot_splash_radius: float, visual_scale: float, shot_poison_damage: int, shot_poison_duration: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	var scene := get_tree().current_scene
	if scene != null and scene.has_method("request_network_projectile"):
		scene.request_network_projectile(network_peer_id, origin, aim_direction, velocity, shot_damage, shot_speed, shot_lifetime, shot_color, shot_splash_radius, visual_scale, shot_poison_damage, shot_poison_duration)


func _get_safe_projectile_origin(aim_direction: Vector2) -> Vector2:
	var desired_origin := global_position + aim_direction * projectile_spawn_distance
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, desired_origin, projectile_block_mask, [get_rid()])
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_origin

	return hit.position - aim_direction * 6.0


func _consume_weapon_ammo() -> void:
	if weapon_kind == WeaponKind.BLASTER:
		return

	weapon_ammo -= 1
	if weapon_ammo <= 0:
		_set_base_weapon()


func _update_pickup_timers(delta: float) -> void:
	if weapon_kind != WeaponKind.BLASTER and weapon_time > 0.0:
		weapon_time -= delta
		if weapon_time <= 0.0:
			_set_base_weapon()

	if shield_time > 0.0:
		shield_time = max(shield_time - delta, 0.0)


func _fire_hook() -> void:
	var aim_vector := _get_aim_direction()

	hook_state = HookState.FIRING
	hook_origin = global_position
	hook_tip = global_position
	hook_direction = aim_vector.normalized()
	hook_anchor = Vector2.ZERO
	current_rope_length = 0.0
	last_pull_force = 0.0


func _release_hook() -> void:
	if hook_state == HookState.ATTACHED or hook_state == HookState.HANGING:
		velocity *= detach_momentum_multiplier

	hook_state = HookState.IDLE
	last_pull_force = 0.0


func _update_hook(delta: float, input_axis: float) -> void:
	match hook_state:
		HookState.IDLE:
			pass
		HookState.FIRING:
			_update_firing_hook(delta)
		HookState.ATTACHED, HookState.HANGING:
			_update_attached_hook(delta, input_axis)


func _update_firing_hook(delta: float) -> void:
	var previous_tip := hook_tip
	var remaining_range := max_hook_range - hook_origin.distance_to(hook_tip)
	if remaining_range <= 0.0:
		hook_state = HookState.IDLE
		return

	var travel_distance: float = min(hook_projectile_speed * delta, remaining_range)
	var step: Vector2 = hook_direction * travel_distance
	hook_tip += step

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(previous_tip, hook_tip, grapple_collision_mask, [get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		hook_anchor = hit.position
		hook_tip = hook_anchor
		current_rope_length = global_position.distance_to(hook_anchor)
		hook_state = HookState.ATTACHED
		return

	if hook_origin.distance_to(hook_tip) >= max_hook_range:
		hook_state = HookState.IDLE


func _update_attached_hook(delta: float, input_axis: float) -> void:
	var to_anchor := hook_anchor - global_position
	var distance := to_anchor.length()
	if distance <= 0.1:
		return

	var direction := to_anchor / distance

	if distance <= arrival_distance:
		_update_hanging_hook(delta, input_axis, direction)
		return

	var target_length: float = max(arrival_distance, current_rope_length - auto_reel_speed * delta)
	current_rope_length = min(target_length, distance)

	var desired_speed: float = clamp((distance - current_rope_length) * 10.5 + auto_reel_speed, 0.0, max_pull_speed)
	var pull_velocity: Vector2 = direction * desired_speed
	if direction.y < -0.12 and abs(direction.x) > 0.25:
		pull_velocity.y = min(pull_velocity.y, -desired_speed * 0.82)
	velocity = velocity.move_toward(pull_velocity, pull_acceleration * delta)

	var tangent := Vector2(-direction.y, direction.x)
	velocity += tangent * input_axis * move_speed * swing_influence * delta
	last_pull_force = desired_speed

	hook_state = HookState.ATTACHED


func _update_hanging_hook(delta: float, input_axis: float, direction: Vector2) -> void:
	hook_state = HookState.HANGING
	last_pull_force = 0.0

	var radial_speed := velocity.dot(direction)
	if radial_speed > 0.0:
		velocity -= direction * radial_speed

	var tangent := Vector2(-direction.y, direction.x)
	velocity += tangent * input_axis * move_speed * swing_influence * delta

	var tangent_speed := velocity.dot(tangent)
	if abs(tangent_speed) < 55.0 and input_axis == 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, 160.0 * delta)


func _update_visuals() -> void:
	var aim := _get_aim_direction()
	if abs(velocity.x) > FACE_VELOCITY_THRESHOLD:
		_set_facing_direction(sign(velocity.x))

	if aim.length_squared() > 0.1:
		muzzle.position = aim.normalized() * projectile_spawn_distance
		_apply_node_facing(muzzle, current_facing)
		_apply_node_facing(weapon_visual, current_facing)

	shield_ring.visible = shield_time > 0.0
	if shield_ring.visible:
		shield_ring.rotation += get_physics_process_delta_time() * 1.6

	var show_hook := hook_state != HookState.IDLE
	rope.visible = show_hook
	hook_tip_visual.visible = show_hook

	if show_hook:
		var end_point := hook_anchor if hook_state == HookState.ATTACHED or hook_state == HookState.HANGING else hook_tip
		rope.clear_points()
		rope.add_point(Vector2.ZERO)
		rope.add_point(to_local(end_point))
		hook_tip_visual.position = to_local(end_point)


func get_debug_text() -> String:
	var attached := hook_state == HookState.ATTACHED or hook_state == HookState.HANGING
	var hook_distance := 0.0
	if hook_state == HookState.FIRING:
		hook_distance = hook_origin.distance_to(hook_tip)
	elif attached:
		hook_distance = global_position.distance_to(hook_anchor)

	var text := "Potato Ninjas - Shooting Playground\n"
	text += "Move: A/D  Jump: Space/W  Fire: Left Mouse  Melee: F  Hook: Right Mouse  Fast fall: S\n"
	text += "Velocity: %s\n" % _format_vec(velocity)
	text += "Hook state: %s\n" % _hook_state_name()
	text += "Hook distance: %.1f / %.1f\n" % [hook_distance, max_hook_range]
	text += "Attached: %s\n" % str(attached)
	text += "Reel speed / pull: %.1f\n" % last_pull_force
	text += "Health: %d / %d\n" % [health, max_health]
	text += "Weapon: %s\n" % _weapon_name()
	text += "Ammo / time: %d / %.1f\n" % [weapon_ammo, weapon_time]
	text += "Shield: %.1f\n" % shield_time
	text += "Fire cooldown: %.2f\n" % fire_cooldown
	text += "Melee cooldown: %.2f\n" % melee_cooldown
	text += "Shots fired: %d\n" % shots_fired
	text += "Grounded: %s" % str(was_grounded)
	return text


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	hook_state = HookState.IDLE
	health = max_health
	is_alive = true
	poison_timer = 0.0
	poison_tick_timer = 0.0
	poison_damage_per_tick = 0
	poison_attacker = null
	respawn_protection_timer = respawn_protection_time
	_set_base_weapon()
	shield_time = 0.0
	_update_health_bar()
	_update_weapon_visual()
	_set_collision_enabled(true)
	show()
	set_physics_process(true)


func take_damage(amount: int, hit_direction: Vector2, attacker: Node = null) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		_receive_network_damage.rpc_id(network_peer_id, amount, hit_direction, _get_attacker_peer_id(attacker))
		return

	_apply_damage(amount, hit_direction, attacker)


func _apply_damage(amount: int, hit_direction: Vector2, attacker: Node = null) -> void:
	if not is_alive:
		return
	if respawn_protection_timer > 0.0:
		return

	var final_damage := amount
	if shield_time > 0.0:
		final_damage = max(1, int(round(float(amount) * shield_damage_multiplier)))

	health = max(health - final_damage, 0)
	velocity += hit_direction.normalized() * 120.0
	_flash_body()
	_update_health_bar()
	_add_scene_feedback(global_position, Color(0.5, 1.0, 0.38), 24.0, 4.0)

	if health <= 0:
		is_alive = false
		_set_collision_enabled(false)
		hide()
		set_physics_process(false)
		died.emit(self, attacker)
		_report_network_death(attacker)


func apply_poison(damage_per_tick: int, duration: float, attacker: Node = null) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		_receive_network_poison.rpc_id(network_peer_id, damage_per_tick, duration, _get_attacker_peer_id(attacker))
		return

	_apply_poison(damage_per_tick, duration, attacker)


func apply_pull(source_pos: Vector2, strength: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		_receive_network_pull.rpc_id(network_peer_id, source_pos, strength)
		return

	var pull_direction := (source_pos - global_position).normalized()
	velocity += pull_direction * strength


func _apply_poison(damage_per_tick: int, duration: float, attacker: Node = null) -> void:
	if not is_alive:
		return

	poison_damage_per_tick = max(poison_damage_per_tick, damage_per_tick)
	poison_timer = max(poison_timer, duration)
	if poison_tick_timer <= 0.0:
		poison_tick_timer = poison_tick_interval
	poison_attacker = attacker
	_add_scene_feedback(global_position, Color(0.32, 0.95, 0.24), 28.0, 1.5)


func _update_poison(delta: float) -> void:
	if poison_timer <= 0.0:
		return

	poison_timer = max(poison_timer - delta, 0.0)
	poison_tick_timer -= delta
	if poison_tick_timer > 0.0:
		return

	poison_tick_timer = poison_tick_interval
	_apply_damage(poison_damage_per_tick, Vector2.ZERO, poison_attacker)
	if is_alive:
		body.color = Color(0.42, 1.0, 0.28)
		var tween := create_tween()
		tween.tween_property(body, "color", base_body_color, 0.18)


@rpc("any_peer", "call_local", "reliable")
func _receive_network_damage(amount: int, hit_direction: Vector2, attacker_peer_id: int) -> void:
	if not is_multiplayer_authority():
		return

	var attacker: Node = null
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_network_player_by_peer"):
		attacker = scene.get_network_player_by_peer(attacker_peer_id)

	_apply_damage(amount, hit_direction, attacker)


@rpc("any_peer", "call_local", "reliable")
func _receive_network_poison(damage_per_tick: int, duration: float, attacker_peer_id: int) -> void:
	if not is_multiplayer_authority():
		return

	var attacker: Node = null
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_network_player_by_peer"):
		attacker = scene.get_network_player_by_peer(attacker_peer_id)

	_apply_poison(damage_per_tick, duration, attacker)


@rpc("any_peer", "call_local", "reliable")
func _receive_network_pull(source_pos: Vector2, strength: float) -> void:
	if not is_multiplayer_authority():
		return

	var pull_direction := (source_pos - global_position).normalized()
	velocity += pull_direction * strength


func get_network_peer_id() -> int:
	return network_peer_id


func _get_attacker_peer_id(attacker: Node) -> int:
	if attacker != null and attacker.has_method("get_network_peer_id"):
		return attacker.get_network_peer_id()

	return 0


func _report_network_death(attacker: Node) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	var scene := get_tree().current_scene
	if scene != null and scene.has_method("report_network_player_death"):
		scene.report_network_player_death(network_peer_id, _get_attacker_peer_id(attacker))


func _flash_body() -> void:
	body.color = Color(1.0, 0.92, 0.36)
	var tween := create_tween()
	tween.tween_property(body, "color", base_body_color, 0.12)


func apply_pickup(pickup_type: StringName) -> bool:
	if not is_alive:
		return false

	match pickup_type:
		&"health":
			if health >= max_health:
				return false
			health = min(max_health, health + 45)
			_update_health_bar()
			_add_scene_feedback(global_position, Color(0.36, 0.95, 0.42), 36.0, 2.0)
		&"shield":
			shield_time = 12.0
			_add_scene_feedback(global_position, Color(0.48, 0.72, 1.0), 42.0, 2.5)
		&"shotgun":
			weapon_kind = WeaponKind.SHOTGUN
			weapon_ammo = 8
			weapon_time = 18.0
			_update_weapon_visual()
			_add_scene_feedback(global_position, Color(0.62, 0.42, 0.24), 34.0, 2.0)
		&"machine_gun":
			weapon_kind = WeaponKind.MACHINE_GUN
			weapon_ammo = 65
			weapon_time = 16.0
			_update_weapon_visual()
			_add_scene_feedback(global_position, Color(0.45, 0.9, 1.0), 34.0, 2.0)
		&"egg_launcher":
			weapon_kind = WeaponKind.EGG_LAUNCHER
			weapon_ammo = 5
			weapon_time = 20.0
			_update_weapon_visual()
			_add_scene_feedback(global_position, Color(0.42, 0.92, 0.36), 40.0, 2.5)
		_:
			return false

	return true


func _set_base_weapon() -> void:
	weapon_kind = WeaponKind.BLASTER
	weapon_ammo = 0
	weapon_time = 0.0
	_update_weapon_visual()


func _weapon_name() -> String:
	match weapon_kind:
		WeaponKind.SHOTGUN:
			return "Kusarigama"
		WeaponKind.MACHINE_GUN:
			return "Rapid Stars"
		WeaponKind.EGG_LAUNCHER:
			return "Poison Darts"
		_:
			return "Throwing Stars"


func get_hud_weapon_name() -> String:
	return _weapon_name()


func get_hud_weapon_icon() -> String:
	match weapon_kind:
		WeaponKind.SHOTGUN:
			return "K"
		WeaponKind.MACHINE_GUN:
			return "*"
		WeaponKind.EGG_LAUNCHER:
			return "P"
		_:
			return "*"


func get_hud_weapon_color() -> Color:
	match weapon_kind:
		WeaponKind.SHOTGUN:
			return Color(0.62, 0.42, 0.24)
		WeaponKind.MACHINE_GUN:
			return Color(0.42, 0.86, 1.0)
		WeaponKind.EGG_LAUNCHER:
			return Color(0.42, 0.92, 0.36)
		_:
			return Color(0.82, 0.86, 0.9)


func get_hud_ammo_text() -> String:
	if weapon_kind == WeaponKind.BLASTER:
		return "Infinite"

	return "%d ammo  %.0fs" % [weapon_ammo, max(weapon_time, 0.0)]


func add_camera_shake(amount: float) -> void:
	camera_shake = min(camera_shake + amount, 14.0)


func _update_camera_shake(delta: float) -> void:
	if camera_shake <= 0.01:
		camera.offset = camera_look_offset
		return

	var shake_offset := Vector2(randf_range(-camera_shake, camera_shake), randf_range(-camera_shake, camera_shake))
	camera.offset = camera_look_offset + shake_offset
	camera_shake = move_toward(camera_shake, 0.0, 28.0 * delta)


func _send_network_state(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	network_send_timer -= delta
	if network_send_timer > 0.0:
		return

	network_send_timer = 1.0 / network_state_send_rate
	_receive_network_state.rpc(
		global_position,
		velocity,
		body.scale.x,
		health,
		is_alive,
		int(weapon_kind),
		weapon_ammo,
		weapon_time,
		shield_time,
		int(hook_state),
		hook_tip,
		hook_anchor
	)


@rpc("any_peer", "call_remote", "unreliable")
func _receive_network_state(pos: Vector2, remote_velocity: Vector2, facing: float, remote_health: int, remote_alive: bool, remote_weapon: int, remote_ammo: int, remote_weapon_time: float, remote_shield_time: float, remote_hook_state: int, remote_hook_tip: Vector2, remote_hook_anchor: Vector2) -> void:
	if is_multiplayer_authority():
		return

	remote_target_position = pos
	remote_target_velocity = remote_velocity
	if not remote_has_state or global_position.distance_to(pos) > remote_snap_distance:
		global_position = pos
	remote_has_state = true
	velocity = remote_velocity
	_set_facing_direction(facing)
	health = remote_health
	is_alive = remote_alive
	weapon_kind = remote_weapon
	weapon_ammo = remote_ammo
	weapon_time = remote_weapon_time
	shield_time = remote_shield_time
	hook_state = remote_hook_state
	hook_tip = remote_hook_tip
	hook_anchor = remote_hook_anchor
	_update_health_bar()
	_update_weapon_visual()
	_set_collision_enabled(is_alive)
	visible = is_alive


func apply_network_death_visibility() -> void:
	is_alive = false
	health = 0
	hook_state = HookState.IDLE
	rope.visible = false
	hook_tip_visual.visible = false
	_update_health_bar()
	_set_collision_enabled(false)
	hide()


func _update_health_bar() -> void:
	if health_bar == null:
		return

	health_bar.scale.x = clamp(float(health) / float(max_health), 0.0, 1.0)


func _set_collision_enabled(enabled: bool) -> void:
	if collision_shape == null:
		return

	collision_shape.set_deferred("disabled", not enabled)


func _apply_cosmetics() -> void:
	var cosmetics := GameSettings.get_current_cosmetics()
	if gi_top != null:
		gi_top.color = cosmetics.get("gi_color", gi_top.color)
	if gi_lapels != null:
		gi_lapels.color = gi_top.color.darkened(0.22)
	if mask_band != null:
		mask_band.color = cosmetics.get("mask_color", mask_band.color)
	if belt != null:
		belt.color = cosmetics.get("belt_color", belt.color)
	if mustache != null:
		mustache.visible = bool(cosmetics.get("mustache_enabled", false))


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
	return [body, gi_top, gi_lapels, belt, mask_band, eye, potato_spots, potato_spot_two, mustache, weapon_visual, staff_spin, muzzle, shield_ring]


func _apply_node_facing(node: Node2D, facing: float) -> void:
	if node == null:
		return

	var home_position: Vector2 = node.get_meta("home_position", node.position)
	var home_scale: Vector2 = node.get_meta("home_scale", node.scale)
	node.position = Vector2(home_position.x * facing, home_position.y)
	node.scale = Vector2(home_scale.x * facing, home_scale.y)


func _update_weapon_visual() -> void:
	if weapon_visual == null:
		return

	match weapon_kind:
		WeaponKind.SHOTGUN:
			weapon_visual.color = Color(0.62, 0.42, 0.24)
			weapon_visual.polygon = PackedVector2Array([Vector2(-18, -4), Vector2(12, -4), Vector2(24, -12), Vector2(31, -8), Vector2(22, 0), Vector2(31, 8), Vector2(24, 12), Vector2(12, 4), Vector2(-18, 4)])
		WeaponKind.MACHINE_GUN:
			weapon_visual.color = Color(0.38, 0.43, 0.48)
			weapon_visual.polygon = PackedVector2Array([Vector2(-15, -5), Vector2(-5, -9), Vector2(18, -8), Vector2(30, -5), Vector2(43, -4), Vector2(48, -2), Vector2(48, 2), Vector2(29, 4), Vector2(15, 5), Vector2(14, 14), Vector2(8, 14), Vector2(6, 5), Vector2(-1, 5), Vector2(-4, 10), Vector2(-10, 10), Vector2(-12, 5), Vector2(-15, 6)])
		WeaponKind.EGG_LAUNCHER:
			weapon_visual.color = Color(0.42, 0.92, 0.36)
			weapon_visual.polygon = PackedVector2Array([Vector2(-14, -3), Vector2(27, -3), Vector2(34, -1), Vector2(34, 1), Vector2(27, 3), Vector2(-14, 3), Vector2(-18, 7), Vector2(-22, 5), Vector2(-18, 0), Vector2(-22, -5), Vector2(-18, -7)])
		_:
			weapon_visual.color = Color(0.82, 0.86, 0.9)
			weapon_visual.polygon = PackedVector2Array([Vector2(0, -12), Vector2(4, -4), Vector2(12, 0), Vector2(4, 4), Vector2(0, 12), Vector2(-4, 4), Vector2(-12, 0), Vector2(-4, -4)])



func _update_remote_interpolation(delta: float) -> void:
	if not remote_has_state:
		return

	var predicted_position := remote_target_position + remote_target_velocity * remote_prediction_time
	var blend := 1.0 - exp(-remote_interpolation_speed * delta)
	global_position = global_position.lerp(predicted_position, blend)
	_update_remote_visuals(delta)


func _update_remote_visuals(delta: float) -> void:
	_update_melee(delta, false)
	shield_ring.visible = shield_time > 0.0
	if shield_ring.visible:
		shield_ring.rotation += delta * 1.6

	var show_hook := hook_state != HookState.IDLE
	rope.visible = show_hook
	hook_tip_visual.visible = show_hook

	if not show_hook:
		return

	var end_point := hook_anchor if hook_state == HookState.ATTACHED or hook_state == HookState.HANGING else hook_tip
	rope.clear_points()
	rope.add_point(Vector2.ZERO)
	rope.add_point(to_local(end_point))
	hook_tip_visual.position = to_local(end_point)


func _add_scene_feedback(pos: Vector2, color: Color, radius: float, shake: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("spawn_hit_effect"):
		scene.spawn_hit_effect(pos, color, radius)
	if scene != null and scene.has_method("add_screen_shake"):
		scene.add_screen_shake(shake)


func _update_touch_controls_reference() -> void:
	if is_instance_valid(_touch_controls):
		return

	var nodes := get_tree().get_nodes_in_group("touch_controls")
	if not nodes.is_empty():
		_touch_controls = nodes[0]


func _touch_controls_active() -> bool:
	return is_instance_valid(_touch_controls) and _touch_controls.visible


func _get_move_axis() -> float:
	var keyboard_axis := Input.get_axis("move_left", "move_right")
	if _touch_controls_active():
		var touch_axis: float = _touch_controls.get_move_axis()
		if abs(touch_axis) > 0.08:
			return touch_axis

	return keyboard_axis


func _consume_touch_jump() -> bool:
	if not _touch_controls_active():
		return false

	return _touch_controls.consume_jump_pressed()


func _is_touch_fire_pressed() -> bool:
	return _touch_controls_active() and _touch_controls.is_fire_pressed()


func _is_touch_grapple_pressed() -> bool:
	return _touch_controls_active() and _touch_controls.is_grapple_pressed()


func _get_aim_direction() -> Vector2:
	if _touch_controls_active():
		var touch_aim: Vector2 = _touch_controls.get_aim_direction()
		if touch_aim.length_squared() > 0.1:
			_last_aim_direction = touch_aim.normalized()
			return _last_aim_direction

	var mouse_aim := get_global_mouse_position() - global_position
	if mouse_aim.length_squared() > 4.0:
		_last_aim_direction = mouse_aim.normalized()

	return _last_aim_direction


func _format_vec(vec: Vector2) -> String:
	return "(%0.1f, %0.1f)" % [vec.x, vec.y]


func _hook_state_name() -> String:
	match hook_state:
		HookState.FIRING:
			return "Firing"
		HookState.ATTACHED:
			return "Attached / auto-reeling"
		HookState.HANGING:
			return "Hanging"
		_:
			return "Idle"
