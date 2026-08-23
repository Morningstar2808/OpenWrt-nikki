#!/bin/sh

# nikki (fork) installer
#
# Ставит и обновляет пакеты из GitHub Releases этого форка.
# Своего фида у форка пока нет, поэтому обновление = повторный запуск скрипта.
#
#   wget -O - https://github.com/Morningstar2808/OpenWrt-nikki/raw/refs/heads/main/install.sh | ash
#   wget -O - .../install.sh | ash -s -- --lang ru
#
# Ставятся только те пакеты, версия которых отличается от установленной,
# поэтому повторный запуск ничего не трогает и сервис не перезапускает.
#
# Аргументы (или переменные окружения):
#   --lang   <коды|all|none>   NIKKI_LANG    переводы LuCI, по умолчанию none
#   --mihomo <meta|alpha>      NIKKI_MIHOMO  ядро, по умолчанию meta
#   --tag    <тег>             NIKKI_TAG     конкретный релиз, по умолчанию последний
#   --repo   <owner/repo>      NIKKI_REPO    другое зеркало релизов
#   --force                                  переставить, даже если версии совпали
#   --help

set -e

REPO="${NIKKI_REPO:-Morningstar2808/OpenWrt-nikki}"
TAG="${NIKKI_TAG:-}"
MIHOMO="${NIKKI_MIHOMO:-meta}"
LANG_SELECTION="${NIKKI_LANG:-none}"
FORCE=0

usage() {
	cat <<'EOF'
nikki (fork) installer

  --lang   <коды|all|none>  переводы LuCI: "ru", "ru zh-cn", all. По умолчанию none
  --mihomo <meta|alpha>     ядро mihomo. По умолчанию meta (стабильные релизы)
  --tag    <тег>            конкретный релиз, например v1.27.0-rc2
  --repo   <owner/repo>     другой репозиторий с теми же ассетами
  --force                   переустановить, даже если версии совпадают
  --help                    эта справка

Примеры:
  wget -O - .../install.sh | ash
  wget -O - .../install.sh | ash -s -- --lang ru
  wget -O - .../install.sh | ash -s -- --mihomo alpha --tag v1.27.0-rc2
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--lang)   LANG_SELECTION="${2:-}"; shift ;;
		--lang=*) LANG_SELECTION="${1#*=}" ;;
		--mihomo)   MIHOMO="${2:-}"; shift ;;
		--mihomo=*) MIHOMO="${1#*=}" ;;
		--tag)   TAG="${2:-}"; shift ;;
		--tag=*) TAG="${1#*=}" ;;
		--repo)   REPO="${2:-}"; shift ;;
		--repo=*) REPO="${1#*=}" ;;
		--force) FORCE=1 ;;
		--help|-h) usage; exit 0 ;;
		*) echo "неизвестный аргумент: $1"; echo; usage; exit 1 ;;
	esac
	shift
done

case "$MIHOMO" in
	meta|alpha) ;;
	*) echo "--mihomo принимает meta или alpha, получено «$MIHOMO»"; exit 1 ;;
esac

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

if [ -x "/bin/opkg" ]; then
	ext="ipk"
else
	ext="apk"
fi

# имя и версия из имени файла:
#   nikki_2026.04.08-3_x86_64.ipk       -> nikki           2026.04.08-3
#   luci-app-nikki-1.27.0-r1.apk        -> luci-app-nikki  1.27.0-r1
pkg_name() {
	case "$1" in
		# ipk: имя_версия_арх.ipk, имя без подчёркиваний
		*.ipk) echo "${1%%_*}" ;;
		# apk: имя-версия[-rN].apk, имя может содержать дефисы
		*)     echo "${1%.apk}" | sed 's/-r[0-9][0-9]*$//' | sed 's/-[0-9][^-]*$//' ;;
	esac
}

pkg_version() {
	case "$1" in
		# арх сам может содержать подчёркивания (x86_64), режем по первым двум
		*.ipk) _r="${1#*_}"; echo "${_r%%_*}" ;;
		*)     _b="${1%.apk}"; _n="$(pkg_name "$1")"; echo "${_b#"${_n}"-}" ;;
	esac
}

installed_version() {
	if [ -x "/bin/opkg" ]; then
		opkg list-installed "$1" 2>/dev/null | awk -v n="$1" '$1 == n { print $3; exit }'
	else
		apk list --installed --manifest "$1" 2>/dev/null | awk -v n="$1" '$1 == n { print $2; exit }'
	fi
}

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

