extends "res://ui/menus/shop/base_shop.gd"

const SERVICE_PATH = "/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService"


func on_shop_item_bought(shop_item: Control, player_index: int) -> void:
	var service = get_node_or_null(SERVICE_PATH)
	if service != null:
		service.call("begin_purchase", player_index, shop_item.item_data, int(shop_item.value))
	.on_shop_item_bought(shop_item, player_index)
	if service != null:
		service.call("end_purchase", player_index)
