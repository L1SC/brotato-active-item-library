extends Node

signal active_item_activated(player_index, item_id, visual)
signal state_changed(player_index, state)
signal activation_rejected(player_index, reason)
signal active_item_changed(player_index, item_id)

const MOD_ID = "L1SC-ActiveItemLibrary"
const ACTION_NAME = "l1sc_active_item_activate"
const ROUTE_REQUEST = "activation_request"
const ROUTE_COMMITTED = "activation_committed"
const ROUTE_REJECTED = "activation_rejected"
const ROUTE_CHOICE_REQUEST = "choice_request"
const ROUTE_CHOICE_COMMITTED = "choice_committed"
const ROUTE_CHOICE_REJECTED = "choice_rejected"
const ONLINE_API_PATH = "/root/ModLoader/six666-BrotatoOnline/BrotatoOnlineAPI"
const BINDINGS_PATH = "user://l1sc_active_item_library_bindings.cfg"
const BINDINGS_VERSION = 1
const DEFAULT_KEY = KEY_SPACE
const DEFAULT_JOYPAD_BUTTON = 5 # Godot 3 right shoulder / RB.
const CHOICE_QUEUE_TTL_MSEC = 15000
const HUD_ICON_SIZE = 28

var _active_items = {}
var _character_active_pools = {}
var _equipped_item_id_by_player = {}
var _pending_choices_by_player = {}
var _purchase_context_by_player = {}
var _queued_choice_requests_by_player = {}
var _queued_choice_commits_by_player = {}
var _choice_request_serial = 0
var _choice_commit_serial = 0
var _last_choice_commit_by_player = {}
var _next_ready_msec = {}
var _pending_request_by_player = {}
var _request_serial = 0
var _activation_serial = 0
var _last_activation_by_player = {}
var _battle_scene_id = 0
var _battle_clock_msec = 0.0
var _online_api = null
var _key_scancode = DEFAULT_KEY
var _joypad_button = DEFAULT_JOYPAD_BUTTON
var _hud_layer = null
var _hud_slots = {}
var _hud_refresh_msec = 0
var _choice_popup = null
var _choice_message = null
var _keep_old_button = null
var _keep_new_button = null
var _popup_player_index = -1


func _ready() -> void:
	_load_bindings()
	_apply_bindings()
	_try_connect_online_api()
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "ActiveItemHUD"
	_hud_layer.layer = 50
	add_child(_hud_layer)
	_create_choice_popup()
	set_process(true)
	set_process_input(true)


func register_active_item(item_id: String, handler: Object, options: Dictionary = {}) -> bool:
	if item_id == "" or handler == null or not is_instance_valid(handler) or not handler.has_method("activate_active_item"):
		return false
	if _active_items.has(item_id):
		return false
	var item = _get_item_resource(item_id)
	if item != null and not _valid_active_item_resource(item):
		return false
	var cooldown_seconds = float(options.get("cooldown_seconds", -1.0))
	if cooldown_seconds < 0.0:
		return false
	_active_items[item_id] = {
		"handler": handler,
		"cooldown_msec": int(round(cooldown_seconds * 1000.0)),
		"display_name": str(options.get("display_name", ""))
	}
	return true


func _valid_active_item_resource(item) -> bool:
	return item != null and item.get_category() == Category.ITEM and int(item.max_nb) == 1


func _get_item_resource(item_id: String):
	if item_id == "":
		return null
	for item in ItemService.items:
		if item != null and str(item.my_id) == item_id:
			return item
	return null


func unregister_active_item(item_id: String, handler: Object) -> bool:
	if not _active_items.has(item_id) or _active_items[item_id]["handler"] != handler:
		return false
	_active_items.erase(item_id)
	return true


func set_character_active_pool(character_id: String, allowed_item_ids: Array) -> bool:
	if character_id == "":
		return false
	var allowed = []
	for item_id in allowed_item_ids:
		if typeof(item_id) != TYPE_STRING or item_id == "" or allowed.has(item_id):
			return false
		allowed.append(item_id)
	_character_active_pools[character_id] = allowed
	return true


func clear_character_active_pool(character_id: String) -> void:
	_character_active_pools.erase(character_id)


func clear_run_state() -> void:
	_equipped_item_id_by_player.clear()
	_pending_choices_by_player.clear()
	_purchase_context_by_player.clear()
	_queued_choice_requests_by_player.clear()
	_queued_choice_commits_by_player.clear()
	_last_choice_commit_by_player.clear()
	_next_ready_msec.clear()
	_pending_request_by_player.clear()
	_last_activation_by_player.clear()
	if _choice_popup != null:
		_choice_popup.hide()
	_popup_player_index = -1
	_clear_hud()


