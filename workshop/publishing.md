# Steam 创意工坊发布记录

- 发布日期：2026-10-05（Steam 时间戳 `1791215853`）
- Mod ID / 版本：`L1SC-ActiveItemLibrary` / `1.0.0`
- [公开工坊条目](https://steamcommunity.com/sharedfiles/filedetails/?id=3814123809)
- [GitHub 源码与 Release v1.0.0](https://github.com/L1SC/brotato-active-item-library/releases/tag/v1.0.0)
- Steam 应用 ID：`1942280`；条目 ID：`3814123809`
- 发布内容：`L1SC-ActiveItemLibrary.zip`，13,487 字节，7 个文件；不含私有测试模组、ContentLoader、Brotils 或 Brotato Online
- 本地及 Steam 下载 ZIP 的 SHA256：`23272774e965861ef8a8ab35781355454334928ca9c85c394a4b28499deb0422`

使用游戏已安装的 `GodotWorkshopUtility.exe` 和 SteamUGC 接口创建并上传。Steam 返回 `item_created = 1`、`item_updated = 1`、无需补签协议；标题、说明、标签、可见性、内容目录与预览图 setter 均返回成功。随后通过 SteamUGC 查询确认可见性为 `0`（Public），应用 ID、所有者、标题、标签、文件大小与预览图大小正确；`downloadItem` 成功，从 Steam 下载的 ZIP 与本地发布包逐字节一致，ZIP CRC 通过。

GitHub Release 的安装 ZIP 也已重新下载核验，与工坊版本的 SHA256 一致，ZIP CRC 通过。仓库公开了源码、接口文档、构建脚本和工坊素材，未提交私有测试文件、旧版 ZIP 或内部工作台账。

公开网页抓取工具未能打开 Steam 社区页面，因此公开状态以 SteamUGC 实际查询为准。功能测试范围见 [README](../README.md) 的「已验证范围」，发布成功不代表实体手柄、跨电脑 Steam P2P 或所有第三方内容模组组合已验证。
