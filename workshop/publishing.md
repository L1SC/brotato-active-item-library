# Steam 创意工坊发布记录

## 1.0.2 — 2026-10-08

- 更新原[公开工坊条目 3814123809](https://steamcommunity.com/sharedfiles/filedetails/?id=3814123809)，将主动道具键盘默认键从 Q 改为空格键，手柄仍为 RB/R1。旧版未标版本且设为 Q 的配置会迁移到空格键，非 Q 的自定义按键保留；用户之后手动设回 Q 也会保存。
- ZIP 为 15,221 字节、8 个文件，SHA256 为 `bc8bd772a2bddafb8a30dcbc816a17c4dd1bd49c6551de4c82f37b8cc0a02d33`。SteamUGC 返回 `item_updated = 1`、`needs_agreement = false`；重新下载后的工坊 ZIP 与发布包逐字节一致。
- [GitHub Release v1.0.2](https://github.com/L1SC/brotato-active-item-library/releases/tag/v1.0.2) 已公开；重新下载的 ZIP SHA256 与工坊包一致。
- 实际 Godot 隔离运行通过新旧配置迁移、空格键单机 35 项、双进程 LAN 房主 17 项/客户端 18 项，以及与 valotato 同时加载的逐风属性和 LAN 检查。本机已启用的模组配置下，两套服务读取的默认键均为空格键。

## 1.0.1 — 2026-10-08

- 更新原[公开工坊条目 3814123809](https://steamcommunity.com/sharedfiles/filedetails/?id=3814123809)，没有创建新条目。新 ZIP 为 15,092 字节、8 个文件，仅含 `L1SC-ActiveItemLibrary`；SHA256 为 `12ff5491f30fe2e76cef331a1401206731af107f26ea76478da4c72d93cbffe0`。
- 新增 `CustomStatService`：注册自定义整数属性、生成可随普通道具增减的原版 `Effect`、读取玩家属性值。保留现有主动道具接口；血条旁图标布局纳入此次更新。工坊说明已同步。
- SteamUGC 返回 `item_updated = 1`、`needs_agreement = false`。远程查询显示应用 ID `1942280`、原所有者、公开状态和新文件大小；随后调用 `downloadItem`，Steam 安装 ZIP 的大小与 SHA256 均与发布包一致。
- [GitHub Release v1.0.1](https://github.com/L1SC/brotato-active-item-library/releases/tag/v1.0.1) 已公开；重新下载的 ZIP 与工坊发布包 SHA256 一致，附带 SHA256 文件。
- 实际 Brotato 1.1.15.4 运行时通过库单独启动、主动道具单机 35 项和双进程 LAN 17/18 项回归；自定义属性的默认值、正负道具效果及存档恢复也通过。与 valotato 双模组加载的属性、按键和局内状态恢复通过，当前源码 LAN 房主 17 项、客户端 27 项通过。

## 1.0.0 — 2026-10-05

- 发布日期：2026-10-05（Steam 时间戳 `1791215853`）
- Mod ID / 版本：`L1SC-ActiveItemLibrary` / `1.0.0`
- [公开工坊条目](https://steamcommunity.com/sharedfiles/filedetails/?id=3814123809)
- [GitHub 源码与 Release v1.0.0](https://github.com/L1SC/brotato-active-item-library/releases/tag/v1.0.0)
- Steam 应用 ID：`1942280`；条目 ID：`3814123809`
- 发布内容：`L1SC-ActiveItemLibrary.zip`，13,487 字节，7 个文件；不含私有测试模组、ContentLoader、Brotils 或 Brotato Online
- 本地及 Steam 下载 ZIP 的 SHA256：`23272774e965861ef8a8ab35781355454334928ca9c85c394a4b28499deb0422`

使用游戏已安装的 `GodotWorkshopUtility.exe` 和 SteamUGC 接口创建并上传。Steam 返回 `item_created = 1`、`item_updated = 1`、无需补签协议；标题、说明、标签、可见性、内容目录与预览图 setter 均返回成功。随后通过 SteamUGC 查询确认可见性为 `0`（Public），应用 ID、所有者、标题、标签、文件大小与预览图大小正确；`downloadItem` 成功，从 Steam 下载的 ZIP 与本地发布包逐字节一致，ZIP CRC 通过。

GitHub Release 的安装 ZIP 也已重新下载核验，与工坊版本的 SHA256 一致，ZIP CRC 通过。仓库公开了源码、接口文档、构建脚本和工坊素材，未提交私有测试文件、旧版 ZIP 或内部工作台账。

GitHub 仓库现以 [MIT License](../LICENSE) 发布原创源码、接口文档、构建脚本和工坊素材；已发布的 1.0.0 工坊包保持不变。

公开网页抓取工具未能打开 Steam 社区页面，因此公开状态以 SteamUGC 实际查询为准。功能测试范围见 [README](../README.md) 的「已验证范围」，发布成功不代表实体手柄、跨电脑 Steam P2P 或所有第三方内容模组组合已验证。