func export_run_state() -> Dictionary:
	var pending = {}
	for player_index in _pending_choices_by_player.keys():
		var choice = _pending_choices_by_player[player_index]
		pending[str(player_index)] = {
			"old_item_id": str(choice["old_item_id"]),
			"new_item_id": str(choice["new_item_id"]),
			"price": int(choice["price"])
		}
	return {"equipped": _equipped_item_id_by_player.duplicate(), "pending": pending}


func import_run_state(saved: Dictionary) -> void:
	clear_run_state()
	for key in saved.get("equipped", {}).keys():
		_equipped_item_id_by_player[int(key)] = str(saved["equipped"][key])
	for key in saved.get("pending", {}).keys():
		var player_index = int(key)
		var choice = saved["pending"][key]
		var old_id = str(choice.get("old_item_id", ""))
		var new_id = str(choice.get("new_item_id", ""))
		if _find_owned_item(player_index, old_id) != null and _find_owned_item(player_index, new_id) != null:
			_pending_choices_by_player[player_index] = {
				"old_item_id": old_id,
				"new_item_id": new_id,
				"price": max(0, int(choice.get("price", 0))),
				"submitted": false,
				"created_msec": OS.get_ticks_msec()
			}
	call_deferred("_maybe_show_choice")


func is_item_allowed_for_player(item_id: String, player_index: int) -> bool:
	if not _active_items.has(item_id):
		return true
	var character_id = _get_character_id(player_index)
	return not _character_active_pools.has(character_id) or _character_active_pools[character_id].has(item_id)


func get_equipped_item_id(player_index: int) -> String:
	var owned = _get_owned_active_items(player_index)
	var preferred = str(_equipped_item_id_by_player.get(player_index, ""))
	for item in owned:
		if str(item.my_id) == preferred:
			return preferred
	return str(owned[0].my_id) if not owned.empty() else ""


func begin_purchase(player_index: int, item, price: int) -> void:
	if item != null and _active_items.has(str(item.my_id)):
		var available_gold = int(RunData.players_data[player_index].gold)
		_purchase_context_by_player[player_index] = {"item_id": str(item.my_id), "price": min(max(0, price), max(0, available_gold))}


func end_purchase(player_index: int) -> void:
	_purchase_context_by_player.erase(player_index)


func on_item_acquired(player_index: int, item, previous_item_id: String) -> void:
	var new_item_id = str(item.my_id)
	if not _active_items.has(new_item_id):
		return
	if previous_item_id == "":
		_equipped_item_id_by_player[player_index] = new_item_id
		_next_ready_msec.erase(player_index)
		emit_signal("active_item_changed", player_index, new_item_id)
		emit_signal("state_changed", player_index, get_state(player_index))
		return
	if previous_item_id == new_item_id or _pending_choices_by_player.has(player_index):
		return
	var context = _purchase_context_by_player.get(player_index, {})
	var price = int(context.get("price", 0)) if str(context.get("item_id", "")) == new_item_id else 0
	_equipped_item_id_by_player[player_index] = previous_item_id
	_begin_choice(player_index, previous_item_id, new_item_id, price)


func _begin_choice(player_index: int, old_item_id: String, new_item_id: String, price: int) -> void:
	_pending_choices_by_player[player_index] = {
		"old_item_id": old_item_id,
		"new_item_id": new_item_id,
		"price": max(0, price),
		"submitted": false,
		"created_msec": OS.get_ticks_msec()
	}
	emit_signal("state_changed", player_index, get_state(player_index))
	if _queued_choice_requests_by_player.has(player_index):
		var queued = _queued_choice_requests_by_player[player_index]
		_queued_choice_requests_by_player.erase(player_index)
		if OS.get_ticks_msec() - int(queued["received_msec"]) < CHOICE_QUEUE_TTL_MSEC:
			_try_commit_choice(player_index, queued["payload"])
	if _queued_choice_commits_by_player.has(player_index):
		var committed = _queued_choice_commits_by_player[player_index]
		_queued_choice_commits_by_player.erase(player_index)
		if OS.get_ticks_msec() - int(committed["received_msec"]) < CHOICE_QUEUE_TTL_MSEC:
			_on_choice_committed(committed["payload"])
	call_deferred("_maybe_show_choice")


