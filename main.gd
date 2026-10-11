extends Node

var sandbox_scene: PackedScene = preload("res://levels/sandbox/sandbox.tscn") 
var level_1: PackedScene = preload("res://levels/level_1/level_1.tscn")

# Just the Entry point of the game.
func _ready():
	call_deferred("change_scene")
	


func change_scene():
	get_tree().change_scene_to_packed(level_1)
