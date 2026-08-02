#!/bin/sh

# paths
HOME_DIR="/etc/nikki"
PROFILES_DIR="$HOME_DIR/profiles"
SUBSCRIPTIONS_DIR="$HOME_DIR/subscriptions"
MIXIN_FILE_PATH="$HOME_DIR/mixin.yaml"
RUN_DIR="$HOME_DIR/run"
RUN_PROFILE_PATH="$RUN_DIR/config.yaml"
PROVIDERS_DIR="$RUN_DIR/providers"
RULE_PROVIDERS_DIR="$PROVIDERS_DIR/rule"
PROXY_PROVIDERS_DIR="$PROVIDERS_DIR/proxy"

# log
LOG_DIR="/var/log/nikki"
APP_LOG_PATH="$LOG_DIR/app.log"
CORE_LOG_PATH="$LOG_DIR/core.log"

# temp
TEMP_DIR="/var/run/nikki"
PID_FILE_PATH="$TEMP_DIR/nikki.pid"
STARTED_FLAG_PATH="$TEMP_DIR/started.flag"
BRIDGE_NF_CALL_IPTABLES_FLAG_PATH="$TEMP_DIR/bridge_nf_call_iptables.flag"
BRIDGE_NF_CALL_IP6TABLES_FLAG_PATH="$TEMP_DIR/bridge_nf_call_ip6tables.flag"

# ucode
UCODE_DIR="$HOME_DIR/ucode"
INCLUDE_UC="$UCODE_DIR/include.uc"
MIXIN_UC="$UCODE_DIR/mixin.uc"
HIJACK_UT="$UCODE_DIR/hijack.ut"

# scripts
SH_DIR="$HOME_DIR/scripts"
INCLUDE_SH="$SH_DIR/include.sh"
FIREWALL_INCLUDE_SH="$SH_DIR/firewall_include.sh"

# nftables
NFT_DIR="$HOME_DIR/nftables"
GEOIP_CN_NFT="$NFT_DIR/geoip_cn.nft"
GEOIP6_CN_NFT="$NFT_DIR/geoip6_cn.nft"

# functions
format_filesize() {
	local b; b=1
	local kb; kb=$((b * 1024))
	local mb; mb=$((kb * 1024))
	local gb; gb=$((mb * 1024))
	local tb; tb=$((gb * 1024))
	local pb; pb=$((tb * 1024))
	local size; size="$1"
	if [ -n "$size" ]; then
		if [ "$size" -lt "$kb" ]; then
			echo "$(awk "BEGIN {print $size / $b}") B"
		elif [ "$size" -lt "$mb" ]; then
			echo "$(awk "BEGIN {print $size / $kb}") KB"
		elif [ "$size" -lt "$gb" ]; then
			echo "$(awk "BEGIN {print $size / $mb}") MB"
		elif [ "$size" -lt "$tb" ]; then
			echo "$(awk "BEGIN {print $size / $gb}") GB"
		elif [ "$size" -lt "$pb" ]; then
			echo "$(awk "BEGIN {print $size / $tb}") TB"
		else
			echo "$(awk "BEGIN {print $size / $pb}") PB"
		fi
	fi
}

prepare_files() {
	if [ ! -d "$LOG_DIR" ]; then
		mkdir -p "$LOG_DIR"
	fi
	if [ ! -f "$APP_LOG_PATH" ]; then
		touch "$APP_LOG_PATH"
	fi
	if [ ! -f "$CORE_LOG_PATH" ]; then
		touch "$CORE_LOG_PATH"
	fi
	if [ ! -d "$TEMP_DIR" ]; then
		mkdir -p "$TEMP_DIR"
	fi
}

log() {
	echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$1] $2" >> "$APP_LOG_PATH"
}

# hwid

