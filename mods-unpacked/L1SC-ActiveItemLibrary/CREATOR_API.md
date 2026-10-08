# Active Item Library / 主动道具前置库

- Mod ID: `L1SC-ActiveItemLibrary`
- Active-item service node: `/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService`
- Custom-stat service node: `/root/ModLoader/L1SC-ActiveItemLibrary/CustomStatService`
- Supported target: Brotato 1.1.15.4 with ModLoader 6.2.0. Brotato Online 6.6.6 is optional.

This library contains no characters, items, weapons or skill effects. Content mods supply their own `ItemData` and activation handler. The library supplies one active-item slot per player, Space/RB input, cooldown, an item-choice popup, save state support and Brotato Online messaging. It also provides a generic interface for integer custom stats backed by the game's ordinary item `Effect` resources.

## Register and use a custom stat

Add `L1SC-ActiveItemLibrary` to your content mod's `manifest.json` `dependencies`. Register each stat before ContentLoader creates any `ItemData` effects that use it. Use a key unique to your mod and register the display text key in your mod's translations. The library does not assign gameplay meaning, units or a maximum to the value.

```gdscript
const STATS_PATH = "/root/ModLoader/L1SC-ActiveItemLibrary/CustomStatService"
const STAT_KEY = "stat_your_namespace_skill_strength"
const STAT_TEXT_KEY = "YOUR_NAMESPACE_SKILL_STRENGTH"

func _ready() -> void:
    var stats = get_node(STATS_PATH)
    var accepted = stats.register_stat(STAT_KEY, STAT_TEXT_KEY, 0)
    assert(accepted)
    # Load content that uses this stat after registration.

func add_stat_effect(item: Resource) -> void:
    var stats = get_node(STATS_PATH)
    item.effects = item.effects.duplicate()
    item.effects.append(stats.make_effect(STAT_KEY, 25))

func read_stat(player_index: int) -> int:
    return get_node(STATS_PATH).get_value(player_index, STAT_KEY)
```

`register_stat(key: String, text_key: String, default_value: int = 0) -> bool` declares the stat and its starting value; it returns `false` for an empty or duplicate key, empty text key, or a hash collision. Call it before `make_effect()`, which returns `null` for an unregistered key. `make_effect(key: String, value: int) -> Resource` creates an ordinary game `Effect`; positive and negative values can be combined across items. `get_value(player_index: int, key: String) -> int` reads the current value. When an item grants or removes its effect, the game's normal effect application updates the stat; inventory and effect persistence use the game's normal save path. The content mod decides how to interpret the number and must register its own display translation. Custom stats are not automatically added to the game's stat panel.

## Declare an active item

Add `L1SC-ActiveItemLibrary` to your content mod's `manifest.json` `dependencies`. If you use ContentLoader to add `ItemData`, also declare its own dependencies as required by ContentLoader. Register your item ID in your mod's `_ready()`; declaration can run before ContentLoader has finished adding the item to `ItemService`.

```gdscript
const LIBRARY_PATH = "/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService"
const ACTIVE_ID = "your_namespace_active_item"

func _ready() -> void:
    var library = get_node(LIBRARY_PATH)
    var accepted = library.register_active_item(ACTIVE_ID, self, {
        "cooldown_seconds": 8.0,
        "display_name": "Your Active Item" # Optional; defaults to the ItemData name.
    })
    assert(accepted)

func activate_active_item(player_index: int, item_id: String, request_data: Dictionary) -> Dictionary:
    # Runs only on the authoritative game instance. Validate any client-supplied data.
    # Apply the gameplay effect here, then return an optional visual payload.
    return {"ok": true, "visual": {"kind": "your_effect"}}

func get_active_item_request_data(player_index: int, item_id: String) -> Dictionary:
    # Optional: capture local aim/target input to send to the host.
    return {}

func show_active_item_visual(player_index: int, item_id: String, visual: Dictionary) -> void:
    # Optional: called on host and clients after activation is confirmed.
    pass
```

