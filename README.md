![GitHub License](https://img.shields.io/github/license/Morningstar2808/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/Morningstar2808/OpenWrt-nikki?style=for-the-badge&logo=github)

**Languages:** [English](README.md) | [Русский](README.ru.md)

# Nikki

Transparent Proxy with Mihomo on OpenWrt.

## What is different here

- Own version numbering, starting at 1.27.0 — one minor ahead of upstream
- Packages are published as GitHub Releases only; there is no package feed (yet), so updating means running the install script again
- Builds are limited to `aarch64_cortex-a53`, `aarch64_generic`, `mipsel_24kc`, `x86_64` on OpenWrt 24.10 and 25.12

Tags with a suffix (`v1.27.0-rc1`) are published as pre-releases, tags without one (`v1.27.0`) as regular releases.

## Requirements

- OpenWrt 24.10 or 25.12
- Linux Kernel >= 5.13
- firewall4

## Features

- Transparent Proxy (Redirect/TPROXY/TUN, IPv4 and/or IPv6)
- Access Control
- Profile Mixin
- Profile Editor
- Scheduled Restart
- Custom HTTP headers for subscription downloads (HWID and similar)

## Installation & Update

```shell
wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```

The script detects the router's architecture and OpenWrt branch, downloads the matching asset from the latest release (pre-releases included) and installs it. Running it again is the update path — and it is safe to repeat: only packages whose version differs from what is installed are touched, so an unchanged run leaves the service alone instead of restarting it.

LuCI translations are not installed by default — the interface stays English. The script prints which translations the build contains.

Options (arguments, or the matching `NIKKI_*` environment variables):

```shell
# LuCI translations: space-separated codes or all
wget -O - .../install.sh | ash -s -- --lang ru
wget -O - .../install.sh | ash -s -- --lang "ru zh-cn"
# specific release / alternative mirror
wget -O - .../install.sh | ash -s -- --tag v1.27.0-rc2 --repo owner/repo
# reinstall, even if versions match
wget -O - .../install.sh | ash -s -- --force
# help
wget -O - .../install.sh | ash -s -- --help
```

The core is always `mihomo-meta`, built from MetaCubeX's tagged releases.

### Manual Installation

If the script cannot be used:

```shell
# 1. Find your architecture and branch
. /etc/openwrt_release; echo "$DISTRIB_ARCH $DISTRIB_RELEASE"
# 2. Download nikki_<arch>-<branch>.tar.gz from the Releases page
# 3. Unpack and install
tar -x -z -f nikki_<arch>-<branch>.tar.gz
opkg install ./*.ipk                      # OpenWrt 24.10
apk add --allow-untrusted ./*.apk         # OpenWrt 25.12
```

## Uninstall & Reset

```shell
wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/uninstall.sh | ash
```

## How to Use

See the [upstream Wiki](https://github.com/nikkinikki-org/OpenWrt-nikki/wiki).

## How it Works

1. Mixin and update profile
2. Run mihomo
3. Set scheduled restart
4. Set IP rule/route
5. Generate nftables and apply it

Note: The steps above may change based on configuration.

## Compilation

```shell
# Add feed
echo "src-git nikki https://github.com/Morningstar2808/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# Update & install feeds
./scripts/feeds update -a
./scripts/feeds install -a
# Compile package
make package/luci-app-nikki/compile
```

The package files will be found under `bin/packages/your_architecture/nikki`.

## Dependencies

- ca-bundle
- curl
- yq
- firewall4
- ip-full
- kmod-inet-diag
- kmod-nft-socket
- kmod-nft-tproxy
- kmod-tun
- kmod-dummy