func _refresh_active_slots() -> void:
	if typeof(RunData) == TYPE_NIL:
		return
	for player_index in range(int(RunData.get_player_count())):
		var owned = _get_owned_active_items(player_index)
		if _pending_choices_by_player.has(player_index):
			var pending = _pending_choices_by_player[player_index]
			if _find_owned_item(player_index, str(pending["old_item_id"])) == null or _find_owned_item(player_index, str(pending["new_item_id"])) == null:
				_pending_choices_by_player.erase(player_index)
				if _popup_player_index == player_index:
					_choice_popup.hide()
					_popup_player_index = -1
		var equipped = get_equipped_item_id(player_index)
		if equipped != str(_equipped_item_id_by_player.get(player_index, "")):
			_equipped_item_id_by_player[player_index] = equipped
			_next_ready_msec.erase(player_index)
			emit_signal("active_item_changed", player_index, equipped)
		if owned.size() > 1 and not _pending_choices_by_player.has(player_index):
			var next_id = ""
			for item in owned:
				if str(item.my_id) != equipped:
					next_id = str(item.my_id)
					break
			if next_id != "":
				_begin_choice(player_index, equipped, next_id, 0)
			else:
				RunData.remove_item(owned.back(), player_index)


func _find_owned_item(player_index: int, item_id: String):
	for item in _get_owned_active_items(player_index):
		if str(item.my_id) == item_id:
			return item
	return null


func get_state(player_index: int) -> Dictionary:
	var item_id = get_equipped_item_id(player_index)
	var active_item = _active_items.get(item_id, {})
	var item_resource = _find_owned_item(player_index, item_id)
	var display_name = str(active_item.get("display_name", ""))
	if display_name == "":
		display_name = tr(str(item_resource.name)) if item_resource != null else item_id
	var remaining_msec = max(0, int(_next_ready_msec.get(player_index, 0) - _battle_clock_msec))
	var battle_active = _is_battle_active()
	var available = not active_item.empty() and _handler_is_valid(active_item)
	var pending = _pending_request_by_player.has(player_index) or _pending_choices_by_player.has(player_index)
	var alive = _player_is_alive(player_index)
	return {
		"player_index": player_index,
		"item_id": item_id,
		"display_name": display_name,
		"battle_active": battle_active,
		"alive": alive,
		"available": available,
		"ready": battle_active and alive and available and remaining_msec == 0 and not pending,
		"pending": pending,
		"cooldown_remaining": float(remaining_msec) / 1000.0
	}


func choose_active_item(player_index: int, keep_new: bool) -> bool:
	if not _owns_player(player_index) or not _pending_choices_by_player.has(player_index):
		return false
	var pending = _pending_choices_by_player[player_index]
	if bool(pending["submitted"]):
		return false
	_choice_request_serial += 1
	var request = {
		"player_index": player_index,
		"old_item_id": str(pending["old_item_id"]),
		"new_item_id": str(pending["new_item_id"]),
		"keep_new": keep_new,
		"request_id": _choice_request_serial
	}
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")) and bool(api.call("is_client")):
		var sent = bool(api.call("send_to_host", MOD_ID, ROUTE_CHOICE_REQUEST, request, {"scope": _choice_message_scope(), "reliable": true}))
		if sent:
			pending["submitted"] = true
			pending["request_id"] = _choice_request_serial
			_pending_choices_by_player[player_index] = pending
			_update_choice_popup()
		return sent
	return _try_commit_choice(player_index, request)


func _try_commit_choice(player_index: int, request: Dictionary) -> bool:
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")) and not bool(api.call("is_host")):
		return false
	if not _pending_choices_by_player.has(player_index):
		return false
	var pending = _pending_choices_by_player[player_index]
	if str(request.get("old_item_id", "")) != str(pending["old_item_id"]) or str(request.get("new_item_id", "")) != str(pending["new_item_id"]):
		_send_choice_rejection(player_index, int(request.get("request_id", 0)), "item_mismatch")
		return false
	if _find_owned_item(player_index, str(pending["old_item_id"])) == null or _find_owned_item(player_index, str(pending["new_item_id"])) == null:
		_send_choice_rejection(player_index, int(request.get("request_id", 0)), "item_missing")
		return false
	_choice_commit_serial += 1
	var committed = {
		"player_index": player_index,
		"old_item_id": str(pending["old_item_id"]),
		"new_item_id": str(pending["new_item_id"]),
		"keep_new": bool(request.get("keep_new", false)),
		"refund": int(pending["price"]) if not bool(request.get("keep_new", false)) else 0,
		"commit_id": _choice_commit_serial
	}
	if api != null and bool(api.call("is_online")):
		return bool(api.call("broadcast", MOD_ID, ROUTE_CHOICE_COMMITTED, committed, {"scope": _choice_message_scope(), "reliable": true}))
	_on_choice_committed(committed)
	return true


