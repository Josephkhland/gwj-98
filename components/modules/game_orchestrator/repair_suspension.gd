class_name RepairSuspension
extends Node
## Freezes grouped subtrees during a repair, preserving audio and physical obstacles.
@export var group: StringName = &"pause_during_repairs"
var _saved: Dictionary = {}
var _active: bool = true

func _ready() -> void:
	_suspend_group()

func _process(_delta: float) -> void:
	# Also covers grouped nodes or descendants added while the repair is open.
	if _active:
		_suspend_group()

func _suspend_group() -> void:
	for node in get_tree().get_nodes_in_group(group):
		_suspend_branch(node)

func _suspend_branch(node: Node) -> void:
	var id := node.get_instance_id()
	var audio := node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D
	if not _saved.has(id):
		var state := {"node": weakref(node), "mode": node.process_mode}
		if node is CollisionObject2D:
			state["disable_mode"] = node.disable_mode
			node.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		_saved[id] = state
		# Explicit PAUSABLE lets audio keep playing beneath a disabled parent,
		# while still respecting the pause menu's full-tree pause.
		node.process_mode = Node.PROCESS_MODE_PAUSABLE if audio else Node.PROCESS_MODE_DISABLED
	if audio:
		return
	for child in node.get_children():
		_suspend_branch(child)

func release() -> void:
	_active = false
	set_process(false)
	for state: Dictionary in _saved.values():
		var node := state["node"].get_ref() as Node
		if node == null:
			continue
		node.process_mode = state["mode"]
		if node is CollisionObject2D:
			node.disable_mode = state["disable_mode"]
	_saved.clear()

func _exit_tree() -> void:
	release()
