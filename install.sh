#!/bin/sh

# nikki (fork) installer
#
# Ставит и обновляет пакеты из GitHub Releases этого форка.
# Своего фида у форка пока нет, поэтому обновление = повторный запуск скрипта.
#
#   wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
#
# Переменные окружения:
#   NIKKI_REPO — откуда брать релизы, по умолчанию Morningstar2808/OpenWrt-nikki
#   NIKKI_TAG  — конкретный тег, например v1.27.0-rc1.
#                По умолчанию берётся самый свежий релиз, включая pre-release.

set -e

REPO="${NIKKI_REPO:-Morningstar2808/OpenWrt-nikki}"
TAG="${NIKKI_TAG:-}"

# check env
if [ ! -x "/bin/opkg" ] && [ ! -x "/usr/bin/apk" ]; then
	echo "не найден ни opkg, ни apk"
	exit 1
fi
if [ ! -x "/sbin/fw4" ]; then
	echo "only supports OpenWrt build with firewall4!"
	exit 1
fi

# include openwrt_release
. /etc/openwrt_release

# get branch/arch
arch="$DISTRIB_ARCH"
branch=
case "$DISTRIB_RELEASE" in
	*"24.10"*)
		branch="openwrt-24.10"
		;;
	*"25.12"*)
		branch="openwrt-25.12"
		;;
	*)
		echo "unsupported release: $DISTRIB_RELEASE (форк собирает только 24.10 и 25.12)"
		exit 1
		;;
esac

asset="nikki_${arch}-${branch}.tar.gz"

# resolve tag
if [ -z "$TAG" ]; then
	echo "get latest release"
	wget -q -O "/tmp/nikki.releases" "https://api.github.com/repos/$REPO/releases?per_page=1"
	TAG="$(jsonfilter -i "/tmp/nikki.releases" -e "@[0].tag_name")"
	rm -f "/tmp/nikki.releases"
	if [ -z "$TAG" ]; then
		echo "не удалось определить последний релиз $REPO"
		exit 1
	fi
fi
echo "version: $TAG"

# download & unpack
work="$(mktemp -d)"
trap 'cd /; rm -rf "$work"' EXIT
cd "$work"

echo "download $asset"
if ! wget -q -O "$asset" "https://github.com/$REPO/releases/download/$TAG/$asset"; then
	echo "в релизе $TAG нет сборки под $arch / $branch"
	exit 1
fi
tar -x -z -f "$asset"
rm -f "$asset"

# get languages
echo "get languages"
if [ -x "/bin/opkg" ]; then
	ext="ipk"
	installed="$(opkg list-installed 'luci-i18n-base-*' | cut -d ' ' -f 1)"
else
	ext="apk"
	installed="$(apk list --installed --manifest 'luci-i18n-base-*' | cut -d ' ' -f 1)"
fi
# luci-i18n-base-ru -> ru, luci-i18n-base-zh-cn-24.100 -> zh-cn
languages="$(echo "$installed" | sed -n 's/^luci-i18n-base-//p' | sed 's/-[0-9].*$//')"

# список на установку: всё из архива, кроме переводов под неустановленные языки
set --
for file in *."$ext"; do
	[ -f "$file" ] || continue
	case "$file" in
		luci-i18n-nikki-*)
			for lang in $languages; do
				case "$file" in
					"luci-i18n-nikki-${lang}_"*|"luci-i18n-nikki-${lang}-"*)
						set -- "$@" "./$file"
						;;
				esac
			done
			;;
		*)
			set -- "$@" "./$file"
			;;
	esac
done

if [ "$#" -eq 0 ]; then
	echo "в архиве нет пакетов"
	exit 1
fi

# install
echo "update feeds"
if [ -x "/bin/opkg" ]; then
	opkg update
	echo "install ipks"
	opkg install "$@"
else
	apk update
	echo "install apks"
	apk add --allow-untrusted "$@"
fi

echo "success: $TAG"