func _on_choice_committed(payload: Dictionary) -> void:
	var player_index = int(payload.get("player_index", -1))
	if player_index < 0:
		return
	var commit_id = int(payload.get("commit_id", 0))
	if commit_id <= int(_last_choice_commit_by_player.get(player_index, 0)):
		return
	var keep_new = bool(payload.get("keep_new", false))
	var keep_id = str(payload.get("new_item_id", "")) if keep_new else str(payload.get("old_item_id", ""))
	var discard_id = str(payload.get("old_item_id", "")) if keep_new else str(payload.get("new_item_id", ""))
	var discarded = _find_owned_item(player_index, discard_id)
	if discarded == null or _find_owned_item(player_index, keep_id) == null:
		_queued_choice_commits_by_player[player_index] = {"payload": payload, "received_msec": OS.get_ticks_msec()}
		return
	RunData.remove_item(discarded, player_index)
	if not keep_new and int(payload.get("refund", 0)) > 0:
		RunData.add_gold(int(payload["refund"]), player_index)
	_last_choice_commit_by_player[player_index] = commit_id
	_equipped_item_id_by_player[player_index] = keep_id
	_next_ready_msec.erase(player_index)
	_pending_choices_by_player.erase(player_index)
	if _popup_player_index == player_index:
		_choice_popup.hide()
		_popup_player_index = -1
	emit_signal("active_item_changed", player_index, keep_id)
	emit_signal("state_changed", player_index, get_state(player_index))
	_refresh_active_slots()
	call_deferred("_maybe_show_choice")


func _send_choice_rejection(player_index: int, request_id: int, reason: String) -> void:
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")) and request_id > 0:
		api.call("send_to_player", player_index, MOD_ID, ROUTE_CHOICE_REJECTED, {
			"player_index": player_index,
			"request_id": request_id,
			"reason": reason
		}, {"scope": _choice_message_scope(), "reliable": true})


func _choice_message_scope() -> String:
	var api = _get_online_api()
	return "battle" if api != null and bool(api.call("is_online")) and str(api.call("get_phase")) == "battle" else "menu"


func _expire_choice_queues() -> void:
	var now = OS.get_ticks_msec()
	for player_index in _queued_choice_requests_by_player.keys():
		var queued = _queued_choice_requests_by_player[player_index]
		if now - int(queued["received_msec"]) >= CHOICE_QUEUE_TTL_MSEC:
			_send_choice_rejection(int(player_index), int(queued["payload"].get("request_id", 0)), "purchase_not_confirmed")
			_queued_choice_requests_by_player.erase(player_index)
	for player_index in _queued_choice_commits_by_player.keys():
		if now - int(_queued_choice_commits_by_player[player_index]["received_msec"]) >= CHOICE_QUEUE_TTL_MSEC:
			_queued_choice_commits_by_player.erase(player_index)


func _on_choice_rejected(payload: Dictionary) -> void:
	var player_index = int(payload.get("player_index", -1))
	if not _pending_choices_by_player.has(player_index):
		return
	var pending = _pending_choices_by_player[player_index]
	if int(pending.get("request_id", -1)) != int(payload.get("request_id", -2)):
		return
	pending["submitted"] = false
	_pending_choices_by_player[player_index] = pending
	_update_choice_popup()


func request_activation(player_index: int, request_data: Dictionary = {}) -> bool:
	_sync_battle_scene()
	var state = get_state(player_index)
	if not bool(state["ready"]) or not _owns_player(player_index):
		return false
	var active_item = _active_items.get(str(state["item_id"]), {})
	var handler = active_item.get("handler", null)
	if request_data.empty() and handler != null and handler.has_method("get_active_item_request_data"):
		var captured = handler.call("get_active_item_request_data", player_index, str(state["item_id"]))
		if typeof(captured) != TYPE_DICTIONARY:
			return false
		request_data = captured
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")) and bool(api.call("is_client")):
		_request_serial += 1
		var request_id = _request_serial
		var sent = bool(api.call("send_to_host", MOD_ID, ROUTE_REQUEST, {
			"player_index": player_index,
			"item_id": str(state["item_id"]),
			"request_id": request_id,
			"request_data": request_data
		}, {"scope": "battle", "reliable": true}))
		if sent:
			_pending_request_by_player[player_index] = request_id
			emit_signal("state_changed", player_index, get_state(player_index))
		return sent
	return _activate_authoritative(player_index, str(state["item_id"]), request_data, 0)


func get_bindings() -> Dictionary:
	return {"keyboard_scancode": _key_scancode, "joypad_button": _joypad_button}


