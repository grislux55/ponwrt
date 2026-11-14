# NNRRWrt (Next-gen Network Routing & Relay Wrt)

English | [简体中文](README_zh.md)

**NNRRWrt** is a Linux 6.18 optical gateway, main-router, and relay firmware primarily engineered for **Nokia XG-040G-MD** (Airoha AN7581, UBI & USB-SFP variants), while maintaining target compatibility across Airoha AN7581 and AN7583 PON devices. It is built upon [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) and [PonWrt](https://github.com/pbs05/ponwrt).

## ⚠️ Disclaimer

NNRRWrt is an open-source firmware project intended for research, learning, and home network engineering.

Flashing firmware or modifying PON-related settings involves risks and may result in boot failure, loss of configuration or device-specific data, or failure to register with the PON network. Please back up the original firmware and device data before making any changes.

Users are responsible for ensuring that their use complies with applicable laws, regulations, and network operator requirements. Do not use this project for unauthorized network access, impersonating or cloning another device's identity, or interfering with operator networks.

The authors and contributors are not responsible for device damage, network service disruption, or other consequences resulting from flashing, configuring, or using this project.

## Repository Ecosystem

| Repository | Feed / Role | Description |
| --- | --- | --- |
| [`grislux55/nnrrwrt`](https://github.com/grislux55/nnrrwrt) | Main Build Tree | ImmortalWrt build system, Linux 6.18 Airoha PPE/QDMA/LRO/P-bit kernel patches, Nokia XG-040G-MD profiles, NNRRWrt defaults, and 4-stage CI/Release workflow |
| [`grislux55/nnrrwrt-drivers`](https://github.com/grislux55/nnrrwrt-drivers) | `nnrrwrt_drivers` | Airoha AN7581/AN7583 xPON MAC (`kmod-airoha-xpon` with `pon0-*` LED trigger state replay) and optical frontend (`EN7572`, `GN28L95`, `UX3363`) kernel modules & firmware |
| [`grislux55/nnrrwrt-packages`](https://github.com/grislux55/nnrrwrt-packages) | `nnrrwrt_packages` | Rust OMCI/OAM daemon (`airoha-pond`), `ponctl`, `airoha-pon-debug`, isolated TR-069 CWMP sandbox (`airoha-tr069-fake` + LuCI), `luci-app-nnrrwrt-dashboard`, `luci-app-pon`, and `luci-app-iptv` |
| [`pbs05/an758x-stock2ubi`](https://github.com/pbs05/an758x-stock2ubi) | Upstream Tool | Stock flash backup and in-place UBI layout migration utility |
| [`pbs05/uboot-an758x`](https://github.com/pbs05/uboot-an758x) | Upstream Bootloader | BL2/FIP bootloader and Web recovery interface for Airoha AN758x |

## Key Capabilities (Nokia XG-040G-MD Profile)

- **Hardware Offload & Long-Haul QDMA Stability**: Enables Airoha PPE hardware flow offloading (`FLOW_STATS`, tunable `bind_rate`), PON multi-GEM P-bit offload, shared-QDMA hardware LRO across WAN (`pon0`) and 2.5GbE LAN (`lan1`), EIP-93 hardware crypto + ARM64 NEON AES, RPS/XPS + `irqbalance`, TCP BBR, FullCone NAT, and QDMA RX ring anti-stall / full 32-queue IRQ binding fixes.
- **Flexible Topologies & IPTV Isolation**: Out-of-the-box Optical Main Router (`pon0` WAN + `br-lan` `192.168.1.1/24`), Transparent Optical Bridge, and Bypass Relay support, with `firewall4` bridge flowtable exclusions protecting `br-iptv`.
- **Dual-Stack OMCI & Isolated TR-069 Sandbox**: `airoha-pond` parses dual-stack OMCI management channel MEs (`ME 134/136/340/347`), paired with `airoha-tr069-fake` running inside an isolated `netifd`/`firewall4` routing table and virtual CWMP data model.
- **Optical Gateway Dashboard, Full 10-LED Support & UBI Safety**: Ships with `luci-app-nnrrwrt-dashboard` (`admin/dashboard`), complete 10-LED LuCI control (`power`, `pon`, `los`, `internet`, `lan1..lan4`, `usb1..usb2`), read-only 5-volume UBI archive export (`bosa`, `ri`, `fip`, `ubootenv`, `ubootenv2`), and automatic convergence of unconfigured Tailscale/DDNS services.

## Supported devices

| SoC | Device | Profile | Stock calibration / identity data |
| --- | --- | --- | --- |
| AN7581 | **Nokia XG-040G-MD UBI** *(Primary Target)* | `nokia_xg-040g-md-ubi`, `nokia_xg-040g-md-ubi-usb-sfp` | `bosa`, `ri` |
| AN7581 | Nokia XG-040G-TF UBI | `nokia_xg-040g-tf-ubi` | `bosa`, `ri` |
| AN7581 | FiberHome HG5382A | `fiberhome_hg5382a` | `factory` |
| AN7581 | FiberHome HG5585F CT | `fiberhome_hg5585f-ct` | `factory` |
| AN7581 | FiberHome HG5585F CU | `fiberhome_hg5585f-cu` | `factory` |
| AN7581 | Gemtek XG2010G | `gemtek_xg2010g` | `dsd` |
| AN7581 | UnionMan UNG00A | `unionman_ung00a` | `reservearea` |
| AN7581 | ZNXT ZN504XG-D | `znxt_zn504xg-d` | `reservearea` |
| AN7581 | ZNXT ZN515XG-D | `znxt_zn515xg-d` | `reservearea` |
| AN7581 | H3C HM2004-DU | `h3c_hm2004-du` | `factory` |
| AN7583 | Nokia XG-040G-MF | `nokia_xg-040g-mf`, `nokia_xg-040g-mf-ubi` | `bosa`, `ri` |

## Build

```sh
# 1. Install build dependencies (Debian/Ubuntu; WSL2 PATH spaces are sanitized automatically)
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

# Or use the ImmortalWrt environment script:
sudo bash -c 'bash <(curl -s https://build-scripts.immortalwrt.org/init_build_environment.sh)'

# 2. Clone NNRRWrt
git clone https://github.com/grislux55/nnrrwrt.git
cd nnrrwrt

# 3. Update and install feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 4. Select configuration
# Option A (Recommended): NNRRWrt customized profile for Nokia XG-040G-MD (UBI & USB-SFP)
cp configs/nnrrwrt-xg040g-md.config .config

# Option B: Generic multi-device AN7581 / AN7583 release configuration
# ./scripts/kconfig.pl + configs/an7581.config configs/release.config > .config
# ./scripts/kconfig.pl + configs/an7583.config configs/release.config > .config

# 5. Expand Kconfig & build firmware
make defconfig
make -j"$(nproc)"
```

Built images are written to `bin/targets/airoha/an7581/` (or `bin/targets/airoha/an7583/`).

## Install & Default Access

Use [AN758x-Stock2UBI](https://github.com/pbs05/an758x-stock2ubi) to back up the stock flash and install the UBI layout. Boot images and Web recovery are provided by [AN758x U-Boot](https://github.com/pbs05/uboot-an758x).

- **Default Web UI**: `http://192.168.1.1` or `https://192.168.1.1` (`redirect_https=0`, default user `root` with no initial password; set a password immediately on first login)
- **Default System Settings**: Hostname `NNRRWrt`, timezone `Asia/Shanghai` (`CST-8`), SSH bound to `lan` only
- **Calibration & UBI Backup/Restore**: Restore or export `bosa` and `ri` (and export a read-only 5-volume `.tar.gz` archive of `bosa`/`ri`/`fip`/`ubootenv`/`ubootenv2`) via **Network → PON → Configuration → PON board data** in LuCI or U-Boot Web recovery. For FiberHome devices, convert `factory` dumps with [FiberHome Factory](https://github.com/pbs05/fiberhome-factory) before writing to the `factory` volume.

## Credits

- Upstream base system: [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) & [OpenWrt](https://openwrt.org/)
- Upstream Airoha PON target & driver foundation: [pbs05/ponwrt](https://github.com/pbs05/ponwrt), [pbs05/openwrt-pon-drivers](https://github.com/pbs05/openwrt-pon-drivers), and [pbs05/openwrt-pon-userspace](https://github.com/pbs05/openwrt-pon-userspace)
