![GitHub License](https://img.shields.io/github/license/Morningstar2808/OpenWrt-nikki?style=for-the-badge&logo=github) ![GitHub Tag](https://img.shields.io/github/v/release/Morningstar2808/OpenWrt-nikki?include_prereleases&style=for-the-badge&logo=github) ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/Morningstar2808/OpenWrt-nikki/total?style=for-the-badge&logo=github)

English

# Nikki (fork)

Transparent Proxy with Mihomo on OpenWrt.

Fork of [nikkinikki-org/OpenWrt-nikki](https://github.com/nikkinikki-org/OpenWrt-nikki).

What is different here:

- custom HTTP headers for subscription downloads, including device identification (HWID) — see [upstream PR #879](https://github.com/nikkinikki-org/OpenWrt-nikki/pull/879)
- own version numbering, starting at 1.27.0 — one minor ahead of upstream
- packages are published as GitHub Releases only; there is no package feed (yet), so updating means running the install script again
- builds are limited to `aarch64_cortex-a53`, `aarch64_generic`, `mipsel_24kc`, `x86_64` on OpenWrt 24.10 and 25.12

Tags with a suffix (`v1.27.0-rc1`) are published as pre-releases, tags without one (`v1.27.0`) as regular releases.

## Prerequisites

- OpenWrt 24.10 or 25.12
- Linux Kernel >= 5.13
- firewall4

## Feature

- Transparent Proxy (Redirect/TPROXY/TUN, IPv4 and/or IPv6)
- Access Control
- Profile Mixin
- Profile Editor
- Scheduled Restart
- Custom HTTP headers for subscription downloads (HWID and similar)

## Install & Update

```shell
wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
```

The script detects the router's architecture and OpenWrt branch, downloads the
matching asset from the latest release (pre-releases included) and installs it.
Running it again is the update path — and it is safe to repeat: only packages
whose version differs from what is installed are touched, so an unchanged run
leaves the service alone instead of restarting it.

LuCI translations are not installed by default — the interface stays English.
The script prints which translations the build contains.

Options (arguments, or the matching `NIKKI_*` environment variables):

```shell
# переводы LuCI: коды через пробел, или all
wget -O - .../install.sh | ash -s -- --lang ru
wget -O - .../install.sh | ash -s -- --lang "ru zh-cn"
# ядро mihomo: meta (по умолчанию) или alpha
wget -O - .../install.sh | ash -s -- --mihomo alpha
# конкретный релиз / другое зеркало
wget -O - .../install.sh | ash -s -- --tag v1.27.0-rc2 --repo owner/repo
# переустановить, даже если версии совпадают
wget -O - .../install.sh | ash -s -- --force
# справка
wget -O - .../install.sh | ash -s -- --help
```

The release ships `mihomo-meta` — the core built from MetaCubeX's tagged
releases. `mihomo-alpha` (nightly branch) is not included; the two packages
conflict with each other, so exactly one is installed. If the other variant is
already on the router, the script stops and prints the removal commands instead
of breaking the install halfway.

Manual install, if the script cannot be used:

```shell
# 1. find your arch and branch
. /etc/openwrt_release; echo "$DISTRIB_ARCH $DISTRIB_RELEASE"
# 2. download nikki_<arch>-<branch>.tar.gz from the Releases page
# 3. unpack and install
tar -x -z -f nikki_<arch>-<branch>.tar.gz
opkg install ./*.ipk                      # OpenWrt 24.10
apk add --allow-untrusted ./*.apk         # OpenWrt 25.12
```

## Uninstall & Reset

```shell
wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/uninstall.sh | ash
```

## How To Use

See the [upstream Wiki](https://github.com/nikkinikki-org/OpenWrt-nikki/wiki).

## How does it work

1. Mixin and Update profile.
2. Run mihomo.
3. Set scheduled restart.
4. Set ip rule/route
5. Generate nftables and apply it.

Note that the steps above may change base on config.

## Compilation

```shell
# add feed
echo "src-git nikki https://github.com/Morningstar2808/OpenWrt-nikki.git;main" >> "feeds.conf.default"
# update & install feeds
./scripts/feeds update -a
./scripts/feeds install -a
# make package
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

## Credits