func set_bindings(keyboard_scancode: int, joypad_button: int) -> bool:
	if keyboard_scancode <= 0 or joypad_button < 0:
		return false
	_key_scancode = keyboard_scancode
	_joypad_button = joypad_button
	_apply_bindings()
	var config = ConfigFile.new()
	config.set_value("input", "keyboard_scancode", _key_scancode)
	config.set_value("input", "joypad_button", _joypad_button)
	config.set_value("input", "version", BINDINGS_VERSION)
	return config.save(BINDINGS_PATH) == OK


func _input(event: InputEvent) -> void:
	if not _is_battle_active() or not event.is_action_pressed(ACTION_NAME):
		return
	if event is InputEventKey and event.echo:
		return
	var player_index = _player_index_for_event(event)
	if player_index >= 0:
		request_activation(player_index)


func _process(delta: float) -> void:
	if not _bindings_intact():
		_apply_bindings()
	_try_connect_online_api()
	_sync_battle_scene()
	if _is_battle_active():
		_battle_clock_msec += delta * 1000.0
	if OS.get_ticks_msec() >= _hud_refresh_msec:
		_hud_refresh_msec = OS.get_ticks_msec() + 100
		_expire_choice_queues()
		_refresh_active_slots()
		_maybe_show_choice()
		_update_hud()


func _sync_battle_scene() -> void:
	var scene = get_tree().current_scene
	var scene_id = scene.get_instance_id() if _is_game_scene() and scene != null else 0
	if scene_id != _battle_scene_id:
		_battle_scene_id = scene_id
		_battle_clock_msec = 0.0
		_next_ready_msec.clear()
		_pending_request_by_player.clear()
		_last_activation_by_player.clear()
		_clear_hud()


func _activate_authoritative(player_index: int, item_id: String, request_data: Dictionary, request_id: int) -> bool:
	_sync_battle_scene()
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")) and not bool(api.call("should_run_authoritative_logic")):
		return false
	var state = get_state(player_index)
	if not bool(state["ready"]) or str(state["item_id"]) != item_id:
		_send_rejection(player_index, request_id, "not_ready")
		return false
	var active_item = _active_items.get(item_id, {})
	var handler = active_item["handler"]
	var result = handler.call("activate_active_item", player_index, item_id, request_data)
	if typeof(result) != TYPE_DICTIONARY or not bool(result.get("ok", false)):
		_send_rejection(player_index, request_id, "handler_rejected")
		return false
	var visual = result.get("visual", {})
	if typeof(visual) != TYPE_DICTIONARY:
		visual = {}
	_activation_serial += 1
	var committed = {
		"player_index": player_index,
		"item_id": item_id,
		"activation_id": _activation_serial,
		"cooldown_msec": int(active_item["cooldown_msec"]),
		"request_id": request_id,
		"visual": visual
	}
	# OnlineAPI.broadcast delivers to Host-local listeners before remote peers.
	# Use that one callback for cooldown and visuals on every peer.
	if api != null and bool(api.call("is_online")):
		return bool(api.call("broadcast", MOD_ID, ROUTE_COMMITTED, committed, {"scope": "battle", "reliable": true}))
	_on_committed(committed)
	return true


func _on_mod_message_received(mod_id: String, route: String, payload: Dictionary, meta: Dictionary) -> void:
	if mod_id != MOD_ID:
		return
	var api = _get_online_api()
	if route == ROUTE_CHOICE_REQUEST:
		if api == null or not bool(api.call("is_host")) or str(meta.get("from_role", "")) != "client":
			return
		var choice_player = int(payload.get("player_index", -1))
		if choice_player < 0 or choice_player != int(meta.get("from_player_index", -2)):
			return
		if _pending_choices_by_player.has(choice_player):
			_try_commit_choice(choice_player, payload)
		else:
			_queued_choice_requests_by_player[choice_player] = {"payload": payload, "received_msec": OS.get_ticks_msec()}
		return
	if route == ROUTE_CHOICE_COMMITTED:
		if api != null and bool(api.call("is_online")) and str(meta.get("from_role", "")) != "host":
			return
		_on_choice_committed(payload)
		return
	if route == ROUTE_CHOICE_REJECTED:
		if api != null and bool(api.call("is_online")) and str(meta.get("from_role", "")) != "host":
			return
		_on_choice_rejected(payload)
		return
	if not _is_battle_active():
		return
	if route == ROUTE_REQUEST:
		if api == null or not bool(api.call("is_host")) or str(meta.get("from_role", "")) != "client":
			return
		var player_index = int(payload.get("player_index", -1))
		if player_index < 0 or player_index != int(meta.get("from_player_index", -2)):
			return
		var request_data = payload.get("request_data", {})
		if typeof(request_data) != TYPE_DICTIONARY:
			return
		_activate_authoritative(player_index, str(payload.get("item_id", "")), request_data, int(payload.get("request_id", 0)))
	elif route == ROUTE_COMMITTED:
		if api != null and bool(api.call("is_online")) and str(meta.get("from_role", "")) != "host":
			return
		_on_committed(payload)
	elif route == ROUTE_REJECTED:
		if api != null and bool(api.call("is_online")) and str(meta.get("from_role", "")) != "host":
			return
		_on_rejected(payload)


