extends Node2D

@export var color := Color(1.0, 0.84, 0.28)
@export var radius := 28.0
@export var lifetime := 0.22

var age := 0.0


func _ready() -> void:
	for index in range(8):
		var shard := Polygon2D.new()
		var angle: float = TAU * float(index) / 8.0
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		shard.color = color
		shard.polygon = PackedVector2Array(
			[
				direction * 5.0,
				direction.rotated(0.6) * 2.0,
				direction.rotated(-0.6) * 2.0
			]
		)
		add_child(shard)


func _process(delta: float) -> void:
	age += delta
	var progress: float = clamp(age / lifetime, 0.0, 1.0)
	scale = Vector2.ONE * lerp(0.35, radius / 8.0, progress)
	modulate.a = 1.0 - progress

	if age >= lifetime:
		queue_free()
