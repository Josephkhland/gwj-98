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

func is_open() -> bool:
	return state == State.UPCOMING or state == State.PENDING

func is_on_time() -> bool:
	return state == State.DELIVERED and delivered_seconds - send_seconds <= 0.001