func _on_committed(payload: Dictionary) -> void:
	_sync_battle_scene()
	var player_index = int(payload.get("player_index", -1))
	if player_index < 0 or get_equipped_item_id(player_index) != str(payload.get("item_id", "")):
		return
	var activation_id = int(payload.get("activation_id", 0))
	if activation_id <= int(_last_activation_by_player.get(player_index, 0)):
		return
	var active_item = _active_items.get(str(payload["item_id"]), {})
	if active_item.empty() or not _handler_is_valid(active_item):
		return
	_last_activation_by_player[player_index] = activation_id
	_next_ready_msec[player_index] = _battle_clock_msec + max(0, int(payload.get("cooldown_msec", 0)))
	_pending_request_by_player.erase(player_index)
	var visual = payload.get("visual", {})
	if typeof(visual) != TYPE_DICTIONARY:
		visual = {}
	var handler = active_item["handler"]
	if handler.has_method("show_active_item_visual"):
		handler.call("show_active_item_visual", player_index, str(payload["item_id"]), visual)
	emit_signal("active_item_activated", player_index, str(payload["item_id"]), visual)
	emit_signal("state_changed", player_index, get_state(player_index))


func _on_rejected(payload: Dictionary) -> void:
	var player_index = int(payload.get("player_index", -1))
	if player_index < 0:
		return
	if _pending_request_by_player.get(player_index, -1) != int(payload.get("request_id", -2)):
		return
	_pending_request_by_player.erase(player_index)
	_next_ready_msec[player_index] = _battle_clock_msec + max(0, int(payload.get("cooldown_remaining_msec", 0)))
	emit_signal("activation_rejected", player_index, str(payload.get("reason", "rejected")))
	emit_signal("state_changed", player_index, get_state(player_index))


func _send_rejection(player_index: int, request_id: int, reason: String) -> void:
	var api = _get_online_api()
	if api == null or not bool(api.call("is_online")) or request_id <= 0:
		return
	api.call("send_to_player", player_index, MOD_ID, ROUTE_REJECTED, {
		"player_index": player_index,
		"request_id": request_id,
		"reason": reason,
		"cooldown_remaining_msec": max(0, int(_next_ready_msec.get(player_index, 0) - _battle_clock_msec))
	}, {"scope": "battle", "reliable": true})


func _get_character_id(player_index: int) -> String:
	if player_index < 0 or typeof(RunData) == TYPE_NIL or player_index >= int(RunData.get_player_count()):
		return ""
	var character = RunData.get_player_character(player_index)
	return str(character.my_id) if character != null else ""


func _get_owned_active_items(player_index: int) -> Array:
	if player_index < 0 or typeof(RunData) == TYPE_NIL or player_index >= int(RunData.get_player_count()):
		return []
	var owned = []
	for item in RunData.get_player_items(player_index):
		if item != null and _active_items.has(str(item.my_id)) and _valid_active_item_resource(item):
			owned.append(item)
	return owned


func _player_is_alive(player_index: int) -> bool:
	if player_index < 0 or typeof(RunData) == TYPE_NIL or player_index >= int(RunData.get_player_count()):
		return false
	return float(RunData.get_player_current_health(player_index)) > 0.0


func _handler_is_valid(skill: Dictionary) -> bool:
	var handler = skill.get("handler", null)
	return handler != null and is_instance_valid(handler) and handler.has_method("activate_active_item")


func _is_battle_active() -> bool:
	if get_tree() == null or get_tree().paused or not _is_game_scene():
		return false
	var api = _get_online_api()
	return api == null or not bool(api.call("is_online")) or str(api.call("get_phase")) == "battle"


func _is_game_scene() -> bool:
	return get_tree() != null and get_tree().current_scene != null and typeof(MenuData) != TYPE_NIL and str(get_tree().current_scene.filename) == str(MenuData.get("game_scene"))


func _owns_player(player_index: int) -> bool:
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")):
		return bool(api.call("owns_player", player_index))
	return _get_local_player_indices().has(player_index)


