extends Node2D

@onready var network_graph : SignalNetworkGraph = $NetworkGraph


func _on_network_graph_connectivity_changed(connected_house_pairs: int, total_house_pairs: int) -> void:
	print("Connected Pairs:", connected_house_pairs)
	if network_graph != null:
		var connected = network_graph.get_broadcast_recipient_keys(&"HouseA",true)
		print(connected)
	pass # Replace with function body.
