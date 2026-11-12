#! /bin/sh
# SPDX-License-Identifier: GPL-2.0-or-later
# Reduced version of which -a using command utility

case $PATH in
	(*[!:]:) PATH="$PATH:" ;;
esac

old_ifs=$IFS
IFS=:
set -f
for ELEMENT in $PATH; do
	[ -n "$ELEMENT" ] && PATH="$ELEMENT" command -v "$@"
done
set +f
IFS=$old_ifs
