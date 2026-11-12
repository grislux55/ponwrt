#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

fail() {
	echo "::error::$*" >&2
	exit 1
}

check_artifacts() {
	local dir="$1"
	[ -d "$dir" ] || fail "Artifact directory not found: $dir"
	local leaked
	leaked="$(find "$dir" -type f \( -name '*.pem' -o -name '*.key' -o -name '*private-key*' -o -name '*.dump' \) | sort || true)"
	if [ -n "$leaked" ]; then
		echo "$leaked" >&2
		fail "Sensitive key/dump files detected in artifact directory: $dir"
	fi
	echo "[OK] Artifact sanitization check passed for: $dir"
}

if [ "${1:-}" = "--check-artifacts" ]; then
	[ -n "${2:-}" ] || fail "Usage: $0 --check-artifacts <dir>"
	check_artifacts "$2"
	exit 0
fi

echo "[1/4] Checking feeds.conf.default for local paths or src-link..."
[ -f feeds.conf.default ] || fail "Missing feeds.conf.default"
if grep -nE '^[[:space:]]*src-link[[:space:]]+' feeds.conf.default; then
	fail "feeds.conf.default must not contain active src-link entries"
fi
if grep -nE '(/home/|/Users/|[A-Za-z]:\\\\|file://)' feeds.conf.default; then
	fail "feeds.conf.default contains local filesystem paths"
fi

echo "[2/4] Checking git-tracked files for forbidden dumps or private keys..."
forbidden_files="$(git ls-files | grep -E '(\.(key|dump|bak)$|(bosa|ri|mtd|ubi).*\.bin$)' || true)"
if [ -n "$forbidden_files" ]; then
	echo "$forbidden_files" >&2
	fail "Forbidden dump/key files tracked in git"
fi

non_allowlisted_pems="$(git ls-files '*.pem' | grep -v '^package/boot/arm-trusted-firmware-microchipsw/src/keys/' || true)"
if [ -n "$non_allowlisted_pems" ]; then
	echo "$non_allowlisted_pems" >&2
	fail "Unexpected .pem file tracked in git"
fi

echo "[3/4] Checking NNRRWrt customized paths for personal paths or private keys..."
custom_paths=()
for p in configs .github target/linux/airoha scripts files feeds.conf.default; do
	[ -e "$p" ] && custom_paths+=("$p")
done
if [ "${#custom_paths[@]}" -gt 0 ]; then
	if git grep -nE '(/home/[A-Za-z0-9._-]+/|/Users/[A-Za-z0-9._-]+/|C:\\\\Users\\\\)' -- "${custom_paths[@]}"; then
		fail "Personal local path detected in tracked project files"
	fi
	if git grep -nE 'BEGIN (RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY' -- "${custom_paths[@]}"; then
		fail "Private key block detected in tracked project files"
	fi
fi

echo "[4/4] Checking customized files for hardcoded ONT credentials or real identity values..."
check_dirs=()
for d in configs target/linux/airoha files; do
	[ -d "$d" ] && check_dirs+=("$d")
done
if [ "${#check_dirs[@]}" -gt 0 ]; then
	if git grep -nE "(option[[:space:]]+(pon_sn|loid|username|password)[[:space:]]+'[^']{4,}'|CONFIG_.*(PPPOE|LOID|PON_SN).*=[\"'][^\"']+[\"'])" -- "${check_dirs[@]}"; then
		fail "Potential hardcoded ONT/broadband credential detected"
	fi
fi

echo "[OK] Repository sanitization check passed."
