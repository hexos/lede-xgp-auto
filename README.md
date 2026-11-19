# NLnet XiGuaPi V3 (西瓜皮V3) LEDE 自动构建 — master 跟随版

基于 [zzzz0317/lede-xgp-auto-build](https://github.com/zzzz0317/lede-xgp-auto-build) 改造，
跟随 [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede) **master 主分支**编译，
并集成两项定制：

## 本仓库相对上游的改动

1. **修复直接构建失败**：上游 `.github/workflows/build.yml` 使用 `actions/cache@v3`，
   GitHub 已于 2025-02-01 下线旧缓存后端，导致 v3 工作流直接失败 → 升级为 `actions/cache@v4`。
2. **跟随 master 主分支**：`prepare.sh` 从上游同步定制文件（`files/`、`xgp.config`）后，
   克隆 `coolsnowwolf/lede` 的 `master` 分支；移除旧 config 中的内核版本锁定，
   由 `make defconfig` 按 master 当前默认内核重新生成，避免 config 漂移导致编译失败。
3. **集成 TD-TECH USB 模组补丁**：`999-add-TD-TECH-option-id.patch` 为内核
   `drivers/usb/serial/option.c` 增加 TD-TECH(VID 0x3466) 多个 PID 的识别。
   构建时按实际内核版本自动放入对应 `target/linux/rockchip/patches-<版本>/`，
   已确认在内核 6.12 / 6.18 上上下文均可应用。
4. **集成 at-webserver (UBUS 版) 插件**：上游提供的 `at-webserver-ubus.zip` 内是
   加固的 `.apk` 二进制包（apk-tools 格式），无法在 opkg/ipk 系统安装，也无法解包；
   因此改为拉取开源源码 [0x4ba/mt5700webui-openwrt-server](https://github.com/0x4ba/mt5700webui-openwrt-server)
   （含 UBUS 选项与串口配置修复），由源码编译出 ipk 并内置进固件。

## 使用方式

1. 点右上角 **Star**，在 **Actions** 页面手动触发 `Build and Release`（`workflow_dispatch`）。
2. 编译完成后在 Releases 页面下载固件。

如需恢复定时构建，取消 `.github/workflows/build.yml` 顶部 `schedule` 的注释。

## 已知事项

- 西瓜皮 V3 支持已合并至 LEDE 主线（[8547db9c](https://github.com/coolsnowwolf/lede/commit/8547db9c25d697d9d966f8f8e91c6a74066ff243)）。
- 通过转接板连接的 PCIe 5G 模块刷机后需断电一次，否则可能找不到模块（转接板硬件原因）。
- 默认信息：SSID `zzXGP` / 密码 `xgpxgpxgp`，LAN `10.0.0.1`，root 密码 `password`。
- at-webserver 为 Rust 项目，依赖 `rust/host` 交叉编译，首次构建耗时较长。

## 定制文件来源

`files/` overlay 与 `xgp.config` 在 `prepare.sh` 阶段从上游仓库自动同步，
因此本仓库无需重复存放这些二进制/自动生成文件，且始终跟随上游更新。

## 免责声明

本项目为个人构建配置，固件风险自担；详细条款参见上游项目说明。