func _get_local_player_indices() -> Array:
	var api = _get_online_api()
	if api != null and bool(api.call("is_online")):
		return api.call("get_local_player_indices")
	var indices = []
	for index in range(CoopService.connected_players.size()):
		indices.append(index)
	if indices.empty() and int(RunData.get_player_count()) > 0:
		indices.append(0)
	return indices


func _player_index_for_event(event: InputEvent) -> int:
	var local_indices = _get_local_player_indices()
	if local_indices.empty():
		return -1
	var device = -999
	if event is InputEventKey:
		device = CoopService.KEYBOARD_REMAPPED_DEVICE_ID
	elif event is InputEventJoypadButton:
		device = CoopService.GAMEPAD_REMAPPED_DEVICE_ID if event.device == 0 else event.device
	else:
		return -1
	for player_index in local_indices:
		if player_index < CoopService.connected_players.size():
			var entry = CoopService.connected_players[player_index]
			if typeof(entry) == TYPE_ARRAY and entry.size() > 0 and int(entry[0]) == device:
				return int(player_index)
	# A single local player may switch input devices during a run.
	return int(local_indices[0]) if local_indices.size() == 1 else -1


func _get_online_api():
	if _online_api != null and is_instance_valid(_online_api):
		return _online_api
	_online_api = get_node_or_null(ONLINE_API_PATH)
	return _online_api


func _try_connect_online_api() -> void:
	var api = _get_online_api()
	if api != null and not api.is_connected("mod_message_received", self, "_on_mod_message_received"):
		api.connect("mod_message_received", self, "_on_mod_message_received")


func _load_bindings() -> void:
	var config = ConfigFile.new()
	if config.load(BINDINGS_PATH) == OK:
		# Version 2 at this path belongs to older valotato releases.
		if int(config.get_value("input", "version", 0)) >= 2:
			return
		_key_scancode = max(1, int(config.get_value("input", "keyboard_scancode", DEFAULT_KEY)))
		_joypad_button = max(0, int(config.get_value("input", "joypad_button", DEFAULT_JOYPAD_BUTTON)))
		if int(config.get_value("input", "version", 0)) < BINDINGS_VERSION:
			if _key_scancode == KEY_Q:
				_key_scancode = DEFAULT_KEY
			config.set_value("input", "keyboard_scancode", _key_scancode)
			config.set_value("input", "version", BINDINGS_VERSION)
			config.save(BINDINGS_PATH)
	else:
		config.set_value("input", "keyboard_scancode", DEFAULT_KEY)
		config.set_value("input", "joypad_button", DEFAULT_JOYPAD_BUTTON)
		config.set_value("input", "version", BINDINGS_VERSION)
		config.save(BINDINGS_PATH)


func _apply_bindings() -> void:
	if not InputMap.has_action(ACTION_NAME):
		InputMap.add_action(ACTION_NAME)
	InputMap.action_erase_events(ACTION_NAME)
	var key = InputEventKey.new()
	key.scancode = _key_scancode
	InputMap.action_add_event(ACTION_NAME, key)
	var joypad = InputEventJoypadButton.new()
	joypad.button_index = _joypad_button
	InputMap.action_add_event(ACTION_NAME, joypad)


func _bindings_intact() -> bool:
	if not InputMap.has_action(ACTION_NAME):
		return false
	var has_key = false
	var has_joypad = false
	for event in InputMap.get_action_list(ACTION_NAME):
		if event is InputEventKey and event.scancode == _key_scancode:
			has_key = true
		elif event is InputEventJoypadButton and event.button_index == _joypad_button:
			has_joypad = true
	return has_key and has_joypad


func _update_hud() -> void:
	if not _is_battle_active():
		_clear_hud()
		return
	var visible_indices = []
	for player_index in _get_local_player_indices():
		var index = int(player_index)
		visible_indices.append(index)
		var state = get_state(index)
		var item = _find_owned_item(index, str(state["item_id"]))
		var health_bar = get_tree().current_scene.get_node_or_null("UI/HUD/LifeContainerP%d/UILifeBarP%d" % [index + 1, index + 1])
		var slot = _hud_slots.get(index, {})
		if item == null or health_bar == null or not health_bar.is_visible_in_tree():
			if not slot.empty():
				slot["panel"].hide()
			continue
		if slot.empty():
			slot = _create_hud_slot(index)
			_hud_slots[index] = slot
		var bar_rect = health_bar.get_global_rect()
		var x = bar_rect.end.x if bar_rect.position.x < get_viewport().size.x / 2.0 else bar_rect.position.x - HUD_ICON_SIZE
		slot["panel"].rect_position = Vector2(x, bar_rect.position.y + (bar_rect.size.y - HUD_ICON_SIZE) / 2.0)
		slot["panel"].show()
		slot["icon"].texture = item.icon
		slot["icon"].modulate = Color(1, 1, 1) if bool(state["ready"]) else Color(0.35, 0.35, 0.35)
	for player_index in _hud_slots.keys():
		if not visible_indices.has(player_index):
			_hud_slots[player_index]["panel"].queue_free()
			_hud_slots.erase(player_index)


