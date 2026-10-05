extends "res://singletons/item_service.gd"

const SERVICE_PATH = "/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService"


func get_rand_item_for_wave(wave: int, player_index: int):
	var service = get_node_or_null(SERVICE_PATH)
	var item = .get_rand_item_for_wave(wave, player_index)
	var attempts = 0
	while service != null and item != null and not service.call("is_item_allowed_for_player", str(item.my_id), player_index) and attempts < 128:
		item = .get_rand_item_for_wave(wave, player_index)
		attempts += 1
	if service != null and item != null and not service.call("is_item_allowed_for_player", str(item.my_id), player_index):
		return _get_allowed_fallback(service, player_index, Category.ITEM)
	return item


func _get_rand_item_for_wave(wave: int, player_index: int, category: int, rng: Reference):
	var service = get_node_or_null(SERVICE_PATH)
	var item = ._get_rand_item_for_wave(wave, player_index, category, rng)
	var attempts = 0
	while service != null and item != null and not service.call("is_item_allowed_for_player", str(item.my_id), player_index) and attempts < 128:
		item = ._get_rand_item_for_wave(wave, player_index, category, rng)
		attempts += 1
	if service != null and item != null and not service.call("is_item_allowed_for_player", str(item.my_id), player_index):
		return _get_allowed_fallback(service, player_index, category)
	return item


func _get_allowed_fallback(service: Object, player_index: int, category: int):
	for candidate in items:
		if candidate == null or candidate.get_category() != category or not bool(candidate.can_be_looted):
			continue
		if not service.call("is_item_allowed_for_player", str(candidate.my_id), player_index):
			continue
		if int(RunData.get_remaining_max_nb_item(candidate, player_index)) != 0:
			return candidate
	return null
