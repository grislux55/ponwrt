# NNRRWrt (Next-gen Network Routing & Relay Wrt)

[English](README.md) | 简体中文

**NNRRWrt** 是重点面向 **Nokia XG-040G-MD**（Airoha AN7581，含标准 UBI 与 USB-SFP 双变体）深度定制的 Linux 6.18 高性能光猫主路由与中继固件，同时完整保留对其他 Airoha AN7581 / AN7583 机型的构建兼容，基于 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 与 [PonWrt](https://github.com/pbs05/ponwrt) 持续演进。

## ⚠️ 免责声明

NNRRWrt 是一个用于技术研究、学习与家庭网络工程实践的开源固件项目。

刷写固件或修改 PON 相关配置存在风险，可能导致设备无法启动、配置或设备数据丢失、PON 无法注册等问题。操作前请务必备份原厂固件及设备相关数据。

使用者应自行确保相关操作符合当地法律法规及运营商相关规定。请勿将本项目用于未经授权的网络接入、冒用或复制他人设备身份，或干扰运营商网络正常运行。

因刷写、配置或使用本项目产生的设备故障、网络服务异常及其他后果，由使用者自行承担。

## 仓库矩阵与职责划分

| 仓库 | Feed / 定位 | 核心职责说明 |
| --- | --- | --- |
| [`grislux55/nnrrwrt`](https://github.com/grislux55/nnrrwrt) | 主固件构建仓 | ImmortalWrt 构建框架、Linux 6.18 Airoha PPE/QDMA/LRO/P-bit 内核补丁、Nokia XG-040G-MD 定制配置、系统安全默认策略与四段式 CI/Release 工作流 |
| [`grislux55/nnrrwrt-drivers`](https://github.com/grislux55/nnrrwrt-drivers) | `nnrrwrt_drivers` | Airoha AN7581/AN7583 xPON MAC 控制器（`kmod-airoha-xpon`，支持 `pon0-*` LED 触发器状态重放）与光前端（`EN7572` / `GN28L95` / `UX3363`）内核驱动及微码 |
| [`grislux55/nnrrwrt-packages`](https://github.com/grislux55/nnrrwrt-packages) | `nnrrwrt_packages` | Rust OMCI/OAM 协议守护进程（`airoha-pond`）、`ponctl`、`airoha-pon-debug`、双栈隔离 TR-069 CWMP 沙盒（`airoha-tr069-fake` + LuCI）、专属网关仪表盘 `luci-app-nnrrwrt-dashboard`、`luci-app-pon` 与 `luci-app-iptv` |
| [`pbs05/an758x-stock2ubi`](https://github.com/pbs05/an758x-stock2ubi) | 上游迁入工具 | 原厂闪存全量备份与免拆原位迁入 UBI 布局工具 |
| [`pbs05/uboot-an758x`](https://github.com/pbs05/uboot-an758x) | 上游引导程序 | Airoha AN758x BL2/FIP U-Boot 与 Web 恢复固件 |

## 核心特性（Nokia XG-040G-MD 定制方案）

- **硬件流卸载与长时运行稳定性**：默认启用 Airoha PPE 硬件流表卸载（开启 `FLOW_STATS` 与可调 `bind_rate`）、PON 多 GEM 动态 P-bit 硬件元数据卸载、WAN (`pon0`) 与 2.5GbE LAN (`lan1`) 共享 QDMA 硬件 LRO、EIP-93 硬件加解密 + ARM64 NEON AES、RPS/XPS + `irqbalance`、TCP BBR 与 FullCone NAT；内建 QDMA RX 环过消费/空环恢复与全 32 队列 IRQ Bank 绑定修复，根治高负载长时运行下行断流。
- **三种标准组网与 IPTV 边界隔离**：开箱默认「光猫主路由」（`pon0` WAN + `br-lan` `192.168.1.1/24`），规范支持「透明光猫桥接」与「旁路中继」模式，并在 `firewall4` 桥接流表中自动排除隔离网桥 `br-iptv`。
- **双栈 OMCI 通道与隔离态 TR-069 沙盒**：`airoha-pond` 原生解析双栈管理通道（`ME 134/136/340/347`），配合 `airoha-tr069-fake` 在独立路由表与防火墙区域内运行持久化虚拟 CWMP 模型并输出 `/tmp` 环形脱敏审计日志。
- **专属网关仪表盘、全量 10 颗 LED 与安全备份**：内置 `luci-app-nnrrwrt-dashboard` 实时首页总览、全部 10 颗物理 LED LuCI 管控（含 EN8811H PHY `LED0` 驱动的 `LAN1` 2.5G 灯与保配置升级自动回填）、关键五卷（`bosa`/`ri`/`fip`/`ubootenv`/`ubootenv2`）只读 `.tar.gz` 一键备份，并在未配置时自动收敛停用 Tailscale / DDNS 后台进程。

## 支持设备

| SoC | 设备 | Profile | 原厂校准/身份数据分区 |
| --- | --- | --- | --- |
| AN7581 | **Nokia XG-040G-MD UBI**（主力定制机型） | `nokia_xg-040g-md-ubi`、`nokia_xg-040g-md-ubi-usb-sfp` | `bosa`、`ri` |
| AN7581 | Nokia XG-040G-TF UBI | `nokia_xg-040g-tf-ubi` | `bosa`、`ri` |
| AN7581 | FiberHome HG5382A | `fiberhome_hg5382a` | `factory` |
| AN7581 | FiberHome HG5585F CT | `fiberhome_hg5585f-ct` | `factory` |
| AN7581 | FiberHome HG5585F CU | `fiberhome_hg5585f-cu` | `factory` |
| AN7581 | Gemtek XG2010G | `gemtek_xg2010g` | `dsd` |
| AN7581 | UnionMan UNG00A | `unionman_ung00a` | `reservearea` |
| AN7581 | ZNXT ZN504XG-D | `znxt_zn504xg-d` | `reservearea` |
| AN7581 | ZNXT ZN515XG-D | `znxt_zn515xg-d` | `reservearea` |
| AN7581 | H3C HM2004-DU | `h3c_hm2004-du` | `factory` |
| AN7583 | Nokia XG-040G-MF | `nokia_xg-040g-mf`、`nokia_xg-040g-mf-ubi` | `bosa`、`ri` |

## 编译

```sh
# 1. 安装编译依赖（Debian/Ubuntu；构建入口已内置 WSL2 空格 PATH 自动清洗）
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
  bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
  g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
  libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
  libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
  ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
  python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
  upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd

# 或使用 ImmortalWrt 一键脚本初始化编译环境
sudo bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 2. 拉取 NNRRWrt 源码
git clone https://github.com/grislux55/nnrrwrt.git
cd nnrrwrt

# 3. 更新并安装 feeds（软件包源）
./scripts/feeds update -a
./scripts/feeds install -a

# 4. 选择构建配置
# 方式 A（推荐）：Nokia XG-040G-MD（标准 UBI + USB-SFP 双变体）NNRRWrt 定制配置
cp configs/nnrrwrt-xg040g-md.config .config

# 方式 B：通用 AN7581 / AN7583 全机型发布配置
# ./scripts/kconfig.pl + configs/an7581.config configs/release.config > .config
# ./scripts/kconfig.pl + configs/an7583.config configs/release.config > .config

# 5. 生成完整配置并并行编译
make defconfig
make -j"$(nproc)"
```

编译产物输出至 `bin/targets/airoha/an7581/`（或 `bin/targets/airoha/an7583/`）。

## 刷入、备份与默认访问

使用 [AN758x-Stock2UBI](https://github.com/pbs05/an758x-stock2ubi) 备份原厂闪存并安装 UBI 布局。启动镜像和 Web 恢复界面由 [AN758x U-Boot](https://github.com/pbs05/uboot-an758x) 提供。

- **默认管理入口**：`http://192.168.1.1` 或 `https://192.168.1.1`（默认关闭强制跳转 `redirect_https=0`，账号 `root` 初始无密码，首次登录后请立即设置管理密码）
- **默认系统参数**：主机名 `NNRRWrt`，时区 `Asia/Shanghai`（`CST-8`），SSH 仅监听 `lan` 侧接口
- **板级校准与关键卷备份/恢复**：刷入固件后，可通过 U-Boot Web 或 LuCI **「网络 → PON → 配置 → PON 板级数据」** 恢复/导出 Nokia `bosa` 与 `ri` 卷，并支持一键只读导出包含 `bosa`/`ri`/`fip`/`ubootenv`/`ubootenv2` 及 SHA-256 清单的 `.tar.gz` 全量备份包。烽火机型 `factory` 需先经 [FiberHome Factory](https://github.com/pbs05/fiberhome-factory) 转换后再写入 `factory` 卷。

## 致谢

- 上游基础发行版：[ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 与 [OpenWrt](https://openwrt.org/)
- 上游 Airoha PON 平台与驱动基线：[pbs05/ponwrt](https://github.com/pbs05/ponwrt)、[pbs05/openwrt-pon-drivers](https://github.com/pbs05/openwrt-pon-drivers) 与 [pbs05/openwrt-pon-userspace](https://github.com/pbs05/openwrt-pon-userspace)