sanitize_header_value() {
	printf '%s' "$1" | tr -d '\r\n' | LC_ALL=C tr -cd ' -~' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

get_device_model() {
	local model; model=""
	if [ -r "/tmp/sysinfo/model" ]; then
		model="$(cat "/tmp/sysinfo/model" 2>/dev/null)"
	fi
	if [ -z "$model" ] && [ -r "/proc/device-tree/model" ]; then
		model="$(tr -d '\0' < "/proc/device-tree/model" 2>/dev/null)"
	fi
	if [ -z "$model" ]; then
		model="$(uname -m 2>/dev/null)"
	fi
	if [ -z "$model" ]; then
		model="OpenWrt Device"
	fi
	sanitize_header_value "$model"
}

get_device_board() {
	local board; board=""
	if [ -r "/tmp/sysinfo/board_name" ]; then
		board="$(cat "/tmp/sysinfo/board_name" 2>/dev/null)"
	fi
	if [ -z "$board" ] && [ -r "/proc/device-tree/compatible" ]; then
		board="$(tr '\0' ',' < "/proc/device-tree/compatible" 2>/dev/null)"
	fi
	sanitize_header_value "$board"
}

get_os_name() {
	local name; name=""
	if [ -r "/etc/os-release" ]; then
		name="$(sed -n 's/^NAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "/etc/os-release" 2>/dev/null | head -n 1)"
	fi
	if [ -z "$name" ]; then
		name="OpenWrt"
	fi
	sanitize_header_value "$name"
}

get_os_version() {
	local version; version=""
	if [ -r "/etc/os-release" ]; then
		version="$(sed -n 's/^VERSION_ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "/etc/os-release" 2>/dev/null | head -n 1)"
	fi
	if [ -z "$version" ] && [ -r "/etc/openwrt_release" ]; then
		version="$(sed -n "s/^DISTRIB_RELEASE='\{0,1\}\([^']*\)'\{0,1\}$/\1/p" "/etc/openwrt_release" 2>/dev/null | head -n 1)"
	fi
	if [ -z "$version" ]; then
		version="$(uname -r 2>/dev/null)"
	fi
	sanitize_header_value "$version"
}

get_hwid_seed() {
	local seed; seed=""
	if [ -r "/proc/device-tree/serial-number" ]; then
		seed="$(tr -d '\0' < "/proc/device-tree/serial-number" 2>/dev/null)"
	fi
	if [ -z "$seed" ]; then
		local interface mac
		for interface in /sys/class/net/*; do
			[ -e "$interface/device" ] || continue
			mac="$(cat "$interface/address" 2>/dev/null)"
			case "$mac" in
				""|"00:00:00:00:00:00")
					continue
				;;
			esac
			seed="$mac"
			break
		done
	fi
	if [ -z "$seed" ]; then
		seed="$(cat "/proc/sys/kernel/hostname" 2>/dev/null)"
	fi
	printf '%s|%s|%s' "$seed" "$(get_device_board)" "$(get_device_model)"
}

generate_hwid() {
	local seed; seed="$1"
	if [ -z "$seed" ]; then
		seed="$(get_hwid_seed)"
	fi
	local digest; digest="$(printf '%s' "nikki-hwid:$seed" | sha256sum 2>/dev/null | cut -d ' ' -f 1)"
	if [ -z "$digest" ]; then
		digest="$(printf '%s' "nikki-hwid:$seed" | md5sum 2>/dev/null | cut -d ' ' -f 1)"
	fi
	printf '%s' "$digest" | awk '
		BEGIN {
			hex = "0123456789abcdef";
			alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
			length_limit = 16;
		}
		{
			out = "";
			for (i = 1; i + 1 <= length($0) && length(out) < length_limit; i += 2) {
				high = index(hex, substr($0, i, 1)) - 1;
				low = index(hex, substr($0, i + 1, 1)) - 1;
				if (high < 0 || low < 0) {
					continue;
				}
				out = out substr(alphabet, ((high * 16 + low) % 62) + 1, 1);
			}
			print out;
		}'
}
