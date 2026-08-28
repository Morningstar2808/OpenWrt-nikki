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
#   --tag    <тег>             NIKKI_TAG     конкретный релиз, по умолчанию последний
#                                            стабильный
#   --pre                      NIKKI_PRE=1   разрешить pre-release (rc, beta)
#   --repo   <owner/repo>      NIKKI_REPO    другое зеркало релизов
#   --force                                  переставить, даже если версии совпали
#   --help

set -e

REPO="${NIKKI_REPO:-Morningstar2808/OpenWrt-nikki}"
TAG="${NIKKI_TAG:-}"
LANG_SELECTION="${NIKKI_LANG:-none}"
PRE="${NIKKI_PRE:-0}"
FORCE=0

usage() {
	cat <<'EOF'
nikki (fork) installer

  --lang   <коды|all|none>  переводы LuCI: "ru", "ru zh-cn", all. По умолчанию none
  --tag    <тег>            конкретный релиз, например v1.27.0-rc2
  --pre                     брать последний релиз, включая pre-release
  --repo   <owner/repo>     другой репозиторий с теми же ассетами
  --force                   переустановить, даже если версии совпадают
  --help                    эта справка

Примеры:
  wget -O - .../install.sh | ash
  wget -O - .../install.sh | ash -s -- --lang ru
  wget -O - .../install.sh | ash -s -- --tag v1.27.0-rc2
EOF
}

need_value() {
	if [ "$2" -lt 2 ]; then
		echo "$1 требует значение"
		exit 1
	fi
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--lang)   need_value "$1" "$#"; LANG_SELECTION="$2"; shift ;;
		--lang=*) LANG_SELECTION="${1#*=}" ;;
		--tag)   need_value "$1" "$#"; TAG="$2"; shift ;;
		--tag=*) TAG="${1#*=}" ;;
		--repo)   need_value "$1" "$#"; REPO="$2"; shift ;;
		--repo=*) REPO="${1#*=}" ;;
		--pre) PRE=1 ;;
		--force) FORCE=1 ;;
		--help|-h) usage; exit 0 ;;
		*) echo "неизвестный аргумент: $1"; echo; usage; exit 1 ;;
	esac
	shift
done

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
		# nikki - 2026.04.08-3
		opkg list-installed "$1" 2>/dev/null | awk -v n="$1" '$1 == n { print $3; exit }'
		return
	fi
	# apk печатает по-разному в зависимости от версии и флагов:
	#   nikki-2026.04.08-r3 aarch64_cortex-a53 {nikki} (GPL-3.0) [installed]
	#   nikki 2026.04.08-r3                                       (--manifest)
	# поэтому разбираем обе формы, а не полагаемся на одну.
	{ apk list --installed --manifest "$1" 2>/dev/null; apk list --installed "$1" 2>/dev/null; } |
	while read -r first second _; do
		case "$first" in
			"$1")
				[ -n "$second" ] || continue
				echo "$second"
				break
				;;
			"$1"-[0-9]*)
				echo "${first#"$1"-}"
				break
				;;
		esac
	done
}

# установлен ли пакет вообще — на случай, если версию вытащить не вышло
is_installed() {
	[ -n "$(installed_version "$1")" ] && return 0
	[ -x "/usr/bin/apk" ] && apk info -e "$1" >/dev/null 2>&1 && return 0
	return 1
}

# свободно килобайт там, где живёт /usr/libexec
free_space_kb() {
	for dir in /overlay /; do
		[ -d "$dir" ] || continue
		df -k "$dir" 2>/dev/null | awk 'NR == 2 { print $4; exit }'
		return
	done
}

