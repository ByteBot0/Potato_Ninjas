extends Area2D

@export_enum("shotgun", "machine_gun", "egg_launcher", "health", "shield") var pickup_type := "shotgun"
@export var respawn_time := 9.0

var respawn_timer := 0.0
var is_available := true

@onready var body: Polygon2D = $Body
@onready var icon: Label = $Icon


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()


func _process(delta: float) -> void:
	rotation += delta * 0.9
	icon.rotation = -rotation

	if is_available:
		return

	respawn_timer -= delta
	if respawn_timer <= 0.0:
		is_available = true
		show()
		set_deferred("monitoring", true)
		set_deferred("monitorable", true)


func _on_body_entered(body_node: Node) -> void:
	if not is_available or not body_node.has_method("apply_pickup"):
		return

	if not body_node.apply_pickup(pickup_type):
		return

	is_available = false
	respawn_timer = respawn_time
	hide()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func _update_visuals() -> void:
	match pickup_type:
		"shotgun":
			body.color = Color(0.62, 0.42, 0.24)
			icon.text = "K"
		"machine_gun":
			body.color = Color(0.45, 0.9, 1.0)
			icon.text = "*"
		"egg_launcher":
			body.color = Color(0.42, 0.92, 0.36)
			icon.text = "P"
		"health":
			body.color = Color(0.36, 0.95, 0.42)
			icon.text = "+"
		"shield":
			body.color = Color(0.48, 0.62, 1.0)
			icon.text = "D"
