#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

WITH_DEFCONFIG=0
if [ "${1:-}" = "--with-defconfig" ]; then
	WITH_DEFCONFIG=1
fi

fail() {
	echo "::error::$*" >&2
	exit 1
}

echo "[1/5] Checking shell scripts syntax (sh -n / bash -n) and shellcheck..."
bash_scripts=(
	.github/scripts/check-sanitization.sh
	.github/scripts/check-static.sh
)
posix_scripts=(
	scripts/sanitize-path.sh
	scripts/command_all.sh
)
mapfile -t airoha_scripts < <(find target/linux/airoha -type f \( -path '*/base-files/etc/board.d/*' -o -path '*/base-files/etc/init.d/*' -o -path '*/base-files/etc/hotplug.d/*' -o -path '*/base-files/lib/preinit/*' -o -path '*/base-files/lib/upgrade/*.sh' \) | sort)

for s in "${bash_scripts[@]}"; do
	bash -n "$s"
done
for s in "${posix_scripts[@]}" "${airoha_scripts[@]}"; do
	sh -n "$s"
done

if command -v shellcheck >/dev/null 2>&1; then
	shellcheck -S warning "${bash_scripts[@]}" "${posix_scripts[@]}"
	if [ "${#airoha_scripts[@]}" -gt 0 ]; then
		shellcheck -s sh -S error -e SC2148 "${airoha_scripts[@]}"
	fi
else
	echo "[WARN] shellcheck not installed; skipped shellcheck pass"
fi

echo "[2/5] Checking GitHub workflows with actionlint..."
if command -v actionlint >/dev/null 2>&1; then
	actionlint .github/workflows/*.yml
else
	echo "[WARN] actionlint not installed; skipped workflow lint"
fi

echo "[3/5] Checking feeds.conf.default and target configs..."
grep -qE '^src-git[[:space:]]+pon_drivers[[:space:]]+https://' feeds.conf.default || fail "feeds.conf.default missing https:// pon_drivers"
grep -qE '^src-git[[:space:]]+pon_userspace[[:space:]]+https://' feeds.conf.default || fail "feeds.conf.default missing https:// pon_userspace"
grep -q '^CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi=y$' configs/an7581.config || fail "an7581.config missing nokia_xg-040g-md-ubi"
grep -q '^CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi-usb-sfp=y$' configs/an7581.config || fail "an7581.config missing nokia_xg-040g-md-ubi-usb-sfp"
grep -q '^define Device/nokia_xg-040g-md-ubi$' target/linux/airoha/image/an7581.mk || fail "an7581.mk missing Device/nokia_xg-040g-md-ubi"
grep -q 'DEVICE_PACKAGES' target/linux/airoha/image/an7581.mk || fail "an7581.mk missing DEVICE_PACKAGES"
[ -f configs/release.config ] || fail "Missing configs/release.config"

echo "[4/5] Checking target/linux/airoha/patches-6.18 patch series..."
patch_count=0
while IFS= read -r pfile; do
	patch_count=$((patch_count + 1))
	base="$(basename "$pfile")"
	[[ "$base" =~ ^[0-9]{3}.*\.patch$ ]] || fail "Invalid patch filename format: $pfile"
	[ -s "$pfile" ] || fail "Empty patch file: $pfile"
	grep -qE '^(---|\+\+\+|diff --git )' "$pfile" || fail "Invalid diff header in patch: $pfile"
done < <(find target/linux/airoha/patches-6.18 -maxdepth 1 -type f | sort)
[ "$patch_count" -gt 0 ] || fail "No patches found in target/linux/airoha/patches-6.18"
echo "[OK] Verified $patch_count kernel patches in target/linux/airoha/patches-6.18"

echo "[5/5] Checking kconfig / defconfig consistency..."
if [ "$WITH_DEFCONFIG" -eq 1 ]; then
	./scripts/kconfig.pl + configs/an7581.config configs/release.config > .config
	make defconfig
	grep -q '^CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi=y$' .config || fail "make defconfig dropped nokia_xg-040g-md-ubi"
	grep -q '^CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi-usb-sfp=y$' .config || fail "make defconfig dropped nokia_xg-040g-md-ubi-usb-sfp"
	echo "[OK] make defconfig preserved XG-040G-MD profiles"
else
	echo "[INFO] Skipping make defconfig (pass --with-defconfig after feeds install)"
fi

echo "[OK] All static checks passed."
