class_name NetworkMessage
extends RefCounted
## Runtime state of one scheduled message during the current day. Created by MessageBoard.
enum State { UPCOMING, PENDING, DELIVERED, EXPIRED }
var definition: MessageNotification
var state: State = State.UPCOMING
var from_house: SignalNetworkHouse
var to_house: SignalNetworkHouse
var from_label: String = ""
var to_label: String = ""
## Times are game seconds since the day began (DayCycleManager.get_elapsed_game_seconds()).
## When the sender transmits; delivered right away if a route exists then.
var send_seconds: float = 0.0
## Last moment a late delivery counts: expiry or end of shift, whichever comes first.
var deadline_seconds: float = 0.0
var delivered_seconds: float = -1.0
var score: int = 0
## Pre-formatted HH:MM clock times for UI.
var send_text: String = ""
var deadline_text: String = ""
## Cheapest blocked route, including its chosen endpoints (and gateway for internet mail).
var repair_path: Array[SignalNetworkVertex] = []
## Advanced once by MessageBoard so world and minimap warnings flash together.
var warning_flash_phase: float = 0.0

func get_repair_routers() -> Array[SignalNetworkRouter]:
	var routers: Array[SignalNetworkRouter] = []
	if is_open():
		for vertex in repair_path:
			if is_instance_valid(vertex) and vertex is SignalNetworkRouter and not vertex.is_available():
				routers.append(vertex)
	return routers

func get_guidance_vertices() -> Array[SignalNetworkVertex]:
	var vertices: Array[SignalNetworkVertex] = []
	if not is_open() or repair_path.is_empty():
		return vertices
	for endpoint in [repair_path.front(), repair_path.back()]:
		if is_instance_valid(endpoint) and endpoint not in vertices:
			vertices.append(endpoint)
	for router in get_repair_routers():
		vertices.append(router)
	return vertices

func get_guidance_color() -> Color:
	return Color("ffb347") if state == State.UPCOMING else Color("ff5950")

func get_expiration_urgency(now: float) -> float:
	if state != State.PENDING:
		return 0.0
	return clampf((now - send_seconds) / maxf(0.001, deadline_seconds - send_seconds), 0.0, 1.0)

func get_warning_period(now: float) -> float:
	return lerpf(1.2, 0.18, get_expiration_urgency(now))

func get_warning_alpha() -> float:
	return 0.3 + 0.7 * (0.5 + 0.5 * sin(TAU * warning_flash_phase))

func is_open() -> bool:
	return state == State.UPCOMING or state == State.PENDING

func is_on_time() -> bool:
	return state == State.DELIVERED and delivered_seconds - send_seconds <= 0.001
