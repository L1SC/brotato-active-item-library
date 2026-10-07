extends "res://singletons/run_data.gd"

const SERVICE_PATH = "/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService"
const STAT_SERVICE_PATH = "/root/ModLoader/L1SC-ActiveItemLibrary/CustomStatService"


func get_player_effects(player_index: int) -> Dictionary:
	var effects = .get_player_effects(player_index)
	var stat_service = get_node_or_null(STAT_SERVICE_PATH)
	if stat_service != null:
		stat_service.seed_effects(effects)
	return effects


func add_item(item, player_index: int, arg2 = false) -> void:
	var service = get_node_or_null(SERVICE_PATH)
	var previous_item_id = service.call("get_equipped_item_id", player_index) if service != null else ""
	.add_item(item, player_index, arg2)
	if service != null and item != null:
		service.call("on_item_acquired", player_index, item, previous_item_id)


func reset() -> void:
	.reset()
	var service = get_node_or_null(SERVICE_PATH)
	if service != null:
		service.call("clear_run_state")


func get_state() -> Dictionary:
	var state = .get_state()
	var service = get_node_or_null(SERVICE_PATH)
	if service != null:
		state["active_item_library"] = service.call("export_run_state")
	return state


func resume_from_state(state: Dictionary) -> void:
	.resume_from_state(state)
	var service = get_node_or_null(SERVICE_PATH)
	if service != null:
		service.call("import_run_state", state.get("active_item_library", {}))
