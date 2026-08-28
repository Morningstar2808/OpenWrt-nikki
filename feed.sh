#!/bin/sh

# nikki (fork) feed
#
# Подключает роутер к фиду форка.
# По умолчанию — GitHub Pages этого репозитория. Другой адрес (зеркало, домашний
# nginx) задаётся переменной:
#
#   NIKKI_FEED_URL=https://nikki.example.org wget -O - .../feed.sh | ash
#
# После подключения:
#   opkg update && opkg install nikki luci-app-nikki
#   apk update  && apk add nikki luci-app-nikki
# и дальше обычные opkg upgrade / apk upgrade.

set -e

FEED_BASE="${NIKKI_FEED_URL:-https://morningstar2808.github.io/OpenWrt-nikki}"

FEED_BASE="${FEED_BASE%/}"

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
		echo "unsupported release: $DISTRIB_RELEASE"
		exit 1
		;;
esac

feed_url="$FEED_BASE/$branch/$arch/nikki"

if [ -x "/bin/opkg" ]; then
	echo "add key"
	wget -q -O "/tmp/key-build.pub" "$FEED_BASE/key-build.pub"
	if [ ! -s "/tmp/key-build.pub" ]; then
		echo "не удалось скачать $FEED_BASE/key-build.pub"
		rm -f "/tmp/key-build.pub"
		exit 1
	fi
	opkg-key add "/tmp/key-build.pub"
	rm -f "/tmp/key-build.pub"

	echo "add feed"
	if grep -q nikki /etc/opkg/customfeeds.conf; then
		sed -i '/nikki/d' /etc/opkg/customfeeds.conf
	fi
	echo "src/gz nikki $feed_url" >> /etc/opkg/customfeeds.conf

	echo "update feeds"
	opkg update
else
	echo "add key"
	wget -q -O "/tmp/nikki.pem" "$FEED_BASE/public-key.pem"
	if [ ! -s "/tmp/nikki.pem" ]; then
		echo "не удалось скачать $FEED_BASE/public-key.pem"
		rm -f "/tmp/nikki.pem"
		exit 1
	fi
	mkdir -p /etc/apk/keys
	mv "/tmp/nikki.pem" "/etc/apk/keys/nikki.pem"

	echo "add feed"
	mkdir -p /etc/apk/repositories.d
	if [ -f /etc/apk/repositories.d/customfeeds.list ] && grep -q nikki /etc/apk/repositories.d/customfeeds.list; then
		sed -i '/nikki/d' /etc/apk/repositories.d/customfeeds.list
	fi
	echo "$feed_url/packages.adb" >> /etc/apk/repositories.d/customfeeds.list

	echo "update feeds"
	apk update
fi

echo "success"
