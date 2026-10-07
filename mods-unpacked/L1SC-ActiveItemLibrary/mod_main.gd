extends Node

const SERVICE_SCRIPT = preload("res://mods-unpacked/L1SC-ActiveItemLibrary/active_item_service.gd")
const STAT_SERVICE_SCRIPT = preload("res://mods-unpacked/L1SC-ActiveItemLibrary/custom_stat_service.gd")


func _init() -> void:
	var base = ModLoaderMod.get_unpacked_dir().plus_file("L1SC-ActiveItemLibrary")
	ModLoaderMod.install_script_extension(base.plus_file("extensions/run_data.gd"))
	ModLoaderMod.install_script_extension(base.plus_file("extensions/item_service.gd"))
	ModLoaderMod.install_script_extension(base.plus_file("extensions/base_shop.gd"))


func _ready() -> void:
	var stat_service = STAT_SERVICE_SCRIPT.new()
	stat_service.name = "CustomStatService"
	add_child(stat_service)
	var service = SERVICE_SCRIPT.new()
	service.name = "ActiveItemService"
	add_child(service)
