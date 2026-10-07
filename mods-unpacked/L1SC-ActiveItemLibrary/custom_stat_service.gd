extends Node

const EFFECT_SCRIPT = preload("res://items/global/effect.gd")

var _stats = {}


func register_stat(key: String, text_key: String, default_value: int = 0) -> bool:
	if key.empty() or text_key.empty() or _stats.has(key):
		return false
	var key_hash = Keys.generate_hash(key)
	for stat in _stats.values():
		if stat.hash == key_hash:
			return false
	_stats[key] = {"hash": key_hash, "text_key": text_key, "default_value": default_value}
	return true


func make_effect(key: String, value: int) -> Resource:
	if not _stats.has(key):
		push_error("CustomStatService: unregistered stat: " + key)
		return null
	var stat = _stats[key]
	var effect = EFFECT_SCRIPT.new()
	effect.key = key
	effect.key_hash = stat.hash
	effect.text_key = stat.text_key
	effect.value = value
	return effect


func get_value(player_index: int, key: String) -> int:
	if not _stats.has(key):
		return 0
	var stat = _stats[key]
	return int(RunData.get_player_effects(player_index).get(stat.hash, stat.default_value))


func seed_effects(effects: Dictionary) -> void:
	for stat in _stats.values():
		if not effects.has(stat.hash):
			effects[stat.hash] = stat.default_value
