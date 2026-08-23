#!/bin/sh

# nikki (fork) uninstaller
#
#   wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/uninstall.sh | ash

# uninstall
if [ -x "/bin/opkg" ]; then
	i18n="$(opkg list-installed 'luci-i18n-nikki-*' | cut -d ' ' -f 1)"
	[ -n "$i18n" ] && opkg remove $i18n
	opkg remove luci-app-nikki
	opkg remove nikki
	opkg remove mihomo-meta
elif [ -x "/usr/bin/apk" ]; then
	i18n="$(apk list --installed --manifest 'luci-i18n-nikki-*' | cut -d ' ' -f 1)"
	[ -n "$i18n" ] && apk del $i18n
	apk del luci-app-nikki
	apk del nikki
	apk del mihomo-meta
fi
# remove config
rm -f /etc/config/nikki
# remove files
rm -rf /etc/nikki
# remove log
rm -rf /var/log/nikki /tmp/log/nikki
# remove temp
rm -rf /var/run/nikki
# remove leftover feed entry (если раньше подключался фид апстрима)
if [ -x "/bin/opkg" ]; then
	if grep -q nikki /etc/opkg/customfeeds.conf; then
		sed -i '/nikki/d' /etc/opkg/customfeeds.conf
	fi
elif [ -x "/usr/bin/apk" ]; then
	if [ -f /etc/apk/repositories.d/customfeeds.list ] && grep -q nikki /etc/apk/repositories.d/customfeeds.list; then
		sed -i '/nikki/d' /etc/apk/repositories.d/customfeeds.list
	fi
	rm -f /etc/apk/keys/nikki.pem
fi
