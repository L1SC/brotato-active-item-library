# Active Item Library / 主动道具前置库

这是一个**不添加任何实际游戏内容**的 Brotato 前置模组。内容作者把自己的 `ItemData` 注册为主动道具后，玩家可以在独立槽位里装备一件，默认用键盘空格键或手柄 RB/R1 触发。获得第二件时，玩家选择保留旧道具或换上新道具；商店购买后保留旧道具会退款。内容作者也能注册自定义整数属性，让普通道具通过原版 `Effect` 增减属性。

Mod ID：`L1SC-ActiveItemLibrary`。已发布到 [Steam 创意工坊](https://steamcommunity.com/sharedfiles/filedetails/?id=3814123809)。适配 Brotato 1.1.15.4、ModLoader 6.2.0，兼容本机安装的 Brotato Online 6.6.6。Brotato Online 是可选模组，本库单机也能运行。

## 给玩家

可以订阅 [创意工坊条目](https://steamcommunity.com/sharedfiles/filedetails/?id=3814123809)，或从 [GitHub Releases](https://github.com/L1SC/brotato-active-item-library/releases) 下载 `L1SC-ActiveItemLibrary.zip`，**不要解压**，放入 Brotato 安装目录的 `mods` 文件夹，在游戏模组菜单启用。还需要安装实际提供主动道具的内容模组；本库本身不会让游戏出现新角色或新道具。联机时所有参与者应安装相同版本的本库和内容模组。

## 给内容作者

在你的 `manifest.json` 的 `dependencies` 中加入 `L1SC-ActiveItemLibrary`。获得服务节点 `/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService`，按 **ItemData.my_id** 注册处理器：

```gdscript
var library = get_node("/root/ModLoader/L1SC-ActiveItemLibrary/ActiveItemService")
library.register_active_item("your_active_item_id", self, {"cooldown_seconds": 8.0})

func activate_active_item(player_index: int, item_id: String, request_data: Dictionary) -> Dictionary:
    # 在主机或单机执行实际效果；自行验证客户端传来的参数。
    return {"ok": true, "visual": {}}
```

主动道具必须是 `Category.ITEM`，`max_nb` 必须为 `1`。内容模组可以使用原版角色 `starting_items` 指定开局道具；`set_character_active_pool(character_id, allowed_item_ids)` 则限制该角色**随机刷新**的主动道具类型。未设置限制的角色可以自由获得任意已注册主动道具。完整接口、可选回调、信号与联机职责见包内 [CREATOR_API.md](mods-unpacked/L1SC-ActiveItemLibrary/CREATOR_API.md)。

自定义属性使用 `/root/ModLoader/L1SC-ActiveItemLibrary/CustomStatService`。在加载使用该属性的道具前调用 `register_stat(key, text_key, default_value)`；用 `make_effect(key, value)` 创建普通道具的正负效果，用 `get_value(player_index, key)` 读取属性。属性名称与数值含义由内容模组定义，具体示例见 [CREATOR_API.md](mods-unpacked/L1SC-ActiveItemLibrary/CREATOR_API.md)。

## 已验证范围

- 仅安装本库时可启动，保持无内容状态。
- 隔离单机测试：空格键、模拟 RB、冷却、独立槽位、随机池限制、商店购买与二选一、退款、存档恢复。
- 自定义属性接口在实际 Godot 运行时通过了默认值、正负道具效果叠加与移除、存档恢复检查；与 valotato 同时加载时也通过了主动技能强度和逐风位移检查。
- Brotato Online 双进程 LAN：客户端请求激活、主机执行效果、两端表现；战斗及商店阶段的主动道具选择；正常波次结束后的房主商店购买与背包同步。

私有测试道具、ContentLoader/Brotils ZIP、Brotato Online 和游戏素材均不进入本库发布 ZIP。实体手柄、跨电脑 Steam P2P 与全部第三方模组组合尚未实测。

## 从源码构建

运行 `python tools/build.py`，得到 `dist/L1SC-ActiveItemLibrary.zip`。工坊预览图可运行 `python workshop/generate_preview.py` 生成。[工坊发布记录](workshop/publishing.md)包含已发布 ZIP 的校验值与核验结果。

## 开源许可

本仓库中的原创源码、接口文档、构建脚本和工坊素材采用 [MIT License](LICENSE) 发布。使用、修改和再发布时请保留许可证与版权声明。Brotato、Brotato Online 以及其他第三方项目和商标不属于本许可范围。