func _create_hud_slot(player_index: int) -> Dictionary:
	var panel = Panel.new()
	panel.name = "Player%dActiveItemSlot" % (player_index + 1)
	panel.rect_size = Vector2(HUD_ICON_SIZE, HUD_ICON_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(panel)
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	background.border_color = Color(0.85, 0.85, 0.85)
	background.set_border_width_all(1)
	panel.add_stylebox_override("panel", background)
	var icon = TextureRect.new()
	icon.rect_position = Vector2(2, 2)
	icon.rect_size = Vector2(HUD_ICON_SIZE - 4, HUD_ICON_SIZE - 4)
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return {"panel": panel, "icon": icon}


func _clear_hud() -> void:
	for slot in _hud_slots.values():
		slot["panel"].queue_free()
	_hud_slots.clear()


func _create_choice_popup() -> void:
	_choice_popup = PopupPanel.new()
	_choice_popup.name = "ActiveItemChoice"
	_choice_popup.pause_mode = Node.PAUSE_MODE_PROCESS
	_choice_popup.rect_scale = Vector2(1.7, 1.7)
	_hud_layer.add_child(_choice_popup)
	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_constant_override("margin_" + side, 18)
	_choice_popup.add_child(margin)
	var column = VBoxContainer.new()
	column.add_constant_override("separation", 12)
	margin.add_child(column)
	_choice_message = Label.new()
	_choice_message.autowrap = true
	_choice_message.rect_min_size = Vector2(460, 60)
	column.add_child(_choice_message)
	_keep_old_button = Button.new()
	_keep_old_button.focus_mode = Control.FOCUS_ALL
	_keep_old_button.connect("pressed", self, "_choice_button_pressed", [false])
	column.add_child(_keep_old_button)
	_keep_new_button = Button.new()
	_keep_new_button.focus_mode = Control.FOCUS_ALL
	_keep_new_button.connect("pressed", self, "_choice_button_pressed", [true])
	column.add_child(_keep_new_button)
	_choice_popup.connect("about_to_show", self, "_center_choice_popup")


func _center_choice_popup() -> void:
	var viewport_size = get_viewport().size
	_choice_popup.rect_position = (viewport_size - _choice_popup.rect_size * _choice_popup.rect_scale) / 2.0


func _maybe_show_choice() -> void:
	if _choice_popup == null or get_tree().current_scene == null:
		return
	if _popup_player_index >= 0 and _pending_choices_by_player.has(_popup_player_index):
		if not _choice_popup.visible:
			_choice_popup.popup_centered(Vector2(520, 200))
		_update_choice_popup()
		return
	for player_index in _get_local_player_indices():
		if _pending_choices_by_player.has(player_index):
			_popup_player_index = int(player_index)
			_update_choice_popup()
			_choice_popup.popup_centered(Vector2(520, 200))
			_keep_old_button.grab_focus()
			return


func _update_choice_popup() -> void:
	if _popup_player_index < 0 or not _pending_choices_by_player.has(_popup_player_index):
		return
	var pending = _pending_choices_by_player[_popup_player_index]
	var old_item = _find_owned_item(_popup_player_index, str(pending["old_item_id"]))
	var new_item = _find_owned_item(_popup_player_index, str(pending["new_item_id"]))
	var old_name = tr(str(old_item.name)) if old_item != null else str(pending["old_item_id"])
	var new_name = tr(str(new_item.name)) if new_item != null else str(pending["new_item_id"])
	_choice_message.text = "Active item slot is full. Choose one item to keep."
	_keep_old_button.text = "Keep current: " + old_name
	_keep_old_button.icon = old_item.icon if old_item != null else null
	if int(pending["price"]) > 0:
		_keep_old_button.text += " (refund %d)" % int(pending["price"])
	_keep_new_button.text = "Equip new: " + new_name
	_keep_new_button.icon = new_item.icon if new_item != null else null
	var waiting = bool(pending["submitted"])
	_keep_old_button.disabled = waiting
	_keep_new_button.disabled = waiting
	if waiting:
		_choice_message.text = "Waiting for host to confirm the active item choice..."


func _choice_button_pressed(keep_new: bool) -> void:
	if _popup_player_index >= 0:
		choose_active_item(_popup_player_index, keep_new)
