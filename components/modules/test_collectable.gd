extends Area2D

signal collected


func _ready() -> void:
	body_entered.connect(_on_body)


func _on_body(_body):
	collected.emit()
	queue_free()