# ядро mihomo: mihomo-meta и mihomo-alpha конфликтуют, ставим ровно одно
mihomo_file=""
for file in mihomo-*."$ext"; do
	[ -f "$file" ] || continue
	case "$file" in
		"mihomo-${MIHOMO}_"*|"mihomo-${MIHOMO}-"*)
			mihomo_file="$file"
			;;
	esac
done
if [ -z "$mihomo_file" ]; then
	for file in mihomo-*."$ext"; do
		[ -f "$file" ] || continue
		mihomo_file="$file"
		break
	done
	if [ -n "$mihomo_file" ]; then
		echo "в сборке нет mihomo-$MIHOMO, ставлю $mihomo_file"
		MIHOMO="$(pkg_name "$mihomo_file")"
		MIHOMO="${MIHOMO#mihomo-}"
	fi
fi
[ -n "$mihomo_file" ] && echo "mihomo: $(pkg_name "$mihomo_file") $(pkg_version "$mihomo_file")"

# второй вариант ядра снимать автоматически опасно: от него зависит nikki
if [ "$MIHOMO" = "meta" ]; then other="alpha"; else other="meta"; fi
if [ -n "$(installed_version "mihomo-$other")" ]; then
	echo ""
	echo "на роутере стоит mihomo-$other, а ставится mihomo-$MIHOMO — пакеты конфликтуют."
	echo "сначала снять старое ядро вместе с зависимыми, затем запустить скрипт снова:"
	echo ""
	if [ -x "/bin/opkg" ]; then
		echo "  /etc/init.d/nikki stop"
		echo "  opkg remove luci-app-nikki nikki mihomo-$other"
	else
		echo "  /etc/init.d/nikki stop"
		echo "  apk del luci-app-nikki nikki mihomo-$other"
	fi
	echo ""
	echo "конфиг /etc/config/nikki при этом сохраняется."
	exit 1
fi

# переводы, которые есть в сборке
available=""
for file in luci-i18n-nikki-*."$ext"; do
	[ -f "$file" ] || continue
	lang="$(pkg_name "$file")"
	available="$available ${lang#luci-i18n-nikki-}"
done
available="$(echo $available)"

# по умолчанию переводы не ставятся — интерфейс английский
case "$LANG_SELECTION" in
	n|no|none|"")
		languages=""
		;;
	a|all)
		languages="$available"
		;;
	*)
		languages=""
		for token in $(echo "$LANG_SELECTION" | tr ',' ' '); do
			found=0
			for lang in $available; do
				if [ "$lang" = "$token" ]; then
					languages="$languages $lang"
					found=1
				fi
			done
			[ "$found" = 0 ] && echo "перевода «$token» в сборке нет, пропускаю"
		done
		languages="$(echo $languages)"
		;;
esac

if [ -n "$languages" ]; then
	echo "languages: $languages"
elif [ -n "$available" ]; then
	echo "languages: english only (в сборке есть: $available — добавить: --lang ru)"
fi

# что вообще относится к этой установке
candidates=""
for file in *."$ext"; do
	[ -f "$file" ] || continue
	case "$file" in
		mihomo-*)
			[ "$file" = "$mihomo_file" ] && candidates="$candidates $file"
			;;
		luci-i18n-nikki-*)
			for lang in $languages; do
				case "$(pkg_name "$file")" in
					"luci-i18n-nikki-$lang") candidates="$candidates $file" ;;
				esac
			done
			;;
		*)
			candidates="$candidates $file"
			;;
	esac
done

if [ -z "$(echo $candidates)" ]; then
	echo "в архиве нет пакетов"
	exit 1
fi

# ставим только то, что отличается от установленного
set --
skipped=0
for file in $candidates; do
	name="$(pkg_name "$file")"
	want="$(pkg_version "$file")"
	have="$(installed_version "$name")"
	if [ "$FORCE" = 0 ] && [ -n "$have" ] && [ "$have" = "$want" ]; then
		skipped=$((skipped + 1))
		continue
	fi
	if [ -n "$have" ]; then
		echo "  $name: $have -> $want"
	else
		echo "  $name: $want (новый)"
	fi
	set -- "$@" "./$file"
done

if [ "$#" -eq 0 ]; then
	echo "всё актуально: $skipped пакетов уже нужной версии, сервис не трогаю"
	echo "переустановить принудительно: --force"
	exit 0
fi
[ "$skipped" -gt 0 ] && echo "без изменений: $skipped"

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
