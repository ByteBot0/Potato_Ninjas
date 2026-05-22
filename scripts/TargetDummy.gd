extends Area2D

@export var max_health := 100
@export var respawn_delay := 1.25

var health := max_health
var spawn_position := Vector2.ZERO
var respawn_timer := 0.0

@onready var body: Polygon2D = $Body
@onready var health_bar: ColorRect = $HealthBar


func _ready() -> void:
	spawn_position = global_position
	_update_visuals()


func _process(delta: float) -> void:
	if respawn_timer <= 0.0:
		return

	respawn_timer -= delta
	if respawn_timer <= 0.0:
		health = max_health
		global_position = spawn_position
		show()
		monitoring = true
		monitorable = true
		_update_visuals()


func take_damage(amount: int, hit_direction: Vector2) -> void:
	if respawn_timer > 0.0:
		return

	health = max(health - amount, 0)
	global_position += hit_direction.normalized() * 4.0
	_flash()
	_update_visuals()

	if health <= 0:
		hide()
		monitoring = false
		monitorable = false
		respawn_timer = respawn_delay


func _flash() -> void:
	body.color = Color(1.0, 0.95, 0.45)
	var tween := create_tween()
	tween.tween_property(body, "color", Color(0.9, 0.28, 0.25), 0.12)


func _update_visuals() -> void:
	var health_ratio := float(health) / float(max_health)
	health_bar.scale.x = health_ratio