The registered resource must be `Category.ITEM` with `max_nb == 1`. Give it a unique `my_id`. A declaration made before the resource is loaded is accepted; an invalid resource will not occupy the active slot. Keep the handler node alive while the mod is active. `register_active_item()` returns `false` for an empty ID, missing handler method, negative cooldown, duplicate declaration, or an already loaded resource with the wrong category/max count. `unregister_active_item(item_id, handler)` only succeeds for the original handler.

The handler returns `{"ok": true}` to consume the activation and start cooldown. Any other result rejects the activation without consuming cooldown. The library does not create damage, projectiles, status effects or other gameplay content. A content mod must implement its own gameplay effect and synchronize custom state that Brotato Online does not already synchronize.

## Active slot and item acquisition

The equipped active item is derived from `RunData` inventory. A character can obtain one through normal starting-item selection, a shop purchase, a reward or any other call to `RunData.add_item()`. No character-specific skill registration is needed.

If the player acquires a different registered active item while one is equipped, a popup offers **keep current** or **equip new**. Only the owner's local screen displays the popup. Both items are temporarily in inventory until a choice is committed; activation is blocked during that time. The discarded item is removed with `RunData.remove_item()`. When the second item was bought in a shop, keeping the current item refunds the amount actually charged, capped by the gold available before the purchase. Pending choice and refund price are included in run save state.

Characters may use the game's own `starting_items` mechanism to offer an active item at the start. In Brotato 1.1.15.4, `CharacterData.starting_items` is an array of item-choice arrays, for example `[[your_item_data]]`. The native character/start-item selection screen performs the grant; merely setting this property in a synthetic run does not itself add the item.

## Character-specific random pool

```gdscript
library.set_character_active_pool("your_character_id", [ACTIVE_ID])
```

This restricts only **registered active items** that can appear from random item rolls for that character. An empty array excludes all registered active items from random rolls. Ordinary items are unaffected. Other characters, with no pool configured, can roll every registered active item. Direct grants, native starting items and explicit forced shop items are still allowed. Use `clear_character_active_pool(character_id)` to remove a restriction, or `is_item_allowed_for_player(item_id, player_index)` to inspect it.

## Input, state and signals

- Keyboard Space and gamepad right shoulder (RB/R1) activate the equipped item by default. `get_bindings()` returns `keyboard_scancode` and `joypad_button`. `set_bindings(scancode, button_index)` changes both and stores them in `user://l1sc_active_item_library_bindings.cfg`. Any unversioned binding saved as Q migrates to Space; non-Q bindings remain. Call `set_bindings()` again if you want Q after upgrading. There is no in-game rebinding menu.
- `get_equipped_item_id(player_index)` returns the active `my_id` or an empty string.
- `get_state(player_index)` returns `item_id`, `display_name`, `battle_active`, `alive`, `available`, `ready`, `pending`, and `cooldown_remaining` (seconds).
- `request_activation(player_index, request_data = {})` supports programmatic use. On a client, `true` means the request was sent, not that the host accepted it.
- Signals: `active_item_activated(player_index, item_id, visual)`, `state_changed(player_index, state)`, `activation_rejected(player_index, reason)`, and `active_item_changed(player_index, item_id)`.

Cooldown advances only during an unpaused battle and resets when the equipped item changes or a new battle scene starts. A small icon beside the player's health bar shows the equipped item: bright when ready, dark while unavailable or cooling down. The library will run solo without Brotato Online; when Online is installed and a session is active, the host validates player ownership, inventory, life state and cooldown before executing the handler.

## Installation and compatibility

Place the `L1SC-ActiveItemLibrary.zip` file, without extracting it, in Brotato's `mods` directory, enable it in the game's mod menu, and restart if prompted. In Online play, all peers need the same library and content mod versions. This library does not bundle or require ContentLoader, Brotils or Brotato Online.

Tested with the installed Brotato 1.1.15.4, ModLoader 6.2.0 and Brotato Online 6.6.6 in isolated solo and two-process LAN runs. Physical controller hardware, cross-computer Steam P2P, and every other mod combination have not been verified.