# resolve tag
if [ -z "$TAG" ]; then
	# по умолчанию — только стабильные релизы: /releases/latest их и отдаёт,
	# pre-release в него не попадает. --pre берёт самый свежий вообще.
	if [ "$PRE" = 1 ]; then
		echo "get latest release (pre-release allowed)"
		api="https://api.github.com/repos/$REPO/releases?per_page=1"
		filter="@[0].tag_name"
	else
		echo "get latest stable release"
		api="https://api.github.com/repos/$REPO/releases/latest"
		filter="@.tag_name"
	fi
	wget -q -O "/tmp/nikki.releases" "$api" || true
	TAG="$(jsonfilter -i "/tmp/nikki.releases" -e "$filter" 2>/dev/null)"
	rm -f "/tmp/nikki.releases"
	if [ -z "$TAG" ]; then
		if [ "$PRE" = 1 ]; then
			echo "не удалось определить последний релиз $REPO"
		else
			echo "у $REPO нет стабильных релизов"
			echo "поставить тестовый: ash -s -- --pre"
		fi
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
# /tmp — это tmpfs, то есть оперативная память. Архив содержит несколько
# пакетов, и распаковка всего подряд (два ядра mihomo — это ~92 МБ) кладёт
# роутер по OOM. Поэтому сначала читаем список, а достаём только нужное.
members="$(tar -t -z -f "$asset" | sed 's|^\./||' | grep "\.$ext\$" || true)"
if [ -z "$members" ]; then
	echo "в архиве нет пакетов .$ext"
	exit 1
fi

# ядро: ставим только mihomo-meta (сборки из тегированных релизов MetaCubeX).
# mihomo-alpha — ночная ветка, из установки исключён намеренно.
mihomo_file=""
for file in $members; do
	case "$file" in
		mihomo-meta_*|mihomo-meta-*)
			mihomo_file="$file"
			break
			;;
	esac
done
if [ -z "$mihomo_file" ]; then
	echo "в сборке $TAG нет mihomo-meta"
	exit 1
fi
echo "mihomo: $(pkg_name "$mihomo_file") $(pkg_version "$mihomo_file")"

# если на роутере осталось альфа-ядро, оно конфликтует с meta
if is_installed "mihomo-alpha"; then
	echo ""
	echo "установлен mihomo-alpha, он конфликтует с mihomo-meta"
	if [ -x "/bin/opkg" ]; then
		echo "  opkg remove luci-app-nikki nikki mihomo-alpha"
	else
		echo "  apk del luci-app-nikki nikki mihomo-alpha"
	fi
	exit 1
fi

# переводы, которые есть в сборке
available=""
for file in $members; do
	case "$file" in
		luci-i18n-nikki-*)
			lang="$(pkg_name "$file")"
			available="$available ${lang#luci-i18n-nikki-}"
			;;
	esac
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
	echo "languages: none (в сборке: $available)"
fi

# что вообще относится к этой установке
candidates=""
for file in $members; do
	case "$file" in
		mihomo-*)
			# в архиве может лежать и mihomo-alpha — он не ставится
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
	echo "всё актуально: $skipped пакетов уже нужной версии"
	echo "переустановить: ash -s -- --force"
	exit 0
fi
[ "$skipped" -gt 0 ] && echo "без изменений: $skipped"

# ядро mihomo — это ~50 МБ распакованного файла. Каталог распаковки лежит
# в /tmp, а /tmp на OpenWrt — это tmpfs, то есть оперативная память: не хватит
# места — роутер уйдёт в OOM прямо посреди установки. Поэтому проверяем оба
# ресурса заранее: память под распаковку и overlay под саму установку.
need_mb=8
case " $* " in
	*mihomo-*) need_mb=60 ;;
esac

tmp_kb="$(df -k "$work" 2>/dev/null | awk 'NR == 2 { print $4; exit }')"
if [ "$FORCE" = 0 ] && [ -n "$tmp_kb" ] && [ "$tmp_kb" -lt $((need_mb * 1024)) ]; then
	echo ""
	echo "$work: свободно $((tmp_kb / 1024)) МБ, нужно ~$need_mb МБ (tmpfs)"
	exit 1
fi

overlay_kb="$(free_space_kb)"
if [ "$FORCE" = 0 ] && [ -n "$overlay_kb" ] && [ "$overlay_kb" -lt $((need_mb * 1024)) ]; then
	echo ""
	echo "/overlay: свободно $((overlay_kb / 1024)) МБ, нужно ~$need_mb МБ"
	echo "обойти проверку: ash -s -- --force"
	exit 1
fi
echo "свободно: tmpfs $((tmp_kb / 1024)) МБ, overlay $((overlay_kb / 1024)) МБ"

# достаём из архива ровно выбранные пакеты и сразу удаляем сам архив,
# чтобы в tmpfs не лежало лишнего
echo "unpack: $#"
tar -x -z -f "$asset" "$@"
rm -f "$asset"
for file in "$@"; do
	if [ ! -f "$file" ]; then
		echo "не удалось распаковать $file"
		exit 1
	fi
done

# install
echo "update OpenWrt indexes (for dependencies)"
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
