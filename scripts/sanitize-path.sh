#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Sanitize PATH for OpenWrt/PonWrt builds (drops relative entries,
# entries containing whitespace, and Windows /mnt/<drive> paths under WSL).

set -f

is_wsl=0
if [ -n "${WSL_DISTRO_NAME:-}" ] || [ -n "${WSL_INTEROP:-}" ]; then
	is_wsl=1
elif [ -r /proc/version ] && grep -qi 'microsoft' /proc/version 2>/dev/null; then
	is_wsl=1
fi

new_path=""
old_ifs=$IFS
IFS=:
for entry in $PATH; do
	case "$entry" in
		""|.|./*|..|../*)
			continue
			;;
		*[[:space:]]*)
			continue
			;;
	esac
	if [ "$is_wsl" -eq 1 ]; then
		case "$entry" in
			/mnt/[A-Za-z]|/mnt/[A-Za-z]/*)
				continue
				;;
		esac
	fi
	case ":$new_path:" in
		*":$entry:"*) continue ;;
	esac
	new_path="${new_path:+$new_path:}$entry"
done
IFS=$old_ifs

if [ -z "$new_path" ]; then
	new_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
fi

printf '%s\n' "$new_path"
